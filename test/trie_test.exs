defmodule MerklePatriciaTree.TrieTest do
  use ExUnit.Case, async: true
  doctest MerklePatriciaTree.Trie

  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.Utils
  alias MerklePatriciaTree.DB.ETS
  alias MerklePatriciaTree.Trie.Verifier

  @max_32_bits 4_294_967_296

  setup do
    {:ok, %{db: ETS.random_ets_db()}}
  end

  describe "get" do
    test "for a simple trie with just a leaf", %{db: db} do
      trie = Trie.new(db)
      trie = %{trie | root_hash: leaf_node([0x01, 0x02, 0x03], "cool")}

      assert Trie.get(trie, <<0x01::4>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x02::4>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4>>) == "cool"
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4, 0x04::4>>) == nil
    end

    test "for a trie with an extension node followed by a leaf", %{db: db} do
      trie = Trie.new(db)

      trie = %{
        trie
        | root_hash:
            [0x01, 0x02]
            |> extension_node(leaf_node([0x03], "cool"))
            |> ExRLP.encode()
            |> store(db)
      }

      assert Trie.get(trie, <<0x01::4>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x02::4>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4>>) == "cool"
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4, 0x04::4>>) == nil
    end

    test "for a trie with an extension node followed by an extension node and then leaf", %{
      db: db
    } do
      trie = Trie.new(db)

      trie = %{
        trie
        | root_hash:
            [0x01, 0x02]
            |> extension_node(extension_node([0x03], leaf_node([0x04], "cool")))
            |> ExRLP.encode()
            |> store(db)
      }

      assert Trie.get(trie, <<0x01::4>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x02::4>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4, 0x04::4>>) == "cool"
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4, 0x04::4, 0x05::4>>) == nil
    end

    test "for a trie with a branch node", %{db: db} do
      trie = Trie.new(db)

      trie = %{
        trie
        | root_hash:
            [0x01]
            |> extension_node(
              branch_node([leaf_node([0x02], "hi") | blanks(15)], "cool")
              |> MerklePatriciaTree.Trie.Node.encode_node(trie)
            )
            |> ExRLP.encode()
            |> store(db)
      }

      assert Trie.get(trie, <<0x01::4>>) == "cool"
      assert Trie.get(trie, <<0x01::4, 0x00::4>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x00::4, 0x02::4>>) == "hi"
      assert Trie.get(trie, <<0x01::4, 0x00::4, 0x0::43>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x01::4>>) == nil
    end

    test "for a trie with encoded nodes", %{db: db} do
      long_string = Enum.join(for _ <- 1..60, do: "A")

      trie = Trie.new(db)

      trie = %{
        trie
        | root_hash:
            [0x01, 0x02]
            |> extension_node([0x03] |> leaf_node(long_string) |> ExRLP.encode() |> store(db))
            |> ExRLP.encode()
            |> store(db)
      }

      assert Trie.get(trie, <<0x01::4>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x02::4>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4>>) == long_string
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4, 0x04::4>>) == nil
    end
  end

  describe "update trie" do
    test "add a leaf to an empty tree", %{db: db} do
      trie = Trie.new(db)

      trie_2 = Trie.update(trie, <<0x01::4, 0x02::4, 0x03::4>>, "cool")

      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4>>) == nil
      assert Trie.get(trie_2, <<0x01::4>>) == nil
      assert Trie.get(trie_2, <<0x01::4, 0x02::4>>) == nil
      assert Trie.get(trie_2, <<0x01::4, 0x02::4, 0x03::4>>) == "cool"
      assert Trie.get(trie_2, <<0x01::4, 0x02::4, 0x03::4, 0x04::4>>) == nil
    end

    test "from blog post", %{db: db} do
      trie = Trie.new(db)

      trie_2 = Trie.update(trie, <<0x01::4, 0x01::4, 0x02::4>>, "hello")

      assert trie_2.root_hash ==
               <<253, 254, 116, 63, 177, 182, 47, 113, 12, 215, 156, 210, 120, 194, 126, 203, 245,
                 185, 190, 106, 252, 55, 165, 227, 244, 197, 162, 154, 240, 232, 98, 109>>
    end

    test "update a leaf value (when stored directly)", %{db: db} do
      trie = Trie.new(db, leaf_node([0x01, 0x02], "first"))
      trie_2 = Trie.update(trie, <<0x01::4, 0x02::4>>, "second")

      assert Trie.get(trie, <<0x01::4, 0x02::4>>) == "first"
      assert Trie.get(trie_2, <<0x01::4, 0x02::4>>) == "second"
    end

    test "update a leaf value (when stored in ets)", %{db: db} do
      long_string = Enum.join(for _ <- 1..60, do: "A")
      long_string_2 = Enum.join(for _ <- 1..60, do: "B")

      trie = Trie.new(db, [0x01, 0x02] |> leaf_node(long_string) |> ExRLP.encode() |> store(db))
      trie_2 = Trie.update(trie, <<0x01::4, 0x02::4>>, long_string_2)

      assert Trie.get(trie, <<0x01::4, 0x02::4>>) == long_string
      assert Trie.get(trie_2, <<0x01::4, 0x02::4>>) == long_string_2
    end

    test "update branch under ext node", %{db: db} do
      trie =
        db
        |> Trie.new()
        |> Trie.update(<<1::4, 2::4>>, "first")
        |> Trie.update(<<1::4, 2::4, 3::4>>, <<"cool">>)

      trie_2 = Trie.update(trie, <<1::4, 2::4, 3::4>>, <<"cooler">>)

      assert Trie.get(trie, <<1::4, 2::4, 3::4>>) == <<"cool">>
      assert Trie.get(trie_2, <<1::4>>) == nil
      assert Trie.get(trie_2, <<1::4, 2::4>>) == "first"
      assert Trie.get(trie_2, <<1::4, 2::4, 3::4>>) == <<"cooler">>
      assert Trie.get(trie_2, <<1::4, 2::4, 3::4, 4::4>>) == nil
    end

    test "update multiple keys", %{db: db} do
      trie =
        db
        |> Trie.new()
        |> Trie.update(<<0x01::4, 0x02::4, 0x03::4>>, "a")
        |> Trie.update(<<0x01::4, 0x02::4, 0x03::4, 0x04::4>>, "b")
        |> Trie.update(<<0x01::4, 0x02::4, 0x04::4>>, "c")
        |> Trie.update(<<0x01::size(256)>>, "d")

      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4>>) == "a"
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4, 0x04::4>>) == "b"
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x04::4>>) == "c"
      assert Trie.get(trie, <<0x01::size(256)>>) == "d"
    end

    test "a set of updates", %{db: db} do
      trie =
        db
        |> Trie.new()
        |> Trie.update(<<5::4, 7::4, 10::4, 15::4, 15::4>>, "a")
        |> Trie.update(<<5::4, 11::4, 0::4, 0::4, 14::4>>, "b")
        |> Trie.update(<<5::4, 10::4, 0::4, 0::4, 14::4>>, "c")
        |> Trie.update(<<4::4, 10::4, 0::4, 0::4, 14::4>>, "d")
        |> Trie.update(<<5::4, 10::4, 1::4, 0::4, 14::4>>, "e")

      assert Trie.get(trie, <<5::4, 7::4, 10::4, 15::4, 15::4>>) == "a"
      assert Trie.get(trie, <<5::4, 11::4, 0::4, 0::4, 14::4>>) == "b"
      assert Trie.get(trie, <<5::4, 10::4, 0::4, 0::4, 14::4>>) == "c"
      assert Trie.get(trie, <<4::4, 10::4, 0::4, 0::4, 14::4>>) == "d"
      assert Trie.get(trie, <<5::4, 10::4, 1::4, 0::4, 14::4>>) == "e"
    end

    test "yet another set of updates", %{db: db} do
      trie =
        db
        |> Trie.new()
        |> Trie.update(
          <<15::4, 10::4, 5::4, 11::4, 5::4, 2::4, 10::4, 9::4, 6::4, 13::4, 10::4, 3::4, 10::4,
            6::4, 7::4, 1::4>>,
          "a"
        )
        |> Trie.update(
          <<15::4, 11::4, 1::4, 14::4, 9::4, 7::4, 9::4, 5::4, 6::4, 15::4, 6::4, 11::4, 8::4,
            5::4, 2::4, 12::4>>,
          "b"
        )
        |> Trie.update(
          <<6::4, 1::4, 10::4, 10::4, 5::4, 7::4, 14::4, 3::4, 10::4, 0::4, 15::4, 3::4, 6::4,
            4::4, 5::4, 0::4>>,
          "c"
        )

      assert Trie.get(
               trie,
               <<15::4, 10::4, 5::4, 11::4, 5::4, 2::4, 10::4, 9::4, 6::4, 13::4, 10::4, 3::4,
                 10::4, 6::4, 7::4, 1::4>>
             ) == "a"

      assert Trie.get(
               trie,
               <<15::4, 11::4, 1::4, 14::4, 9::4, 7::4, 9::4, 5::4, 6::4, 15::4, 6::4, 11::4,
                 8::4, 5::4, 2::4, 12::4>>
             ) == "b"

      assert Trie.get(
               trie,
               <<6::4, 1::4, 10::4, 10::4, 5::4, 7::4, 14::4, 3::4, 10::4, 0::4, 15::4, 3::4,
                 6::4, 4::4, 5::4, 0::4>>
             ) == "c"
    end

    test "yet another set of updates now in memory", %{db: db} do
      trie =
        db
        |> Trie.new()
        |> Trie.update(
          <<15::4, 10::4, 5::4, 11::4, 5::4, 2::4, 10::4, 9::4, 6::4, 13::4, 10::4, 3::4, 10::4,
            6::4, 7::4, 1::4>>,
          "a"
        )
        |> Trie.update(
          <<15::4, 11::4, 1::4, 14::4, 9::4, 7::4, 9::4, 5::4, 6::4, 15::4, 6::4, 11::4, 8::4,
            5::4, 2::4, 12::4>>,
          "b"
        )
        |> Trie.update(
          <<6::4, 1::4, 10::4, 10::4, 5::4, 7::4, 14::4, 3::4, 10::4, 0::4, 15::4, 3::4, 6::4,
            4::4, 5::4, 0::4>>,
          "c"
        )

      assert Trie.get(
               trie,
               <<15::4, 10::4, 5::4, 11::4, 5::4, 2::4, 10::4, 9::4, 6::4, 13::4, 10::4, 3::4,
                 10::4, 6::4, 7::4, 1::4>>
             ) == "a"

      assert Trie.get(
               trie,
               <<15::4, 11::4, 1::4, 14::4, 9::4, 7::4, 9::4, 5::4, 6::4, 15::4, 6::4, 11::4,
                 8::4, 5::4, 2::4, 12::4>>
             ) == "b"

      assert Trie.get(
               trie,
               <<6::4, 1::4, 10::4, 10::4, 5::4, 7::4, 14::4, 3::4, 10::4, 0::4, 15::4, 3::4,
                 6::4, 4::4, 5::4, 0::4>>
             ) == "c"
    end

    test "acceptence testing", %{db: db} do
      {trie, values} =
        Enum.reduce(1..100, {Trie.new(db), []}, fn _, {trie, dict} ->
          key = random_key()
          value = random_value()

          updated_trie = Trie.update(trie, key, value)

          # Verify each key exists in our trie
          for {k, v} <- dict do
            assert Trie.get(trie, k) == v
          end

          {updated_trie, [{key, value} | dict]}
        end)

      # Next, assert tree is well formed
      assert Verifier.verify_trie(trie, values) == :ok
    end
  end

  @tag timeout: 100_000_000
  test "Read from random trie", %{db: db} do
    trie_list = get_random_tree_list(1000)
    trie = create_trie(trie_list, Trie.new(db))

    Enum.each(trie_list, fn {key, value} ->
      assert ^value = Trie.get(trie, key)
    end)
  end

  @tag timeout: 100_000_000
  test "Delete a node from trie", %{db: db} do
    trie =
      Trie.new(db)
      |> Trie.update(<<15::4, 10::4, 5::4, 11::4, 5::4, 1::4>>, "a")
      |> Trie.update(<<15::4, 11::4, 1::4, 14::4, 9::4, 7::4>>, "b")
      |> Trie.update(<<6::4, 1::4, 10::4, 10::4, 5::4, 7::4>>, "c")
      |> Trie.update(<<6::4, 1::4, 11::4, 10::4, 5::4, 7::4>>, "c")

    assert Trie.get(trie, <<15::4, 11::4, 1::4, 14::4, 9::4, 7::4>>) == "b"

    trie = Trie.delete(trie, <<15::4, 11::4, 1::4, 14::4, 9::4, 7::4>>)
    assert Trie.get(trie, <<15::4, 11::4, 1::4, 14::4, 9::4, 7::4>>) == nil
  end

  @tag timeout: 100_000_000
  test "Delete random nodes from random trie" do
    %{db: {_, db_ref1}} = init_trie1 = Trie.new(ETS.random_ets_db())
    %{db: {_, db_ref2}} = init_trie2 = Trie.new(ETS.random_ets_db())

    full_trie_list = Enum.uniq_by(get_random_tree_list(1000), fn {x, _} -> x end)

    full_trie =
      Enum.reduce(full_trie_list, init_trie1, fn {key, val}, acc_trie ->
        Trie.update(acc_trie, key, val)
      end)

    ## Reducing the full list trie randomly and
    ## getting the removed keys as well.
    {keys, sub_trie_list} = reduce_trie(500, full_trie_list)

    constructed_trie =
      Enum.reduce(sub_trie_list, init_trie2, fn {key, val}, acc_trie ->
        Trie.update(acc_trie, key, val)
      end)

    ## We are going to delete the previously reduced
    ## keys from the full trie. The result should be
    ## root hash equal to the constructed trie.
    reconstructed_trie =
      Enum.reduce(keys, full_trie, fn {key, _}, acc_trie ->
        Trie.delete(acc_trie, key)
      end)

    assert true = :ets.delete(db_ref1)
    assert true = :ets.delete(db_ref2)
    assert constructed_trie.root_hash == reconstructed_trie.root_hash
  end

  def leaf_node(key_end, value) do
    [HexPrefix.encode({key_end, true}), value]
  end

  def store(node_value, db) do
    node_hash = :keccakf1600.sha3_256(node_value)
    MerklePatriciaTree.DB.put!(db, node_hash, node_value)

    node_hash
  end

  def extension_node(shared_nibbles, node_hash) do
    [HexPrefix.encode({shared_nibbles, false}), node_hash]
  end

  def branch_node(branches, value) when length(branches) == 16 do
    {:branch, branches ++ [value]}
  end

  def blanks(n) do
    for _ <- 1..n, do: []
  end

  @doc """
  Creates trie from trie list by entering each element
  """
  def create_trie(trie_list, empty_trie) do
    Enum.reduce(trie_list, empty_trie, fn {key, val}, acc_trie ->
      Trie.update(acc_trie, key, val)
    end)
  end

  def random_hex_key() do
    <<:rand.uniform(15)::4, :rand.uniform(15)::4, :rand.uniform(15)::4, :rand.uniform(15)::4,
      :rand.uniform(15)::4, :rand.uniform(15)::4, :rand.uniform(15)::4, :rand.uniform(15)::4,
      :rand.uniform(15)::4, :rand.uniform(15)::4, :rand.uniform(15)::4, :rand.uniform(15)::4,
      :rand.uniform(15)::4, :rand.uniform(15)::4, :rand.uniform(15)::4, :rand.uniform(15)::4,
      :rand.uniform(15)::4, :rand.uniform(15)::4>>
  end

  def random_key() do
    <<:rand.uniform(@max_32_bits)::32, :rand.uniform(@max_32_bits)::32,
      :rand.uniform(@max_32_bits)::32, :rand.uniform(@max_32_bits)::32,
      :rand.uniform(@max_32_bits)::32, :rand.uniform(@max_32_bits)::32,
      :rand.uniform(@max_32_bits)::32, :rand.uniform(@max_32_bits)::32>>
  end

  def random_value(), do: Utils.random_string(40)

  def reduce_trie(num_nodes, list) do
    popup_random_from_trie(
      num_nodes,
      List.pop_at(list, Enum.random(0..(length(list) - 2))),
      {[], []}
    )
  end

  def popup_random_from_trie(0, _, acc), do: acc

  def popup_random_from_trie(num_nodes, {data, rest}, {keys, _}) do
    popup_random_from_trie(
      num_nodes - 1,
      List.pop_at(rest, Enum.random(0..(length(rest) - 2))),
      {keys ++ [data], rest}
    )
  end

  def get_random_tree_list(size) do
    for _ <- 0..size, do: {random_hex_key(), random_value()}
  end
end
