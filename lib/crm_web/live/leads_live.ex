defmodule CrmWeb.LeadsLive do
  use CrmWeb, :live_view

  alias Crm.Pipeline
  alias Crm.Pipeline.Lead

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Crm.PubSub, "leads")

    filters = %{search: "", status: "all"}
    leads = Pipeline.list_leads(filters)
    all_leads = Pipeline.list_leads()

    {:ok,
     assign(socket,
       leads: leads,
       stats: compute_stats(all_leads),
       filters: filters,
       form: nil,
       page: 1,
       per_page: 10,
       filtered_count: length(leads)
     )}
  end

  @impl true
  def handle_info({:lead_updated, _updated_lead}, socket) do
    leads = Pipeline.list_leads(socket.assigns.filters)
    all_leads = Pipeline.list_leads()

    {:noreply,
     assign(socket, leads: leads, stats: compute_stats(all_leads), filtered_count: length(leads))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, form: nil, editing_lead: nil, page_title: "Leads")
  end

  defp apply_action(socket, :new, _params) do
    changeset = Pipeline.change_lead(%Lead{})
    assign(socket, form: to_form(changeset), editing_lead: nil, page_title: "New Lead")
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    lead = Pipeline.get_lead!(id)
    changeset = Pipeline.change_lead(lead)
    assign(socket, form: to_form(changeset), editing_lead: lead, page_title: "Edit Lead")
  end

  @impl true
  def handle_event("save", %{"lead" => params}, socket) do
    case socket.assigns.live_action do
      :new -> create_lead(socket, params)
      :edit -> update_lead(socket, params)
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    lead = Pipeline.get_lead!(id)

    case Pipeline.delete_lead(lead) do
      {:ok, _} ->
        leads = Enum.reject(socket.assigns.leads, &(&1.id == lead.id))

        {:noreply,
         socket
         |> assign(leads: leads, stats: compute_stats(leads), filtered_count: length(leads))
         |> put_flash(:info, "Lead deleted.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete lead.")}
    end
  end

  def handle_event("retry", %{"id" => id}, socket) do
    lead = Pipeline.get_lead!(id)

    case Pipeline.retry_lead(lead) do
      {:ok, _} ->
        {:noreply, put_flash(socket, :info, "Retrying draft for #{lead.contact_person}.")}

      {:error, :invalid_status} ->
        {:noreply, put_flash(socket, :error, "Only failed leads can be retried.")}
    end
  end

  def handle_event("draft_now", %{"id" => id}, socket) do
    lead = Pipeline.get_lead!(id)

    case Pipeline.enqueue_draft(lead) do
      {:ok, _} ->
        {:noreply, put_flash(socket, :info, "Drafting started for #{lead.contact_person}.")}

      {:error, :invalid_status} ->
        {:noreply, put_flash(socket, :error, "Lead must be pending to draft.")}
    end
  end

  def handle_event("filter", params, socket) do
    filters = %{search: params["search"] || "", status: params["status"] || "all"}
    leads = Pipeline.list_leads(filters)

    {:noreply,
     assign(socket, leads: leads, filters: filters, page: 1, filtered_count: length(leads))}
  end

  def handle_event("validate", %{"lead" => params}, socket) do
    lead = socket.assigns.editing_lead || %Lead{}
    changeset = Pipeline.change_lead(lead, params) |> Map.put(:action, :validate)
    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    {:noreply, assign(socket, page: String.to_integer(page))}
  end

  defp create_lead(socket, params) do
    case Pipeline.create_lead(params) do
      {:ok, _lead} ->
        leads = Pipeline.list_leads()

        {:noreply,
         socket
         |> put_flash(:info, "Lead created.")
         |> assign(leads: leads, stats: compute_stats(leads))
         |> push_navigate(to: ~p"/leads")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp update_lead(socket, params) do
    case Pipeline.update_lead(socket.assigns.editing_lead, params) do
      {:ok, _lead} ->
        leads = Pipeline.list_leads()

        {:noreply,
         socket
         |> put_flash(:info, "Lead updated.")
         |> assign(leads: leads, stats: compute_stats(leads), page: 1)
         |> push_navigate(to: ~p"/leads")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-100">
      <%!-- Page header --%>
      <div class="border-b border-base-300 bg-base-100 px-6 py-5">
        <div class="mx-auto max-w-7xl flex items-center justify-between">
          <div>
            <h1 class="text-xl font-semibold tracking-tight">Leads</h1>
            <p class="text-sm text-base-content/50 mt-0.5">Manage your sales pipeline</p>
          </div>
          <div class="flex items-center gap-2">
            <.link navigate={~p"/drafts"} class="btn btn-ghost btn-sm gap-1.5">
              <.icon name="hero-envelope-micro" class="size-4" /> Drafts
              <span :if={@stats.awaiting_review > 0} class="badge badge-warning badge-xs">
                {@stats.awaiting_review}
              </span>
            </.link>
            <.button navigate={~p"/leads/new"} variant="primary">
              <.icon name="hero-plus-micro" class="size-4 mr-1" /> New Lead
            </.button>
          </div>
        </div>
      </div>

      <div class="mx-auto max-w-7xl px-6 py-6 space-y-6">
        <%!-- Search + filter row --%>
        <form phx-change="filter" phx-submit="filter" class="flex flex-col sm:flex-row gap-3">
          <input type="hidden" name="status" value={@filters.status} />
          <div class="relative flex-1">
            <.icon
              name="hero-magnifying-glass-micro"
              class="absolute left-3 top-1/2 -translate-y-1/2 size-4 text-base-content/40 pointer-events-none"
            />
            <input
              type="text"
              name="search"
              value={@filters.search}
              placeholder="Search contact, company, or email…"
              phx-debounce="300"
              class="input input-bordered w-full pl-9 text-sm"
            />
          </div>
          <div class="flex flex-wrap gap-1">
            <%= for {label, value} <- [{"All", "all"}, {"Pending", "pending"}, {"Drafting", "drafting"},
                                        {"In Review", "awaiting_review"}, {"Approved", "approved"},
                                        {"Sent", "sent"}, {"Failed", "failed"}] do %>
              <button
                type="button"
                phx-click="filter"
                phx-value-search={@filters.search}
                phx-value-status={value}
                class={[
                  "btn btn-xs",
                  if(@filters.status == value, do: "btn-primary", else: "btn-ghost")
                ]}
              >
                {label}
              </button>
            <% end %>
          </div>
        </form>

        <%!-- Stats row --%>
        <div class="grid grid-cols-2 sm:grid-cols-4 gap-4">
          <div class="bg-base-200 rounded-xl p-4 flex flex-col gap-1">
            <span class="text-xs font-medium text-base-content/50 uppercase tracking-wide">
              Total
            </span>
            <span class="text-3xl font-bold">{@stats.total}</span>
          </div>
          <div class="bg-base-200 rounded-xl p-4 flex flex-col gap-1">
            <span class="text-xs font-medium text-base-content/50 uppercase tracking-wide">
              Pending
            </span>
            <span class="text-3xl font-bold text-info">{@stats.pending}</span>
          </div>
          <div class="bg-base-200 rounded-xl p-4 flex flex-col gap-1">
            <span class="text-xs font-medium text-base-content/50 uppercase tracking-wide">
              In Review
            </span>
            <span class="text-3xl font-bold text-warning">{@stats.awaiting_review}</span>
          </div>
          <div class="bg-base-200 rounded-xl p-4 flex flex-col gap-1">
            <span class="text-xs font-medium text-base-content/50 uppercase tracking-wide">Sent</span>
            <span class="text-3xl font-bold text-success">{@stats.sent}</span>
          </div>
        </div>

        <%!-- Slide-in form panel --%>
        <div
          :if={@live_action in [:new, :edit]}
          class="rounded-xl border border-base-300 bg-base-200 overflow-hidden"
        >
          <div class="flex items-center justify-between px-5 py-4 border-b border-base-300">
            <h2 class="font-semibold">
              {if @live_action == :new, do: "Add new lead", else: "Edit lead"}
            </h2>
            <.link
              navigate={~p"/leads"}
              class="text-base-content/40 hover:text-base-content transition-colors"
            >
              <.icon name="hero-x-mark" class="size-5" />
            </.link>
          </div>
          <div class="px-5 py-5">
            <.form
              for={@form}
              phx-submit="save"
              phx-change="validate"
              class="grid grid-cols-1 sm:grid-cols-3 gap-4"
            >
              <.input
                field={@form[:contact_person]}
                label="Contact Person"
                placeholder="Jane Smith"
                required
              />
              <.input field={@form[:company_name]} label="Company" placeholder="Acme Corp" required />
              <.input
                field={@form[:email_address]}
                type="email"
                label="Email"
                placeholder="jane@acme.com"
                required
              />
              <div class="sm:col-span-3 flex gap-3 pt-1">
                <.button type="submit" variant="primary">
                  {if @live_action == :new, do: "Create lead", else: "Save changes"}
                </.button>
                <.button navigate={~p"/leads"}>Cancel</.button>
              </div>
            </.form>
          </div>
        </div>

        <%!-- Pagination controls --%>
        <% pages = total_pages(@filtered_count, @per_page) %>
        <%= if pages > 1 do %>
          <div class="flex items-center justify-between mt-4 px-1">
            <p class="text-xs text-base-content/40">
              Page {@page} of {pages}
            </p>
            <div class="join">
              <button
                phx-click="paginate"
                phx-value-page={@page - 1}
                disabled={@page == 1}
                class="join-item btn btn-sm btn-ghost disabled:opacity-30"
              >
                <.icon name="hero-chevron-left" class="size-4" /> Prev
              </button>
              <%= for p <- max(1, @page - 2)..min(pages, @page + 2) do %>
                <button
                  phx-click="paginate"
                  phx-value-page={p}
                  class={[
                    "join-item btn btn-sm",
                    if(p == @page, do: "btn-primary", else: "btn-ghost")
                  ]}
                >
                  {p}
                </button>
              <% end %>
              <button
                phx-click="paginate"
                phx-value-page={@page + 1}
                disabled={@page >= pages}
                class="join-item btn btn-sm btn-ghost disabled:opacity-30"
              >
                Next <.icon name="hero-chevron-right" class="size-4" />
              </button>
            </div>
          </div>
        <% end %>

        <%!-- Leads table --%>
        <div class="rounded-xl border border-base-300 overflow-hidden">
          <table class="w-full text-sm">
            <thead>
              <tr class="bg-base-200 border-b border-base-300">
                <th class="text-left px-4 py-3 font-medium text-base-content/60">Contact</th>
                <th class="text-left px-4 py-3 font-medium text-base-content/60">Company</th>
                <th class="text-left px-4 py-3 font-medium text-base-content/60 hidden sm:table-cell">
                  Email
                </th>
                <th class="text-left px-4 py-3 font-medium text-base-content/60">Status</th>
                <th class="text-left px-4 py-3 font-medium text-base-content/60 hidden md:table-cell">
                  Added
                </th>
                <th class="px-4 py-3"></th>
              </tr>
            </thead>
            <tbody>
              <tr :if={@leads == []}>
                <td colspan="6" class="text-center text-base-content/40 py-16">
                  <.icon name="hero-user-group" class="size-8 mx-auto mb-2 opacity-30" />
                  <p>No leads yet.</p>
                  <.link
                    navigate={~p"/leads/new"}
                    class="text-primary underline underline-offset-2 text-sm"
                  >
                    Add your first lead
                  </.link>
                </td>
              </tr>
              <tr
                :for={lead <- page_leads(@leads, @page, @per_page)}
                class="border-t border-base-300 hover:bg-base-200/50 transition-colors group"
              >
                <td class="px-4 py-3 font-medium">{lead.contact_person}</td>
                <td class="px-4 py-3 text-base-content/70">{lead.company_name}</td>
                <td class="px-4 py-3 text-base-content/60 hidden sm:table-cell">
                  {lead.email_address}
                </td>
                <td class="px-4 py-3">
                  <span class={[
                    "inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium",
                    status_pill_class(lead.already_emailed)
                  ]}>
                    <span class={["size-1.5 rounded-full", status_dot_class(lead.already_emailed)]}>
                    </span>
                    {lead.already_emailed}
                  </span>
                </td>
                <td class="px-4 py-3 text-base-content/40 hidden md:table-cell">
                  {Calendar.strftime(lead.inserted_at, "%b %d, %Y")}
                </td>
                <td class="px-4 py-3">
                  <div class="flex gap-2 justify-end opacity-0 group-hover:opacity-100 transition-opacity">
                    <button
                      :if={lead.already_emailed == :failed}
                      class="btn btn-xs btn-ghost text-warning"
                      phx-click="retry"
                      phx-value-id={lead.id}
                      title={lead.last_error}
                    >
                      <.icon name="hero-arrow-path-micro" class="size-3.5" /> Retry
                    </button>
                    <button
                      :if={lead.already_emailed == :pending}
                      class="btn btn-xs btn-ghost text-info"
                      phx-click="draft_now"
                      phx-value-id={lead.id}
                    >
                      <.icon name="hero-bolt-micro" class="size-3.5" /> Draft
                    </button>
                    <.link
                      navigate={~p"/leads/#{lead.id}/edit"}
                      class="btn btn-xs btn-ghost"
                    >
                      <.icon name="hero-pencil-micro" class="size-3.5" /> Edit
                    </.link>
                    <button
                      class="btn btn-xs btn-ghost text-error"
                      phx-click="delete"
                      phx-value-id={lead.id}
                      data-confirm={"Delete #{lead.contact_person}?"}
                    >
                      <.icon name="hero-trash-micro" class="size-3.5" /> Delete
                    </button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  defp compute_stats(leads) do
    %{
      total: length(leads),
      pending: Enum.count(leads, &(&1.already_emailed == :pending)),
      awaiting_review: Enum.count(leads, &(&1.already_emailed == :awaiting_review)),
      sent: Enum.count(leads, &(&1.already_emailed == :sent))
    }
  end

  defp status_pill_class(:pending), do: "bg-base-300 text-base-content/70"
  defp status_pill_class(:drafting), do: "bg-info/15 text-info"
  defp status_pill_class(:awaiting_review), do: "bg-warning/15 text-warning"
  defp status_pill_class(:approved), do: "bg-accent/15 text-accent"
  defp status_pill_class(:sent), do: "bg-success/15 text-success"
  defp status_pill_class(:failed), do: "bg-error/15 text-error"

  defp status_dot_class(:pending), do: "bg-base-content/40"
  defp status_dot_class(:drafting), do: "bg-info"
  defp status_dot_class(:awaiting_review), do: "bg-warning"
  defp status_dot_class(:approved), do: "bg-accent"
  defp status_dot_class(:sent), do: "bg-success"
  defp status_dot_class(:failed), do: "bg-error"

  defp page_leads(leads, page, per_page) do
    Enum.slice(leads, (page - 1) * per_page, per_page)
  end

  defp total_pages(count, per_page), do: div(count + per_page - 1, per_page)
end
