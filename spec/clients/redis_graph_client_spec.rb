require "clients/redis_graph_client"

require "active_job"
require "redisgraph"

RSpec.describe RedisGraphClient do
  before { subject.connection.connection.flushall }

  describe "#put" do
    let(:job) { ActiveJob::Base.new }

    it { expect { subject.put(:job => job) }.to change { subject.connection.query("MATCH (n) RETURN (n)").resultset.count }.by(1) }
    it { expect(subject.put(:job => job)).to include({ "job_id" => job.job_id }) }
    it { expect(subject.put(:job => job)).to include({ "queue" => job.queue_name }) }
    it { expect(subject.put(:job => job)).to include({ "name" => job.class.to_s }) }

    context "with arguments" do
      let(:job) { ActiveJob::Base.new(:foo => "hello", :bar => "goodbye") }

      it { expect(subject.put(:job => job)).to include({ "foo" => "hello" }) }
      it { expect(subject.put(:job => job)).to include({ "bar" => "goodbye" }) }
    end
  end

  describe "#append" do
    let(:job) { ActiveJob::Base.new }

    before { subject.put(:job => job) }

    it { expect(subject.append(:job => job, :foo => "hello")).to include({ "foo" => "hello" }) }
  end

  describe "#enqueued" do
    let(:from) { ActiveJob::Base.new }
    let(:to) { ActiveJob::Base.new }

    before do
      subject.put(:job => from)
      subject.put(:job => to)
    end

    it { expect { subject.enqueued(:from => from, :to => to) }.to change { subject.connection.query("MATCH (n)-[:enqueued]->(m) RETURN n, m").resultset.count }.by(1) }
    it { expect(subject.enqueued(:from => from, :to => to)).to eq(true) }

    context "when at least one node doesn't exist" do
      let(:bad_job) { ActiveJob::Base.new }

      it { expect(subject.enqueued(:from => from, :to => bad_job)).to eq(false) }
      it { expect(subject.enqueued(:from => bad_job, :to => to)).to eq(false) }
      it { expect(subject.enqueued(:from => bad_job, :to => bad_job)).to eq(false) }
    end
  end
end
