{{- define "agribridge.image" -}}
{{- if .settings.digest -}}
{{- if not (regexMatch "^sha256:[a-f0-9]{64}$" .settings.digest) -}}
{{- fail "image digest must be a sha256 digest" -}}
{{- end -}}
{{- printf "%s@%s" .settings.repository .settings.digest -}}
{{- else -}}
{{- if .requireDigest -}}{{- fail "GitOps releases require published image digests" -}}{{- end -}}
{{- printf "%s:%s" .settings.repository .settings.tag -}}
{{- end -}}
{{- end -}}
