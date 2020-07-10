require "active_support"
require "redisgraph"

require_relative "../clients/redis_graph_client"

module ActiveJob
  module Grapher
    extend ActiveSupport::Concern

    included do
      around_enqueue do |job, block|
        client = RedisGraphClient.new
        client.put(:job => job)
        client.append(:job => job, :enqueued_at => Time.now.to_f)

        enqueuing_job = Struct.new(:job_id)
        client.enqueued(
          :from => enqueuing_job.new(ActiveJob::Base.logger.formatter.current_tags.last),
          :to => job,
        )

        block.call
      end

      around_perform do |job, block|
        client = RedisGraphClient.new
        client.append(:job => job, :started_at => Time.now.to_f)

        block.call

        client.append(:job => job, :finished_at => Time.now.to_f)
      end
    end
  end
end
