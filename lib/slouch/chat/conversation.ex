defmodule Slouch.Chat.Conversation do
  use Ash.Resource,
    otp_app: :slouch,
    domain: Slouch.Chat,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "conversations"
    repo Slouch.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
    end

    read :my_conversations do
      argument :user_id, :uuid, allow_nil?: false

      filter expr(exists(participants, user_id == ^arg(:user_id)))

      prepare build(
                load: [
                  participants: [user: [:avatar_url, :display_label]],
                  last_message: [:user]
                ]
              )
    end
  end

  attributes do
    uuid_primary_key :id
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :participants, Slouch.Chat.ConversationParticipant
    has_many :direct_messages, Slouch.Chat.DirectMessage

    has_one :last_message, Slouch.Chat.DirectMessage do
      sort inserted_at: :desc
    end
  end
end
