defmodule Slouch.Chat.ConversationParticipant do
  use Ash.Resource,
    otp_app: :slouch,
    domain: Slouch.Chat,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "conversation_participants"
    repo Slouch.Repo

    references do
      reference :conversation, on_delete: :delete
      reference :user, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept []
      argument :conversation_id, :uuid, allow_nil?: false
      argument :user_id, :uuid, allow_nil?: false

      change manage_relationship(:conversation_id, :conversation, type: :append)
      change manage_relationship(:user_id, :user, type: :append)
    end
  end

  attributes do
    uuid_primary_key :id
    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :conversation, Slouch.Chat.Conversation, allow_nil?: false
    belongs_to :user, Slouch.Accounts.User, allow_nil?: false
  end

  identities do
    identity :unique_participant, [:conversation_id, :user_id]
  end
end
