class RedisGraphClient
  attr_accessor :connection

  def initialize(connection: RedisGraph.new("active_job"))
    @connection = connection
  end

  def put(job:)
    properties = {
      :job_id => job.job_id,
      :name => job.class,
      :queue => job.queue_name,
      **Hash(job.arguments.first)
    }.map do |key, value|
      "#{key}: '#{value}'"
    end.join(", ")

    connection.query("CREATE (n {#{properties}}) RETURN (n)").resultset.first.first
  end

  def append(job:, **kwargs)
    properties = kwargs.map do |key, value|
      "n.#{key} = '#{value}'"
    end.join(", ")

    connection.query("MATCH (n {job_id: '#{job.job_id}'}) SET #{properties} RETURN (n)").resultset.first&.first
  end

  def enqueued(from:, to:)
    result = connection.query("MATCH (f {job_id: '#{from.job_id}'}), (t {job_id: '#{to.job_id}'}) CREATE (f)-[:enqueued]->(t)")

    result.stats[:relationships_created].to_i > 0
  end
end
