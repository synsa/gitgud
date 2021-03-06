defmodule GitGud.Web.EmailView do
  @moduledoc false
  use GitGud.Web, :view

  alias GitGud.Email
  alias GitGud.User

  import Phoenix.HTML.Tag

  @spec email_tags(Plug.Conn.t, User.t, Email.t) :: binary
  def email_tags(conn, user, email) do
    tags = []
    tags = if tag = primary_tag(conn, user, email), do: [tag|tags], else: tags
    tags = if tag = public_tag(conn, user, email), do: [tag|tags], else: tags
    tags = if tag = verified_tag(conn, user, email), do: [tag|tags], else: tags
    content_tag(:div, [class: "field is-grouped is-grouped-multiline"], do:
      for tag <- Enum.reverse(tags) do
        content_tag(:div, [class: "control"], do: tag)
      end
    )
  end

  @spec title(atom, map) :: binary
  def title(:index, _assigns), do: "Settings · Emails"

  #
  # Helpers
  #

  defp primary_tag(_conn, %User{id: user_id, primary_email_id: email_id}, %Email{id: email_id, user_id: user_id}) do
    content_tag(:span, [class: "tag is-primary"], do: "Primary")
  end

  defp primary_tag(_conn, %User{}, %Email{}), do: nil

  defp public_tag(_conn, %User{id: user_id, public_email_id: email_id}, %Email{id: email_id, user_id: user_id}) do
    content_tag(:span, [class: "tag is-info"], do: "Public")
  end

  defp public_tag(_conn, %User{}, %Email{}), do: nil

  defp verified_tag(_conn, %User{id: user_id}, %Email{user_id: user_id, verified: true}) do
    content_tag(:span, [class: "tag"], do: "Verified")
  end

  defp verified_tag(conn, %User{id: user_id}, %Email{user_id: user_id} = email) do
    form_for(conn, Routes.email_path(conn, :send_verification), [as: :email], &unverified_tag_fields(&1, email))
  end

  defp verified_tag(_conn, %User{}, %Email{}), do: nil

  defp unverified_tag_fields(form, email) do
    [
      hidden_input(form, :id, value: email.id),
      content_tag(:div, [class: "tags has-addons"], do: [
        content_tag(:span, [class: "tag"], do: "Unverified"),
        submit(content_tag(:span, content_tag(:i, [], class: "fa fa-sync"), [class: "icon"]), [class: "button tag tooltip is-warning", data_tooltip: "Send verification email"])
      ])
    ]
  end
end
