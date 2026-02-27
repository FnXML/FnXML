defmodule FnXML.Conformance.TestSuite do
  @moduledoc """
  Test suite management for W3C/OASIS XML Conformance Test Suite.

  Implements `FnConformance.TestSuite` behaviour to handle downloading,
  locating, and cleaning the xmlconf test data.

  The test suite tarball contains ~2,000 tests from multiple vendors
  (W3C, Sun, OASIS, IBM, etc.) covering valid, not-well-formed, invalid,
  and error test categories.
  """

  @behaviour FnConformance.TestSuite

  alias FnConformance.TestSuite.Downloader

  @xmlconf_url "https://www.w3.org/XML/Test/xmlts20130923.tar.gz"

  @impl true
  def name, do: "W3C/OASIS XML Conformance Test Suite"

  @impl true
  def suite_path do
    Path.join(base_dir(), "xmlconf")
  end

  @impl true
  def download do
    IO.puts("\n=== Downloading XML Conformance Test Suite ===\n")
    IO.puts("Source: #{@xmlconf_url}")

    case Downloader.tarball(@xmlconf_url, suite_path()) do
      {:ok, :downloaded} ->
        IO.puts("Download complete.")
        :ok

      {:ok, :exists} ->
        IO.puts("Test suite already downloaded at: #{suite_path()}")
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def available? do
    File.dir?(suite_path()) and
      File.exists?(Path.join(suite_path(), "xmlconf.xml"))
  end

  @impl true
  def clean do
    Downloader.clean(suite_path())
  end

  @doc """
  Check and report test suite availability.
  """
  @spec status() :: :available | :not_downloaded
  def status do
    if available?(), do: :available, else: :not_downloaded
  end

  defp base_dir do
    Application.app_dir(:fnxml, "priv/test_suites")
  rescue
    # Fallback for dev/test when app isn't fully started
    _ -> Path.join(File.cwd!(), "priv/test_suites")
  end
end
