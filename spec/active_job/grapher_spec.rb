require "active_job"
require "active_job/grapher"
require "redisgraph"

module ActiveJob
  RSpec.describe Grapher do
    include ActiveJob::TestHelper
    ActiveJob::Base.queue_adapter = :test

    class GraphingJob < ActiveJob::Base
      include ActiveJob::Grapher

      def perform; end
    end

    let(:redis) { RedisGraph.new("active_job") }

    after { redis.connection.flushall }

    context "when a job is enqueued" do
      it "adds a node" do
        expect { GraphingJob.perform_later }.to change { redis.query("MATCH (n) RETURN (n)").resultset.count }.by(1)
      end

      context "from another job" do
        class EnqueuingJob < GraphingJob
          def perform
            GraphingJob.perform_later
          end
        end

        before { EnqueuingJob.perform_later }

        it "adds a node" do
          expect { perform_enqueued_jobs }.to change { redis.query("MATCH (n) RETURN (n)").resultset.count }.by(1)
        end
      end
    end
  end
end
