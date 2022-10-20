# keycloak-kubernetes

This tutorial shows how to deploy a Keycloak cluster to Kubernetes.

All the deployment steps together with a quick cluster test are available on YouTube: [Deploying Keycloak cluster to Kubernetes](https://www.youtube.com/watch?v=g8LVIr8KKSA&list=PLPZal7ksxNs0mgScrJxrggEayV-TPZ9sA&index=1).

I also provide a cloud native demo app which contains:

- React front-end application authenticating with Keycloak using official Keycloak JavaScript adapter [lukaszbudnik/hotel-spa](https://github.com/lukaszbudnik/hotel-spa)
- haproxy acting as an authentication & authorization gateway implemented by [lukaszbudnik/haproxy-auth-gateway](https://github.com/lukaszbudnik/haproxy-auth-gateway)
- mock backend microservices implemented by [lukaszbudnik/yosoy](https://github.com/lukaszbudnik/yosoy)
- ready-to-import Keycloak realm with predefined client, roles, and test users

The deployment and a walkthrough of the demo apps is also available on YouTube: [Keycloak - Distributed apps end-to-end demo](https://www.youtube.com/watch?v=J42sR1t7Vt0&list=PLPZal7ksxNs0mgScrJxrggEayV-TPZ9sA&index=8).

If you want to learn more about Keycloak see [Building cloud native apps: Identity and Access Management](https://dev.to/lukaszbudnik/building-cloud-native-apps-identity-and-access-management-1e5m).

# Deploy Keycloak cluster locally

For local development I will use minikube. For a production-like deployment see [Deploy Keycloak cluster to AWS](#deploy-keycloak-cluster-to-aws-eks).

Start and bootstrap minikube:

```bash
# start minikube
minikube start
minikube addons enable ingress
# prerequisites
helm repo add bitnami https://charts.bitnami.com/bitnami
# when using minikube ingress addon ingress-nginx is already installed
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx -n ingress-nginx --create-namespace ingress-nginx/ingress-nginx
```

Deploy the Keycloak cluster:

```bash
# create dedicated namespace for our deployments
kubectl create ns hotel
# create TLS cert
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout auth-tls.key -out auth-tls.crt -subj "/CN=auth.localtest.me/O=hotel"
kubectl create secret -n hotel tls auth-tls-secret --key auth-tls.key --cert auth-tls.crt
# deploy PostgreSQL cluster - in dev we will use 1 replica, in production use the default value of 3 (or set it to even a higher value)
helm install -n hotel keycloak-db bitnami/postgresql-ha --set postgresql.replicaCount=1
# deploy Keycloak cluster
kubectl apply -n hotel -f keycloak.yaml
# create HTTPS ingress for Keycloak
kubectl apply -n hotel -f keycloak-ingress.yaml
```

Start the tunnel.

```bash
# create tunnel
minikube tunnel
```

Keycloak is now available at: https://auth.localtest.me.

> Note: `auth.localtest.me` points to `127.0.0.1`. In case [localtest.me](https://readme.localtest.me) is blocked on your machine you need to add an entry to `/etc/hosts` or use [minikube ingress-dns addon](https://minikube.sigs.k8s.io/docs/handbook/addons/ingress-dns/).

# Install demo apps

I have provided a sample Hotel SPA application which authenticates with Keycloak using official Keycloak JavaScript adapter, obtains JSON Web Token, and then uses it to talk to the protected services using HTTP Authorization Bearer mechanism.

The architecture diagram looks like this:

![Keycloak demo apps](keycloak-demo-apps.png?raw=true)

## Import ready-to-use Keycloak realm

Keycloak offers partial exports of clients and users/roles from the admin console. There is also a low level import/export functionality which can export complete realm (together with cryptographic keys). I already setup such realm with clients, roles, and test users. I also exported RSA public key in pem format.

After this step a hotel realm will be setup with the following 2 users:

- `julio` with password `julio` and role `camarero`
- `angela` with password `angela` and roles `camarero`, `doncella`, and `cocinera`

There will be also `react` client setup with the following settings:

- `public` access type
- `realm roles` mapper added
- application URLs set to https://lukaszbudnik.github.io/hotel-spa/ (publicly accessible single-page application)

```bash
# find first keycloak pod
POD_NAME=$(kubectl get pods -n hotel -l app=keycloak --no-headers -o custom-columns=":metadata.name" | head -1)
# copy realm to the pod
cat demo/keycloak/hotel_realm.json | kubectl exec -n hotel -i $POD_NAME -- sh -c "cat > /tmp/hotel_realm.json"
# import realm
kubectl exec -n hotel $POD_NAME -- \
/opt/keycloak/bin/kc.sh import --file /tmp/hotel_realm.json
```

As you can see the last command starts Keycloak. That's how import/export actually works. Yes, I know... why there is no option for import/export and then exit? Look for the following messages in the log:

```
06:57:21,510 INFO  [org.keycloak.exportimport.singlefile.SingleFileImportProvider] (ServerService Thread Pool -- 64) Full importing from file /tmp/hotel_realm.json
06:57:25,264 INFO  [org.keycloak.exportimport.util.ImportUtils] (ServerService Thread Pool -- 64) Realm 'hotel' imported
06:57:25,332 INFO  [org.keycloak.services] (ServerService Thread Pool -- 64) KC-SERVICES0032: Import finished successfully
```

At the end there will be an error about Quarkus HTTP server not being able to start. That's OK - there is already Kecloak running in this pod and we only wanted to import the test realm.

More on import/export functionality can be found in Keycloak documentation: https://www.keycloak.org/docs/latest/server_admin/#_export_import.

## Deploy mock backend services

Mock backend services are powered by [lukaszbudnik/yosoy](https://github.com/lukaszbudnik/yosoy). If you haven't used any mocking backend services I highly recommend using yosoy. yosoy is a perfect tool for mocking distributed systems.

There are 3 mock services available:

- doncella
- cocinera
- camarero

They are all deployed as headless services and there is no way end-user can access them directly. All HTTP requests must come through API gateway.

```bash
kubectl apply -n hotel -f demo/apps/hotel.yaml
```

## Deploy haproxy-auth-gateway

Authentication and authorization is implemented by haproxy-auth-gateway project.

haproxy-auth-gateway is drop-in transparent authentication and authorization gateway for cloud native apps. For more information please see [lukaszbudnik/haproxy-auth-gateway](https://github.com/lukaszbudnik/haproxy-auth-gateway).

In this demo I implemented the following ACLs:

- `/camarero` is only allowed if JWT token is valid and contains `camarero` role
- `/doncella` is only allowed if JWT token is valid and contains `doncella` role
- `/cocinera` is only allowed if JWT token is valid and contains `cocinera` role

```bash
# create configmaps
kubectl create configmap -n hotel haproxy-auth-gateway-iss-cert --from-file=demo/haproxy-auth-gateway/config/hotel.pem
kubectl create configmap -n hotel haproxy-auth-gateway-haproxy-cfg --from-file=demo/haproxy-auth-gateway/config/haproxy.cfg
# deploy the gateway
kubectl apply -n hotel -f demo/haproxy-auth-gateway/gateway.yaml
# create HTTPS ingress for the gateway
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout api-tls.key -out api-tls.crt -subj "/CN=api.localtest.me/O=hotel"
kubectl create secret -n hotel tls api-tls-secret --key api-tls.key --cert api-tls.crt
kubectl apply -n hotel -f demo/haproxy-auth-gateway/gateway-ingress.yaml
```

The API gateway is now available at: https://api.localtest.me.

## Public hotel-spa app

The front-end application is [lukaszbudnik/hotel-spa](https://github.com/lukaszbudnik/hotel-spa) which is a React single-page application hosted on GitHub pages: https://lukaszbudnik.github.io/hotel-spa/.

Think of GitHub pages as our CDN.

It uses the following configuration:

```javascript
const keycloak = new Keycloak({
  url: "https://auth.localtest.me",
  realm: "hotel",
  clientId: "react",
});
```

If you followed all the steps in the above tutorial the app is ready to be used: https://lukaszbudnik.github.io/hotel-spa!

# Deploy Keycloak cluster to AWS EKS

The tutorial was moved to separate page: [Deploy Keycloak cluster to AWS EKS](aws-eks-deployment.md).
