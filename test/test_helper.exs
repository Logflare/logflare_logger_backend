ExUnit.configure(
  seed: 1337,
  exclude: [integration: true]
)

ExUnit.start()

Application.ensure_all_started(:bypass)
