class CreateCourseSubjects < ActiveRecord::Migration
  def change
    create_table :course_subjects do |t|
      t.integer :course_id
      t.integer :suject_id
      t.integer :status

      t.timestamps null: false
    end
  end
end
