defmodule MerklePatriciaTreeProofTest do
  use ExUnit.Case

  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.Test
  alias MerklePatriciaTree.DB.LevelDB

  def create_test_trie_test() do

    list = get_tree_list()
    trie =
      Enum.reduce(list, Trie.new(LevelDB.init("tmp/#{MerklePatriciaTree.Test.random_string(10)}")),
        fn({key, val}, acc_trie) ->
          Trie.update(acc_trie, key, val)
        end)
    {trie, list}
  end

  def get_tree_list() do
    for _ <- 0..100, do: {random_key(), "0000"}
  end

  def random_key() do

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

  @tag :proof_test_success
  @tag timeout: 30_000_000
  test "Proof Success Tests" do
    {trie, list} = create_test_trie_test()

    Enum.all?(list, fn({key, value}) ->
      {val, proof} = MerklePatriciaTree.Proof.construct_proof(trie, key)
      assert val == value
      assert :true = MerklePatriciaTree.Proof.verify_proof(key, val, trie.root_hash, proof.db)

    end)
  end

end
