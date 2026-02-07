defmodule Slouch.Bots.Bot do
  use Ash.Resource,
    otp_app: :slouch,
    domain: Slouch.Bots,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "bots"
    repo Slouch.Repo

    references do
      reference :user, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :description, :handler_module, :is_active]
      argument :user_id, :uuid, allow_nil?: false
      change manage_relationship(:user_id, :user, type: :append)
    end

    read :active do
      filter expr(is_active == true)
      prepare build(load: [:user])
    end

    read :by_name do
      argument :name, :string, allow_nil?: false
      filter expr(name == ^arg(:name))
      prepare build(load: [:user])
      get? true
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      allow_nil? true
      public? true
    end

    attribute :handler_module, :string do
      allow_nil? false
      public? true
    end

    attribute :is_active, :boolean do
      allow_nil? false
      default true
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Slouch.Accounts.User do
      allow_nil? false
    end
  end

  identities do
    identity :unique_name, [:name]
    identity :unique_user, [:user_id]
  end
end
