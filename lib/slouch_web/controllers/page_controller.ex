defmodule SlouchWeb.PageController do
  use SlouchWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
