struct Int
  def object_id
    self
  end
end

module Cryngine
  module System
    class BufferChannel(T) < Channel(T)
      def initialize(@capacity = 2)
        @queue = Deque(T).new(@capacity)
        @mutex = Mutex.new
        super()
      end

      def send(value : T)
        unless full?
          @queue << value
          Crystal::Scheduler.enqueue @receivers
          @receivers.clear
        end
        raise_if_closed

        unless empty?
          @senders << Fiber.current
          Crystal::Scheduler.reschedule
          raise_if_closed
        end

        self
      end

      private def receive_impl
        while empty?
          yield if @closed
          @receivers << Fiber.current
          Crystal::Scheduler.reschedule
        end

        @queue.shift.tap do
          Crystal::Scheduler.enqueue @senders
          @senders.clear
        end
      end

      def queue
        "queue: #{@queue.to_a.join}"
      end

      def full?
        @queue.size >= @capacity
      end

      def any?
        @queue.any?
      end

      def empty?
        queue = @queue
        return true if queue.nil?
        queue.empty?
      end
    end
  end
end
