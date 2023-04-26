module Idv
  module HybridMobile
    module HybridMobileConcern
      extend ActiveSupport::Concern

      include AcuantConcern

      included do
        before_action :render_404_if_hybrid_mobile_controllers_disabled
      end

      def check_valid_document_capture_session
        if !document_capture_user
          # The user has not "logged in" to document capture via the EntryController
          return handle_invalid_document_capture_session
        end

        if !document_capture_session
          # The user has not visited the EntryController with a valid document capture session UUID
          return handle_invalid_document_capture_session
        end

        return handle_invalid_document_capture_session if document_capture_session.expired?
      end

      def document_capture_session
        return @document_capture_session if defined?(@document_capture_session)
        @document_capture_session =
          DocumentCaptureSession.find_by(uuid: document_capture_session_uuid)
      end

      def document_capture_session_uuid
        session[:document_capture_session_uuid]
      end

      def document_capture_user
        return @document_capture_user if defined?(@document_capture_user)
        @document_capture_user = User.find_by(id: session[:doc_capture_user_id])
      end

      def handle_invalid_document_capture_session
        flash[:error] = t('errors.capture_doc.invalid_link')
        redirect_to root_url
      end

      def irs_reproofing?
        document_capture_user.reproof_for_irs?(
          service_provider: current_sp,
        ).present?
      end

      def render_404_if_hybrid_mobile_controllers_disabled
        render_not_found unless IdentityConfig.store.doc_auth_hybrid_mobile_controllers_enabled
      end
    end
  end
end
