defmodule Chatbot.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :chatbot

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end

  def ingest do
    # get the urls of the 100 most downloaded packages (it's paginated)
    # packages =
    #   Req.get!("https://hex.pm/api/packages?sort=downloads&page=1").body
    #   |> Enum.map(&Map.take(&1, ["name", "docs_html_url", "latest_stable_version"]))
    #   |> Enum.reject(&(&1["docs_html_url"] == nil))

    # add elixir docs
    packages =
      ["carbonite"]
      |> Enum.map(
        &%{
          "name" => &1,
          "latest_stable_version" => "0.15.0"
        }
      )

    # packages = [%{"name" => "elixir", "docs_html_url" = "https://hexdocs.pm/elixir/"} | packages]

    num_packages = 3

    docs_urls =
      Enum.take(packages, num_packages)
      |> Enum.map(&"https://repo.hex.pm/docs/#{&1["name"]}-#{&1["latest_stable_version"]}.tar.gz")

    code_urls =
      Enum.take(packages, num_packages)
      |> Enum.map(
        &"https://repo.hex.pm/tarballs/#{&1["name"]}-#{&1["latest_stable_version"]}.tar"
      )

    docs =
      Enum.flat_map(docs_urls, fn url ->
        req = Req.new(url: url) |> ReqHex.attach()

        tarball = Req.get!(req).body

        for {file, content} <- tarball, text_file?(file) do
          file = to_string(file)
          %{source: file, document: content}
        end
      end)

    code =
      Enum.flat_map(code_urls, fn url ->
        req = Req.new(url: url) |> ReqHex.attach()

        tarball = Req.get!(req).body

        for {file, content} <- tarball["contents.tar.gz"] do
          %{source: file, document: content}
        end
      end)

    Chatbot.Rag.index(docs ++ code)
  end

  defp text_file?(file) when is_list(file) do
    file
    |> to_string()
    |> String.ends_with?([".html", ".md", ".txt"])
  end

  defp text_file?(file) when is_binary(file) do
    file
    |> String.ends_with?([".html", ".md", ".txt"])
  end
end
