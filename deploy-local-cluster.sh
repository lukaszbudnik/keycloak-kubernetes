#!/bin/bash

#Set namespace to suit your requirements
namespace=hotel

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx -n ingress-nginx --create-namespace ingress-nginx/ingress-nginx

helm repo add bitnami https://charts.bitnami.com/bitnami

kubectl create ns $namespace

openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout auth-tls.key -out auth-tls.crt -subj "/CN=auth.localtest.me/O=hotel"
kubectl create secret -n $namespace tls auth-tls-secret --key auth-tls.key --cert auth-tls.crt

helm install -n $namespace keycloak-db bitnami/postgresql-ha --set postgresql.replicaCount=1

sleep 30

kubectl apply -n $namespace -f keycloak.yaml

sleep 120

kubectl apply -n $namespace -f keycloak-ingress.yaml

sleep 30

kubectl get deployment -n $namespace
kubectl get service -n $namespace
kubectl get ingress -n $namespace

kubectl get pods -n $namespace

# check if all pods are in ready status
pods=$(kubectl get pods -n $namespace --no-headers=true | awk '{print $2}')
all=$(echo "$pods" | wc -l)
ready=$(echo "$pods" | grep '1/1' | wc -l)

[ "$all" = "$ready" ]

exit $?
