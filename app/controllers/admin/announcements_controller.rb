class Admin::AnnouncementsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin
  before_action :set_announcement, only: [:edit, :update, :destroy, :toggle_active]

  def index
    @announcements = Announcement.order(created_at: :desc)
  end

  def new
    @announcement = Announcement.new
  end

  def create
    @announcement = Announcement.new(announcement_params)

    if @announcement.save
      redirect_to admin_announcements_path, notice: t("controllers.admin.announcements.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @announcement.update(announcement_params)
      redirect_to admin_announcements_path, notice: t("controllers.admin.announcements.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def toggle_active
    @announcement.update!(active: !@announcement.active?)
    notice = @announcement.active? ? t("controllers.admin.announcements.activated") : t("controllers.admin.announcements.deactivated")
    redirect_to admin_announcements_path, notice: notice
  end

  def destroy
    @announcement.destroy
    redirect_to admin_announcements_path, notice: t("controllers.admin.announcements.deleted")
  end

  private

  def set_announcement
    @announcement = Announcement.find(params[:id])
  end

  def announcement_params
    params.require(:announcement).permit(:title, :body, :level, :active, :starts_at, :ends_at)
  end

  def require_admin
    redirect_to root_path, alert: t("controllers.admin.cards.access_denied") unless current_user.admin?
  end
end
