require 'rails_helper'

RSpec.describe OnCallSchedule, type: :model do
  describe 'validations' do
    subject { create(:on_call_schedule) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:slug) }
    it { should validate_presence_of(:schedule_type) }
    it { should validate_presence_of(:project_id) }

    it { should validate_inclusion_of(:schedule_type).in_array(%w[weekly custom]) }
    it { should validate_uniqueness_of(:slug).scoped_to(:project_id) }
  end

  describe 'callbacks' do
    describe 'before_validation' do
      it 'generates slug from name on create' do
        schedule = build(:on_call_schedule, name: 'Engineering On-Call', slug: nil)
        schedule.valid?
        expect(schedule.slug).to eq('engineering-on-call')
      end
    end
  end

  describe 'scopes' do
    let(:project_id) { SecureRandom.uuid }
    let!(:enabled_schedule) { create(:on_call_schedule, enabled: true, project_id: project_id) }
    let!(:disabled_schedule) { create(:on_call_schedule, :disabled, project_id: project_id) }

    describe '.enabled' do
      it 'returns only enabled schedules' do
        expect(OnCallSchedule.enabled).to include(enabled_schedule)
        expect(OnCallSchedule.enabled).not_to include(disabled_schedule)
      end
    end

    describe '.for_project' do
      let(:other_project_id) { SecureRandom.uuid }
      let!(:other_schedule) { create(:on_call_schedule, project_id: other_project_id) }

      it 'returns schedules for specific project' do
        expect(OnCallSchedule.for_project(project_id)).to include(enabled_schedule)
        expect(OnCallSchedule.for_project(project_id)).not_to include(other_schedule)
      end
    end
  end

  describe '#current_on_call_user' do
    context 'when current shift has not expired' do
      let(:schedule) { create(:on_call_schedule, :custom, current_shift_end: 2.hours.from_now) }

      it 'returns current_on_call without updating' do
        expect(schedule).not_to receive(:update_current_on_call!)
        expect(schedule.current_on_call_user).to eq('user1')
      end
    end

    context 'when current shift has expired' do
      let(:schedule) { create(:on_call_schedule, :custom, current_shift_end: 1.hour.ago) }

      it 'updates and returns new on-call user' do
        expect(schedule).to receive(:update_current_on_call!).and_call_original
        schedule.current_on_call_user
      end
    end

    context 'when current_shift_end is nil' do
      let(:schedule) { create(:on_call_schedule, :custom, current_shift_end: nil) }

      it 'updates and returns new on-call user' do
        expect(schedule).to receive(:update_current_on_call!).and_call_original
        schedule.current_on_call_user
      end
    end
  end

  describe '#update_current_on_call!' do
    context 'with weekly schedule type' do
      let(:schedule) { create(:on_call_schedule, schedule_type: 'weekly') }

      it 'calls update_weekly_on_call!' do
        expect(schedule).to receive(:update_weekly_on_call!)
        schedule.update_current_on_call!
      end
    end

    context 'with custom schedule type' do
      let(:schedule) { create(:on_call_schedule, :custom) }

      it 'calls update_rotation_on_call!' do
        expect(schedule).to receive(:update_rotation_on_call!)
        schedule.update_current_on_call!
      end
    end
  end

  describe '#update_weekly_on_call! (private)' do
    let(:schedule) { create(:on_call_schedule, schedule_type: 'weekly') }

    it 'sets on-call based on current day of week' do
      travel_to Time.zone.parse('2024-01-01 12:00:00') do # Monday
        schedule.send(:update_weekly_on_call!)
        expect(schedule.current_on_call).to eq('user1')
        expect(schedule.current_shift_start).to be_within(1.second).of(Time.current.beginning_of_day)
        expect(schedule.current_shift_end).to be_within(1.second).of(Time.current.end_of_day)
      end
    end
  end

  describe '#update_rotation_on_call! (private)' do
    context 'with daily rotation' do
      let(:rotation_start) { 3.days.ago.beginning_of_day }
      let(:schedule) do
        create(:on_call_schedule,
          schedule_type: 'custom',
          rotation_type: 'daily',
          rotation_start: rotation_start,
          members: ['user1', 'user2', 'user3']
        )
      end

      it 'rotates daily based on rotation_start' do
        schedule.send(:update_rotation_on_call!)
        # 3 days since start, 3 members, so index = (3 / 1) % 3 = 0
        expect(schedule.current_on_call).to eq('user1')
      end
    end

    context 'with weekly rotation' do
      let(:rotation_start) { 14.days.ago.beginning_of_day }
      let(:schedule) do
        create(:on_call_schedule,
          schedule_type: 'custom',
          rotation_type: 'weekly',
          rotation_start: rotation_start,
          members: ['user1', 'user2', 'user3']
        )
      end

      it 'rotates weekly based on rotation_start' do
        schedule.send(:update_rotation_on_call!)
        # 14 days since start, 3 members, so index = (14 / 7) % 3 = 2
        expect(schedule.current_on_call).to eq('user3')
      end
    end

    context 'with empty members' do
      let(:schedule) do
        create(:on_call_schedule,
          schedule_type: 'custom',
          rotation_type: 'daily',
          rotation_start: Time.current,
          members: []
        )
      end

      it 'does not update when members is empty' do
        expect {
          schedule.send(:update_rotation_on_call!)
        }.not_to change(schedule, :current_on_call)
      end
    end
  end
end
