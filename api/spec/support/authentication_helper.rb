module AuthenticationHelper
  def sign_in(user)
    post session_url, params: { email_address: user.email_address, password: user.password }
  end

  def sign_out
    delete session_url
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelper, type: :request
end
