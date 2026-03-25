defmodule ExBitstringStatusList.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/bawolf/ex_bitstring_status_list"

  def project do
    [
      app: :ex_bitstring_status_list,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description:
        "Bitstring Status List entry, credential, and revocation verification helpers for Elixir.",
      package: package(),
      source_url: @source_url,
      homepage_url: @source_url,
      docs: [
        main: "readme",
        extras: [
          "README.md",
          "SUPPORTED_FEATURES.md",
          "INTEROP_NOTES.md",
          "FIXTURE_POLICY.md",
          "RELEASE_CHECKLIST.md",
          "CHANGELOG.md",
          "LICENSE"
        ],
        source_ref: "v#{@version}",
        source_url: @source_url
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {ExBitstringStatusList.Application, []}
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.37", only: :dev, runtime: false},
      {:jason, "~> 1.4"}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Bryant Wolf"],
      links: %{
        "GitHub" => @source_url,
        "Hex" => "https://hex.pm/packages/ex_bitstring_status_list",
        "Docs" => "https://hexdocs.pm/ex_bitstring_status_list",
        "CI" => "#{@source_url}/actions/workflows/ci.yml",
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md",
        "Fixture Policy" => "#{@source_url}/blob/main/FIXTURE_POLICY.md",
        "Interop Notes" => "#{@source_url}/blob/main/INTEROP_NOTES.md",
        "Supported Features" => "#{@source_url}/blob/main/SUPPORTED_FEATURES.md",
        "License" => "#{@source_url}/blob/main/LICENSE"
      }
    ]
  end
end
