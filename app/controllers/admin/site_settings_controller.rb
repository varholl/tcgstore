class Admin::SiteSettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  def edit
    @site_setting = SiteSetting.instance
  end

  def update
    @site_setting = SiteSetting.instance

    if @site_setting.update(site_setting_params)
      redirect_to edit_admin_site_settings_path, notice: t('controllers.admin.site_settings.updated')
    else
      render :edit
    end
  end

  private

  def require_admin
    redirect_to root_path, alert: t('controllers.admin.site_settings.access_denied') unless current_user.admin?
  end

  def site_setting_params
    params.require(:site_setting).permit(:maintenance_mode, :maintenance_message)
  end
end
