class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_locale
  before_action :set_theme
  before_action :set_blue_rate
  helper_method :current_theme, :blue_dollar_rate

  def set_language
    locale = params[:locale].to_s
    locale = I18n.default_locale.to_s unless I18n.available_locales.map(&:to_s).include?(locale)
    cookies[:locale] = { value: locale, expires: 1.year.from_now }
    current_user.update(locale: locale) if user_signed_in?
    redirect_back fallback_location: root_path
  end

  def toggle_theme
    new_theme = current_theme == "dark" ? "light" : "dark"
    cookies[:theme] = { value: new_theme, expires: 1.year.from_now }
    current_user.update(theme: new_theme) if user_signed_in?
    redirect_back fallback_location: root_path
  end

  private

  def set_locale
    locale = cookies[:locale]
    I18n.locale = if locale.present? && I18n.available_locales.map(&:to_s).include?(locale)
                    locale
                  else
                    I18n.default_locale
                  end
  end

  def set_theme
    theme = cookies[:theme]
    @current_theme = %w[dark light].include?(theme) ? theme : "dark"
  end

  def current_theme
    @current_theme || "dark"
  end

  def set_blue_rate
    @blue_dollar_rate = Rails.cache.fetch("blue_dollar_rate", expires_in: 15.minutes) do
      uri = URI("https://dolarapi.com/v1/dolares/blue")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 3
      http.read_timeout = 3
      response = http.request(Net::HTTP::Get.new(uri))
      data = JSON.parse(response.body)
      data["venta"]&.to_f
    rescue StandardError
      nil
    end
  end

  def blue_dollar_rate
    @blue_dollar_rate
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :phone_number, :locale])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :phone_number, :locale])
  end
end
