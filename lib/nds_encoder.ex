defmodule FnXML.Stream.NativeDataStruct.Encoder do
  @moduledoc """
  This Module defines the NativeDataStruct.Encoder Behaviour which is used to
  encode a Native Data Struct (NDS) to an XML stream.
  """

  alias FnXML.Stream.NativeDataStruct, as: NDS

  @doc """
  the meta callback is used to encode the tag, namespace and attributes for the NDS struct
  """
  @callback meta(nds :: NDS.t, map :: map) :: NDS.t

  @doc """
  the content callback is used to encode the content for the NDS struct.  This typically includes
  any text elements or child elements.

  The content is normally a list of binaries and NDS structs, where
  the binaries are the text elements and the NDS structs are the child
  elements.  The order of the elements is representative of their order in XML.
  """
  @callback content(nds :: NDS.t, map :: map) :: NDS.t


  def encode(map, opts) do
    module = Keyword.get(opts, :module, NDS.Encoder.Default)

    %NDS{ private: %{opts: opts} }
    |> module.meta(map)
    |> module.content(map)
  end
end
