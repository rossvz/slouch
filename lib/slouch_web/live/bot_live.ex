defmodule SlouchWeb.BotLive do
  use SlouchWeb, :live_view

  alias Slouch.Bots.HandlerRegistry

  on_mount {SlouchWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    bots = Slouch.Bots.Bot |> Ash.read!(authorize?: false) |> Ash.load!([:user])

    {:ok,
     assign(socket,
       bots: bots,
       page_title: "Bot Management",
       show_modal: false,
       editing_bot: nil,
       form_params: default_form_params(),
       available_handlers: HandlerRegistry.available_handlers()
     )}
  end

  @impl true
  def handle_event("show_create_modal", _params, socket) do
    {:noreply, assign(socket, show_modal: true, editing_bot: nil, form_params: default_form_params())}
  end

  def handle_event("show_edit_modal", %{"bot-id" => bot_id}, socket) do
    bot = Enum.find(socket.assigns.bots, &(&1.id == bot_id))

    if bot do
      form_params = %{
        "name" => bot.name,
        "description" => bot.description || "",
        "handler_module" => bot.handler_module,
        "trigger_type" => bot.trigger_type,
        "response_style" => bot.response_style,
        "avatar_url" => bot.avatar_url || "",
        "config" => Jason.encode!(bot.config, pretty: true)
      }

      {:noreply, assign(socket, show_modal: true, editing_bot: bot, form_params: form_params)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, show_modal: false, editing_bot: nil)}
  end

  def handle_event("install_handler", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    handler = Enum.at(socket.assigns.available_handlers, index)

    if handler do
      form_params = %{
        "name" => handler.name,
        "description" => handler.description,
        "handler_module" => handler.module,
        "trigger_type" => handler.trigger_type,
        "response_style" => "thread",
        "avatar_url" => handler.avatar,
        "config" => "{}"
      }

      {:noreply, assign(socket, show_modal: true, editing_bot: nil, form_params: form_params)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("save_bot", params, socket) do
    config =
      case Jason.decode(params["config"] || "{}") do
        {:ok, map} -> map
        {:error, _} -> %{}
      end

    if socket.assigns.editing_bot do
      update_params = %{
        name: params["name"],
        description: params["description"],
        trigger_type: params["trigger_type"],
        response_style: params["response_style"],
        avatar_url: params["avatar_url"],
        config: config
      }

      socket.assigns.editing_bot
      |> Ash.Changeset.for_update(:update, update_params)
      |> Ash.update!(authorize?: false)

      bots = Slouch.Bots.Bot |> Ash.read!(authorize?: false) |> Ash.load!([:user])
      {:noreply, assign(socket, bots: bots, show_modal: false, editing_bot: nil)}
    else
      slug =
        params["name"]
        |> String.downcase()
        |> String.replace(~r/[^a-z0-9]+/, "-")
        |> String.trim("-")

      bot_user =
        Slouch.Accounts.User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "#{slug}@slouch.bot",
          password: "botpassword123456",
          password_confirmation: "botpassword123456",
          display_name: params["name"]
        })
        |> Ash.create!(authorize?: false)

      bot_user
      |> Ecto.Changeset.change(%{confirmed_at: DateTime.utc_now(), is_bot: true})
      |> Slouch.Repo.update!()

      Slouch.Bots.Bot
      |> Ash.Changeset.for_create(:create, %{
        name: params["name"],
        description: params["description"],
        handler_module: params["handler_module"],
        trigger_type: params["trigger_type"],
        response_style: params["response_style"],
        avatar_url: params["avatar_url"],
        config: config,
        user_id: bot_user.id
      })
      |> Ash.create!(authorize?: false)

      bots = Slouch.Bots.Bot |> Ash.read!(authorize?: false) |> Ash.load!([:user])
      {:noreply, assign(socket, bots: bots, show_modal: false)}
    end
  rescue
    e ->
      {:noreply, put_flash(socket, :error, "Error: #{Exception.message(e)}")}
  end

  def handle_event("toggle_active", %{"bot-id" => bot_id}, socket) do
    bot = Enum.find(socket.assigns.bots, &(&1.id == bot_id))

    if bot do
      bot
      |> Ash.Changeset.for_update(:update, %{is_active: !bot.is_active})
      |> Ash.update!(authorize?: false)

      bots = Slouch.Bots.Bot |> Ash.read!(authorize?: false) |> Ash.load!([:user])
      {:noreply, assign(socket, bots: bots)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("delete_bot", %{"bot-id" => bot_id}, socket) do
    bot = Enum.find(socket.assigns.bots, &(&1.id == bot_id))

    if bot do
      Ash.destroy!(bot, authorize?: false)
      bots = Slouch.Bots.Bot |> Ash.read!(authorize?: false) |> Ash.load!([:user])
      {:noreply, assign(socket, bots: bots)}
    else
      {:noreply, socket}
    end
  end

  defp default_form_params do
    %{
      "name" => "",
      "description" => "",
      "handler_module" => "",
      "trigger_type" => "mention",
      "response_style" => "thread",
      "avatar_url" => "",
      "config" => "{}"
    }
  end

  defp relative_time(nil), do: "Never"

  defp relative_time(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      true -> "#{div(diff, 86400)}d ago"
    end
  end

  defp total_messages(bots), do: Enum.sum(Enum.map(bots, & &1.messages_handled))
  defp active_count(bots), do: Enum.count(bots, & &1.is_active)

  defp trigger_badge_color(trigger_type) do
    case trigger_type do
      "mention" -> "badge-primary"
      "channel_join" -> "badge-success"
      "schedule" -> "badge-warning"
      "keyword" -> "badge-info"
      "all_messages" -> "badge-secondary"
      _ -> "badge-ghost"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200">
      <div class="navbar bg-base-100 shadow-sm">
        <div class="flex-1">
          <h1 class="text-xl font-bold flex items-center gap-2 px-4">
            <.icon name="hero-cpu-chip" class="w-6 h-6" />
            Bot Management
          </h1>
        </div>
        <div class="flex-none gap-2 px-4">
          <.link navigate={~p"/"} class="btn btn-ghost btn-sm gap-1">
            <.icon name="hero-arrow-left" class="w-4 h-4" />
            Back to Chat
          </.link>
          <button phx-click="show_create_modal" class="btn btn-primary btn-sm gap-1">
            <.icon name="hero-plus" class="w-4 h-4" />
            Create Bot
          </button>
        </div>
      </div>

      <div class="max-w-7xl mx-auto px-4 py-6">
        <div class="stats shadow bg-base-100 w-full mb-6">
          <div class="stat">
            <div class="stat-figure text-primary">
              <.icon name="hero-cpu-chip" class="w-8 h-8" />
            </div>
            <div class="stat-title">Total Bots</div>
            <div class="stat-value text-primary">{length(@bots)}</div>
          </div>
          <div class="stat">
            <div class="stat-figure text-success">
              <.icon name="hero-signal" class="w-8 h-8" />
            </div>
            <div class="stat-title">Active</div>
            <div class="stat-value text-success">{active_count(@bots)}</div>
          </div>
          <div class="stat">
            <div class="stat-figure text-info">
              <.icon name="hero-chat-bubble-bottom-center-text" class="w-8 h-8" />
            </div>
            <div class="stat-title">Messages Handled</div>
            <div class="stat-value text-info">{total_messages(@bots)}</div>
          </div>
        </div>

        <div :if={@bots != []} class="mb-8">
          <h2 class="text-lg font-semibold mb-4">Your Bots</h2>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <div :for={bot <- @bots} class="card bg-base-100 shadow-md">
              <div class="card-body p-5">
                <div class="flex items-start justify-between">
                  <div class="flex items-center gap-3">
                    <div class="avatar">
                      <div class="w-12 h-12 rounded-full bg-base-200 flex items-center justify-center">
                        <img
                          :if={bot.avatar_url}
                          src={bot.avatar_url}
                          alt={bot.name}
                          class="rounded-full"
                        />
                        <span :if={!bot.avatar_url} class="text-2xl">🤖</span>
                      </div>
                    </div>
                    <div>
                      <div class="flex items-center gap-2">
                        <h3 class="font-bold">{bot.name}</h3>
                        <span class={"badge badge-xs #{trigger_badge_color(bot.trigger_type)}"}>
                          {bot.trigger_type}
                        </span>
                      </div>
                      <p class="text-sm opacity-60 mt-0.5 line-clamp-2">{bot.description}</p>
                    </div>
                  </div>
                  <div class="flex items-center gap-1">
                    <div class={[
                      "w-2.5 h-2.5 rounded-full",
                      if(bot.is_active, do: "bg-success", else: "bg-base-300")
                    ]}>
                    </div>
                  </div>
                </div>

                <div class="flex items-center gap-4 mt-3 text-sm opacity-60">
                  <div class="flex items-center gap-1">
                    <.icon name="hero-chat-bubble-bottom-center-text" class="w-3.5 h-3.5" />
                    <span>{bot.messages_handled} msgs</span>
                  </div>
                  <div class="flex items-center gap-1">
                    <.icon name="hero-clock" class="w-3.5 h-3.5" />
                    <span>{relative_time(bot.last_active_at)}</span>
                  </div>
                </div>

                <div class="divider my-2"></div>

                <div class="flex items-center justify-between">
                  <label class="label cursor-pointer gap-2 p-0">
                    <span class="text-sm">{if bot.is_active, do: "Active", else: "Inactive"}</span>
                    <input
                      type="checkbox"
                      class="toggle toggle-sm toggle-success"
                      checked={bot.is_active}
                      phx-click="toggle_active"
                      phx-value-bot-id={bot.id}
                    />
                  </label>
                  <div class="flex gap-1">
                    <button
                      phx-click="show_edit_modal"
                      phx-value-bot-id={bot.id}
                      class="btn btn-ghost btn-xs"
                    >
                      <.icon name="hero-pencil-square" class="w-4 h-4" />
                    </button>
                    <button
                      phx-click="delete_bot"
                      phx-value-bot-id={bot.id}
                      data-confirm="Are you sure you want to delete this bot?"
                      class="btn btn-ghost btn-xs text-error"
                    >
                      <.icon name="hero-trash" class="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div :if={@bots == []} class="text-center py-12 mb-8">
          <div class="text-5xl mb-4">🤖</div>
          <h2 class="text-xl font-bold mb-2">No bots yet</h2>
          <p class="opacity-60 mb-4">Create a bot or install one from the marketplace below.</p>
        </div>

        <div>
          <h2 class="text-lg font-semibold mb-4 flex items-center gap-2">
            <.icon name="hero-squares-2x2" class="w-5 h-5" />
            Available Handlers
          </h2>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <div :for={{handler, idx} <- Enum.with_index(@available_handlers)} class="card bg-base-100 shadow-md">
              <div class="card-body p-5">
                <div class="flex items-center gap-3 mb-2">
                  <div class="avatar">
                    <div class="w-10 h-10 rounded-full">
                      <img src={handler.avatar} alt={handler.name} />
                    </div>
                  </div>
                  <div>
                    <h3 class="font-bold">{handler.name}</h3>
                    <span class={"badge badge-xs #{trigger_badge_color(handler.trigger_type)}"}>
                      {handler.trigger_type}
                    </span>
                  </div>
                </div>
                <p class="text-sm opacity-60 flex-1">{handler.description}</p>
                <div class="card-actions justify-end mt-3">
                  <button
                    phx-click="install_handler"
                    phx-value-index={idx}
                    class="btn btn-primary btn-sm btn-outline gap-1"
                  >
                    <.icon name="hero-arrow-down-tray" class="w-4 h-4" />
                    Install
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <dialog id="bot-modal" class={["modal", @show_modal && "modal-open"]}>
        <div class="modal-box max-w-lg">
          <h3 class="font-bold text-lg mb-4">
            {if @editing_bot, do: "Edit Bot", else: "Create Bot"}
          </h3>
          <form phx-submit="save_bot">
            <div class="form-control mb-3">
              <label class="label"><span class="label-text">Name</span></label>
              <input
                type="text"
                name="name"
                value={@form_params["name"]}
                placeholder="My Awesome Bot"
                class="input input-bordered"
                required
              />
            </div>

            <div class="form-control mb-3">
              <label class="label"><span class="label-text">Description</span></label>
              <textarea
                name="description"
                placeholder="What does this bot do?"
                class="textarea textarea-bordered"
                rows="2"
              >{@form_params["description"]}</textarea>
            </div>

            <div class="form-control mb-3">
              <label class="label"><span class="label-text">Handler Module</span></label>
              <select name="handler_module" class="select select-bordered" required>
                <option value="" disabled selected={@form_params["handler_module"] == ""}>
                  Select a handler...
                </option>
                <option
                  :for={h <- @available_handlers}
                  value={h.module}
                  selected={@form_params["handler_module"] == h.module}
                >
                  {h.name}
                </option>
              </select>
            </div>

            <div class="grid grid-cols-2 gap-3 mb-3">
              <div class="form-control">
                <label class="label"><span class="label-text">Trigger Type</span></label>
                <select name="trigger_type" class="select select-bordered">
                  <option
                    :for={tt <- ~w(mention channel_join schedule keyword all_messages)}
                    value={tt}
                    selected={@form_params["trigger_type"] == tt}
                  >
                    {tt}
                  </option>
                </select>
              </div>

              <div class="form-control">
                <label class="label"><span class="label-text">Response Style</span></label>
                <select name="response_style" class="select select-bordered">
                  <option
                    :for={rs <- ~w(reply thread reaction dm)}
                    value={rs}
                    selected={@form_params["response_style"] == rs}
                  >
                    {rs}
                  </option>
                </select>
              </div>
            </div>

            <div class="form-control mb-3">
              <label class="label"><span class="label-text">Avatar URL</span></label>
              <input
                type="text"
                name="avatar_url"
                value={@form_params["avatar_url"]}
                placeholder="https://..."
                class="input input-bordered"
              />
            </div>

            <div class="form-control mb-3">
              <label class="label"><span class="label-text">Config (JSON)</span></label>
              <textarea
                name="config"
                placeholder="{}"
                class="textarea textarea-bordered font-mono text-sm"
                rows="3"
              >{@form_params["config"]}</textarea>
            </div>

            <div class="modal-action">
              <button type="button" phx-click="close_modal" class="btn">Cancel</button>
              <button type="submit" class="btn btn-primary">
                {if @editing_bot, do: "Update Bot", else: "Create Bot"}
              </button>
            </div>
          </form>
        </div>
        <form method="dialog" class="modal-backdrop">
          <button type="button" phx-click="close_modal">close</button>
        </form>
      </dialog>

      <Layouts.flash_group flash={@flash} />
    </div>
    """
  end
end
