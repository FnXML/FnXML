defmodule FnXML.MixProject do
  use Mix.Project

  @version "0.1.0"

  @doc """
  Check if NIF should be enabled.

  NIF is disabled when:
  1. FNXML_NIF=false environment variable is set
  2. Parent project specifies `{:fnxml, "~> x.x", nif: false}` in deps
  """
  def nif_enabled? do
    cond do
      System.get_env("FNXML_NIF") == "false" -> false
      get_parent_nif_option() == false -> false
      true -> true
    end
  end

  defp get_parent_nif_option do
    try do
      # Get the parent project's config to check for nif: false option
      case Mix.Project.config()[:app] do
        :fnxml ->
          # We are the main project, check if any parent loaded us with nif: false
          nil

        _other_app ->
          # We're being compiled as a dependency, check parent's deps
          Mix.Project.config()[:deps]
          |> Enum.find(fn
            {:fnxml, opts} when is_list(opts) -> true
            {:fnxml, _version, opts} when is_list(opts) -> true
            _ -> false
          end)
          |> case do
            {:fnxml, opts} -> Keyword.get(opts, :nif, nil)
            {:fnxml, _version, opts} -> Keyword.get(opts, :nif, nil)
            _ -> nil
          end
      end
    rescue
      _ -> nil
    end
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def project do
    [
      app: :fnxml,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Test coverage
      test_coverage: [tool: ExCoveralls],

      # Docs
      name: "FnXML",
      source_url: "https://github.com/yourname/fnxml",
      docs: docs(),
      description: description(),
      package: package()
    ]
  end

  defp description do
    "High-performance streaming XML parser for Elixir with optional Zig NIF acceleration."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/yourname/fnxml"},
      files: ~w(lib native .formatter.exs mix.exs README* LICENSE*)
    ]
  end

  defp docs do
    [
      main: "FnXML",
      extras: ["README.md", "usage-rules.md"],
      groups_for_modules: [
        Core: [FnXML, FnXML.Parser, FnXML.Stream],
        "DOM API": [FnXML.DOM, FnXML.DOM.Document, FnXML.DOM.Element, FnXML.DOM.Builder, FnXML.DOM.Serializer],
        "SAX API": [FnXML.SAX, FnXML.SAX.Handler],
        "StAX API": [FnXML.StAX, FnXML.StAX.Reader, FnXML.StAX.Writer],
        Namespaces: [FnXML.Namespaces, FnXML.Namespaces.Context, FnXML.Namespaces.QName, FnXML.Namespaces.Resolver, FnXML.Namespaces.Validator],
        DTD: [FnXML.DTD, FnXML.DTD.Model, FnXML.DTD.Parser],
        Utilities: [FnXML.Element, FnXML.Stream.SimpleForm]
      ]
    ]
  end

  def application do
    [extra_applications: [:logger, :xmerl]]
  end

  defp deps do
    base_deps = [
      {:mix_test_watch, "~> 1.2", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:nimble_parsec, "~> 1.4"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:benchee, "~> 1.3", only: :dev},
      {:benchee_html, "~> 1.0", only: :dev},
      {:saxy, "~> 1.5", only: :dev},
      {:erlsom, "~> 1.5", only: :dev},
      {:nx, "~> 0.7", only: :dev}
    ]

    if nif_enabled?() do
      base_deps ++ [{:zigler, "~> 0.13", runtime: false}]
    else
      base_deps
    end
  end
end
