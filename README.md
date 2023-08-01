# LogflareLogger

An Elixir Logger backend for [Logflare](https://github.com/Logflare/logflare). Streams logs to the [Logflare.app](https://logflare.app) API.

# Configuration

Get your `api_key` and create a `source` at [logflare.app](https://logflare.app/dashboard)

You will need a Logflare source **source_id** which you can copy from your dashboard after you create a one.

```elixir
config :logger,
  level: :info, # or other Logger level
  backends: [LogflareLogger.HttpBackend]

config :logflare_logger_backend,
  url: "https://api.logflare.app", # https://api.logflare.app is configured by default and you can set your own url
  level: :info, # Default LogflareLogger level is :info. Note that log messages are filtered by the :logger application first
  api_key: "...", # your Logflare API key, found on your dashboard
  source_id: "...", # the Logflare source UUID, found  on your Logflare dashboard
  flush_interval: 1_000, # minimum time in ms before a log batch is sent
  max_batch_size: 50, # maximum number of events before a log batch is sent
  metadata: :all # optionally you can drop keys if they exist with `metadata: [drop: [:list, :keys, :to, :drop]]`
```

Alternatively, you can configure these options in your system environment. Prefix the above option names with `LOGFLARE_`.

```bash
export LOGFLARE_URL="https://api.logflare.app"
export LOGFLARE_API_KEY="..."
export LOGFLARE_SOURCE_ID="..."
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

- atoms converted to strings
- charlists are converted to strings
- tuples converted to arrays
- keyword lists converted to maps
- structs converted to maps
- NaiveDateTime and DateTime are converted using the `String.Chars` protocol
- pids are converted to strings

LogflareLogger doesn't support:

- non-binary messages, e.g. `Logger.info(%{user_count: 1337})`

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
    {:logflare_logger_backend, "~> 0.11.4"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/logflare_logger_backend](https://hexdocs.pm/logflare_logger_backend).
