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
  @spec init(DB.db_name(), [atom()]) :: DB.db()
  def init(db_name, cf_names) do
    cf_params =
      Enum.map(cf_names, fn name ->
        {Atom.to_charlist(name), []}
      end)

    db_name = String.to_charlist(db_name)

    case :rocksdb.open_with_cf(db_name, [create_if_missing: true], cf_params) do
      {:ok, db_ref, cf_refs} ->
        cf_list = cf_names |> Enum.zip(cf_refs) |> Enum.into(%{})

        {__MODULE__, {db_ref, cf_list}}

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
  @spec get(DB.db_ref(), atom(), Trie.key()) :: {:ok, DB.value()} | :not_found
  def get({db, cf_list}, cf_name, key) do
    cf_ref = Map.get(cf_list, cf_name)

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
  @spec put!(DB.db_ref(), atom(), Trie.key(), DB.value()) :: :ok
  def put!({db, cf_list}, cf_name, key, value) do
    cf_ref = Map.get(cf_list, cf_name)

    case :rocksdb.put(db, cf_ref, key, value, []) do
      :ok -> :ok
    end
  end
end
