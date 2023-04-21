# frozen_string_literal: true

class Analytics
  include AnalyticsEvents
  prepend Idv::AnalyticsEventsEnhancer

  attr_accessor :user
  attr_reader :request, :sp, :ahoy, :irs_session_id, :events

  class FakeAhoy
    attr_reader :events

    def initialize
      @events = {}
    end

    def track(event, analytics_hash)
      if analytics_hash[:proofing_components].instance_of?(Idv::ProofingComponentsLogging)
        analytics_hash[:proofing_components] = analytics_hash[:proofing_components].as_json.symbolize_keys
      end
      @events[event] ||= []

      event_properties = analytics_hash[:event_properties].merge(user_id: analytics_hash[:user_id])
      @events[event] << event_properties
    end
  end

  def self.create_null
    Analytics.new(
      user: AnonymousUser.new,
      request: nil,
      sp: OpenStruct.new(value: 'something'),
      session: {},
      ahoy: FakeAhoy.new,
    )
  end

  def initialize(user:, request:, sp:, session:, ahoy: nil, irs_session_id: nil)
    @user = user
    @request = request
    @sp = sp
    @ahoy = ahoy || Ahoy::Tracker.new(request: request)
    @session = session
    @irs_session_id = irs_session_id
    @events = {}
  end

  def track_event(event, attributes = {})
    attributes.delete(:pii_like_keypaths)
    update_session_events_and_paths_visited_for_analytics(event) if attributes[:success] != false
    analytics_hash = {
      event_properties: attributes.except(:user_id),
      new_event: first_event_this_session?,
      path: request&.path,
      session_duration: session_duration,
      user_id: attributes[:user_id] || user.uuid,
      locale: I18n.locale,
    }

    analytics_hash[:irs_session_id] = irs_session_id if irs_session_id
    analytics_hash.merge!(request_attributes) if request

    ahoy.track(event, analytics_hash)

    duped_attributes = attributes.dup
    if duped_attributes[:proofing_components].instance_of?(Idv::ProofingComponentsLogging)
      duped_attributes[:proofing_components] = duped_attributes[:proofing_components].as_json.symbolize_keys
    end
    events[event] ||= []
    events[event] << duped_attributes

    # Tag NewRelic APM trace with a handful of useful metadata
    # https://www.rubydoc.info/github/newrelic/rpm/NewRelic/Agent#add_custom_attributes-instance_method
    ::NewRelic::Agent.add_custom_attributes(
      user_id: analytics_hash[:user_id],
      user_ip: request&.remote_ip,
      service_provider: sp,
      event_name: event,
      git_sha: IdentityConfig::GIT_SHA,
    )
  end

  def update_session_events_and_paths_visited_for_analytics(event)
    @session[:events] ||= {}
    @session[:first_event] = !@session[:events].key?(event)
    @session[:events][event] = true
  end

  def first_event_this_session?
    @session[:first_event]
  end

  def track_mfa_submit_event(attributes)
    multi_factor_auth(
      **attributes,
      pii_like_keypaths: [[:errors, :personal_key], [:error_details, :personal_key]],
    )
  end

  def request_attributes
    attributes = {
      user_ip: request.remote_ip,
      hostname: request.host,
      pid: Process.pid,
      service_provider: sp,
      trace_id: request.headers['X-Amzn-Trace-Id'],
    }

    attributes[:git_sha] = IdentityConfig::GIT_SHA
    if IdentityConfig::GIT_TAG.present?
      attributes[:git_tag] = IdentityConfig::GIT_TAG
    else
      attributes[:git_branch] = IdentityConfig::GIT_BRANCH
    end

    attributes.merge!(browser_attributes)
  end

  def browser
    @browser ||= BrowserCache.parse(request.user_agent)
  end

  def browser_attributes
    {
      user_agent: request.user_agent,
      browser_name: browser.name,
      browser_version: browser.full_version,
      browser_platform_name: browser.platform.name,
      browser_platform_version: browser.platform.version,
      browser_device_name: browser.device.name,
      browser_mobile: browser.device.mobile?,
      browser_bot: browser.bot?,
    }
  end

  def session_duration
    @session[:session_started_at].present? ? Time.zone.now - session_started_at : nil
  end

  def session_started_at
    value = @session[:session_started_at]
    return value unless value.is_a?(String)
    Time.zone.parse(value)
  end
end
