defmodule MerklePatriciaTree.TrieTest do
  use ExUnit.Case, async: true
  #doctest MerklePatriciaTree.Trie

  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.Trie.Verifier
  alias MerklePatriciaTree.Test

  @max_32_bits 4294967296

  setup do
    db = Test.random_ets_db()
    {:ok, %{db: db}}
  end

  @tag timeout: 100_000_000
  test "Read from random trie", %{db: db} do
    empty_trie = Trie.new(db)

    trie_list = get_random_tree_list(5)
    trie = create_trie(trie_list, empty_trie)

    Enum.each(trie_list, fn {key, value} ->
      ^value = Trie.get(trie, key)
    end)
  end

  @tag timeout: 100_000_000
  test "Simple node from trie", %{db: db} do
    trie =
      Trie.new(db)
      |> Trie.update(<<15::4, 10::4, 5::4, 11::4, 5::4, 1::4>>, "a")
      |> Trie.update(<<15::4, 11::4, 1::4, 14::4, 9::4, 7::4>>, "b")
      |> Trie.update(<<6::4, 1::4, 10::4, 10::4, 5::4, 7::4>>, "c")
      |> Trie.update(<<6::4, 1::4, 11::4, 10::4, 5::4, 7::4>>, "c")

    assert Trie.get(trie, <<15::4, 11::4, 1::4, 14::4, 9::4, 7::4>>) == "b"

    trie = Trie.delete(trie, <<15::4, 11::4, 1::4, 14::4, 9::4, 7::4>>)
    assert Trie.get(trie, <<15::4, 11::4, 1::4, 14::4, 9::4, 7::4>>) == nil

  end

  @tag timeout: 100_000_000
  test "Delete random nodes from random trie" do
    %{db: {_, db_ref1}} = init_trie1 = Trie.new(Test.random_ets_db)
    %{db: {_, db_ref2}} = init_trie2 = Trie.new(Test.random_ets_db)

    full_trie_list =
      Enum.uniq_by(get_random_tree_list(10_000), fn {x, _} -> x end)

      full_trie = Enum.reduce(full_trie_list, init_trie1,
      fn({key, val}, acc_trie) ->
          MerklePatriciaTree.Trie.update(acc_trie, key, val)
      end)

    ## Reducing the full list trie randomly and
    ## getting the removed keys as well.
    {keys, sub_trie_list} = reduce_trie(5_000, full_trie_list)

    constructed_trie =
      Enum.reduce(sub_trie_list, init_trie2,
        fn({key, val}, acc_trie) ->
          Trie.update(acc_trie, key, val)
        end)

    ## We are going to delete the previously reduced
    ## keys from the full trie. The result should be
    ## root hash equal to the constructed trie.
    reconstructed_trie =
      Enum.reduce(keys, full_trie,
        fn({key, _}, acc_trie) ->
          Trie.delete(acc_trie, key)
        end)

    assert true = :ets.delete(db_ref1)
    assert true = :ets.delete(db_ref2)
    assert constructed_trie.root_hash == reconstructed_trie.root_hash
  end

  @doc """
  Creates trie from trie list by entering each element
  """
  def create_trie(trie_list, empty_trie) do
    Enum.reduce(trie_list, empty_trie, fn {key, val}, acc_trie ->
      Trie.update(acc_trie, key, val)
    end)
  end

  def leaf_node(key_end, value) do
    [HexPrefix.encode({key_end, true}), value]
  end

  def store(node_value, db) do
    node_hash = :keccakf1600.sha3_256(node_value)
    MerklePatriciaTree.DB.put!(db, node_hash, node_value)

    node_hash
  end

  def extension_node(shared_nibbles, node_hash) do
    [HexPrefix.encode({shared_nibbles, false}), node_hash]
  end

  def branch_node(branches, value) when length(branches) == 16 do
    branches ++ [value]
  end

  def blanks(n) do
    for _ <- 1..n, do: []
  end

  def random_hex_key() do
    <<:rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4,
      :rand.uniform(15)::4>>
  end

  def random_value() do
    <<:rand.uniform(@max_32_bits)::32>>
  end

  def reduce_trie(num_nodes, list) do
    popup_random_from_trie(
      num_nodes,
      List.pop_at(list, Enum.random(0..length(list) - 2)),
      {[], []})
  end

  def popup_random_from_trie(0, _, acc), do: acc
  def popup_random_from_trie(num_nodes, {data, rest}, {keys, _}) do
    popup_random_from_trie(
      num_nodes - 1,
      List.pop_at(rest, Enum.random(0..length(rest) - 2)),
      {keys ++ [data], rest}
    )
  end

  def get_random_tree_list(size) do
    for _ <- 0..size, do: {random_hex_key(), random_value()}
  end

end
