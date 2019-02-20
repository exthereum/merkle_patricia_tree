defmodule MerklePatriciaTree.DB.ETSTest do
  use ExUnit.Case, async: false
  alias MerklePatriciaTree.DB
  alias MerklePatriciaTree.DB.ETS

  test "init creates an ets table" do
    {_, {edb, _}} = ETS.init(MerklePatriciaTree.Test.random_atom(20))

    :ets.insert(edb, {"key", "value"})
    assert :ets.lookup(edb, "key") == [{"key", "value"}]
  end

  test "get/1" do
    {_, {edb, _} = db_ref} = ETS.init(MerklePatriciaTree.Test.random_atom(20))

    :ets.insert(edb, {"key", "value"})
    assert ETS.get(db_ref, "key") == {:ok, "value"}
    assert ETS.get(db_ref, "key2") == :not_found
  end

  test "get!/1" do
    db = {_, {edb, _} = _db_ref} = ETS.init(MerklePatriciaTree.Test.random_atom(20))

    :ets.insert(edb, {"key", "value"})
    assert DB.get!(db, "key") == "value"

    assert_raise MerklePatriciaTree.DB.KeyNotFoundError, "cannot find key `key2`", fn ->
      DB.get!(db, "key2")
    end
  end

  test "put!/2" do
    {_, {edb, _} = db_ref} = ETS.init(MerklePatriciaTree.Test.random_atom(20))

    assert ETS.put!(db_ref, "key", "value") == :ok
    assert :ets.lookup(edb, "key") == [{"key", "value"}]
  end
end
