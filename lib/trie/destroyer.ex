defmodule MerklePatriciaTree.Trie.Destroyer do
  @moduledoc """
  Destroyer is responsible for removing keys from a
  merkle trie. To remove a key, we need to make a
  delta to our trie which ends up as the canonical
  form of the given tree as defined in http://gavwood.com/Paper.pdf.

  Note: this algorithm is non-obvious, and hence why we have a good
  number of functional and invariant tests. We should add more specific
  unit tests to this module.

  """
  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.Trie.Node
  alias MerklePatriciaTree.ListHelper

  @empty_branch <<>>

  @doc """
  Removes a key from a given trie, if it exists.

  This may radically change the structure of the trie.
  """
  @spec remove_key(Node.trie_node(), Trie.key(), Trie.t()) :: Node.trie_node()
  def remove_key(trie_node, key, trie) do
    trie_remove_key(trie_node, key, trie)
  end

  # To remove this leaf, simply remove it
  defp trie_remove_key({:leaf, leaf_prefix, _value}, prefix, _trie) when prefix == leaf_prefix do
    :empty
  end

  # This key doesn't exist, do nothing.
  defp trie_remove_key({:leaf, leaf_prefix, value}, _prefix, _trie) do
    {:leaf, leaf_prefix, value}
  end

  # Shed shared prefix and continue removal operation
  defp trie_remove_key({:ext, ext_prefix, node_hash}, key_prefix, trie) do
    {_matching_prefix, ext_tl, remaining_tl} = ListHelper.overlap(ext_prefix, key_prefix)

    unless length(ext_tl) == 0 do
      # Prefix doesn't match ext, do nothing.
      {:ext, ext_prefix, node_hash}
    else
      existing_node = Node.decode_trie(node_hash |> Trie.into(trie))
      updated_node = trie_remove_key(existing_node, remaining_tl, trie)

      # Handle the potential cases of children
      case updated_node do
        :empty ->
          :empty

        {:leaf, leaf_prefix, leaf_value} ->
          {:leaf, ext_prefix ++ leaf_prefix, leaf_value}

        {:ext, new_ext_prefix, new_ext_node_hash} ->
          {:ext, ext_prefix ++ new_ext_prefix, new_ext_node_hash}

        els ->
          {:ext, ext_prefix, els |> Node.encode_node(trie)}
      end
    end
  end

  # Remove from a branch when directly on value
  defp trie_remove_key({:branch, branches}, [], trie) when length(branches) == 17 do
    {:branch, List.replace_at(branches, 16, "")}
    |> try_to_reduce_branch(trie)
  end

  # Remove beneath a branch
  defp trie_remove_key({:branch, branches}, [prefix_hd | prefix_tl], trie)
       when length(branches) == 17 do
    updated_branches =
      List.update_at(branches, prefix_hd, fn branch ->
        branch_node = branch |> Trie.into(trie) |> Node.decode_trie()

        case trie_remove_key(branch_node, prefix_tl, trie) do
          :empty -> ""
          node -> Node.encode_node(node, trie)
        end
      end)

    non_blank_branches =
      updated_branches
      |> Enum.drop(-1)
      |> Enum.with_index()
      |> Enum.filter(fn {branch, _} -> branch != @empty_branch end)

    final_value = List.last(updated_branches)

    cond do
      non_blank_branches |> Enum.empty?() ->
        # We just have a final value, this will need to percolate up
        {:leaf, [], final_value}

      Enum.count(non_blank_branches) == 1 and final_value == "" ->
        # We just have a node we need to percolate up
        {branch_node, i} = List.first(non_blank_branches)

        decoded_branch_node = Node.decode_trie(branch_node |> Trie.into(trie))

        case decoded_branch_node do
          {:leaf, leaf_prefix, leaf_value} ->
            {:leaf, [i | leaf_prefix], leaf_value}

          {:ext, ext_prefix, ext_node_hash} ->
            {:ext, [i | ext_prefix], ext_node_hash}

          # TODO: Is this illegal since ext has to have at least two nibbles?
          {:branch, _branches} ->
            {:ext, [i], branch_node}
        end

      true ->
        {:branch, updated_branches}
    end
  end

  # Merge into empty to create a leaf
  defp trie_remove_key(:empty, _prefix, _trie), do: :empty

  # Reduce branch node
  defp try_to_reduce_branch(branch, trie) do
    case get_singleton_branch(branch) do
      ## More than one element in the branch
      ## so we cannot delete it.
      :error ->
        branch

      ## This should not suppose to happened.
      ## We have empty branch.
      ## TODO: Consider handlig the error.
      :none ->
        :error

      {:value, value} ->
        {:leaf, [], value}

      {next, next_node} ->
        case Node.decode_node(next_node, trie) do
          {:leaf, path, val} ->
            {:leaf, [next] ++ path, val}

          {:ext, path, val} ->
            {:ext, [next] ++ path, val}

          {:branch, _} ->
            {:ext, [next], next_node}
        end
    end
  end

  defp get_singleton_branch({:branch, branch} = b) do
    init_acc =
      case List.last(branch) do
        value when value == nil or value == "" ->
          :none

        value ->
          {:value, value}
      end

    get_singleton_branch(b, 0, init_acc)
  end

  ## We reached the end of the branch
  defp get_singleton_branch(_branch, n, res) when n > 15, do: res

  ## Get next element of the branch.
  ## If we have more than one element in our
  ## accumulator, then we return `error`.
  ## Means, the branch cannot be reduced
  defp get_singleton_branch({:branch, branch} = b, n, acc) do
    node = Enum.at(branch, n)

    case node == "" or node == nil do
      true ->
        get_singleton_branch(b, n + 1, acc)

      false when acc != :none ->
        ## More than one value
        :error

      false ->
        ## First value
        get_singleton_branch(b, n + 1, {n, node})
    end
  end
end
