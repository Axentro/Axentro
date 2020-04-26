require "uuid"

struct Topic
  getter name : String

  def initialize(@name : String); end

  def ==(other : Topic)
    self.name == other.name
  end
end

struct TopicMessage
  getter payload : String

  def initialize(@payload : String); end
end

struct TopicMessageInfo
  property subscribers : Array(TopicSubscriber) = [] of TopicSubscriber

  def initialize(topic : Topic, message : TopicMessage); end
end

struct TopicNotification
  getter topic : Topic
  getter message : TopicMessage

  def initialize(@topic : Topic, @message : TopicMessage); end
end

struct OutboundTopicNotification
  getter message : TopicMessage

  def initialize(@message : TopicMessage); end
end

struct TopicSubscriber
  getter id : String
  getter topic : Topic

  def initialize(@topic : Topic)
    @id = UUID.random.to_s
  end
end

class MessageBus
  inbound : Channel(TopicNotification)
  outbound : Channel(TopicNotification)
  messages : Array(TopicMessageInfo)

  def initialize(@subscribers : Array(TopicSubscriber))
    @messages = [] of TopicMessageInfo
    @inbound = Channel(TopicNotification).new
    @outbound = Channel(TopicNotification).new
  end

  def run
    spawn same_thread: true {
      notification = @inbound.receive
      @messages << TopicMessageInfo.new(notification.topic, notification.@message)
      @subscribers.each do |subscriber|
        pending = @messages.reject { |topic_info| topic_info.subscribers.includes?(subscriber) }
        pending.each { |message| @outbound.send(notification) }
      end
    }
  end

  def publish(topic : Topic, message : TopicMessage)
    spawn {
      notification = TopicNotification.new(topic, message)
      @inbound.send(notification)
    }
  end

  def subscribe(subscriber : TopicSubscriber, func)
    spawn {
      notification = @outbound.receive
      #   @messages.each { |message| message.subscribers << subscriber }
      func.call(notification)
    }
  end
end

numbers = Topic.new("numbers")
letters = Topic.new("letters")
numbers_subscriber_1 = TopicSubscriber.new(numbers)
numbers_subscriber_2 = TopicSubscriber.new(numbers)

mb = MessageBus.new([numbers_subscriber_1, numbers_subscriber_2])
mb.run

mb.publish(numbers, TopicMessage.new("1"))
mb.publish(numbers, TopicMessage.new("2"))

mb.subscribe(numbers_subscriber_1, ->(message : TopicNotification) {
  puts "first"
  pp message
}
)

mb.subscribe(numbers_subscriber_2, ->(message : TopicNotification) {
  puts "second"
  pp message
}
)

sleep 5
