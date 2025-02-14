defmodule Chatbot.Rag.Serving do
  # @embedding_repo {:hf, "thenlper/gte-small" }
  @embedding_repo {:hf, "jinaai/jina-embeddings-v2-base-code" }
  # @embedding_repo {:hf, "jinaai/jina-embeddings-v2-base-en" }
 
  @llm_repo {:hf, "microsoft/phi-3.5-mini-instruct"}
  # @llm_repo {:hf, "meta-llama/Meta-Llama-3-8B"}

  def build_embedding_serving() do
    {:ok, model_info} = Bumblebee.load_model(@embedding_repo,
        spec_overrides: [architecture: :base],
        params_filename: "model.safetensors"
    )

    {:ok, tokenizer} = Bumblebee.load_tokenizer(@embedding_repo)

    Bumblebee.Text.TextEmbedding.text_embedding(model_info, tokenizer,
      compile: [batch_size: 64, sequence_length: 512],
      defn_options: [compiler: EXLA],
      output_attribute: :hidden_state,
      # output_attribute: :hidden_states,
      # output_attribute: :attentions,
      # output_attribute: :logits,
      output_pool: :mean_pooling
    )
  end

  def build_llm_serving() do
    {:ok, model_info} = Bumblebee.load_model(@llm_repo)
    {:ok, tokenizer} = Bumblebee.load_tokenizer(@llm_repo)
    {:ok, generation_config} = Bumblebee.load_generation_config(@llm_repo)

    generation_config = Bumblebee.configure(generation_config, max_new_tokens: 1024)

    Bumblebee.Text.generation(model_info, tokenizer, generation_config,
      compile: [batch_size: 1, sequence_length: 6000],
      defn_options: [compiler: EXLA],
      stream: true
    )
  end

  def load_all do
    Bumblebee.load_model(@llm_repo)
    Bumblebee.load_tokenizer(@llm_repo)
    Bumblebee.load_generation_config(@llm_repo)

    Bumblebee.load_model(@embedding_repo)
    Bumblebee.load_tokenizer(@embedding_repo)
  end
end
