// CI/CD pipeline: Test -> Build -> Scan -> Push -> Deploy -> Smoke test
// Environment variables (AWS_REGION, ECR_REPO_URL, ECS_CLUSTER, ECS_SERVICE, APP_URL, MIN_TASKS)
// are injected into Jenkins by Terraform via Configuration as Code. AWS access uses the
// instance IAM role - there are no stored AWS credentials.
pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
    timeout(time: 30, unit: 'MINUTES')
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }

  stages {
    stage('Prepare') {
      steps {
        script {
          env.IMAGE_TAG = sh(returnStdout: true, script: 'git rev-parse --short=8 HEAD').trim()
          env.IMAGE_URI = "${env.ECR_REPO_URL}:${env.IMAGE_TAG}"
        }
        echo "Building ${env.IMAGE_URI}"
      }
    }

    stage('Test') {
      steps {
        // The Dockerfile 'test' stage runs `npm test`; a failing test fails the build.
        sh 'docker build --target test -t app-test:${IMAGE_TAG} app/'
      }
    }

    stage('Build') {
      steps {
        sh 'docker build --target runtime --build-arg APP_VERSION=${IMAGE_TAG} -t ${IMAGE_URI} app/'
      }
    }

    stage('Security scan') {
      steps {
        // Fail on fixable CRITICAL vulnerabilities in the final image
        sh '''
          docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v trivy-cache:/root/.cache \
            aquasec/trivy:0.58.1 image \
            --exit-code 1 --severity CRITICAL --ignore-unfixed --no-progress \
            ${IMAGE_URI}
        '''
      }
    }

    stage('Push to ECR') {
      steps {
        sh '''
          aws ecr get-login-password --region ${AWS_REGION} \
            | docker login --username AWS --password-stdin ${ECR_REPO_URL%%/*}

          REPO_NAME=${ECR_REPO_URL#*/}
          if aws ecr describe-images --region ${AWS_REGION} --repository-name ${REPO_NAME} \
               --image-ids imageTag=${IMAGE_TAG} >/dev/null 2>&1; then
            echo "Image ${IMAGE_TAG} already in ECR (tags are immutable) - skipping push"
          else
            docker push ${IMAGE_URI}
          fi
        '''
      }
    }

    stage('Deploy to ECS') {
      steps {
        sh './scripts/deploy.sh'
      }
    }

    stage('Smoke test') {
      steps {
        // -k: the ALB DNS name will not match a custom-domain certificate if HTTPS is enabled
        sh '''
          for i in $(seq 1 12); do
            VERSION=$(curl -fsSk ${APP_URL}/ | jq -r .version || true)
            if [ "$VERSION" = "${IMAGE_TAG}" ]; then
              echo "Smoke test passed: version ${VERSION} is live"
              curl -fsSk ${APP_URL}/health
              exit 0
            fi
            echo "Waiting for ${IMAGE_TAG} (currently '${VERSION}')..."
            sleep 10
          done
          echo "Smoke test failed"; exit 1
        '''
      }
    }
  }

  post {
    success { echo "Deployed ${env.IMAGE_URI} to ${env.APP_URL}" }
    failure { echo 'Pipeline failed - ECS automatically keeps/rolls back to the last healthy revision.' }
    always {
      sh 'docker image prune -f || true'
      cleanWs()
    }
  }
}
