defmodule MerklePatriciaTreeProofTest do
  use ExUnit.Case

  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.DB.LevelDB
  alias MerklePatriciaTree.Proof

  @tag :proof_test_success
  @tag timeout: 30_000_000
  test "Proof Success Tests" do
    {trie, list} = create_random_trie_test()

    Enum.each(list, fn({key, value}) ->
      proof_trie = Trie.new(LevelDB.init("/tmp/patricia_proof_trie"))
      {^value, proof} =
        Proof.construct_proof({trie, key, proof_trie})

      assert :true = Proof.verify_proof(key, value, trie.root_hash, proof.db)

      {_, proof_ref} = proof.db
      assert :ok = Exleveldb.close(proof_ref)
    end)

    {_, db_ref} = trie.db
    :ok = Exleveldb.close(db_ref)
  end

  def create_random_trie_test() do
    db_ref = Trie.new(LevelDB.init("/tmp/patricia_test_trie"))
    list = get_random_tree_list()

    trie =
      Enum.reduce(list, db_ref,
        fn({key, val}, acc_trie) ->
          Trie.update(acc_trie, key, val)
        end)
    {trie, list}
  end

  def get_random_tree_list() do
    for _ <- 0..1_000, do: {random_key(), random_value(12)}
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

  defp random_value(len), do: MerklePatriciaTree.Test.random_string(len)

end
