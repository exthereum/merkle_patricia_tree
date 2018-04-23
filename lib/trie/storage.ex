defmodule MerklePatriciaTree.Trie.Storage do
  @moduledoc """
  Module to get and put nodes in a trie by the given
  storage mechanism. Generally, handles the function `n(I, i)`,
  Eq.(178) from the Yellow Paper.
  """

  alias MerklePatriciaTree.DB
  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.Utils

  @max_rlp_len 32

  @spec max_rlp_len() :: integer()
  def max_rlp_len(), do: @max_rlp_len

  @doc """
  Takes an RLP-encoded node and pushes it to storage,
  as defined by `n(I, i)` Eq.(178) of the Yellow Paper.

  NOTA BENE: we are forced to deviate from the Yellow Paper as nodes which are
  smaller than 32 bytes aren't encoded in RLP, as suggested by the equations.

  Specifically, Eq.(178) says that the node is encoded as `c(J,i)` in the second
  portion of the definition of `n`. By the definition of `c`, all return values are
  RLP encoded. But, we have found emperically that the `n` does not encode values to
  RLP for smaller nodes.

  ## Examples

      iex> trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.DB.ETS.random_ets_db())
      iex> MerklePatriciaTree.Trie.Storage.put_node(<<>>, trie)
      <<128>>
      iex> MerklePatriciaTree.Trie.Storage.put_node("Hi", trie) |> ExRLP.decode()
      "Hi"
      iex> MerklePatriciaTree.Trie.Storage.put_node(["AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"], trie)
      <<58, 104, 97, 241, 160, 195, 142, 243, 97, 153, 240, 89, 91, 165, 173, 193, 32,
      181, 139, 138, 221, 238, 154, 172, 74, 44, 181, 67, 136, 21, 10, 205>>
  """
  @spec put_node(ExRLP.t(), Trie.t()) :: binary()
  def put_node(rlp, trie) do
    case ExRLP.encode(rlp) do
      # store large nodes
      encoded when byte_size(encoded) >= @max_rlp_len ->
        store(encoded, trie.db)

      encoded ->
        encoded
    end
  end

  @doc """
  TODO: Doc and test
  """
  @spec store(ExRLP.t(), MerklePatriciaTree.DB.db()) :: binary()
  def store(rlp_encoded_node, db) do
    hash = Utils.hash(rlp_encoded_node)
    DB.put!(db, hash, rlp_encoded_node)
    hash
  end

  @doc """
  Gets the RLP encoded value of a given trie root. Specifically,
  we invert the function `n(I, i)` Eq.(178) from the Yellow Paper.

  ## Examples

    iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.DB.ETS.random_ets_db(), <<>>)
    ...> |> MerklePatriciaTree.Trie.Storage.get_node()
    <<>>

    iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.DB.ETS.random_ets_db(), <<130, 72, 105>>)
    ...> |> MerklePatriciaTree.Trie.Storage.get_node()
    "Hi"

    iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.DB.ETS.random_ets_db(), <<254, 112, 17, 90, 21, 82, 19, 29, 72, 106, 175, 110, 87, 220, 249, 140, 74, 165, 64, 94, 174, 79, 78, 189, 145, 143, 92, 53, 173, 136, 220, 145>>)
    ...> |> MerklePatriciaTree.Trie.Storage.get_node()
    :not_found


    iex> trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.DB.ETS.random_ets_db(), <<130, 72, 105>>)
    iex> MerklePatriciaTree.Trie.Storage.put_node(["AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"], trie)
    <<58, 104, 97, 241, 160, 195, 142, 243, 97, 153, 240, 89, 91, 165, 173, 193, 32, 181, 139, 138, 221, 238, 154, 172, 74, 44, 181, 67, 136, 21, 10, 205>>
    iex> MerklePatriciaTree.Trie.Storage.get_node(%{trie| root_hash: <<58, 104, 97, 241, 160, 195, 142, 243, 97, 153, 240, 89, 91, 165, 173, 193, 32, 181, 139, 138, 221, 238, 154, 172, 74, 44, 181, 67, 136, 21, 10, 205>>})
    ["AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"]
  """
  @spec get_node(Trie.t()) :: ExRLP.t() | :not_found
  def get_node(trie) do
    case trie.root_hash do
      <<>> ->
        <<>>

      # node was stored directly
      x when not is_binary(x) ->
        x

      h ->
        # stored in db
        case DB.get(trie.db, h) do
          {:ok, v} -> ExRLP.decode(v)
          :not_found -> :not_found
        end
    end
  end
end
