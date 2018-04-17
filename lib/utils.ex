defmodule MerklePatriciaTree.Utils do
  @moduledoc """
  Helper functions related to common operations
  """

  @hash_bytes 32

  @doc """
  Returns a semi-random string of length `length` that
  can be represented by alphanumeric characters.

  Adopted from https://stackoverflow.com/a/32002566.

  ## Examples

      iex> MerklePatriciaTree.Test.random_string(20) |> is_binary
      true

      iex> String.length(MerklePatriciaTree.Test.random_string(20))
      20

      iex> MerklePatriciaTree.Test.random_string(20) == MerklePatriciaTree.Test.random_string(20)
      false
  """
  def random_string(length) do
    :crypto.strong_rand_bytes(length) |> Base.url_encode64 |> binary_part(0, length)
  end

  @doc """
  Returns a semi-random atom, similar to `random_string/1`, but
  is an atom. This is obviously not to be used in production since
  atoms are not garbage collected.

  ## Examples

      iex> MerklePatriciaTree.Test.random_atom(20) |> is_atom
      true

      iex> MerklePatriciaTree.Test.random_atom(20) |> Atom.to_string |> String.length
      20

      iex> MerklePatriciaTree.Test.random_atom(20) == MerklePatriciaTree.Test.random_atom(20)
      false
  """
  def random_atom(length) do
    length |> random_string |> String.to_atom
  end

  @doc """
  Hashes a data using blake2b
  """
  @spec hash(binary) :: binary | {:error, term}
  def hash(bin) when is_binary(bin) do
    {:ok, hash} = :enacl.generichash(@hash_bytes, bin)
    hash
  end

  def hash(_) do
    {:error, "wrong input data"}
  end
end
