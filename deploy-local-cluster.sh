#!/bin/bash

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx -n ingress-nginx --create-namespace ingress-nginx/ingress-nginx

helm repo add bitnami https://charts.bitnami.com/bitnami

kubectl create ns hotel

openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout auth-tls.key -out auth-tls.crt -subj "/CN=auth.localtest.me/O=hotel"
kubectl create secret -n hotel tls auth-tls-secret --key auth-tls.key --cert auth-tls.crt

helm install -n hotel keycloak-db bitnami/postgresql-ha --set postgresql.replicaCount=1

sleep 30

kubectl apply -n hotel -f keycloak.yaml

sleep 120

kubectl apply -n hotel -f keycloak-ingress.yaml

sleep 30

kubectl get deployment -n hotel
kubectl get service -n hotel
kubectl get ingress -n hotel

curl -k https://auth.localtest.me/realms/master/protocol/openid-connect/certs

exit 0
