# LogflareLogger

A Logger backend for [Logflare](https://github.com/Logflare/logflare). Streams logs in batches to the Logflare.com or self-hosted (coming soon) Logflare app.

# Configuration

Get your `api_key` and create up to a 100 `source`s at [logflare.app](https://logflare.app)

```
config :logflare_logger_backend,
  api_key: "...",
  source: "...",
  level: :info, # or other Logger level,
  flush_interval: 1_000 # minimum time in ms before a log batch is sent to the server ",
  max_batch_size: 50 # maximum number of events before a log batch is sent to the server
```


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `logflare_logger_backend` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:logflare_logger_backend, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/logflare_logger_backend](https://hexdocs.pm/logflare_logger_backend).
