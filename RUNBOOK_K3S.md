# Runbook: Deploy Spring Petclinic on a local k3s cluster

This runbook guides a beginner through deploying this Spring Petclinic app to k3s. It covers prerequisites, two image strategies, Helm install with a k3s-tuned values file, secrets, optional DB persistence, ingress, verification and troubleshooting.

**Important**: this repository already contains a Helm chart at [helm/petclinic/values.yaml](helm/petclinic/values.yaml) and templates under [helm/petclinic/templates](helm/petclinic/templates). We'll reuse that chart and supply a k3s override file.

1) Prerequisites
- k3s installed and running on your machine or VM. On Windows prefer WSL2 for Linux-based commands, or run k3s on a remote Linux VM. See https://k3s.io.
- `kubectl` configured to talk to your k3s cluster.
- `helm` (v3+) installed.
- Docker (or build tools) to build the image locally, or access to a container registry.

2) What we will do (summary)
- Build the app image (Maven → Docker image).
- Get the image to k3s (either push to registry or import into k3s containerd).
- Configure Kubernetes secrets (DB credentials) and optional PVCs for DB.
- Install the Helm chart with a `values-k3s.yaml` override tuned for k3s (ClusterIP + Ingress, resources, image pullPolicy etc.).
- Verify app, inspect logs, and troubleshoot common issues.

3) Build the container image
- From repository root, build the app artifact and image:
```bash
# Build jar (skip tests for speed)
mvn -DskipTests package

# Build Docker image (example tag)
docker build -t ghcr.io/OWNER/petclinic:latest .
```

Two image strategies (choose one):

- A) Push to a registry (recommended when k3s nodes cannot reach your dev machine):
```bash
# Tag & push (example to Docker Hub)
docker tag ghcr.io/OWNER/petclinic:latest yourdockerhubuser/petclinic:latest
docker push yourdockerhubuser/petclinic:latest
```

- B) Load image directly into k3s containerd (convenient for local single-node k3s):
```bash
# Save image to tar
docker save ghcr.io/OWNER/petclinic:latest -o petclinic.tar

# On the k3s host (if local k3s single node), import to k3s containerd
sudo k3s ctr images import petclinic.tar

# Alternative (if `ctr` not available directly):
# sudo ctr -n k8s.io images import petclinic.tar
```

Notes: On Windows with WSL2, run the `k3s` import inside WSL or on the Linux host. If you use k3d for local clusters, use `k3d image import`.

4) Prepare Kubernetes secrets and config
- Do not put DB credentials in `values.yaml`; create a Kubernetes Secret instead. Example (replace values):
```bash
kubectl create secret generic petclinic-db \
  --from-literal=DB_USERNAME=petuser \
  --from-literal=DB_PASSWORD=petpass
```

- You can inject these into the app either by modifying the Helm chart to consume the secret as env vars, or by patching the Deployment after install: example patch to set env vars (quick, not permanent):
```bash
# Replace POD env with your JDBC string
kubectl set env deployment/petclinic \
  SPRING_DATASOURCE_URL=jdbc:postgresql://my-postgres.default.svc.cluster.local:5432/petclinic \
  SPRING_DATASOURCE_USERNAME=$(kubectl get secret petclinic-db -o jsonpath="{.data.DB_USERNAME}" | base64 --decode) \
  SPRING_DATASOURCE_PASSWORD=$(kubectl get secret petclinic-db -o jsonpath="{.data.DB_PASSWORD}" | base64 --decode)
```

Better approach: modify the chart to add `env:` support so Helm can create env from Secret—see notes below.

5) (Optional) Deploy a persistent DB (recommended for production-like testing)
- Option A: Use Bitnami helm chart for PostgreSQL and set `storageClass=local-path`:
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install my-postgres bitnami/postgresql \
  --set global.storageClass=local-path \
  --set persistence.size=5Gi \
  --set postgresqlPassword=petpass \
  --set postgresqlUsername=petuser \
  --set postgresqlDatabase=petclinic
```

- Option B: Create a PVC manually (example):
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 5Gi
```

