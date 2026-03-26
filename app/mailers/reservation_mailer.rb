require "ostruct"

class ReservationMailer < ApplicationMailer
  def created(reservation)
    @reservation = reservation
    @items = group_items(reservation.reservation_items.includes(:card))

    recipients = build_recipients(reservation, notify_sellers: true)
    return if recipients.empty?

    I18n.with_locale(user_locale(reservation)) do
      mail(to: recipients, subject: default_i18n_subject(id: reservation.id))
    end
  end

  def updated(reservation)
    @reservation = reservation
    @items = group_items(reservation.reservation_items.includes(:card))

    recipients = build_recipients(reservation, notify_sellers: true)
    return if recipients.empty?

    I18n.with_locale(user_locale(reservation)) do
      mail(to: recipients, subject: default_i18n_subject(id: reservation.id))
    end
  end

  def cancelled(reservation)
    @reservation = reservation
    @items = group_items(reservation.reservation_items.includes(:card))

    recipients = build_recipients(reservation, notify_sellers: true)
    return if recipients.empty?

    I18n.with_locale(user_locale(reservation)) do
      mail(to: recipients, subject: default_i18n_subject(id: reservation.id))
    end
  end

  def prepared(reservation)
    @reservation = reservation
    @items = group_items(reservation.reservation_items.includes(:card))
    @reservation_url = reservation_url(reservation)

    return if reservation.guest?

    I18n.with_locale(user_locale(reservation)) do
      mail(to: reservation.user.email, subject: default_i18n_subject(id: reservation.id))
    end
  end

  def fulfilled(reservation)
    @reservation = reservation
    @items = group_items(reservation.reservation_items.includes(:card))

    return if reservation.guest?

    I18n.with_locale(user_locale(reservation)) do
      mail(to: reservation.user.email, subject: default_i18n_subject(id: reservation.id))
    end
  end

  def expired(reservation)
    @reservation = reservation
    @items = group_items(reservation.reservation_items.includes(:card))

    return if reservation.guest?

    I18n.with_locale(user_locale(reservation)) do
      mail(to: reservation.user.email, subject: default_i18n_subject(id: reservation.id))
    end
  end

  def new_public_note(reservation, author)
    @reservation = reservation
    @author = author

    if author.admin? || author.seller.present?
      # Admin/seller replied — notify the reservation owner
      return if reservation.guest?
      recipient = reservation.user.email
      I18n.with_locale(user_locale(reservation)) do
        mail(to: recipient, subject: default_i18n_subject(id: reservation.id))
      end
    else
      # User posted — notify sellers involved in this reservation
      seller_emails = seller_emails_for(reservation)
      return if seller_emails.empty?
      mail(to: seller_emails, subject: default_i18n_subject(id: reservation.id))
    end
  end

  def transfer_receipt(reservation, file)
    @reservation = reservation
    @user = reservation.user

    attachments[file.original_filename] = {
      mime_type: file.content_type,
      content: file.read
    }

    recipients = seller_emails_for(reservation)
    return if recipients.empty?

    mail(
      to: recipients,
      subject: I18n.t('reservation_mailer.transfer_receipt.subject', id: reservation.id, user: @user&.name || 'Guest')
    )
  end

  private

  def seller_emails_for(reservation)
    seller_ids = reservation.reservation_items.joins(:card).distinct.pluck("cards.seller_id")
    Seller.where(id: seller_ids).filter_map do |seller|
      seller.user&.email || seller.email
    end.uniq
  end

  def build_recipients(reservation, notify_sellers: false)
    recipients = []
    recipients << reservation.user.email if reservation.user.present?
    if notify_sellers
      seller_ids = reservation.reservation_items.joins(:card).distinct.pluck("cards.seller_id")
      sellers = Seller.where(id: seller_ids)
      sellers.each do |seller|
        email = seller.user&.email || seller.email
        recipients << email if email.present?
      end
    end
    recipients.uniq
  end

  def group_items(items)
    items.group_by { |i| i.card.card_identity }.map do |_identity, group|
      representative = group.first
      ::OpenStruct.new(
        card: representative.card,
        quantity: group.sum(&:quantity),
        unit_price: representative.unit_price
      )
    end
  end

  def user_locale(reservation)
    reservation.user&.locale || I18n.default_locale
  end
end
