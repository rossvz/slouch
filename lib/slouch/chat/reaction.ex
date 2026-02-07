defmodule Slouch.Chat.Reaction do
  use Ash.Resource,
    otp_app: :slouch,
    domain: Slouch.Chat,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "reactions"
    repo Slouch.Repo

    references do
      reference :message, on_delete: :delete
      reference :user, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :react do
      accept [:emoji]
      argument :message_id, :uuid, allow_nil?: false
      change manage_relationship(:message_id, :message, type: :append)
      change relate_actor(:user)
    end

    read :by_message do
      argument :message_id, :uuid, allow_nil?: false
      filter expr(message_id == ^arg(:message_id))
      prepare build(load: [:user])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :emoji, :string do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :message, Slouch.Chat.Message, allow_nil?: false
    belongs_to :user, Slouch.Accounts.User, allow_nil?: false
  end

  identities do
    identity :unique_reaction, [:message_id, :user_id, :emoji]
  end
end
