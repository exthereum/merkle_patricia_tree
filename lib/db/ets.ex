defmodule MerklePatriciaTree.DB.ETS do
  @moduledoc """
  Implementation of `MerklePatriciaTree.DB` which
  is backed by :ets.
  """

  alias MerklePatriciaTree.DB
  alias MerklePatriciaTree.Trie

  @behaviour MerklePatriciaTree.DB

  @doc """
  Performs initialization for this db.
  """
  @spec init(DB.db_name(), [atom()]) :: DB.db()
  def init(db_name, _cf_names) do
    :ets.new(db_name, [:set, :public, :named_table])

    {__MODULE__, {db_name, %{}}}
  end

  @doc """
  Retrieves a key from the database.
  """
  @spec get(DB.db_ref(), atom(), Trie.key()) :: {:ok, DB.value()} | :not_found
  def get({db, _}, _cf_name, key) do
    case :ets.lookup(db, key) do
      [{^key, v} | _rest] -> {:ok, v}
      _ -> :not_found
    end
  end

  @doc """
  Stores a key in the database.
  """
  @spec put!(DB.db_ref(), atom(), Trie.key(), DB.value()) :: :ok
  def put!({db, _}, _cf_name, key, value) do
    case :ets.insert(db, {key, value}) do
      true -> :ok
    end
  end
end
