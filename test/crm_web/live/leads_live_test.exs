defmodule CrmWeb.LeadsLiveTest do
  use CrmWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Crm.Pipeline

  defp create_lead(attrs) do
    defaults = %{
      contact_person: "Test Person",
      company_name: "Test Corp",
      email_address: "test#{System.unique_integer([:positive])}@example.com"
    }

    {:ok, lead} = Pipeline.create_lead(Map.merge(defaults, attrs))
    lead
  end

  describe "filter UI" do
    test "renders search input and all status pills", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/leads")

      assert has_element?(view, "input[name='search']")

      for status <- ~w[all pending drafting awaiting_review approved sent failed] do
        assert has_element?(view, "button[phx-value-status='#{status}']"),
               "missing pill for status=#{status}"
      end
    end

    test "All pill is active by default", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/leads")

      assert has_element?(view, "button[phx-value-status='all'].btn-primary")
    end
  end

  describe "search" do
    test "filters leads by contact name", %{conn: conn} do
      create_lead(%{contact_person: "Alice Smith", company_name: "Acme"})
      create_lead(%{contact_person: "Bob Jones", company_name: "Beta"})

      {:ok, view, _html} = live(conn, ~p"/leads")

      html = render_change(view, "filter", %{"search" => "alice", "status" => "all"})

      assert html =~ "Alice Smith"
      refute html =~ "Bob Jones"
    end

    test "filters leads by company name", %{conn: conn} do
      create_lead(%{contact_person: "Person A", company_name: "FindMe Corp"})
      create_lead(%{contact_person: "Person B", company_name: "Hidden Inc"})

      {:ok, view, _html} = live(conn, ~p"/leads")

      html = render_change(view, "filter", %{"search" => "findme", "status" => "all"})

      assert html =~ "FindMe Corp"
      refute html =~ "Hidden Inc"
    end

    test "filters leads by email address", %{conn: conn} do
      create_lead(%{email_address: "needle@haystack.com"})
      create_lead(%{email_address: "other@ignore.com"})

      {:ok, view, _html} = live(conn, ~p"/leads")

      html = render_change(view, "filter", %{"search" => "needle", "status" => "all"})

      assert html =~ "needle@haystack.com"
      refute html =~ "other@ignore.com"
    end

    test "clearing search restores all leads", %{conn: conn} do
      create_lead(%{contact_person: "Alice"})
      create_lead(%{contact_person: "Bob"})

      {:ok, view, _html} = live(conn, ~p"/leads")

      render_change(view, "filter", %{"search" => "alice", "status" => "all"})
      html = render_change(view, "filter", %{"search" => "", "status" => "all"})

      assert html =~ "Alice"
      assert html =~ "Bob"
    end
  end

  describe "status filter" do
    test "clicking a status pill filters by that status", %{conn: conn} do
      create_lead(%{contact_person: "Pending Lead"})

      {:ok, _alice_sent} =
        Pipeline.create_lead(%{
          contact_person: "Sent Lead",
          company_name: "Corp",
          email_address: "sent#{System.unique_integer([:positive])}@corp.com",
          already_emailed: :sent
        })

      {:ok, view, _html} = live(conn, ~p"/leads")

      html = render_change(view, "filter", %{"search" => "", "status" => "pending"})

      assert html =~ "Pending Lead"
      refute html =~ "Sent Lead"
    end

    test "active pill updates when status changes", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/leads")

      render_change(view, "filter", %{"search" => "", "status" => "pending"})

      assert has_element?(view, "button[phx-value-status='pending'].btn-primary")
      refute has_element?(view, "button[phx-value-status='all'].btn-primary")
    end
  end

  describe "combined search + status" do
    test "search and status compose with AND logic", %{conn: conn} do
      create_lead(%{contact_person: "Alice Pending"})

      {:ok, _} =
        Pipeline.create_lead(%{
          contact_person: "Alice Sent",
          company_name: "Corp",
          email_address: "alicesent#{System.unique_integer([:positive])}@corp.com",
          already_emailed: :sent
        })

      {:ok, view, _html} = live(conn, ~p"/leads")

      html = render_change(view, "filter", %{"search" => "alice", "status" => "sent"})

      assert html =~ "Alice Sent"
      refute html =~ "Alice Pending"
    end

    test "typing preserves the active status filter", %{conn: conn} do
      create_lead(%{contact_person: "Alice", company_name: "Acme"})

      {:ok, view, _html} = live(conn, ~p"/leads")

      # Set status to pending via the hidden input being sent with form change
      render_change(view, "filter", %{"search" => "", "status" => "pending"})

      # Now type a search — the hidden input carries status=pending
      html = render_change(view, "filter", %{"search" => "alice", "status" => "pending"})

      assert has_element?(view, "button[phx-value-status='pending'].btn-primary")
      assert html =~ "Alice"
    end
  end
end
