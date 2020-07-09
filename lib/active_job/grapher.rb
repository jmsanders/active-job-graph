require "active_support"
require "redisgraph"

module ActiveJob
  module Grapher
    extend ActiveSupport::Concern

    included do
      around_enqueue do |job, block|
        redis = RedisGraph.new("active_job")
        ActiveJob::Grapher.put(:job => job, :client => redis)

        block.call
      end
    end

    def self.put(job:, client:)
      properties = {
        :job_id => job.job_id,
        :name => job.class,
        :queue => job.queue_name,
        **Hash(job.arguments.first)
      }.map do |key, value|
        "#{key}: '#{value}'"
      end.join(", ")

      client.query("CREATE (j:job {#{properties}}) RETURN (j)").resultset.first.first
    end
  end
end
