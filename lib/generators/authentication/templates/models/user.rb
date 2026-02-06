class User < ApplicationRecord
  MIN_PASSWORD = 4
  GENERATED_EMAIL_SUFFIX = "@generated-mail.clacky.ai"

  has_secure_password validations: false

  # ========== Role-based Access Control (Optional) ==========
  # If you need roles (premium, moderator, etc.), add a `role` field:
  #   rails g migration AddRoleToUsers role:string
  #   # In migration: add_column :users, :role, :string, default: 'user', null: false
  #   # Then add in this model:
  #   ROLES = %w[user premium moderator].freeze
  #   validates :role, inclusion: { in: ROLES }
  #   def premium? = role == 'premium'
  #   def moderator? = role == 'moderator'
  # ==========================================================

  # ========== Multi-Role Separate Routes (e.g. Doctor/Patient) ==========
  # For apps needing separate signup/login pages per role:
  #   1. ROLES = %w[doctor patient].freeze
  #   2. Add scoped routes: scope '/doctor', as: 'doctor' do ... end
  #   3. In RegistrationsController#create: @user.role = params[:role]
  #   4. Create role-specific views: sessions/new_doctor.html.erb
  #   5. For extra fields per role, use polymorphic Profile:
  #      has_one :doctor_profile, dependent: :destroy
  #      has_one :patient_profile, dependent: :destroy
  #      def profile = doctor? ? doctor_profile : patient_profile
  # See generator output for full setup instructions.
  # ======================================================================

  generates_token_for :email_verification, expires_in: 2.days do
    email
  end
  generates_token_for :password_reset, expires_in: 20.minutes

  has_many :sessions, dependent: :destroy

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  validates :password, allow_nil: true, length: { minimum: MIN_PASSWORD }, if: :password_required?
  validates :password, confirmation: true, if: :password_required?

  normalizes :email, with: -> { _1.strip.downcase }

  before_validation if: :email_changed?, on: :update do
    self.verified = false
  end

  after_update if: :password_digest_previously_changed? do
    sessions.where.not(id: Current.session).delete_all
  end

  # OAuth methods
  def self.from_omniauth(auth)
    name = auth.info.name.presence || "#{SecureRandom.hex(10)}_user"
    email = auth.info.email.presence || User.generate_email(name)

    # First, try to find user by email
    user = find_by(email: email)
    if user
      user.update(provider: auth.provider, uid: auth.uid)
      return user
    end

    # Then, try to find user by provider and uid
    user = find_by(provider: auth.provider, uid: auth.uid)
    return user if user

    # If not found, create a new user
    verified = !email.end_with?(GENERATED_EMAIL_SUFFIX)
    create(
      name: name,
      email: email,
      provider: auth.provider,
      uid: auth.uid,
      verified: verified,
    )
  end

  def self.generate_email(name)
    if name.present?
      name.downcase.gsub(' ', '_') + GENERATED_EMAIL_SUFFIX
    else
      SecureRandom.hex(10) + GENERATED_EMAIL_SUFFIX
    end
  end

  public

  def oauth_user?
    provider.present? && uid.present?
  end

  def email_was_generated?
    email.end_with?(GENERATED_EMAIL_SUFFIX)
  end

  def password_required?
    return false if oauth_user?
    password_digest.blank? || password.present?
  end

  # write your own code here

end
