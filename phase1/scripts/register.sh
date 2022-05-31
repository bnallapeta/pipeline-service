#!/usr/bin/env bash

# Copyright 2022 The pipelines-service Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

usage() {

    printf "Usage: DATA_DIR="/workspace" ./register.sh \n\n"

    # Parameters
    printf "The following parameters need to be passed to the script: \n"
    printf "DATA_DIR: the location of the cluster files \n"
}

prechecks () {
    DATA_DIR=${DATA_DIR:-}
    if [[ -z "${DATA_DIR}" ]]; then
        printf "DATA_DIR not set\n\n"
        usage
	      exit 1
    fi
}

# populate clusters with the cluster names taken from the kubeconfig
# populate contexts with the context name taken from the kubeconfig
# populate kubeconfigs with the associated kubeconfig for each cluster name
# only consider the first context for a specific cluster
get_clusters() {
    clusters=()
    contexts=()
    kubeconfigs=()
    printf "Extracting files under the kubeconfig dir and reading the content in each file \n"
    files=("$(ls "$DATA_DIR/gitops/credentials/kubeconfig/compute")")
    for kubeconfig in "${files[@]}"; do
        printf "%s\n" "$kubeconfig"
        subs=("$(KUBECONFIG=${DATA_DIR}/gitops/credentials/kubeconfig/compute/${kubeconfig} kubectl config view -o jsonpath='{range .contexts[*]}{.name}{","}{.context.cluster}{"\n"}{end}')")
        for sub in "${subs[@]}"; do
            context=$(echo -n "${sub}" | cut -d ',' -f 1)
            cluster=$(echo -n "${sub}" | cut -d ',' -f 2 | cut -d ':' -f 1)
	    if ! (echo "${clusters[@]}" | grep "${cluster}"); then
                clusters+=( "${cluster}" )
                contexts+=( "${context}" )
                kubeconfigs+=( "${kubeconfig}" )
                printf "%s --- %s --- %s \n" "$cluster" "$context" "$kubeconfig"
            fi
        done
    done

}

gitops_installed_check() {
#  printf "Checking if Openshift GitOps is installed on the cluster... \n"
    for i in "${!clusters[@]}"; do
      #checking if the gitops server pod is up and running
      declare podname=""
      declare -i i=0
      declare -i timeout=60
      printf "Checking if the GitOps cluster pod is available and Ready."

      until [[ -n $podname ]] ; do
        (( i+=2 ))
        if [[ "${i}" -gt "${timeout}" ]]; then
          printf "\nGitOps cluster pod not found. Exiting the script! \n"
          exit 1
        fi
        printf "."
#        podname=$(KUBECONFIG="${DATA_DIR}/gitops/credentials/kubeconfig/compute/${kubeconfigs[@]}" kubectl --context "${contexts[@]}" get pods --ignore-not-found -n openshift-gitops -l=app.kubernetes.io/name=cluster -o jsonpath='{.items[0].metadata.name}')
        podname=$(KUBECONFIG="${DATA_DIR}/gitops/credentials/kubeconfig/compute/${kubeconfigs[@]}" kubectl --context "${contexts[@]}" get pods --ignore-not-found -n openshift-gitops -l=app.kubernetes.io/name=openshift-gitops-server -o jsonpath='{.items[0].metadata.name}')
        sleep 2
      done

      printf "\n"
      KUBECONFIG="${DATA_DIR}/gitops/credentials/kubeconfig/compute/${kubeconfigs[@]}" kubectl --context "${contexts[@]}" wait --for=condition=Ready "pod/$podname" -n openshift-gitops --timeout=100s

    done
}

install_pipelines_triggers() {
  printf "Installing pipelines and triggers components on the cluster via Openshift GitOps... \n"
  for i in "${!clusters[@]}"; do
    KUBECONFIG="${DATA_DIR}/gitops/credentials/kubeconfig/compute/${kubeconfigs[$i]}" kubectl --context "${contexts[$i]}" apply -f "${DATA_DIR}/phase1/argocd/argocd.yaml"
  done
}

postchecks() {
  #checking if the pipelines and triggers pods are up and running
  #pipelines controller
  declare pipelines_podname=""
  printf "Checking if the pipelines pod is available and Ready"
  until [[ -n $pipelines_podname ]] ; do
    printf "."
    pipelines_podname=$(KUBECONFIG="${DATA_DIR}/gitops/credentials/kubeconfig/compute/${kubeconfigs[$i]}" kubectl --context "${contexts[$i]}" get pods --ignore-not-found -n openshift-pipelines -l=app=tekton-pipelines-controller -o jsonpath='{.items[0].metadata.name}')
    sleep 10
  done

  KUBECONFIG="${DATA_DIR}/gitops/credentials/kubeconfig/compute/${kubeconfigs[$i]}" kubectl --context "${contexts[$i]}" wait --for=condition=Ready "pod/$pipelines_podname" -n openshift-pipelines --timeout=60s

  #triggers controller
  declare triggers_podname=""
  printf "\nChecking if the triggers pod is available and Ready"
  until [[ -n $triggers_podname ]] ; do
    printf "."
    triggers_podname=$(KUBECONFIG="${DATA_DIR}/gitops/credentials/kubeconfig/compute/${kubeconfigs[$i]}" kubectl --context "${contexts[$i]}" get pods --ignore-not-found -n openshift-pipelines -l=app=tekton-triggers-controller -o jsonpath='{.items[0].metadata.name}')
    sleep 10
  done

  KUBECONFIG="${DATA_DIR}/gitops/credentials/kubeconfig/compute/${kubeconfigs[$i]}" kubectl --context "${contexts[$i]}" wait --for=condition=Ready "pod/$triggers_podname" -n openshift-pipelines --timeout=60s

  #triggers interceptor
  declare triggers_interceptor_podname=""
  printf "\nChecking if the triggers interceptor pod is available and Ready"
  until [[ -n $triggers_interceptor_podname ]] ; do
    printf "."
    triggers_interceptor_podname=$(KUBECONFIG="${DATA_DIR}/gitops/credentials/kubeconfig/compute/${kubeconfigs[$i]}" kubectl --context "${contexts[$i]}" get pods --ignore-not-found -n openshift-pipelines -l=app=tekton-triggers-core-interceptors -o jsonpath='{.items[0].metadata.name}')
    sleep 10
  done

  KUBECONFIG="${DATA_DIR}/gitops/credentials/kubeconfig/compute/${kubeconfigs[$i]}" kubectl --context "${contexts[$i]}" wait --for=condition=Ready "pod/$triggers_interceptor_podname" -n openshift-pipelines --timeout=60s

}

main() {
  prechecks
  get_clusters
  gitops_installed_check
  install_pipelines_triggers
  postchecks
}

if [ "${BASH_SOURCE[0]}" == "$0" ]; then
  main "$@"
fi