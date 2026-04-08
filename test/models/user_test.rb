require "test_helper"

class UserTest < ActiveSupport::TestCase
  def with_locale(locale)
    previous = I18n.locale
    I18n.locale = locale
    yield
  ensure
    I18n.locale = previous
  end

  def build_user(attrs = {})
    User.new({
      email: "newuser@example.com",
      password: "secret123",
      password_confirmation: "secret123",
      name: "New User"
    }.merge(attrs))
  end

  # --- Spanish (rails-i18n + custom keys) -----------------------------------

  test "validates blank email in Spanish" do
    with_locale(:es) do
      user = build_user(email: "")
      assert_not user.valid?
      assert_includes user.errors[:email], "no puede estar en blanco"
    end
  end

  test "validates password confirmation mismatch in Spanish (custom override)" do
    with_locale(:es) do
      user = build_user(password: "secret123", password_confirmation: "different")
      assert_not user.valid?
      # Custom key in es.yml: activerecord.errors.models.user.attributes.password_confirmation.confirmation
      assert_includes user.errors[:password_confirmation], "no coincide con la contraseña"
    end
  end

  test "validates email taken in Spanish (devise.es.yml)" do
    existing = users(:alice)
    with_locale(:es) do
      user = build_user(email: existing.email)
      assert_not user.valid?
      assert_includes user.errors[:email], "ya está en uso"
    end
  end

  test "validates password too short in Spanish" do
    with_locale(:es) do
      user = build_user(password: "abc", password_confirmation: "abc")
      assert_not user.valid?
      assert(user.errors[:password].any? { |m| m.include?("demasiado corto") || m.include?("muy corto") },
             "expected a Spanish 'too short' message, got: #{user.errors[:password].inspect}")
    end
  end

  test "validates custom phone_number format in Spanish" do
    with_locale(:es) do
      user = build_user(phone_number: "abc")
      assert_not user.valid?
      assert_includes user.errors[:phone_number],
                      "debe ser un número de teléfono válido (solo dígitos, entre 6 y 13 dígitos)"
    end
  end

  # --- English --------------------------------------------------------------

  test "validates blank email in English" do
    with_locale(:en) do
      user = build_user(email: "")
      assert_not user.valid?
      assert_includes user.errors[:email], "can't be blank"
    end
  end

  test "validates email taken in English (devise.en.yml)" do
    existing = users(:alice)
    with_locale(:en) do
      user = build_user(email: existing.email)
      assert_not user.valid?
      assert_includes user.errors[:email], "is already taken"
    end
  end

  test "validates custom dni format in English" do
    with_locale(:en) do
      user = build_user(dni: "abc")
      assert_not user.valid?
      assert_includes user.errors[:dni],
                      "must be a valid DNI (digits only, 8 to 11 digits)"
    end
  end
end
