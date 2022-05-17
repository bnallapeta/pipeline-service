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

    printf "Usage: ARGO_URL="https://argoserver.com" ARGO_USER="user" ARGO_PWD="xxxxxxxxx" DATA_DIR="/workspace" ./register.sh\n\n"

    # Parameters
    printf "The following parameters need to be passed to the script:\n"
    printf "ARGO_URL: the address of the Argo CD server the clusters need to be registered to\n"
    printf "ARGO_USER: the user for the authentication\n"
    printf "ARGO_PWD: the password for the authentication\n"
    printf "DATA_DIR: the location of the cluster files\n"
    printf "INSECURE (optional): whether insecured connection to Argo CD should be allowed. Default value: false\n\n"
}

prechecks () {
    if ! command -v argocd &> /dev/null; then
        printf "Argocd CLI could not be found\n"
    	exit 1
    fi
    ARGO_URL=${ARGO_URL:-}
    if [[ -z "${ARGO_URL}" ]]; then
        printf "ARGO_URL not set\n\n"
        usage
        exit 1	
    fi
    ARGO_USER=${ARGO_USER:-}
    if [[ -z "${ARGO_USER}" ]]; then
        printf "ARGO_USER not set\n\n"
        usage
	exit 1
    fi
    ARGO_PWD=${ARGO_PWD:-}
    if [[ -z "${ARGO_PWD}" ]]; then
	printf "ARGO_PWD not set\n\n"
        usage
	exit 1
    fi
    DATA_DIR=${DATA_DIR:-}
    if [[ -z "${DATA_DIR}" ]]; then
        printf "DATA_DIR not set\n\n"
        usage
	exit 1
    fi
    INSECURE=${INSECURE:-}
    if [[ $(tr '[:upper:]' '[:lower:]' <<< "$INSECURE") == "true" ]]; then
	printf "insecured connection to Argo CD allowed!\n"
        insecure="--insecure"
    else
        insecure=""
    fi
}

# populate clusters with the cluster names taken from the kubconfig
# populate kubconfigs with the associated kubeconfig for each cluster name
get_clusters() {
    clusters=()
    kubeconfigs=()
    # TODO: Romain has /credentials/kubeconfig/plnsvc
    # to clarify: is it a directory plnsvc for all the workload clusters or is plnsvc already specific to 1 workload cluster?
    # If it is the later we need to differentiate between workload clusters (a subdirectory?), kcp and Argo CD credentials
    # something like:
    #   credentials/kubeconfig/workload/plnsvc1
    #   credentials/kubeconfig/workload/plnsvc2
    #   credentials/kubeconfig/workload/plnsvc3
    # If it the former, why plnsvc as name? How does it identify the role they are playing within the service?
    # Looking at /environment it seems to be the former.
    files=($(ls $DATA_DIR/gitops/credentials/kubeconfig/plnsvc))
    for kubeconfig in "${files[@]}"; do
        clusters_sub=($(KUBECONFIG=${DATA_DIR}/gitops/credentials/kubeconfig/plnsvc/${kubeconfig} kubectl config get-clusters | cut -d ':' -f 1 ))
        clusters_sub=( ${clusters_sub[@]:1} )
        clusters+=( ${clusters_sub[@]} )
        for i in "${!clusters_sub[@]}"; do
            kubeconfigs+=( ${kubeconfig} )
        done
    done
}

parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )

prechecks

printf "Retrieving clusters\n"
get_clusters

printf "Logging into Argo CD\n"
# TODO: there may be a better way than user/password
# there should be no assumption that Argo CD runs on the same cluster
argocd ${insecure} login $ARGO_URL --username $ARGO_USER --password $ARGO_PWD

printf "Getting the list of registered clusters\n"
existing_clusters=$(argocd cluster list -o json | jq '.[].name')

printf "Registering clusters and provisioning credentials for Argo CD\n"
for i in "${!clusters[@]}"; do
    printf "Processing cluster %s\n" "${clusters[$i]}"
    if echo "${existing_clusters}" | grep "${clusters[$i]}"; then
        printf "Cluster already registered\n"
    else
        printf "Registering cluster\n"
	# TODO: Romain has /environment/plnsvc/cluster-name/config
	# to clarify:
	# - do we need "config". It seems I don't
	# - as above is "plnsvc" the right name? workload or compute may be a better choice.
	# - the directory name needs to match with the cluster name in kubeconfig
	# - need to document that a directory /environment/plnsvc/${clusters[$i]}/ns-rbac with a kustomize having
	# /environment/plnsvc/base/ns-rbac as a base needs to be created for every new cluster
        # Split between namespace creation and application of rbac policies:
	# - `argocd cluster add` requires the namespaces to exist
	# - `argocd cluster add` applies default rbac that may differ from what is desired
        KUBECONFIG=${DATA_DIR}/gitops/credentials/kubeconfig/plnsvc/${kubeconfigs[$i]} kubectl apply -k ${DATA_DIR}/gitops/environment/plnsvc/${clusters[$i]}/namespaces
#        KUBECONFIG=${DATA_DIR}/gitops/credentials/kubeconfig/plnsvc/${kubeconfigs[$i]} argocd ${insecure} cluster add "${clusters[$i]}" --system-namespace argocd-management --namespace=tekton-pipelines --namespace=kcp-syncer
        KUBECONFIG=${DATA_DIR}/gitops/credentials/kubeconfig/plnsvc/${kubeconfigs[$i]} argocd ${insecure} cluster add "$(yq ".contexts[0].name" <"${DATA_DIR}/gitops/credentials/kubeconfig/plnsvc/${kubeconfigs[$i]}")" --system-namespace argocd-management --namespace=tekton-pipelines --namespace=kcp-syncer --yes
        KUBECONFIG=${DATA_DIR}/gitops/credentials/kubeconfig/plnsvc/${kubeconfigs[$i]} kubectl apply -k ${DATA_DIR}/gitops/environment/plnsvc/${clusters[$i]}/argocd-rbac
        #TODO: After running this script for the first time, this error always pops up. And goes away once you run the script a second time.
        #Interestingly, the below ip 172.30.254.114:6379 seems to belong to the argocd redis pod.
        #FATA[0005] rpc error: code = Unknown desc = dial tcp 172.30.254.114:6379: connect: connection refused
    fi
done

