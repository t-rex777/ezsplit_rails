class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  layout false

  # GET /register?token=&email_address=
  def show
    @app_url = "ezsplit://register?#{URI.encode_www_form(token: params[:token], email_address: params[:email_address])}"
  end
end
