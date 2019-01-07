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
  @type db_ref :: {any(), map()}
  @type cf_ref :: any()
  @type db :: {t, db_ref}
  @type value :: binary()

  @callback init(db_name, [atom()]) :: db

  # use custom cf
  @callback get(db_ref, atom(), MerklePatriciaTree.Trie.key()) :: {:ok, value} | :not_found
  @callback put!(db_ref, atom(), MerklePatriciaTree.Trie.key(), value) :: :ok

  @doc """
  Retrieves a key from the database. Using default column family.
  """
  @spec get(db, MerklePatriciaTree.Trie.key()) :: {:ok, value} | :not_found
  def get(db, key), do: get(db, :default, key)

  @doc """
  Retrieves a key from the database, but raises if that key does not exist. Using default column family.
  """
  @spec get(db, MerklePatriciaTree.Trie.key()) :: {:ok, value} | :not_found
  def get!(db, key), do: get!(db, :default, key)

  @doc """
  Retrieves a key from the database.
  """
  @spec get(db, atom(), MerklePatriciaTree.Trie.key()) :: {:ok, value} | :not_found
  def get(_db = {db_mod, db_ref}, cf_name, key) do
    db_mod.get(db_ref, cf_name, key)
  end

  @doc """
  Retrieves a key from the database, but raises if that key does not exist.

  """
  @spec get!(db, atom(), MerklePatriciaTree.Trie.key()) :: value
  def get!(db, cf_name, key) do
    case get(db, cf_name, key) do
      {:ok, value} -> value
      :not_found -> raise KeyNotFoundError, message: "cannot find key `#{key}`"
    end
  end

  @doc """
  Stores a key in the database. Use default column family.
  """
  @spec put!(db, MerklePatriciaTree.Trie.key(), value) :: :ok
  def put!(db, key, value), do: put!(db, :default, key, value)

  @doc """
  Stores a key in the database.
  """
  @spec put!(db, atom(), MerklePatriciaTree.Trie.key(), value) :: :ok
  def put!(_db = {db_mod, db_ref}, cf_name, key, value) do
    db_mod.put!(db_ref, cf_name, key, value)
  end
end
