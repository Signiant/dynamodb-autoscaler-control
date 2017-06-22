#!/bin/bash

 # Check whether there are EMR clusters running with a prefix matching that passed in
 # If there are, pause the autoscaler by setting it's ECS tasks to zero
 # If not, set the number of tasks to 1


 # aws emr list-clusters --active --query 'Clusters[*].Name' --output text

# Expected env vars:
# EMR_PREFIX - prefix to match for running EMR clusters
# EMR_REGION - look for EMR clusters in this region
# AUTOSCALER_CLUSTER - Name of the ECS cluster running the dynamoDB autoscaler
# AUTOSCALER_REGION - Region of the ECS cluster running the autoscaler
# AUTOSCALER_SERVICE - Name of the service that is the dynamoDB autoscaler

pauseScaler()
{
  echo "Pausing the autoscaler"
}

resumeScaler()
{
  echo "Resuming the autoscaler"
}

while :
do
  echo "Checking for EMR clusters with prefix ${EMR_PREFIX}"

  #cluster_list=$(aws emr list-clusters --active --query 'Clusters[*].Name' --output text --region {$EMR_REGION})

  cluster_list=$(aws emr list-clusters --terminated --query 'Clusters[*].Name' --output text --region ${EMR_REGION})

  for cluster_name in ${cluster_list}; do
    echo "checking cluster ${cluster_name}"
    if [[ ${cluster_name} = $EMR_PREFIX* ]]; then
      echo "Active EMR cluster [${cluster_name}] found matching prefix [${EMR_PREFIX}] - pausing dynamodb autoscaler"
      pauseScaler
      break
    fi
  done

  sleep 60
done
