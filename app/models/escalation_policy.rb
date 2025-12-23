class EscalationPolicy < ApplicationRecord
  has_many :alert_rules, dependent: :nullify

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :project_id }
  validates :project_id, presence: true

  before_validation :generate_slug, on: :create

  scope :enabled, -> { where(enabled: true) }
  scope :for_project, ->(project_id) { where(project_id: project_id) }

  private

  def generate_slug
    self.slug ||= name&.parameterize
  end
end
