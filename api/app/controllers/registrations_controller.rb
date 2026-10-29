class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  layout false

  # GET /register?token=&email_address=
  # A QR invite link has no email_address.
  def show
    query = { token: params[:token], email_address: params[:email_address] }.compact_blank
    @app_url = "ezsplit://register?#{URI.encode_www_form(query)}"
  end
end
