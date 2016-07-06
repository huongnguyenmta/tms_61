class UserTask < ActiveRecord::Base
  belongs_to :user
  belongs_to :task
  belongs_to :user_subject
end
