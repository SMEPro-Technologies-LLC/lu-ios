# IOS+ Lamar Edition — Helm Chart Production Artifact

**Document:** SME-IOS-LU-HELM-PROD-001  
**Artifact:** Helm chart (`iosme-lamar-1.0.0.tgz`) — the sole production deployment artifact per §08 Kubernetes Delivery clause  
**Target:** RKE2 / vanilla Kubernetes on RHEL 9 (VMware vSphere)  
**Namespace:** `iosme`  
**Reference:** SME-IOS-LU-FINAL-001 §01.3 Production Deliverable: Helm Chart, §08 Contract Clauses (Kubernetes delivery, Infrastructure cap, Open exit, Banner integrity, Copilot audit-only, Blockchain disabled, Audit chain DR, Embedding store classification)

---

## 1. Artifact Integrity & Delivery

Per §08 Open Exit clause: **All source code, manifests, configuration, and documentation transferred to Lamar at each stage gate.** This Helm chart is the operational artifact. No vendor-proprietary lock-in.

| Property | Value |
|----------|-------|
| Chart Name | `iosme-lamar` |
| Chart Version | `1.0.0` |
| App Version | `iosme-v1.0.0` |
| Repository | `https://github.com/Lamar-University/iosme-charts` (transferred at Phase 1) |
| Packaging | `helm package iosme-lamar` → `iosme-lamar-1.0.0.tgz` |
| Signature | Cosign / GPG signed by SMEPro release key; public key transferred to Lamar GitHub |
| Values Files | `values-lamar-prod.yaml` (production overrides), `values-lamar-dev.yaml` (development) |

---

## 2. Chart Directory Structure

```
iosme-lamar/
├── Chart.yaml
├── values.yaml                     # Default (reference only — DO NOT USE IN PROD)
├── values-lamar-prod.yaml          # Lamar production overrides
├── values-lamar-dev.yaml           # Lamar development overrides
├── README.md                       # Operational runbook
├── templates/
│   ├── _helpers.tpl                # Common labels, selectors, naming
│   ├── namespace.yaml              # iosme namespace creation
│   ├── configmap.yaml              # Feature flags, governance thresholds, crypto config
│   ├── secret.yaml                 # TEMPLATE — references External Secrets Operator / Vault
│   ├── api-deployment.yaml         # API Gateway + Policy Engine (2 replicas)
│   ├── api-service.yaml            # ClusterIP for API pods
│   ├── worker-deployment.yaml      # Celery worker pool (2 replicas)
│   ├── postgres-statefulset.yaml   # PostgreSQL 15 primary (db-01) + replica (db-02)
│   ├── postgres-service.yaml       # Headless + ClusterIP services
│   ├── redis-deployment.yaml       # Redis 7 shared cache / queue
│   ├── redis-service.yaml          # ClusterIP for Redis
│   ├── ingress.yaml                # NGINX Ingress Controller + TLS 1.3 + cert-manager
│   ├── hpa.yaml                    # HorizontalPodAutoscaler (optional, disabled by default)
│   ├── lti-service-deployment.yaml # LTI 1.3 Tool Provider service
│   ├── lti-service-service.yaml    # ClusterIP for LTI
│   ├── network-policies.yaml       # Banner replica isolation, Anthropic egress rules
│   ├── serviceaccount.yaml         # RBAC service account with minimal permissions
│   ├── rbac.yaml                   # Role + RoleBinding (namespace-scoped)
│   ├── pdb.yaml                    # PodDisruptionBudget (1 per deployment)
│   └── migrations-job.yaml         # Alembic post-install hook (weight -5)
├── crds/                           # Empty — no custom CRDs required at this version
└── charts/                         # Subchart dependencies (if any; empty for v1.0.0)
```

---

## 3. Manifest Specifications (Production-Ready)

### 3.1 namespace.yaml + ConfigMap

