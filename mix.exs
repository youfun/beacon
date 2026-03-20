defmodule Beacon.MixProject do
  use Mix.Project

  def project do
    [
      app: :beacon,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Beacon.Application, []}
    ]
  end

  defp deps do
    [
      {:bandit, "~> 1.6"},
      {:plug, "~> 1.16"},
      {:earmark, "~> 1.4"},
      {:file_system, "~> 1.0"},
      {:burrito, "~> 1.0"}
    ]
  end

  defp releases do
    [
      beacon: [
        steps: [:assemble, &Burrito.wrap/1],
        burrito: [
          targets: [
            linux:       [os: :linux,   cpu: :x86_64],
            macos_arm:   [os: :darwin,  cpu: :aarch64],
            macos_intel: [os: :darwin,  cpu: :x86_64],
            windows:     [os: :windows, cpu: :x86_64]
          ]
        ]
      ]
    ]
  end
end
