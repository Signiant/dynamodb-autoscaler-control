# dynamodb-autoscaler-control
Allows automatic enabling or disabling of the DynamoDB autoscaler depending on the presence of a running EMR cluster.

# Purpose
We backup all our DynamoDB tables nighly to S3 using EMR clusters (several in parallel).  We also have our own DynamoDB throughput autoscaler which will scale up if it sees read or write throughput use exceeding 50% of provisioned throughput.

Because we want to read as fast as possible for the backup, we spike the throughput on each table and then read at that rate.  If we have the autoscaler enabled, it will continually scale the provisioned read throughput on the table for the duration of the backup.

Before we start the table backup, we'd like to pause the autoscaler.  In our case, the autoscaler runs on ECS so pausing it is a simple matter of setting the number of running tasks to zero and then setting it back to one when the backups are complete.  This service does this by looking for EMR clusters matching a specific prefix in the active state and pausing the autoscaler if any are running (the check is every 60 seconds).

# Basic workings
The controller will wake every 60 seconds and query for the currently active EMR clusters using the AWS CLI.

If none are found matching the provided prefix, it will test to see if there is a running task for the autoscaler service and if not, start one.

If a running EMR cluster is found matching the prefix, it will test to see if there is a running task for the autoscaler and if so, set the number of tasks to zero for the service

# Running from the command line

```bash
docker run \
  -e EMR_PREFIX='my_emr_cluster_prefix' \
  -e EMR_REGION='us-east-1' \
  -e AUTOSCALER_CLUSTER='my_ecs_cluster' \
  -e AUTOSCALER_REGION='us-west-2' \
  -e AUTOSCALER_SERVICE='my_dynamo_scaler_ecs_service_name'
  signiant/dynamodb-autoscaler-control
```
The following parameters are optional:

* DEBUG_OUTPUT - if this is present, the tool will output more information to the log
* AWS_ACCESS_KEY_ID - if running outside AWS, a valid access key
* AWS_SECRET_ACCESS_KEY - if running outside AWS, a valid secret key
