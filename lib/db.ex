defmodule MerklePatriciaTree.DB do
  @moduledoc """
  Defines a general key-value storage to back and persist
  out Merkle Patricia Trie. This is generally LevelDB in the
  community, but for testing, we'll generally use `:ets`.

  We define a callback that can be implemented by a number
  of potential backends.
  """
  defmodule KeyNotFoundError do
    defexception [:message]
  end

  @type t :: module()
  @type db_name :: any()
  @type db_ref :: {any(), any()}
  @type cf_ref :: any()
  @type db :: {t, db_ref}
  @type value :: binary()

  @callback init(db_name) :: db

  @callback get(db_ref, MerklePatriciaTree.Trie.key()) :: {:ok, value} | :not_found
  @callback put!(db_ref, MerklePatriciaTree.Trie.key(), value) :: :ok

  @doc """
  Retrieves a key from the database.
  """
  @spec get(db, MerklePatriciaTree.Trie.key()) :: {:ok, value} | :not_found
  def get(_db = {db_mod, db_ref}, key) do
    db_mod.get(db_ref, key)
  end

  @doc """
  Retrieves a key from the database, but raises if that key does not exist.

  """
  @spec get!(db, MerklePatriciaTree.Trie.key()) :: value
  def get!(db, key) do
    case get(db, key) do
      {:ok, value} -> value
      :not_found -> raise KeyNotFoundError, message: "cannot find key `#{key}`"
    end
  end

  @doc """
  Stores a key in the database.
  """
  @spec put!(db, MerklePatriciaTree.Trie.key(), value) :: :ok
  def put!(_db = {db_mod, db_ref}, key, value), do: db_mod.put!(db_ref, key, value)
end
