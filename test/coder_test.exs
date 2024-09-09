defmodule WITSML.CoderTest do
  use ExUnit.Case

  alias FnXML.Stream.NativeDataStruct, as: NDS

  def test_encode(map, opts) do
    NDS.encode(map, opts)
    |> Enum.to_list()
    |> IO.inspect(label: "NDS Encode")
    |> FnXML.Stream.to_xml(opts)
    |> Enum.join()
  end
  
  @tag :skip
  test "decodes a WITSML message" do
    # val = %{
    #   "wells" => %{
    #     :version => "v.test",
    #     :xmlns => "http:/www.witsml.org/schemas/1series",
    #     "well" => [
    #       %{:uid => "abc", "statusWell" => "active"},
    #       %{:uid => "123", "statusWell" => "active"}
    #     ]
    #   }
# }
    val = %{ "a" => %{"b" => "b_val"} } |> IO.inspect(label: "Input for decode witsml")

    |> test_encode(pretty: true, tag_from_parent: "root", text_only_children: true)
#    |> WITSML.Coder.map_to_xml()
    IO.puts("query encode: #{val}")
  end
end
