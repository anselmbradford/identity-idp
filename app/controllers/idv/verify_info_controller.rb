module Idv
  class VerifyInfoController < ApplicationController
    include IdvStepConcern
    include StepUtilitiesConcern
    include StepIndicatorConcern
    include VerifyInfoConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_ssn_step_complete
    before_action :confirm_profile_not_already_confirmed

    def show
      @in_person_proofing = false
      @verify_info_submit_path = idv_verify_info_path
      @step_indicator_steps = step_indicator_steps

      increment_step_counts
      analytics.idv_doc_auth_verify_visited(**analytics_arguments)
      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
        call('verify', :view, true)

      if ssn_throttle.throttled?
        idv_failure_log_throttled(:proof_ssn)
        redirect_to idv_session_errors_ssn_failure_url
        return
      end

      if resolution_throttle.throttled?
        idv_failure_log_throttled(:idv_resolution)
        redirect_to throttled_url
        return
      end

      @had_barcode_read_failure = flow_session[:had_barcode_read_failure]
      process_async_state(load_async_state)
    end

    def update
      return if idv_session.verify_info_step_document_capture_session_uuid
      analytics.idv_doc_auth_verify_submitted(**analytics_arguments)
      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
        call('verify', :update, true)

      pii[:uuid_prefix] = ServiceProvider.find_by(issuer: sp_session[:issuer])&.app_id

      ssn_throttle.increment!
      if ssn_throttle.throttled?
        idv_failure_log_throttled(:proof_ssn)
        analytics.throttler_rate_limit_triggered(
          throttle_type: :proof_ssn,
          step_name: 'verify_info',
        )
        redirect_to idv_session_errors_ssn_failure_url
        return
      end

      if resolution_throttle.throttled?
        idv_failure_log_throttled(:idv_resolution)
        redirect_to throttled_url
        return
      end

      document_capture_session = DocumentCaptureSession.create(
        user_id: current_user.id,
        issuer: sp_session[:issuer],
      )
      document_capture_session.requested_at = Time.zone.now

      idv_session.verify_info_step_document_capture_session_uuid = document_capture_session.uuid
      idv_session.vendor_phone_confirmation = false
      idv_session.user_phone_confirmation = false

      Idv::Agent.new(pii).proof_resolution(
        document_capture_session,
        should_proof_state_id: should_use_aamva?(pii),
        trace_id: amzn_trace_id,
        user_id: current_user.id,
        threatmetrix_session_id: flow_session[:threatmetrix_session_id],
        request_ip: request.remote_ip,
      )

      redirect_to idv_verify_info_url
    end

    private

    def prev_url
      if IdentityConfig.store.doc_auth_ssn_controller_enabled
        idv_ssn_url
      else
        idv_doc_auth_url
      end
    end

    def analytics_arguments
      {
        flow_path: flow_path,
        step: 'verify',
        step_count: current_flow_step_counts['verify'],
        analytics_id: 'Doc Auth',
        irs_reproofing: irs_reproofing?,
      }.merge(**acuant_sdk_ab_test_analytics_args)
    end

    # copied from verify_step
    def pii
      @pii = flow_session[:pii_from_doc] if flow_session
    end

    def delete_pii
      flow_session.delete(:pii_from_doc)
      flow_session.delete(:pii_from_user)
    end

    # copied from address_controller
    def confirm_ssn_step_complete
      return if pii.present? && pii[:ssn].present?
      redirect_to prev_url
    end

    def confirm_profile_not_already_confirmed
      return unless idv_session.profile_confirmation == true
      redirect_to idv_review_url
    end

    def current_flow_step_counts
      user_session['idv/doc_auth_flow_step_counts'] ||= {}
      user_session['idv/doc_auth_flow_step_counts'].default = 0
      user_session['idv/doc_auth_flow_step_counts']
    end

    def increment_step_counts
      current_flow_step_counts['verify'] += 1
    end

    # copied from verify_base_step. May want reconciliation with phone_step
    def process_async_state(current_async_state)
      if current_async_state.none?
        idv_session.resolution_successful = false
        render :show
      elsif current_async_state.in_progress?
        render 'shared/wait'
      elsif current_async_state.missing?
        analytics.idv_proofing_resolution_result_missing
        flash.now[:error] = I18n.t('idv.failure.timeout')
        render :show

        delete_async
        idv_session.resolution_successful = false

        log_idv_verification_submitted_event(
          success: false,
          failure_reason: { idv_verification: [:timeout] },
        )
      elsif current_async_state.done?
        async_state_done(current_async_state)
      end
    end
  end
end
