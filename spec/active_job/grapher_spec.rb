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

    describe ".put" do
      subject { described_class.put(:job => job, :client => redis) }

      let(:job) { ActiveJob::Base.new }

      it { expect { subject }.to change { redis.query("MATCH (n) RETURN (n)").resultset.count }.by(1) }
      it { expect(subject).to include({ "job_id" => job.job_id }) }
      it { expect(subject).to include({ "queue" => job.queue_name }) }
      it { expect(subject).to include({ "name" => job.class.to_s }) }

      context "with arguments" do
        let(:job) { ActiveJob::Base.new(:foo => "hello", :bar => "goodbye") }

        it { expect(subject).to include({ "foo" => "hello" }) }
        it { expect(subject).to include({ "bar" => "goodbye" }) }
      end
    end
  end
end
