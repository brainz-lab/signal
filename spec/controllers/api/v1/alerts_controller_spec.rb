require 'rails_helper'

RSpec.describe Api::V1::AlertsController, type: :controller do
  let(:project_id) { SecureRandom.uuid }

  describe 'GET #index' do
    let!(:alert1) { create(:alert, :firing, project_id: project_id) }
    let!(:alert2) { create(:alert, :resolved, project_id: project_id) }
    let!(:other_alert) { create(:alert, project_id: SecureRandom.uuid) }

    before do
      request.headers.merge!(api_headers(project_id))
    end

    it 'returns alerts for the project' do
      get :index
      expect(response).to have_http_status(:success)
      expect(json_response['alerts'].count).to eq(2)
    end

    it 'filters by state' do
      get :index, params: { state: 'firing' }
      expect(json_response['alerts'].count).to eq(1)
      expect(json_response['alerts'].first['state']).to eq('firing')
    end

    it 'filters by severity' do
      critical_rule = create(:alert_rule, :critical, project_id: project_id)
      create(:alert, alert_rule: critical_rule, project_id: project_id)

      get :index, params: { severity: 'critical' }
      expect(json_response['alerts'].count).to eq(1)
    end

    it 'filters unacknowledged alerts' do
      create(:alert, :firing, :acknowledged, project_id: project_id)

      get :index, params: { unacknowledged: 'true' }
      expect(json_response['alerts'].count).to eq(2)
    end

    it 'limits results' do
      create_list(:alert, 60, project_id: project_id)

      get :index, params: { limit: 10 }
      expect(json_response['alerts'].count).to eq(10)
    end

    context 'without authentication' do
      before do
        request.headers.delete('Authorization')
      end

      it 'returns unauthorized' do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET #show' do
    let(:alert) { create(:alert, :firing, project_id: project_id) }

    before do
      request.headers.merge!(api_headers(project_id))
    end

    it 'returns alert details' do
      get :show, params: { id: alert.id }
      expect(response).to have_http_status(:success)
      expect(json_response['id']).to eq(alert.id)
      expect(json_response['incident']).to be_present
    end

    it 'returns not found for non-existent alert' do
      get :show, params: { id: SecureRandom.uuid }
      expect(response).to have_http_status(:not_found)
    end

    it 'returns not found for alert from different project' do
      other_alert = create(:alert)
      get :show, params: { id: other_alert.id }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #acknowledge' do
    let(:alert) { create(:alert, :firing, project_id: project_id) }

    before do
      request.headers.merge!(api_headers(project_id))
    end

    it 'acknowledges the alert' do
      post :acknowledge, params: { id: alert.id, by: 'user1', note: 'Working on it' }

      expect(response).to have_http_status(:success)
      alert.reload
      expect(alert.acknowledged).to be true
      expect(alert.acknowledged_by).to eq('user1')
      expect(alert.acknowledgment_note).to eq('Working on it')
    end

    it 'uses API as default acknowledger' do
      post :acknowledge, params: { id: alert.id }

      alert.reload
      expect(alert.acknowledged_by).to eq('API')
    end

    it 'returns not found for non-existent alert' do
      post :acknowledge, params: { id: SecureRandom.uuid }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #trigger' do
    let(:alert_rule) { create(:alert_rule, project_id: project_id, name: 'Test Rule') }

    before do
      request.headers.merge!(api_headers(project_id))
    end

    it 'creates a manual alert' do
      expect {
        post :trigger, params: {
          name: 'Test Rule',
          value: 150,
          labels: { host: 'server-01' }
        }
      }.to change(Alert, :count).by(1)

      expect(response).to have_http_status(:created)
      alert = Alert.last
      expect(alert.state).to eq('firing')
      expect(alert.current_value).to eq(150)
      expect(alert.labels['host']).to eq('server-01')
    end

    it 'returns not found if rule does not exist' do
      post :trigger, params: { name: 'Non-existent Rule' }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #resolve_by_name' do
    let(:alert_rule) { create(:alert_rule, project_id: project_id, name: 'Test Rule') }
    let!(:alert1) { create(:alert, :firing, alert_rule: alert_rule) }
    let!(:alert2) { create(:alert, :firing, alert_rule: alert_rule) }

    before do
      request.headers.merge!(api_headers(project_id))
    end

    it 'resolves all firing alerts for the rule' do
      post :resolve_by_name, params: { name: 'Test Rule' }

      expect(response).to have_http_status(:success)
      expect(json_response['resolved_count']).to eq(2)

      alert1.reload
      alert2.reload
      expect(alert1.state).to eq('resolved')
      expect(alert2.state).to eq('resolved')
    end

    it 'returns not found if rule does not exist' do
      post :resolve_by_name, params: { name: 'Non-existent Rule' }
      expect(response).to have_http_status(:not_found)
    end
  end
end
