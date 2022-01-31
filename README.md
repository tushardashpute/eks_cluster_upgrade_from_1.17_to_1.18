# eks_cluster_upgrade_from_1.17_to_1.18
steps for eks_cluster_upgrade_from_1.17_to_1.18

**Upgrade Using Jenkins Job**

High Level Steps:
1. Generate kubeconfig for the cluster
2. Update the control-plane to the desired version
3. Update kube-proxy,coredns,AWS_VPC_CNI

![image](https://user-images.githubusercontent.com/74225291/151735236-31c0f884-0fa6-4e13-903a-787c8e3e0810.png)


5. Create a new nodegroup with the updated EKS version
6. Migrate to new nodegroup
