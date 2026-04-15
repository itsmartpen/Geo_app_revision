
pipeline{
    agent any 
    tools {
        maven 'M2_HOME'
    }
    environment {
      AWS_REGION = 'us-east-1'
      SCANNER_HOME= tool 'sonar'
      ARTIFACTORY_URL=  'http://54.90.160.188:8081/artifactory'
      REPO = 'geolocation'
      APP_NAME = 'geoapp'
      APP_OWNER = 'cloud_team'
      DOCKER_REPO_NAME = "${APP_NAME}"
      REPO_URL     = 'public.ecr.aws/g0j7o9l5'
      DOCKER_REPO = "${REPO_URL}/${DOCKER_REPO_NAME}"
      BRANCH_NAME= 'main'
      GIT_CRED = 'GITHUB_CRED'
      KUBERNETES_CRED = 'KUBERNETES_CRED'
      KUBERNETES_URL = 'https://104.237.133.213:6443'
      SONAQUBE_CRED = 'sonarqube_ID'
      SONAQUBE_INSTALLATION = 'Sonarqube'
      JFROG_CRED = 'j_frog-cred'
      PROJECT_URL = 'https://github.com/kserge2001/cicd-code.git'
      ARTIFACTPATH = 'target/*.jar'
      ARTIFACTTARGETPATH = "release_${BUILD_ID}.jar"
      HELMARTIFACTPATH = "geoapp-${BUILD_ID}.tgz"
      HELMARTIFACTTARGET = "heml/geoapp-${BUILD_ID}.tgz"

    }
    stages{
        stage('Git Checkout'){
            steps{
                git branch: "${BRANCH_NAME}", credentialsId: "${GIT_CRED}", \
                url: "${PROJECT_URL}"
            }
        }
       
        // this stage is for test
        stage('Unit Test'){
            steps{
                sh 'mvn clean'
                sh 'mvn compile '
                sh 'mvn test'
            }
        }
        
        stage('Sonarqube Scan'){
            steps{
                withSonarQubeEnv(credentialsId: "${SONAQUBE_CRED}", \
                installationName: "${SONAQUBE_INSTALLATION}" ) {
              sh ''' $SCANNER_HOME/bin/sonar-scanner -Dsonar.projectName=${APP_NAME} -Dsonar.projectKey=${APP_NAME} \
                   -Dsonar.java.binaries=. '''
}
            }
        }
        stage('Quality Gate Check'){
            steps{
              script{
                 waitForQualityGate abortPipeline: false, credentialsId: "${SONAQUBE_CRED}" 
              }
            }
        }
        
        stage('Trivy Scan'){
            steps{
                 sh "trivy fs --format table -o maven_dependency.html ."
            }
        }
       
     
        stage('Code Package'){
            steps{
                sh 'mvn package'
            }
        }
      
        stage('Upload Jar to Jfrog'){
            steps{
                withCredentials([usernamePassword(credentialsId: "${JFROG_CRED}", \
                 usernameVariable: 'ARTIFACTORY_USER', passwordVariable: 'ARTIFACTORY_PASSWORD')]) {
                    script {
                        // Define the artifact path and target location
                        //def artifactPath = 'target/*.jar'
                        //def targetPath = "release_${BUILD_ID}.jar"

                        // Upload the artifact using curl
                        sh """
                            curl -u ${ARTIFACTORY_USER}:${ARTIFACTORY_PASSWORD} \
                                 -T ${ARTIFACTPATH} \
                                 ${ARTIFACTORY_URL}/${REPO}/${ARTIFACTTARGETPATH}
                        """
            }
        }
    }

}

    stage('Docker image Build'){
        steps{
            script{
           sh "docker build --no-cache -t ${DOCKER_REPO}:latest ."
           sh "docker build --no-cache -t ${DOCKER_REPO}:${BUILD_ID} ."
            }
           
        }
    }
  
    stage('Scan Docker Image'){
        steps{
          sh """trivy image --format table -o docker_image_report.html ${DOCKER_REPO}:${BUILD_ID}"""
  
        }
    }
  
    stage('Push Image To Registry'){
        steps{
          script{
        //def ecr_passwrd=sh(script: "aws ecr-public get-login-password --region 'us-east-1'")
         //sh "docker login --username AWS --password ${ecr_passwrd} public.ecr.aws/g0j7o9l5"   
        sh "aws ecr-public get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${REPO_URL}"
        sh "docker push ${DOCKER_REPO}:latest "
        sh "docker push ${DOCKER_REPO}:${BUILD_ID} "
        }
    }
    }

    stage('Chart Version Update'){
        steps{
         sh "python3 setup_scripts/chartUpdate.py ${BUILD_ID}" 
           
        }
    }
    stage('Package Helm'){
        steps{
            sh 'helm package geoapp'
        }
    }

    stage('Upload helm package to Jfrog'){
            steps{
                 withCredentials([usernamePassword(credentialsId: "${JFROG_CRED}", \
                 usernameVariable: 'ARTIFACTORY_USER', passwordVariable: 'ARTIFACTORY_PASSWORD')]) {
                    script {
                        // Define the artifact path and target location
                        //def artifactPath = 'geo-app-${BUILD_ID}.tgz'
                        //def targetPath = "heml/geo-app-${BUILD_ID}.tgz"

                        // Upload the artifact using curl
                        sh """
                            curl -u ${ARTIFACTORY_USER}:${ARTIFACTORY_PASSWORD} \
                                 -T ${HELMARTIFACTPATH} \
                                 ${ARTIFACTORY_URL}/${REPO}/${HELMARTIFACTTARGET}
                        """
            }
        }
    }
    

}

stage('Deploy helm to k8s'){
    steps{
        kubeconfig(credentialsId: "${KUBERNETES_CRED}" ,caCertificate: '', serverUrl: "${KUBERNETES_URL}") {
    
   // sh 'helm rollback geo -n dev'
   // sh 'sleep 60'
   sh 'kubectl delete secret -l owner=helm,name=geo -n dev'
    sh 'helm upgrade --install geo geoapp -n dev'
    

    }
  }
}
 
    }
    
    post {
    always {
        script {
            def jobName = env.JOB_NAME
            def buildNumber = env.BUILD_NUMBER
            def pipelineStatus = currentBuild.result ?: 'SUCCESS'
            def bannerColor = pipelineStatus == 'SUCCESS' ? 'green' : 'red'

            def body = """
                <html>
                <body>
                <div style="border: 4px solid ${bannerColor}; padding: 10px;">
                <h2>${jobName} - Build ${buildNumber}</h2>
                <div style="background-color: ${bannerColor}; padding: 10px;">
                <h3>Please see attached report </h3>
                <h3 style="color: white;">Pipeline Status: ${pipelineStatus}</h3>
                </div>
                <p>Check the <a href="${BUILD_URL}">console output</a>.</p>
                </div>
                </body>
                </html>
            """

            emailext (
                subject: "${jobName} - Build ${buildNumber} - ${pipelineStatus}",
                body: body,
                to: 'unixclassd1@gmail.com',
                from: 'unixclassd1@gmail.com',
                replyTo: 'jenkins@example.com',
                mimeType: 'text/html',
                attachmentsPattern: 'maven_dependency.html, docker_image_report.html'
            )
        }
        
    }
    failure {
        script {
            def jobName = env.JOB_NAME
            def buildNumber = env.BUILD_NUMBER
            def pipelineStatus = currentBuild.result ?: 'SUCCESS'
            def bannerColor = pipelineStatus == 'SUCCESS' ? 'green' : 'red'

            def body = """
                <html>
                <body>
                <div style="border: 4px solid ${bannerColor}; padding: 10px;">
                <h2>${jobName} - Build ${buildNumber}</h2>
                <div style="background-color: ${bannerColor}; padding: 10px;">
                <h3 style="color: white;">Pipeline Status: ${pipelineStatus}</h3>
                </div>
                <p>Check the <a href="${BUILD_URL}">console output</a>.</p>
                </div>
                </body>
                </html>
            """

            emailext (
                subject: "${jobName} - Build ${buildNumber} - ${pipelineStatus}",
                body: body,
                to: 'unixclassd1@gmail.com',
                from: 'unixclassd1@gmail.com',
                replyTo: 'jenkins@example.com',
                mimeType: 'text/html',
                attachmentsPattern: 'maven_dependency.html, docker_image_report.html'
            )
        }
     }
    
    } 
   
}

