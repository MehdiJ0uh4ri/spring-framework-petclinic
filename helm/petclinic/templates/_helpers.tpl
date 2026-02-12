{{- define "petclinic.name" -}}
{{- default .Chart.Name .Values.nameOverride -}}
{{- end -}}

{{- define "petclinic.fullname" -}}
{{- printf "%s" (include "petclinic.name" .) -}}
{{- end -}}
