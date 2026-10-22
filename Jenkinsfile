pipeline {
    agent any

    environment {
        DOCKER_IMAGE = "kurellapoojitha/foodwaste"
    }

    stages {
        stage('Clone Code') {
            steps {
                // FIXED: Changed url from 'https://github.com' to your full repository endpoint
                git branch: 'main',
                    url: 'https://github.com'
                
                bat 'git log -1 --oneline'
            }
        }

        stage('Parallel Application Tests') {
            parallel {
                stage('HTML Validation') {
                    steps {
                        bat '''
                        if not exist index.html exit /b 1
                        findstr /I /C:"Food Waste Tracking" index.html
                        if errorlevel 1 exit /b 1
                        findstr /I /C:"Available" index.html
                        if errorlevel 1 exit /b 1
                        findstr /I /C:"Redistributed" index.html
                        if errorlevel 1 exit /b 1
                        '''
                    }
                }
                stage('Deployment File Validation') {
                    steps {
                        bat '''
                        if not exist Dockerfile exit /b 1
                        if not exist deployment.yaml exit /b 1
                        if not exist Jenkinsfile exit /b 1
                        findstr /I /C:"FROM nginx" Dockerfile
                        if errorlevel 1 exit /b 1
                        findstr /I /C:"kind: Deployment" deployment.yaml
                        if errorlevel 1 exit /b 1
                        '''
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                bat 'docker build --pull -t %DOCKER_IMAGE%:%BUILD_NUMBER% .'
                bat 'docker tag %DOCKER_IMAGE%:%BUILD_NUMBER% %DOCKER_IMAGE%:latest'
            }
        }

        stage('Archive Build Artifacts') {
            steps {
                archiveArtifacts artifacts: 'index.html, Dockerfile, deployment.yaml', allowEmptyArchive: false
            }
        }

        stage('Push Docker Image') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-poojitha',
                    usernameVariable: 'USER',
                    passwordVariable: 'PASS'
                )]) {
                    bat 'docker login -u %USER% -p %PASS%'
                    bat 'docker push %DOCKER_IMAGE%:%BUILD_NUMBER%'
                    bat 'docker push %DOCKER_IMAGE%:latest'
                }
            }
        }
    }
}
