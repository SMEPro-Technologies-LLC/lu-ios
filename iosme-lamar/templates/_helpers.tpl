{{/*
=============================================================================
_helpers.tpl — Common template helpers for iosme-lamar
=============================================================================
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "iosme-lamar.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this
(by the DNS naming spec).
*/}}
{{- define "iosme-lamar.fullname" -}}
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
Create chart label (chart name + version).
*/}}
{{- define "iosme-lamar.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels applied to all resources.
*/}}
{{- define "iosme-lamar.labels" -}}
helm.sh/chart: {{ include "iosme-lamar.chart" . }}
{{ include "iosme-lamar.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
compliance.lamar.edu/scope: {{ .Values.compliance.scope | default "education-only" | quote }}
{{- end }}

{{/*
Selector labels (used in matchLabels — must be stable across upgrades).
*/}}
{{- define "iosme-lamar.selectorLabels" -}}
app.kubernetes.io/name: {{ include "iosme-lamar.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Resolve the ServiceAccount name to use for all pods.
*/}}
{{- define "iosme-lamar.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "iosme-lamar.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
