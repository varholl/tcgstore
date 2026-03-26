class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_locale
  before_action :set_theme
  before_action :set_blue_rate
  before_action :set_maintenance_mode
  helper_method :current_theme, :blue_dollar_rate, :maintenance_mode?, :admin_or_seller?

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

  def set_maintenance_mode
    @maintenance_mode = SiteSetting.maintenance_mode?
    @maintenance_message = SiteSetting.maintenance_message
  end

  def maintenance_mode?
    @maintenance_mode
  end

  def admin_or_seller?
    user_signed_in? && (current_user.admin? || current_user.seller.present?)
  end

  def require_no_maintenance!
    return unless maintenance_mode?
    return if user_signed_in? && current_user.admin?

    redirect_back fallback_location: root_path, alert: @maintenance_message.presence || t('maintenance.default_message')
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :phone_number, :locale])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :phone_number, :locale])
  end
end
