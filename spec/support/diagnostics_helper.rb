# frozen_string_literal: true

module MessageBus::DiagnosticsHelper
  def publish(channel, data, opts = nil)
    id = super(channel, data, opts)
    if @tracking && (@channel.nil? || @channel == channel)
      m = MessageBus::Message.new(-1, id, channel, data)

      if opts
        m.user_ids = opts[:user_ids]
        m.group_ids = opts[:group_ids]
        m.client_ids = opts[:client_ids]
        m.site_id = opts[:site_id]
      end

      @tracking << m
    end
    id
  end

  def track_publish(channel = nil)
    @channel = channel
    @tracking = tracking = []
    yield
    tracking
  ensure
    @tracking = nil
  end
end

module MessageBus
  extend MessageBus::DiagnosticsHelper
end
