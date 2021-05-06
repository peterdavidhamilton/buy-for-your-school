class AddEventLog < ActiveRecord::Migration[6.1]
  def change
    create_table :events, id: :uuid do |t|
      t.string :journey_id
      t.string :user_id
      t.string :contentful_category_id
      t.string :contentful_section_id
      t.string :contentful_task_id
      t.string :contentful_step_id
      t.string :action
      t.jsonb :data
      t.timestamps
    end
  end
end
