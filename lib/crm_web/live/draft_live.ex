defmodule CrmWeb.DraftLive do
  use CrmWeb, :live_view

  alias Crm.Pipeline

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Crm.PubSub, "leads")

    lead = Pipeline.get_lead!(id)
    changeset = Pipeline.change_lead(lead, %{})

    {:ok,
     assign(socket,
       lead: lead,
       form: to_form(changeset, as: "draft"),
       page_title: "Edit Draft"
     )}
  end

  @impl true
  def handle_info({:lead_updated, updated_lead}, socket) do
    if updated_lead.id == socket.assigns.lead.id do
      {:noreply,
       assign(socket,
         lead: updated_lead,
         form: to_form(Pipeline.change_lead(updated_lead, %{}), as: "draft")
       )}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("validate", %{"draft" => params}, socket) do
    changeset =
      Pipeline.change_lead(socket.assigns.lead, params) |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: "draft"))}
  end

  def handle_event("save", %{"draft" => params}, socket) do
    case Pipeline.update_lead(socket.assigns.lead, params) do
      {:ok, updated_lead} ->
        {:noreply,
         socket
         |> assign(
           lead: updated_lead,
           form: to_form(Pipeline.change_lead(updated_lead, %{}), as: "draft")
         )
         |> put_flash(:info, "Draft saved.")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: "draft"))}
    end
  end

  def handle_event("approve", _params, socket) do
    case Pipeline.approve_lead(socket.assigns.lead) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Email queued for sending.")
         |> push_navigate(to: ~p"/drafts")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not approve draft.")}
    end
  end

  def handle_event("reject", _params, socket) do
    case Pipeline.update_lead_status(socket.assigns.lead.id, :pending) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Draft rejected, lead reset to pending.")
         |> push_navigate(to: ~p"/drafts")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not reject draft.")}
    end
  end

  def handle_event("regenerate", _params, socket) do
    case Pipeline.regenerate_draft(socket.assigns.lead) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Regenerating draft…")
         |> push_navigate(to: ~p"/drafts")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not regenerate draft.")}
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
            <h1 class="text-xl font-semibold tracking-tight">{@lead.contact_person}</h1>
            <p class="text-sm text-base-content/50 mt-0.5">
              {@lead.company_name} · {@lead.email_address}
            </p>
          </div>
          <.link navigate={~p"/drafts"} class="btn btn-ghost btn-sm gap-1.5">
            <.icon name="hero-arrow-left-micro" class="size-4" /> All Drafts
          </.link>
        </div>
      </div>

      <div class="mx-auto max-w-4xl px-6 py-6">
        <%!-- Wrong status notice --%>
        <div :if={@lead.already_emailed != :awaiting_review} class="alert alert-warning">
          <.icon name="hero-exclamation-triangle-micro" class="size-5" />
          <span>
            This lead is not in the review queue (status: <strong>{@lead.already_emailed}</strong>).
          </span>
          <.link navigate={~p"/leads"} class="btn btn-sm btn-ghost">Go to Leads</.link>
        </div>

        <%!-- Edit form --%>
        <div
          :if={@lead.already_emailed == :awaiting_review}
          class="rounded-xl border border-base-300 bg-base-200 overflow-hidden"
        >
          <div class="flex items-center justify-between px-5 py-4 border-b border-base-300">
            <h2 class="font-semibold text-sm">Email Draft</h2>
            <span class="text-xs text-base-content/40">
              Drafted {if @lead.drafted_at,
                do: Calendar.strftime(@lead.drafted_at, "%b %d at %H:%M"),
                else: "—"}
            </span>
          </div>

          <div
            :if={@lead.company_context not in [nil, ""]}
            class="px-5 py-3 bg-base-200/60 border-b border-base-300"
          >
            <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider mb-1">
              Company Context
            </p>
            <p class="text-sm text-base-content/70 whitespace-pre-wrap">{@lead.company_context}</p>
          </div>

          <div class="px-5 py-5 bg-base-100/50">
            <.form for={@form} phx-submit="save" phx-change="validate" class="space-y-4">
              <div class="space-y-1.5">
                <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                  Subject
                </p>
                <.input field={@form[:draft_subject]} placeholder="Email subject…" />
              </div>
              <div class="space-y-1.5">
                <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">
                  Body
                </p>
                <.input
                  field={@form[:draft_body]}
                  type="textarea"
                  rows="14"
                  placeholder="Email body…"
                  class="w-full font-sans text-sm leading-relaxed resize-y"
                />
              </div>
              <div class="pt-1">
                <.button type="submit" variant="primary">
                  <.icon name="hero-check-micro" class="size-4" /> Save changes
                </.button>
              </div>
            </.form>
          </div>

          <%!-- Action bar --%>
          <div class="flex items-center gap-3 px-5 py-4 border-t border-base-300 bg-base-200">
            <button
              class="btn btn-primary btn-sm gap-1.5"
              phx-click="approve"
              data-confirm={"Send this email to #{@lead.email_address}?"}
            >
              <.icon name="hero-paper-airplane-micro" class="size-4" /> Approve & Send
            </button>
            <button
              class="btn btn-ghost btn-sm text-base-content/60"
              phx-click="reject"
            >
              <.icon name="hero-x-mark-micro" class="size-4" /> Reject
            </button>
            <button
              class="btn btn-ghost btn-sm gap-1.5 text-info"
              phx-click="regenerate"
            >
              <.icon name="hero-arrow-path-micro" class="size-4" /> Regenerate
            </button>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
