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
          "docs_html_url" => "https://hexdocs.pm/#{&1}/",
          "latest_stable_version" => "0.15.0"
        }
      )

    # packages = [%{"name" => "elixir", "docs_html_url" = "https://hexdocs.pm/elixir/"} | packages]

    num_packages = 3
    docs_urls = Enum.take(packages, num_packages) |> Enum.map(& &1["docs_html_url"])

    code_urls =
      Enum.take(packages, num_packages)
      |> Enum.map(
        &"https://repo.hex.pm/tarballs/#{&1["name"]}-#{&1["latest_stable_version"]}.tar"
      )

    package_names = Enum.take(packages, num_packages) |> Enum.map(& &1["name"])

    validate_first_level = fn
      {:ok, url}, _state, _opts ->
        case URI.parse(url).path do
          nil ->
            {:error, "no path"}

          path ->
            if Path.split(path) |> Enum.count() > 3 do
              {:error, "too deep"}
            else
              {:ok, url}
            end
        end

      value, _state, _opts ->
        value
    end

    validate_same_package = fn
      {:ok, url}, _state, _opts ->
        package =
          case URI.parse(url).path do
            nil ->
              nil

            path ->
              ["/", package | _path] = Path.split(path)
              package
          end

        if package in package_names do
          {:ok, url}
        else
          {:error, "different package"}
        end

      value, _state, _opts ->
        value
    end

    hexpm_prefetch = fn url, state, opts ->
      {:ok, url}
      |> Hop.validate_hostname(state, opts)
      |> Hop.validate_scheme(state, opts)
      |> Hop.validate_content(state, opts)
      |> validate_first_level.(state, opts)
      |> validate_same_package.(state, opts)
    end

    hexpm_next = fn url, %{body: body}, state, opts ->
      links =
        Hop.fetch_links(url, body,
          crawl_query?: opts[:crawl_query?],
          crawl_fragment?: opts[:crawl_fragment?]
        )

      refresh =
        Floki.parse_document!(body)
        |> Floki.find("html head meta")
        |> Floki.attribute("content")
        |> Enum.find(&String.contains?(&1, " url="))

      if refresh do
        [_, site] = String.split(refresh, " url=")

        refresh_url = "#{url}#{site}"

        {:ok, [refresh_url | links], state}
      else
        {:ok, links, state}
      end
    end

    docs =
      Enum.flat_map(docs_urls, fn url ->
        Hop.new(url)
        |> Hop.prefetch(&hexpm_prefetch.(&1, &2, &3))
        |> Hop.next(&hexpm_next.(&1, &2, &3, &4))
        |> Hop.stream()
        |> Stream.map(fn h ->
          Process.sleep(300)
          h
        end)
        |> Enum.map(fn {url, response, _state} ->
          doc =
            response.body
            |> Readability.article()
            |> Readability.readable_text()

          IO.puts(url)

          %{source: url, document: doc}
        end)
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
end
