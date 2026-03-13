class CardPriceMailer < ApplicationMailer
  def fallback_results(ck_updated_cards, scryfall_updated_cards, not_found_cards)
    @ck_updated_cards = ck_updated_cards
    @scryfall_updated_cards = scryfall_updated_cards
    @not_found_cards = not_found_cards

    recipients = User.where(admin: true).pluck(:email)
    return if recipients.empty?

    total_updated = ck_updated_cards.size + scryfall_updated_cards.size
    mail(
      to: recipients,
      subject: t('card_price_mailer.fallback_results.subject',
                  updated: total_updated,
                  not_found: not_found_cards.size)
    )
  end
end
