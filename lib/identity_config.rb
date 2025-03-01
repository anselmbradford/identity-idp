class IdentityConfig
  GIT_SHA = `git rev-parse --short=8 HEAD`.chomp
  GIT_TAG = `git tag --points-at HEAD`.chomp.split("\n").first
  GIT_BRANCH = `git rev-parse --abbrev-ref HEAD`.chomp

  VENDOR_STATUS_OPTIONS = %i[operational partial_outage full_outage]

  class << self
    attr_reader :store, :key_types, :unused_keys
  end

  CONVERTERS = {
    # Allows loading a string configuration from a system environment variable
    # ex: To read DATABASE_HOST from system environment for the database_host key
    # database_host: ['env', 'DATABASE_HOST']
    # To use a string value directly, you can specify a string explicitly:
    # database_host: 'localhost'
    string: proc do |value|
      if value.is_a?(Array) && value.length == 2 && value.first == 'env'
        ENV.fetch(value[1])
      elsif value.is_a?(String)
        value
      else
        raise 'invalid system environment configuration value'
      end
    end,
    symbol: proc { |value| value.to_sym },
    comma_separated_string_list: proc do |value|
      value.split(',')
    end,
    integer: proc do |value|
      Integer(value)
    end,
    float: proc do |value|
      Float(value)
    end,
    json: proc do |value, options: {}|
      JSON.parse(value, symbolize_names: options[:symbolize_names])
    end,
    boolean: proc do |value|
      case value
      when 'true', true
        true
      when 'false', false
        false
      else
        raise 'invalid boolean value'
      end
    end,
    date: proc { |value| Date.parse(value) if value },
    timestamp: proc do |value|
      # When the store is built `Time.zone` is not set resulting in a NoMethodError
      # if Time.zone.parse is called
      #
      # rubocop:disable Rails/TimeZone
      Time.parse(value)
      # rubocop:enable Rails/TimeZone
    end,
  }

  attr_reader :key_types

  def initialize(read_env)
    @read_env = read_env
    @written_env = {}
    @key_types = {}
  end

  def add(key, type: :string, allow_nil: false, enum: nil, options: {})
    value = @read_env[key]

    @key_types[key] = type

    converted_value = CONVERTERS.fetch(type).call(value, options: options) if !value.nil?
    raise "#{key} is required but is not present" if converted_value.nil? && !allow_nil
    if enum && !(enum.include?(converted_value) || (converted_value.nil? && allow_nil))
      raise "unexpected #{key}: #{value}, expected one of #{enum}"
    end

    @written_env[key] = converted_value
    @written_env
  end

  attr_reader :written_env

  def self.build_store(config_map)
    #  ______________________________________
    # / Adding something new in here? Please \
    # \ keep methods sorted alphabetically.  /
    #  --------------------------------------
    #                                   /
    #           _.---._    /\\         /
    #        ./'       "--`\//        /
    #      ./              o \       /
    #     /./\  )______   \__ \
    #    ./  / /\ \   | \ \  \ \
    #       / /  \ \  | |\ \  \7
    #        "     "    "  "

    config = IdentityConfig.new(config_map)
    config.add(:aamva_auth_request_timeout, type: :float)
    config.add(:aamva_auth_url, type: :string)
    config.add(:aamva_cert_enabled, type: :boolean)
    config.add(:aamva_private_key, type: :string)
    config.add(:aamva_public_key, type: :string)
    config.add(:aamva_supported_jurisdictions, type: :json)
    config.add(:aamva_verification_request_timeout, type: :float)
    config.add(:aamva_verification_url)
    config.add(:account_reset_token_valid_for_days, type: :integer)
    config.add(:account_reset_wait_period_days, type: :integer)
    config.add(:account_suspended_support_code, type: :string)
    config.add(:acuant_assure_id_password)
    config.add(:acuant_assure_id_subscription_id)
    config.add(:acuant_assure_id_url)
    config.add(:acuant_assure_id_username)
    config.add(:acuant_create_document_timeout, type: :float)
    config.add(:acuant_facial_match_url)
    config.add(:acuant_get_results_timeout, type: :float)
    config.add(:acuant_passlive_url)
    config.add(:acuant_sdk_initialization_creds)
    config.add(:acuant_sdk_initialization_endpoint)
    config.add(:acuant_timeout, type: :float)
    config.add(:acuant_upload_image_timeout, type: :float)
    config.add(:add_email_link_valid_for_hours, type: :integer)
    config.add(:address_identity_proofing_supported_country_codes, type: :json)
    config.add(:all_redirect_uris_cache_duration_minutes, type: :integer)
    config.add(:allowed_ialmax_providers, type: :json)
    config.add(:allowed_verified_within_providers, type: :json)
    config.add(:asset_host, type: :string)
    config.add(:async_stale_job_timeout_seconds, type: :integer)
    config.add(:async_wait_timeout_seconds, type: :integer)
    config.add(:attribute_encryption_key, type: :string)
    config.add(:attribute_encryption_key_queue, type: :json)
    config.add(:aws_http_retry_limit, type: :integer)
    config.add(:aws_http_retry_max_delay, type: :integer)
    config.add(:aws_http_timeout, type: :integer)
    config.add(:aws_kms_client_contextless_pool_size, type: :integer)
    config.add(:aws_kms_client_multi_pool_size, type: :integer)
    config.add(:aws_kms_key_id, type: :string)
    config.add(:aws_kms_multi_region_key_id, type: :string)
    config.add(:aws_kms_session_key_id, type: :string)
    config.add(:aws_logo_bucket, type: :string)
    config.add(:aws_region, type: :string)
    config.add(:backup_code_cost, type: :string)
    config.add(:broken_personal_key_window_finish, type: :timestamp)
    config.add(:broken_personal_key_window_start, type: :timestamp)
    config.add(:component_previews_embed_frame_ancestors, type: :json)
    config.add(:component_previews_enabled, type: :boolean)
    config.add(:country_phone_number_overrides, type: :json)
    config.add(:dashboard_api_token, type: :string)
    config.add(:dashboard_url, type: :string)
    config.add(:database_host, type: :string)
    config.add(:database_name, type: :string)
    config.add(:database_password, type: :string)
    config.add(:database_pool_idp, type: :integer)
    config.add(:database_read_replica_host, type: :string)
    config.add(:database_readonly_password, type: :string)
    config.add(:database_readonly_username, type: :string)
    config.add(:database_socket, type: :string)
    config.add(:database_sslmode, type: :string)
    config.add(:database_statement_timeout, type: :integer)
    config.add(:database_timeout, type: :integer)
    config.add(:database_username, type: :string)
    config.add(:database_worker_jobs_host, type: :string)
    config.add(:database_worker_jobs_name, type: :string)
    config.add(:database_worker_jobs_password, type: :string)
    config.add(:database_worker_jobs_sslmode, type: :string)
    config.add(:database_worker_jobs_username, type: :string)
    config.add(:deleted_user_accounts_report_configs, type: :json)
    config.add(:deliver_mail_async, type: :boolean)
    config.add(:development_mailer_deliver_method, type: :symbol, enum: [:file, :letter_opener])
    config.add(:disable_email_sending, type: :boolean)
    config.add(:disable_logout_get_request, type: :boolean)
    config.add(:disallow_all_web_crawlers, type: :boolean)
    config.add(:disposable_email_services, type: :json)
    config.add(:doc_auth_attempt_window_in_minutes, type: :integer)
    config.add(:doc_auth_check_failed_image_resubmission_enabled, type: :boolean)
    config.add(:doc_auth_client_glare_threshold, type: :integer)
    config.add(:doc_auth_client_sharpness_threshold, type: :integer)
    config.add(:doc_auth_custom_ui_enabled, type: :boolean)
    config.add(:doc_auth_error_dpi_threshold, type: :integer)
    config.add(:doc_auth_error_glare_threshold, type: :integer)
    config.add(:doc_auth_error_sharpness_threshold, type: :integer)
    config.add(:doc_auth_exit_question_section_enabled, type: :boolean)
    config.add(:doc_auth_max_attempts, type: :integer)
    config.add(:doc_auth_max_capture_attempts_before_native_camera, type: :integer)
    config.add(:doc_auth_max_submission_attempts_before_native_camera, type: :integer)
    config.add(:doc_auth_s3_request_timeout, type: :integer)
    config.add(:doc_auth_selfie_capture_enabled, type: :boolean)
    config.add(:doc_auth_sdk_capture_orientation, type: :json, options: { symbolize_names: true })
    config.add(:doc_auth_supported_country_codes, type: :json)
    config.add(:doc_auth_vendor, type: :string)
    config.add(:doc_auth_vendor_randomize, type: :boolean)
    config.add(:doc_auth_vendor_randomize_alternate_vendor, type: :string)
    config.add(:doc_auth_vendor_randomize_percent, type: :integer)
    config.add(:doc_capture_polling_enabled, type: :boolean)
    config.add(:doc_capture_request_valid_for_minutes, type: :integer)
    config.add(:domain_name, type: :string)
    config.add(:email_from, type: :string)
    config.add(:email_from_display_name, type: :string)
    config.add(:email_registrations_per_ip_limit, type: :integer)
    config.add(:email_registrations_per_ip_period, type: :integer)
    config.add(:email_registrations_per_ip_track_only_mode, type: :boolean)
    config.add(:enable_add_mfa_redirect_for_personal_key, type: :boolean)
    config.add(:enable_load_testing_mode, type: :boolean)
    config.add(:enable_rate_limiting, type: :boolean)
    config.add(:enable_test_routes, type: :boolean)
    config.add(:enable_usps_verification, type: :boolean)
    config.add(:encrypted_document_storage_enabled, type: :boolean)
    config.add(:encrypted_document_storage_s3_bucket, type: :string)
    config.add(:event_disavowal_expiration_hours, type: :integer)
    config.add(:feature_idv_force_gpo_verification_enabled, type: :boolean)
    config.add(:feature_idv_hybrid_flow_enabled, type: :boolean)
    config.add(:geo_data_file_path, type: :string)
    config.add(:get_usps_proofing_results_job_cron, type: :string)
    config.add(:get_usps_proofing_results_job_reprocess_delay_minutes, type: :integer)
    config.add(:get_usps_proofing_results_job_request_delay_milliseconds, type: :integer)
    config.add(:get_usps_ready_proofing_results_job_cron, type: :string)
    config.add(:get_usps_waiting_proofing_results_job_cron, type: :string)
    config.add(:good_job_max_threads, type: :integer)
    config.add(:good_job_queue_select_limit, type: :integer)
    config.add(:good_job_queues, type: :string)
    config.add(:gpo_designated_receiver_pii, type: :json, options: { symbolize_names: true })
    config.add(:gpo_max_profile_age_to_send_letter_in_days, type: :integer)
    config.add(:hide_phone_mfa_signup, type: :boolean)
    config.add(:hmac_fingerprinter_key, type: :string)
    config.add(:hmac_fingerprinter_key_queue, type: :json)
    config.add(:identity_pki_disabled, type: :boolean)
    config.add(:identity_pki_local_dev, type: :boolean)
    config.add(:idv_acuant_sdk_upgrade_a_b_testing_enabled, type: :boolean)
    config.add(:idv_acuant_sdk_upgrade_a_b_testing_percent, type: :integer)
    config.add(:idv_acuant_sdk_version_alternate, type: :string)
    config.add(:idv_acuant_sdk_version_default, type: :string)
    config.add(:idv_attempt_window_in_hours, type: :integer)
    config.add(:idv_available, type: :boolean)
    config.add(:idv_contact_phone_number, type: :string)
    config.add(:idv_max_attempts, type: :integer)
    config.add(:idv_min_age_years, type: :integer)
    config.add(:idv_send_link_attempt_window_in_minutes, type: :integer)
    config.add(:idv_send_link_max_attempts, type: :integer)
    config.add(:idv_sp_required, type: :boolean)
    config.add(:in_person_completion_survey_url, type: :string)
    config.add(:in_person_doc_auth_button_enabled, type: :boolean)
    config.add(:in_person_email_reminder_early_benchmark_in_days, type: :integer)
    config.add(:in_person_email_reminder_final_benchmark_in_days, type: :integer)
    config.add(:in_person_email_reminder_late_benchmark_in_days, type: :integer)
    config.add(:in_person_enrollment_validity_in_days, type: :integer)
    config.add(:in_person_enrollments_ready_job_cron, type: :string)
    config.add(:in_person_enrollments_ready_job_email_body_pattern, type: :string)
    config.add(:in_person_enrollments_ready_job_enabled, type: :boolean)
    config.add(:in_person_enrollments_ready_job_max_number_of_messages, type: :integer)
    config.add(:in_person_enrollments_ready_job_queue_url, type: :string)
    config.add(:in_person_enrollments_ready_job_visibility_timeout_seconds, type: :integer)
    config.add(:in_person_enrollments_ready_job_wait_time_seconds, type: :integer)
    config.add(:in_person_full_address_entry_enabled, type: :boolean)
    config.add(:in_person_outage_emailed_by_date, type: :string)
    config.add(:in_person_outage_expected_update_date, type: :string)
    config.add(:in_person_outage_message_enabled, type: :boolean)
    config.add(:in_person_proofing_enabled, type: :boolean)
    config.add(:in_person_proofing_enforce_tmx, type: :boolean)
    config.add(:in_person_proofing_opt_in_enabled, type: :boolean)
    config.add(:in_person_public_address_search_enabled, type: :boolean)
    config.add(:in_person_results_delay_in_hours, type: :integer)
    config.add(:in_person_send_proofing_notifications_enabled, type: :boolean)
    config.add(:in_person_stop_expiring_enrollments, type: :boolean)
    config.add(:include_slo_in_saml_metadata, type: :boolean)
    config.add(:invalid_gpo_confirmation_zipcode, type: :string)
    config.add(:lexisnexis_account_id, type: :string)
    config.add(:lexisnexis_base_url, type: :string)
    config.add(:lexisnexis_hmac_auth_enabled, type: :boolean)
    config.add(:lexisnexis_hmac_key_id, type: :string)
    config.add(:lexisnexis_hmac_secret_key, type: :string)
    config.add(:lexisnexis_instant_verify_timeout, type: :float)
    config.add(:lexisnexis_instant_verify_workflow, type: :string)
    config.add(:lexisnexis_instant_verify_workflow_ab_testing_enabled, type: :boolean)
    config.add(:lexisnexis_instant_verify_workflow_ab_testing_percent, type: :integer)
    config.add(:lexisnexis_instant_verify_workflow_alternate, type: :string)
    config.add(:lexisnexis_password, type: :string)
    config.add(:lexisnexis_phone_finder_timeout, type: :float)
    config.add(:lexisnexis_phone_finder_workflow, type: :string)
    config.add(:lexisnexis_request_mode, type: :string)
    config.add(:lexisnexis_threatmetrix_api_key, type: :string, allow_nil: true)
    config.add(:lexisnexis_threatmetrix_base_url, type: :string, allow_nil: true)
    config.add(:lexisnexis_threatmetrix_js_signing_cert, type: :string)
    config.add(:lexisnexis_threatmetrix_mock_enabled, type: :boolean)
    config.add(:lexisnexis_threatmetrix_org_id, type: :string,  allow_nil: true)
    config.add(:lexisnexis_threatmetrix_policy, type: :string,  allow_nil: true)
    config.add(:lexisnexis_threatmetrix_support_code, type: :string)
    config.add(:lexisnexis_threatmetrix_timeout, type: :float)
    config.add(:lexisnexis_trueid_account_id, type: :string)
    config.add(:lexisnexis_trueid_hmac_key_id, type: :string)
    config.add(:lexisnexis_trueid_hmac_secret_key, type: :string)
    config.add(:lexisnexis_trueid_liveness_cropping_workflow, type: :string)
    config.add(:lexisnexis_trueid_liveness_nocropping_workflow, type: :string)
    config.add(:lexisnexis_trueid_noliveness_cropping_workflow, type: :string)
    config.add(:lexisnexis_trueid_noliveness_nocropping_workflow, type: :string)
    config.add(:lexisnexis_trueid_password, type: :string)
    config.add(:lexisnexis_trueid_timeout, type: :float)
    config.add(:lexisnexis_trueid_username, type: :string)
    config.add(:lexisnexis_username, type: :string)
    config.add(:lockout_period_in_minutes, type: :integer)
    config.add(:log_to_stdout, type: :boolean)
    config.add(:login_otp_confirmation_max_attempts, type: :integer)
    config.add(:logins_per_email_and_ip_bantime, type: :integer)
    config.add(:logins_per_email_and_ip_limit, type: :integer)
    config.add(:logins_per_email_and_ip_period, type: :integer)
    config.add(:logins_per_ip_limit, type: :integer)
    config.add(:logins_per_ip_period, type: :integer)
    config.add(:logins_per_ip_track_only_mode, type: :boolean)
    config.add(:logo_upload_enabled, type: :boolean)
    config.add(:mailer_domain_name)
    config.add(:max_auth_apps_per_account, type: :integer)
    config.add(:max_bad_passwords, type: :integer)
    config.add(:max_bad_passwords_window_in_seconds, type: :integer)
    config.add(:max_emails_per_account, type: :integer)
    config.add(:max_mail_events, type: :integer)
    config.add(:max_mail_events_window_in_days, type: :integer)
    config.add(:max_phone_numbers_per_account, type: :integer)
    config.add(:max_piv_cac_per_account, type: :integer)
    config.add(:min_password_score, type: :integer)
    config.add(:minimum_wait_before_another_usps_letter_in_hours, type: :integer)
    config.add(:mx_timeout, type: :integer)
    config.add(:newrelic_license_key, type: :string)
    config.add(:nonessential_email_banlist, type: :json)
    config.add(
      :openid_connect_redirect,
      type: :string,
      enum: ['server_side', 'client_side', 'client_side_js'],
    )
    config.add(
      :openid_connect_redirect_uuid_override_map,
      type: :json,
    )
    config.add(
      :openid_connect_redirect_issuer_override_map,
      type: :json,
    )
    config.add(:openid_connect_content_security_form_action_enabled, type: :boolean)
    config.add(:otp_delivery_blocklist_findtime, type: :integer)
    config.add(:otp_delivery_blocklist_maxretry, type: :integer)
    config.add(:otp_expiration_warning_seconds, type: :integer)
    config.add(:otp_min_attempts_remaining_warning_count, type: :integer)
    config.add(:otp_valid_for, type: :integer)
    config.add(:otps_per_ip_limit, type: :integer)
    config.add(:otps_per_ip_period, type: :integer)
    config.add(:otps_per_ip_track_only_mode, type: :boolean)
    config.add(:outbound_connection_check_retry_count, type: :integer)
    config.add(:outbound_connection_check_timeout, type: :integer)
    config.add(:outbound_connection_check_url)
    config.add(:participate_in_dap, type: :boolean)
    config.add(:password_max_attempts, type: :integer)
    config.add(:password_pepper, type: :string)
    config.add(:personal_key_retired, type: :boolean)
    config.add(:phone_carrier_registration_blocklist, type: :comma_separated_string_list)
    config.add(:phone_confirmation_max_attempt_window_in_minutes, type: :integer)
    config.add(:phone_confirmation_max_attempts, type: :integer)
    config.add(
      :phone_recaptcha_country_score_overrides,
      type: :json,
      options: { symbolize_names: true },
    )
    config.add(:phone_recaptcha_mock_validator, type: :boolean)
    config.add(:phone_recaptcha_score_threshold, type: :float)
    config.add(:phone_service_check, type: :boolean)
    config.add(:phone_setups_per_ip_limit, type: :integer)
    config.add(:phone_setups_per_ip_period, type: :integer)
    config.add(:phone_setups_per_ip_track_only_mode, type: :boolean)
    config.add(:pii_lock_timeout_in_minutes, type: :integer)
    config.add(:pinpoint_sms_configs, type: :json)
    config.add(:pinpoint_sms_sender_id, type: :string, allow_nil: true)
    config.add(:pinpoint_voice_configs, type: :json)
    config.add(:pinpoint_voice_pool_size, type: :integer)
    config.add(:piv_cac_service_timeout, type: :float)
    config.add(:piv_cac_service_url, type: :string)
    config.add(:piv_cac_verify_token_secret)
    config.add(:piv_cac_verify_token_url, type: :string)
    config.add(:poll_rate_for_verify_in_seconds, type: :integer)
    config.add(:proof_address_max_attempt_window_in_minutes, type: :integer)
    config.add(:proof_address_max_attempts, type: :integer)
    config.add(:proof_ssn_max_attempt_window_in_minutes, type: :integer)
    config.add(:proof_ssn_max_attempts, type: :integer)
    config.add(:proofer_mock_fallback, type: :boolean)
    config.add(
      :proofing_device_profiling,
      type: :symbol,
      enum: [:disabled, :collect_only, :enabled],
    )
    config.add(:push_notifications_enabled, type: :boolean)
    config.add(:pwned_passwords_file_path, type: :string)
    config.add(:rack_mini_profiler, type: :boolean)
    config.add(:rack_timeout_service_timeout_seconds, type: :integer)
    config.add(:rails_mailer_previews_enabled, type: :boolean)
    config.add(:raise_on_missing_title, type: :boolean)
    config.add(:reauthn_window, type: :integer)
    config.add(:recaptcha_enterprise_api_key, type: :string)
    config.add(:recaptcha_enterprise_project_id, type: :string)
    config.add(:recaptcha_secret_key_v2, type: :string)
    config.add(:recaptcha_secret_key_v3, type: :string)
    config.add(:recaptcha_site_key_v2, type: :string)
    config.add(:recaptcha_site_key_v3, type: :string)
    config.add(:recovery_code_length, type: :integer)
    config.add(:redis_pool_size, type: :integer)
    config.add(:redis_throttle_pool_size, type: :integer)
    config.add(:redis_throttle_url, type: :string)
    config.add(:redis_url, type: :string)
    config.add(:reg_confirmed_email_max_attempts, type: :integer)
    config.add(:reg_confirmed_email_window_in_minutes, type: :integer)
    config.add(:reg_unconfirmed_email_max_attempts, type: :integer)
    config.add(:reg_unconfirmed_email_window_in_minutes, type: :integer)
    config.add(:reject_id_token_hint_in_logout, type: :boolean)
    config.add(:remember_device_expiration_hours_aal_1, type: :integer)
    config.add(:remember_device_expiration_minutes_aal_2, type: :integer)
    config.add(:report_timeout, type: :integer)
    config.add(:requests_per_ip_cidr_allowlist, type: :comma_separated_string_list)
    config.add(:requests_per_ip_limit, type: :integer)
    config.add(:requests_per_ip_path_prefixes_allowlist, type: :comma_separated_string_list)
    config.add(:requests_per_ip_period, type: :integer)
    config.add(:requests_per_ip_track_only_mode, type: :boolean)
    config.add(:reset_password_email_max_attempts, type: :integer)
    config.add(:reset_password_email_window_in_minutes, type: :integer)
    config.add(:reset_password_on_auth_fraud_event, type: :boolean)
    config.add(:risc_notifications_active_job_enabled, type: :boolean)
    config.add(:risc_notifications_local_enabled, type: :boolean)
    config.add(:risc_notifications_rate_limit_interval, type: :integer)
    config.add(:risc_notifications_rate_limit_max_requests, type: :integer)
    config.add(:risc_notifications_rate_limit_overrides, type: :json)
    config.add(:risc_notifications_request_timeout, type: :integer)
    config.add(:ruby_workers_idv_enabled, type: :boolean)
    config.add(:rules_of_use_horizon_years, type: :integer)
    config.add(:rules_of_use_updated_at, type: :timestamp)
    config.add(:s3_public_reports_enabled, type: :boolean)
    config.add(:s3_report_bucket_prefix, type: :string)
    config.add(:s3_report_public_bucket_prefix, type: :string)
    config.add(:s3_reports_enabled, type: :boolean)
    config.add(:saml_endpoint_configs, type: :json, options: { symbolize_names: true })
    config.add(:saml_secret_rotation_enabled, type: :boolean)
    config.add(:scrypt_cost, type: :string)
    config.add(:second_mfa_reminder_account_age_in_days, type: :integer)
    config.add(:second_mfa_reminder_sign_in_count, type: :integer)
    config.add(:secret_key_base, type: :string)
    config.add(:seed_agreements_data, type: :boolean)
    config.add(:service_provider_request_ttl_hours, type: :integer)
    config.add(:ses_configuration_set_name, type: :string)
    config.add(:session_check_delay, type: :integer)
    config.add(:session_check_frequency, type: :integer)
    config.add(:session_encryption_key, type: :string)
    config.add(:session_encryptor_alert_enabled, type: :boolean)
    config.add(:session_timeout_in_minutes, type: :integer)
    config.add(:session_timeout_warning_seconds, type: :integer)
    config.add(:session_total_duration_timeout_in_minutes, type: :integer)
    config.add(:set_remember_device_session_expiration, type: :boolean)
    config.add(:show_unsupported_passkey_platform_authentication_setup, type: :boolean)
    config.add(:show_user_attribute_deprecation_warnings, type: :boolean)
    config.add(:skip_encryption_allowed_list, type: :json)
    config.add(:sp_handoff_bounce_max_seconds, type: :integer)
    config.add(:sp_issuer_user_counts_report_configs, type: :json)
    config.add(:state_tracking_enabled, type: :boolean)
    config.add(:team_ada_email, type: :string)
    config.add(:team_all_login_emails, type: :json)
    config.add(:team_daily_reports_emails, type: :json)
    config.add(:team_ursula_email, type: :string)
    config.add(:telephony_adapter, type: :string)
    config.add(:test_ssn_allowed_list, type: :comma_separated_string_list)
    config.add(:totp_code_interval, type: :integer)
    config.add(:unauthorized_scope_enabled, type: :boolean)
    config.add(:use_dashboard_service_providers, type: :boolean)
    config.add(:use_kms, type: :boolean)
    config.add(:use_vot_in_sp_requests, type: :boolean)
    config.add(:usps_auth_token_refresh_job_enabled, type: :boolean)
    config.add(:usps_confirmation_max_days, type: :integer)
    config.add(:usps_ipp_client_id, type: :string)
    config.add(:usps_ipp_password, type: :string)
    config.add(:usps_ipp_request_timeout, type: :integer)
    config.add(:usps_ipp_root_url, type: :string)
    config.add(:usps_ipp_sponsor_id, type: :string)
    config.add(:usps_ipp_transliteration_enabled, type: :boolean)
    config.add(:usps_ipp_username, type: :string)
    config.add(:usps_ipp_enrollment_status_update_email_address, type: :string)
    config.add(:usps_mock_fallback, type: :boolean)
    config.add(:usps_upload_enabled, type: :boolean)
    config.add(:usps_upload_sftp_directory, type: :string)
    config.add(:usps_upload_sftp_host, type: :string)
    config.add(:usps_upload_sftp_password, type: :string)
    config.add(:usps_upload_sftp_timeout, type: :integer)
    config.add(:usps_upload_sftp_username, type: :string)
    config.add(:valid_authn_contexts, type: :json)
    config.add(:vendor_status_acuant, type: :symbol, enum: VENDOR_STATUS_OPTIONS)
    config.add(:vendor_status_lexisnexis_instant_verify, type: :symbol, enum: VENDOR_STATUS_OPTIONS)
    config.add(:vendor_status_lexisnexis_phone_finder, type: :symbol, enum: VENDOR_STATUS_OPTIONS)
    config.add(:vendor_status_lexisnexis_trueid, type: :symbol, enum: VENDOR_STATUS_OPTIONS)
    config.add(:vendor_status_sms, type: :symbol, enum: VENDOR_STATUS_OPTIONS)
    config.add(:vendor_status_voice, type: :symbol, enum: VENDOR_STATUS_OPTIONS)
    config.add(:vendor_status_idv_scheduled_maintenance_start, type: :string)
    config.add(:vendor_status_idv_scheduled_maintenance_finish, type: :string)
    config.add(:verification_errors_report_configs, type: :json)
    config.add(:verify_gpo_key_attempt_window_in_minutes, type: :integer)
    config.add(:verify_gpo_key_max_attempts, type: :integer)
    config.add(:verify_personal_key_attempt_window_in_minutes, type: :integer)
    config.add(:verify_personal_key_max_attempts, type: :integer)
    config.add(:version_headers_enabled, type: :boolean)
    config.add(:voice_otp_pause_time)
    config.add(:voice_otp_speech_rate)
    config.add(:weekly_auth_funnel_report_config, type: :json)

    @key_types = config.key_types
    @unused_keys = config_map.keys - config.written_env.keys
    @store = RedactedStruct.new('IdentityConfig', *config.written_env.keys, keyword_init: true).
      new(**config.written_env)
  end
end
