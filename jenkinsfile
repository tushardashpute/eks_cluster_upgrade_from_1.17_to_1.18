pipeline {

    // Use stash and unstash if removing this
    agent any

    environment {
    eks_cluster_name = "${cluster_name}" 
    artifacts_dir = "${env.WORKSPACE}/artifacts"
    aws_region = "${aws_region}"
    job_root_dir="${env.WORKSPACE}"
    kubernetes_version= "${kubernetes_version}"
    }
    
 
    stages {

    stage('Initialize workspace') {
        steps {
        // Make sure the directory is clean
        dir("${artifacts_dir}") {
            deleteDir()
        }
        sh(script: "mkdir -p ${artifacts_dir}", label: 'Create artifacts directory')
        }
    }
    
    stage("SCM"){
            steps{
                checkout([$class: 'GitSCM', 
                	branches: [[name: '*/main']], doGenerateSubmoduleConfigurations: false, 
                	extensions: [], 
                	submoduleCfg: [], 
                	userRemoteConfigs: [[url: 'https://github.com/tushardashpute/eks_cluster_upgrade_from_1.17_to_1.18.git']]])
            }
        }


    stage('Generate kubeconfig for the cluster') {
        steps {
        script {
            env.KUBECONFIG = "${artifacts_dir}/${eks_cluster_name}-kubeconfig"
            sh 'chmod +x ${WORKSPACE}/*.sh'
        }
        sh(script: '${WORKSPACE}/generate_kubeconfig_eks.sh', label: 'Generate kubeconfig file')
        }
    }
    
    
	stage('Check CoreDNS version') {
	    steps {
			script{
				env.COREDNSVERSION = getCommandOutput("kubectl get deployment coredns -n kube-system -o=jsonpath='{\$.spec.template.spec.containers[:1].image}' | grep -oP '(?<=coredns:v).*'")
				sh(script: '''echo $COREDNSVERSION''', label: 'CoreDNS version')
			}
	    }
	}
	
    stage('Update EKS control plane') {
	    when { expression { shouldUpdateControlPlane(params.kubernetes_version) } }

	    environment {
			kubernetes_version = "${params.kubernetes_version}"
	    }

	    steps {
			script {
		    	sh '''aws eks update-cluster-version \\
                      --region ${aws_region} \\
                      --name ${eks_cluster_name} \\
                      --kubernetes-version  ${kubernetes_version} > cluster-update-output.json'''
                      
                eks_update_id="jq -r '.update.id' cluster-update-output.json"
		    	env.eks_update_id = "4b14ae3b-cfe2-41c7-a78a-6c06a4ab81a5"
		    	
		    	sh '''env.update_status=$(aws eks describe-update \\
			    --region "${aws_region}" \\
			    --name "${eks_cluster_name}" \\
			    --update-id "${eks_update_id}" |
			    jq -r \'.update.status\')'''
			
			    sh '''while [[ "${update_status}" != "Successful" ]]; do
	            echo "Update status is \'${update_status}\'. Waiting for 1m."
	            sleep 1m
	            update_status=$(aws eks describe-update \\
			    --region "${aws_region}" \\
			    --name "${eks_cluster_name}" \\
			    --update-id "${eks_update_id}" |
			    jq -r \'.update.status\')
                done'''
			}
	    }
	}
	
	stage('Update cluster addons') {
	    when { expression { env.control_plane_update_done == 'true' } }

	    environment {
			kubernetes_version = "${params.kubernetes_version}"
	    }

	    steps {
		script {
		    // ref: https://docs.aws.amazon.com/eks/latest/userguide/update-cluster.html
		    def kubeProxyVersions = [
		        '1.19': '1.19.6-eksbuild.2',
		        '1.18': '1.18.8-eksbuild.1',
			    '1.17': '1.17.9-eksbuild.1'
		    ]
		    def corednsVersions = [
		        '1.19': '1.8.0-eksbuild.1',
		        '1.18': '1.7.0-eksbuild.1',
			    '1.17': '1.6.6-eksbuild.1'
		    ]
		    def cni_plugin_url = "https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/v1.7.5/config/v1.7/aws-k8s-cni.yaml"

		    sh(script:"""${WORKSPACE}/update_cluster_addons.sh \
		    	      --kube-proxy-version ${kubeProxyVersions[env.kubernetes_version]} \
		    	      --coredns-version ${corednsVersions[env.kubernetes_version]} \
		    	      --cni-url ${cni_plugin_url}""",
		       label: 'Update KubeProxy, CoreDNS and CNI plugin'
		    )
		}
	    }
	}
	
 	stage('Update worker nodes ASGs') 
	    {
	    steps {
			script{
			
sh '''nodegroup_name=$(eksctl get nodegroups \\
			    --region "${aws_region}" \\
			    --cluster "${eks_cluster_name}"\\
			    -o json |
			    jq -r \'.[0].Name\')

eksctl upgrade nodegroup \\
		    --name= ${nodegroup_name} \\
		    --cluster ${eks_cluster_name} \\
		    --kubernetes-version=${kubernetes_version} \\
		    --region ${aws_region}'''
		}
		}
	} 	
	
    }
    post {
	    cleanup {
	          cleanWs(cleanWhenFailure: false)
	    }
    }
}
def getCommandOutput(command, label=null) {
    if (label == null) {
	label = command.split()[0]
    }
    return sh(script: "${command}", label: label, returnStdout: true).trim()
}

def shouldUpdateControlPlane(kubernetes_version) {
    def currentMajorVersion = getCommandOutput("kubectl version -ojson | jq -r '.serverVersion.major'", 'Find current Kubernetes major version')
    def currentMinorVersion = getCommandOutput("kubectl version -ojson | jq -r '.serverVersion.minor'", 'Find current Kubernetes minor version')
    def signIndex = currentMinorVersion.lastIndexOf("+")
    if (signIndex != -1) {
	currentMinorVersion = currentMinorVersion.substring(0, signIndex)
    }

    def (majorVersion, minorVersion) = kubernetes_version.tokenize('.')

    println("Current control plane version: ${currentMajorVersion}.${currentMinorVersion}")
    println("Requested control plane version: ${kubernetes_version}")
    if (majorVersion.toInteger() > currentMajorVersion.toInteger()) {
	println("Updating the control plane: requested version is greater than the current version")
	return true
    } else if (majorVersion.toInteger() == currentMajorVersion.toInteger() && minorVersion.toInteger() > currentMinorVersion.toInteger()) {
	println("Updating the control plane: requested version is greater than the current version")
	return true
    } else {
	println("Skipping control plane update: requested version is either same or older than the current version")
	return false
    }
}
