defmodule SlouchWeb.ChatLive do
  use SlouchWeb, :live_view

  alias SlouchWeb.Presence

  on_mount {SlouchWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    channels = Slouch.Chat.Channel |> Ash.read!()
    current_user = Ash.load!(socket.assigns.current_user, [:avatar_url, :display_label])

    conversations = load_conversations(current_user)

    all_users =
      Slouch.Accounts.User
      |> Ash.read!()
      |> Ash.load!([:avatar_url, :display_label])
      |> Enum.reject(&(&1.id == current_user.id || &1.is_bot))

    {:ok,
     assign(socket,
       current_user: current_user,
       channels: channels,
       channel: nil,
       conversation: nil,
       conversations: conversations,
       all_users: all_users,
       messages: [],
       dm_messages: [],
       show_thread: false,
       thread_parent: nil,
       thread_replies: [],
       thread_type: nil,
       online_users: MapSet.new(),
       view_mode: :none
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    channel_name = params["channel_name"]
    conversation_id = params["conversation_id"]
    old_channel = socket.assigns.channel
    old_conversation = socket.assigns.conversation

    if connected?(socket) do
      unsubscribe_current(socket, old_channel, old_conversation)
    end

    cond do
      conversation_id ->
        handle_dm_params(conversation_id, socket)

      channel_name ->
        handle_channel_params(channel_name, socket)

      true ->
        {:noreply,
         assign(socket,
           channel: nil,
           conversation: nil,
           messages: [],
           dm_messages: [],
           online_users: MapSet.new(),
           show_thread: false,
           thread_parent: nil,
           thread_replies: [],
           thread_type: nil,
           view_mode: :none,
           page_title: nil
         )}
    end
  end

  defp handle_channel_params(channel_name, socket) do
    channel = Enum.find(socket.assigns.channels, &(&1.name == channel_name))

    if connected?(socket) && channel do
      Phoenix.PubSub.subscribe(Slouch.PubSub, "chat:#{channel.id}")
      Phoenix.PubSub.subscribe(Slouch.PubSub, "presence:#{channel.id}")

      Presence.track(self(), "presence:#{channel.id}", socket.assigns.current_user.id, %{
        email: to_string(socket.assigns.current_user.email),
        display_label: to_string(socket.assigns.current_user.display_label),
        joined_at: System.system_time(:second)
      })
    end

    messages =
      if channel do
        Slouch.Chat.Message
        |> Ash.Query.for_read(:by_channel, %{channel_id: channel.id})
        |> Ash.read!(actor: socket.assigns.current_user)
      else
        []
      end

    online_users =
      if channel && connected?(socket) do
        "presence:#{channel.id}" |> Presence.list() |> Map.keys() |> MapSet.new()
      else
        MapSet.new()
      end

    {:noreply,
     assign(socket,
       channel: channel,
       conversation: nil,
       messages: messages,
       dm_messages: [],
       online_users: online_users,
       show_thread: false,
       thread_parent: nil,
       thread_replies: [],
       thread_type: nil,
       view_mode: :channel,
       page_title: channel && "# #{channel.name}"
     )}
  end

  defp handle_dm_params(conversation_id, socket) do
    case Ash.get(Slouch.Chat.Conversation, conversation_id,
           load: [participants: [user: [:avatar_url, :display_label]]]
         ) do
      {:ok, conversation} ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Slouch.PubSub, "dm:#{conversation.id}")
        end

        dm_messages =
          Slouch.Chat.DirectMessage
          |> Ash.Query.for_read(:by_conversation, %{conversation_id: conversation.id})
          |> Ash.read!(actor: socket.assigns.current_user)

        other = other_participant(conversation, socket.assigns.current_user.id)

        {:noreply,
         assign(socket,
           channel: nil,
           conversation: conversation,
           messages: [],
           dm_messages: dm_messages,
           online_users: MapSet.new(),
           show_thread: false,
           thread_parent: nil,
           thread_replies: [],
           thread_type: nil,
           view_mode: :dm,
           page_title: other && to_string(other.display_label)
         )}

      {:error, _} ->
        {:noreply, push_navigate(socket, to: ~p"/")}
    end
  end

  defp unsubscribe_current(socket, old_channel, old_conversation) do
    if old_channel do
      Phoenix.PubSub.unsubscribe(Slouch.PubSub, "chat:#{old_channel.id}")
      Presence.untrack(self(), "presence:#{old_channel.id}", socket.assigns.current_user.id)
      Phoenix.PubSub.unsubscribe(Slouch.PubSub, "presence:#{old_channel.id}")
    end

    if old_conversation do
      Phoenix.PubSub.unsubscribe(Slouch.PubSub, "dm:#{old_conversation.id}")
    end
  end

  @impl true
  def handle_event("toggle_reaction", %{"message-id" => message_id, "emoji" => emoji}, socket) do
    current_user = socket.assigns.current_user

    existing =
      Slouch.Chat.Reaction
      |> Ash.Query.for_read(:by_message, %{message_id: message_id})
      |> Ash.read!(actor: current_user)
      |> Enum.find(&(&1.user_id == current_user.id && &1.emoji == emoji))

    if existing do
      Ash.destroy!(existing, actor: current_user)
    else
      Slouch.Chat.Reaction
      |> Ash.Changeset.for_create(:react, %{emoji: emoji, message_id: message_id},
        actor: current_user
      )
      |> Ash.create!()
    end

    Phoenix.PubSub.broadcast(
      Slouch.PubSub,
      "chat:#{socket.assigns.channel.id}",
      {:reaction_toggled, message_id}
    )

    {:noreply, socket}
  end

  def handle_event("toggle_dm_reaction", %{"message-id" => message_id, "emoji" => emoji}, socket) do
    current_user = socket.assigns.current_user

    existing =
      Slouch.Chat.DmReaction
      |> Ash.Query.for_read(:by_direct_message, %{direct_message_id: message_id})
      |> Ash.read!(actor: current_user)
      |> Enum.find(&(&1.user_id == current_user.id && &1.emoji == emoji))

    if existing do
      Ash.destroy!(existing, actor: current_user)
    else
      Slouch.Chat.DmReaction
      |> Ash.Changeset.for_create(:react, %{emoji: emoji, direct_message_id: message_id},
        actor: current_user
      )
      |> Ash.create!()
    end

    Phoenix.PubSub.broadcast(
      Slouch.PubSub,
      "dm:#{socket.assigns.conversation.id}",
      {:dm_reaction_toggled, message_id}
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("send_message", %{"body" => body}, socket) do
    body = String.trim(body)

    if body == "" do
      {:noreply, socket}
    else
      channel = socket.assigns.channel
      current_user = socket.assigns.current_user

      message =
        Slouch.Chat.Message
        |> Ash.Changeset.for_create(:create, %{body: body, channel_id: channel.id},
          actor: current_user
        )
        |> Ash.create!()

      message = Ash.load!(message, user: [:avatar_url, :display_label])

      Phoenix.PubSub.broadcast(
        Slouch.PubSub,
        "chat:#{channel.id}",
        {:new_message, message}
      )

      Phoenix.PubSub.broadcast(
        Slouch.PubSub,
        "bot:mentions",
        {:check_mentions, message, channel}
      )

      {:noreply, socket}
    end
  end

  def handle_event("send_dm", %{"body" => body}, socket) do
    body = String.trim(body)

    if body == "" do
      {:noreply, socket}
    else
      conversation = socket.assigns.conversation
      current_user = socket.assigns.current_user

      dm =
        Slouch.Chat.DirectMessage
        |> Ash.Changeset.for_create(:create, %{body: body, conversation_id: conversation.id},
          actor: current_user
        )
        |> Ash.create!()

      dm = Ash.load!(dm, user: [:avatar_url, :display_label])

      Phoenix.PubSub.broadcast(
        Slouch.PubSub,
        "dm:#{conversation.id}",
        {:new_dm, dm}
      )

      {:noreply, socket}
    end
  end

  def handle_event("start_dm", %{"user-id" => other_user_id}, socket) do
    current_user = socket.assigns.current_user
    conversation = find_or_create_conversation(current_user.id, other_user_id)
    conversations = load_conversations(current_user)

    {:noreply,
     socket
     |> assign(conversations: conversations)
     |> push_navigate(to: ~p"/dm/#{conversation.id}")}
  end

  def handle_event("create_channel", %{"name" => name}, socket) do
    name = name |> String.trim() |> String.downcase() |> String.replace(~r/[^a-z0-9-]/, "-")

    if name == "" do
      {:noreply, socket}
    else
      Slouch.Chat.Channel
      |> Ash.Changeset.for_create(:create, %{name: name})
      |> Ash.create!()

      channels = Slouch.Chat.Channel |> Ash.read!()
      {:noreply, socket |> assign(channels: channels) |> push_patch(to: ~p"/chat/#{name}")}
    end
  end

  def handle_event("randomize_avatar", _params, socket) do
    user = socket.assigns.current_user
    seed = Ash.UUID.generate()

    updated_user =
      user
      |> Ash.Changeset.for_update(:update_profile, %{avatar_seed: seed})
      |> Ash.update!(actor: user)
      |> Ash.load!([:avatar_url, :display_label])

    {:noreply, assign(socket, current_user: updated_user)}
  end

  def handle_event("update_profile", params, socket) do
    user = socket.assigns.current_user

    updated_user =
      user
      |> Ash.Changeset.for_update(:update_profile, %{
        display_name: params["display_name"],
        status_emoji: params["status_emoji"],
        status_text: params["status_text"]
      })
      |> Ash.update!(actor: user)
      |> Ash.load!([:avatar_url, :display_label])

    socket =
      socket
      |> assign(current_user: updated_user)
      |> push_event("close-modal", %{id: "profile-modal"})

    {:noreply, socket}
  end

  def handle_event("open_thread", %{"message-id" => message_id}, socket) do
    parent = Ash.get!(Slouch.Chat.Message, message_id, load: [user: [:avatar_url, :display_label]])

    replies =
      Slouch.Chat.Message
      |> Ash.Query.for_read(:thread_replies, %{parent_message_id: message_id})
      |> Ash.read!()

    {:noreply, assign(socket, show_thread: true, thread_parent: parent, thread_replies: replies, thread_type: :channel)}
  end

  def handle_event("open_dm_thread", %{"message-id" => message_id}, socket) do
    parent = Ash.get!(Slouch.Chat.DirectMessage, message_id, load: [user: [:avatar_url, :display_label]])

    replies =
      Slouch.Chat.DirectMessage
      |> Ash.Query.for_read(:thread_replies, %{parent_message_id: message_id})
      |> Ash.read!()

    {:noreply, assign(socket, show_thread: true, thread_parent: parent, thread_replies: replies, thread_type: :dm)}
  end

  def handle_event("close_thread", _, socket) do
    {:noreply, assign(socket, show_thread: false, thread_parent: nil, thread_replies: [], thread_type: nil)}
  end

  def handle_event("send_reply", %{"body" => body}, socket) do
    body = String.trim(body)

    if body == "" do
      {:noreply, socket}
    else
      case socket.assigns.thread_type do
        :channel -> send_channel_reply(body, socket)
        :dm -> send_dm_reply(body, socket)
      end
    end
  end

  defp send_channel_reply(body, socket) do
    reply =
      Slouch.Chat.Message
      |> Ash.Changeset.for_create(
        :create,
        %{
          body: body,
          channel_id: socket.assigns.channel.id,
          parent_message_id: socket.assigns.thread_parent.id
        },
        actor: socket.assigns.current_user
      )
      |> Ash.create!()
      |> Ash.load!([user: [:avatar_url, :display_label]])

    Phoenix.PubSub.broadcast(
      Slouch.PubSub,
      "chat:#{socket.assigns.channel.id}",
      {:new_reply, socket.assigns.thread_parent.id, reply}
    )

    {:noreply, assign(socket, thread_replies: socket.assigns.thread_replies ++ [reply])}
  end

  defp send_dm_reply(body, socket) do
    reply =
      Slouch.Chat.DirectMessage
      |> Ash.Changeset.for_create(
        :create,
        %{
          body: body,
          conversation_id: socket.assigns.conversation.id,
          parent_message_id: socket.assigns.thread_parent.id
        },
        actor: socket.assigns.current_user
      )
      |> Ash.create!()
      |> Ash.load!([user: [:avatar_url, :display_label]])

    Phoenix.PubSub.broadcast(
      Slouch.PubSub,
      "dm:#{socket.assigns.conversation.id}",
      {:new_dm_reply, socket.assigns.thread_parent.id, reply}
    )

    {:noreply, assign(socket, thread_replies: socket.assigns.thread_replies ++ [reply])}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    existing_ids = MapSet.new(socket.assigns.messages, & &1.id)

    if MapSet.member?(existing_ids, message.id) do
      {:noreply, socket}
    else
      message = Ash.load!(message, [:reply_count, user: [:avatar_url, :display_label], reactions: [:user]], actor: socket.assigns.current_user)
      {:noreply, assign(socket, messages: socket.assigns.messages ++ [message])}
    end
  end

  def handle_info({:new_dm, dm}, socket) do
    existing_ids = MapSet.new(socket.assigns.dm_messages, & &1.id)

    if MapSet.member?(existing_ids, dm.id) do
      {:noreply, socket}
    else
      dm = Ash.load!(dm, [:reply_count, user: [:avatar_url, :display_label], reactions: [:user]])
      {:noreply, assign(socket, dm_messages: socket.assigns.dm_messages ++ [dm])}
    end
  end

  def handle_info({:reaction_toggled, message_id}, socket) do
    messages =
      Enum.map(socket.assigns.messages, fn msg ->
        if msg.id == message_id do
          Ash.load!(msg, [reactions: [:user]], actor: socket.assigns.current_user)
        else
          msg
        end
      end)

    {:noreply, assign(socket, messages: messages)}
  end

  def handle_info({:dm_reaction_toggled, message_id}, socket) do
    dm_messages =
      Enum.map(socket.assigns.dm_messages, fn msg ->
        if msg.id == message_id do
          Ash.load!(msg, [reactions: [:user]], actor: socket.assigns.current_user)
        else
          msg
        end
      end)

    {:noreply, assign(socket, dm_messages: dm_messages)}
  end

  def handle_info({:new_reply, parent_message_id, reply}, socket) do
    messages =
      Enum.map(socket.assigns.messages, fn msg ->
        if msg.id == parent_message_id do
          %{msg | reply_count: (msg.reply_count || 0) + 1}
        else
          msg
        end
      end)

    socket =
      if socket.assigns.show_thread && socket.assigns.thread_parent.id == parent_message_id do
        if reply.user_id != socket.assigns.current_user.id do
          assign(socket, thread_replies: socket.assigns.thread_replies ++ [reply])
        else
          socket
        end
      else
        socket
      end

    {:noreply, assign(socket, messages: messages)}
  end

  def handle_info({:new_dm_reply, parent_message_id, reply}, socket) do
    dm_messages =
      Enum.map(socket.assigns.dm_messages, fn msg ->
        if msg.id == parent_message_id do
          %{msg | reply_count: (msg.reply_count || 0) + 1}
        else
          msg
        end
      end)

    socket =
      if socket.assigns.show_thread && socket.assigns.thread_parent.id == parent_message_id do
        if reply.user_id != socket.assigns.current_user.id do
          assign(socket, thread_replies: socket.assigns.thread_replies ++ [reply])
        else
          socket
        end
      else
        socket
      end

    {:noreply, assign(socket, dm_messages: dm_messages)}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    online_users =
      if socket.assigns.channel do
        "presence:#{socket.assigns.channel.id}"
        |> Presence.list()
        |> Map.keys()
        |> MapSet.new()
      else
        MapSet.new()
      end

    {:noreply, assign(socket, online_users: online_users)}
  end

  defp load_conversations(user) do
    Slouch.Chat.Conversation
    |> Ash.Query.for_read(:my_conversations, %{user_id: user.id})
    |> Ash.read!()
  end

  defp find_or_create_conversation(user_id_1, user_id_2) do
    existing =
      Slouch.Chat.Conversation
      |> Ash.Query.for_read(:my_conversations, %{user_id: user_id_1})
      |> Ash.read!()
      |> Enum.find(fn conv ->
        participant_ids = Enum.map(conv.participants, & &1.user_id) |> MapSet.new()
        MapSet.member?(participant_ids, user_id_2) && MapSet.size(participant_ids) == 2
      end)

    if existing do
      existing
    else
      conversation =
        Slouch.Chat.Conversation
        |> Ash.Changeset.for_create(:create, %{})
        |> Ash.create!()

      for uid <- [user_id_1, user_id_2] do
        Slouch.Chat.ConversationParticipant
        |> Ash.Changeset.for_create(:create, %{conversation_id: conversation.id, user_id: uid})
        |> Ash.create!()
      end

      Ash.load!(conversation, [participants: [user: [:avatar_url, :display_label]]])
    end
  end

  defp other_participant(conversation, current_user_id) do
    conversation.participants
    |> Enum.find(&(&1.user_id != current_user_id))
    |> case do
      nil -> nil
      participant -> participant.user
    end
  end

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%-I:%M %p")
  end

  defp format_date_label(date) do
    today = Date.utc_today()
    yesterday = Date.add(today, -1)

    cond do
      date == today -> "Today"
      date == yesterday -> "Yesterday"
      true -> Calendar.strftime(date, "%B %-d, %Y")
    end
  end

  defp user_display(message) do
    to_string(message.user.display_label)
  end

  defp same_author_group?(msg, prev_msg) do
    msg.user_id == prev_msg.user_id &&
      DateTime.diff(msg.inserted_at, prev_msg.inserted_at, :second) < 300
  end

  defp group_reactions(reactions, current_user_id) do
    reactions
    |> Enum.group_by(& &1.emoji)
    |> Enum.map(fn {emoji, reacts} ->
      %{
        emoji: emoji,
        count: length(reacts),
        reacted_by_me: Enum.any?(reacts, &(&1.user_id == current_user_id))
      }
    end)
  end

  defp messages_with_grouping(messages) do
    messages
    |> Enum.with_index()
    |> Enum.map(fn {msg, idx} ->
      prev = if idx > 0, do: Enum.at(messages, idx - 1)
      show_date = prev == nil || DateTime.to_date(msg.inserted_at) != DateTime.to_date(prev.inserted_at)
      compact = prev != nil && !show_date && same_author_group?(msg, prev)
      {msg, show_date, compact}
    end)
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:grouped_messages, messages_with_grouping(assigns.messages))
      |> assign(:grouped_dm_messages, messages_with_grouping(assigns.dm_messages))

    ~H"""
    <div class="flex h-screen overflow-hidden">
      <aside class="w-64 bg-base-300 flex flex-col flex-shrink-0">
        <div class="p-4 font-bold text-xl tracking-tight border-b border-base-content/10">
          SLOUCH
        </div>

        <nav class="flex-1 overflow-y-auto px-1">
          <div class="px-2 mt-3 mb-1 text-xs font-semibold uppercase tracking-wider opacity-50">
            Channels
          </div>
          <ul>
            <li :for={ch <- @channels}>
              <.link
                patch={~p"/chat/#{ch.name}"}
                class={[
                  "flex items-center px-3 py-1.5 rounded text-sm transition-colors",
                  if(@channel && @channel.id == ch.id,
                    do: "bg-base-100 font-bold",
                    else: "hover:bg-base-100/50 opacity-80 hover:opacity-100"
                  )
                ]}
              >
                <span class="opacity-50 mr-1.5">#</span>
                <span class="truncate">{ch.name}</span>
              </.link>
            </li>
          </ul>

          <form phx-submit="create_channel" class="mt-3 px-2">
            <div class="flex items-center gap-1 text-sm opacity-60 hover:opacity-100 transition-opacity">
              <span class="text-lg leading-none">+</span>
              <input
                name="name"
                placeholder="Add channel"
                class="input input-ghost input-xs bg-transparent flex-1 focus:outline-none"
                autocomplete="off"
              />
            </div>
          </form>

          <div class="px-2 mt-5 mb-1 text-xs font-semibold uppercase tracking-wider opacity-50">
            Direct Messages
          </div>
          <ul>
            <li :for={conv <- @conversations}>
              <% other = other_participant(conv, @current_user.id) %>
              <.link
                :if={other}
                navigate={~p"/dm/#{conv.id}"}
                class={[
                  "flex items-center gap-2 px-3 py-1.5 rounded text-sm transition-colors",
                  if(@conversation && @conversation.id == conv.id,
                    do: "bg-base-100 font-bold",
                    else: "hover:bg-base-100/50 opacity-80 hover:opacity-100"
                  )
                ]}
              >
                <div class="avatar">
                  <div class="w-5 h-5 rounded-full">
                    <img src={other.avatar_url} alt={to_string(other.display_label)} />
                  </div>
                </div>
                <span class="truncate">{to_string(other.display_label)}</span>
              </.link>
            </li>
          </ul>

          <div class="mt-2 px-2">
            <div class="dropdown dropdown-bottom w-full">
              <div
                tabindex="0"
                role="button"
                class="flex items-center gap-1 text-sm opacity-60 hover:opacity-100 transition-opacity cursor-pointer"
              >
                <span class="text-lg leading-none">+</span>
                <span>New message</span>
              </div>
              <ul tabindex="0" class="dropdown-content z-50 menu p-2 shadow-lg bg-base-200 rounded-box w-56 mt-1">
                <li :for={u <- @all_users}>
                  <button phx-click="start_dm" phx-value-user-id={u.id} class="flex items-center gap-2">
                    <div class="avatar">
                      <div class="w-6 h-6 rounded-full">
                        <img src={u.avatar_url} alt={to_string(u.display_label)} />
                      </div>
                    </div>
                    <span class="truncate">{to_string(u.display_label)}</span>
                  </button>
                </li>
              </ul>
            </div>
          </div>
        </nav>

        <div class="p-3 border-t border-base-content/10">
          <div class="flex items-center gap-3">
            <div class="relative cursor-pointer" onclick="document.getElementById('profile-modal').showModal()">
              <div class="avatar">
                <div class="w-9 rounded-full">
                  <img src={@current_user.avatar_url} alt="Avatar" />
                </div>
              </div>
              <div class="absolute -bottom-0.5 -right-0.5 presence-dot bg-success"></div>
            </div>
            <div class="flex-1 min-w-0">
              <div class="text-sm font-medium truncate">{@current_user.display_label}</div>
              <div :if={@current_user.status_emoji || @current_user.status_text} class="text-xs text-base-content/60 truncate">
                {if @current_user.status_emoji, do: @current_user.status_emoji <> " ", else: ""}{@current_user.status_text}
              </div>
            </div>
            <.link href={~p"/sign-out"} method="delete" class="btn btn-ghost btn-xs">
              <.icon name="hero-arrow-right-on-rectangle" class="w-4 h-4" />
            </.link>
          </div>
        </div>
      </aside>

      <main class="flex-1 flex flex-col min-w-0">
        <%= case @view_mode do %>
          <% :channel -> %>
            <header class="border-b border-base-300 px-5 py-3 flex-shrink-0 flex items-center justify-between">
              <div>
                <div class="font-bold text-lg"># {@channel.name}</div>
                <div :if={@channel.topic} class="text-sm opacity-50">{@channel.topic}</div>
              </div>
              <div class="flex items-center gap-2 text-sm opacity-60">
                <div class="flex items-center gap-1.5">
                  <div class="w-2 h-2 rounded-full bg-success"></div>
                  <span>{MapSet.size(@online_users)} online</span>
                </div>
              </div>
            </header>

            <div
              id="messages"
              phx-hook="ScrollBottom"
              phx-update="replace"
              class="flex-1 overflow-y-auto px-5 py-2"
            >
              <%= if @messages == [] do %>
                <div class="flex flex-col items-center justify-center h-full text-center">
                  <div class="text-4xl mb-3">#</div>
                  <h3 class="text-lg font-bold mb-1">This is the beginning of #{@channel.name}</h3>
                  <p :if={@channel.topic} class="text-sm opacity-60 max-w-md">{@channel.topic}</p>
                  <p :if={!@channel.topic} class="text-sm opacity-50">Send a message to get the conversation started.</p>
                </div>
              <% else %>
                <.message_list
                  grouped_messages={@grouped_messages}
                  current_user_id={@current_user.id}
                  msg_type={:channel}
                  id_prefix="msg"
                />
              <% end %>
            </div>

            <div class="border-t border-base-300 px-5 py-3 flex-shrink-0">
              <form phx-submit="send_message">
                <div class="relative">
                  <textarea
                    id="message-input"
                    name="body"
                    phx-hook="MessageInput"
                    placeholder={"Message ##{@channel.name}"}
                    class="message-textarea textarea textarea-bordered w-full pr-16 leading-normal"
                    autocomplete="off"
                    rows="1"
                  ></textarea>
                  <button type="submit" class="btn btn-primary btn-sm absolute right-2 bottom-2">
                    Send
                  </button>
                </div>
              </form>
            </div>

          <% :dm -> %>
            <% other = other_participant(@conversation, @current_user.id) %>
            <header class="border-b border-base-300 px-5 py-3 flex-shrink-0 flex items-center gap-3">
              <div :if={other} class="avatar">
                <div class="w-8 h-8 rounded-full">
                  <img src={other.avatar_url} alt={to_string(other.display_label)} />
                </div>
              </div>
              <div :if={other} class="font-bold text-lg">{to_string(other.display_label)}</div>
            </header>

            <div
              id="dm-messages"
              phx-hook="ScrollBottom"
              phx-update="replace"
              class="flex-1 overflow-y-auto px-5 py-2"
            >
              <%= if @dm_messages == [] do %>
                <div class="flex flex-col items-center justify-center h-full text-center">
                  <div :if={other} class="avatar mb-3">
                    <div class="w-16 h-16 rounded-full">
                      <img src={other.avatar_url} alt={to_string(other.display_label)} />
                    </div>
                  </div>
                  <h3 :if={other} class="text-lg font-bold mb-1">{to_string(other.display_label)}</h3>
                  <p class="text-sm opacity-50">This is the beginning of your conversation.</p>
                </div>
              <% else %>
                <.message_list
                  grouped_messages={@grouped_dm_messages}
                  current_user_id={@current_user.id}
                  msg_type={:dm}
                  id_prefix="dm"
                />
              <% end %>
            </div>

            <div class="border-t border-base-300 px-5 py-3 flex-shrink-0">
              <form phx-submit="send_dm">
                <div class="relative">
                  <textarea
                    id="dm-input"
                    name="body"
                    phx-hook="MessageInput"
                    placeholder={if other, do: "Message #{to_string(other.display_label)}", else: "Message"}
                    class="message-textarea textarea textarea-bordered w-full pr-16 leading-normal"
                    autocomplete="off"
                    rows="1"
                  ></textarea>
                  <button type="submit" class="btn btn-primary btn-sm absolute right-2 bottom-2">
                    Send
                  </button>
                </div>
              </form>
            </div>

          <% _ -> %>
            <div class="flex-1 flex flex-col items-center justify-center text-center p-8">
              <h1 class="text-4xl font-bold mb-2 tracking-tight">SLOUCH</h1>
              <p class="text-lg opacity-60 mb-6">Your team's chat, minus the hustle.</p>
              <%= if @channels == [] do %>
                <p class="text-sm opacity-50">Create a channel in the sidebar to get started.</p>
              <% else %>
                <p class="text-sm opacity-50">Select a channel or conversation to start chatting</p>
              <% end %>
            </div>
        <% end %>
      </main>

      <div :if={@show_thread} class="thread-panel w-96 border-l border-base-300 flex flex-col bg-base-100 flex-shrink-0">
        <div class="flex items-center justify-between px-4 py-3 border-b border-base-300">
          <h3 class="font-bold">Thread</h3>
          <button phx-click="close_thread" class="btn btn-ghost btn-sm btn-circle">
            <.icon name="hero-x-mark" class="w-4 h-4" />
          </button>
        </div>

        <div class="p-4 border-b border-base-300 bg-base-200/30">
          <div class="flex items-start gap-3">
            <div class="flex-shrink-0">
              <div class="avatar">
                <div class="w-9 h-9 rounded-full">
                  <img src={@thread_parent.user.avatar_url} alt={user_display(@thread_parent)} />
                </div>
              </div>
            </div>
            <div class="min-w-0">
              <div class="flex items-baseline gap-2">
                <span class="font-semibold text-sm">{user_display(@thread_parent)}</span>
                <.bot_badge :if={Map.get(@thread_parent.user, :is_bot, false)} />
                <span class="text-xs opacity-40">{format_time(@thread_parent.inserted_at)}</span>
              </div>
              <p class="text-sm mt-0.5 whitespace-pre-wrap">{@thread_parent.body}</p>
            </div>
          </div>
        </div>

        <div :if={@thread_replies != []} class="px-4 py-2 border-b border-base-300">
          <span class="text-xs font-medium opacity-50">
            {length(@thread_replies)} {if length(@thread_replies) == 1, do: "reply", else: "replies"}
          </span>
        </div>

        <div class="flex-1 overflow-y-auto p-4 space-y-3" id="thread-messages" phx-hook="ScrollBottom">
          <div :for={reply <- @thread_replies} class="flex items-start gap-3">
            <div class="flex-shrink-0">
              <div class="avatar">
                <div class="w-8 h-8 rounded-full">
                  <img src={reply.user.avatar_url} alt={user_display(reply)} />
                </div>
              </div>
            </div>
            <div class="min-w-0">
              <div class="flex items-baseline gap-2">
                <span class="font-semibold text-sm">{user_display(reply)}</span>
                <.bot_badge :if={Map.get(reply.user, :is_bot, false)} />
                <span class="text-xs opacity-40">{format_time(reply.inserted_at)}</span>
              </div>
              <p class="text-sm mt-0.5 whitespace-pre-wrap">{reply.body}</p>
            </div>
          </div>
        </div>

        <div class="p-3 border-t border-base-300">
          <form phx-submit="send_reply">
            <div class="relative">
              <textarea
                id="reply-input"
                name="body"
                phx-hook="MessageInput"
                placeholder="Reply..."
                class="message-textarea textarea textarea-bordered textarea-sm w-full pr-16 leading-normal"
                autocomplete="off"
                rows="1"
              ></textarea>
              <button type="submit" class="btn btn-primary btn-xs absolute right-2 bottom-2">
                Send
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>

    <dialog id="profile-modal" class="modal">
      <div class="modal-box">
        <h3 class="font-bold text-lg mb-4">Edit Profile</h3>
        <form phx-submit="update_profile">
          <div class="flex flex-col items-center mb-4">
            <div class="avatar mb-2">
              <div class="w-20 rounded-full">
                <img src={@current_user.avatar_url} alt="Avatar" />
              </div>
            </div>
            <button type="button" phx-click="randomize_avatar" class="btn btn-ghost btn-xs mt-1">
              <.icon name="hero-arrow-path" class="w-3.5 h-3.5" /> Randomize
            </button>
            <p class="text-sm text-base-content/60 mt-1">{@current_user.email}</p>
          </div>

          <div class="form-control mb-3">
            <label class="label"><span class="label-text">Display Name</span></label>
            <input type="text" name="display_name" value={@current_user.display_name}
              placeholder="How should others see you?" class="input input-bordered" />
          </div>

          <div class="form-control mb-3">
            <label class="label"><span class="label-text">Status</span></label>
            <input type="text" name="status_text" value={@current_user.status_text}
              placeholder="What's your status?" class="input input-bordered" />
            <input type="hidden" name="status_emoji" value={@current_user.status_emoji} />
          </div>

          <div class="form-control mb-3" id="theme-selector" phx-hook="ThemeSelector">
            <label class="label"><span class="label-text">Theme</span></label>
            <div class="flex flex-wrap gap-2">
              <button type="button" phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="system" class="btn btn-sm">
                <.icon name="hero-computer-desktop-micro" class="size-4" /> System
              </button>
              <button type="button" phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="light" class="btn btn-sm">
                <.icon name="hero-sun-micro" class="size-4" /> Light
              </button>
              <button type="button" phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="dark" class="btn btn-sm">
                <.icon name="hero-moon-micro" class="size-4" /> Dark
              </button>
              <button type="button" phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="catppuccin-latte" class="btn btn-sm">
                <.icon name="hero-sun-micro" class="size-4" /> Catppuccin Latte
              </button>
              <button type="button" phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="catppuccin-mocha" class="btn btn-sm">
                <.icon name="hero-moon-micro" class="size-4" /> Catppuccin Mocha
              </button>
            </div>
          </div>

          <div class="modal-action">
            <button type="button" onclick="document.getElementById('profile-modal').close()" class="btn">Cancel</button>
            <button type="submit" class="btn btn-primary">Save</button>
          </div>
        </form>
      </div>
      <form method="dialog" class="modal-backdrop"><button>close</button></form>
    </dialog>

    <Layouts.flash_group flash={@flash} />
    """
  end

  defp message_list(assigns) do
    ~H"""
    <div :for={{msg, show_date, compact} <- @grouped_messages} id={"#{@id_prefix}-#{msg.id}"}>
      <div :if={show_date} class="flex items-center gap-3 my-4">
        <div class="flex-1 border-t border-base-300"></div>
        <span class="text-xs font-medium opacity-50 whitespace-nowrap">
          {format_date_label(DateTime.to_date(msg.inserted_at))}
        </span>
        <div class="flex-1 border-t border-base-300"></div>
      </div>

      <%= if compact do %>
        <div class="message-row group flex items-start pl-12 pr-2 py-0.5 -mx-2 rounded hover:bg-base-200/50 transition-colors relative">
          <span class="compact-time text-xs opacity-0 absolute left-1 top-1 w-10 text-right tabular-nums">
            {format_time(msg.inserted_at)}
          </span>
          <div class="flex-1 min-w-0">
            <div class="text-sm whitespace-pre-wrap">{msg.body}</div>
            <.message_extras msg={msg} current_user_id={@current_user_id} msg_type={@msg_type} />
          </div>
          <.message_actions msg={msg} msg_type={@msg_type} />
        </div>
      <% else %>
        <div class="message-row group flex gap-3 pr-2 py-1.5 -mx-2 px-2 rounded hover:bg-base-200/50 transition-colors relative mt-3 first:mt-0">
          <div class="flex-shrink-0 mt-0.5">
            <div class="avatar">
              <div class="w-9 h-9 rounded-full">
                <img src={msg.user.avatar_url} alt={user_display(msg)} />
              </div>
            </div>
          </div>
          <div class="flex-1 min-w-0">
            <div class="flex items-baseline gap-2">
              <span class="font-semibold text-sm hover:underline cursor-pointer">{user_display(msg)}</span>
              <.bot_badge :if={Map.get(msg.user, :is_bot, false)} />
              <span class="text-xs opacity-40">{format_time(msg.inserted_at)}</span>
            </div>
            <div class="text-sm whitespace-pre-wrap">{msg.body}</div>
            <.message_extras msg={msg} current_user_id={@current_user_id} msg_type={@msg_type} />
          </div>
          <.message_actions msg={msg} msg_type={@msg_type} />
        </div>
      <% end %>
    </div>
    """
  end

  defp bot_badge(assigns) do
    ~H"""
    <span class="badge badge-xs badge-primary font-semibold tracking-wide">BOT</span>
    """
  end

  defp message_extras(assigns) do
    reaction_event = if assigns.msg_type == :dm, do: "toggle_dm_reaction", else: "toggle_reaction"
    thread_event = if assigns.msg_type == :dm, do: "open_dm_thread", else: "open_thread"
    assigns = assign(assigns, reaction_event: reaction_event, thread_event: thread_event)

    ~H"""
    <div :if={@msg.reactions != []} class="flex items-center gap-1 mt-1 flex-wrap">
      <button
        :for={reaction_group <- group_reactions(@msg.reactions, @current_user_id)}
        phx-click={@reaction_event}
        phx-value-message-id={@msg.id}
        phx-value-emoji={reaction_group.emoji}
        class={[
          "badge badge-sm gap-1 cursor-pointer hover:badge-primary transition-colors",
          reaction_group.reacted_by_me && "badge-primary"
        ]}
      >
        <span>{reaction_group.emoji}</span>
        <span>{reaction_group.count}</span>
      </button>
    </div>
    <div :if={@msg.reply_count > 0} class="mt-1">
      <button
        phx-click={@thread_event}
        phx-value-message-id={@msg.id}
        class="text-xs text-primary hover:underline cursor-pointer"
      >
        {if @msg.reply_count == 1, do: "1 reply", else: "#{@msg.reply_count} replies"}
      </button>
    </div>
    """
  end

  defp message_actions(assigns) do
    reaction_event = if assigns.msg_type == :dm, do: "toggle_dm_reaction", else: "toggle_reaction"
    thread_event = if assigns.msg_type == :dm, do: "open_dm_thread", else: "open_thread"
    assigns = assign(assigns, reaction_event: reaction_event, thread_event: thread_event)

    ~H"""
    <div class="message-actions opacity-0 transition-opacity absolute -top-3 right-2 flex items-center bg-base-100 border border-base-300 rounded-full shadow-sm px-1 h-8">
      <button
        :for={emoji <- ~w(👍 😂 ✅)}
        phx-click={@reaction_event}
        phx-value-message-id={@msg.id}
        phx-value-emoji={emoji}
        class="hover:bg-base-200 rounded-full w-7 h-7 flex items-center justify-center text-base transition-colors"
        title={"React with #{emoji}"}
      >
        {emoji}
      </button>
      <div class="dropdown dropdown-end dropdown-top">
        <div
          tabindex="0"
          role="button"
          class="hover:bg-base-200 rounded-full w-7 h-7 flex items-center justify-center transition-colors"
          title="More reactions"
        >
          <.icon name="hero-face-smile" class="w-4 h-4 opacity-50" />
        </div>
        <div
          tabindex="0"
          class="dropdown-content z-50 p-2 shadow-lg bg-base-200 rounded-box mb-1"
        >
          <div class="flex gap-1">
            <button
              :for={emoji <- ~w(👍 ❤️ 😂 🎉 🤔 👀 🚀 ✅)}
              phx-click={@reaction_event}
              phx-value-message-id={@msg.id}
              phx-value-emoji={emoji}
              class="btn btn-ghost btn-sm text-lg hover:bg-base-300"
            >
              {emoji}
            </button>
          </div>
        </div>
      </div>
      <div class="w-px h-4 bg-base-300 mx-0.5"></div>
      <button
        phx-click={@thread_event}
        phx-value-message-id={@msg.id}
        class="hover:bg-base-200 rounded-full w-7 h-7 flex items-center justify-center transition-colors"
        title="Reply in thread"
      >
        <.icon name="hero-chat-bubble-left" class="w-4 h-4 opacity-50" />
      </button>
    </div>
    """
  end
end
