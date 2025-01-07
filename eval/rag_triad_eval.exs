openai_key = Application.compile_env(:chatbot, :openai_key)

dataset =
  "https://huggingface.co/datasets/explodinggradients/amnesty_qa/resolve/main/english.json"

IO.puts("downloading dataset")

data =
  Req.get!(dataset).body
  |> Jason.decode!()

IO.puts("indexing")

data["contexts"]
|> Enum.map(&Enum.join(&1, " "))
|> Enum.with_index(fn context, index -> %{document: context, source: "#{index}"} end)
|> Chatbot.Rag.index()

IO.puts("generating responses")

generations =
  for question <- data["question"] do
    Chatbot.Rag.query(question)
  end

openai_params = %{
  model: "gpt-4o-mini",
  api_key: openai_key
}

IO.puts("evaluating")

generations =
  for generation <- generations do
    Rag.Evaluation.OpenAI.evaluate_rag_triad(generation, openai_params)
  end

json = generations |> Enum.map(& &1.evaluations) |> Jason.encode!()

File.write!(Path.join(__DIR__, "triad_eval.json"), json)

average_rag_triad_scores =
  Enum.map(
    generations,
    fn gen ->
      %{
        evaluations: %{
          "context_relevance_score" => context_relevance_score,
          "groundedness_score" => groundedness_score,
          "answer_relevance_score" => answer_relevance_score
        }
      } = gen

      (context_relevance_score + groundedness_score + answer_relevance_score) / 3
    end
  )

total_average_score = Enum.sum(average_rag_triad_scores) / Enum.count(average_rag_triad_scores)

IO.puts("Score: #{total_average_score}")
