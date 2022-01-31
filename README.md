# eks_cluster_upgrade_from_1.17_to_1.18
steps for eks_cluster_upgrade_from_1.17_to_1.18

**Upgrade Using Jenkins Job**

High Level Steps:
1. Generate kubeconfig for the cluster
2. Update the control-plane to the desired version
3. Update kube-proxy,coredns,AWS_VPC_CNI
4. Create a new nodegroup with the updated EKS version
5. Migrate to new nodegroup