```yaml
# templates/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: {{ .Values.namespace }}
  labels:
    app.kubernetes.io/name: {{ include "iosme-lamar.name" . }}
    app.kubernetes.io/instance: {{ .Release.Name }}
    app.kubernetes.io/managed-by: {{ .Release.Service }}
    compliance.lamar.edu/scope: education-only
    compliance.lamar.edu/regimes: FERPA,SACSCOC,TitleIX,ADA508,TexasEdCode,AACSB,ABET

---
# templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: iosme-config
  namespace: {{ .Values.namespace }}
data:
  # === Feature Flags (per §08 Blockchain disabled clause) ===
  IOS_FEATURE_ENABLE_PRECOGNITION: "true"
  IOS_FEATURE_ENABLE_MAC: "true"
  IOS_FEATURE_ENABLE_COMPLIANCE: "true"
  IOS_FEATURE_ENABLE_SIMULATION: "true"
  IOS_FEATURE_ENABLE_OBSERVABILITY: "true"
  IOS_FEATURE_ENABLE_BLOCKCHAIN_ANCHOR: "false"   # §08: NEVER true without Provost CR
  
  # === Governance Thresholds ===
  GOVERNANCE_SCORE_THRESHOLD: "0.75"
  SAFE_AI_LADDER_CLEAR_THRESHOLD: "0"
  SAFE_AI_LADDER_WARNING_THRESHOLD: "3"
  SAFE_AI_LADDER_ADVISORY_THRESHOLD: "5"
  SAFE_AI_LADDER_TIMEOUT_THRESHOLD: "8"
  SAFE_AI_LADDER_BAN_THRESHOLD: "10"
  SAFE_AI_LADDER_WINDOW_MINUTES: "5"
  
  # === Cryptographic Config (§08 Audit chain DR) ===
  AUDIT_HASH_ALGORITHM: "SHA-256"
  AUDIT_SIGNATURE_ALGORITHM: "ECDSA-secp256k1"
  AUDIT_RETENTION_YEARS: "7"
  AUDIT_MERKLE_ROLLUP_INTERVAL_MINUTES: "5"
  
  # === Embedding Store Classification (§08) ===
  EMBEDDING_CLASSIFICATION: "PII-equivalent"
  EMBEDDING_ENCRYPTION_AT_REST: "true"
  EMBEDDING_ACCESS_LOGGED: "true"
  EMBEDDING_EXTERNAL_RETRIEVAL: "false"
  
  # === Routing ===
  API_BASE_PATH: "/v1/ai"
  LTI_PROVIDER_PATH: "/lti/v1p3/launch"
  
  # === Banner Integrity (§08) ===
  BANNER_DIRECT_MUTATION: "false"   # Hard guard — must be false in production
  BANNER_WRITEBACK_CHANNEL: "ethos"  # All writes via Ellucian Ethos API
  BANNER_HITL_APPROVAL_REQUIRED: "true"
  BANNER_TRACEID_REQUIRED: "true"
  BANNER_REPLICA_TABLES: "course_catalog,curriculum,program_affiliation,cip_codes"
  
  # === Copilot Audit-Only (§08) ===
  COPILOT_INTERCEPTION_ENABLED: "false"   # Must NEVER be true
  COPILOT_AUDIT_MODE: "post-execution"
  COPILOT_AUDIT_SOURCE: "graph-purview"
  
  # === Compliance Scope (§08 Education-only) ===
  UCO_VERTICAL_SCOPE: "education"
  UCO_ACTIVE_REGIMES: "FERPA,SACSCOC,TitleIV,TitleIX,ADA508,TexasEdCode,AACSB,ABET"
  UCO_RULE_COUNT: "35"
  
  # === Database ===
  POSTGRES_VERSION: "15"
  POSTGRES_DB: "iosme_uco"
  POSTGRES_REPLICATION_MODE: "streaming"
  
  # === Redis ===
  REDIS_VERSION: "7"
  REDIS_AOF_ENABLED: "true"
  REDIS_MAX_MEMORY_MB: "512"
  REDIS_MAX_MEMORY_POLICY: "allkeys-lru"
```

### 3.2 api-deployment.yaml

