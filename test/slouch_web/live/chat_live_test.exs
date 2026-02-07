defmodule SlouchWeb.ChatLiveTest do
  use SlouchWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Slouch.TestHelpers

  setup %{conn: conn} do
    user = create_user()
    channel = create_channel(%{name: "general", topic: "General chat"})

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> AshAuthentication.Plug.Helpers.store_in_session(user)

    %{conn: conn, user: user, channel: channel}
  end

  describe "mount without channel" do
    test "renders welcome page", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/chat")

      assert html =~ "SLOUCH"
      assert html =~ "Select a channel or conversation to start chatting"
      assert has_element?(view, "a", "general")
    end
  end

  describe "channel view" do
    test "renders channel header", %{conn: conn, channel: channel} do
      {:ok, _view, html} = live(conn, ~p"/chat/#{channel.name}")

      assert html =~ "# general"
      assert html =~ "General chat"
    end

    test "shows empty channel message", %{conn: conn, channel: channel} do
      {:ok, _view, html} = live(conn, ~p"/chat/#{channel.name}")

      assert html =~ "This is the beginning of #general"
    end

    test "displays existing messages", %{conn: conn, user: user, channel: channel} do
      create_message(channel, user, %{body: "Hello everyone!"})

      {:ok, _view, html} = live(conn, ~p"/chat/#{channel.name}")

      assert html =~ "Hello everyone!"
    end
  end

  describe "send_message" do
    test "sends a message", %{conn: conn, channel: channel} do
      {:ok, view, _html} = live(conn, ~p"/chat/#{channel.name}")

      view
      |> form("form[phx-submit='send_message']", %{body: "Hello from test!"})
      |> render_submit()

      html = render(view)
      assert html =~ "Hello from test!"
    end

    test "ignores blank messages", %{conn: conn, channel: channel} do
      {:ok, view, _html} = live(conn, ~p"/chat/#{channel.name}")

      view
      |> form("form[phx-submit='send_message']", %{body: "   "})
      |> render_submit()

      messages =
        Slouch.Chat.Message
        |> Ash.Query.for_read(:by_channel, %{channel_id: channel.id})
        |> Ash.read!()

      assert messages == []
    end
  end

  describe "create_channel" do
    test "creates a new channel and navigates to it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/chat")

      view
      |> form("form[phx-submit='create_channel']", %{name: "new-channel"})
      |> render_submit()

      assert_patch(view, ~p"/chat/new-channel")
      assert render(view) =~ "# new-channel"
    end

    test "normalizes channel name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/chat")

      view
      |> form("form[phx-submit='create_channel']", %{name: "My Channel!"})
      |> render_submit()

      assert_patch(view, ~p"/chat/my-channel-")
    end

    test "ignores blank channel name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/chat")

      view
      |> form("form[phx-submit='create_channel']", %{name: "   "})
      |> render_submit()

      channels = Ash.read!(Slouch.Chat.Channel)
      assert length(channels) == 1
    end
  end

  describe "update_profile" do
    test "updates the user profile", %{conn: conn, channel: channel} do
      {:ok, view, _html} = live(conn, ~p"/chat/#{channel.name}")

      view
      |> form("form[phx-submit='update_profile']", %{
        display_name: "New Name",
        status_text: "Working"
      })
      |> render_submit()

      html = render(view)
      assert html =~ "New Name"
    end
  end

  describe "threads" do
    test "opens a thread panel", %{conn: conn, user: user, channel: channel} do
      message = create_message(channel, user, %{body: "Thread parent"})

      {:ok, view, _html} = live(conn, ~p"/chat/#{channel.name}")

      view
      |> element("button[phx-click='open_thread'][phx-value-message-id='#{message.id}']")
      |> render_click()

      html = render(view)
      assert html =~ "Thread"
      assert html =~ "Thread parent"
    end

    test "sends a thread reply", %{conn: conn, user: user, channel: channel} do
      message = create_message(channel, user, %{body: "Thread parent"})

      {:ok, view, _html} = live(conn, ~p"/chat/#{channel.name}")

      view
      |> element("button[phx-click='open_thread'][phx-value-message-id='#{message.id}']")
      |> render_click()

      view
      |> form("form[phx-submit='send_reply']", %{body: "A reply!"})
      |> render_submit()

      html = render(view)
      assert html =~ "A reply!"
    end

    test "closes a thread panel", %{conn: conn, user: user, channel: channel} do
      message = create_message(channel, user, %{body: "Thread parent"})

      {:ok, view, _html} = live(conn, ~p"/chat/#{channel.name}")

      view
      |> element("button[phx-click='open_thread'][phx-value-message-id='#{message.id}']")
      |> render_click()

      assert render(view) =~ "Thread"

      view
      |> element("button[phx-click='close_thread']")
      |> render_click()

      refute render(view) =~ "thread-panel"
    end
  end

  describe "reactions" do
    test "adds a reaction to a message", %{conn: conn, user: user, channel: channel} do
      message = create_message(channel, user, %{body: "React to me"})

      {:ok, view, _html} = live(conn, ~p"/chat/#{channel.name}")

      view
      |> element(
        "button[phx-click='toggle_reaction'][phx-value-message-id='#{message.id}'][phx-value-emoji='👍'][title]"
      )
      |> render_click()

      reactions =
        Slouch.Chat.Reaction
        |> Ash.Query.for_read(:by_message, %{message_id: message.id})
        |> Ash.read!()

      assert length(reactions) == 1
      assert hd(reactions).emoji == "👍"
    end

    test "removes a reaction when toggled twice", %{conn: conn, user: user, channel: channel} do
      message = create_message(channel, user, %{body: "React to me"})

      {:ok, view, _html} = live(conn, ~p"/chat/#{channel.name}")

      selector =
        "button[phx-click='toggle_reaction'][phx-value-message-id='#{message.id}'][phx-value-emoji='👍'][title]"

      view |> element(selector) |> render_click()

      assert Slouch.Chat.Reaction
             |> Ash.Query.for_read(:by_message, %{message_id: message.id})
             |> Ash.read!()
             |> length() == 1

      view |> element(selector) |> render_click()

      assert Slouch.Chat.Reaction
             |> Ash.Query.for_read(:by_message, %{message_id: message.id})
             |> Ash.read!() == []
    end
  end

  describe "navigation" do
    test "navigating between channels loads correct messages", %{
      conn: conn,
      user: user,
      channel: channel
    } do
      create_message(channel, user, %{body: "In general"})
      channel2 = create_channel(%{name: "random"})
      create_message(channel2, user, %{body: "In random"})

      {:ok, view, _html} = live(conn, ~p"/chat/#{channel.name}")
      assert render(view) =~ "In general"
      refute render(view) =~ "In random"

      view |> element("a[href='/chat/random']") |> render_click()
      assert_patch(view, ~p"/chat/random")

      html = render(view)
      assert html =~ "In random"
      refute html =~ "In general"
    end
  end

  describe "authentication" do
    test "redirects unauthenticated users to sign-in" do
      conn = build_conn()
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/chat")

      assert path =~ "/sign-in"
    end
  end
end
