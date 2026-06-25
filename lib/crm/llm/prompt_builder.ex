defmodule Crm.Llm.PromptBuilder do
  @moduledoc """
  Builds structured prompts for email drafting.
  Keeping prompt logic here makes it easy to iterate
  without touching the API call layer.
  """

  def system_prompt do
    """
    You are a professional B2B sales assistant helping draft personalized
    outreach emails. Your emails are:
    - Concise (150-200 words max)
    - Warm but professional in tone
    - Focused on starting a conversation, not closing a sale
    - Free of generic filler phrases like "I hope this email finds you well"

    You must respond with valid JSON only, no preamble, no markdown fences.
    The JSON must have exactly two keys: "subject" and "body".

    Example response format:
    {"subject": "...", "body": "..."}
    """
  end

  def user_prompt(lead) do
    context_section =
      case lead.company_context do
        nil -> ""
        "" -> ""
        ctx -> "\nAdditional context about #{lead.company_name}:\n#{ctx}\n"
      end

    """
    Draft a personalized outreach email for the following lead:

    Contact person: #{lead.contact_person}
    Company: #{lead.company_name}
    Email: #{lead.email_address}
    #{context_section}
    The email should:
    1. Address #{lead.contact_person} by first name
    2. Reference #{lead.company_name} specifically — don't be generic
    3. Briefly introduce our service and why it's relevant to them
    4. End with a single, low-friction call to action (e.g. a 20 min call)

    Respond with JSON only: {"subject": "...", "body": "..."}
    """
  end
end