```yaml
# templates/api-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "iosme-lamar.fullname" . }}-api
  namespace: {{ .Values.namespace }}
  labels:
    app.kubernetes.io/component: api
    compliance.lamar.edu/data-classification: restricted
spec:
  replicas: {{ .Values.api.replicas }}  # Default: 2 (§01.3)
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app.kubernetes.io/component: api
  template:
    metadata:
      labels:
        app.kubernetes.io/component: api
    spec:
      serviceAccountName: {{ include "iosme-lamar.serviceAccountName" . }}
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchExpressions:
                  - key: app.kubernetes.io/component
                    operator: In
                    values:
                      - api
              topologyKey: kubernetes.io/hostname
      containers:
        - name: api
          image: "{{ .Values.api.image.repository }}:{{ .Values.api.image.tag }}"
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 8000
              protocol: TCP
          command: ["uvicorn"]
          args: ["app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
          envFrom:
            - configMapRef:
                name: iosme-config
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: iosme-db-credentials
                  key: url
            - name: REDIS_URL
              valueFrom:
                secretKeyRef:
                  name: iosme-redis-credentials
                  key: url
            - name: ANTHROPIC_API_KEY
              valueFrom:
                secretKeyRef:
                  name: iosme-anthropic-api-key
                  key: token
            - name: BANNER_ETHOS_API_KEY
              valueFrom:
                secretKeyRef:
                  name: iosme-banner-credentials
                  key: ethos-api-key
            - name: LTI_JWS_PRIVATE_KEY
              valueFrom:
                secretKeyRef:
                  name: iosme-lti-keypair
                  key: private-key
            - name: VAULT_ADDR
              valueFrom:
                secretKeyRef:
                  name: iosme-vault-config
                  key: addr
          resources:
            requests:
              cpu: "1"
              memory: "1Gi"
            limits:
              cpu: "2"
              memory: "2Gi"
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /health/ready
              port: http
            initialDelaySeconds: 5
            periodSeconds: 5
            failureThreshold: 3
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}
```

### 3.3 worker-deployment.yaml

```yaml
# templates/worker-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "iosme-lamar.fullname" . }}-worker
  namespace: {{ .Values.namespace }}
  labels:
    app.kubernetes.io/component: worker
spec:
  replicas: {{ .Values.worker.replicas }}  # Default: 2
  selector:
    matchLabels:
      app.kubernetes.io/component: worker
  template:
    metadata:
      labels:
        app.kubernetes.io/component: worker
    spec:
      serviceAccountName: {{ include "iosme-lamar.serviceAccountName" . }}
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
      containers:
        - name: worker
          image: "{{ .Values.worker.image.repository }}:{{ .Values.worker.image.tag }}"
          imagePullPolicy: IfNotPresent
          command: ["celery"]
          args: ["-A", "app.celery_app", "worker", "--concurrency=4", "--loglevel=info"]
          envFrom:
            - configMapRef:
                name: iosme-config
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: iosme-db-credentials
                  key: url
            - name: REDIS_URL
              valueFrom:
                secretKeyRef:
                  name: iosme-redis-credentials
                  key: url
            - name: ANTHROPIC_API_KEY
              valueFrom:
                secretKeyRef:
                  name: iosme-anthropic-api-key
                  key: token
          resources:
            requests:
              cpu: "0.5"
              memory: "512Mi"
            limits:
              cpu: "1"
              memory: "1Gi"
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}
```

### 3.4 postgres-statefulset.yaml

```yaml
# templates/postgres-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ include "iosme-lamar.fullname" . }}-postgres
  namespace: {{ .Values.namespace }}
  labels:
    app.kubernetes.io/component: database
    compliance.lamar.edu/data-classification: critical
spec:
  serviceName: {{ include "iosme-lamar.fullname" . }}-postgres-headless
  replicas: 2  # Primary + Replica
  selector:
    matchLabels:
      app.kubernetes.io/component: database
  template:
    metadata:
      labels:
        app.kubernetes.io/component: database
    spec:
      serviceAccountName: {{ include "iosme-lamar.serviceAccountName" . }}
      nodeSelector:
        node-role.kubernetes.io/db: "true"  # Pinned to db-01 / db-02 VMs
      tolerations:
        - key: node-role.kubernetes.io/db
          operator: Equal
          value: "true"
          effect: NoSchedule
      securityContext:
        runAsNonRoot: true
        runAsUser: 999  # postgres UID
        fsGroup: 999
      containers:
        - name: postgres
          image: postgres:15-alpine
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 5432
              name: postgres
          env:
            - name: POSTGRES_DB
              valueFrom:
                configMapKeyRef:
                  name: iosme-config
                  key: POSTGRES_DB
            - name: POSTGRES_USER
              valueFrom:
                secretKeyRef:
                  name: iosme-db-credentials
                  key: username
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: iosme-db-credentials
                  key: password
            - name: PGDATA
              value: /var/lib/postgresql/data/pgdata
            - name: POSTGRES_REPLICA
              value: "true"  # Secondary pod; primary pod configured via init logic
          resources:
            requests:
              cpu: "4"
              memory: "8Gi"
            limits:
              cpu: "8"
              memory: "16Gi"
          livenessProbe:
            exec:
              command: ["pg_isready", "-U", "postgres"]
            initialDelaySeconds: 60
            periodSeconds: 10
            failureThreshold: 3
          readinessProbe:
            exec:
              command: ["pg_isready", "-U", "postgres"]
            initialDelaySeconds: 10
            periodSeconds: 5
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: {{ .Values.postgres.storageClass }}  # ios-san-fast
        resources:
          requests:
            storage: {{ .Values.postgres.storageSize }}  # 2 Ti for primary, 4 Ti for replica
```

