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

SCRIPT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null
  pwd
)"

source "$SCRIPT_DIR/common.sh"

usage() {

    printf "Usage: CLUSTER_ENV="kubernetes" DATA_DIR="/workspace" ./deploy.sh\n\n"

    # Parameters
    printf "The following parameters need to be passed to the script:\n"
    printf "DATA_DIR: the location of this repository\n"
    printf "CLUSTER_ENV: the cluster you are running this script on. Takes either kubernetes or openshift as accepted values.\n"
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
    INSECURE=${INSECURE:-}
    if [[ $(tr '[:upper:]' '[:lower:]' <<< "$INSECURE") == "true" ]]; then
	printf "insecured connection to Argo CD allowed!\n"
        insecure="--insecure"
    else
        insecure=""
    fi
}

install_argocd() {
  if [ "$(tr '[:upper:]' '[:lower:]' <<< "$CLUSTER_ENV")" == "kubernetes" ]; then
    echo "CLUSTER_ENV is set to kubernetes. Proceeding with installing ArgoCD on the kubernetes cluster."

    KUBECONFIG=$KUBECONFIG_PCLUSTER kubectl apply -k ../kubernetes/argocd/argo-server

    #Prints the ArgoCD details once it's installed successfully
    #Print ARGO_URL, ARGO_USER and ARGO_PWD
    ARGO_URL=$(KUBECONFIG=$KUBECONFIG_PCLUSTER kubectl -n argocd get svc argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    ARGO_USER="admin"
    ARGO_PWD="$(KUBECONFIG=$KUBECONFIG_PCLUSTER kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo)"

  elif [ "$(tr '[:upper:]' '[:lower:]' <<< "$CLUSTER_ENV")" == "openshift" ]; then
    echo "CLUSTER_ENV is set to openshift. Proceeding with installing ArgoCD on the openshift cluster."

    KUBECONFIG=$KUBECONFIG_PCLUSTER oc apply -k ../openshift/argocd/argo-server

    #Prints the ArgoCD details once it's installed successfully
    #Print ARGO_URL, ARGO_USER and ARGO_PWD

    declare podname=""
    until [[ -n $podname ]] ; do
      echo "Checking if the Argo pod is ready..."
      podname=$(oc get pods --ignore-not-found -n openshift-gitops -l=app.kubernetes.io/name=openshift-gitops-repo-server -o jsonpath='{.items[0].metadata.name}')
      sleep 3
    done

    oc wait --for=condition=Ready "pod/$podname" -n openshift-gitops --timeout=100s
    ARGO_URL="$(KUBECONFIG=$KUBECONFIG_PCLUSTER oc -n openshift-gitops get route openshift-gitops-server -o jsonpath='{.spec.host}')"
    ARGO_USER="admin"
    #TODO: Add a loop to check if ARGO_PWD is indeed fetched
    ARGO_PWD="$(KUBECONFIG=$KUBECONFIG_PCLUSTER oc -n openshift-gitops get secret openshift-gitops-cluster -o jsonpath="{.data.admin\.password}" | base64 -d; echo)"

  fi


  printf '\nARGO_URL: %s\n' "$ARGO_URL"
  printf 'ARGO_USER: %s\n' "admin"
  printf 'ARGO_PWD: %s\n' "$ARGO_PWD"

#  argocd login "$ARGO_URL" --insecure --username "$ARGO_USER" --password "$ARGO_PWD" >/dev/null

}

install_argo_apps() {
  if [ "$(tr '[:upper:]' '[:lower:]' <<< "$CLUSTER_ENV")" == "kubernetes" ]; then
    echo "CLUSTER_ENV is set to kubernetes. Proceeding with installing pipelines and triggers on the kubernetes cluster."

    KUBECONFIG=$KUBECONFIG_PCLUSTER kubectl apply -f ../kubernetes/argocd/argocd.yaml
    echo "Print the status of the ArgoCD applications."

    KUBECONFIG=$KUBECONFIG_PCLUSTER kubectl -n argocd get apps

  elif [ "$(tr '[:upper:]' '[:lower:]' <<< "$CLUSTER_ENV")" == "openshift" ]; then
    echo "CLUSTER_ENV is set to openshift. Proceeding with installing pipelines and triggers on the openshift cluster."

    KUBECONFIG=$KUBECONFIG_PCLUSTER oc apply -f ../openshift/argocd/argocd.yaml
    echo "Print the status of the ArgoCD applications."

    KUBECONFIG=$KUBECONFIG_PCLUSTER oc -n openshift-gitops get apps
  fi
}

register_pcluster_to_argocd() {
  ARGO_URL="$ARGO_URL" ARGO_USER="$ARGO_USER" ARGO_PWD="$ARGO_PWD" DATA_DIR="/home/bnr/workspace/pipelines-service" INSECURE="true" /home/bnr/workspace/pipelines-service/gitops/argocd/image/register.sh
}

main() {
  parse_init "$@"

  CLUSTER_ENV=${CLUSTER_ENV:-kubernetes}
  KUBECONFIG_PCLUSTER="$DATA_DIR/gitops/credentials/kubeconfig/plnsvc/pcluster.kubeconfig"

#Steps
#1. Install ArgoCD on kubernetes or openshift based on flag
#2. Install pipelines and triggers on the physical cluster
#3. Register this cluster onto argocd using gitops/argocd/image/register.sh

  install_argocd
  install_argo_apps
#  register_pcluster_to_argocd #Not required to call this function explicitly as PAC based (PR push) registration is setup.

}

if [ "${BASH_SOURCE[0]}" == "$0" ]; then
  main "$@"
fi