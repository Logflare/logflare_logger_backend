ExUnit.configure(seed: 1337)
ExUnit.start()
ExUnit.configure(exclude: [integration: true])

Application.ensure_all_started(:bypass)
