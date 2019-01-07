defmodule MerklePatriciaTree.DB.RocksDBTest do
  use ExUnit.Case, async: false
  alias MerklePatriciaTree.DB
  alias MerklePatriciaTree.DB.RocksDB

  test "init creates an rocks table" do
    db_name = "/tmp/db#{MerklePatriciaTree.Test.random_string(20)}"

    {_, db_ref} = RocksDB.init(db_name, [:default])
    RocksDB.close(db_ref)
    {:ok, _db} = :rocksdb.open(String.to_charlist(db_name), create_if_missing: false)
  end

  test "get/1" do
    {_, db_ref} = RocksDB.init("/tmp/db#{MerklePatriciaTree.Test.random_string(20)}", [:default])

    RocksDB.put!(db_ref, :default, "key", "value")
    assert RocksDB.get(db_ref, :default, "key") == {:ok, "value"}
    assert RocksDB.get(db_ref, :default, "key2") == :not_found
  end

  test "get!/1" do
    db =
      {_, db_ref} =
      RocksDB.init("/tmp/db#{MerklePatriciaTree.Test.random_string(20)}", [:default])

    RocksDB.put!(db_ref, :default, "key", "value")
    assert DB.get!(db, "key") == "value"

    assert_raise MerklePatriciaTree.DB.KeyNotFoundError, "cannot find key `key2`", fn ->
      DB.get!(db, "key2")
    end
  end

  test "put!/2" do
    {_, db_ref} = RocksDB.init("/tmp/db#{MerklePatriciaTree.Test.random_string(20)}", [:default])

    assert RocksDB.put!(db_ref, :default, "key", "value") == :ok
    assert RocksDB.get(db_ref, :default, "key") == {:ok, "value"}
  end

  test "simple init, put, get" do
    db =
      {_, db_ref} =
      RocksDB.init("/tmp/db#{MerklePatriciaTree.Test.random_string(20)}", [:default])

    assert RocksDB.put!(db_ref, :default, "name", "bob") == :ok
    assert DB.get!(db, "name") == "bob"
    assert RocksDB.get(db_ref, :default, "age") == :not_found
  end
end
