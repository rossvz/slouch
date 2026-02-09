# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
mix setup                    # Full setup: deps, db, assets, seeds
mix ecto.reset               # Drop + create + migrate + seed
mix phx.server               # Start dev server (localhost:4000)
mix test                     # Run all tests (auto-runs ash.setup)
mix test test/path_test.exs  # Run single test file
mix test --failed            # Re-run failed tests
mix precommit                # Compile (warnings=errors) + format + test
mix ash_postgres.generate_migrations --name description  # Generate Ash migrations
mix format                   # Format code
```

## Architecture

Slouch is a Slack-like chat app using Elixir/Phoenix with Ash Framework for resource modeling.

### Domains

Three Ash domains in `lib/slouch/`:

- **Accounts** — `User` (with AshAuthentication: password, magic link, email confirmation), `Token`
- **Chat** — `Channel`, `Message` (with threading via `parent_message_id`), `Membership`, `Reaction`, `Conversation` (DMs), `ConversationParticipant`, `DirectMessage`, `DmReaction`
- **Bots** — `Bot` resource + handler system. Each bot has a `handler_module`, `trigger_type` (mention/channel_join/keyword/schedule/all_messages), and a linked `User` with `is_bot: true`

### LiveViews

- `ChatLive` (`/`, `/chat/:channel_name`, `/dm/:conversation_id`) — Main chat interface, large file
- `BotLive` (`/bots`) — Bot admin CRUD and marketplace

### Real-Time

PubSub topics:
- `"chat:#{channel_id}"` — messages, replies, reactions
- `"dm:#{conversation_id}"` — direct messages and reactions
- `"presence:#{channel_id}"` — user presence via `SlouchWeb.Presence`
- `"bot:mentions"`, `"bot:channel_join"`, `"bot:all_messages"` — bot dispatch events

Bot `Dispatcher` is a GenServer subscribing to bot topics and spawning async handler tasks with 5s per-bot-per-channel rate limiting.

### Bot System

- `Slouch.Bots.Handler` — behaviour with `handle_mention/3`, optional `handle_channel_join/3`, `handle_schedule/1`, `handle_keyword/4`
- `Slouch.Bots.Responder` — `post_message/3`, `post_reply/4`, `add_reaction/3`, `record_activity/1`
- `Slouch.Bots.HandlerRegistry` — static list of available handler modules
- 6 handlers in `lib/slouch/bots/handlers/`

## Ash Framework Patterns

- Use `Ash.Query.for_read/3` for reads, `Ash.Changeset.for_create/for_update` for writes
- Do NOT use `Ash.ActionInput.for_action/3` for reads (that's for generic actions only)
- `Ash.create!(authorize?: false)` bypasses policies (seeds/tests)
- User has policy authorizer — `AshAuthenticationInteraction` bypass only covers auth actions
- To confirm users in seeds/tests: `Ecto.Changeset.change(user, %{confirmed_at: DateTime.utc_now()}) |> Repo.update!()`
- Available User update actions: `:confirm`, `:password_reset_with_password`, `:update_profile`
- When generating Ash migrations, create a snapshot matching the hand-written migration timestamp if writing migrations manually

## Testing

- Factory helpers in `test/support/test_helpers.ex`: `create_user/1`, `create_channel/1`, `create_message/3`, `create_membership/2`, `create_reaction/3`
- `DataCase` for domain/resource tests, `ConnCase` for controller/LiveView tests
- Async tests supported; SQL Sandbox in manual mode
- `Ash.create!(authorize?: false)` in all test factories

## Seed Users

| Email | Password |
|-------|----------|
| alice@example.com | password123456 |
| bob@example.com | password123456 |

## Dev Tools

- AshAdmin at `/admin` (dev only)
- LiveDashboard at `/dev/dashboard`
- Swoosh mailbox at `/dev/mailbox`
- LiveDebugger on port 4007

## Key Dependencies

- **Ash Framework 3.0+** with AshPostgres, AshAuthentication, AshPhoenix
- **Phoenix 1.8** / LiveView 1.1 — uses `Layouts.app` wrapper, `<.icon>` for heroicons
- **Tailwind v4** — no `tailwind.config.js`, uses `@import "tailwindcss"` syntax in `app.css`
- **DaisyUI** for component styling
- **Req** for HTTP requests (not httpoison/tesla)

## Database

PostgreSQL dev config expects `postgres`/`postgres` role on localhost:5432.
