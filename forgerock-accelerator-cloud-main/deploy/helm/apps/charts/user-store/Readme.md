# **SUMMARY**

This folder contains the Helm chart for deploying the ForgeRock `User Store` component.

## **PREREQUISITE**

#### [[ Secrets Manager ]]
- Ensure the secrets are accessible from via CICD server or Kubernetes cluster deplending on you secrets deployment methodology.
- The below secrets must exists. Speak with a Midships technical consultant for clarification if you have any queries:
  - amIdentityStoreAdminPassword
  - certificate
  - certificateKey
  - deploymentKey
  - file_dsconfig
  - file_schema
  - javaProperties
  - monitorUserPassword
  - properties
  - rootUserPassword
  - truststorePwd
  - userStoreCertPwd
- Note: <br/>
  Above list is default for the accelerator. Please updates as required with you bespoke secrets as required.

## **USAGE**

#### [[ CICD ]]
_EXAMPLE COMMANDS (Self Replication)_
```
helm install \
  --kubeconfig "/root/.kube/config" \
  --set userstore.image="gcr.io/massive-dynamo-235117/forgerock-user-store:fr7" \
  --set userstore.podName="forgerock-user-store-blue" \
  --set userstore.serviceName="forgerock-user-store" \
  --set userstore.replicas="2" \
  --set userstore.clusterDomain="cluster.local" \
  --set userstore.basedn="ou=users" \
  --set userstore.load_schema="true" \
  --set userstore.load_dsconfig="false" \
  --set secretsmanager.url="http://104.197.209.36:8200" \
  --set secretsmanager.token="s.0KKo0eJy1PKgqCRZsXCrpbPa" \
  --set secretsmanager.us_path="forgerock/data/sit/user-store" \
  --set secretsmanager.rs_path="" \
  --set userstore.namespace="forgerock" \
  --set userstore.use_javaProps="false" \
  --set userstore.self_replicate="true" \
  --set userstore.rs_svc='' \
  --set userstore.envType="SIT" \
  --set userstore.disable_insecure_comms="true" \
  --namespace forgerock \
  forgerock-user-store user-store/
```

_EXAMPLE COMMANDS (using Replication Server)_
```
helm install \
  --kubeconfig "/root/.kube/config" \
  --set userstore.image="gcr.io/massive-dynamo-235117/forgerock-user-store:fr7" \
  --set userstore.podName="forgerock-user-store-green" \
  --set userstore.serviceName="forgerock-user-store" \
  --set userstore.replicas="2" \
  --set userstore.clusterDomain="cluster.local" \
  --set userstore.basedn="ou=users" \
  --set userstore.load_schema="true" \
  --set userstore.load_dsconfig="true" \
  --set secretsmanager.url="http://104.197.209.36:8200" \
  --set secretsmanager.token="s.0KKo0eJy1PKgqCRZsXCrpbPa" \
  --set secretsmanager.us_path="forgerock/data/sit/user-store" \
  --set secretsmanager.rs_path="forgerock/data/sit/repl-server" \
  --set userstore.namespace="forgerock" \
  --set userstore.use_javaProps="false" \
  --set userstore.self_replicate="false" \
  --set userstore.rs_svc='forgerock-repl-server-blue-0.forgerock-repl-server.forgerock.svc.cluster.local:8989\,forgerock-repl-server-blue-1.forgerock-repl-server.forgerock.svc.cluster.local:8989' \
  --set userstore.envType="SIT" \
  --set userstore.disable_insecure_comms="true" \
  --namespace forgerock \
  forgerock-user-store user-store/
```
