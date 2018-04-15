defmodule MerklePatriciaTree.Trie do
  @moduledoc File.read!("#{__DIR__}/../README.md")

  alias MerklePatriciaTree.Trie.Helper
  alias MerklePatriciaTree.Trie.Builder
  alias MerklePatriciaTree.Trie.Destroyer
  alias MerklePatriciaTree.Trie.Inspector
  alias MerklePatriciaTree.Trie.Node
  alias MerklePatriciaTree.DB
  alias MerklePatriciaTree.ListHelper

  defstruct [db: nil, root_hash: nil]

  @type root_hash :: binary()

  @type t :: %__MODULE__{
    db: DB.db,
    root_hash: root_hash
  }

  @type key :: binary()

  @empty_trie <<>>
  @empty_trie_root_hash @empty_trie |> ExRLP.encode |> :keccakf1600.sha3_256

  @doc """
  Returns the canonical empty trie.

  Note: this root hash will not be accessible unless you have stored
  the result in a db. If you are initializing a new trie, instead of
  checking a result is empty, it's strongly recommended you use

  """
  @spec empty_trie_root_hash() :: root_hash
  def empty_trie_root_hash(), do: @empty_trie_root_hash

  @doc """
  Contructs a new unitialized trie.

  """
  @spec new(DB.db, root_hash) :: __MODULE__.t
  def new(db={_, _}, root_hash \\ @empty_trie) do
    %__MODULE__{db: db, root_hash: root_hash} |> store
  end

  @doc """
  Moves trie down to be rooted at `next_node`,
  this is effectively (and literally) just changing
  the root_hash to `node_hash`.
  """
  def into(next_node, trie) do
    %{trie| root_hash: next_node}
  end

  def get_next_node(next_node, trie), do: into(next_node, trie)

  @doc """
  Given a trie, returns the value associated with key.
  """
  @spec get(__MODULE__.t, __MODULE__.key) :: binary() | nil
  def get(trie, key) do
    do_get(trie, Helper.get_nibbles(key))
  end

  @spec do_get(__MODULE__.t | nil, [integer()]) :: binary() | nil
  defp do_get(nil, _), do: nil
  defp do_get(trie, nibbles=[nibble| rest]) do
    # Let's decode `c(I, i)`

    case Node.decode_trie(trie) do
      :empty -> nil # no node, bail
      {:branch, branches} ->
        # branch node
        case Enum.at(branches, nibble) do
          [] -> nil
          node_hash -> node_hash |> into(trie) |> do_get(rest)
        end
      {:leaf, prefix, value} ->
        # leaf, value is second value if match first
        case nibbles do
          ^prefix -> value
          _ -> nil
        end
      {:ext, shared_prefix, next_node} ->
        # extension, continue walking tree if we match
        case ListHelper.get_postfix(nibbles, shared_prefix) do
          nil -> nil # did not match extension node
          rest -> next_node |> into(trie) |> do_get(rest)
        end
    end
  end

  defp do_get(trie, []) do
    # Only branch nodes can have values for a nil lookup
    case Node.decode_trie(trie) do
      {:branch, branches} -> List.last(branches)
      {:leaf, [], v} -> v
      _ -> nil
    end
  end

  @doc """
  Removing a value for a given key and reorganize the
  trie structure.
  """
  @spec delete(__MODULE__.t, __MODULE__.key) :: __MODULE__.t
  def delete(trie, key) do
    Node.decode_trie(trie)
    |> Destroyer.remove_key(Helper.get_nibbles(key), trie)
    |> Node.encode_node(trie)
    |> into(trie)
    |> store
  end

  @doc """
  Updates a trie by setting key equal to value.
  """
  def update(trie, key, value) do
    # We're going to recursively walk toward our key,
    # then we'll add our value (either a new leaf or the value
    # on a branch node), then we'll walk back up the tree and
    # update all previous nodes. This may require changing the
    # type of the node.
    Node.decode_trie(trie)
    |> Builder.put_key(Helper.get_nibbles(key), value, trie)
    |> Node.encode_node(trie)
    |> into(trie)
    |> store
  end

  def store(trie) do
    root_hash = if not is_binary(trie.root_hash) or trie.root_hash == <<>>, do: ExRLP.encode(trie.root_hash), else: trie.root_hash

    if byte_size(root_hash) < MerklePatriciaTree.Trie.Storage.max_rlp_len do
      %{trie | root_hash: root_hash |> MerklePatriciaTree.Trie.Storage.store(trie.db)}
    else
      trie
    end
  end

end
