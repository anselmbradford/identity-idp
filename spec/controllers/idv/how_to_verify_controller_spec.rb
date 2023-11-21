require 'rails_helper'

RSpec.describe Idv::HowToVerifyController do
  let(:user) { create(:user) }
  let(:enabled) { true }

  before do
    allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled) { enabled }
    stub_sign_in(user)
    stub_analytics
    subject.idv_session.welcome_visited = true
    subject.idv_session.idv_consent_given = true
  end

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(Idv::HowToVerifyController.step_info).to be_valid
    end
  end

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
      )
    end
  end

  describe '#show' do
    it 'renders the show template' do
      get :show

      expect(response).to render_template :show
    end

    context 'agreement step not completed' do
      before do
        subject.idv_session.idv_consent_given = nil
      end

      it 'redirects to agreement path' do
        get :show

        expect(response).to redirect_to idv_agreement_path
      end
    end
  end

  describe '#update' do
    it 'invalidates future steps' do
      expect(subject).to receive(:clear_future_steps!)

      put :update
    end
  end
end