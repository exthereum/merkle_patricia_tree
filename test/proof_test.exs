defmodule MerklePatriciaTreeProofTest do
  use ExUnit.Case

  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.DB.LevelDB
  alias MerklePatriciaTree.DB
  alias MerklePatriciaTree.Proof
  alias MerklePatriciaTree.Utils
  alias MerklePatriciaTree.Trie.Helper

  @tag :proof_test_success
  @tag timeout: 30_000_000
  test "Proof Success Tests" do
    {trie, list} = create_random_trie_test()

    Enum.each(list, fn {key, value} ->
      proof_trie = Trie.new(LevelDB.init("/tmp/patricia_proof_trie"))
      {^value, proof} = Proof.construct_proof({trie, key, proof_trie})

      assert :ok === Proof.verify_proof(key, value, trie.root_hash, proof)

      {_, proof_ref} = proof.db
      assert :ok = Exleveldb.close(proof_ref)
    end)

    {_, db_ref} = trie.db
    :ok = Exleveldb.close(db_ref)
  end

  @tag timeout: 30_000_000
  test "Verification with empty DB fails" do
    {trie, list} = create_random_trie_test()
    proof = Trie.new(LevelDB.init("/tmp/patricia_proof_trie_empty"))

    Enum.each(list, fn {key, value} ->
      assert {:error, _} = Proof.verify_proof(key, value, trie.root_hash, proof)
    end)

    {_, proof_ref} = proof.db
    :ok = Exleveldb.close(proof_ref)

    {_, db_ref} = trie.db
    :ok = Exleveldb.close(db_ref)
  end

  @tag timeout: 30_000_000
  test "Verification with malformed DB fails" do
    {trie, list} = create_random_trie_test()

    Enum.each(list, fn {key, value} ->
      proof_trie = Trie.new(LevelDB.init("/tmp/patricia_proof_trie_malformed"))
      {^value, proof} = Proof.construct_proof({trie, key, proof_trie})

      DB.put!(proof.db, trie.root_hash, <<1, 2, 3, 4, 5, 6, 7, 8>>)

      assert {:error, _} = Proof.verify_proof(key, value, trie.root_hash, proof)

      {_, proof_ref} = proof.db
      :ok = Exleveldb.close(proof_ref)
    end)

    {_, db_ref} = trie.db
    :ok = Exleveldb.close(db_ref)
  end

  @tag timeout: 30_000_000
  test "Check whether we actually check the hashes ;)" do
    {trie, _} = create_random_trie_test()

    bogus_key = <<0x1E, 0x2F>>
    bogus_val = <<1, 2, 3, 4>>

    bogus_proof = Trie.new(LevelDB.init("/tmp/patricia_proof_trie_bogus"))

    DB.put!(
      bogus_proof.db,
      trie.root_hash,
      ExRLP.encode([
        HexPrefix.encode({Helper.get_nibbles(bogus_key), true}),
        bogus_val
      ])
    )

    assert {:error, _} = Proof.verify_proof(bogus_key, bogus_val, trie.root_hash, bogus_proof)

    {_, proof_ref} = bogus_proof.db
    :ok = Exleveldb.close(proof_ref)

    {_, db_ref} = trie.db
    :ok = Exleveldb.close(db_ref)
  end

  @tag timeout: 30_000_000
  test "Test proof lookups" do
    {trie, list} = create_random_trie_test()

    Enum.each(list, fn {key, value} ->
      proof_trie = Trie.new(LevelDB.init("/tmp/patricia_proof_trie_lookups"))
      {^value, proof} = Proof.construct_proof({trie, key, proof_trie})

      # try to lookup an existing key
      ^value = Proof.lookup_proof(key, trie.root_hash, proof)
      # try to lookup an non existient key
      {:error, _} = Proof.lookup_proof(<<0x1E, 0x2F>>, trie.root_hash, proof)

      {_, proof_ref} = proof.db
      :ok = Exleveldb.close(proof_ref)
    end)

    {_, db_ref} = trie.db
    :ok = Exleveldb.close(db_ref)
  end

  @tag timeout: 30_000_000
  test "Test lookups for proofs with multiple entries" do
    {trie, list} = create_random_trie_test()

    proof_trie = Trie.new(LevelDB.init("/tmp/patricia_proof_trie_lookups_with_multiple_entries"))

    Enum.each(list, fn {key, value} ->
      {^value, _} = Proof.construct_proof({trie, key, proof_trie})
      # try to lookup an existing key
      ^value = Proof.lookup_proof(key, trie.root_hash, proof_trie)
      # try to lookup an non existient key
      {:error, _} = Proof.lookup_proof(<<0x1E, 0x2F>>, trie.root_hash, proof_trie)
    end)

    # try to lookup every key
    Enum.each(list, fn {key, value} ->
      ^value = Proof.lookup_proof(key, trie.root_hash, proof_trie)
    end)

    {_, proof_ref} = proof_trie.db
    :ok = Exleveldb.close(proof_ref)

    {_, db_ref} = trie.db
    :ok = Exleveldb.close(db_ref)
  end

  def create_random_trie_test() do
    db_ref = Trie.new(LevelDB.init("/tmp/patricia_test_trie"))
    list = get_random_tree_list()

    trie =
      Enum.reduce(list, db_ref, fn {key, val}, acc_trie ->
        Trie.update(acc_trie, key, val)
      end)

    {trie, list}
  end

  def get_random_tree_list() do
    for _ <- 0..1_000, do: {random_key(), random_value(40)}
  end

  def random_key() do
    <<:rand.uniform(15)::4, :rand.uniform(15)::4, :rand.uniform(15)::4, :rand.uniform(15)::4,
      :rand.uniform(15)::4, :rand.uniform(15)::4, :rand.uniform(15)::4, :rand.uniform(15)::4,
      :rand.uniform(15)::4, :rand.uniform(15)::4, :rand.uniform(15)::4, :rand.uniform(15)::4,
      :rand.uniform(15)::4, :rand.uniform(15)::4, :rand.uniform(15)::4, :rand.uniform(15)::4,
      :rand.uniform(15)::4, :rand.uniform(15)::4>>
  end

  defp random_value(len), do: Utils.random_string(len)
end
