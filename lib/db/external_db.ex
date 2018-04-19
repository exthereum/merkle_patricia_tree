defmodule MerklePatriciaTree.DB.ExternalDB do
  @moduledoc """
  Implementation of `MerklePatriciaTree.DB` which
  is backed by external db.
  """

  alias MerklePatriciaTree.DB
  alias MerklePatriciaTree.Trie

  @behaviour MerklePatriciaTree.DB
  @typedoc """
  The map contains must contain the `put` and `get` handlers.
  Those hanlders must call the module and the functions that
  are responsible for `put` and `get`. They are handling the
  db_ref as well.
  """
  @type db_handler :: %{put: function(), get: function()}
  @doc """
  Takes function that will handle the db operations
  """
  @spec init(db_handler) :: db_handler()
  def init(db_handler) when is_map(db_handler), do: {__MODULE__, db_handler}

  @doc """
  Retrieves a key from the external database.
  """
  @spec get(db_handler(), Trie.key()) :: {:ok, DB.value()} | :not_found
  def get(%{get: db_handler}, key) do
    case db_handler.(key) do
      {:ok, _v} = result -> result
      _ -> :not_found
    end
  end

  @doc """
  Stores a key in the external database.
  """
  @spec put!(db_handler(), Trie.key(), DB.value()) :: :ok
  def put!(%{put: db_handler}, key, value) do
    :ok = db_handler.(key, value)
  end
end
