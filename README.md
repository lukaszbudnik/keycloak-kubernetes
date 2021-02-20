# keycloak-kubernetes

This tutorial shows how to deploy a Keycloak cluster to Kubernetes.

All the deployment steps together with a quick cluster test are available on YouTube: [Deploying Keycloak cluster to Kubernetes](https://www.youtube.com/watch?v=g8LVIr8KKSA&list=PLPZal7ksxNs0mgScrJxrggEayV-TPZ9sA&index=1).

I also provide a cloud native demo app which contains:

- React front-end application authenticating with Keycloak using official Keycloak JavaScript adapter
- haproxy acting as an authentication & authorization gateway implemented by [lukaszbudnik/haproxy-auth-gateway](https://github.com/lukaszbudnik/haproxy-auth-gateway)
- mock backend microservices implemented by [lukaszbudnik/yosoy](https://github.com/lukaszbudnik/yosoy)
- ready-to-import Keycloak realm with predefined client, roles, and test users

# Deploy Keycloak cluster

See [Prerequisites](PREREQUISITES.md) to make sure you have Kubernetes Dashboard, nginx-ingress, and bitnami helm repo configured.

If you have all the prerequisites then you are just a few commands from running your first Keycloak cluster on Kubernetes:

```bash
# create dedicated namespace for our deployments
kubectl create ns hotel
# deploy PostgreSQL cluster
helm install -n hotel keycloak-db bitnami/postgresql-ha
# deploy Keycloak cluster
kubectl apply -n hotel -f keycloak.yaml
# create HTTPS ingress for Keycloak
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=auth.localtest.me/O=hotel"
kubectl create secret -n hotel tls auth-tls-secret --key tls.key --cert tls.crt
kubectl apply -n hotel -f keycloak-ingress.yaml
```

Keycloak is now available at: https://auth.localtest.me.

# Install demo apps

I have provided a sample Hotel SPA application which authenticates with Keycloak using official Keycloak JavaScript adapter, obtains JSON Web Token, and then uses it to talk to the protected services using HTTP Authorization Bearer mechanism. Authentication and authorization is implemented by [lukaszbudnik/haproxy-auth-gateway](https://github.com/lukaszbudnik/haproxy-auth-gateway). Mock backend services are implemented by [lukaszbudnik/yosoy](https://github.com/lukaszbudnik/yosoy).

## Import ready-to-use Keycloak realm

Keycloak offers partial exports of clients and users/roles from the admin console. There is also a low level import/export functionality which can export complete realm (together with cryptographic keys). I already setup such realm with clients, roles, and test users. I also exported RSA public key in pem format.

This step could be done using Keycloak API but to keep things simple I will use import functionality:

```bash
# find first keycloak pod
POD_NAME=$(kubectl get pods -n hotel -l app=keycloak --no-headers -o custom-columns=":metadata.name" | head -1)
# copy realm to the pod
kubectl cp -n hotel demo/keycloak/hotel_realm.json $POD_NAME:/tmp/hotel_realm.json
# import realm
kubectl exec -n hotel $POD_NAME -- \
/opt/jboss/keycloak/bin/standalone.sh \
-Djboss.socket.binding.port-offset=100 \
-Dkeycloak.migration.action=import \
-Dkeycloak.migration.provider=singleFile \
-Dkeycloak.migration.file=/tmp/hotel_realm.json
```

As you can see the last command starts Keycloak. That's how import/export actually works. Yes, I know... why there is no option for import/export and then exit? Look for the following messages in the log:

```
06:57:21,510 INFO  [org.keycloak.exportimport.singlefile.SingleFileImportProvider] (ServerService Thread Pool -- 64) Full importing from file /tmp/hotel_realm.json
06:57:25,264 INFO  [org.keycloak.exportimport.util.ImportUtils] (ServerService Thread Pool -- 64) Realm 'hotel' imported
06:57:25,332 INFO  [org.keycloak.services] (ServerService Thread Pool -- 64) KC-SERVICES0032: Import finished successfully
```

And then press [CTRL]+[C] to exit.

More on import/export functionality can be found in Keycloak documentation: https://www.keycloak.org/docs/latest/server_admin/#_export_import.

## Setup haproxy-auth-gateway

```bash
# create configmaps
kubectl create configmap -n hotel haproxy-auth-gateway-iss-cert --from-file=demo/haproxy-auth-gateway/config/hotel.pem
kubectl create configmap -n hotel haproxy-auth-gateway-haproxy-cfg --from-file=demo/haproxy-auth-gateway/config/haproxy.cfg
# deploy the gateway
kubectl apply -n hotel -f demo/haproxy-auth-gateway/gateway.yaml
kubectl apply -n hotel -f demo/haproxy-auth-gateway/gateway-ingress.yaml
```
