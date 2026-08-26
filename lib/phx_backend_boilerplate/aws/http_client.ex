defmodule PhxBackendBoilerplate.AWS.HTTPClient do
  @moduledoc """
  `ExAws.Request.HttpClient` implementation using Req + the app Finch pool.

  Prefer this over Hackney so outbound AWS calls share the same transport as
  `PhxBackendBoilerplate.HTTP`.
  """

  @behaviour ExAws.Request.HttpClient

  @finch PhxBackendBoilerplate.Finch

  @impl ExAws.Request.HttpClient
  def request(method, url, body, headers, _http_opts) do
    case Req.request(
           method: method,
           url: url,
           body: body,
           headers: headers,
           finch: [name: @finch],
           decode_body: false,
           retry: false
         ) do
      {:ok, response} ->
        {:ok,
         %{
           status_code: response.status,
           headers: Req.get_headers_list(response),
           body: response.body
         }}

      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end
end
