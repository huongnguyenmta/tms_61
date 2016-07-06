class UserSubject < ActiveRecord::Base
  belongs_to :user
  belongs_to :subject
  belongs_to :course_subject
  has_many :user_tasks, dependent: :destroy
end
