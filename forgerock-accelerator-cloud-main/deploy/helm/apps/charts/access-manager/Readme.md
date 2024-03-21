# **SUMMARY**

This folder contains the Helm chart for deploying ForgeRock `Access Manager` component.

## **PREREQUISITE**

#### [[ Secrets Manager ]]
- Ensure the secrets are accessible from via CICD server or Kubernetes cluster deplending on you secrets deployment methodology.
- The below secrets must exists. Speak with a Midships technical consultant for clarification if you have any queries:
  - tomcatJKSPwd
  - amAdminPwd
  - cfgStoreDirMgrPwd
  - userStoreDirMgrPwd
  - truststorePwd
  - amPwdEncKey
  - certificate
  - certificateKey
  - cert_es256
  - cert_es256Key
  - cert_es384
  - cert_es384Key
  - cert_es512
  - cert_es512Key
  - cert_general
  - cert_generalKey
  - cert_rsajwtsign
  - cert_rsajwtsignKey
  - cert_selfserviceenc
  - cert_selfserviceenckey
  - enckey_AmPwd
  - enckey_directenc
  - enckey_hmacsign
  - enckey_selfservicesign
- Note: <br/>
  Above list is default for the accelerator. Please updates as required with you bespoke secrets as required.

## **USAGE**

#### [[ CICD ]]
_EXAMPLE COMMANDS (with Application Policy Store (APS) Self Replication)_
```
helm install \
  --kubeconfig "/root/.kube/config" \
  --set am.replicas="2" \
  --set am.podName="forgerock-access-manager-gcp" \
  --set am.serviceName="forgerock-access-manager" \
  --set configstore.podName="forgerock-app-policy-store" \
  --set configstore.use_javaProps="false" \
  --set configstore.self_replicate="true" \
  --set configstore.envType="SIT" \
  --set configstore.clusterDomain="cluster.local" \
  --set configstore.basedn="ou=am-config" \
  --set configstore.disable_insecure_comms="false" \
  --set configstore.rs_svc='' \
  --set configstore.image="gcr.io/massive-dynamo-235117/forgerock-app-policy-store:fr7" \
  --set am.image="gcr.io/massive-dynamo-235117/forgerock-access-manager:fr7" \
  --set secretsmanager.url="http://104.197.209.36:8200" \
  --set secretsmanager.token="s.0KKo0eJy1PKgqCRZsXCrpbPa" \
  --set secretsmanager.am_path="forgerock/data/sit/access-manager" \
  --set secretsmanager.aps_path="forgerock/data/sit/config-store" \
  --set secretsmanager.ts_path="forgerock/data/sit/token-store" \
  --set secretsmanager.us_path="forgerock/data/sit/user-store" \
  --set secretsmanager.rs_path="" \
  --set am.namespace="forgerock" \
  --set am.envType="SIT" \
  --set am.cookieName="iPlanetDirectoryPro" \
  --set am.lbDomain="am.d2portal.co.uk" \
  --set am.secretsmanager_client_path_runtime_am="forgerock/data/sit/runtime/access-manager" \
  --set am.cs_k8s_svc_url="cs.forgerock-access-manager.forgerock.svc.cluster.local" \
  --set am.us_k8s_svc_url="forgerock-user-store.forgerock.svc.cluster.local" \
  --set am.ts_k8s_svc_url="forgerock-token-store.forgerock.svc.cluster.local" \
  --set am.goto_urls='"https://url1.com/*"' \
  --set am.us_connstring_affinity='"forgerock-user-store-gcp-0.forgerock-user-store.forgerock.svc.cluster.local:1636"\,"forgerock-user-store-gcp-1.forgerock-user-store.forgerock.svc.cluster.local:1636"' \
  --set am.ps_connstring_affinity='forgerock-policy-store.forgerock.svc.cluster.local:1636' \
  --set am.ts_connstring_affinity='forgerock-token-store-gcp-0.forgerock-token-store.forgerock.svc.cluster.local:1636\,forgerock-token-store-gcp-1.forgerock-token-store.forgerock.svc.cluster.local:1636' \
  --set am.amster_files="amster_DefaultCtsDataStoreProperties\,amster_DefaultSecurityProperties\,amster_platform\,amster_AuthenticationGlobal\,amster_IdStore_OpenDJ\,amster_realm_customers\,amster_realm_internals" \
  --set am.auth_trees="authTrees_customers_register\,authTrees_customers_stepup\,authTrees_customers_login" \
  --namespace forgerock \
  forgerock-access-manager access-manager/
```

