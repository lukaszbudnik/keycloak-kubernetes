# keycloak-kubernetes

This tutorial shows you how to deploy a Keycloak cluster on Kubernetes.

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

# Install Keycloak

We are now ready to install Keycloak:

```
kubectl create ns hotel
helm install -n hotel keycloak-db bitnami/postgresql-ha
kubectl apply -n hotel -f keycloak.yaml
# create HTTPS ingress
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=auth.localtest.me/O=hotel"
kubectl create secret -n hotel tls auth-tls-secret --key tls.key --cert tls.crt
kubectl apply -n hotel -f keycloak-ingress.yaml
```

Keycloak is available at: https://auth.localtest.me.

To get a public key of the `master` realm in PEM format use:

```
echo '-----BEGIN PUBLIC KEY-----' && \
curl -k -s https://auth.localtest.me/auth/realms/master/ | jq -r '.public_key' | fold -w 40 && \
echo '-----END PUBLIC KEY-----'
```