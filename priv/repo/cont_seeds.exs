defmodule ContSeeds do
  alias Crm.Repo
  alias Crm.Pipeline.Lead

  @statuses [:pending, :drafting, :awaiting_review, :approved, :sent, :failed]

  @first_names ~w(John Jane Alex Chris Sam Taylor Jordan Casey Morgan)
  @last_names ~w(Smith Johnson Lee Brown Garcia Davis Wilson Martinez)
  @companies [
    "Acme Inc", "Globex Corp", "Initech", "Umbrella Corp",
    "Soylent Corp", "Hooli", "Stark Industries"
  ]
  @domains ["example.com", "demo.io", "test.com", "mail.com", "xyz.com", "bolt.com"]

  # --- Public API ---

  def run(opts \\ []) do
    delay = Keyword.get(opts, :delay, 300)
    batch_size = Keyword.get(opts, :batch_size, 1)

    loop(delay, batch_size, 1)
  end

   # --- Loop ---

  defp loop(delay, batch_size, n) do
    records =
      Enum.map(1..batch_size, fn _ ->
        build_attrs()
      end)

    Enum.each(records, &insert!/1)

    IO.puts("Inserted batch #{n} (#{batch_size} records)")

    :timer.sleep(delay)
    loop(delay, batch_size, n + 1)
  end

  # --- Insert ---

  defp insert!(attrs) do
    %Lead{}
    |> Lead.changeset(attrs)
    |> Repo.insert!()
  end

  # --- Data generation ---

  defp build_attrs do
    first = rand(@first_names)
    last = rand(@last_names)
    company = rand(@companies)
    domain = rand(@domains)
    status = rand(@statuses)

    base = %{
      email_address: email(first, last, domain),
      contact_person: "#{first} #{last}",
      company_name: company,
      already_emailed: status
    }

    enrich_by_status(base, status)
  end

  # --- Status-aware enrichment (this is the important part) ---

  defp enrich_by_status(attrs, :pending), do: attrs

  defp enrich_by_status(attrs, :drafting) do
    Map.put(attrs, :drafted_at, random_past_time())
  end

  defp enrich_by_status(attrs, :awaiting_review) do
    attrs
    |> with_draft()
    |> Map.put(:drafted_at, random_past_time())
  end

  defp enrich_by_status(attrs, :approved) do
    attrs
    |> with_draft()
    |> Map.put(:drafted_at, random_past_time())
  end

  defp enrich_by_status(attrs, :sent) do
    attrs
    |> with_draft()
    |> Map.put(:drafted_at, random_past_time())
    |> Map.put(:sent_at, random_past_time())
  end

  defp enrich_by_status(attrs, :failed) do
    attrs
    |> with_draft()
    |> Map.put(:drafted_at, random_past_time())
    |> Map.put(:last_error, "SMTP timeout")
  end

  # --- Helpers ---

  defp with_draft(attrs) do
    Map.merge(attrs, %{
      draft_subject: "Quick question about #{attrs.company_name}",
      draft_body: "Hi #{attrs.contact_person},\n\nI'd love to connect...\n"
    })
  end

 defp email(first, last, domain) do
  suffix = random_suffix()
  "#{String.downcase(first)}.#{String.downcase(last)}.#{suffix}@#{domain}"
end

  defp rand(list), do: Enum.random(list)

  defp random_past_time do
    seconds_ago = Enum.random(60..86_400)
    DateTime.utc_now() |> DateTime.add(-seconds_ago, :second)
  end

  defp random_suffix do
    :crypto.strong_rand_bytes(4)
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 6)
  end


end

ContSeeds.run()
