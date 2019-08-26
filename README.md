# LogflareLogger

An Elixir Logger backend for [Logflare](https://github.com/Logflare/logflare). Streams logs to the [Logflare.app](https://logflare.app) API or self-hosted Logflare app.

This package is under active development and not yet ready for production usage.

# Configuration

Get your `api_key` and create up a `source` at [logflare.app](https://logflare.app)

You will need **source_id** which you can copy from your dashboard.

```elixir
config :logger,
  level: :info, # or other Logger level,
  backends: [LogflareLogger.HttpBackend]

config :logflare_logger_backend,
  url: "https://api.logflare.app", # http://logflare.app is configured by defaul and you can set your own url
  api_key: "...",
  source_id: "...",
  flush_interval: 1_000, # minimum time in ms before a log batch is sent to the server ",
  max_batch_size: 50 # maximum number of events before a log batch is sent to the server
```

## Usage

After configuring LogflareLogger in `config.exs`, use `Logger.info, Logger.error, ...` functions to send log events to Logflare app.

## Usage with context

`LogflareLogger.context` function signatures follows the one of `Logger.metadata` with slight modifications to parameters and return values.

```elixir
# Merges map or keyword with existing context, will overwrite values.
LogflareLogger.context(%{user: %{id: 3735928559}})
LogflareLogger.context(user: %{id: 3735928559})

# Get all context entries or a value for a specific key
LogflareLogger.context(:user)
LogflareLogger.context()

# Deletes all context entries or specific context key/value
LogflareLogger.context(user: nil)
LogflareLogger.reset_context()
```

## Current limitations

Logflare log event BigQuery table schema is auto-generated per source. If you send a log with `Logger.info("first", user: %{id: 1})`, Logflare will generate a metadata field of type integer. If in the future, you'll send a log event to the same source using `Logger.info("first", user: %{id: "d9c2feff-d38a-4671-8de4-a1e7f7dd7e3c"1})`, the log with a binary id will be rejected.

LogflareLogger log payloads sent to Logflare API are encoded using [BERT](http://bert-rpc.org).

At this moment LogflareLogger doesn't support full one-to-one logging of Elixir types and applies the following conversions:

* atoms converted to strings
* charlists are converted to strings
* tuples converted to arrays
* keyword lists converted to maps
* structs converted to maps
* NaiveDateTime and DateTime are converted using the `String.Chars` protocol
* pids are converted to strings

LogflareLogger doesn't support:

* non-binary messages, e.g. `Logger.info(%{user_count: 1337})`

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
    {:logflare_logger_backend, "~> 0.6.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/logflare_logger_backend](https://hexdocs.pm/logflare_logger_backend).
