{{- define "agribridge.image" -}}
{{- printf "%s:%s" .repository .tag -}}
{{- end -}}