_EXAMPLE COMMANDS (with Replication Server)_
```
helm install \
  --kubeconfig "/root/.kube/config" \
  --set am.replicas="2" \
  --set am.podName="forgerock-access-manager-gcp" \
  --set am.serviceName="forgerock-access-manager" \
  --set configstore.podName="forgerock-app-policy-store" \
  --set configstore.use_javaProps="false" \
  --set configstore.self_replicate="false" \
  --set configstore.envType="SIT" \
  --set configstore.clusterDomain="cluster.local" \
  --set configstore.basedn="ou=am-config" \
  --set configstore.disable_insecure_comms="false" \
  --set configstore.rs_svc='forgerock-repl-server-gcp-0.forgerock-repl-server.forgerock.svc.cluster.local:8989\,forgerock-repl-server-gcp-1.forgerock-repl-server.forgerock.svc.cluster.local:8989' \
  --set configstore.image="gcr.io/massive-dynamo-235117/forgerock-app-policy-store:fr7" \
  --set am.image="gcr.io/massive-dynamo-235117/forgerock-access-manager:fr7" \
  --set secretsmanager.url="http://104.197.209.36:8200" \
  --set secretsmanager.token="s.0KKo0eJy1PKgqCRZsXCrpbPa" \
  --set secretsmanager.am_path="forgerock/data/sit/access-manager" \
  --set secretsmanager.aps_path="forgerock/data/sit/config-store" \
  --set secretsmanager.ts_path="forgerock/data/sit/token-store" \
  --set secretsmanager.us_path="forgerock/data/sit/user-store" \
  --set secretsmanager.rs_path="forgerock/data/sit/repl-server" \
  --set am.namespace="forgerock" \
  --set am.envType="SIT" \
  --set am.cookieName="iPlanetDirectoryPro" \
  --set am.lbDomain="am.d2portal.co.uk" \
  --set am.secretsmanager_client_path_runtime_am="forgerock/data/sit/runtime/access-manager" \
  --set am.cs_k8s_svc_url="cs.forgerock-access-manager.forgerock.svc.cluster.local" \
  --set am.us_k8s_svc_url="forgerock-user-store.forgerock.svc.cluster.local" \
  --set am.ts_k8s_svc_url="forgerock-token-store.forgerock.svc.cluster.local" \
  --set am.goto_urls='"https://url1.com/*"' \
  --set am.us_connstring_affinity='"forgerock-user-store-gcp-0.forgerock-user-store.forgerock.svc.cluster.local:1636"\,"forgerock-user-store-gcp-1.forgerock-user-store.forgerock.svc.cluster.local:1636"' \
  --set am.ps_connstring_affinity='forgerock-policy-store.forgerock.svc.cluster.local:1636' \
  --set am.ts_connstring_affinity='forgerock-token-store-gcp-0.forgerock-token-store.forgerock.svc.cluster.local:1636\,forgerock-token-store-gcp-1.forgerock-token-store.forgerock.svc.cluster.local:1636' \
  --set am.amster_files="amster_DefaultCtsDataStoreProperties\,amster_DefaultSecurityProperties\,amster_platform\,amster_AuthenticationGlobal\,amster_IdStore_OpenDJ\,amster_realm_customers\,amster_realm_internals" \
  --set am.auth_trees="authTrees_customers_register\,authTrees_customers_stepup\,authTrees_customers_login" \
    --set am.log_mode="stdout" \
  --namespace forgerock \
  forgerock-access-manager access-manager/
```
