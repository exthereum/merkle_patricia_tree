defmodule MerklePatriciaTree.DB.RocksDB do
  @moduledoc """
  Implementation of MerklePatriciaTree.DB which
  is backed by rocksdb.
  """

  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.DB

  require Logger

  @behaviour MerklePatriciaTree.DB

  @doc """
  Performs initialization for this db.
  """
  @spec init(DB.db_name()) :: DB.db()
  def init(db_name) do
    db_name = String.to_charlist(db_name)
    db_options = [create_if_missing: true]

    case :rocksdb.open_with_cf(db_name, db_options, [{'default', []}]) do
      {:ok, db_ref, [default]} ->
        {__MODULE__, {db_ref, default}}

      {:error, error} ->
        Logger.error("Cannot open database. Error is: #{inspect(error)}")
        raise "Failed to open database"
    end
  end

  @spec init_with_cf(DB.db_name(), [atom()]) :: [DB.db()]
  def init_with_cf(db_name, cf_names) do
    cf_params =
      Enum.map(cf_names, fn name ->
        {Atom.to_charlist(name), []}
      end)

    db_name = String.to_charlist(db_name)
    db_options = [create_if_missing: true, create_missing_column_families: true]

    case :rocksdb.open_with_cf(db_name, db_options, cf_params) do
      {:ok, db_ref, cf_refs} ->
        Enum.map(cf_refs, fn cf_ref -> {__MODULE__, {db_ref, cf_ref}} end)

      {:error, error} ->
        Logger.error("Cannot open database. Error is: #{inspect(error)}")
        raise "Failed to open database"
    end
  end

  @doc """
  Close the database.
  """
  @spec close(DB.db_ref()) :: :ok
  def close({db, _}), do: :rocksdb.close(db)

  @doc """
  Retrieves a key from the database.
  """
  @spec get(DB.db_ref(), Trie.key()) :: {:ok, DB.value()} | :not_found
  def get({db, cf_ref}, key) do
    case :rocksdb.get(db, cf_ref, key, []) do
      {:ok, v} ->
        {:ok, v}

      :not_found ->
        :not_found

      error ->
        Logger.warn("Error on get: #{inspect(error)}")
        :not_found
    end
  end

  @doc """
  Stores a key in the database.
  """
  @spec put!(DB.db_ref(), Trie.key(), DB.value()) :: :ok
  def put!({db, cf_ref}, key, value) do
    case :rocksdb.put(db, cf_ref, key, value, []) do
      :ok -> :ok
    end
  end
end
