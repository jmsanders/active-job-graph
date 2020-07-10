# active-job-graph

`active-job-graph` is an ActiveJob module that uses [ActiveJob Callbacks](https://api.rubyonrails.org/classes/ActiveJob/Callbacks/ClassMethods.html) to log jobs to a graph database.

Each enqueued job is represented as a node. If a job enqueues another job, it's represented with an `enqueued` relationship.

For example, imagine the following simple workflow where `JobA` sleeps for up to 5 seconds and then enqueues `JobB` up to 5 times. `JobB` sleeps for up to 5 second and then enqueues `JobC` up to 5 times. `JobC` sleeps for up 5 seconds. We've threaded a `workflow_id` argument through all of the jobs so that we conceptually group them:

```rb
class JobA < ActiveJob::Base
  include ActiveJob::Grapher

  def perform(workflow_id:)
    rand(0..5).times do
      sleep rand(0..5)
      JobB.perform_later(:workflow_id => workflow_id)
    end
  end
end

class JobB < ActiveJob::Base
  include ActiveJob::Grapher

  def perform(workflow_id:)
    rand(0..5).times do
      sleep rand(0..5)
      JobC.perform_later(:workflow_id => workflow_id)
    end
  end
end

class JobC < ActiveJob::Base
  include ActiveJob::Grapher

  def perform(workflow_id:)
    sleep rand(0..5)
  end
end
```

Let's run the workflow 5 times:

```rb
5.times do
  JobA.perform_later(:workflow_id => SecureRandom.uuid)
end
```

`active-job-redis` enables us to answer questions like "how long did each workflow take?"

```sh
> redis-cli
127.0.0.1:6379> GRAPH.QUERY active_job "MATCH (n {name: 'JobA'})-[:enqueued *1..]->(m) RETURN n.workflow_id, max(toInteger(m.finished_at) - toInteger(n.started_at))"
1) 1) "n.workflow_id"
   2) "max(toInteger(m.finished_at) - toInteger(n.started_at))"
2) 1) 1) "09ee28d6-833b-4663-9f41-37d703888696"
      2) (integer) 32
   2) 1) "189bb455-1b73-45fa-8817-af0698c53beb"
      2) (integer) 33
   3) 1) "3b6ccb36-7313-46da-8c04-933f18fc466c"
      2) (integer) 31
   4) 1) "9363eafc-f02a-496e-9289-1214a014b614"
      2) (integer) 29
   5) 1) "d7ef7814-d35f-47f2-9b3f-49effda169f7"
      2) (integer) 30
3) 1) "Query internal execution time: 1.021100 milliseconds"
```

Or group that same question by the `job_id` of `JobA`:

```sh
> redis-cli
127.0.0.1:6379> GRAPH.QUERY active_job "MATCH (n {name: 'JobA'})-[:enqueued *1..]->(m) RETURN n.job_id, max(toInteger(m.finished_at) - toInteger(n.started_at))"
1) 1) "n.job_id"
   2) "max(toInteger(m.finished_at) - toInteger(n.started_at))"
2) 1) 1) "034e86bd-d727-4a5f-b9dc-3a458b6358e0"
      2) (integer) 32
   2) 1) "17a04678-a5fa-4aab-8c2d-bccdbfb3b712"
      2) (integer) 30
   3) 1) "1d2993f4-dc96-4ca4-974f-bdac9603c77b"
      2) (integer) 33
   4) 1) "29e7a803-1f5b-4d94-a256-6c805a3bb1f1"
      2) (integer) 29
   5) 1) "a36e8fd0-a4fa-40d3-9cc5-f5c88ce64883"
      2) (integer) 31
3) 1) "Query internal execution time: 0.760500 milliseconds"
```

Or how many times `JobC` was enqueued per workflow execution:

```sh
> redis-cli
127.0.0.1:6379> GRAPH.QUERY active_job "MATCH (n {name: 'JobA'})-[:enqueued *1..]->(m {name: 'JobC'}) RETURN n.workflow_id, count(m)"
1) 1) "n.workflow_id"
   2) "count(m)"
2) 1) 1) "09ee28d6-833b-4663-9f41-37d703888696"
      2) (integer) 2
   2) 1) "189bb455-1b73-45fa-8817-af0698c53beb"
      2) (integer) 14
   3) 1) "3b6ccb36-7313-46da-8c04-933f18fc466c"
      2) (integer) 7
   4) 1) "9363eafc-f02a-496e-9289-1214a014b614"
      2) (integer) 11
   5) 1) "d7ef7814-d35f-47f2-9b3f-49effda169f7"
      2) (integer) 6
3) 1) "Query internal execution time: 0.748300 milliseconds"
```

And so on and so forth.

# Test

```
bundle install
docker-compose up -d
bundle exec rspec
```

# What's next?

- [ ] Make the graph database client configurable
- [ ] Support graph database backends beyond [RedisGraph](https://github.com/RedisGraph/RedisGraph)
- [ ] Represent failures and retries