6) Create a k3s-tuned Helm values file
- Create `values-k3s.yaml` locally with at least these changes (example):
```yaml
image:
  repository: yourdockerhubuser/petclinic
  tag: latest
  pullPolicy: IfNotPresent

replicaCount: 1

service:
  type: ClusterIP
  port: 8080
  nodePort: 30080

ingress:
  enabled: true
  host: petclinic.local

resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
```

Notes:
- `service.type: ClusterIP` + `ingress.enabled: true` is preferred on k3s with Traefik. If you prefer not to use Ingress, set `service.type: NodePort` (the chart defaults to NodePort).
- `image.pullPolicy` should be `IfNotPresent` if you preload the image.

7) Configure DNS/hosts for ingress
- If using `ingress.host: petclinic.local` and Traefik is present, map the host to your k3s node IP in your client machine's `/etc/hosts` (or Windows' `C:\Windows\System32\drivers\etc\hosts`):
```
<k3s-node-ip> petclinic.local
```

Alternative: set `ingress.host` to `<node-ip>.nip.io` so public DNS resolves automatically.

8) Install the Helm chart to k3s
- Example command (from repo root):
```bash
helm upgrade --install petclinic helm/petclinic -f values-k3s.yaml --wait
```

- If the image is in a registry requiring auth, create an imagePullSecret and reference it in the chart (or attach to the service account). Example to create Docker registry secret:
```bash
kubectl create secret docker-registry regcred \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=YOURUSER \
  --docker-password=YOURPASS \
  --docker-email=YOU@EXAMPLE.COM

# Then reference it by adding to the chart or patching the service account.
```

9) Verify deployment
- Pods and services:
```bash
kubectl get pods -l app=petclinic
kubectl get svc -l app=petclinic
kubectl get ingress
```

- Check logs if pods don't become ready:
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
kubectl get events --sort-by=.lastTimestamp
```

- Test app via ingress (example):
```bash
curl -v http://petclinic.local/  # if /etc/hosts points to k3s node
```

10) Common issues & fixes
- ImagePullBackOff: ensure image exists in registry reachable by k3s, or import image into k3s (see section 3). Check `kubectl describe pod` for exact reason.
- CrashLoopBackOff due to DB connection: confirm DB service is reachable and credentials are correct. Use `kubectl exec` into pod to test connectivity tools (psql, telnet) if available.
- 404 / Ingress not routing: confirm Ingress exists and Traefik is running (`kubectl get pods -n kube-system` or `kubectl get pods -n traefik`). Check `kubectl describe ingress <name>` for errors and ensure host resolves to node IP.
- Probes failing: adjust `readinessProbe` and `livenessProbe` initial delays in `helm/petclinic/templates/deployment.yaml` if startup is slow.

11) Rollback and cleanup
- Rollback Helm release:
```bash
helm rollback petclinic 1
```

- Uninstall Helm release and delete resources:
```bash
helm uninstall petclinic
kubectl delete secret petclinic-db
kubectl delete pvc postgres-pvc
```

12) Recommendations to improve repo for k3s
- Add support in the Helm chart for environment variables (Secrets) so DB credentials can be provided as Helm values that refer to a Secret.
- Add a `values-k3s.yaml` example committed to the repo (without secrets) to make repeatable installs easier.
- Consider adding a small manifest or Helm chart dependency for Postgres with `storageClass=local-path` for local testing.

13) Example `values-k3s.yaml` (repeat, for copy/paste)
```yaml
image:
  repository: yourdockerhubuser/petclinic
  tag: latest
  pullPolicy: IfNotPresent

replicaCount: 1

service:
  type: ClusterIP
  port: 8080
  nodePort: 30080

ingress:
  enabled: true
  host: petclinic.local

resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
```

14) Next steps I can do for you
- Create a `values-k3s.yaml` committed in the repo (no secrets).
- Patch the Helm chart to support reading DB credentials from `values.yaml` and creating env entries from Secrets.
- Provide an explicit example of deploying Bitnami Postgres as part of the workflow.

---
File added: [RUNBOOK_K3S.md](RUNBOOK_K3S.md)
