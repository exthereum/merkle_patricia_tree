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
    insert_proof_db(trie.root_hash, trie.db, proof_db)

    ## Constructing the proof trie going through the rest of the nodes
    next_node = Trie.get_next_node(trie.root_hash, trie)
    construct_proof(next_node, Helper.get_nibbles(key), proof_db)
  end

  defp construct_proof(trie, nibbles=[nibble| rest], proof) do
    case Node.decode_trie(trie) do
      :empty ->
        {nil, proof}

      {:branch, branches} ->
        # branch node
        case Enum.at(branches, nibble) do
          [] ->
            {nil, proof}

          node_hash when is_binary(node_hash) and byte_size(node_hash) == 32 ->

            insert_proof_db(node_hash, trie.db, proof)
            construct_proof(
              Trie.get_next_node(node_hash, trie), rest, proof
            )

          node_hash ->
            construct_proof(Trie.get_next_node(node_hash, trie), rest, proof)

        end

      {:leaf, prefix, value} ->
        case nibbles do
          ^prefix -> {value, proof}
          _ -> {nil, proof}
        end

      {:ext, shared_prefix, next_node} when is_list(next_node) ->
        # extension, continue walking tree if we match
        case ListHelper.get_postfix(nibbles, shared_prefix) do
          nil -> {nil, proof} # did not match extension node
          rest -> construct_proof(Trie.get_next_node(next_node, trie), rest, proof)
        end

      {:ext, shared_prefix, next_node} ->
        case ListHelper.get_postfix(nibbles, shared_prefix) do
          nil  -> {nil, proof}
          rest ->
            insert_proof_db(next_node, trie.db, proof)
            construct_proof(Trie.get_next_node(next_node, trie), rest, proof)
        end
    end
  end

  defp construct_proof(trie, [], proof) do
    case Node.decode_trie(trie) do
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
    case decode_node(hash, proof) do
      :error -> false
      node -> int_verify_proof(Helper.get_nibbles(key), node, value, proof)
    end
  end

  defp int_verify_proof(path, {:ext, shared_prefix, next_node}, value, proof) do
    case ListHelper.get_postfix(path, shared_prefix) do
      nil -> false
      rest -> int_verify_proof(rest, decode_node(next_node, proof), value, proof)
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
        int_verify_proof(rest, decode_node(next_node, proof), value, proof)
    end
  end

  defp int_verify_proof(path, {:leaf, shared_prefix, node_val}, value, _) do
    node_val == value and path == shared_prefix
  end

  defp int_verify_proof(_path, _node,  _value, _proof), do: false

  defp decode_node(hash, proof) when is_binary(hash) and byte_size(hash) == 32 do
    case read_from_db(proof, hash) do
      {:ok, node} -> decode_node(ExRLP.decode(node), proof)
      _ -> :error
    end
  end

  defp decode_node(node, proof), do: Node.decode_node(node, proof)

  ## DB operations

  defp insert_proof_db(hash, db, proof) do
    {:ok, node} = DB.get(db, hash)
    DB.put!(proof.db, hash, node)
  end

  defp read_from_db(db, hash), do: DB.get(db, hash)

end
