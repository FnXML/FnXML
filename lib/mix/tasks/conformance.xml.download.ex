defmodule Mix.Tasks.Conformance.Xml.Download do
  @moduledoc """
  Download and manage the W3C/OASIS XML Conformance Test Suite.

  ## Usage

      mix conformance.xml.download            # Download the test suite
      mix conformance.xml.download --status   # Check availability
      mix conformance.xml.download --clean    # Remove downloaded test data
  """

  use Mix.Task

  @shortdoc "Download XML conformance test suite"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [status: :boolean, clean: :boolean]
      )

    Mix.Task.run("app.start")

    alias FnXML.Conformance.TestSuite

    cond do
      opts[:status] ->
        case TestSuite.status() do
          :available ->
            IO.puts("XML Conformance Test Suite: available")
            IO.puts("  Path: #{TestSuite.suite_path()}")

            disk = FnConformance.TestSuite.Downloader.disk_usage(TestSuite.suite_path())
            if disk, do: IO.puts("  Size: #{disk}")

          :not_downloaded ->
            IO.puts("XML Conformance Test Suite: not downloaded")
            IO.puts("  Download with: mix conformance.xml.download")
        end

      opts[:clean] ->
        IO.puts("Removing XML conformance test suite...")

        case TestSuite.clean() do
          :ok -> IO.puts("Removed.")
          {:error, reason} -> IO.puts("Error: #{inspect(reason)}")
        end

      true ->
        case TestSuite.download() do
          :ok -> :ok
          {:error, reason} -> Mix.raise("Download failed: #{inspect(reason)}")
        end
    end
  end
end
