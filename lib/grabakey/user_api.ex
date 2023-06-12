defmodule Grabakey.UserApi do
  alias Grabakey.UserDb
  alias Grabakey.Mailer

  @max_body_len 256
  @token_header "gak-token"
  @headers %{"content-type" => "text/plain"}
  @fail_delay 1000

  def init(req, {:new, _} = state) do
    method = :cowboy_req.method(req)
    dos_delay(method, state)

    case method do
      "POST" ->
        create_user(req, state)

      _ ->
        fail_delay()
        req = :cowboy_req.reply(404, req)
        {:ok, req, state}
    end
  end

  def init(req, {:id, _} = state) do
    method = :cowboy_req.method(req)
    dos_delay(method, state)

    case method do
      "GET" ->
        get_pubkey(req, state)

      "PUT" ->
        update_pubkey(req, state)

      "DELETE" ->
        delete_user(req, state)

      _ ->
        fail_delay()
        req = :cowboy_req.reply(404, req)
        {:ok, req, state}
    end
  end

  def create_user(req, {_, %{mailer: mailer}} = state) do
    len = :cowboy_req.body_length(req)

    # find_by_email required to fetch the real id on conflict update
    # user.token to get the real updated token even if race condition
    with {true, req} <- {is_integer(len), req},
         {true, req} <- {len > 3 and len <= @max_body_len, req},
         {{:ok, email, req}, _} <- {:cowboy_req.read_body(req), req},
         {{:ok, user}, email, req} <- {UserDb.create_from_email(email), email, req},
         {user, token, req} <- {UserDb.find_by_email(email), user.token, req},
         {true, user, token, req} <- {user != nil, user, token, req},
         {{:ok, _res}, req} <- {Mailer.deliver(user, token, mailer), req} do
      req = :cowboy_req.reply(200, @headers, req)
      {:ok, req, state}
    else
      _res ->
        fail_delay()
        req = :cowboy_req.reply(400, req)
        {:ok, req, state}
    end
  end

  def delete_user(req, state) do
    id = :cowboy_req.binding(:id, req)
    token = :cowboy_req.header(@token_header, req)

    with {true, req} <- {is_binary(token), req},
         {{:ok, _}, req} <- {Ecto.ULID.cast(id), req},
         {{:ok, _}, req} <- {Ecto.ULID.cast(token), req},
         {user, req} <- {UserDb.find_by_id_and_token(id, token), req},
         {true, user, req} <- {user != nil, user, req},
         {{:ok, _res}, req} <- {UserDb.delete(user), req} do
      req = :cowboy_req.reply(200, @headers, req)
      {:ok, req, state}
    else
      _res ->
        fail_delay()
        req = :cowboy_req.reply(400, req)
        {:ok, req, state}
    end
  end

  def update_pubkey(req, state) do
    len = :cowboy_req.body_length(req)
    id = :cowboy_req.binding(:id, req)
    token = :cowboy_req.header(@token_header, req)

    with {true, req} <- {is_binary(token), req},
         {{:ok, _}, req} <- {Ecto.ULID.cast(id), req},
         {{:ok, _}, req} <- {Ecto.ULID.cast(token), req},
         {true, req} <- {is_integer(len), req},
         {true, req} <- {len > 0 and len <= @max_body_len, req},
         {{:ok, pubkey, req}, _} <- {:cowboy_req.read_body(req), req},
         {true, pubkey, req} <- {valid_pubkey?(pubkey), pubkey, req},
         {user, req} <- {UserDb.find_by_id_and_token(id, token), req},
         {true, user, req} <- {user != nil, user, req},
         {{:ok, _res}, req} <- {UserDb.update_pubkey(user, pubkey), req} do
      req = :cowboy_req.reply(200, @headers, req)
      {:ok, req, state}
    else
      _res ->
        fail_delay()
        req = :cowboy_req.reply(400, req)
        {:ok, req, state}
    end
  end

  def get_pubkey(req, state) do
    id = :cowboy_req.binding(:id, req)

    with {{:ok, _}, req} <- {Ecto.ULID.cast(id), req},
         {user, req} <- {UserDb.find_by_id(id), req},
         {true, user, req} <- {user != nil, user, req} do
      req = :cowboy_req.reply(200, @headers, user.pubkey, req)
      {:ok, req, state}
    else
      _res ->
        fail_delay()
        req = :cowboy_req.reply(400, req)
        {:ok, req, state}
    end
  end

  defp dos_delay(method, {_, %{delay: delay}}) do
    case method do
      "PUT" -> :timer.sleep(delay)
      "POST" -> :timer.sleep(delay)
      "DELETE" -> :timer.sleep(delay)
      "GET" -> :nop
    end
  end

  defp fail_delay() do
    :timer.sleep(@fail_delay)
  end

  defp valid_pubkey?(pubkey) do
    case String.split(pubkey, " ") do
      ["ssh-ed25519", _, _] -> true
      _ -> false
    end
  end
end
