#!/bin/bash

set -x -o errexit -o pipefail


POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    --kube-proxy-version)
    kube_proxy_version="$2"
    # skip the current argument and value
    shift
    shift
    ;;
    --coredns-version)
    coredns_version="$2"
    shift
    shift
    ;;
    --cni-url)
    cni_plugin_url="$2"
    shift
    shift
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

cd "${artifacts_dir}"


echo "Updating KubeProxy to ${kube_proxy_version}"
kubectl set image daemonset.apps/kube-proxy \
	--namespace kube-system \
	kube-proxy=602401143452.dkr.ecr.us-east-1.amazonaws.com/eks/kube-proxy:v${kube_proxy_version}

kubectl rollout status daemonset.apps/kube-proxy \
	--namespace kube-system

if [[ "${COREDNSVERSION}" =~ "${coredns_version}" ]]; then
    echo "Updating CoreDNS to ${coredns_version}"
    if [[ -z "$(kubectl get configmap coredns -n kube-system -o yaml |grep upstream)" ]]; then
        echo "Upstream Not present"
    else
        echo "Removing upstream from the config map"
        kubectl get configmap coredns -n kube-system -o yaml > coredns.yaml && sed -i -e /upstream$/d -e 's|upstream\\n||g' coredns.yaml 
        kubectl apply -f coredns.yaml -n kube-system
        echo "Upstream removed"
    fi
    kubectl set image deployment.apps/coredns \
        coredns=602401143452.dkr.ecr.us-east-1.amazonaws.com/eks/coredns:v${coredns_version} \
        --namespace kube-system	

    kubectl rollout status deployment.apps/coredns \
        --namespace kube-system
else 
echo "Skipping updating CoreDNS as Tag is Same"
fi
echo "Updating CNI version"

kv=$(echo $kubernetes_version | cut -d'.' -f 2-)
if [[ $kv -lt 18 ]]; then
  	echo "No need to update aws vpc cni as K8s version is less than or eqaul to 1.19"
else
    echo "Updating CNI version!!!!"
  	curl -o aws-k8s-cni.yaml ${cni_plugin_url}
  	sed -i -e 's/us-west-2/us-east-1/' aws-k8s-cni.yaml
  	kubectl apply -f aws-k8s-cni.yaml

	  kubectl rollout status daemonset.apps/aws-node \
		--namespace kube-system
fi
