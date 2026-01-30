{{- define "my-app.name" -}}
changedetection
{{- end }}

{{- define "my-app.fullname" -}}
{{ include "my-app.name" . }}-{{ .Release.Name }}
{{- end }}
