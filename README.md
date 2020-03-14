# Throttlex
> ### Throttle/Circuit Breaker Utilities

## Installation

The package can be installed by adding `throttlex` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [
    {:throttlex, github: "safeboda/throttlex"}
  ]
end
```

## Running Tests

To run the tests:

```
$ mix test
```

Running tests with coverage:

```
$ mix coveralls.html
```

And you can check out the coverage result in `cover/excoveralls.html`.

## Contributing

Before to submit a PR it is highly recommended to run:

 * `mix test` to run tests.

 * `mix coveralls.html && open cover/excoveralls.html` to run tests and
   check out code coverage (expected 100%).

 * `mix format && mix credo --strict` to format your code properly and find
   code style issues.

 * `mix dialyzer` to run dialyzer for type checking; might take a while on the
   first invocation.

## License

Copyright (c) 2020 SafeBoda

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
