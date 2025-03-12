defmodule Chatbot.Rag do
  alias Chatbot.Repo
  alias Rag.{Ai, Embedding, Generation, Retrieval}

  import Ecto.Query
  import Pgvector.Ecto.Query

  @provider Ai.Nx.new(%{embeddings_serving: Rag.EmbeddingServing})

  def ingest_ecto() do
    docs_url = "https://repo.hex.pm/docs/ecto-3.12.5.tar.gz"

    code_url = "https://repo.hex.pm/tarballs/ecto-3.12.5.tar"

    req = Req.new(url: docs_url) |> ReqHex.attach()
    docs_tarball = Req.get!(req).body

    docs =
      for {file, content} <- docs_tarball, text_file?(file) do
        file = to_string(file)
        %{source: file, document: content}
      end

    req = Req.new(url: code_url) |> ReqHex.attach()
    code_tarball = Req.get!(req).body

    code =
      for {file, content} <- code_tarball["contents.tar.gz"] do
        %{source: file, document: content}
      end

    index(docs ++ code)
  end

  defp text_file?(file) when is_list(file) do
    file
    |> to_string()
    |> String.ends_with?([".html", ".md", ".txt"])
  end

  defp text_file?(file) when is_binary(file) do
    file
    |> String.ends_with?([".html", ".md", ".txt"])
  end

  def index(ingestions) do
    chunks =
      ingestions
      |> Enum.flat_map(&chunk_text(&1, :document))
      |> Embedding.generate_embeddings_batch(@provider,
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
      |> Embedding.generate_embedding(@provider)
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
    {:ok,
     Repo.all(
       from(c in Chatbot.Rag.Chunk,
         order_by: l2_distance(c.embedding, ^Pgvector.new(query_embedding)),
         limit: ^limit
       )
     )}
  end

  defp query_fulltext(%{query: query}, limit \\ 3) do
    query = query |> String.trim() |> String.replace(" ", " & ")

    {:ok,
     Repo.all(
       from(c in Chatbot.Rag.Chunk,
         where: fragment("to_tsvector(?) @@ to_tsquery(?)", c.document, ^query),
         limit: ^limit
       )
     )}
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
