defmodule SlouchWeb.PageControllerTest do
  use SlouchWeb.ConnCase

  test "GET / redirects unauthenticated users to sign-in", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) =~ "/sign-in"
  end
end
