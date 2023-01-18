## Purpose
This folder contains manifests for various PipelineRuns, including Tasks and Pipelines, which are used to measure metrics in the Pipeline Service. These metrics are used to determine a set of Service Level Indicators (SLIs) that help us understand the performance of the system.

It's important to note that the manifests in this folder use canary workloads, which are deterministic payloads whose outcome is known. This serves as a benchmark for testing the system by measuring the time taken to execute these PipelineRuns. By using canary workloads, we can ensure that the metrics captured are accurate and reliable.  
 

#### _pipelinerun-duration.yaml_
This yaml file is utilized to measure the duration of execution for a PipelineRun that calculates the Fibonacci series up to a specified number. The primary objective of this measurement is to ascertain the performance of the system and to identify any potential bottlenecks in the process. This information can be used to make necessary debugging and optimizations to the system in order to understand the issue and fix it.
Eg: The PipelineRun is taking longer time to execute because it is not getting enough CPU. So an admin could potentially look at this and make a decision to add more CPUs to the cluster.
This PipelineRun is run as a CronJob every 15 minutes to make sure that the system is consistently performing as expected. Also, note that the OpenShift Pipelines [Pruner](https://github.com/openshift-pipelines/pipeline-service/blob/05c1a5bd7d822f34be19d90d9660ce0a8d0dd1e2/operator/gitops/argocd/pipeline-service/openshift-pipelines/tekton-config.yaml) configured at the cluster level will run to remove the existing PipelineRuns every 10 minutes.
