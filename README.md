# Examine

*Inspect All The Things*

Examine adds contextual information around `IO.inspect` and enables easy inspection of pipelines.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `examine` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:examine, "~> 0.1.0"}
  ]
end
```

## Example

```elixir
list = [1, 2, 3]

list
|> Enum.map(&{&1, to_string(&1 * &1)})
|> Enum.into(%{})
|> Dbg.inspect(show_vars: true)
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/examine](https://hexdocs.pm/examine).

