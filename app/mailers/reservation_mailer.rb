class ReservationMailer < ApplicationMailer
  def created(reservation)
    @reservation = reservation
    @items = reservation.reservation_items.includes(:card)

    recipients = build_recipients(reservation, notify_admins: true)
    return if recipients.empty?

    I18n.with_locale(user_locale(reservation)) do
      mail(to: recipients, subject: default_i18n_subject(id: reservation.id))
    end
  end

  def updated(reservation)
    @reservation = reservation
    @items = reservation.reservation_items.includes(:card)

    recipients = build_recipients(reservation, notify_admins: true)
    return if recipients.empty?

    I18n.with_locale(user_locale(reservation)) do
      mail(to: recipients, subject: default_i18n_subject(id: reservation.id))
    end
  end

  def cancelled(reservation)
    @reservation = reservation
    @items = reservation.reservation_items.includes(:card)

    recipients = build_recipients(reservation, notify_admins: true)
    return if recipients.empty?

    I18n.with_locale(user_locale(reservation)) do
      mail(to: recipients, subject: default_i18n_subject(id: reservation.id))
    end
  end

  def fulfilled(reservation)
    @reservation = reservation
    @items = reservation.reservation_items.includes(:card)

    return if reservation.guest?

    I18n.with_locale(user_locale(reservation)) do
      mail(to: reservation.user.email, subject: default_i18n_subject(id: reservation.id))
    end
  end

  def expired(reservation)
    @reservation = reservation
    @items = reservation.reservation_items.includes(:card)

    return if reservation.guest?

    I18n.with_locale(user_locale(reservation)) do
      mail(to: reservation.user.email, subject: default_i18n_subject(id: reservation.id))
    end
  end

  def transfer_receipt(reservation, file)
    @reservation = reservation
    @user = reservation.user

    attachments[file.original_filename] = {
      mime_type: file.content_type,
      content: file.read
    }

    admin_emails = User.where(admin: true).pluck(:email)
    return if admin_emails.empty?

    mail(
      to: admin_emails,
      subject: I18n.t('reservation_mailer.transfer_receipt.subject', id: reservation.id, user: @user&.name || 'Guest')
    )
  end

  private

  def build_recipients(reservation, notify_admins: false)
    recipients = []
    recipients << reservation.user.email if reservation.user.present?
    recipients.concat(User.where(admin: true).pluck(:email)) if notify_admins
    recipients.uniq
  end

  def user_locale(reservation)
    reservation.user&.locale || I18n.default_locale
  end
end
