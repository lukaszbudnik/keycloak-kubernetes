# Prerequisites

Before we get to the actual Keycloak installation we need to setup our Kubernetes cluster.

## kubernetes-dashboard

If you don't have kubernetes dashboard installed already:

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.2.0/aio/deploy/recommended.yaml
kubectl -n kubernetes-dashboard get secret $(kubectl -n kubernetes-dashboard get sa/admin-user -o jsonpath="{.secrets[0].name}") -o go-template="{{.data.token | base64decode}}"
kubectl proxy
```

Copy the token from the above output and use it to authenticate to: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#/service?namespace=default.

## nginx-ingress

Make sure you have nginx ingress installed too:

```
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx -n ingress-nginx --create-namespace ingress-nginx/ingress-nginx
```

## bitnami

And of course bitnami repo:

```
helm repo add bitnami https://charts.bitnami.com/bitnami
```