**Note:** The StatefulSet uses an init container or operator pattern to distinguish primary (db-01) from replica (db-02). For production, a **PostgreSQL Operator** (e.g., Zalando, CloudNativePG) is recommended over raw StatefulSet. SMEPro provides the raw StatefulSet as the minimum viable artifact; operator migration is a Year 2 enhancement.

### 3.5 redis-deployment.yaml

```yaml
# templates/redis-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "iosme-lamar.fullname" . }}-redis
  namespace: {{ .Values.namespace }}
  labels:
    app.kubernetes.io/component: cache
spec:
  replicas: 1  # Single instance with AOF persistence; sentinel/cluster for HA in Year 2
  selector:
    matchLabels:
      app.kubernetes.io/component: cache
  template:
    metadata:
      labels:
        app.kubernetes.io/component: cache
    spec:
      containers:
        - name: redis
          image: redis:7-alpine
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 6379
              name: redis
          command: ["redis-server"]
          args:
            - "--appendonly yes"
            - "--maxmemory 512mb"
            - "--maxmemory-policy allkeys-lru"
          resources:
            requests:
              cpu: "0.25"
              memory: "512Mi"
            limits:
              cpu: "0.5"
              memory: "512Mi"
          livenessProbe:
            exec:
              command: ["redis-cli", "ping"]
            periodSeconds: 10
          readinessProbe:
            exec:
              command: ["redis-cli", "ping"]
            periodSeconds: 5
```

### 3.6 ingress.yaml + cert-manager

```yaml
# templates/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "iosme-lamar.fullname" . }}-ingress
  namespace: {{ .Values.namespace }}
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"
    cert-manager.io/cluster-issuer: "lamar-letsencrypt-prod"  # Or Lamar's internal CA issuer
    cert-manager.io/acme-challenge-type: "http01"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - {{ .Values.ingress.host }}
      secretName: iosme-tls-cert
  rules:
    - host: {{ .Values.ingress.host }}
      http:
        paths:
          - path: /v1/ai
            pathType: Prefix
            backend:
              service:
                name: {{ include "iosme-lamar.fullname" . }}-api
                port:
                  number: 8000
          - path: /lti/v1p3/launch
            pathType: Prefix
            backend:
              service:
                name: {{ include "iosme-lamar.fullname" . }}-lti-service
                port:
                  number: 8080
          - path: /health
            pathType: Prefix
            backend:
              service:
                name: {{ include "iosme-lamar.fullname" . }}-api
                port:
                  number: 8000
```

**cert-manager ClusterIssuer:**

```yaml
# Deployed separately by ITIS or SMEPro during Phase 1
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: lamar-letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: itis-ssl@lamar.edu
    privateKeySecretRef:
      name: lamar-letsencrypt-key
    solvers:
      - http01:
          ingress:
            class: nginx
```

**Alternative:** If Lamar uses an internal CA (e.g., Microsoft AD CS), cert-manager can be configured with a CA Issuer instead of Let's Encrypt.

### 3.7 migrations-job.yaml

