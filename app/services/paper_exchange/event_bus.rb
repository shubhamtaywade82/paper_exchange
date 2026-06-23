module PaperExchange
  class EventBus
    def initialize
      @subscribers = Hash.new { |h, k| h[k] = [] }
    end

    def subscribe(event_name, &block)
      @subscribers[event_name] << block
    end

    def publish(event_name, payload = {})
      @subscribers[event_name].each { |handler| handler.call(payload) }
    end
  end

  def self.event_bus
    @event_bus ||= EventBus.new
  end
end
