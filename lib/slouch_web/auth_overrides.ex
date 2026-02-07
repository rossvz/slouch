defmodule SlouchWeb.AuthOverrides do
  use AshAuthentication.Phoenix.Overrides

  override AshAuthentication.Phoenix.Components.Password do
    set :register_extra_component, SlouchWeb.Components.RegisterExtra
  end
end
