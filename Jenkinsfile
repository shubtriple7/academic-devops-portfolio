pipeline {
    agent any

    parameters {
        string(name: 'DOCKER_REPO', defaultValue: 'shub1818/academic-portfolio', description: 'Docker Hub repository name (format: username/repository)')
        string(name: 'K8S_NAMESPACE', defaultValue: 'default', description: 'Target Kubernetes namespace')
    }

    environment {
        DOCKER_CREDENTIALS_ID = 'dockerhub-creds'
        IMAGE_NAME            = "${params.DOCKER_REPO}"
        IMAGE_TAG             = "${env.BUILD_NUMBER}-${env.GIT_COMMIT ? env.GIT_COMMIT.take(7) : 'build'}"
        // Ensures kubectl accesses the Minikube cluster correctly on the EC2 host
        KUBECONFIG            = "${env.HOME}/.kube/config"
    }

    stages {
        stage('1. Checkout') {
            steps {
                echo "=========================================="
                echo "Stage 1: Checking out source code from Git"
                echo "Commit: ${env.GIT_COMMIT ?: 'Latest'}"
                echo "Branch: ${env.GIT_BRANCH ?: 'main'}"
                echo "=========================================="
                checkout scm
            }
        }

        stage('2. Build and Test') {
            steps {
                echo "=========================================="
                echo "Stage 2: Running Automated Unit & Smoke Tests"
                echo "=========================================="
                // Enforce quality gate using the native Node.js test runner
                sh '''
                    echo "[INFO] Validating Node.js syntax and executing tests..."
                    node --version
                    node --test test/app.test.js
                '''
            }
        }

        stage('3. Docker Build') {
            steps {
                echo "=========================================="
                echo "Stage 3: Building Container Image"
                echo "Target: ${IMAGE_NAME}:${IMAGE_TAG}"
                echo "=========================================="
                sh """
                    echo "[INFO] Building Docker image with unique tag and latest..."
                    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -t ${IMAGE_NAME}:latest .
                    echo "[INFO] Docker images built successfully:"
                    docker images | grep "${IMAGE_NAME}" | head -n 2
                """
            }
        }

        stage('4. Push Image') {
            steps {
                echo "=========================================="
                echo "Stage 4: Authenticating and Pushing to Docker Hub"
                echo "Credential ID: ${DOCKER_CREDENTIALS_ID}"
                echo "=========================================="
                withCredentials([usernamePassword(
                    credentialsId: "${DOCKER_CREDENTIALS_ID}",
                    usernameVariable: 'DOCKER_HUB_USER',
                    passwordVariable: 'DOCKER_HUB_TOKEN'
                )]) {
                    sh """
                        echo "[INFO] Logging into Docker Hub securely..."
                        echo "\$DOCKER_HUB_TOKEN" | docker login -u "\$DOCKER_HUB_USER" --password-stdin
                        
                        echo "[INFO] Pushing unique immutable tag: ${IMAGE_NAME}:${IMAGE_TAG}"
                        docker push ${IMAGE_NAME}:${IMAGE_TAG}
                        
                        echo "[INFO] Pushing latest tag: ${IMAGE_NAME}:latest"
                        docker push ${IMAGE_NAME}:latest
                        
                        echo "[INFO] Logging out from Docker Hub..."
                        docker logout
                    """
                }
            }
        }

        stage('5. Deploy to Minikube') {
            steps {
                echo "=========================================="
                echo "Stage 5: Deploying Application to Kubernetes"
                echo "Cluster: Minikube"
                echo "=========================================="
                sh """
                    if [ -f /var/jenkins_home/k8s-kubeconfig ]; then
                        export KUBECONFIG=/var/jenkins_home/k8s-kubeconfig
                    fi
                    echo "[INFO] Applying Kubernetes manifests..."
                    kubectl apply -f k8s/service.yaml -n ${params.K8S_NAMESPACE}
                    
                    # Update deployment image with the newly built immutable tag
                    echo "[INFO] Applying deployment with image ${IMAGE_NAME}:${IMAGE_TAG}..."
                    sed -i 's|image: .*|image: ${IMAGE_NAME}:${IMAGE_TAG}|' k8s/deployment.yaml
                    kubectl apply -f k8s/deployment.yaml -n ${params.K8S_NAMESPACE}
                    
                    echo "[INFO] Waiting for rolling update rollout to complete..."
                    kubectl rollout status deployment/academic-portfolio -n ${params.K8S_NAMESPACE} --timeout=120s
                """
            }
        }

        stage('6. Verify Deployment') {
            steps {
                echo "=========================================="
                echo "Stage 6: Verifying Deployment, Pods & Smoke Testing"
                echo "=========================================="
                sh """
                    if [ -f /var/jenkins_home/k8s-kubeconfig ]; then
                        export KUBECONFIG=/var/jenkins_home/k8s-kubeconfig
                    fi
                    echo "--- Pod Status ---"
                    kubectl get pods -l app=academic-portfolio -n ${params.K8S_NAMESPACE} -o wide
                    
                    echo "--- Service Status ---"
                    kubectl get service academic-portfolio-service -n ${params.K8S_NAMESPACE}
                    
                    echo "--- Deployment Status ---"
                    kubectl get deployment academic-portfolio -n ${params.K8S_NAMESPACE}
                    
                    echo "--- Application-Level HTTP Smoke Test ---"
                    MINIKUBE_IP="192.168.49.2"
                    NODE_PORT=\$(kubectl get svc academic-portfolio-service -n ${params.K8S_NAMESPACE} -o jsonpath='{.spec.ports[0].nodePort}')
                    
                    echo "[INFO] Probing http://\${MINIKUBE_IP}:\${NODE_PORT}/health ..."
                    curl --retry 5 --retry-connrefused --retry-delay 3 -s -f "http://\${MINIKUBE_IP}:\${NODE_PORT}/health" || \
                    kubectl exec -n ${params.K8S_NAMESPACE} deployment/academic-portfolio -- wget -qO- http://127.0.0.1:3000/health
                    
                    echo ""
                    echo "[SUCCESS] Application verified healthy and active on Minikube!"
                """
            }
        }
    }

    post {
        always {
            echo "=========================================="
            echo "Pipeline Run #${env.BUILD_NUMBER} Finished"
            echo "=========================================="
        }
        success {
            echo "SUCCESS: CI/CD Pipeline executed cleanly!"
            echo "Image Tag Deployed: ${IMAGE_NAME}:${IMAGE_TAG}"
        }
        failure {
            echo "FAILURE: Pipeline encountered an error. Gathering diagnostics..."
            sh """
                if [ -f /var/jenkins_home/k8s-kubeconfig ]; then
                    export KUBECONFIG=/var/jenkins_home/k8s-kubeconfig
                fi
                echo "--- Recent Pod Logs ---"
                kubectl logs -l app=academic-portfolio -n ${params.K8S_NAMESPACE} --tail=30 || true
                echo "--- Pod Events ---"
                kubectl describe pods -l app=academic-portfolio -n ${params.K8S_NAMESPACE} || true
            """
        }
    }
}
