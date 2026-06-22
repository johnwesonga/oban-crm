# priv/repo/seeds.exs

alias Crm.Repo
alias Crm.Pipeline.Lead

# Clear existing seeds to make this idempotent
Repo.delete_all(Lead)

leads = [
  %{
    email_address: "sarah.chen@techvision.io",
    contact_person: "Sarah Chen",
    company_name: "TechVision IO",
    already_emailed: :pending
  },
  %{
    email_address: "marcus.wright@blueridge-capital.com",
    contact_person: "Marcus Wright",
    company_name: "Blue Ridge Capital",
    already_emailed: :pending
  },
  %{
    email_address: "priya.patel@novaspark.co",
    contact_person: "Priya Patel",
    company_name: "NovaSpark",
    already_emailed: :pending
  },
  %{
    email_address: "james.okonkwo@meridianhealth.org",
    contact_person: "James Okonkwo",
    company_name: "Meridian Health",
    already_emailed: :pending
  },
  %{
    email_address: "lucia.fernandez@castillo-group.mx",
    contact_person: "Lucia Fernandez",
    company_name: "Castillo Group",
    already_emailed: :pending
  },
  # Already in progress — tests the non-pending filter
  %{
    email_address: "tom.baker@graystone-ventures.com",
    contact_person: "Tom Baker",
    company_name: "Graystone Ventures",
    already_emailed: :drafting
  },
  %{
    email_address: "nina.schmidt@berlindynamics.de",
    contact_person: "Nina Schmidt",
    company_name: "Berlin Dynamics",
    already_emailed: :awaiting_review
  },
  # Already completed — tests that scan worker ignores these
  %{
    email_address: "david.kim@seoultech.kr",
    contact_person: "David Kim",
    company_name: "Seoul Tech",
    already_emailed: :sent,
    sent_at: DateTime.utc_now() |> DateTime.truncate(:second)
  },
  %{
    email_address: "anna.kowalski@warsawsoft.pl",
    contact_person: "Anna Kowalski",
    company_name: "Warsaw Soft",
    already_emailed: :sent,
    sent_at: ~U[2024-11-01 09:30:00Z]
  },
  # Failed — tests error recovery path
  %{
    email_address: "raj.mehta@mumbaiventures.in",
    contact_person: "Raj Mehta",
    company_name: "Mumbai Ventures",
    already_emailed: :failed,
    last_error: "LLM timeout after 3 attempts"
  }
]

for attrs <- leads do
  %Lead{}
  |> Lead.changeset(attrs)
  |> Repo.insert!()
end

IO.puts("""
Seeds inserted:
  #{Enum.count(leads, &(&1.already_emailed == :pending))} pending
  #{Enum.count(leads, &(&1.already_emailed == :drafting))} drafting
  #{Enum.count(leads, &(&1.already_emailed == :awaiting_review))} awaiting review
  #{Enum.count(leads, &(&1.already_emailed == :sent))} sent
  #{Enum.count(leads, &(&1.already_emailed == :failed))} failed
""")
