defmodule MerklePatriciaTree.Proof do

  require Integer

  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.Test
  alias MerklePatriciaTree.Trie.Node
  alias MerklePatriciaTree.Trie.Helper
  alias MerklePatriciaTree.ListHelper

  def construct_proof(trie, key) do
    proof_db = Trie.new(Test.random_ets_db())
    insert_proof_db(trie.root_hash, trie.db, proof_db)
    construct_proof(Trie.get_next_node(trie.root_hash, trie), Helper.get_nibbles(key), proof_db)
  end

  ## TODO : simplify this
  defp construct_proof(nil, val, proof), do: {val, proof}
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
              Trie.get_next_node(node_hash, trie), rest, proof)

          node_hash ->
            construct_proof(Trie.get_next_node(node_hash, trie), rest, proof)
        end

      {:leaf, prefix, value} ->
        case nibbles do
          ^prefix ->
            {value, proof}
          _ -> {nil, proof}
        end

      {:ext, shared_prefix, node_val} when shared_prefix == rest ->
        {node_val, proof}

      {:ext, shared_prefix, next_node} when is_list(next_node) ->
        {{:branch, next_node}, proof}

        {:ext, shared_prefix, next_node} ->
        case ListHelper.get_postfix(nibbles, shared_prefix) do
          nil ->
            {nil, proof}

          rest ->
            insert_proof_db(next_node, trie.db, proof)
            construct_proof(Trie.get_next_node(next_node, trie), rest, proof)
        end
    end
  end

  defp construct_proof(trie, [], proof) do
    case Node.decode_trie(trie) do
      {:branch, branches} -> {List.last(branches), proof}
      {:leaf, [], v} -> {v, proof}
      _ -> {nil, proof}
    end
  end

  def verify_proof(key, value, hash, proof_db) do
    case read_from_db(proof_db, hash) do
      {:ok, node} ->
        int_verify_proof(
          Helper.get_nibbles(key),
          decode_node(construct_val(node), proof_db),
          value, proof_db)

      {:bad_hash, h} = res ->
        res
    end
  end

  def set_branch(branch) do
    {:branch, branch}
  end

  def read_from_db(db, hash), do: MerklePatriciaTree.DB.get(db, hash)

  def get_branch_val(branch, at) do
    Enum.at(branch, at)
  end

  def construct_path(path1, path2), do: path1 -- path2

  def int_verify_proof(path, {:value, {cpath, true}, val}, value, proof_db) do
    :true
  end

  def int_verify_proof([nibble | []] = path, {:value, {cpath, false}, val}, value, proof_db) do
    int_verify_proof([], decode_node(construct_val(val), proof_db), value, proof_db)
  end

  def int_verify_proof([head_p | tail_p] = path, {:value, {cpath, false}, val}, value, proof_db) do
    {nibble, nibbles, rest} =
       if cpath == path do
         {[], [], []}
       else
         [nibble | rest] = nibbles = construct_path(path, cpath)
         {nibble, nibbles, rest}
       end

    case val do
      bin when is_binary(bin) ->
        int_verify_proof(nibbles, decode_node(construct_val(bin), proof_db), value, proof_db)

      [_|_] = branch when length(branch) == 17 ->
        ## TODO
        :false

      [k, v] ->
        ## TODO
        :false
    end
  end

  def int_verify_proof([], {:branch, [_|_] = branch}, value, proof_db) when length(branch) == 17 do
    get_branch_val(branch, 16) == value
  end

  def int_verify_proof([], val, value, proof_db) do
    case val do
      [_, ^value] ->
        :true

      ^value ->
        :true

      bad_value ->
        {:bad_value, bad_value}
    end
  end

  def int_verify_proof([nibble | [] = nibbles] = path, {:branch, branch}, value, proof_db) do
    branch_val = get_branch_val(branch, nibble)
    int_verify_proof(nibbles, decode_node(construct_val(branch_val), proof_db), value, proof_db)
  end

  def int_verify_proof([nibble | nibbles] = path, bin, value, proof_db) when is_binary(bin) do
    int_verify_proof(path, decode_node(bin, proof_db), value, proof_db)
  end

  def int_verify_proof([nibble | nibbles] = path, {:branch, branch}, value, proof_db) do
    branch_val = get_branch_val(branch, nibble)
    int_verify_proof(nibbles, decode_node(construct_val(branch_val), proof_db), value, proof_db)
  end

  def construct_val([_|_] = branch) when length(branch) == 17, do: {:branch, branch}
  def construct_val(bin) when is_binary(bin), do: bin
  def construct_val([k, v]), do: {:value, decode_path(k), v}

  ## The node is 32 byte, so perhaps this is hash, so we will look up into db
  def decode_node(node, db) when byte_size(node) == 32 do
    case read_from_db(db, node) do
      {:ok, node} ->
        ExRLP.decode(node) |> construct_val()

      :not_found ->
        ## TODO : handle it
    end
  end

  def decode_node(node, db) when is_binary(node) do
    ExRLP.decode(node) |> construct_val()
  end

  def decode_node([path, val], db), do: {:value, path, val}

  def decode_node({:branch, _} = branch, db), do: branch

  def decode_node([_|_] = branch, db) when length(branch) == 17, do: {:branch, branch}

  def decode_node(any, _), do: any

  def decode_path(key) when is_binary(key), do: HexPrefix.decode(key)

  def decode_path([key, node]) when is_binary(key), do: HexPrefix.decode(key)

  def decode_path([_ | _]), do: []

  defp insert_proof_db(hash, db, proof) do
    {:ok, node} = MerklePatriciaTree.DB.get(db, hash)
    MerklePatriciaTree.DB.put!(proof.db, hash, node)
  end
end
