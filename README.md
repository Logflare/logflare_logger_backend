# LogflareLogger

An Elixir Logger backend for [Logflare](https://github.com/Logflare/logflare). Streams logs to the [Logflare.app](https://logflare.app) API or self-hosted Logflare app.

This package is under active development and not yet ready for production usage.

# Configuration

Get your `api_key` and create up a `source` at [logflare.app](https://logflare.app)

You will need **source_id** which you can copy from your dashboard.

```elixir
config :logger,
  backends: [LogflareLogger.HttpBackend],

config :logflare_logger_backend,
  url: "http://logflare.app", # http://logflare.app is configured by defaul and you can set your own url
  api_key: "...",
  source_id: "...",
  level: :info, # or other Logger level,
  flush_interval: 1_000 # minimum time in ms before a log batch is sent to the server ",
  max_batch_size: 50 # maximum number of events before a log batch is sent to the server
```

## Usage

After configuring LogflareLogger in `config.exs`, use `Logger.info, Logger.error, ...` functions to send log events to Logflare app.

## Usage with context

```elixir
# Merges map or keyword with existing context, will overwrite values.
LogflareLogger.merge_context(%{user: %{id: 3735928559}})
LogflareLogger.merge_context(user: %{id: 3735928559})

# Get all context entries or a value for a specific key
LogflareLogger.get_context(:user)
LogflareLogger.get_context()

# Deletes all context entries or specific context key/value
LogflareLogger.delete_context(:user)
LogflareLogger.delete_context()
```
## Exceptions

LogflareLogger automatically logs all exceptions and formats stacktraces.

## Troubleshooting

Run `mix logflare_logger.verify_config` to test your config.

Email <support@logflare.app> for help!

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
