defmodule Slouch.Chat.DirectMessage do
  use Ash.Resource,
    otp_app: :slouch,
    domain: Slouch.Chat,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "direct_messages"
    repo Slouch.Repo

    references do
      reference :conversation, on_delete: :delete
      reference :user, on_delete: :delete
      reference :parent_message, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:body]
      argument :conversation_id, :uuid, allow_nil?: false
      argument :parent_message_id, :uuid, allow_nil?: true

      change manage_relationship(:conversation_id, :conversation, type: :append_and_remove)
      change manage_relationship(:parent_message_id, :parent_message, type: :append)
      change relate_actor(:user)
    end

    read :by_conversation do
      argument :conversation_id, :uuid, allow_nil?: false

      filter expr(conversation_id == ^arg(:conversation_id) and is_nil(parent_message_id))

      prepare build(
                sort: [inserted_at: :asc],
                load: [:reply_count, user: [:avatar_url, :display_label], reactions: [:user]]
              )
    end

    read :thread_replies do
      argument :parent_message_id, :uuid, allow_nil?: false

      filter expr(parent_message_id == ^arg(:parent_message_id))

      prepare build(load: [user: [:avatar_url, :display_label]], sort: [inserted_at: :asc])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :body, :string do
      allow_nil? false
      public? true
    end

    attribute :parent_message_id, :uuid, allow_nil?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :conversation, Slouch.Chat.Conversation, allow_nil?: false
    belongs_to :user, Slouch.Accounts.User, allow_nil?: false

    belongs_to :parent_message, Slouch.Chat.DirectMessage,
      allow_nil?: true,
      define_attribute?: false

    has_many :replies, Slouch.Chat.DirectMessage, destination_attribute: :parent_message_id
    has_many :reactions, Slouch.Chat.DmReaction
  end

  aggregates do
    count :reply_count, :replies
  end
end
