#!/bin/bash

 # Check whether there are EMR clusters running with a prefix
 # If there are, pause the autoscaler by setting it's ECS tasks to zero
 # If not, set the number of tasks to 1


# Expected env vars:
# EMR_PREFIX - prefix to match for running EMR clusters
# EMR_REGION - look for EMR clusters in this region
# AUTOSCALER_CLUSTER - Name of the ECS cluster running the dynamoDB autoscaler
# AUTOSCALER_REGION - Region of the ECS cluster running the autoscaler
# AUTOSCALER_SERVICE - Name of the service that is the dynamoDB autoscaler

#
# Get the number of RUNNING tsaks for the autoscaler ECS service
#
getNumberOfTasks()
{
  num_tasks=$(aws ecs describe-services --cluster ${AUTOSCALER_CLUSTER} --services ${AUTOSCALER_SERVICE} --region ${AUTOSCALER_REGION} --query 'services[0].["runningCount"]' --output text)
  echo ${num_tasks}
}

#
# Sets the number of running tasks for the autoscaler service
#
setNumberOfTasks()
{
  desired_count=$1
  local ret=0

  desired_set_count=$(aws ecs update-service --cluster ${AUTOSCALER_CLUSTER} --service ${AUTOSCALER_SERVICE} --desired-count ${desired_count} --region ${AUTOSCALER_REGION} --query 'service.desiredCount')
  if [ "${desired_set_count}" != "${desired_count}" ]; then
    # We were unable to set the desired tasks for some reason...
    ret=1
  fi

  echo ${ret}
}

#
# Get the number of tasks running for the autoscaler service. if > 0, set to 0
#
pauseScaler()
{
  running_task_count=$(getNumberOfTasks)

  if [ "${running_task_count}" -gt 0 ]; then
    echo "Autoscaler has ${running_task_count} task(s) running - updating to run 0"
    status=$(setNumberOfTasks 0)

    if [ $status == 0 ]; then
      echo "Updated autoscaler service to set number of running tasks to 0"
    else
      echo "ERROR: Unable to update autoscaler service to set number of running tasks to 0 (pause)"
    fi

  else
    echo "Autoscaler currently has ${running_task_count} tasks running - no pause update needed"
  fi
}

#
# Get the number of tasks running for the autoscaler service. If 0, set to 1
#
resumeScaler()
{
  running_task_count=$(getNumberOfTasks)

  if [ "${running_task_count}" == 0 ]; then
    echo "Autoscaler has no currently no running tasks - updating to run 1"
    status=$(setNumberOfTasks 1)

    if [ $status == 0 ]; then
      echo "Updated autoscaler service to set number of running tasks to 1"
    else
      echo "ERROR: Unable to update autoscaler service to set number of running tasks to 1 (resume)"
    fi
  else
    echo "Autoscaler currently has ${running_task_count} tasks running - no resume update needed"
  fi
}

while :
do
  echo "Checking for EMR clusters with prefix ${EMR_PREFIX}"

  cluster_list=$(aws emr list-clusters --active --query 'Clusters[*].Name' --output text --region ${EMR_REGION})

  # use this for testing
  #cluster_list=$(aws emr list-clusters --terminated --query 'Clusters[*].Name' --output text --region ${EMR_REGION})

  if [ -z "${cluster_list}" ]; then
    echo "No active EMR clusters found matching prefix [${EMR_PREFIX}] - ensuring autoscaler is running"
    resumeScaler
  else
    for cluster_name in ${cluster_list}; do
      echo "checking cluster ${cluster_name}"
      if [[ ${cluster_name} = $EMR_PREFIX* ]]; then
        echo "Active EMR cluster [${cluster_name}] found matching prefix [${EMR_PREFIX}] - pausing dynamodb autoscaler"
        pauseScaler
        break
      fi
    done
  fi
  sleep 60
done
