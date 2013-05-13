class PaymentMethod::DotpayPl < Spree::PaymentMethod
  attr_accessible :preferred_account_id, :preferred_urlc_pin, :preferred_pin, :preferred_url, :preferred_type, :preferred_currency, :preferred_language, :preferred_dotpay_server_1, :preferred_dotpay_server_2
  preference :account_id, :string
  preference :pin, :string
  preference :urlc_pin, :string
  preference :url, :string, :default => "https://ssl.dotpay.pl/"
  preference :type, :string, :default => "3"
  preference :currency, :string, :default => "PLN"
  preference :language, :string, :default => "pl"

  def payment_profiles_supported?
    false
  end

end
