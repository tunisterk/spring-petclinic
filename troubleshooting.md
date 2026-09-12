# Troubleshooting Guide

This document records the main issues encountered while building, destroying, recreating, and validating the Spring PetClinic DevOps platform on AWS EKS.

The goal is not only to list errors, but to show the troubleshooting process: **symptom → investigation → root cause → fix → lesson learned**.

---

## 1. Terraform Modularization and State Refactoring

### Symptom

After refactoring the Terraform configuration into reusable modules, Terraform wanted to recreate resources that already existed.

### Root Cause

The resources had moved to new Terraform addresses after modularization.

For example, a resource previously defined in the root module could now exist under:

```text
module.network...
module.iam...
module.eks...
```

Terraform tracks resources by state address, not by their AWS name alone.

### Fix

Use Terraform `moved` blocks so Terraform understands that the resource address changed without the actual infrastructure needing replacement.

Example concept:

```hcl
moved {
  from = aws_vpc.main
  to   = module.network.aws_vpc.main
}
```

### Lesson Learned

When restructuring Terraform, always consider the state implications. Refactoring code does not automatically refactor Terraform state.

---

## 2. AWS Account Migration and Hard-Coded IAM Policy ARN

### Symptom

Infrastructure creation failed after moving the project to a different AWS account.

### Root Cause

An IAM policy ARN from the previous AWS account was hard-coded in the Terraform configuration.

### Fix

The AWS Load Balancer Controller IAM policy was brought under Terraform management instead of referencing a hard-coded account-specific ARN.

### Lesson Learned

Avoid hard-coding account-specific ARNs wherever the resource can be created and referenced dynamically by Terraform.

---

## 3. Incorrect EBS CSI Managed Policy ARN

### Symptom

Terraform failed while attaching the AWS managed EBS CSI policy.

### Root Cause

The ARN was written with an incorrect `/service-role/` path.

Incorrect pattern:

```text
arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicyV2
```

Correct pattern:

```text
arn:aws:iam::aws:policy/AmazonEBSCSIDriverPolicyV2
```

### Fix

Use the correct AWS managed policy ARN.

### Lesson Learned

AWS managed policy paths are not always obvious from their service name. Verify the exact ARN before using it in Terraform.

---

## 4. PostgreSQL PVC Stuck in Pending

### Symptom

The PostgreSQL pod could not start because its PVC remained in:

```text
Pending
```

### Investigation

Commands used:

```bash
kubectl get pvc
kubectl describe pvc <pvc-name>
kubectl get storageclass
```

### Root Cause

The application requested the `gp3` StorageClass, but that StorageClass did not exist in the cluster.

### Fix

A `gp3` StorageClass was added:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
parameters:
  type: gp3
```

### Lesson Learned

A PVC can only bind if the referenced StorageClass exists and its provisioner is operational.

---

## 5. Argo CD Did Not Deploy a Local StorageClass File

### Symptom

The `storageclass.yml` file existed locally, but the cluster still did not have the `gp3` StorageClass.

### Investigation

The local working tree contained the file, but Argo CD was following the repository revision in Git.

Useful checks:

```bash
git rev-parse HEAD
git show HEAD:helm/petclinic/templates/storageclass.yml
```

Compare with:

```bash
kubectl get application petclinic -n argocd \
  -o jsonpath='{.status.sync.revision}'
```

### Root Cause

The file was created locally but had not been committed and pushed.

Argo CD does not deploy local files. It deploys the desired state stored in Git.

### Fix

Commit and push the file, then refresh/synchronize Argo CD.

### Lesson Learned

In GitOps:

```text
Local filesystem != desired state
Git repository = desired state
```

---

## 6. EBS CSI Driver Stuck During Startup

### Symptom

The EBS CSI add-on was not healthy.

The controller showed approximately:

```text
1/6 Running
```

while the node pods were healthy.

### Investigation

Commands used:

```bash
kubectl get pods -n kube-system
kubectl logs -n kube-system <ebs-csi-controller-pod> -c ebs-plugin
aws eks describe-addon \
  --cluster-name petclinic-cluster \
  --addon-name aws-ebs-csi-driver \
  --region eu-central-1
