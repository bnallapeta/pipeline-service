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

    printf "Usage: DATA_DIR="/workspace" ./register.sh\n\n"

    # Parameters
    printf "The following parameters need to be passed to the script:\n"
    printf "DATA_DIR: the location of the cluster files\n"
}

prechecks () {
    if ! command -v argocd &> /dev/null; then
        printf "Argocd CLI could not be found\n"
    	exit 1
    fi

    DATA_DIR=${DATA_DIR:-}
    if [[ -z "${DATA_DIR}" ]]; then
        printf "DATA_DIR not set\n\n"
        usage
	      exit 1
    fi

    #TODO: Add a precheck to see if openshift-gitops operator is installed
}

# populate clusters with the cluster names taken from the kubeconfig
# populate contexts with the context name taken from the kubeconfig
# populate kubeconfigs with the associated kubeconfig for each cluster name
# only consider the first context for a specific cluster
get_clusters() {
    clusters=()
    contexts=()
    kubeconfigs=()
    files=("$(ls "$DATA_DIR/gitops/credentials/kubeconfig/compute")")
    for kubeconfig in "${files[@]}"; do
        subs=("$(KUBECONFIG=${DATA_DIR}/gitops/credentials/kubeconfig/compute/${kubeconfig} kubectl config view -o jsonpath='{range .contexts[*]}{.name}{","}{.context.cluster}{"\n"}{end}')")
        for sub in "${subs[@]}"; do
            context=$(echo -n "${sub}" | cut -d ',' -f 1)
            cluster=$(echo -n "${sub}" | cut -d ',' -f 2 | cut -d ':' -f 1)
	    if ! (echo "${clusters[@]}" | grep "${cluster}"); then
                clusters+=( "${cluster}" )
                contexts+=( "${context}" )
                kubeconfigs+=( "${kubeconfig}" )
            fi
        done
    done

#    printf '%s -- %s -- %s\n' "${kubeconfigs[@]}" "${clusters[@]}" "${contexts[@]}"
}

install_pipelines_triggers() {
  #TODO: Add a loading bar until components are created
  echo "Installing pipelines and triggers components on the cluster via Openshift GitOps..."
  for i in "${!clusters[@]}"; do
    KUBECONFIG="${DATA_DIR}/gitops/credentials/kubeconfig/compute/${kubeconfigs[$i]}" oc --context "${contexts[$i]}" apply -f "${DATA_DIR}/phase1/argocd/argocd.yaml"
  done
}

main() {
  prechecks
  get_clusters
  install_pipelines_triggers
}

if [ "${BASH_SOURCE[0]}" == "$0" ]; then
  main "$@"
fi