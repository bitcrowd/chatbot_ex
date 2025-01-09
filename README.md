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

## fly deployment
you must set SECRET_KEY_BASE to deploy to fly.io

`flyctl secret set SECRET_KEY_BASE=...`

you can ingest data into the system by running `/app/bin/chatbot eval Chatbot.Release.ingest`. 
