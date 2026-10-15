# Cloud Computing & DevOps (CCA 2): End-to-End Automated CI/CD Pipeline

> **Student Project & Practical Demonstration**  
> **Course:** Cloud Computing and DevOps (CCA 2)  
> **Topic:** Automated CI/CD Pipeline with AWS EC2, Jenkins, Docker, Docker Hub, and Minikube  
> **Score Rubric:** 10 Marks Total  

---

## 1. Project Overview & Architecture

This repository hosts a production-ready, cloud-native Academic Portfolio & DevOps Showcase Web Application and its complete continuous integration and continuous deployment (CI/CD) automation pipeline.

### Architectural Workflow

```mermaid
flowchart TD
    subgraph Developer_Environment ["Local Workstation"]
        Dev[Developer] -->|git commit & push| GitHub[GitHub Repository]
    end

    subgraph AWS_Cloud ["AWS EC2 Cloud Host (Ubuntu 22.04 LTS)"]
        subgraph CI_CD_Engine ["Jenkins Automation Server"]
            GitHub -->|SCM Trigger / Webhook| J1[Stage 1: Checkout SCM]
            J1 --> J2[Stage 2: Build & Test (Unit & Smoke Tests)]
            J2 --> J3[Stage 3: Docker Build (Immutable Tag)]
            J3 --> J4[Stage 4: Docker Hub Push (dockerhub-creds)]
            J4 --> J5[Stage 5: Deploy to Minikube (kubectl)]
            J5 --> J6[Stage 6: Verify Deployment & HTTP Smoke Test]
        end

        subgraph Container_Registry ["Docker Hub"]
            J4 -->|Push Image| DH[(Docker Hub Repository)]
        end

        subgraph K8s_Cluster ["Minikube Kubernetes Cluster"]
            J5 -->|Rolling Update| K8sDeploy[Kubernetes Deployment (2 Replicas)]
            DH -->|Pull Image| K8sDeploy
            K8sDeploy --> Pod1[Pod 1]
            K8sDeploy --> Pod2[Pod 2]
            K8sSvc[Kubernetes Service: NodePort 30080] --> Pod1
            K8sSvc --> Pod2
        end
    end

    User[Browser / Viva Evaluator] -->|Access Port 30080| K8sSvc
```

---

## 2. Technology Stack & Component Mapping

| Component | Technology | Role & Justification |
| :--- | :--- | :--- |
| **Cloud Infrastructure** | **AWS EC2 (Ubuntu LTS)** | Hosts Jenkins server, Docker engine, and local Minikube cluster. |
| **Source SCM** | **GitHub** | Version control repository hosting source code, manifests, and Jenkinsfile. |
| **CI/CD Automation** | **Jenkins LTS** | Multi-stage pipeline orchestrator executing automated build, test, package, push, and deploy. |
| **Container Engine** | **Docker CE** | Packages application and dependencies into reproducible, lightweight container images. |
| **Artifact Registry** | **Docker Hub** | Secure remote container registry storing versioned, immutable Docker images. |
| **Orchestration** | **Minikube** | Single-node Kubernetes cluster simulating production container orchestration on EC2. |
| **K8s CLI** | **kubectl** | Manages deployments, services, rollouts, and health inspection. |
| **Application Stack** | **Node.js (Native Test Runner)** | Lightweight portfolio web app with built-in `/health` endpoints and zero-dependency unit tests. |

---

## 3. Repository Structure

```
d:\shub
├── .dockerignore                 # Excludes files from Docker build context
├── .gitignore                    # Prevents committing secrets, keys, and logs
├── Dockerfile                    # Multi-stage, non-root Alpine container definition
├── Jenkinsfile                   # Declarative 6-stage CI/CD pipeline script
├── package.json                  # Application metadata and test scripts
├── README.md                     # Comprehensive assignment documentation
├── k8s/
│   ├── deployment.yaml           # K8s Deployment (2 replicas, probes, resource limits)
│   └── service.yaml              # K8s Service (NodePort 30080)
├── scripts/
│   └── setup-ec2-devops-host.sh  # Automated provisioning script for EC2
├── src/
│   ├── server.js                 # HTTP server with `/health`, `/api/info`, and UI routes
│   └── public/
│       ├── index.html            # Responsive UI with live health probe & version label
│       └── styles.css            # Modern dark-mode styling
└── test/
    └── app.test.js               # Automated unit tests covering all routes and health
```

---

## 4. Assignment Rubric & Marks Mapping

| Rubric Section | Marks | Criteria Implemented |
| :--- | :--- | :--- |
| **Project & GitHub Setup** | 1.0 | Functional web application, structured repository, clean `.gitignore`, GitHub SCM integration. |
| **AWS & Jenkins Setup** | 1.5 | Provisioned Ubuntu EC2 instance, restricted security groups, Jenkins LTS + Java 17 configured. |
| **Dockerfile Implementation** | 1.5 | Secure, non-root container image, automated test gate during build, health check configured. |
| **Jenkinsfile & Pipeline** | 2.0 | Declarative pipeline with 6 mandatory stages, error handling, dynamic tagging, rollout verification. |
| **Image Registry Integration** | 1.0 | Docker Hub credential binding (`dockerhub-creds`), push of immutable tag (`${BUILD_NUMBER}`) & latest. |
| **Kubernetes on Minikube** | 1.5 | Valid Deployment & Service manifests, rolling updates, liveness/readiness probes, pod verification. |
| **Demonstration & 2nd Run** | 1.5 | Live execution, visible source code change (v1.0 -> v2.0), automated redeployment, viva readiness. |
| **Total** | **10.0** | **Complete Practical Demonstration** |

