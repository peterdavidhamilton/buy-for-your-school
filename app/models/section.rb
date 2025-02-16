class Section < ApplicationRecord
  self.implicit_order_column = "order"
  default_scope { order(:order) }

  belongs_to :journey
  has_many :tasks, dependent: :destroy
  has_many :steps, through: :tasks, class_name: "Step"

  validates :title, :contentful_id, presence: true
end
