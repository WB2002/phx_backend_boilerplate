# Shared Redacted + PII key lists for logger / Phoenix filter_parameters.
# Evaluated via Code.eval_file from config.exs and prod.exs.
#
# Phoenix :filter_parameters uses substring match — avoid short generic keys
# like "name" or "id" that would over-filter (username, filename, etc.).

redacted = ~w(
  password
  password_confirmation
  secret
  secret_key
  token
  access_token
  refresh_token
  api_key
  authorization
  cookie
  credit_card
  cvv
  otp
  pin
)

pii = ~w(
  email
  phone
  phone_number
  mobile
  first_name
  last_name
  full_name
  date_of_birth
  dob
  ssn
  address
  street
  postal_code
)

%{redacted: redacted, pii: pii}
