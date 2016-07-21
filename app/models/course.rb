class Course < ActiveRecord::Base
  include ActivityLog

  enum status: [:not_started, :in_process, :closed]

  has_many :user_courses, dependent: :destroy
  has_many :users, through: :user_courses, dependent: :destroy
  has_many :course_subjects, dependent: :destroy
  has_many :subjects, through: :course_subjects, dependent: :destroy

  paginates_per Settings.course.per_page

  validates :name, presence: true, length: {minimum: 6, maximum: 90}
  validates :description, presence: true, length: {minimum: 9}
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :subject_ids, presence: true
  validate :check_date

  before_create :set_not_started_status
  after_update :create_user_subject, if: -> {self.in_process?}

  scope :get_courses_in_month, -> do
    where("(cast(strftime('%m', start_date) as int) <= #{Time.now.month}
      AND cast(strftime('%m', end_date) as int) > #{Time.now.month})
      OR cast(strftime('%m', end_date) as int) = #{Time.now.month}")
      .where.not(status: Course.statuses[:not_started])
  end

  def duration
    "#{start_date.to_formatted_s :short} : #{end_date.to_formatted_s :short}"
  end

  def status_content
    if self.not_started?
      I18n.t "model.course.label.new"
    elsif self.in_process?
      I18n.t "model.course.label.in_process"
    elsif self.closed?
      I18n.t "model.course.label.closed"
    end
  end

  def status_label
    if self.not_started?
      Settings.course.status_label.not_started
    elsif self.in_process?
      Settings.course.status_label.in_process
    elsif self.closed?
      Settings.course.status_label.closed
    end
  end

  private
  def set_not_started_status
    self.status = Course.statuses[:not_started]
  end

  def create_user_subject
    self.users.trainee.each do |trainee|
      self.subjects.each do |subject|
        UserSubject.first_or_create user_id: trainee.id,
          course_id: id, subject_id: subject.id
      end
    end
  end

  def check_date
    return if self.end_date.blank? || self.start_date.blank?
    if self.end_date < self.start_date
      self.errors.add :end_date, I18n.t("model.course.must_be_after_or_equal_end_date")
    end
    if self.start_date < Date.today
      self.errors.add :start_date, I18n.t("model.course.not_in_past")
    end
  end
end
