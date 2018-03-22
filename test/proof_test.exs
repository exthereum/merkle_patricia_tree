defmodule MerklePatriciaTreeProof do
  use ExUnit.Case

  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.Test
  alias MerklePatriciaTree.Trie.Node5B
  alias MerklePatriciaTree.Trie.Helper

  def create_test_trie_test() do
    db = Test.random_ets_db(:test)

    Enum.reduce(get_tree_list(), Trie.new(db),
      fn({key, val}, acc_trie) ->
        Trie.update(acc_trie, key, val)
      end)

  end

  def get_tree_list() do
    [{<<0::4, 1::4, 1::4>>, <<"011">>},
     {<<0::4, 1::4, 0::4, 1::4, 0::4, 3::4>>, <<"113">>},
     {<<0::4, 1::4, 0::4, 1::4, 0::4, 2::4>>,  <<"112">>},
     {<<0::4, 1::4, 0::4, 1::4, 0::4, 2::4, 5::4, 7::4>>, <<"11257">>},
     {<<0::4, 1::4, 0::4, 1::4, 0::4, 2::4, 5::4, 7::4, 8::4, 0::4>>, <<"1125780">>}]
  end

  @tag :proof_test_1
  test "Proof Success Tests" do
    trie = create_test_trie_test

    Enum.all?(get_tree_list(), fn({key, val}) ->
      {val, proof} = MerklePatriciaTree.Proof.construct_proof(trie, key)
      res = if MerklePatriciaTree.Proof.verify_proof(key, val, trie.root_hash, proof.db) do
        true
      else
        false
      end

      assert :true = res
    end)
  end

end
