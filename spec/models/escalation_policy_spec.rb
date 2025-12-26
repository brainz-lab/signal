require 'rails_helper'

RSpec.describe EscalationPolicy, type: :model do
  describe 'associations' do
    it { should have_many(:alert_rules).dependent(:nullify) }
  end

  describe 'validations' do
    subject { create(:escalation_policy) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:slug) }
    it { should validate_presence_of(:project_id) }
    it { should validate_uniqueness_of(:slug).scoped_to(:project_id) }
  end

  describe 'callbacks' do
    describe 'before_validation' do
      it 'generates slug from name on create' do
        policy = build(:escalation_policy, name: 'Critical Escalation', slug: nil)
        policy.valid?
        expect(policy.slug).to eq('critical-escalation')
      end

      it 'does not override existing slug' do
        policy = build(:escalation_policy, name: 'Policy', slug: 'custom-slug')
        policy.valid?
        expect(policy.slug).to eq('custom-slug')
      end
    end
  end

  describe 'scopes' do
    let(:project_id) { SecureRandom.uuid }
    let!(:enabled_policy) { create(:escalation_policy, enabled: true, project_id: project_id) }
    let!(:disabled_policy) { create(:escalation_policy, :disabled, project_id: project_id) }

    describe '.enabled' do
      it 'returns only enabled policies' do
        expect(EscalationPolicy.enabled).to include(enabled_policy)
        expect(EscalationPolicy.enabled).not_to include(disabled_policy)
      end
    end

    describe '.for_project' do
      let(:other_project_id) { SecureRandom.uuid }
      let!(:other_policy) { create(:escalation_policy, project_id: other_project_id) }

      it 'returns policies for specific project' do
        expect(EscalationPolicy.for_project(project_id)).to include(enabled_policy)
        expect(EscalationPolicy.for_project(project_id)).not_to include(other_policy)
      end
    end
  end
end
