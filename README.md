# active-job-graph

`active-job-graph` is an ActiveJob module that uses [ActiveJob Callbacks](https://api.rubyonrails.org/classes/ActiveJob/Callbacks/ClassMethods.html) to log jobs to a graph database.

Each enqueued job is represented as a node. If a job enqueues another job, it's represented with an `enqueued` relationship.

# Test

```
bundle install
docker-compose up -d
bundle exec rspec
```

# What's next?

- [ ] Make the graph database client configurable
- [ ] Support graph database backends beyond [RedisGraph](https://github.com/RedisGraph/RedisGraph)
- [ ] Append timestamps to nodes when enqueued, when performing starts, and when performing finishes
- [ ] Represent failures and retries
- [ ] Add a demo
