require 'rails_helper'

RSpec.describe MaintenanceWindow, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:starts_at) }
    it { should validate_presence_of(:ends_at) }
    it { should validate_presence_of(:project_id) }

    describe 'ends_after_starts' do
      it 'is invalid when ends_at is before starts_at' do
        window = build(:maintenance_window, starts_at: 2.hours.from_now, ends_at: 1.hour.from_now)
        expect(window).not_to be_valid
        expect(window.errors[:ends_at]).to include('must be after starts_at')
      end

      it 'is invalid when ends_at equals starts_at' do
        time = 1.hour.from_now
        window = build(:maintenance_window, starts_at: time, ends_at: time)
        expect(window).not_to be_valid
      end

      it 'is valid when ends_at is after starts_at' do
        window = build(:maintenance_window, starts_at: 1.hour.from_now, ends_at: 2.hours.from_now)
        expect(window).to be_valid
      end
    end
  end

  describe 'scopes' do
    let(:project_id) { SecureRandom.uuid }
    let!(:active_window) { create(:maintenance_window, active: true, project_id: project_id) }
    let!(:inactive_window) { create(:maintenance_window, :inactive, project_id: project_id) }
    let!(:current_window) { create(:maintenance_window, :current, project_id: project_id) }
    let!(:future_window) { create(:maintenance_window, :future, project_id: project_id) }

    describe '.active' do
      it 'returns only active windows' do
        expect(MaintenanceWindow.active).to include(active_window, current_window, future_window)
        expect(MaintenanceWindow.active).not_to include(inactive_window)
      end
    end

    describe '.current' do
      it 'returns windows that are currently in effect' do
        expect(MaintenanceWindow.current).to include(current_window)
        expect(MaintenanceWindow.current).not_to include(future_window)
      end
    end

    describe '.for_project' do
      let(:other_project_id) { SecureRandom.uuid }
      let!(:other_window) { create(:maintenance_window, project_id: other_project_id) }

      it 'returns windows for specific project' do
        expect(MaintenanceWindow.for_project(project_id)).to include(active_window)
        expect(MaintenanceWindow.for_project(project_id)).not_to include(other_window)
      end
    end
  end

  describe '#currently_active?' do
    context 'when window is active and current' do
      let(:window) { create(:maintenance_window, :current) }

      it 'returns true' do
        expect(window.currently_active?).to be true
      end
    end

    context 'when window is inactive' do
      let(:window) { create(:maintenance_window, :inactive, :current) }

      it 'returns false' do
        expect(window.currently_active?).to be false
      end
    end

    context 'when window is in the future' do
      let(:window) { create(:maintenance_window, :future) }

      it 'returns false' do
        expect(window.currently_active?).to be false
      end
    end

    context 'when window is in the past' do
      let(:window) { create(:maintenance_window, :past) }

      it 'returns false' do
        expect(window.currently_active?).to be false
      end
    end
  end

  describe '#covers_rule?' do
    context 'when rule_ids is empty' do
      let(:window) { create(:maintenance_window, rule_ids: []) }

      it 'returns true for any rule' do
        expect(window.covers_rule?(SecureRandom.uuid)).to be true
      end
    end

    context 'when rule_ids is not empty' do
      let(:rule_id1) { SecureRandom.uuid }
      let(:rule_id2) { SecureRandom.uuid }
      let(:window) { create(:maintenance_window, rule_ids: [rule_id1, rule_id2]) }

      it 'returns true for covered rules' do
        expect(window.covers_rule?(rule_id1)).to be true
        expect(window.covers_rule?(rule_id2)).to be true
      end

      it 'returns false for non-covered rules' do
        expect(window.covers_rule?(SecureRandom.uuid)).to be false
      end
    end
  end
end
