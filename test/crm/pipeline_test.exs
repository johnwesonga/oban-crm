defmodule Crm.PipelineTest do
  use Crm.DataCase, async: true

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

  describe "list_leads/1 — no filters" do
    test "returns all leads" do
      lead1 = create_lead(%{company_name: "Alpha"})
      lead2 = create_lead(%{company_name: "Beta"})

      ids = Pipeline.list_leads() |> Enum.map(& &1.id)

      assert lead1.id in ids
      assert lead2.id in ids
    end

    test "returns empty list when no leads exist" do
      assert Pipeline.list_leads() == []
    end
  end

  describe "list_leads/1 — search filter" do
    test "matches contact_person (partial, case-insensitive)" do
      alice = create_lead(%{contact_person: "Alice Smith"})
      _bob = create_lead(%{contact_person: "Bob Jones"})

      results = Pipeline.list_leads(%{search: "alice"})
      assert length(results) == 1
      assert hd(results).id == alice.id
    end

    test "matches company_name" do
      acme = create_lead(%{company_name: "Acme Corp"})
      _other = create_lead(%{company_name: "Beta Inc"})

      results = Pipeline.list_leads(%{search: "acme"})
      assert length(results) == 1
      assert hd(results).id == acme.id
    end

    test "matches email_address" do
      target = create_lead(%{email_address: "hello@findme.com"})
      _other = create_lead(%{email_address: "other@ignore.com"})

      results = Pipeline.list_leads(%{search: "findme"})
      assert length(results) == 1
      assert hd(results).id == target.id
    end

    test "search is case-insensitive" do
      lead = create_lead(%{company_name: "CamelCase Corp"})

      assert [found] = Pipeline.list_leads(%{search: "CAMELCASE"})
      assert found.id == lead.id
    end

    test "returns empty list when nothing matches" do
      create_lead(%{contact_person: "Nobody"})
      assert Pipeline.list_leads(%{search: "zzznomatch"}) == []
    end

    test "empty search returns all leads" do
      create_lead(%{})
      create_lead(%{})
      assert length(Pipeline.list_leads(%{search: ""})) == 2
    end
  end

  describe "list_leads/1 — status filter" do
    test "filters by a specific status" do
      pending_lead = create_lead(%{})

      {:ok, sent_lead} =
        Pipeline.create_lead(%{
          contact_person: "Sent Person",
          company_name: "Sent Corp",
          email_address: "sent@example.com",
          already_emailed: :sent
        })

      pending_results = Pipeline.list_leads(%{status: "pending"})
      sent_results = Pipeline.list_leads(%{status: "sent"})

      assert Enum.any?(pending_results, &(&1.id == pending_lead.id))
      refute Enum.any?(pending_results, &(&1.id == sent_lead.id))

      assert Enum.any?(sent_results, &(&1.id == sent_lead.id))
      refute Enum.any?(sent_results, &(&1.id == pending_lead.id))
    end

    test "unknown/nil status returns all leads" do
      create_lead(%{})
      create_lead(%{})
      assert length(Pipeline.list_leads(%{status: "all"})) == 2
      assert length(Pipeline.list_leads(%{status: nil})) == 2
      assert length(Pipeline.list_leads(%{})) == 2
    end
  end

  describe "list_leads/1 — combined search + status" do
    test "applies both filters with AND logic" do
      _alice_pending = create_lead(%{contact_person: "Alice A", already_emailed: :pending})

      {:ok, alice_sent} =
        Pipeline.create_lead(%{
          contact_person: "Alice B",
          company_name: "Corp",
          email_address: "aliceb@corp.com",
          already_emailed: :sent
        })

      _bob_pending = create_lead(%{contact_person: "Bob C"})

      results = Pipeline.list_leads(%{search: "alice", status: "sent"})
      assert length(results) == 1
      assert hd(results).id == alice_sent.id
    end
  end
end
