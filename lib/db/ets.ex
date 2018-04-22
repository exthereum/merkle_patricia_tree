defmodule MerklePatriciaTree.DB.ETS do
  @moduledoc """
  Implementation of `MerklePatriciaTree.DB` which
  is backed by :ets.
  """

  alias MerklePatriciaTree.DB
  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.Utils

  @behaviour MerklePatriciaTree.DB

  @doc """
  Performs initialization for this db.
  """
  @spec init(DB.db_name()) :: DB.db()
  def init(db_name) do
    :ets.new(db_name, [:set, :public, :named_table])

    {__MODULE__, db_name}
  end

  @doc """
  Retrieves a key from the database.
  """
  @spec get(DB.db_ref(), Trie.key()) :: {:ok, DB.value()} | :not_found
  def get(db_ref, key) do
    case :ets.lookup(db_ref, key) do
      [{^key, v} | _rest] -> {:ok, v}
      _ -> :not_found
    end
  end

  @doc """
  Stores a key in the database.
  """
  @spec put!(DB.db_ref(), Trie.key(), DB.value()) :: :ok
  def put!(db_ref, key, value) do
    case :ets.insert(db_ref, {key, value}) do
      true -> :ok
    end
  end

  @doc """
  Returns a random :ets database suitable for testing

  ## Examples

      iex> {MerklePatriciaTree.DB.ETS, db_ref} = random_ets_db()
      iex> :ets.info(db_ref)[:type]
      :set

      iex> {MerklePatriciaTree.DB.ETS, db_ref} = random_ets_db(:test1)
      iex> :ets.info(db_ref)[:name]
      :test1
  """
  def random_ets_db(name \\ nil) do
    init(name || Utils.random_atom(20))
  end
end
