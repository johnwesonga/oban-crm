defmodule CrmWeb.DraftsLive do
  use CrmWeb, :live_view

  alias Crm.Pipeline

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Crm.PubSub, "email_drafts")
    end

    leads = Pipeline.list_awaiting_review_leads()

    {:ok,
     assign(socket, leads: leads, editing_id: nil, edit_form: nil, page_title: "Draft Review")}
  end

  @impl true
  def handle_info({:new_draft, lead}, socket) do
    {:noreply, assign(socket, leads: [lead | socket.assigns.leads])}
  end

  @impl true
  def handle_event("edit_draft", %{"id" => id}, socket) do
    lead = Enum.find(socket.assigns.leads, &(to_string(&1.id) == id))
    changeset = Pipeline.change_lead(lead, %{})
    {:noreply, assign(socket, editing_id: id, edit_form: to_form(changeset, as: "draft"))}
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, editing_id: nil, edit_form: nil)}
  end

  def handle_event("validate_draft", %{"draft" => params}, socket) do
    lead = Enum.find(socket.assigns.leads, &(to_string(&1.id) == socket.assigns.editing_id))
    changeset = Pipeline.change_lead(lead, params) |> Map.put(:action, :validate)
    {:noreply, assign(socket, edit_form: to_form(changeset, as: "draft"))}
  end

  def handle_event("save_draft", %{"draft" => params}, socket) do
    lead = Enum.find(socket.assigns.leads, &(to_string(&1.id) == socket.assigns.editing_id))

    case Pipeline.update_lead(lead, params) do
      {:ok, updated_lead} ->
        leads =
          Enum.map(socket.assigns.leads, fn l ->
            if l.id == updated_lead.id, do: updated_lead, else: l
          end)

        {:noreply,
         socket
         |> assign(leads: leads, editing_id: nil, edit_form: nil)
         |> put_flash(:info, "Draft updated.")}

      {:error, changeset} ->
        {:noreply, assign(socket, edit_form: to_form(changeset, as: "draft"))}
    end
  end

  @impl true
  def handle_event("approve", %{"id" => id}, socket) do
    lead = Pipeline.get_lead!(id)

    case Pipeline.approve_lead(lead) do
      {:ok, _} ->
        leads = Enum.reject(socket.assigns.leads, &(to_string(&1.id) == id))

        {:noreply,
         socket |> assign(leads: leads) |> put_flash(:info, "Email queued for sending.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not approve draft.")}
    end
  end

  @impl true
  def handle_event("regenerate", %{"id" => id}, socket) do
    lead = Pipeline.get_lead!(id)

    case Pipeline.regenerate_draft(lead) do
      {:ok, _} ->
        leads = Enum.reject(socket.assigns.leads, &(to_string(&1.id) == id))

        {:noreply,
         socket
         |> assign(leads: leads)
         |> put_flash(:info, "Regenerating draft for #{lead.contact_person}.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not regenerate draft.")}
    end
  end

  @impl true
  def handle_event("reject", %{"id" => id}, socket) do
    case Pipeline.update_lead_status(String.to_integer(id), :pending) do
      {:ok, _} ->
        leads = Enum.reject(socket.assigns.leads, &(to_string(&1.id) == id))

        {:noreply,
         socket
         |> assign(leads: leads)
         |> put_flash(:info, "Draft rejected, lead reset to pending.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not reject draft.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <%!-- Page header --%>
      <div class="border-b border-base-300 bg-base-100 px-6 py-5">
        <div class="mx-auto max-w-4xl flex items-center justify-between">
          <div>
            <h1 class="text-xl font-semibold tracking-tight">Draft Review</h1>
            <p class="text-sm text-base-content/50 mt-0.5">
              {length(@leads)} {if length(@leads) == 1, do: "draft", else: "drafts"} awaiting approval
            </p>
          </div>
          <.link navigate={~p"/leads"} class="btn btn-ghost btn-sm gap-1.5">
            <.icon name="hero-arrow-left-micro" class="size-4" /> All Leads
          </.link>
        </div>
      </div>

      <div class="mx-auto max-w-4xl px-6 py-6">
        <%!-- Empty state --%>
        <div
          :if={@leads == []}
          class="flex flex-col items-center justify-center py-24 gap-3 text-center"
        >
          <div class="size-14 rounded-full bg-base-200 flex items-center justify-center">
            <.icon name="hero-envelope" class="size-7 text-base-content/30" />
          </div>
          <p class="font-medium text-base-content/60">No drafts awaiting review</p>
          <p class="text-sm text-base-content/40">
            New drafts will appear here as the pipeline runs.
          </p>
        </div>

        <%!-- Draft cards --%>
        <div class="space-y-4">
          <div
            :for={lead <- @leads}
            class="rounded-xl border border-base-300 bg-base-200 overflow-hidden"
          >
            <%!-- Card header --%>
            <div class="flex items-center justify-between px-5 py-4 bg-base-200 border-b border-base-300">
              <div class="flex items-center gap-3">
                <div class="size-9 rounded-full bg-warning/15 flex items-center justify-center shrink-0">
                  <span class="text-warning font-semibold text-sm">
                    {lead.contact_person |> String.at(0) |> String.upcase()}
                  </span>
                </div>
                <div>
                  <p class="font-semibold text-sm">{lead.contact_person}</p>
                  <p class="text-xs text-base-content/50">
                    {lead.company_name} · {lead.email_address}
                  </p>
                </div>
              </div>
              <div class="flex items-center gap-2">
                <span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium bg-warning/15 text-warning">
                  <span class="size-1.5 rounded-full bg-warning"></span> awaiting review
                </span>
                <button
                  :if={@editing_id != to_string(lead.id)}
                  class="btn btn-ghost btn-xs gap-1"
                  phx-click="edit_draft"
                  phx-value-id={lead.id}
                >
                  <.icon name="hero-pencil-micro" class="size-3.5" /> Edit
                </button>
              </div>
            </div>

            <%!-- Email preview (read mode) --%>
            <div :if={@editing_id != to_string(lead.id)} class="px-5 py-4 space-y-4 bg-base-100/50">
              <div class="space-y-1.5">
                <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                  Subject
                </p>
                <p class="text-sm font-medium">{lead.draft_subject}</p>
              </div>
              <div class="space-y-1.5">
                <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                  Body
                </p>
                <pre class="text-sm text-base-content/80 whitespace-pre-wrap font-sans leading-relaxed">{lead.draft_body}</pre>
              </div>
            </div>

            <%!-- Email edit form (edit mode) --%>
            <div :if={@editing_id == to_string(lead.id)} class="px-5 py-4 bg-base-100/50">
              <.form
                for={@edit_form}
                phx-submit="save_draft"
                phx-change="validate_draft"
                class="space-y-4"
              >
                <div class="space-y-1.5">
                  <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                    Subject
                  </p>
                  <.input
                    field={@edit_form[:draft_subject]}
                    placeholder="Email subject…"
                    class="w-full"
                  />
                </div>
                <div class="space-y-1.5">
                  <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                    Body
                  </p>
                  <.input
                    field={@edit_form[:draft_body]}
                    type="textarea"
                    rows="10"
                    placeholder="Email body…"
                    class="w-full font-sans text-sm leading-relaxed resize-y"
                  />
                </div>
                <div class="flex gap-2 pt-1">
                  <button type="submit" class="btn btn-sm btn-primary gap-1.5">
                    <.icon name="hero-check-micro" class="size-4" /> Save
                  </button>
                  <button
                    type="button"
                    class="btn btn-sm btn-ghost"
                    phx-click="cancel_edit"
                  >
                    Cancel
                  </button>
                </div>
              </.form>
            </div>

            <%!-- Actions --%>
            <div class="flex items-center gap-3 px-5 py-4 border-t border-base-300 bg-base-200">
              <button
                class="btn btn-primary btn-sm gap-1.5"
                phx-click="approve"
                phx-value-id={lead.id}
                data-confirm={"Send this email to #{lead.email_address}?"}
              >
                <.icon name="hero-paper-airplane-micro" class="size-4" /> Approve & Send
              </button>
              <button
                class="btn btn-ghost btn-sm text-base-content/60"
                phx-click="reject"
                phx-value-id={lead.id}
              >
                <.icon name="hero-x-mark-micro" class="size-4" /> Reject
              </button>
              <button
                class="btn btn-ghost btn-sm gap-1.5 text-info"
                phx-click="regenerate"
                phx-value-id={lead.id}
              >
                <.icon name="hero-arrow-path-micro" class="size-4" /> Regenerate
              </button>
              <span class="ml-auto text-xs text-base-content/30">
                Drafted {if lead.drafted_at,
                  do: Calendar.strftime(lead.drafted_at, "%b %d at %H:%M"),
                  else: "—"}
              </span>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