```yaml
# templates/migrations-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "iosme-lamar.fullname" . }}-migrations
  namespace: {{ .Values.namespace }}
  annotations:
    "helm.sh/hook": post-install,post-upgrade
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": hook-succeeded
  labels:
    app.kubernetes.io/component: migrations
spec:
  template:
    metadata:
      labels:
        app.kubernetes.io/component: migrations
    spec:
      restartPolicy: OnFailure
      backoffLimit: 3
      activeDeadlineSeconds: 600
      containers:
        - name: migrations
          image: "{{ .Values.api.image.repository }}:{{ .Values.api.image.tag }}"
          imagePullPolicy: IfNotPresent
          command: ["alembic"]
          args: ["upgrade", "head"]
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: iosme-db-credentials
                  key: url
          resources:
            requests:
              cpu: "0.5"
              memory: "512Mi"
            limits:
              cpu: "1"
              memory: "1Gi"
```

### 3.8 network-policies.yaml

```yaml
# templates/network-policies.yaml
# Per §08 Banner Integrity and Embedding Store Classification clauses

# --- Default Deny All Ingress ---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: {{ .Values.namespace }}
spec:
  podSelector: {}
  policyTypes:
    - Ingress

# --- Default Deny All Egress ---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-egress
  namespace: {{ .Values.namespace }}
spec:
  podSelector: {}
  policyTypes:
    - Egress

# --- API Pods: Ingress from NGINX only, Egress to DB, Redis, Anthropic, Banner, Blackboard, Concourse, Microsoft ---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-allow
  namespace: {{ .Values.namespace }}
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/component: api
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/component: ingress
      ports:
        - protocol: TCP
          port: 8000
  egress:
    - to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/component: database
      ports:
        - protocol: TCP
          port: 5432
    - to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/component: cache
      ports:
        - protocol: TCP
          port: 6379
    - to: []  # External endpoints
      ports:
        - protocol: TCP
          port: 443
      # IPs: api.anthropic.com, lamar.banner.domain, lamar.blackboard.domain, concourse.intellidemia.com, graph.microsoft.com
      # Implemented via Calico GlobalNetworkPolicy or namespace-level with external IPs

# --- Database Pods: Ingress from API/Worker only, NO internet egress ---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-allow
  namespace: {{ .Values.namespace }}
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/component: database
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/component: api
        - podSelector:
            matchLabels:
              app.kubernetes.io/component: worker
      ports:
        - protocol: TCP
          port: 5432
    - from:  # Banner replication source
        - namespaceSelector:
            matchLabels:
              name: banner-replication  # Placeholder — actual Banner namespace TBD
          podSelector: {}
      ports:
        - protocol: TCP
          port: 5432
  egress:
    - to: []  # Deny all internet egress from DB pods

# --- GPU Pods: Ingress from API/Worker only, NO internet egress (sovereign inference) ---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: gpu-allow
  namespace: {{ .Values.namespace }}
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/component: inference
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/component: api
        - podSelector:
            matchLabels:
              app.kubernetes.io/component: worker
      ports:
        - protocol: TCP
          port: 11434  # Ollama default
  egress:
    - to: []  # No internet egress — sovereign inference
```

**Note:** Calico `GlobalNetworkPolicy` or `NetworkPolicy` with external IP blocks is required for fine-grained egress to specific domains (Anthropic, Microsoft, Banner, Blackboard, Concourse). Native Kubernetes NetworkPolicy does not support DNS-based egress rules. The Calico implementation is:

```yaml
# Calico GlobalNetworkPolicy (deployed alongside the Helm chart)
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: iosme-egress-external
spec:
  selector: app.kubernetes.io/managed-by == 'Helm'
  types:
    - Egress
  egress:
    - action: Allow
      protocol: TCP
      destination:
        domains: ["api.anthropic.com"]
        ports: [443]
    - action: Allow
      protocol: TCP
      destination:
        domains: ["graph.microsoft.com", "purview.microsoft.com"]
        ports: [443]
    - action: Allow
      protocol: TCP
      destination:
        domains: ["*.blackboard.com"]  # Anthology SaaS domain
        ports: [443]
    - action: Allow
      protocol: TCP
      destination:
        domains: ["*.intellidemia.com"]  # Concourse SaaS
        ports: [443]
    - action: Deny
```

### 3.9 secret.yaml (Template)

