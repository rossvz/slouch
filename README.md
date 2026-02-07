# Slouch

A Slack-like team chat application built with Elixir, Phoenix, and the Ash Framework.

## Features

- **Real-time messaging** — Channels with instant message delivery via Phoenix PubSub
- **Message threads** — Reply to messages in a side panel, with reply counts on the main view
- **Emoji reactions** — React to messages with quick-pick emojis or a full picker
- **User profiles** — Display names, auto-generated avatars (DiceBear), and custom status
- **Online presence** — See who's online in each channel via Phoenix Presence
- **Authentication** — Password login, magic links, email confirmation, and remember me
- **Polished UI** — Message grouping, date separators, theme support (light/dark), and responsive layout

## Tech Stack

- [Elixir](https://elixir-lang.org/) / [Phoenix](https://www.phoenixframework.org/) — Backend and real-time
- [Ash Framework](https://ash-hq.org/) — Resource modeling, actions, and policies
- [AshAuthentication](https://hexdocs.pm/ash_authentication/) — Auth strategies and token management
- [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/) — Server-rendered reactive UI
- [DaisyUI](https://daisyui.com/) + [Tailwind CSS](https://tailwindcss.com/) — Styling
- [PostgreSQL](https://www.postgresql.org/) — Database

## Setup

Prerequisites: Elixir 1.17+, PostgreSQL

```bash
# Install dependencies
mix setup

# Reset database with seed data
mix ecto.reset

# Start the server
mix phx.server
```

Visit [localhost:4000](http://localhost:4000).

### Seed Users

| Email | Password |
|-------|----------|
| alice@example.com | password123456 |
| bob@example.com | password123456 |

## Project Structure

```
lib/slouch/
  accounts/          # User, Token resources
  chat/              # Channel, Message, Membership, Reaction resources

lib/slouch_web/
  live/chat_live.ex  # Main chat LiveView
  presence.ex        # Phoenix Presence tracking
  router.ex          # Routes and auth pipelines
```

## License

MIT
