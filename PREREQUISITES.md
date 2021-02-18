# Prerequisites

Before we get to the actual Keycloak installation we need to setup our Kubernetes cluster.

## kubernetes-dashboard

If you don't have kubernetes dashboard installed already:

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0/aio/deploy/recommended.yaml
kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep admin-user | awk '{print $1}')
kubectl proxy
```

Copy the token from the above output and use it to authenticate to: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#/service?namespace=default.

## nginx-ingress

Make sure you have nginx ingress installed too:

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.43.0/deploy/static/provider/cloud/deploy.yaml
```

## helm

And of course helm with bitnami repo:

```
helm repo add bitnami https://charts.bitnami.com/bitnami
```
