pipeline {
  agent any

  environment {
    COMPOSE = "docker compose -f docker-compose.prod.yml --env-file versions.env --env-file .env"
  }

  stages {
    stage('checkout') {
      steps {
        checkout scm
      }
    }

    stage('secrets') {
      steps {
        withCredentials([file(credentialsId: 'stays-prod-env', variable: 'SECRETS')]) {
          sh 'install -m 600 "$SECRETS" .env'
        }
      }
    }

    stage('validate') {
      steps {
        sh '$COMPOSE config --quiet'
      }
    }

    stage('pull') {
      steps {
        sh '$COMPOSE pull'
      }
    }

    stage('deploy') {
      steps {
        sh '$COMPOSE up -d --remove-orphans'
      }
    }

    stage('status') {
      steps {
        sh '$COMPOSE ps'
      }
    }
  }

  post {
    always {
      sh 'rm -f .env'
    }
  }
}
