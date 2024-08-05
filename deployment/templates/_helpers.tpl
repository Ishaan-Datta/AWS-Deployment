{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "wishlist.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "wishlist.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "wishlist.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Get the application URL
*/}}
{{- if contains "NodePort" .Values.service.type }}
  export NODE_PORT=$(kubectl get --namespace {{ .Release.Namespace }} -o jsonpath="{.spec.ports[0].nodePort}" services {{ template "wishlist.fullname" . }})
  export NODE_IP=$(kubectl get nodes --namespace {{ .Release.Namespace }} -o jsonpath="{.items[0].status.addresses[0].address}")
  echo http://$NODE_IP:$NODE_PORT
{{- else if contains "LoadBalancer" .Values.service.type }}
     NOTE: It may take a few minutes for the LoadBalancer IP to be available.
           You can watch the status of by running 'kubectl get svc -w {{ template "wishlist.fullname" . }}'
  export SERVICE_IP=$(kubectl get svc --namespace {{ .Release.Namespace }} {{ template "wishlist.fullname" . }} -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  echo http://$SERVICE_IP:{{ .Values.service.port }}
{{- else if contains "ClusterIP" .Values.service.type }}
  export POD_NAME=$(kubectl get pods --namespace {{ .Release.Namespace }} -l "app={{ template "wishlist.name" . }},release={{ .Release.Name }}" -o jsonpath="{.items[0].metadata.name}")
  echo "Visit http://127.0.0.1:8080 to use your application"
  kubectl port-forward $POD_NAME 8080:80
{{- end }}

{{/*
This is a comment. It will not appear in the rendered output.

Common labels
*/}}
{{- define "mychart.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name | quote }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
{{- end }}

{{/*
Template to create metadata labels for frontend resources
*/}}
{{- define "mychart.frontend.labels" -}}
app: {{ .Values.frontend.appName | default .Chart.Name | quote }}
{{ include "mychart.labels" . | nindent 2 }}
{{- end }}

{{/*
Template to create metadata labels for backend resources
*/}}
{{- define "mychart.backend.labels" -}}
app: {{ .Values.backend.appName | default .Chart.Name | quote }}
{{ include "mychart.labels" . | nindent 2 }}
{{- end }}


{{/*
Common labels
*/}}
{{- define "mychart.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name | quote }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
{{- end }}

{{/*
Template to create metadata labels for frontend resources
*/}}
{{- define "mychart.frontend.labels" -}}
app: {{ .Values.frontend.appName | default .Chart.Name | quote }}
{{ include "mychart.labels" . | nindent 2 }}
{{- end }}

{{/*
Template to create metadata labels for backend resources
*/}}
{{- define "mychart.backend.labels" -}}
app: {{ .Values.backend.appName | default .Chart.Name | quote }}
{{ include "mychart.labels" . | nindent 2 }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mychart.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name | quote }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
{{- end }}

{{/*
Template to create metadata labels for frontend resources
*/}}
{{- define "mychart.frontend.labels" -}}
app: {{ .Values.frontend.appName | default .Chart.Name | quote }}
{{ include "mychart.labels" . | nindent 2 }}
{{- end }}

{{/*
Template to create metadata labels for backend resources
*/}}
{{- define "mychart.backend.labels" -}}
app: {{ .Values.backend.appName | default .Chart.Name | quote }}
{{ include "mychart.labels" . | nindent 2 }}
{{- end }}

http://127.0.0.1:8080