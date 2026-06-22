defmodule Crm.Mailer do
  use Swoosh.Mailer, otp_app: :crm

  import Swoosh.Email

  @from_name Application.compile_env(:crm, :mailer_from_name, "CRM")
  @from_address Application.compile_env(:crm, :mailer_from_address, "noreply@example.com")

  def send_email(to_address, subject, body) do
    new()
    |> from({@from_name, @from_address})
    |> to(to_address)
    |> subject(subject)
    |> text_body(body)
    |> deliver()
  end
end
