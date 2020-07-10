require "active_support"
require "redisgraph"

module ActiveJob
  module Grapher
    extend ActiveSupport::Concern

    included do
      around_enqueue do |job, block|
        redis = RedisGraph.new("active_job")
        ActiveJob::Grapher.put(:job => job, :client => redis)
        ActiveJob::Grapher.append(:job => job, :client => redis, :enqueued_at => Time.now.to_f)

        enqueuing_job = Struct.new(:job_id)
        ActiveJob::Grapher.enqueued(
          :from => enqueuing_job.new(ActiveJob::Base.logger.formatter.current_tags.last),
          :to => job,
          :client => redis
        )

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

    def self.append(job:, client:, **kwargs)
      properties = kwargs.map do |key, value|
        "j.#{key} = '#{value}'"
      end.join(", ")

      client.query("MATCH (j:job {job_id: '#{job.job_id}'}) SET #{properties} RETURN (j)").resultset.first.first
    end

    def self.enqueued(from:, to:, client:)
      result = client.query("MATCH (f {job_id: '#{from.job_id}'}), (t {job_id: '#{to.job_id}'}) CREATE (f)-[:enqueued]->(t)")

      result.stats[:relationships_created].to_i > 0
    end
  end
end
