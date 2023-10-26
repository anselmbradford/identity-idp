require 'rails_helper'

RSpec.describe 'Idv::FlowPolicy' do
  include Rails.application.routes.url_helpers

  let(:user) { create(:user) }

  let(:idv_session) do
    Idv::Session.new(
      user_session: {},
      current_user: user,
      service_provider: nil,
    )
  end

  let(:user_phone_confirmation_session) { nil }
  let(:has_gpo_pending_profile) { nil }

  subject { Idv::FlowPolicy.new(idv_session: idv_session, user: user) }

  context '#controller_allowed?' do
    it 'allows the welcome step' do
      expect(subject.controller_allowed?(controller: Idv::WelcomeController)).to be true
    end
  end

  context 'each step in the flow' do
    before do
      allow(Idv::PhoneConfirmationSession).to receive(:from_h).
        with(user_phone_confirmation_session).and_return(user_phone_confirmation_session)
      allow(user).to receive(:gpo_pending_profile?).and_return(has_gpo_pending_profile)
    end
    context 'empty session' do
      it 'returns welcome' do
        expect(subject.info_for_latest_step.key).to eq(:welcome)
      end
    end

    context 'preconditions for agreement are present' do
      it 'returns agreement' do
        idv_session.welcome_visited = true
        expect(subject.info_for_latest_step.key).to eq(:agreement)
        expect(subject.controller_allowed?(controller: Idv::AgreementController)).to be
        expect(subject.controller_allowed?(controller: Idv::HybridHandoffController)).not_to be
      end
    end

    context 'preconditions for hybrid_handoff are present' do
      it 'returns hybrid_handoff' do
        idv_session.welcome_visited = true
        idv_session.idv_consent_given = true
        expect(subject.info_for_latest_step.key).to eq(:hybrid_handoff)
        expect(subject.controller_allowed?(controller: Idv::HybridHandoffController)).to be
        expect(subject.controller_allowed?(controller: Idv::DocumentCaptureController)).not_to be
      end
    end

    context 'preconditions for document_capture are present' do
      it 'returns document_capture' do
        idv_session.welcome_visited = true
        idv_session.idv_consent_given = true
        idv_session.flow_path = 'standard'
        expect(subject.info_for_latest_step.key).to eq(:document_capture)
        expect(subject.controller_allowed?(controller: Idv::DocumentCaptureController)).to be
        # expect(subject.controller_allowed?(controller: Idv::SsnController)).not_to be
      end
    end

    context 'preconditions for link_sent are present' do
      it 'returns link_sent' do
        idv_session.welcome_visited = true
        idv_session.idv_consent_given = true
        idv_session.flow_path = 'hybrid'
        expect(subject.info_for_latest_step.key).to eq(:link_sent)
        expect(subject.controller_allowed?(controller: Idv::LinkSentController)).to be
        # expect(subject.controller_allowed?(controller: Idv::SsnController)).not_to be
      end
    end

    # context 'preconditions for ssn are present' do
    #   before do
    #     idv_session.welcome_visited = true
    #     idv_session.idv_consent_given = true
    #     idv_session.flow_path = 'standard'
    #     idv_session.pii_from_doc = { pii: 'value' }
    #   end
    #
    #   it 'returns ssn for standard flow' do
    #     expect(subject.info_for_latest_step.key).to eq(:ssn)
    #     expect(subject.controller_allowed?(controller: idv_ssn_path)).to be
    #     expect(subject.controller_allowed?(controller: idv_verify_info_path)).not_to be
    #     expect(subject.path_for_latest_step).to eq(idv_ssn_path)
    #   end
    #
    #   it 'returns ssn for hybrid flow' do
    #     idv_session.flow_path = 'hybrid'
    #     expect(subject.info_for_latest_step.key).to eq(:ssn)
    #     expect(subject.controller_allowed?(controller: idv_ssn_path)).to be
    #     expect(subject.controller_allowed?(controller: idv_verify_info_path)).not_to be
    #     expect(subject.path_for_latest_step).to eq(idv_ssn_path)
    #   end
    # end
    #
    # context 'preconditions for verify_info are present' do
    #   it 'returns verify_info' do
    #     idv_session.welcome_visited = true
    #     idv_session.idv_consent_given = true
    #     idv_session.flow_path = 'standard'
    #     idv_session.pii_from_doc = { pii: 'value' }
    #     idv_session.ssn = '666666666'
    #
    #     expect(subject.info_for_latest_step.key).to eq(:verify_info)
    #     expect(subject.controller_allowed?(controller: idv_verify_info_path)).to be
    #     expect(subject.controller_allowed?(controller: idv_phone_path)).not_to be
    #     expect(subject.path_for_latest_step).to eq(idv_verify_info_path)
    #   end
    # end
    #
    # context 'preconditions for phone are present' do
    #   it 'returns phone' do
    #     idv_session.welcome_visited = true
    #     idv_session.idv_consent_given = true
    #     idv_session.flow_path = 'standard'
    #     idv_session.applicant = { pii: 'value' }
    #     idv_session.ssn = '666666666'
    #     idv_session.resolution_successful = true
    #
    #     expect(subject.info_for_latest_step.key).to eq(:phone)
    #     expect(subject.controller_allowed?(controller: idv_phone_path)).to be
    #     expect(subject.controller_allowed?(controller: idv_otp_verification_path)).not_to be
    #     expect(subject.path_for_latest_step).to eq(idv_phone_path)
    #   end
    # end
    #
    # context 'preconditions for otp_verification are present' do
    #   let(:user_phone_confirmation_session) { { code: 'abcde' } }
    #
    #   it 'returns otp_verification' do
    #     idv_session.welcome_visited = true
    #     idv_session.idv_consent_given = true
    #     idv_session.flow_path = 'standard'
    #     idv_session.applicant = { pii: 'value' }
    #     idv_session.ssn = '666666666'
    #     idv_session.resolution_successful = true
    #     idv_session.user_phone_confirmation_session = user_phone_confirmation_session
    #
    #     expect(subject.info_for_latest_step.key).to eq(:otp_verification)
    #     expect(subject.controller_allowed?(controller: idv_otp_verification_path)).to be
    #     expect(subject.controller_allowed?(controller: idv_enter_password_path)).not_to be
    #     expect(subject.path_for_latest_step).to eq(idv_otp_verification_path)
    #   end
    # end
    #
    # context 'preconditions for enter_password are present' do
    #   let(:user_phone_confirmation_session) { { code: 'abcde' } }
    #
    #   context 'user has a gpo address_verification_mechanism' do
    #     it 'returns enter_password with gpo verification pending' do
    #       idv_session.welcome_visited = true
    #       idv_session.idv_consent_given = true
    #       idv_session.flow_path = 'standard'
    #       idv_session.applicant = { pii: 'value' }
    #       idv_session.ssn = '666666666'
    #       idv_session.resolution_successful = true
    #       idv_session.user_phone_confirmation_session = user_phone_confirmation_session
    #       idv_session.address_verification_mechanism = 'gpo'
    #
    #       expect(subject.info_for_latest_step.key).to eq(:enter_password)
    #       expect(subject.controller_allowed?(controller: idv_enter_password_path)).to be
    #       expect(subject.controller_allowed?(controller: idv_personal_key_path)).not_to be
    #       expect(subject.path_for_latest_step).to eq(idv_enter_password_path)
    #     end
    #   end
    #
    #   context 'user passed phone step' do
    #     it 'returns enter_password' do
    #       idv_session.welcome_visited = true
    #       idv_session.idv_consent_given = true
    #       idv_session.flow_path = 'standard'
    #       idv_session.applicant = { pii: 'value' }
    #       idv_session.ssn = '666666666'
    #       idv_session.resolution_successful = true
    #       idv_session.user_phone_confirmation_session = user_phone_confirmation_session
    #       idv_session.vendor_phone_confirmation = true
    #       idv_session.user_phone_confirmation = true
    #
    #       expect(subject.info_for_latest_step.key).to eq(:enter_password)
    #       expect(subject.controller_allowed?(controller: idv_enter_password_path)).to be
    #       expect(subject.controller_allowed?(controller: idv_personal_key_path)).not_to be
    #       expect(subject.path_for_latest_step).to eq(idv_enter_password_path)
    #     end
    #   end
    # end
  end
end