```yaml
# templates/secret.yaml
# NOTE: This is a TEMPLATE. Actual secret values are managed by External Secrets Operator
# pulling from HashiCorp Vault, OR injected via helm-secrets / sops.
# Never commit real values to Git.

apiVersion: v1
kind: Secret
metadata:
  name: iosme-db-credentials
  namespace: {{ .Values.namespace }}
  annotations:
    secret.lamar.edu/source: "hashicorp-vault"
    secret.lamar.edu/path: "iosme/data/db"
type: Opaque
stringData:
  url: "REPLACED_BY_VAULT"
  username: "REPLACED_BY_VAULT"
  password: "REPLACED_BY_VAULT"

---
apiVersion: v1
kind: Secret
metadata:
  name: iosme-anthropic-api-key
  namespace: {{ .Values.namespace }}
  annotations:
    secret.lamar.edu/source: "hashicorp-vault"
    secret.lamar.edu/path: "iosme/data/anthropic"
type: Opaque
stringData:
  token: "REPLACED_BY_VAULT"

---
apiVersion: v1
kind: Secret
metadata:
  name: iosme-lti-keypair
  namespace: {{ .Values.namespace }}
  annotations:
    secret.lamar.edu/source: "hashicorp-vault"
    secret.lamar.edu/path: "iosme/data/lti"
type: Opaque
stringData:
  private-key: "REPLACED_BY_VAULT"
```

---

## 4. values-lamar-prod.yaml (Production Overrides)

```yaml
# values-lamar-prod.yaml
# Production overrides for Lamar University
# Reference this file during deployment: helm install iosme-lamar ./iosme-lamar -f values-lamar-prod.yaml

namespace: iosme

replicaCount:
  api: 2
  worker: 2
  lti: 1

api:
  image:
    repository: ghcr.io/lamar-university/iosme-api
    tag: v1.0.0
  replicas: 2
  resources:
    requests:
      cpu: "1"
      memory: "1Gi"
    limits:
      cpu: "2"
      memory: "2Gi"

worker:
  image:
    repository: ghcr.io/lamar-university/iosme-worker
    tag: v1.0.0
  replicas: 2
  resources:
    requests:
      cpu: "0.5"
      memory: "512Mi"
    limits:
      cpu: "1"
      memory: "1Gi"

postgres:
  storageClass: ios-san-fast
  storageSize: 2Ti
  primary:
    nodeSelector:
      node-role.kubernetes.io/db: "true"
  replica:
    nodeSelector:
      node-role.kubernetes.io/db: "true"
    storageSize: 4Ti

redis:
  enabled: true
  persistence:
    enabled: true
    size: 1Gi
    storageClass: ios-san-standard

gpu:
  enabled: true
  nodeSelector:
    node-role.kubernetes.io/gpu: "true"
  resources:
    limits:
      nvidia.com/gpu: 2
  inference:
    model: llama-3.3-70b-int8
    embeddingModel: bge-m3

ingress:
  enabled: true
  className: nginx
  host: ios-lti.lamar.edu
  tls:
    enabled: true
    certManager: true
    clusterIssuer: lamar-letsencrypt-prod

hpa:
  enabled: false  # Disabled by default at Lamar scale; enable after Phase 4 load testing
  api:
    minReplicas: 2
    maxReplicas: 6
    targetCPUUtilizationPercentage: 70
  worker:
    minReplicas: 2
    maxReplicas: 6
    targetCPUUtilizationPercentage: 70

podDisruptionBudget:
  enabled: true
  minAvailable: 1

serviceAccount:
  create: true
  name: iosme-sa

secrets:
  source: vault  # Options: vault, sops, manual
  vault:
    addr: "https://vault.lamar.edu:8200"
    role: "iosme-prod"
    path: "iosme/data"

# === §08 Compliance Overrides ===
compliance:
  scope: education-only
  regimes:
    - FERPA
    - SACSCOC
    - TitleIX
    - ADA508
    - TexasEdCode
    - AACSB
    - ABET
  bannerDirectMutation: false
  copilotInterception: false
  blockchainAnchor: false
```

---

## 5. Deployment Commands (Production Runbook)

### 5.1 Pre-Deployment (Phase 1 Milestone)

