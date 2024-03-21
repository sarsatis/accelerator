# **SUMMARY**

This folder contains the Helm chart for deploying the ForgeRock `Configuration Store` component.

## **PREREQUISITE**

#### [[ Secrets Manager ]]
- Ensure the secrets are accessible from via CICD server or Kubernetes cluster deplending on you secrets deployment methodology.
- The below secrets must exists. Speak with a Midships technical consultant for clarification if you have any queries:
  - amConfigAdminPassword
  - certificate
  - certificateKey
  - configStoreCertPwd
  - deploymentKey
  - javaProperties
  - monitorUserPassword
  - properties
  - rootUserPassword
  - truststorePwd
- Note: <br/>
  Above list is default for the accelerator. Please updates as required with you bespoke secrets as required.

## **USAGE**

#### [[ CICD ]]
_EXAMPLE COMMANDS (Self Replication)_
```
helm install \
  --kubeconfig "/root/.kube/config" \
  --set configstore.image="gcr.io/massive-dynamo-235117/forgerock-app-policy-store:fr7" \
  --set configstore.podName="forgerock-app-policy-store-blue" \
  --set configstore.serviceName="forgerock-app-policy-store" \
  --set configstore.replicas="2" \
  --set configstore.clusterDomain="cluster.local" \
  --set configstore.basedn="ou=users" \
  --set configstore.load_schema="true" \
  --set configstore.load_dsconfig="false" \
  --set secretsmanager.url="http://104.197.209.36:8200" \
  --set secretsmanager.token="s.0KKo0eJy1PKgqCRZsXCrpbPa" \
  --set secretsmanager.us_path="forgerock/data/sit/config-store" \
  --set secretsmanager.rs_path="" \
  --set configstore.namespace="forgerock" \
  --set configstore.use_javaProps="false" \
  --set configstore.self_replicate="true" \
  --set configstore.rs_svc='' \
  --set configstore.envType="SIT" \
  --set configstore.disable_insecure_comms="true" \
  --namespace forgerock \
  forgerock-app-policy-store config-store/
```

_EXAMPLE COMMANDS (using Replication Server)_
```
helm install \
  --kubeconfig "/root/.kube/config" \
  --set configstore.image="gcr.io/massive-dynamo-235117/forgerock-app-policy-store:fr7" \
  --set configstore.podName="forgerock-app-policy-store-green" \
  --set configstore.serviceName="forgerock-app-policy-store" \
  --set configstore.replicas="2" \
  --set configstore.clusterDomain="cluster.local" \
  --set configstore.basedn="ou=users" \
  --set secretsmanager.url="http://104.197.209.36:8200" \
  --set secretsmanager.token="s.0KKo0eJy1PKgqCRZsXCrpbPa" \
  --set secretsmanager.aps_path="forgerock/data/sit/config-store" \
  --set secretsmanager.rs_path="forgerock/data/sit/repl-server" \
  --set configstore.namespace="forgerock" \
  --set configstore.use_javaProps="false" \
  --set configstore.self_replicate="false" \
  --set configstore.rs_svc='forgerock-repl-server-blue-0.forgerock-repl-server.forgerock.svc.cluster.local:8989\,forgerock-repl-server-blue-1.forgerock-repl-server.forgerock.svc.cluster.local:8989' \
  --set configstore.envType="SIT" \
  --set configstore.disable_insecure_comms="true" \
  --namespace forgerock \
  forgerock-app-policy-store config-store/
```
