defmodule MerklePatriciaTree.Proof do

  require Integer

  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.Trie.Node
  alias MerklePatriciaTree.Trie.Helper
  alias MerklePatriciaTree.ListHelper
  alias MerklePatriciaTree.DB
  alias MerklePatriciaTree.DB.LevelDB

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

      {:ext, shared_prefix, node_val} when shared_prefix == rest ->
        {node_val, proof}

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

  def verify_proof(key, value, hash, proof_db) do
    case read_from_db(proof_db, hash) do
      {:ok, node} ->
        int_verify_proof(
          Helper.get_nibbles(key),
          decode_node(construct_val(node), proof_db),
          value, proof_db)

      {:bad_hash, _} = res -> res
    end
  end

  defp int_verify_proof(_, {:value, {_, true}, val}, value, _) when val == value do
    :true
  end

  defp int_verify_proof([_ | []], {:value, {_, false}, val}, value, proof_db) do
    int_verify_proof([], decode_node(construct_val(val), proof_db), value, proof_db)
  end

  defp int_verify_proof([_ | _] = path, {:value, {cpath, false}, val}, value, proof_db) do
    rest = ListHelper.get_postfix(path, cpath)

    case val do
      bin when is_binary(bin) ->
        int_verify_proof(
          rest, decode_node(construct_val(bin), proof_db), value, proof_db
        )

      [_|_] = branch when length(branch) == 17 ->
        int_verify_proof(
          rest, decode_node(construct_val(branch), proof_db), value, proof_db
        )

      [_k, _v] ->
        ## TODO
        :false
    end
  end

  defp int_verify_proof([], {:branch, [_|_] = branch}, value, _proof_db) when length(branch) == 17 do
    get_branch_val(branch, 16) == value
  end

  defp int_verify_proof([], [_, val], value, _proof_db) when val == value, do: true
  defp int_verify_proof([], val, value, _proof_db) when val ==  value, do: true
  defp int_verify_proof([], _val, _value, _proof_db) , do: false

  defp int_verify_proof([nibble | [] = nibbles], {:branch, branch}, value, proof_db) do
    branch_val = get_branch_val(branch, nibble)
    int_verify_proof(nibbles, decode_node(construct_val(branch_val), proof_db), value, proof_db)
  end

  defp int_verify_proof([_|_] = path, bin, value, proof_db) when is_binary(bin) do
    int_verify_proof(path, decode_node(bin, proof_db), value, proof_db)
  end

  defp int_verify_proof([nibble | nibbles], {:branch, branch}, value, proof_db) do
    branch_val = get_branch_val(branch, nibble)
    int_verify_proof(nibbles, decode_node(construct_val(branch_val), proof_db), value, proof_db)
  end

  defp construct_val([_|_] = branch) when length(branch) == 17, do: {:branch, branch}
  defp construct_val(bin) when is_binary(bin), do: bin
  defp construct_val([k, v]), do: {:value, decode_path(k), v}

  ## The node is 32 byte, so perhaps this is hash, so we will look up into db
  defp decode_node(node, db) when byte_size(node) == 32 do
    case read_from_db(db, node) do
      {:ok, node} ->
        ExRLP.decode(node) |> construct_val()

      :not_found ->
        ## TODO : handle it
        :error
    end
  end

  defp decode_node(node, _db) when is_binary(node) do
    ExRLP.decode(node) |> construct_val()
  end

  defp decode_node([path, val], _db), do: {:value, path, val}

  defp decode_node({:branch, _} = branch, _db), do: branch

  defp decode_node([_|_] = branch, _db) when length(branch) == 17, do: {:branch, branch}

  defp decode_node(any, _), do: any

  defp decode_path(key) when is_binary(key), do: HexPrefix.decode(key)

  defp decode_path([key, _node]) when is_binary(key), do: HexPrefix.decode(key)

  defp decode_path([_ | _]), do: []

  defp get_branch_val(branch, at), do: Enum.at(branch, at)

  ## DB operations

  defp insert_proof_db(hash, db, proof) do
    {:ok, node} = DB.get(db, hash)
    DB.put!(proof.db, hash, node)
  end

  defp read_from_db(db, hash), do: MerklePatriciaTree.DB.get(db, hash)

end
