# frozen_string_literal: true

require 'faktory_worker_ruby'
require 'singleton'

require 'rdfportal/extension'

class ThreadSafeCounter
  include Singleton

  def initialize
    @count = 0
    @mutex = Thread::Mutex.new
  end

  def increment
    @mutex.synchronize do
      @count += 1
    end
  end

  def decrement
    @mutex.synchronize do
      @count -= 1
    end
  end

  def value
    @mutex.synchronize do
      @count
    end
  end
end

class QueueCountMiddleware
  def call(_worker, _job)
    ThreadSafeCounter.instance.increment
    yield
  ensure
    ThreadSafeCounter.instance.decrement
  end
end

class JobLogger
  def call(item)
    logger.info(item['jobtype']) { "[#{item['jid']}] Start args = #{item['args'].inspect}" }

    start = Time.now

    yield

    logger.info(item['jobtype']) { "[#{item['jid']}] Done elapsed = #{elapsed(start)}" }
  rescue StandardError => e
    logger.error(item['jobtype']) { "[#{item['jid']}] Failed elapsed = #{elapsed(start)}\n" + e.full_message }
    raise e
  end

  private

  def elapsed(start)
    (Time.now - start).readable_duration
  end

  def logger
    Faktory.logger
  end
end
