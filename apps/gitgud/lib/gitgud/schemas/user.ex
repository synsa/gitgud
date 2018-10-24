defmodule GitGud.User do
  @moduledoc """
  User account schema and helper functions.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  import Comeonin.Argon2, only: [add_hash: 1, check_pass: 2]

  alias GitGud.DB

  alias GitGud.Repo
  alias GitGud.SSHKey
  alias GitGud.Email

  schema "users" do
    field     :username,      :string
    field     :name,          :string
    has_many  :emails,        Email, on_delete: :delete_all
    has_many  :repos,         Repo, foreign_key: :owner_id
    has_many  :ssh_keys,      SSHKey, on_delete: :delete_all
    field     :password,      :string, virtual: true
    field     :password_hash, :string
    timestamps()
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    username: binary,
    name: binary,
    emails: [Email.t],
    repos: [Repo.t],
    ssh_keys: [SSHKey.t],
    password: binary,
    password_hash: binary,
    inserted_at: NaiveDateTime.t,
    updated_at: NaiveDateTime.t
  }

  @doc """
  Creates a new user with the given `params`.
  """
  @spec create(map|keyword) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def create(params) do
    changeset = registration_changeset(%__MODULE__{}, Map.new(params))
    DB.insert(changeset)
  end

  @doc """
  Similar to `create/1`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec create!(map|keyword) :: t
  def create!(params) do
    case create(params) do
      {:ok, user} -> user
      {:error, changeset} -> raise Ecto.InvalidChangesetError, action: changeset.action, changeset: changeset
    end
  end

  @doc """
  Updates the given `user` with the given `params`.
  """
  @spec update(t, atom, map|keyword) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def update(%__MODULE__{} = user, changeset_type, params) do
    DB.update(update_changeset(user, changeset_type, Map.new(params)))
  end

  @doc """
  Similar to `update/2`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec update!(t, atom, map|keyword) :: t
  def update!(%__MODULE__{} = user, changeset_type, params) do
    DB.update!(update_changeset(user, changeset_type, Map.new(params)))
  end

  @doc """
  Deletes the given `user`.
  """
  @spec delete(t) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def delete(%__MODULE__{} = user) do
    DB.delete(user)
  end

  @doc """
  Similar to `delete!/1`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec delete!(t) :: t
  def delete!(%__MODULE__{} = user) do
    DB.delete!(user)
  end

  @doc """
  Returns a registration changeset for the given `params`.
  """
  @spec registration_changeset(t, map) :: Ecto.Changeset.t
  def registration_changeset(%__MODULE__{} = user, params \\ %{}) do
    user
    |> cast(params, [:username, :name, :password])
    |> cast_assoc(:emails, required: true)
    |> validate_required([:username, :name, :password])
    |> validate_username()
    |> validate_password()
  end

  @doc """
  Returns a profile changeset for the given `params`.
  """
  @spec profile_changeset(map) :: Ecto.Changeset.t
  def profile_changeset(%__MODULE__{} = user, params \\ %{}) do
    user
    |> cast(params, [:name])
    |> validate_required([:name])
  end

  @doc """
  Returns the matching user for the given credentials; elsewhise returns `nil`.
  """
  @spec check_credentials(binary, binary) :: t | nil
  def check_credentials(email_or_username, password) do
    query = from u in __MODULE__,
           join: e in assoc(u, :emails),
       or_where: u.username == ^email_or_username,
       or_where: e.verified == true and e.email == ^email_or_username,
        preload: [emails: e]
    case check_pass(DB.one(query), password) do
      {:ok, user} -> user
      {:error, _reason} -> nil
    end
  end

  #
  # Helpers
  #

  defp update_changeset(user, :profile, params), do: profile_changeset(user, params)

  defp validate_username(changeset) do
    changeset
    |> validate_length(:username, min: 3, max: 24)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_-]+$/)
    |> unique_constraint(:username)
  end

  defp validate_password(changeset) do
    changeset
    |> validate_length(:password, min: 6)
    |> put_password_hash(:password)
  end

  defp put_password_hash(changeset, field) do
    if password = changeset.valid? && get_field(changeset, field),
      do: change(changeset, add_hash(password)),
    else: changeset
  end
end
