require "active_job/grapher"

require "active_job"
require "redisgraph"
require "clients/redis_graph_client"

module ActiveJob
  RSpec.describe Grapher do
    include ActiveJob::TestHelper
    ActiveJob::Base.queue_adapter = :test

    class GraphingJob < ActiveJob::Base
      include ActiveJob::Grapher

      def perform; end
    end

    let(:client) { RedisGraphClient.new }

    before { client.connection.connection.flushall }

    context "when a job is enqueued" do
      it "adds a node" do
        expect { GraphingJob.perform_later }.to change { client.connection.query("MATCH (n) RETURN (n)").resultset.count }.by(1)
      end

      it "includes the enqueued_at time" do
        expect { GraphingJob.perform_later}.to change{ client.connection.query("MATCH (n) RETURN (n.enqueued_at)").resultset }
        expect(client.connection.query("MATCH (n) RETURN (n.enqueued_at)").resultset.first.first).to_not eq(nil)
      end

      context "from another job" do
        class EnqueuingJob < GraphingJob
          def perform
            GraphingJob.perform_later
          end
        end

        before { EnqueuingJob.perform_later }

        it "relates the two nodes" do
          expect { perform_enqueued_jobs }.to change { client.connection.query("MATCH (n)-[:enqueued]->(m) RETURN n, m").resultset.count }.by(1)
        end
      end
    end

    context "when a job is performed" do
      before { GraphingJob.perform_later }
      it "appends the start and finished times" do
        expect { perform_enqueued_jobs }.to change{ client.connection.query("MATCH (n) RETURN n.started_at, n.finished_at").resultset }

        started_at = client.connection.query("MATCH (n) RETURN (n.started_at)").resultset.first.first
        finished_at = client.connection.query("MATCH (n) RETURN (n.finished_at)").resultset.first.first
        expect(finished_at).to be > started_at
      end
    end
  end
end
