# hyperflow-amqp-executor

Job executor for [Hyperflow](http://github.com/dice-cyfronet/hyperflow) workflow engine.

## Usage

Executor may be configured in two ways:

 * by using YAML configuration file (see `examples/settings.yml`) - path to that file should be passed as only argument
 * via environment variables:
   * `STORAGE` = cloud | nfs | local | plgdata | gridftp, defaults to `cloud` (Amazon S3)
   * `AWS_ACCESS_KEY_ID` (for S3 cloud storage)
   * `AWS_SECRET_ACCESS_KEY` (for S3 cloud storage)
   * `AMQP_URL` – address of AMQP queue
   * `AMQP_QUEUE` – name of AMQP queue (defaults to `hyperflow.jobs`)
   * `THREADS` (defaults to number of cores or 1 if it couldn't be determined)
   * `X509_USER_PROXY` – user proxy certificate for PLGData and GridFTP storage
   * `PLGDATA_ENDPOINT` – endpoint of PLGData service (defaults to: `https://data.plgrid.pl`)

To execute jobs:
  
`$ hyperflow-amqp-executor`

To collect some metrics:
  
`$ hyperflow-amqp-metric-collector`

## Supported data storage services

### cloud: Cloud object data storage service

In this scenario, input and output files of jobs are stored in cloud object data storage service such as [Amazon S3](http://aws.amazon.com/s3/). In that case executor does the follwing:

* Create temporary directory
* Download input files
* Execute job in temporary directory
* Upload output files
* Remove temporary directory (anyway, app should remove temporary files itself)

Each task needs to provide some options:

* `s3_bucket` - name of Amazon S3 bucket,
* `s3_prefix` - path prefix in bucket,
* *(optionally)* cloud_storage – same hash as in config file to use other than default storage provider.

### nfs: (Slow) network file system

This case is similar to previous one, but executor will copy files from and copy results back to locally available filesystem. It may be NFS, SSHFS or other file system where working directly on remote data is not recommended.

Job options:

* `workdir` - working directory (files will be copied to local temporary workdir for task processing).

### local: Local/network file system

In this scenario we assume that job is executed in shared directory available on execution node. It may be NFS/SMB/etc. share or local disk for single node deployments. There is no stage-in or stage-out phase, job is executed directly in specified directory, so that job must not leave any temporary files.

Job options:

* `workdir` - working directory (tasks will be executed in this working directory).

### plgdata: PL-Grid Data

Behaves like *cloud* storage, but uses [PL-Grid Data](https://data.plgrid.pl) service as a backend. It requires path of user proxy certificate in `$X509_USER_PROXY`. Does not have any external requirements, however in PLGData file uploads are limited to 256 MiB per file.

Each task needs to provide some options:

* `prefix` – path of working directory on the storage infrastructure (probably something like /people/plgyourlogin/workflowdir).

### gridftp: GridFTP

Behaves like *cloud* storage, but uses [GridFTP](https://www.globus.org/toolkit/docs/latest-stable/gridftp/) service as a backend. It requires path of user proxy certificate in `$X509_USER_PROXY`. Requires `globus-url-copy` which is part of Globus Toolkit installed.

Each task needs to provide some options:

* `prefix` – path of working directory on the storage infrastructure (probably something like gsiftp://example.com/people/plgyourlogin/workflowdir).

## Execution event monitoring

Executor publishes events for monitoring purpose by `hyperflow.events` exchange created on AMQP server. The exchange is topic type, so one may subscribe for specific event type. To request all messages request wildcard routing key `#`. Routing keys are as follows:

* `executor.ready`
* `job.{job-id}.started`
* `job.{job-id}.finished`
* `job.{job-id}.stage-in.started` - not applicable for `local` storage
* `job.{job-id}.stage-in.finished` - not applicable for `local` storage
* `job.{job-id}.execution.started`
* `job.{job-id}.execution.finished`
* `job.{job-id}.stage-out.started` - not applicable for `local` storage
* `job.{job-id}.stage-out.finished` - not applicable for `local` storage

Each event published in JSON provides:

* `executor`: UUID executor id 
* `timestamp`: UNIX timestamp (float in UTC timezone)
* `type`: Like routing key, but without job id part.

Events related to jobs also are provided with:

* `id`: Job id (AMQP correlation id)
* `thread`: Executor thread id (random looking number)

Stage finish events send some additional info: `job.*.stage-in.finished` and `job.*.stage-out.finished` provide `time` and `bytes` for transfer time and data size respectively. The event of `job.*.execution.finished` provides `executable` name, `metrics` and `exit_status`.


## Contributing to hyperflow-amqp-executor
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright

Copyright © 2013-2015 Kamil Figiela (kfigiela@agh.edu.pl). Distributed under MIT License. See LICENSE.txt for further details.

