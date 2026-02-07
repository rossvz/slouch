defmodule Slouch.Chat.Channel do
  use Ash.Resource,
    otp_app: :slouch,
    domain: Slouch.Chat,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "channels"
    repo Slouch.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :topic]
    end

    update :update do
      accept [:name, :topic]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :topic, :string do
      allow_nil? true
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :messages, Slouch.Chat.Message
    has_many :memberships, Slouch.Chat.Membership

    many_to_many :members, Slouch.Accounts.User do
      through Slouch.Chat.Membership
      source_attribute_on_join_resource :channel_id
      destination_attribute_on_join_resource :user_id
    end
  end

  identities do
    identity :unique_name, [:name]
  end
end
