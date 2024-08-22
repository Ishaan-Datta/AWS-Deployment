{{/*
Conditional Logic Section
*/}}

{{- define "AWS-Deployment-Chart.frontendtype" }}
{{- if and .Values.deployment.localTesting (not .Values.deployment.ingressEnabled) }}
    type: NodePort
{{- else if and (not .Values.deployment.localTesting) (not .Values.deployment.ingressEnabled) }}
    type: LoadBalancer
{{- else }}
    type: ClusterIP
{{- end }}
{{- end }}

{{/*
Change bottom to .cloud_tag when done testing
*/}}

{{- define "AWS-Deployment-Chart.userdbImage" }}
{{- if .Values.deployment.localTesting }}
        image: "{{ .Values.userdatabase.image.repository }}:{{ .Values.userdatabase.image.local_tag }}"
{{- else }}
        image: "{{ .Values.userdatabase.image.repository }}:{{ .Values.userdatabase.image.local_tag }}"
{{- end }}
{{- end }}

{{/*
Expand the name of the chart.
*/}}
{{- define "AWS-Deployment-Chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "AWS-Deployment-Chart.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "AWS-Deployment-Chart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "AWS-Deployment-Chart.labels" -}}
helm.sh/chart: {{ include "AWS-Deployment-Chart.chart" . }}
{{ include "AWS-Deployment-Chart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "AWS-Deployment-Chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "AWS-Deployment-Chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "AWS-Deployment-Chart.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "AWS-Deployment-Chart.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

