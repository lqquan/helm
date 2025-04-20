{{- define "mychart.password.with.cache" -}}
  {{- if not (index .Values "generatedPassword") -}}
    {{- $_ := set .Values "generatedPassword" (randAlphaNum 12) -}}
  {{- end -}}
  {{- .Values.generatedPassword -}}
{{- end -}}
