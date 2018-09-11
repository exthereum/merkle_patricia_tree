defmodule MerklePatriciaTreeTest do
  use ExUnit.Case

  alias MerklePatriciaTree.Trie

  @passing_tests %{
    anyorder: :all,
    test: :all
  }

  test "Ethereum Common Tests" do
    for {test_type, test_group} <- @passing_tests do
      for {test_name, test} <- read_test_file(test_type),
          test_group == :all or Enum.member?(test_group, String.to_atom(test_name)) do
        db = MerklePatriciaTree.DB.ETS.random_ets_db()
        test_in = test["in"]

        input =
          if is_map(test_in) do
            test_in
            |> Enum.into([])
            |> Enum.map(fn {a, b} -> [a, b] end)
            |> Enum.shuffle()
          else
            test_in
          end

        trie =
          Enum.reduce(input, Trie.new(db), fn [k, v], trie ->
            Trie.update(trie, k |> maybe_hex, v |> maybe_hex)
          end)

        assert trie.root_hash == test["root"] |> hex_to_binary
      end
    end
  end

  test "Updating test" do
    db = MerklePatriciaTree.DB.ETS.random_ets_db()
    trie1 = Trie.new(db)
    trie2 = Trie.new(db)
    trie1 = Trie.update(trie1, "key", "oldvalue")
    trie1 = Trie.update(trie1, "key_loner", "loner_key_value")
    trie1 = Trie.update(trie1, "key", "newvalue")
    trie2 = Trie.update(trie2, "key", "newvalue")
    trie2 = Trie.update(trie2, "key_loner", "loner_key_value")
    assert trie1.root_hash == trie2.root_hash
  end

  def read_test_file(type) do
    {:ok, body} = File.read(test_file_name(type))
    Poison.decode!(body)
  end

  def test_file_name(type) do
    "test/support/ethereum_common_tests/TrieTests/trie#{Atom.to_string(type)}.json"
  end

  def maybe_hex(hex_string = "0x" <> _str), do: hex_to_binary(hex_string)
  def maybe_hex(x), do: x

  def hex_to_binary(string) do
    string
    |> String.slice(2..-1)
    |> Base.decode16!(case: :mixed)
  end

  def hex_to_int(string) do
    string
    |> hex_to_binary()
    |> :binary.decode_unsigned()
  end
end
