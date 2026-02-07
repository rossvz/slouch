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
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:body]
      argument :conversation_id, :uuid, allow_nil?: false

      change manage_relationship(:conversation_id, :conversation, type: :append_and_remove)
      change relate_actor(:user)
    end

    read :by_conversation do
      argument :conversation_id, :uuid, allow_nil?: false

      filter expr(conversation_id == ^arg(:conversation_id))

      prepare build(sort: [inserted_at: :asc], load: [user: [:avatar_url, :display_label]])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :body, :string do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :conversation, Slouch.Chat.Conversation, allow_nil?: false
    belongs_to :user, Slouch.Accounts.User, allow_nil?: false
  end
end
