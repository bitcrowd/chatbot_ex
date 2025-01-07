defmodule Chatbot.Rag do
  alias Chatbot.Repo
  import Ecto.Query
  import Pgvector.Ecto.Query

  alias Rag.{Embedding, Generation, Retrieval}

  def ingest(path) do
    path
    |> load()
    |> index()
  end

  def load(path) do
    path
    |> list_text_files()
    |> Enum.map(&%{source: &1})
    |> Enum.map(&Rag.Loading.load_file(&1))
  end

  defp list_text_files(path) do
    path
    |> Path.join("/**/*.txt")
    |> Path.wildcard()
  end

  def index(ingestions) do
    chunks =
      ingestions
      |> Enum.flat_map(&chunk_text(&1, :document))
      |> Embedding.Nx.generate_embeddings_batch(Rag.EmbeddingServing,
        text_key: :chunk,
        embedding_key: :embedding
      )
      |> Enum.map(&to_chunk(&1))

    Repo.insert_all(Chatbot.Rag.Chunk, chunks)
  end

  defp chunk_text(ingestion, text_key, opts \\ []) do
    text = Map.fetch!(ingestion, text_key)
    chunks = TextChunker.split(text, opts)

    Enum.map(chunks, &Map.put(ingestion, :chunk, &1.text))
  end

  def build_generation(query) do
    generation =
      Generation.new(query)
      |> Embedding.Nx.generate_embedding(Rag.EmbeddingServing)
      |> Retrieval.retrieve(:fulltext_results, fn generation -> query_fulltext(generation) end)
      |> Retrieval.retrieve(:semantic_results, fn generation ->
        query_with_pgvector(generation)
      end)
      |> Retrieval.reciprocal_rank_fusion(
        %{fulltext_results: 1, semantic_results: 1},
        :rrf_result
      )
      |> Retrieval.deduplicate(:rrf_result, [:source])

    context =
      Generation.get_retrieval_result(generation, :rrf_result)
      |> Enum.map_join("\n\n", & &1.document)

    context_sources =
      Generation.get_retrieval_result(generation, :rrf_result)
      |> Enum.map(& &1.source)

    prompt = prompt(query, context)

    generation
    |> Generation.put_context(context)
    |> Generation.put_context_sources(context_sources)
    |> Generation.put_prompt(prompt)
  end

  defp to_chunk(ingestion) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    ingestion
    |> Map.put_new(:inserted_at, now)
    |> Map.put_new(:updated_at, now)
  end

  defp query_with_pgvector(%{query_embedding: query_embedding}, limit \\ 3) do
    Repo.all(
      from(c in Chatbot.Rag.Chunk,
        order_by: l2_distance(c.embedding, ^Pgvector.new(query_embedding)),
        limit: ^limit
      )
    )
  end

  defp query_fulltext(%{query: query}, limit \\ 3) do
    query = query |> String.trim() |> String.replace(" ", " & ")

    Repo.all(
      from(c in Chatbot.Rag.Chunk,
        where: fragment("to_tsvector(?) @@ to_tsquery(?)", c.document, ^query),
        limit: ^limit
      )
    )
  end

  defp prompt(query, context) do
    """
    Context information is below.
    ---------------------
    #{context}
    ---------------------
    Given the context information and no prior knowledge, answer the query.
    Query: #{query}
    Answer:
    """
  end
end
