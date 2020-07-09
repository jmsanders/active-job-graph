require "active_support"
require "redisgraph"

module ActiveJob
  module Grapher
    extend ActiveSupport::Concern

    included do
      around_enqueue do |job, block|
        redis = RedisGraph.new("active_job")
        redis.query("CREATE (:job)")

        block.call
      end
    end
  end
end
