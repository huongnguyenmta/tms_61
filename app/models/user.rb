class User < ActiveRecord::Base
  include Exportable

  enum role: [:supervisor, :trainee]

  devise :database_authenticatable, :registerable,
    :recoverable, :rememberable, :trackable, :validatable, :omniauthable,
    omniauth_providers: [:facebook, :twitter, :google_oauth2]

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
  validates :password, presence: true, allow_blank: true
  validates :role, presence: true
  validate :avatar_size

  scope :not_in_course_process, -> (course_id) do
    where("users.id NOT IN
      (SELECT user_id FROM user_courses
      JOIN courses ON course_id = courses.id
      WHERE courses.status = #{Course.statuses[:in_process]}
      AND courses.id IS NOT :course_id)", course_id: course_id)
  end

  scope :in_course_process, -> do
    where("users.id IN
      (SELECT user_id FROM user_courses
      JOIN courses ON course_id = courses.id
      WHERE courses.status = #{Course.statuses[:in_process]})")
  end

  scope :user_is_supervisor, ->{where role: User.roles[:supervisor]}

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
          user.role = User.roles[:trainee]
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

    def monthly_report
      @supervisor = User.user_is_supervisor
      @courses = Course.in_this_month
      @supervisor.each do |supervisor|
        UserMailer.monthly_report_to_supervisor(supervisor, @courses).deliver
      end
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
