defmodule Slouch.Chat.DmReaction do
  use Ash.Resource,
    otp_app: :slouch,
    domain: Slouch.Chat,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "dm_reactions"
    repo Slouch.Repo

    references do
      reference :direct_message, on_delete: :delete
      reference :user, on_delete: :delete
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
    belongs_to :direct_message, Slouch.Chat.DirectMessage, allow_nil?: false
    belongs_to :user, Slouch.Accounts.User, allow_nil?: false
  end

  identities do
    identity :unique_dm_reaction, [:direct_message_id, :user_id, :emoji]
  end

  actions do
    defaults [:read, :destroy]

    create :react do
      accept [:emoji]
      argument :direct_message_id, :uuid, allow_nil?: false
      change manage_relationship(:direct_message_id, :direct_message, type: :append)
      change relate_actor(:user)
    end

    read :by_direct_message do
      argument :direct_message_id, :uuid, allow_nil?: false
      filter expr(direct_message_id == ^arg(:direct_message_id))
      prepare build(load: [:user])
    end
  end
end
