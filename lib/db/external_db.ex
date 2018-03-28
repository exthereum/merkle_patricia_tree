defmodule MerklePatriciaTree.DB.ExternalDB do
  @moduledoc """
  Implementation of `MerklePatriciaTree.DB` which
  is backed by external db.
  """

  alias MerklePatriciaTree.DB
  alias MerklePatriciaTree.Trie

  @behaviour MerklePatriciaTree.DB

  @type db_handler :: function()

  @doc """
  Takes function that will handle the db operations
  """
  @spec init(db_handler) :: db_handler()
  def init(db_handler) when is_function(db_handler) do
    {__MODULE__, db_handler}
  end

  @doc """
  Retrieves a key from the external database.
  """
  @spec get(db_handler(), Trie.key) :: {:ok, DB.value} | :not_found
  def get(db_handler, key) do
    case db_handler.(key) do
      {:ok, v} = result -> result
      _ -> :not_found
    end
  end

  @doc """
  Stores a key in the external database.
  """
  @spec put!(db_handler(), Trie.key, DB.value) :: :ok
  def put!(db_handler, key, value) do
    :ok = db_handler.(key, value)
  end
end
