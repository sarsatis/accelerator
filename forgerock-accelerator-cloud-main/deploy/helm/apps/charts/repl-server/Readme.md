# **SUMMARY**

This folder contains the Helm chart for deploying the ForgeRock `Replication Server` component. This can be used as a shared Replication Server (RS) for multiple Directory Servers (User, Token and Application Policy Store (APS)s) or as a dedicated RS for each User, and Token store.

## **PREREQUISITE**

#### [[ Secrets Manager ]]
- Ensure the secrets are accessible from via CICD server or Kubernetes cluster deplending on you secrets deployment methodology.
- The below secrets must exists. Speak with a Midships technical consultant for clarification if you have any queries:
  - certificate
  - certificateKey
  - deploymentKey
  - javaProperties
  - keystorePwd
  - monitorUserPassword
  - properties
  - rootUserPassword
  - truststorePwd
- Note: <br/>
  Above list is default for the accelerator. Please updates as required with you bespoke secrets as required.

## **USAGE**

#### [[ CICD ]]
_EXAMPLE COMMANDS (Cluster only Replication)_
```
helm install \
  --kubeconfig "/root/.kube/config" \
  --set replserver.image="gcr.io/massive-dynamo-235117/forgerock-repl-server:fr7" \
  --set replserver.podName="forgerock-repl-server-blue" \
  --set replserver.serviceName="forgerock-repl-server" \
  --set replserver.clusterDomain="cluster.local" \
  --set replserver.replicas="2" \
  --set replserver.basedn_to_repl_us="ou=users" \
  --set replserver.basedn_to_repl_ts="ou=tokens" \
  --set replserver.basedn_to_repl_cs="ou=am-config" \
  --set replserver.srvs_to_repl_us="forgerock-user-store-gcp-0.forgerock-user-store.forgerock.svc.cluster.local\,forgerock-user-store-gcp-1.forgerock-user-store.forgerock.svc.cluster.local" \
  --set replserver.srvs_to_repl_ts="forgerock-token-store-gcp-0.forgerock-token-store.forgerock.svc.cluster.local\,forgerock-token-store-gcp-1.forgerock-token-store.forgerock.svc.cluster.local" \
  --set replserver.srvs_to_repl_cs="forgerock-access-manager-gcp-0.forgerock-access-manager.forgerock.svc.cluster.local\,forgerock-access-manager-gcp-1.forgerock-access-manager.forgerock.svc.cluster.local" \
  --set replserver.envType="SIT" \
  --set replserver.use_javaProps="false" \
  --set replserver.global_repl_on="false" \
  --set replserver.global_repl_fqdns="" \
  --set secretsmanager.url="http://104.197.209.36:8200" \
  --set secretsmanager.token="s.0KKo0eJy1PKgqCRZsXCrpbPa" \
  --set secretsmanager.rs_path="forgerock/data/sit/repl-server" \
  --set secretsmanager.us_path="forgerock/data/sit/user-store" \
  --set secretsmanager.ts_path="forgerock/data/sit/token-store" \
  --set secretsmanager.aps_path="forgerock/data/sit/config-store" \
  --namespace forgerock \
  forgerock-repl-server repl-server/
```

_EXAMPLE COMMANDS (Inter Cluster Replication : Multi-cluster Replication)_
```
helm install \
  --kubeconfig "/root/.kube/config" \
  --set replserver.image="gcr.io/massive-dynamo-235117/forgerock-repl-server:fr7" \
  --set replserver.podName="forgerock-repl-server-green" \
  --set replserver.serviceName="forgerock-repl-server" \
  --set replserver.clusterDomain="cluster.local" \
  --set replserver.replicas="2" \
  --set replserver.basedn_to_repl_us="ou=users" \
  --set replserver.basedn_to_repl_ts="ou=tokens" \
  --set replserver.basedn_to_repl_cs="ou=am-config" \
  --set replserver.srvs_to_repl_us="forgerock-user-store-gcp-0.forgerock-user-store.forgerock.svc.cluster.local\,forgerock-user-store-gcp-1.forgerock-user-store.forgerock.svc.cluster.local" \
  --set replserver.srvs_to_repl_ts="forgerock-token-store-gcp-0.forgerock-token-store.forgerock.svc.cluster.local\,forgerock-token-store-gcp-1.forgerock-token-store.forgerock.svc.cluster.local" \
  --set replserver.srvs_to_repl_cs="forgerock-access-manager-gcp-0.forgerock-access-manager.forgerock.svc.cluster.local\,forgerock-access-manager-gcp-1.forgerock-access-manager.forgerock.svc.cluster.local" \
  --set replserver.envType="SIT" \
  --set replserver.use_javaProps="false" \
  --set replserver.global_repl_on="true" \
  --set replserver.global_repl_fqdns="europe-north-1A.forgerock-repl-server.forgerock.svc.cluster.local\,europe-north-1B.forgerock-repl-server.forgerock.svc.cluster.local" \
  --set secretsmanager.url="http://104.197.209.36:8200" \
  --set secretsmanager.token="s.0KKo0eJy1PKgqCRZsXCrpbPa" \
  --set secretsmanager.rs_path="forgerock/data/sit/repl-server" \
  --set secretsmanager.us_path="forgerock/data/sit/user-store" \
  --set secretsmanager.ts_path="forgerock/data/sit/token-store" \
  --set secretsmanager.aps_path="forgerock/data/sit/config-store" \
  --namespace forgerock \
  forgerock-repl-server repl-server/
```
