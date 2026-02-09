defmodule Slouch.Repo.Migrations.EnhanceBots do
  use Ecto.Migration

  def up do
    alter table(:bots) do
      add :trigger_type, :text, null: false, default: "mention"
      add :response_style, :text, null: false, default: "thread"
      add :config, :map, null: false, default: %{}
      add :avatar_url, :text
      add :messages_handled, :bigint, null: false, default: 0
      add :last_active_at, :utc_datetime_usec
    end
  end

  def down do
    alter table(:bots) do
      remove :trigger_type
      remove :response_style
      remove :config
      remove :avatar_url
      remove :messages_handled
      remove :last_active_at
    end
  end
end
