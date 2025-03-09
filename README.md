# Chatbot

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Configuration options

### Mock API calls

If you just want to try out the chatbot, but you don't have any LLM setup yet, you can set `MOCK_LLM_API` to `true` and use the chatbot with fake mocked messages.

```
MOCK_LLM_API=true mix phx.server
```

### Using Ollama

Currently, the application is set to use Ollama. The model is set to `llama3.2:latest`. Change the it in `lib/chatbot/chat.ex`. 

To use Ollama, you need to have it installed and running on your machine. Look at the [Ollama website](https://ollama.com/) for more information. To pull the model, run the following command:

```
ollama pull llama3.2:latest
``` 

### Using OpenAI

To use OpenAI, change the @llm definition in the `lib/chatbot/chat.ex`.

``` 
@llm LangChain.ChatModels.ChatOllamaAI.new!(%{
  model: "llama3.2:latest",
  stream: false
})
```

Set the `OPENAI_API_KEY` environment variable to your OpenAI API key.

```
OPENAI_API_KEY=your_openai_api_key mix phx.server
```