```

### Important Error

The controller reported a credential error similar to:

```text
failed to refresh cached credentials, no EC2 IMDS role found
```

while attempting AWS API operations such as:

```text
DescribeAvailabilityZones
```

### Root Cause

The EBS CSI controller had no valid AWS identity.

### Fix

Use EKS Pod Identity for the service account:

```text
ebs-csi-controller-sa
```

The Pod Identity Agent must be installed and an association must exist between:

```text
Cluster
Namespace: kube-system
Service Account: ebs-csi-controller-sa
IAM Role: AmazonEKS_EBS_CSI_DriverRole
```

### Result

The EBS CSI controller recovered to:

```text
6/6 Running
```

and the EKS add-on reported:

```text
ACTIVE
```

### Lesson Learned

A Kubernetes CSI driver may be running as a pod but still fail because it has no cloud-provider permissions.

---

## 7. Missing EKS Pod Identity Agent

### Symptom

The EBS CSI Pod Identity association existed conceptually, but credentials were still unavailable.

### Root Cause

The EKS Pod Identity Agent was not installed in the recreated cluster.

### Fix

Install the managed add-on:

```text
eks-pod-identity-agent
```

and recreate/verify the Pod Identity association.

### Lesson Learned

Pod Identity requires both:

```text
IAM role + association + Pod Identity Agent
```

If any one is missing, workloads cannot obtain AWS credentials.

---

## 8. Manual EBS Components Disappeared After Cluster Recreation

### Symptom

After `terraform destroy` and a fresh cluster creation:

- Argo CD restored the application
- the Helm chart restored Kubernetes resources
- but the EBS CSI add-on and Pod Identity configuration did not return

The PostgreSQL PVC remained pending.

### Root Cause

Those components had originally been configured manually and were outside Terraform.

### Fix

Move them into Terraform:

- `aws_eks_addon` for Pod Identity Agent
- `aws_eks_addon` for EBS CSI Driver
- dedicated IAM role
- AWS managed EBS CSI policy attachment
- `aws_eks_pod_identity_association`

Existing manual resources were imported into Terraform state rather than recreated.

### Lesson Learned

If a cluster rebuild depends on a manual step, the infrastructure is not truly reproducible.

---

## 9. Terraform Import of Pod Identity Association Failed

### Symptom

Importing the Pod Identity association produced errors saying the association ID had an invalid length.

### Root Cause

The import ID format was entered incorrectly, including placeholder text or spaces.

### Fix

Use the exact format:

```text
cluster-name,association-id
```

Example:

```bash
terraform import \
  module.eks_addons_iam.aws_eks_pod_identity_association.ebs_csi \
  petclinic-cluster,a-xxxxxxxxxxxxxxxxx
```

No spaces should be inserted around the comma.

### Lesson Learned

Terraform import identifiers are provider-specific. Check the required import format carefully.

---

## 10. Terraform Add-on Output Used Unsupported `.status`

### Symptom

Terraform returned:

```text
Unsupported attribute
```

when trying to output:

```hcl
aws_eks_addon.example.status
```

### Root Cause

The AWS provider version in use did not expose the add-on `status` attribute in that resource schema.

### Fix

Remove the unsupported output and verify the add-on state using the AWS CLI instead:

```bash
aws eks describe-addon ...
```

### Lesson Learned

Do not assume a resource attribute exists because it appears logical. Always check the provider schema/version.

---

## 11. PostgreSQL 18 Storage Path Change

### Symptom

PostgreSQL failed to start correctly when the persistent volume was mounted at:

```text
/var/lib/postgresql/data
```

### Root Cause

The PostgreSQL 18 container image uses a changed storage layout compared with older assumptions.

### Fix

Mount the persistent volume at:

```text
/var/lib/postgresql
```

### Lesson Learned

Major database image upgrades can change container filesystem expectations. Always check the image-specific documentation when upgrading major versions.

---

## 12. PetClinic CrashLoop During Database Startup

### Symptom

After a fresh cluster deployment, PetClinic started before PostgreSQL was ready and entered a restart loop.

### Root Cause

The application attempted database connectivity before PostgreSQL was accepting connections.

### Fix

Add an init container to PetClinic:

```yaml
initContainers:
  - name: wait-for-postgres
    image: busybox:1.36
    command:
      - sh
      - -c
      - |
        until nc -z demo-db 5432; do
          echo "Waiting for PostgreSQL..."
          sleep 3
        done
        echo "PostgreSQL is ready."
