class SavedSearch < ApplicationRecord
  belongs_to :project

  validates :name, presence: true, length: { maximum: 100 }
  validates :query_params, presence: true
  validates :project_id, presence: true

  scope :for_project, ->(project_id) { where(project_id: project_id) }
  scope :recent, -> { order(created_at: :desc) }
end
