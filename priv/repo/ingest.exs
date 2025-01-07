# Script for ingesting embeddings into the database. You can run it as:
#
#     mix run priv/repo/ingest.exs

# get the urls of the 100 most downloaded packages (it's paginated)
# packages =
#   Req.get!("https://hex.pm/api/packages?sort=downloads&page=1").body
#   |> Enum.map(&Map.take(&1, ["name", "docs_html_url"]))
#   |> Enum.reject(&(&1["docs_html_url"] == nil))

# add elixir docs
packages =
  ["phoenix_live_view"]
  |> Enum.map(&%{"name" => &1, "docs_html_url" => "https://hexdocs.pm/#{&1}/"})

# packages = [%{"name" => "elixir", "docs_html_url" = "https://hexdocs.pm/elixir/"} | packages]

urls = Enum.take(packages, 3) |> Enum.map(& &1["docs_html_url"])
package_names = Enum.take(packages, 3) |> Enum.map(& &1["name"])

validate_first_level = fn
  {:ok, url}, _state, _opts ->
    package =
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
  Enum.flat_map(urls, fn url ->
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

Chatbot.Rag.index(docs)
