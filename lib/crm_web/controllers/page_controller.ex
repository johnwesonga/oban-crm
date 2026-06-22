defmodule CrmWeb.PageController do
  use CrmWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
