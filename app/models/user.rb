class User < ActiveRecord::Base
  enum role: [:supervisor, :trainee]

  devise :database_authenticatable, :registerable,
    :recoverable, :rememberable, :trackable, :validatable, :omniauthable,
    omniauth_providers: [:facebook, :twitter, :google_oauth2]

  has_many :activities, dependent: :destroy
  has_many :user_courses, dependent: :destroy
  has_many :courses, through: :user_courses
  has_many :user_tasks, dependent: :destroy
  has_many :tasks, through: :user_tasks
  has_many :user_subjects, dependent: :destroy
  has_many :subjects, through: :user_subjects
  has_many :authorizations

  paginates_per Settings.user.per_page
  mount_uploader :avatar, AvatarUploader

  validates :name,  presence: true, length: {maximum: 50}
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
  validates :email, presence: true, length: {maximum: 255},
    format: {with: VALID_EMAIL_REGEX}, uniqueness: true
  validates :password, presence: true, length: {minimum: 5, maximum: 120}, on: :create
  validates :password, length: {minimum: 5, maximum: 120}, on: :update, allow_blank: true
  validate :avatar_size

  scope :not_in_course_process, -> do
    where("users.id NOT IN
      (SELECT user_id FROM user_courses
      JOIN courses ON course_id = courses.id
      WHERE courses.status = #{Course.statuses[:in_process]}
      AND courses.id IS NOT course_id)")
  end

  scope :in_course_process, -> do
    where("users.id IN
      (SELECT user_id FROM user_courses
      JOIN courses ON course_id = courses.id
      WHERE courses.status = #{Course.statuses[:in_process]})")
  end

  scope :count_trainee_into_course_in_month, -> do
    where(id: UserCourse.select(:user_id)
      .where(course_id: Course.get_courses_in_month.map(&:id)),
        role: User.roles[:trainee])
  end

  scope :user_is_supervisor, ->{where(role: User.roles[:supervisor])}

  class << self
    def role_titles
      User.roles.keys
    end

    def new_with_session params, session
      if session["devise.user_attributes"]
        new(session["devise.user_attributes"],without_protection: true) do |user|
          user.attributes = params
          user.valid?
        end
      else
        super
      end
    end

    def from_omniauth auth, current_user
      authorization = Authorization.where(provider: auth.provider, uid:
        auth.uid.to_s, token: auth.credentials.token,
        secret: auth.credentials.secret).first_or_initialize
      if authorization.user.blank?
        user = current_user || User.where("email = ?", auth["info"]["email"]).first
        if user.blank?
          user = User.new
          user.password = Devise.friendly_token[0,10]
          user.name = auth.info.name
          user.email = auth.info.email
          if auth.provider == "twitter"
            user.save(validate: false)
          else
            user.save
          end
        end
        authorization.user_id = user.id
        authorization.save
      end
      authorization.user
   end
  end

  def in_process?
    User.in_course_process.pluck(:id).include? id
  end

  private
  def avatar_size
    if avatar.size > 5.megabytes
      errors.add :avatar, I18n.t("model.user.avatar_size_error")
    end
  end
end
