defmodule Slouch.Chat.Membership do
  use Ash.Resource,
    otp_app: :slouch,
    domain: Slouch.Chat,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "memberships"
    repo Slouch.Repo

    references do
      reference :channel, on_delete: :delete
      reference :user, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :join do
      argument :channel_id, :uuid, allow_nil?: false

      change manage_relationship(:channel_id, :channel, type: :append_and_remove)
      change relate_actor(:user)
    end
  end

  attributes do
    uuid_primary_key :id
    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :channel, Slouch.Chat.Channel do
      allow_nil? false
    end

    belongs_to :user, Slouch.Accounts.User do
      allow_nil? false
    end
  end

  identities do
    identity :unique_membership, [:channel_id, :user_id]
  end
end
