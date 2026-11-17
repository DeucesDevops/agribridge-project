{{- define "agribridge.workload" -}}
{{- $component := .component }}
{{- with .root }}
{{- $settings := index .Values $component }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-{{ $component }}
spec:
  replicas: {{ $settings.replicas }}
  revisionHistoryLimit: 5
  selector:
    matchLabels:
      app: {{ .Release.Name }}-{{ $component }}
  strategy:
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}-{{ $component }}
      annotations:
        checksum/config: {{ include (print .Template.BasePath "/config.yaml") . | sha256sum }}
    spec:
      serviceAccountName: {{ .Release.Name }}
      automountServiceAccountToken: false
      terminationGracePeriodSeconds: 40
      securityContext:
        runAsNonRoot: true
        {{- if eq $component "web" }}
        runAsUser: 101
        runAsGroup: 101
        fsGroup: 101
        {{- else }}
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        {{- end }}
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: {{ $component }}
          image: {{ include "agribridge.image" $settings | quote }}
          imagePullPolicy: IfNotPresent
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          ports:
            - name: http
              containerPort: {{ if eq $component "api" }}3000{{ else }}8080{{ end }}
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: "1"
              memory: 512Mi
          {{- if eq $component "api" }}
          envFrom:
            - configMapRef:
                name: {{ .Release.Name }}-config
            - secretRef:
                name: {{ .Release.Name }}-runtime
          startupProbe:
            httpGet:
              path: /healthz
              port: http
            periodSeconds: 5
            failureThreshold: 60
          readinessProbe:
            httpGet:
              path: /readyz
              port: http
            periodSeconds: 10
          volumeMounts:
            - name: tmp
              mountPath: /tmp
          {{- else }}
          env:
            - name: API_UPSTREAM
              value: {{ .Release.Name }}-api:3000
          readinessProbe:
            httpGet:
              path: /healthz
              port: http
          volumeMounts:
            - name: tmp
              mountPath: /tmp
            - name: nginx-config
              mountPath: /etc/nginx/conf.d
          {{- end }}
          livenessProbe:
            httpGet:
              path: /healthz
              port: http
            periodSeconds: 10
          lifecycle:
            preStop:
              exec:
                command: ["/bin/sh", "-c", "sleep 5"]
      volumes:
        - name: tmp
          emptyDir: {}
        {{- if eq $component "web" }}
        - name: nginx-config
          emptyDir: {}
        {{- end }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}-{{ $component }}
  labels:
    app: {{ .Release.Name }}-{{ $component }}
spec:
  selector:
    app: {{ .Release.Name }}-{{ $component }}
  ports:
    - name: http
      port: {{ if eq $component "api" }}3000{{ else }}8080{{ end }}
      targetPort: http
{{- end }}
{{- end }}
