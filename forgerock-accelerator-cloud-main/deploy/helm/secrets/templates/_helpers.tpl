# ========================================================================
# MIDSHIPS
# COPYRIGHT 2023

# Legal Notice:
# Installation and use of this script is subject to a license agreement
# with Midships Limited (a company registered in England, under company
# registration number: 11324587). This script cannot be modified or
# shared with another organisation unless approved in writing by Midships
# Limited. You as a user of this script must review, accept and comply
# with the license terms of each downloaded/installed package that is
# referenced by this script. By proceeding with the installation, you are
# accepting the license terms of each package, and acknowledging that your
# use of each package will be subject to its respective license terms.
# For more information visit www.midships.io

# NOTE:
# Don't check this file into source control with any sensitive hard
# coded values.
# ========================================================================
{{/*
Generate self certificates with below predefined keys in yaml:
  SECRET_CERTIFICATE: <public-key-base63-encoded-pep>
  SECRET_CERTIFICATE_KEY: <private-key-base63-encoded-pep>

[ Parameters ]
- .commonName
- .serviceName
*/}}
{{- define "midships.gen-certs" -}}
  {{- $serviceName := (hasKey . "serviceName") | ternary .serviceName "" }}
  {{- $svcCn := (hasKey . "commonName") | ternary .commonName $serviceName }}
  {{- $indxMax := sub (len (splitList " " $serviceName)) 1 }}
  {{- $svcSanAll := list "" | compact }}
  {{- range $idx, $svcName := ( split " " $serviceName ) }}
    {{- $indxCurr := ($idx | replace "_" "") | int64 }}
    {{- $svcFqdn1 := printf "%s.%s.svc.cluster.local" $svcName $.release.Namespace }}
    {{- $svcFqdn2 := printf "*.%s" $svcFqdn1 }}
    {{- $svcSanAll = concat $svcSanAll (list $svcFqdn1 $svcFqdn2 $svcCn "localhost") }}
    {{- if eq ($indxCurr | int64) $indxMax }}
      {{- $cert := genSelfSignedCert $svcCn nil $svcSanAll 3653 }}
  SECRET_CERTIFICATE: {{ $cert.Cert | b64enc | quote }}
  SECRET_CERTIFICATE_KEY: {{ $cert.Key | b64enc | quote }}
    {{- end }}
  {{- end }}
{{- end -}}

{{/*
Generate self certificates with below user specified keys in yaml:
  <user-specified-yaml-key-for-public>: <public-key-base63-encoded-pep>
  <user-specified-yaml-key-for-private>: <private-key-base63-encoded-pep>
[ Parameters ]
- .commonName
- .keyPublicCert
- .keyPrivateCert
*/}}
{{- define "midships.gen-certs-user-keys" -}}
  {{- $svcCn := (hasKey . "commonName") | ternary .commonName "generated.cert.com" }}
  {{- $keyForPublicCert := (hasKey . "keyPublicCert") | ternary .keyPublicCert "incorrect-key-for-cert-pub" }}
  {{- $keyForPrivateCert := (hasKey . "keyPrivateCert") | ternary .keyPrivateCert "incorrect-key-for-cert-pri" }}
  {{- $cert := genSelfSignedCert $svcCn nil nil 3653 }}
  {{ $keyForPublicCert }}: {{ $cert.Cert | b64enc | quote }}
  {{ $keyForPrivateCert }}: {{ $cert.Key | b64enc | quote }}
{{- end -}}