---

## 5. Step-by-Step Implementation Guide

### Stage 1: AWS EC2 Instance Provisioning
1. **Launch EC2 Instance:**
   - **AMI:** Ubuntu Server 22.04 LTS (HVM)
   - **Instance Type:** `t3.medium` (2 vCPU, 4 GiB RAM) — *Necessary to comfortably run Jenkins + Docker + Minikube together.*
   - **Storage:** 30 GiB gp3 (within or standard AWS usage, estimated cost: ~\$0.0416/hr while active).
2. **Security Group Configuration:**
   - `SSH (Port 22)`: Source: `My IP` (Restricted access).
   - `Custom TCP (Port 8080)`: Source: `My IP` (Jenkins Dashboard).
   - `Custom TCP (Port 30080)`: Source: `Anywhere` or `My IP` (Application NodePort).
3. **Execute One-Click EC2 Provisioning:**
   ```bash
   chmod +x scripts/setup-ec2-devops-host.sh
   ./scripts/setup-ec2-devops-host.sh
   ```

### Stage 2: Configure Jenkins Credentials
1. Open Jenkins: `http://<EC2-PUBLIC-IP>:8080`
2. Unlock with initial password:
   ```bash
   sudo cat /var/lib/jenkins/secrets/initialAdminPassword
   ```
3. Install suggested plugins (Pipeline, Git, Credentials Binding).
4. Navigate to: **Manage Jenkins** &rarr; **Credentials** &rarr; **System** &rarr; **Global credentials**.
5. Add credential:
   - **Kind:** Username with password
   - **Username:** Your Docker Hub username
   - **Password:** Docker Hub Personal Access Token (PAT)
   - **ID:** `dockerhub-creds` *(Mandatory)*

### Stage 3: Create and Run the Pipeline Job
1. In Jenkins, click **New Item** &rarr; Name: `cca2-devops-pipeline` &rarr; Select **Pipeline** &rarr; OK.
2. In Pipeline definition:
   - Select: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `https://github.com/<your-username>/academic-devops-portfolio.git`
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`
3. Click **Save** and trigger **Build Now**.

---

## 6. Mandatory Second Deployment Demonstration

To demonstrate an end-to-end continuous deployment flow for college evaluation:

1. **Modify application version in `src/server.js` and `package.json`:**
   - Change `version: "1.0.0"` &rarr; `version: "2.0.0"`.
2. **Commit and push to GitHub:**
   ```bash
   git add .
   git commit -m "feat(ui): release v2.0.0 with updated banner for college viva demonstration"
   git push origin main
   ```
3. **Trigger Pipeline Run #2:**
   - Jenkins pulls commit `v2.0.0`.
   - Docker builds and pushes image tag `2-<commit-sha>`.
   - Minikube performs a zero-downtime rolling update.
   - Access `http://<EC2-PUBLIC-IP>:30080/` to confirm live version **2.0.0** is rendered!

---

## 7. Verification & Diagnostic Commands

```bash
# 1. Check Minikube cluster nodes
kubectl get nodes -o wide

# 2. Check running application pods
kubectl get pods -l app=academic-portfolio -o wide

# 3. Check service exposure
kubectl get svc academic-portfolio-service

# 4. Check rollout history
kubectl rollout history deployment/academic-portfolio

# 5. Perform HTTP smoke test
curl -i http://localhost:30080/health
```

---

## 8. Evidence & Screenshot Checklist for Submission

Capture the following screenshots and place them in the assignment report:

- [ ] **Screenshot 1:** AWS EC2 Management Console showing running instance and security group rules.
- [ ] **Screenshot 2:** Local unit test execution passing (`npm test` / `node --test`).
- [ ] **Screenshot 3:** Docker Hub repository showing pushed image tags (`1-...`, `2-...`, `latest`).
- [ ] **Screenshot 4:** Jenkins Stage View displaying all 6 stages green for Build #1.
- [ ] **Screenshot 5:** Minikube status and running Kubernetes pods (`kubectl get pods`).
- [ ] **Screenshot 6:** Deployed application UI (Version 1.0.0) running in browser.
- [ ] **Screenshot 7:** GitHub commit history showing the source code change for Version 2.0.0.
- [ ] **Screenshot 8:** Jenkins Stage View for Build #2 and updated application UI (Version 2.0.0).

---

## 9. Viva Voce Preparation (Q&A)

**Q1: Why did we use Minikube instead of a multi-node Kubernetes cluster?**  
*Answer:* Minikube provides a complete, lightweight single-node Kubernetes cluster ideal for development, testing, and CI/CD demonstration on a single cloud VM without incurring multi-node cloud infrastructure costs.

**Q2: Why use immutable image tags instead of just `latest`?**  
*Answer:* The `latest` tag is mutable and makes rollbacks unpredictable. Unique immutable tags (e.g., `${BUILD_NUMBER}-${GIT_COMMIT}`) ensure that every deployment is traceable to an exact source code commit and can be rolled back reliably.

**Q3: How do readiness and liveness probes differ?**  
*Answer:* Liveness probes determine if the container needs to be restarted if deadlocked or unresponsive. Readiness probes determine if the container is ready to accept incoming network traffic.
