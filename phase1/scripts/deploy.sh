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
  echo "
Usage:
    ${0##*/} [options]

Setup the pipeline service on a cluster running on KCP." >&2
  usage_args
}

install_argocd() {
  if [ "$(tr '[:upper:]' '[:lower:]' <<< "$CLUSTER_ENV")" == "kubernetes" ]; then
    echo "CLUSTER_ENV is set to kubernetes. Proceeding with installing ArgoCD on the kubernetes cluster."
    KUBECONFIG=$KUBECONFIG_PCLUSTER kubectl apply -k ../argocd/argo-server/overlays/kubernetes/
  elif [ "$(tr '[:upper:]' '[:lower:]' <<< "$CLUSTER_ENV")" == "openshift" ]; then
    echo "CLUSTER_ENV is set to openshift. Proceeding with installing ArgoCD on the openshift cluster."
    KUBECONFIG=$KUBECONFIG_PCLUSTER kubectl apply -k ../argocd/argo-server/overlays/openshift/
  fi

  #Prints the ArgoCD details once it's installed successfully
  #Print ARGO_URL, ARGO_USER and ARGO_PWD
  if [ "$(tr '[:upper:]' '[:lower:]' <<< "$CLUSTER_ENV")" == "kubernetes" ]; then
    ARGO_URL=$(KUBECONFIG=$KUBECONFIG_PCLUSTER kubectl -n argocd get svc argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    ARGO_USER="admin"
    ARGO_PWD="$(KUBECONFIG=$KUBECONFIG_PCLUSTER kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo)"
  elif [ "$(tr '[:upper:]' '[:lower:]' <<< "$CLUSTER_ENV")" == "openshift" ]; then
    ARGO_URL="$(KUBECONFIG=$KUBECONFIG_PCLUSTER oc -n argocd get route argocd-server -o jsonpath='{.spec.host}')"
    ARGO_USER="admin"
    #TODO: Add a loop to check if ARGO_PWD is indeed fetched
    ARGO_PWD="$(KUBECONFIG=$KUBECONFIG_PCLUSTER oc -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo)"
  fi

  printf '\nARGO_URL: %s\n' "$ARGO_URL"
  printf 'ARGO_USER: %s\n' "admin"
  printf 'ARGO_PWD: %s\n' "$ARGO_PWD"

#  argocd login "$ARGO_URL" --insecure --username "$ARGO_USER" --password "$ARGO_PWD" >/dev/null

}

install_argo_apps() {
  if [ "$(tr '[:upper:]' '[:lower:]' <<< "$CLUSTER_ENV")" == "kubernetes" ]; then
    echo "CLUSTER_ENV is set to kubernetes. Proceeding with installing pipelines and triggers on the kubernetes cluster."

    KUBECONFIG=$KUBECONFIG_PCLUSTER kubectl apply -f ../argocd/argocd.yaml

  elif [ "$(tr '[:upper:]' '[:lower:]' <<< "$CLUSTER_ENV")" == "openshift" ]; then
    echo "CLUSTER_ENV is set to openshift. Proceeding with installing pipelines and triggers on the openshift cluster."

    KUBECONFIG=$KUBECONFIG_PCLUSTER oc apply -f ../argocd/argocd.yaml
  fi
}

register_pcluster_to_argocd() {
  ARGO_URL="$ARGO_URL" ARGO_USER="$ARGO_USER" ARGO_PWD="$ARGO_PWD" DATA_DIR="/home/bnr/workspace/pipelines-service" INSECURE="true" /home/bnr/workspace/pipelines-service/gitops/argocd/image/register.sh
}

main() {
  parse_init "$@"

  #TODO: What is the default env we want to maintain - kubernetes or openshift
  CLUSTER_ENV=${CLUSTER_ENV:-kubernetes}
  KUBECONFIG_PCLUSTER="/home/bnr/workspace/pipelines-service/gitops/credentials/kubeconfig/plnsvc/pcluster.kubeconfig"
#  CLUSTER_NAME="plnsvc"
#  KCP_ENV="kcp-unstable"
#  KUBECONFIG_KCP_ARGOCD="$KUBECONFIG_DIR/kcp.argocd-manager.yaml"
#  KUBECONFIG_KCP_PLNSVC="$KUBECONFIG_DIR/kcp.plnsvc-manager.yaml"

#Steps
#1. Install ArgoCD on kubernetes or openshift based on flag
#2. Install pipelines and triggers on the physical cluster
#3. Register this cluster onto argocd using gitops/argocd/image/register.sh

#  install_argocd
  install_argo_apps
#  register_pcluster_to_argocd

}

if [ "${BASH_SOURCE[0]}" == "$0" ]; then
  main "$@"
fi