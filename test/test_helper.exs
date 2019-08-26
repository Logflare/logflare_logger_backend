ExUnit.start()
ExUnit.configure(exclude: [integration: true])

Application.ensure_all_started(:bypass)