```

### Result

The pod remains in an init state until PostgreSQL becomes reachable.

### Lesson Learned

Kubernetes controls startup ordering poorly by default. Dependencies should be handled through readiness or explicit startup checks rather than assuming another pod is ready.

---

## 13. PetClinic Terminated by Liveness Probe

### Symptom

PetClinic started successfully and connected to PostgreSQL, but later terminated gracefully.

Pod inspection showed:

```text
Exit Code: 143
```

### Investigation

Application logs looked healthy, so the next step was:

```bash
kubectl describe pod <petclinic-pod>
```

This revealed that Kubernetes was killing the container because of the liveness probe.

### Root Cause

Spring Boot took long enough to initialize that liveness checks began too early.

### Fix

Add a `startupProbe`.

The application uses:

```text
/livez
/readyz
```

with Spring Boot configured to expose additional health probe paths.

### Lesson Learned

Use:

```text
startupProbe
```

for slow-starting applications.

`livenessProbe` should answer:

> Is this already-running container stuck?

It should not be responsible for determining whether an application has finished starting.

---

## 14. HPA Showed `<unknown>/70%`

### Symptom

The HPA displayed:

```text
cpu: <unknown>/70%
```

and could not determine desired replicas.

### Investigation

```bash
kubectl describe hpa petclinic
```

showed an error similar to:

```text
unable to fetch metrics from resource metrics API
server could not find requested resource
(get pods.metrics.k8s.io)
```

### Root Cause

Metrics Server was missing after cluster recreation.

It had previously been installed manually.

### Fix

Install Metrics Server:

```bash
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

helm upgrade --install metrics-server \
  metrics-server/metrics-server \
  -n kube-system
```

### Result

HPA metrics became available again and desired replicas returned to normal.

### Lesson Learned

Prometheus and Metrics Server solve different problems:

```text
Prometheus
→ monitoring / historical metrics

Metrics Server
→ Kubernetes Resource Metrics API
→ kubectl top / HPA
```

---

## 15. Monitoring Components Missing After Cluster Recreation

### Symptom

After rebuilding the cluster, the application returned through Argo CD but monitoring did not.

### Root Cause

`kube-prometheus-stack` and Metrics Server were installed manually rather than through the reproducible infrastructure path.

### Fix

Create:

```text
monitoring/install-monitoring.sh
```

which performs:

```text
helm upgrade --install monitoring ...
helm upgrade --install metrics-server ...
```

### Lesson Learned

A documented or automated bootstrap path is required for platform components that are intentionally kept outside Terraform.

---

## 16. AWS Load Balancer Controller Ingress Address Remained Empty

### Symptom

The Kubernetes Ingress existed, but:

```text
ADDRESS
```

remained empty.

### Root Cause

The AWS Load Balancer Controller was not installed or not functioning correctly.

### Fix

Install the controller using the official AWS Helm chart and a service account mapped to the Terraform-managed IAM role.

The installation also explicitly provided:

```text
clusterName
region
vpcId
```

### Lesson Learned

An `Ingress` resource by itself does not create an AWS ALB.

A controller is required to reconcile the Kubernetes Ingress into an AWS load balancer.

---

## 17. AWS Load Balancer Controller Could Not Discover VPC

### Symptom

The controller failed during ALB reconciliation because it could not automatically determine the VPC.

### Fix

Pass the values explicitly during Helm installation:

```text
region=eu-central-1
vpcId=<EKS-VPC-ID>
```

### Lesson Learned

Auto-discovery is convenient, but explicit configuration is useful when metadata-based discovery fails.

---

## 18. AWS Load Balancer Controller Webhook Had No Endpoints

### Symptom

Kubernetes temporarily reported a webhook error similar to:

```text
no endpoints available
```

### Root Cause

The controller pods/webhook were still starting.

### Fix

Wait for the controller deployment to become ready and confirm successful reconciliation.

### Lesson Learned

Not every startup-time error represents a persistent configuration issue. Check whether the component is simply still initializing.

---

## 19. ALB Hostname Worked in AWS but Failed in WSL DNS

### Symptom

The ALB was successfully provisioned and healthy, but `curl` from WSL initially failed to resolve the hostname.

### Root Cause

The AWS infrastructure layer was healthy; the problem was local DNS resolution inside the WSL environment.

### Lesson Learned

Troubleshooting must separate layers:

```text
AWS resource health
Kubernetes resource health
Application health
Local client/DNS health
```

A failure from the client does not automatically mean the cloud resource is broken.

---

## 20. Terraform Destroy Blocked by ALB Resources

### Symptom

`terraform destroy` failed with errors such as:

```text
DependencyViolation
```

for subnets and Internet Gateway resources.

### Root Cause

The AWS Load Balancer Controller had created resources outside Terraform's state, including:

- Application Load Balancer
- Elastic Network Interfaces
- public IP mappings

Terraform attempted to delete the VPC infrastructure while those resources still depended on it.

### Fix

Delete the application/Ingress while the AWS Load Balancer Controller is still running.

Wait for AWS to remove the ALB and related ENIs, then run:

```bash
terraform destroy
```

again.

### Lesson Learned

Terraform cannot automatically destroy resources created indirectly by Kubernetes controllers unless Terraform also owns those resources.

Destroy order matters.

---

## 21. Argo CD: Synced but Degraded

### Symptom

Argo CD showed the application as:

```text
Synced
Degraded
```

### Explanation

These statuses answer different questions.

```text
Synced
→ Does the live cluster match Git?

