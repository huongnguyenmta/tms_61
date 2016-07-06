class CreateUserCourses < ActiveRecord::Migration
  def change
    create_table :user_courses do |t|
      t.integer :user_id
      t.integer :course_id
      t.datetime :start_date
      t.datetime :end_date
      t.integer :status

      t.timestamps null: false
    end
  end
end
