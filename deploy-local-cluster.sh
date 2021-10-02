#!/bin/bash

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx -n ingress-nginx --create-namespace ingress-nginx/ingress-nginx

helm repo add bitnami https://charts.bitnami.com/bitnami

kubectl create ns hotel

helm install -n hotel keycloak-db bitnami/postgresql-ha

kubectl apply -n hotel -f keycloak.yaml

openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout auth-tls.key -out auth-tls.crt -subj "/CN=auth.localtest.me/O=hotel"
kubectl create secret -n hotel tls auth-tls-secret --key auth-tls.key --cert auth-tls.crt
kubectl apply -n hotel -f keycloak-ingress.yaml

sleep 10

kubectl get deployment -n hotel
kubectl get service -n hotel
kubectl get ingress -n hotel

curl -k -v https://auth.localtest.me/auth/realms/master/protocol/openid-connect/certs

exit 0