Healthy / Degraded
→ Are the resulting Kubernetes workloads actually healthy?
```

### Lesson Learned

A perfectly synchronized GitOps deployment can still be broken at runtime.

Always inspect both sync and health status.

---

## 22. Old PetClinic Pod Stayed in CrashLoop After Database Recovery

### Symptom

PostgreSQL and storage recovered, but an existing PetClinic pod remained unhealthy.

### Fix

Restart the deployment:

```bash
kubectl rollout restart deployment petclinic
```

A newly created pod started successfully.

### Long-Term Improvement

The wait-for-PostgreSQL init container was added so future pods do not hit the same startup race.

### Lesson Learned

Fixing a dependency does not always reset the current state of an already-failing workload.

---

## 23. Helm Lint Did Not Work Against Remote Chart Reference

### Symptom

Attempting something similar to:

```bash
helm lint prometheus-community/kube-prometheus-stack
```

did not work as expected.

### Root Cause

`helm lint` is primarily designed for a local chart directory.

### Fix

For validation of a remote chart with local values, use rendering:

```bash
helm template ...
```

For the PetClinic chart stored locally, use:

```bash
helm lint helm/petclinic
```

### Lesson Learned

Choose the Helm validation command based on whether the chart is local or remote.

---

## 24. Grafana HPA Desired Replicas Showed 0

### Symptom

The Grafana HPA desired replicas panel displayed `0`.

### Investigation

This matched the HPA failure observed through:

```bash
kubectl describe hpa petclinic
```

### Root Cause

Metrics Server was missing, so HPA could not calculate CPU utilization.

### Fix

Reinstall Metrics Server.

### Result

The dashboard returned to:

```text
Current Replicas: 1
Desired Replicas: 1
```

### Lesson Learned

Dashboards visualize system state; when a panel looks wrong, verify the underlying Kubernetes API or metric source before assuming the Grafana query is wrong.

---

## 25. Alertmanager Verification

### Goal

Verify that alerting was not only configured but actually functional.

### Test

Temporarily scale PetClinic to zero:

```bash
kubectl scale deployment petclinic --replicas=0 -n default
```

The custom rule:

```text
PetClinicDown
```

has:

```text
for: 2m
```

After the condition persisted long enough, the alert appeared in Alertmanager.

Restore the deployment:

```bash
kubectl scale deployment petclinic --replicas=1 -n default
```

### Lesson Learned

Monitoring configuration is only complete once the entire path has been tested:

```text
Metric
→ Prometheus rule
→ Pending
→ Firing
→ Alertmanager
```

---

# Useful Troubleshooting Commands

## Kubernetes

```bash
kubectl get pods -A
kubectl get svc -A
kubectl get ingress -A
kubectl get pvc
kubectl get storageclass
kubectl get hpa
kubectl describe pod <pod>
kubectl logs <pod>
kubectl get events --sort-by=.metadata.creationTimestamp
```

## EKS Add-ons

```bash
aws eks list-addons \
  --cluster-name petclinic-cluster \
  --region eu-central-1

aws eks describe-addon \
  --cluster-name petclinic-cluster \
  --addon-name aws-ebs-csi-driver \
  --region eu-central-1
```

## Argo CD

```bash
kubectl get application petclinic -n argocd

kubectl get application petclinic -n argocd \
  -o jsonpath='{.status.sync.revision}'
```

## HPA / Metrics

```bash
kubectl top pods
kubectl top nodes
kubectl describe hpa petclinic
```

## Terraform

```bash
terraform validate
terraform plan
terraform state list
terraform output
```

## Helm

```bash
helm list -A
helm lint helm/petclinic
helm template petclinic helm/petclinic
```

---

# Troubleshooting Approach Used

The main troubleshooting approach throughout the project was:

```text
1. Observe the symptom
2. Identify the failing layer
3. Inspect status/events/logs
4. Read the exact error
5. Validate dependencies
6. Make one targeted change
7. Verify recovery
8. Make the fix reproducible
```

The most important principle was avoiding random changes.

For example:

```text
PVC Pending
```

was traced through:

```text
PVC
→ StorageClass
→ CSI Driver
→ AWS credentials
→ Pod Identity Agent
→ IAM role
```

rather than repeatedly modifying the application manifest.

This approach made the debugging process more repeatable and helped convert manual fixes into Terraform, Helm, or documented bootstrap steps.
