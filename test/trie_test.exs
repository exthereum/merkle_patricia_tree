defmodule MerklePatriciaTree.TrieTest do
  use ExUnit.Case, async: true

  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.Utils
  alias MerklePatriciaTree.DB.ETS

  setup do
    {:ok, %{db: ETS.random_ets_db()}}
  end

  @tag timeout: 100_000_000
  test "Read from random trie", %{db: db} do
    trie_list = get_random_tree_list(1000)
    trie = create_trie(trie_list, Trie.new(db))

    Enum.each(trie_list, fn {key, value} ->
      assert ^value = Trie.get(trie, key)
    end)
  end

  @tag timeout: 100_000_000
  test "Delete a node from trie", %{db: db} do
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
    %{db: {_, db_ref1}} = init_trie1 = Trie.new(ETS.random_ets_db)
    %{db: {_, db_ref2}} = init_trie2 = Trie.new(ETS.random_ets_db)

    full_trie_list =
      Enum.uniq_by(get_random_tree_list(10_000), fn {x, _} -> x end)

    full_trie = Enum.reduce(full_trie_list, init_trie1,
      fn({key, val}, acc_trie) -> Trie.update(acc_trie, key, val) end)

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

  def random_value(), do: Utils.random_string(40)

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
