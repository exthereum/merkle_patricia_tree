defmodule MerklePatriciaTree.Proof do
  require Integer

  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.Trie.Node
  alias MerklePatriciaTree.Trie.Helper
  alias MerklePatriciaTree.ListHelper
  alias MerklePatriciaTree.DB

  @doc """
  Building proof tree for given path by going through each node ot this path
  and making new partial tree.
  """
  @spec construct_proof(Trie.t(), Trie.key(), Trie.t()) :: :ok
  def construct_proof({trie, key, proof_db}) do
    ## Inserting the value of the root hash into the proof db
    node = insert_proof_db(trie.root_hash, trie.db, proof_db)
    ## Constructing the proof trie going through the rest of the nodes
    construct_proof({rlp_decode(node), trie}, Helper.get_nibbles(key), proof_db)
  end

  defp construct_proof({:error, _}, _, proof), do: {nil, proof}

  defp construct_proof({node, trie}, nibbles = [nibble | rest], proof) do
    case decode_node(node, trie, proof) do
      :empty ->
        {nil, proof}

      {:branch, branches} ->
        # branch node
        case Enum.at(branches, nibble) do
          [] ->
            {nil, proof}

          node_hash when is_binary(node_hash) and byte_size(node_hash) == 32 ->
            node = insert_proof_db(node_hash, trie.db, proof)
            construct_proof({node, trie}, rest, proof)

          node_hash ->
            construct_proof({node_hash, trie}, rest, proof)
        end

      {:leaf, prefix, value} ->
        case nibbles do
          ^prefix -> {value, proof}
          _ -> {nil, proof}
        end

      {:ext, shared_prefix, next_node} when is_list(next_node) ->
        # extension, continue walking tree if we match
        case ListHelper.get_postfix(nibbles, shared_prefix) do
          nil ->
            # did not match extension node
            {nil, proof}

          rest ->
            construct_proof({next_node, trie}, rest, proof)
        end

      {:ext, shared_prefix, next_node} ->
        case ListHelper.get_postfix(nibbles, shared_prefix) do
          nil ->
            {nil, proof}

          rest ->
            node = insert_proof_db(next_node, trie.db, proof)
            construct_proof({node, trie}, rest, proof)
        end

      _ ->
        {nil, proof}
    end
  end

  defp construct_proof({node, _trie}, [], proof) do
    case Node.decode_node(node, proof) do
      {:branch, branches} ->
        {List.last(branches), proof}

      {:leaf, [], v} ->
        {v, proof}

      _ ->
        {nil, proof}
    end
  end

  @doc """
  Verifying that particular path leads to a given value.
  """
  @spec verify_proof(Trie.key(), Trie.value(), binary(), Trie.t()) :: :ok
  def verify_proof(key, value, hash, proof) do
    case read_from_db(proof.db, hash) do
      {:ok, node} ->
        case decode_node(rlp_decode(node), nil, proof) do
          :error -> false
          node -> int_verify_proof(Helper.get_nibbles(key), node, value, proof)
        end
      :not_found ->
        false
    end
  end

  defp int_verify_proof(path, {:ext, shared_prefix, next_node}, value, proof) do
    case ListHelper.get_postfix(path, shared_prefix) do
      nil -> false
      rest -> int_verify_proof(rest, decode_node(next_node, nil, proof), value, proof)
    end
  end

  defp int_verify_proof([], {:branch, branch}, value, _) do
    List.last(branch) == value
  end

  defp int_verify_proof([nibble | rest], {:branch, branch}, value, proof) do
    case Enum.at(branch, nibble) do
      [] ->
        false

      next_node ->
        int_verify_proof(rest, decode_node(next_node, nil, proof), value, proof)
    end
  end

  defp int_verify_proof(path, {:leaf, shared_prefix, node_val}, value, _) do
    node_val == value and path == shared_prefix
  end

  defp int_verify_proof(_path, _node, _value, _proof), do: false

  defp decode_node(:error, _, _), do: :error

  defp decode_node(node, trie, proof) do
    case node do
      node when is_list(node) and length(node) == 17 ->
        {:branch, node}

      node when is_binary(node) ->
        rlp_node =
          if byte_size(node) == 32 do
            case read_from_db(proof.db, node) do
              {:ok, rlp} ->
                rlp
              :not_found ->
                :error
            end
          else
            node
          end

        decode_node(rlp_decode(rlp_node), trie, proof)

      [hp_k, v] ->
        {prefix, is_leaf} = HexPrefix.decode(hp_k)

        if is_leaf do
          {:leaf, prefix, v}
        else
          build_ext(prefix, v, trie, proof)
        end

      nil -> :empty
    end
  end

  defp build_ext(prefix, hash, nil, proof) when byte_size(hash) == 32 do
    case read_from_db(proof.db, hash) do
      {:ok, rlp_node} ->
        case rlp_decode(rlp_node) do
            :error ->
              :error
            v ->
              {:ext, prefix, v}
          end
      :not_found ->
        :error
    end
  end

  defp build_ext(prefix, hash, trie, proof) when is_binary(hash) and byte_size(hash) == 32 do
    rlp_node = insert_proof_db(hash, trie.db, proof)
    case rlp_decode(rlp_node) do
      :error ->
        :error
      v ->
        {:ext, prefix, v}
    end
  end

  defp build_ext(prefix, hash, _trie, _proof) do
    {:ext, prefix, hash}
  end

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
    {:ok, node} = DB.get(db, hash)
    :ok = DB.put!(proof.db, hash, node)
    node
  end

  defp read_from_db(db, hash), do: DB.get(db, hash)
end
