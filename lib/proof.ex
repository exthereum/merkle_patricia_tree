defmodule MerklePatriciaTree.Proof do
  require Integer

  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.Trie.Helper
  alias MerklePatriciaTree.ListHelper
  alias MerklePatriciaTree.DB
  alias MerklePatriciaTree.Utils

  @type decoded_node() :: :empty | {atom(), list()}
  @type decode_node_error() :: {:error, :bad_hash | :missing_hash | :invalid_node}
  @type proof_verification_error() :: {:error, :invalid_proof, {:bad_val, Trie.value()}} | decode_node_error()

  @doc """
  Building proof tree for given path by going through each node ot this path
  and making new partial tree.
  """
  @spec construct_proof({Trie.t(), Trie.key(), Trie.t()}) :: {Trie.val() | nil, Trie.t()} | decode_node_error()
  def construct_proof({trie, key, proof_db}) do
    ## Constructing the proof trie going through the rest of the nodes
    case decode_node_and_check_hash_with_trie_copy(trie.root_hash, trie, proof_db) do
      {:ok, decoded} ->
        int_construct_proof(decoded, trie, Helper.get_nibbles(key), proof_db)
      {:error, _} = err ->
        err
    end
  end

  @spec int_construct_proof(decoded_node(), Trie.t(), list(), Trie.t()) :: {Trie.val() | nil, Trie.t()} | decode_node_error()
  defp int_construct_proof(:empty, _, _, proof), do: {nil, proof}

  defp int_construct_proof({:branch, branches}, _, [], proof) do
    {List.last(branches), proof}
  end

  defp int_construct_proof({:leaf, [], v}, _, [], proof) do
    {v, proof}
  end

  defp int_construct_proof(_, _, [], proof) do
    {nil, proof}
  end

  defp int_construct_proof({:branch, branches}, trie, [nibble | rest], proof) do
    case Enum.at(branches, nibble) do
      [] ->
        {nil, proof}

      encoded_node ->
        case decode_node_and_check_hash_with_trie_copy(encoded_node, trie, proof) do
          {:ok, decoded} ->
            int_construct_proof(decoded, trie, rest, proof)
          {:error, _} = err ->
            err
        end

    end
  end

  defp int_construct_proof({:leaf, [prefix, value]}, _, nibbles, proof) do
    case nibbles do
          ^prefix -> {value, proof}
          _ -> {nil, proof}
        end
  end

  defp int_construct_proof({:ext, [shared_prefix, next_hash]}, trie, nibbles, proof) do
    # extension, continue walking tree if we match
    case ListHelper.get_postfix(nibbles, shared_prefix) do
      nil ->
        # did not match extension node
        {nil, proof}

      rest ->
        # we match the extension node
        case decode_node_and_check_hash_with_trie_copy(next_hash, trie, proof) do
          {:ok, decoded} ->
            int_construct_proof(decoded, trie, rest, proof)
          {:error, _} = err ->
            err
        end
    end
  end

  @doc """
  Verifying that particular path leads to a given value.
  """
  @spec verify_proof(Trie.key(), Trie.value(), binary(), Trie.t()) :: :ok | proof_verification_error()
  def verify_proof(key, value, hash, proof) do
    case decode_node_and_check_hash_with_trie_lookup(hash, proof) do
      {:ok, decoded} ->
        int_verify_proof(Helper.get_nibbles(key), decoded, value, proof)
      {:error, _} = err ->
        err
    end
  end

  @spec int_verify_proof(list(), decoded_node(), Trie.value(), Trie.t()) :: :ok | proof_verification_error()
  defp int_verify_proof(path, {:ext, [shared_prefix, next_hash]}, value, proof) do
    case ListHelper.get_postfix(path, shared_prefix) do
      nil -> {:error, :invalid_proof}
      rest ->
        case decode_node_and_check_hash_with_trie_lookup(next_hash, proof) do
          {:ok, decoded} ->
            int_verify_proof(rest, decoded, value, proof)
          {:error, _} = err ->
            err
        end
    end
  end

  defp int_verify_proof([], {:branch, branch}, value, _) do
    found_val = List.last(branch)
    if(found_val == value) do
      :ok
    else
      {:error, {:bad_val, found_val}}
    end
  end

  defp int_verify_proof([nibble | rest], {:branch, branch}, value, proof) do
    case Enum.at(branch, nibble) do
      [] ->
        {:error, :invalid_proof}

      next_node ->
        case decode_node_and_check_hash_with_trie_lookup(next_node, proof) do
          {:ok, decoded} ->
            int_verify_proof(rest, decoded, value, proof)
        end
    end
  end

  defp int_verify_proof(path, {:leaf, [shared_prefix, node_val]}, value, _) do
    cond do
      path != shared_prefix ->
        {:error, :invalid_proof}
      node_val != value ->
        {:error, {:bad_val, node_val}}
      true ->
        :ok
    end
  end

  defp int_verify_proof(_, _, _, _) do
    {:error, :invalid_proof}
  end

  @spec decode_node_and_check_hash_with_trie_lookup(binary(), Trie.t()) :: {:ok, decoded_node()} | decode_node_error()
  defp decode_node_and_check_hash_with_trie_lookup(hash, trie) do
    decode_node_and_check_hash(hash, fn hash -> read_from_db(trie.db, hash) end)
  end

  @spec decode_node_and_check_hash_with_trie_copy(binary(), Trie.t(), Trie.t()) :: {:ok, decoded_node()} | decode_node_error()
  defp decode_node_and_check_hash_with_trie_copy(hash, trie, proof) do
    decode_node_and_check_hash(hash, &insert_proof_db(&1, trie.db, proof))
  end

  @spec decode_node_and_check_hash(binary(), (binary() -> (binary() | :not_found))) :: {:ok, decoded_node()} | decode_node_error()
  defp decode_node_and_check_hash(hash, hash_lookup_fun) when is_binary(hash) and byte_size(hash) == 32 do
    case hash_lookup_fun.(hash) do
      :not_found ->
        {:error, :missing_hash}
      rlp ->
        case Utils.hash(rlp) do
          ^hash ->
            decode_node_and_check_hash(rlp, hash_lookup_fun)
          k ->
            {:error, :bad_hash}
        end
    end
  end

  defp decode_node_and_check_hash(rlp, _) when is_binary(rlp) and byte_size(rlp) != 32 do
    case rlp_decode(rlp) do
      :error ->
        {:error, :invalid_node}
      nil ->
        {:ok, :empty}
      decoded ->
        decode_node(decoded)
    end
  end

  defp decode_node_and_check_hash(a, b) do
    {:error, :invalid_node}
  end

  @spec decode_node(list()) :: {:ok, {atom(), list()}} | {:error, :invalid_node}
  defp decode_node(branch) when is_list(branch) and length(branch) == 17 do
    {:ok, {:branch, branch}}
  end

  defp decode_node([hp_k, v]) do
    {prefix, is_leaf} = HexPrefix.decode(hp_k)
    if is_leaf do
        {:ok, {:leaf, [prefix, v]}}
      else
      #extension node must contain a proper hash
      if(is_binary(v) and byte_size(v) == 32) do
        {:ok, {:ext, [prefix, v]}}
      else
        {:error, :invalid_node}
      end
    end
  end

  defp decode_node(_), do: {:error, :invalid_node}

  @spec rlp_decode(binary()) :: list()
  defp rlp_decode(val) when is_binary(val) do
    try do
      ExRLP.decode(val)
    rescue
      ArgumentError -> :error
    end
  end

  defp rlp_decode(_), do: :error

  ## DB operations
  defp insert_proof_db(hash, db, proof) do
    case DB.get(db, hash) do
      {:ok, node} ->
        :ok = DB.put!(proof.db, hash, node)
        node
      :not_found ->
        :not_found
    end
  end

  defp read_from_db(db, hash) do
    case DB.get(db, hash) do
      {:ok, val} ->
        val
      :not_found ->
        :not_found
    end
  end
end
