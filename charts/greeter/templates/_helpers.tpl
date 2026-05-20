{{- define "greeter.name" -}}greeter{{- end -}}
{{- define "greeter.fullname" -}}{{ include "greeter.name" . }}{{- end -}}
{{- define "greeter.labels" -}}
app.kubernetes.io/name: {{ include "greeter.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
