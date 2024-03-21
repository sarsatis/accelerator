# **SUMMARY**

This folder contains the Hellm Chart for deploying the ForgeRock `Token Store` component.

## **PREREQUISITE**

#### [[ Secrets Manager ]]
- Ensure the secrets are accessible from via CICD server or Kubernetes cluster deplending on you secrets deployment methodology.
- The below secrets must exists. Speak with a Midships technical consultant for clarification if you have any queries:
  - amCtsAdminPassword
  - certificate
  - certificateKey
  - deploymentKey
  - javaProperties
  - monitorUserPassword
  - properties
  - rootUserPassword
  - tokenStoreCertPwd
  - truststorePwd
- Note: <br/>
  Above list is default for the accelerator. Please updates as required with you bespoke secrets as required.

## **USAGE**

#### [[ CICD ]]
_EXAMPLE COMMANDS (Self Replication)_
```
helm install \
  --kubeconfig "/root/.kube/config" \
  --set tokenstore.image="gcr.io/massive-dynamo-235117/forgerock-token-store:fr7" \
  --set tokenstore.podName="forgerock-token-store-blue" \
  --set tokenstore.serviceName="forgerock-token-store" \
  --set tokenstore.clusterDomain="cluster.local" \
  --set tokenstore.replicas="2" \
  --set tokenstore.basedn="ou=tokens" \
  --set tokenstore.self_replicate="true" \
  --set tokenstore.use_javaProps="false" \
  --set tokenstore.envType="SIT" \
  --set tokenstore.disable_insecure_comms="true" \
  --set secretsmanager.url="http://104.197.209.36:8200" \
  --set secretsmanager.token="s.0KKo0eJy1PKgqCRZsXCrpbPa" \
  --set secretsmanager.ts_path="forgerock/data/sit/token-store" \
  --set secretsmanager.rs_path="" \
  --set tokenstore.rs_svc='' \
  --namespace forgerock \
  forgerock-token-store token-store/
```

_EXAMPLE COMMANDS (using Replication Server)_
```
helm install \
  --kubeconfig "/root/.kube/config" \
  --set tokenstore.image="gcr.io/massive-dynamo-235117/forgerock-token-store:fr7" \
  --set tokenstore.podName="forgerock-token-store-green" \
  --set tokenstore.serviceName="forgerock-token-store" \
  --set tokenstore.clusterDomain="cluster.local" \
  --set tokenstore.replicas="2" \
  --set tokenstore.basedn="ou=tokens" \
  --set tokenstore.self_replicate="false" \
  --set tokenstore.use_javaProps="false" \
  --set tokenstore.envType="SIT" \
  --set tokenstore.disable_insecure_comms="true" \
  --set secretsmanager.url="http://104.197.209.36:8200" \
  --set secretsmanager.token="s.0KKo0eJy1PKgqCRZsXCrpbPa" \
  --set secretsmanager.ts_path="forgerock/data/sit/token-store" \
  --set secretsmanager.rs_path="forgerock/data/sit/repl-server" \
  --set tokenstore.rs_svc='forgerock-repl-server-blue-0.forgerock-repl-server.forgerock.svc.cluster.local:8989\,forgerock-repl-server-blue-1.forgerock-repl-server.forgerock.svc.cluster.local:8989' \
  --namespace forgerock \
  forgerock-token-store token-store/
```
