defmodule MerklePatriciaTree.Proof do

  require Integer

  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.Test
  alias MerklePatriciaTree.Trie.Node
  alias MerklePatriciaTree.Trie.Helper
  alias MerklePatriciaTree.ListHelper

  def construct_proof(trie, key) do
    proof_db = Trie.new(Test.random_ets_db())
    case MerklePatriciaTree.DB.get(trie.db, trie.root_hash) do
      {:ok, val} when is_binary(val) ->

        MerklePatriciaTree.DB.put!(proof_db.db, trie.root_hash, val)
      _ ->
        :ok
    end
    construct_proof(Trie.get_next_node(trie.root_hash, trie), Helper.get_nibbles(key), proof_db)
  end

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

        {:ext, shared_prefix, node_val} when shared_prefix == nibbles ->
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
      {:ok, node}  ->
        int_verify_proof(Helper.get_nibbles(key),
          decode_node(node, proof_db), value, proof_db)

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

  def int_verify_proof(path, {:value, cpath, val}, value, proof_db) when val == value do
    ## TODO check if decode_path(cpath) return true
    :ok
  end

  def int_verify_proof(path, {:value, cpath, val}, value, proof_db) do
    cpath =
    if is_binary(cpath) do
      {k, bool} = HexPrefix.decode(cpath)
    else
      cpath
    end

    ## TODO fix path issues
    [nibble | rest] = construct_path(path, cpath)

    if is_binary(val) do
      case decode_node(val, proof_db) do
        {:branch, branch} ->
          branch_val = get_branch_val(branch, nibble)
          int_verify_proof(rest, decode_node(branch_val, proof_db), value, proof_db)

        any -> :todo
      end

    else
      int_verify_proof(rest, get_branch_val(val, nibble), value, proof_db)
    end
  end

  def int_verify_proof([], {:branch, [_|_] = branch}, value, proof_db) do
    if value == get_branch_val(branch, 16) do
      :ok
    else
      {:bad_value, get_branch_val(branch, 16)}
    end
  end

  def int_verify_proof([] = path, [k, val], value, proof_db) do
    if val == value do
      :ok
    else
      {:bad_value, val}
    end
  end

  def int_verify_proof([nibble | nibbles] = path, node, value, proof_db) do
    case decode_node(node, proof_db) do
      {:branch, [k, v]} ->

        {decoded_path, bool} = decode_path(k)
        if bool do
          if v == value do
            :ok
          else
            {:bad_value, v}
          end
        else

          int_verify_proof(nibbles, decode_node(v, proof_db), value, proof_db)
        end


      {:branch, [_|_] = branch} ->

        case get_branch_val(branch, nibble) do
          b = [_|_] ->
            int_verify_proof(nibbles, decode_node({:branch, b}, proof_db), value, proof_db)

          {:value, _, ^value} ->
            :ok

          any ->
            int_verify_proof(nibbles, decode_node(branch, proof_db), value, proof_db)
        end

        any -> :todo

    end
  end

  ## The node is 32 byte, so perhaps this is hash, so we will look up into db
  def decode_node(node, db) when byte_size(node) == 32 do
    case read_from_db(db, node) do

      {:ok, node} ->

        case ExRLP.decode(node) do
          [cpath, [_|_] = branch] ->
          {decoded_path, _} = decode_path(cpath)

          {:value, decoded_path, branch}

          [_|_] = branch ->
            {:branch, branch}
        end
    end
  end

  def decode_node(node, db) when is_binary(node) do
    case ExRLP.decode(node) do
      [cpath, val] ->
        {decoded_path, _} = decode_path(cpath)
        {:value, decoded_path, val}

      [_|_] = branch ->
        {:branch, branch}
    end
  end

  def decode_node([path, val], db), do: {:value, path, val}

  def decode_node({:branch, _} = branch, db), do: branch

  def decode_node([_|_] = branch, db), do: {:branch, branch}

  def decode_path(key) when is_binary(key), do: HexPrefix.decode(key)

  def decode_path([key, node]) when is_binary(key), do: HexPrefix.decode(key)

  def decode_path([_ | _]), do: []

  defp insert_proof_db(hash, db, proof) do
    {:ok, node} = MerklePatriciaTree.DB.get(db, hash)
    MerklePatriciaTree.DB.put!(proof.db, hash, node)
  end

  def create_test_trie() do
    db = Test.random_ets_db(:test)
    trie = Trie.new(db)
    trie = Trie.update(trie, <<0::4, 1::4, 0::4, 1::4, 0::4, 2::4>>, <<"112">>)
    trie = Trie.update(trie, <<0::4, 1::4, 0::4, 1::4, 0::4, 3::4>>, <<"113">>)
    #trie = Trie.update(trie, <<0::4, 1::4, 0::4>>, <<"010">>)
    trie = Trie.update(trie, <<0::4, 1::4, 1::4>>, <<"011">>)
    #trie = Trie.update(trie, <<0::4, 1::4, 0::4, 1::4, 0::4, 2::4, 5::4, 7::4>>, <<"11257">>)
    #trie = Trie.update(trie, <<0::4, 1::4, 0::4, 1::4, 0::4, 2::4, 5::4, 7::4, 8::4, 0::4>>, <<"1125780">>)
  end

end
