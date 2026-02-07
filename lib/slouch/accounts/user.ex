defmodule Slouch.Accounts.User do
  use Ash.Resource,
    otp_app: :slouch,
    domain: Slouch.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication]

  authentication do
    add_ons do
      log_out_everywhere do
        apply_on_password_change? true
      end

      confirmation :confirm_email do
        monitor_fields [:email]
        confirm_on_create? true
        confirm_on_update? true
        require_interaction? true
        auto_confirm_actions [:sign_in_with_magic_link]
        sender Slouch.Accounts.User.Senders.SendConfirmationEmail
      end
    end

    tokens do
      enabled? true
      token_resource Slouch.Accounts.Token
      signing_secret Slouch.Secrets
      store_all_tokens? true
      require_token_presence_for_authentication? true
    end

    strategies do
      magic_link do
        identity_field :email
        registration_enabled? true
        require_interaction? true

        sender Slouch.Accounts.User.Senders.SendMagicLinkEmail
      end

      password :password do
        identity_field :email
        hashed_password_field :hashed_password
        register_action_accept [:display_name]

        resettable do
          sender Slouch.Accounts.User.Senders.SendPasswordResetEmail
        end
      end

      remember_me :remember_me
    end
  end

  postgres do
    table "users"
    repo Slouch.Repo
  end

  calculations do
    calculate :avatar_url, :string, expr("https://api.dicebear.com/7.x/bottts-neutral/svg?seed=" <> email)
    calculate :display_label, :string, expr(display_name || email)
  end

  actions do
    defaults [:read]

    read :get_by_subject do
      description "Get a user by the subject claim in a JWT"
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject
    end

    read :get_by_email do
      description "Looks up a user by their email"
      get_by :email
    end

    create :sign_in_with_magic_link do
      description "Sign in or register a user with magic link."

      argument :token, :string do
        description "The token from the magic link that was sent to the user"
        allow_nil? false
      end

      argument :remember_me, :boolean do
        description "Whether to generate a remember me token"
        allow_nil? true
      end

      upsert? true
      upsert_identity :unique_email
      upsert_fields [:email]

      # Uses the information from the token to create or sign in the user
      change AshAuthentication.Strategy.MagicLink.SignInChange

      change {AshAuthentication.Strategy.RememberMe.MaybeGenerateTokenChange,
              strategy_name: :remember_me}

      metadata :token, :string do
        allow_nil? false
      end
    end

    update :update_profile do
      accept [:display_name, :status_emoji, :status_text]
    end

    action :request_magic_link do
      argument :email, :ci_string do
        allow_nil? false
      end

      run AshAuthentication.Strategy.MagicLink.Request
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action(:update_profile) do
      authorize_if expr(id == ^actor(:id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :hashed_password, :string do
      allow_nil? true
      sensitive? true
    end

    attribute :confirmed_at, :utc_datetime_usec do
      allow_nil? true
    end

    attribute :display_name, :string do
      allow_nil? true
      public? true
    end

    attribute :status_emoji, :string do
      allow_nil? true
      public? true
    end

    attribute :status_text, :string do
      allow_nil? true
      public? true
    end
  end

  identities do
    identity :unique_email, [:email]
  end
end
