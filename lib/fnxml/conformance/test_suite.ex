defmodule FnXML.Conformance.TestSuite do
  @moduledoc """
  Manages download of W3C/OASIS XML Conformance Test Suite.
  """

  @behaviour FnConformance.TestSuite

  @test_suite_url "https://www.w3.org/XML/Test/xmlts20130923.tar.gz"

  @impl true
  def name, do: "W3C/OASIS XML Conformance Test Suite"

  @impl true
  def suite_path do
    Path.join([File.cwd!(), "priv", "test_suites", "xmlconf"])
  end

  @impl true
  def download do
    dest = suite_path()

    if File.dir?(dest) do
      :ok
    else
      parent = Path.dirname(dest)
      File.mkdir_p!(parent)
      tarball = Path.join(parent, "xmlts.tar.gz")

      IO.puts("    Downloading from #{@test_suite_url}...")

      with {_, 0} <-
             System.cmd("curl", ["-L", "-o", tarball, "--silent", "--show-error", @test_suite_url],
               stderr_to_stdout: true
             ),
           {_, 0} <-
             System.cmd("tar", ["-xzf", tarball, "-C", parent],
               stderr_to_stdout: true
             ) do
        File.rm(tarball)
        IO.puts("    Downloaded successfully")
        :ok
      else
        {error, _} ->
          File.rm(tarball)
          {:error, error}
      end
    end
  end

  @impl true
  def available? do
    File.dir?(suite_path()) and File.exists?(Path.join(suite_path(), "xmlconf.xml"))
  end

  @impl true
  def clean do
    FnConformance.TestSuite.Downloader.clean(suite_path())
  end
end
