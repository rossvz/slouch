defmodule Slouch.Repo.Migrations.AddUserProfileFields do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :display_name, :text
      add :status_emoji, :text
      add :status_text, :text
    end
  end

  def down do
    alter table(:users) do
      remove :display_name
      remove :status_emoji
      remove :status_text
    end
  end
end
