module IdvSessionConcern
  extend ActiveSupport::Concern

  included do
    before_action :redirect_unless_idv_session_user
    before_action :redirect_unless_sp_requested_verification
  end

  def confirm_idv_needed
    redirect_to idv_activated_url unless idv_needed?
  end

  def hybrid_session?
    session[:doc_capture_user_id].present?
  end

  def idv_needed?
    user_needs_selfie? ||
      idv_session_user.active_profile.blank? ||
      decorated_sp_session.requested_more_recent_verification? ||
      idv_session_user.reproof_for_irs?(service_provider: current_sp)
  end

  def idv_session
    @idv_session ||= Idv::Session.new(
      user_session: user_session,
      current_user: idv_session_user,
      service_provider: current_sp,
    )
  end

  def irs_reproofing?
    current_user&.reproof_for_irs?(
      service_provider: current_sp,
    ).present?
  end

  def document_capture_session_uuid
    idv_session.document_capture_session_uuid
  end

  def document_capture_session
    return @document_capture_session if defined?(@document_capture_session)
    @document_capture_session = DocumentCaptureSession.find_by(
      uuid: document_capture_session_uuid,
    )
  end

  def redirect_unless_idv_session_user
    redirect_to root_url if !idv_session_user
  end

  def redirect_unless_sp_requested_verification
    return if !IdentityConfig.store.idv_sp_required
    return if idv_session_user.profiles.any?

    ial_context = IalContext.new(
      ial: sp_session_ial,
      service_provider: sp_from_sp_session,
      user: idv_session_user,
    )
    return if ial_context.ial2_or_greater?

    redirect_to account_url
  end

  def idv_session_user
    return User.find_by(id: session[:doc_capture_user_id]) if !current_user && hybrid_session?

    current_user
  end

  def user_needs_selfie?
    decorated_sp_session.selfie_required? && !current_user.identity_verified_with_selfie?
  end
end
