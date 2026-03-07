class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_locale

  def set_language
    locale = params[:locale].to_s
    locale = I18n.default_locale.to_s unless I18n.available_locales.map(&:to_s).include?(locale)
    cookies[:locale] = { value: locale, expires: 1.year.from_now }
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

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :phone_number])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :phone_number])
  end
end
