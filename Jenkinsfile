pipeline {
  agent {
    kubernetes {
      yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: hextris-deploy
spec:
  containers:
    - name: terraform
      image: hashicorp/terraform:1.9
      command: [ "cat" ]
      tty: true
    - name: ssh
      image: alpine:latest
      command: [ "cat" ]
      tty: true
"""
    }
  }

  parameters {
    string(name: 'REMOTE_HOST', description: 'Public IP or hostname of the target VM')
    string(name: 'SSH_USER', defaultValue: 'ubuntu', description: 'SSH username')
  }

  environment {
    TF_DIR = 'terraform'
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Terraform Init & Apply') {
      steps {
        container('terraform') {
          withCredentials([sshUserPrivateKey(credentialsId: 'vm_ssh_key', keyFileVariable: 'SSH_KEY_PATH')]) {
            sh '''
              cd ${TF_DIR}
              terraform init -input=false

              # Timestamp unique pour forcer la reprovision
              TS=$(date +%s)

              terraform apply -auto-approve \
                -var "remote_host=${REMOTE_HOST}" \
                -var "ssh_user=${SSH_USER}" \
                -var "ssh_private_key=$(cat $SSH_KEY_PATH)" \
                -var "timestamp=$TS"
            '''
          }
        }
      }
    }

    stage('Retrieve setup logs') {
      steps {
        container('ssh') {
          sh 'apk add --no-cache openssh-client'  // Installe le client SSH
          withCredentials([sshUserPrivateKey(credentialsId: 'vm_ssh_key', keyFileVariable: 'SSH_KEY_PATH')]) {
            sh '''
              mkdir -p ${TF_DIR}/logs
              LOG_FILE=${TF_DIR}/logs/hextris_setup_$(date +%s).txt

              echo "Retrieving /var/log/hextris_setup.log from ${REMOTE_HOST}..."
              ssh -o StrictHostKeyChecking=no -i $SSH_KEY_PATH ${SSH_USER}@${REMOTE_HOST} "sudo cat /var/log/hextris_setup.log" > $LOG_FILE || echo "⚠️ Log not found."

              echo "Showing last 20 lines of log for preview:"
              tail -n 20 $LOG_FILE || true
            '''
          }
        }
      }
    }
  }

  post {
    success {
      echo "Hextris successfully deployed at: http://${params.REMOTE_HOST}"
      sh '''
        echo "----- Last 30 lines of Hextris setup log -----"
        tail -n 30 terraform/logs/*.txt || true
        echo "---------------------------------------------"
      '''
    }
    always {
      node ('any') {
        echo "Archiving setup logs..."
        archiveArtifacts artifacts: 'terraform/logs/*.txt', fingerprint: true, allowEmptyArchive: true
      }
    }
  }
}

