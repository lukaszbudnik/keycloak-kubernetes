# Deploy Keycloak to AWS EKS

You can follow below instructions together with my YouTube video: [Deploying Keycloak cluster to AWS EKS](https://youtu.be/BuNZ7bjbzOQ).

Apart of standard Kubernetes tools like `kubectl` and `helm` below example uses [eksctl](https://eksctl.io) to automate provisioning of the AWS infrastructure.

Things are changing over time, the original video was recorded back in 2021. I refreshed below instructions in October 2022 (EKS now requires CSI ESB for PVC, external-dns chart stopped working and Route53 entry needs to be added manually).

Here are the tools and versions I used:

```bash
$ aws --version
aws-cli/2.8.3 Python/3.9.11 Linux/4.14.291-218.527.amzn2.x86_64 exec-env/CloudShell exe/x86_64.amzn.2 prompt/off
$ eksctl version
0.115.0
$ helm version
version.BuildInfo{Version:"v3.10.1", GitCommit:"9f88ccb6aee40b9a0535fcc7efea6055e1ef72c9", GitTreeState:"clean", GoVersion:"go1.18.7"}
$ kubectl version
Client Version: version.Info{Major:"1", Minor:"23+", GitVersion:"v1.23.7-eks-4721010", GitCommit:"b77d9473a02fbfa834afa67d677fd12d690b195f", GitTreeState:"clean", BuildDate:"2022-06-27T22:22:16Z", GoVersion:"go1.17.10", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"23+", GitVersion:"v1.23.10-eks-15b7512", GitCommit:"cd6399691d9b1fed9ec20c9c5e82f5993c3f42cb", GitTreeState:"clean", BuildDate:"2022-08-31T19:17:01Z", GoVersion:"go1.17.13", Compiler:"gc", Platform:"linux/amd64"}
```

## Setup

Setup env variables for AWS account and region:

```bash
export AWS_ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text)
export AWS_REGION=us-east-2
export CLUSTER_EKS_NAME=hotel
export CLUSTER_DNS_NAME=auth.myproduct.example.org
export CLUSTER_CERT_ARN=arn:aws:acm:${AWS_REGION}:${AWS_ACCOUNT}:certificate/95aadb9b-a05c-477d-9d73-7a89329e4af6
```

## Deploy and setup infrastructure

Deploy and setup EKS cluster:

```bash
# install gettext utils (envsubst is used below)
sudo yum install gettext

# create cluster
eksctl create cluster \
  --name $CLUSTER_EKS_NAME \
  --region $AWS_REGION \
  --version 1.23 \
  --with-oidc \
  --node-type t3.medium \
  --nodes 4 \
  --managed

# create ALB controller
curl -o aws-load-balancer-controller-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.4/docs/install/iam_policy.json
aws iam create-policy \
  --policy-name AmazonEKS_AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://aws-load-balancer-controller-policy.json
eksctl create iamserviceaccount \
  --cluster=$CLUSTER_EKS_NAME \
  --region $AWS_REGION \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::$AWS_ACCOUNT:policy/AmazonEKS_AWSLoadBalancerControllerIAMPolicy \
  --approve
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_EKS_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# create CSI ESB driver which is required for PVC which are used by Bitnami PostgreSQL chart
# for an encrypted EBS please see: https://docs.aws.amazon.com/eks/latest/userguide/csi-iam-role.html
eksctl create iamserviceaccount \
  --cluster $CLUSTER_EKS_NAME \
  --region $AWS_REGION \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve \
  --role-only \
  --role-name AmazonEKS_EBS_CSI_DriverRole
eksctl create addon \
  --cluster $CLUSTER_EKS_NAME \
  --region $AWS_REGION \
  --name aws-ebs-csi-driver \
  --service-account-role-arn arn:aws:iam::$AWS_ACCOUNT:role/AmazonEKS_EBS_CSI_DriverRole
```

Deploy Keycloak:

```bash
# create dedicated namespace for our deployments
kubectl create ns hotel
# create TLS cert
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout auth-tls.key -out auth-tls.crt -subj "/CN=auth.localtest.me/O=hotel"
kubectl create secret -n hotel tls auth-tls-secret --key auth-tls.key --cert auth-tls.crt
# deploy PostgreSQL cluster - in dev we will use 1 replica, in production use the default value of 3 (or set it to even a higher value)
helm install -n hotel keycloak-db bitnami/postgresql-ha --set postgresql.replicaCount=1
# deploy Keycloak cluster
# envsubst replaces all env variables placeholders with their actual values
envsubst < keycloak-eks-placeholder.yaml > keycloak-eks.yaml
kubectl apply -n hotel -f keycloak-eks.yaml
# deploy AWS ALB ingress
# envsubst replaces all env variables placeholders with their actual values
envsubst < keycloak-ingress-eks-placeholder.yaml > keycloak-ingress-eks.yaml
# deploy the ingress
kubectl apply -n hotel -f keycloak-ingress-eks.yaml
```

Wait a minute for ALB to be provisioned. Copy the DNS of the ALB and add it as an A alias record in Route53.

Open Keycloak:

```bash
open https://$CLUSTER_DNS_NAME
```

## AWS IAM Mappings

If you use different IAM user/role for eksctl and AWS console you need to add IAM mappings:

```bash
# ARN of either IAM role or IAM user
export AWS_IAM_ARN=$(aws sts get-caller-identity | jq -r '.Arn')

eksctl create iamidentitymapping \
  --cluster $CLUSTER_EKS_NAME \
  --region $AWS_REGION \
  --arn $AWS_IAM_ARN \
  --username admin \
  --group system:masters
```

## Clean up resources:

```bash
eksctl delete cluster --name $CLUSTER_EKS_NAME --region $AWS_REGION
```
