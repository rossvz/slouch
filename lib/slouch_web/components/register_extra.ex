defmodule SlouchWeb.Components.RegisterExtra do
  use Phoenix.Component
  import Phoenix.HTML.Form, only: [input_id: 2]
  import PhoenixHTMLHelpers.Form

  def render(assigns) do
    ~H"""
    <div class="mt-2 mb-2">
      <label
        class="block text-sm font-medium text-base-content mb-1"
        for={input_id(@form, :display_name)}
      >
        Display name
      </label>
      {text_input(@form, :display_name,
        class: "input w-full",
        placeholder: "How others will see you"
      )}
    </div>
    """
  end
end