```bash
# 1. Verify cluster health
kubectl get nodes -o wide
# Expected: 6 nodes Ready, labels match node selectors

# 2. Verify storage classes
kubectl get storageclass
# Expected: ios-san-fast (Retain, AllowVolumeExpansion), ios-san-standard

# 3. Verify Vault connectivity (if using External Secrets Operator)
vault status
# Expected: sealed=false

# 4. Verify GPU node (if enabled)
kubectl get nodes -l node-role.kubernetes.io/gpu=true
kubectl describe node lu-ios-gpu-01 | grep nvidia.com/gpu
# Expected: nvidia.com/gpu: 2

# 5. Verify ingress controller
kubectl get pods -n ingress-nginx
# Expected: NGINX Ingress Controller Running

# 6. Verify cert-manager
kubectl get pods -n cert-manager
# Expected: cert-manager, cainjector, webhook Running
```

### 5.2 Deploy the Chart

```bash
# Clone the transferred repository
git clone https://github.com/Lamar-University/iosme-charts.git
cd iosme-charts

# Review production values
cat values-lamar-prod.yaml

# Dry-run to validate
helm install iosme-lamar ./iosme-lamar \
  -f values-lamar-prod.yaml \
  --namespace iosme \
  --create-namespace \
  --dry-run --debug

# Actual deployment
helm install iosme-lamar ./iosme-lamar \
  -f values-lamar-prod.yaml \
  --namespace iosme \
  --create-namespace \
  --wait \
  --timeout 600s

# Post-deployment: verify migrations ran
kubectl get jobs -n iosme
# Expected: iosme-lamar-migrations COMPLETE

# Verify all pods
kubectl get pods -n iosme
# Expected: 2× api, 2× worker, 2× postgres, 1× redis, 1× lti-service, 1× gpu-inference
```

### 5.3 Upgrade Procedure

```bash
# Pull updated chart
git pull origin main

# Review diff
helm diff upgrade iosme-lamar ./iosme-lamar -f values-lamar-prod.yaml

# Upgrade
helm upgrade iosme-lamar ./iosme-lamar \
  -f values-lamar-prod.yaml \
  --namespace iosme \
  --wait \
  --timeout 600s
```

### 5.4 Rollback Procedure

```bash
# List revisions
helm history iosme-lamar -n iosme

# Rollback to previous revision
helm rollback iosme-lamar [REVISION] -n iosme
```

---

## 6. Deliverables Checklist

| Item | Delivered By | Format | Handoff Gate | Reviewer |
|------|-------------|--------|-------------|----------|
| Helm chart source (`iosme-lamar/`) | SMEPro | GitHub repo | Phase 1 | Lamar IOS+ Platform Engineer |
| `values-lamar-prod.yaml` | SMEPro | YAML | Phase 1 | Lamar ITIS, Platform Engineer |
| `values-lamar-dev.yaml` | SMEPro | YAML | Phase 1 | Lamar Platform Engineer |
| Chart packaging script (`helm package`) | SMEPro | Bash | Phase 1 | Platform Engineer |
| Cosign/GPG signing keys | SMEPro | Public key file | Phase 1 | Lamar Security / ISO |
| Deployment runbook (this doc) | SMEPro | Markdown | Phase 1 | Platform Engineer, ITIS |
| Upgrade/rollback runbook | SMEPro | Markdown | Phase 1 | Platform Engineer |
| Secret management guide (Vault + ESO) | SMEPro | Markdown | Phase 1 | Platform Engineer, ITIS |
| Network policy validation script | SMEPro | Python + kubectl | Phase 2 | Platform Engineer, Network Engineer |
| Helm chart unit tests (if applicable) | SMEPro | Helm test hooks | Phase 2 | Platform Engineer |

---

## 7. Versioning & Change Log

| Version | Date | Changes | Signed Off By |
|---------|------|---------|--------------|
| 1.0.0 | Phase 1 | Initial production artifact | SMEPro Architect + Lamar IOS+ Platform Engineer |
| 1.0.1 | Phase 2 | Post-integration fixes (if any) | Platform Engineer |
| 1.1.0 | Phase 4 | Post-pen-test hardening changes | Platform Engineer + ISO |
| 2.0.0 | Year 2 | Major platform upgrade (operator migration, etc.) | Platform Engineer + SMEPro Premium Support |

---

*End of Helm Chart Production Artifact Specification.*
