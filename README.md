# hyperflow-amqp-executor

AMQP job executor for Hyperflow workflow engine (http://github.com/dice-cyfronet/hyperflow).

## Usage

Executor is configured via environment variables:

 * AWS_ACCESS_KEY_ID
 * AWS_SECRET_ACCESS_KEY
 * AMQP_URL
 * THREADS (defaults to number of cores or 1 if it couldn't be determined)


To execute jobs:
  
`$ hyperflow-amqp-executor`

To collect metrics:
  
`$ hyperflow-amqp-metric-collector`

## Contributing to hyperflow-amqp-executor
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright

Copyright (c) 2013 Kamil Figiela (kfigiela@agh.edu.pl). See LICENSE.txt for further details.

