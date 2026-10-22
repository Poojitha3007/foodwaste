
pipeline {
    agent any

    parameters {
        booleanParam(
            name: 'DEPLOY_TO_K8S',
            defaultValue: true,
            description: 'Deploy the application to Kubernetes'
        )

        booleanParam(
            name: 'INTRODUCE_FAILURE',
            defaultValue: false,
            description: 'Test a faulty rollout and automatic rollback'
        )
    }

    environment {
        DOCKER_IMAGE = 'kurellapoojitha/foodwaste'
        DOCKER_CREDENTIALS = 'dockerhub-poojitha'
        KUBE_CREDENTIALS = 'kuberconfig'
    }

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    stages {
        stage('Clone Code') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/Poojitha3007/foodwaste.git'

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
                bat '''
                docker build --pull -t %DOCKER_IMAGE%:%BUILD_NUMBER% .
                docker tag %DOCKER_IMAGE%:%BUILD_NUMBER% %DOCKER_IMAGE%:latest
                '''
            }
        }

        stage('Archive Build Artifacts') {
            steps {
                archiveArtifacts(
                    artifacts: 'index.html,Dockerfile,Jenkinsfile,deployment.yaml',
                    fingerprint: true
                )
            }
        }

        stage('Push Docker Image') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: "${DOCKER_CREDENTIALS}",
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )
                ]) {
                    bat '''
                    @echo off
                    echo %DOCKER_PASS% | docker login -u %DOCKER_USER% --password-stdin
                    if errorlevel 1 exit /b 1

                    docker push %DOCKER_IMAGE%:%BUILD_NUMBER%
                    if errorlevel 1 exit /b 1

                    docker push %DOCKER_IMAGE%:latest
                    if errorlevel 1 exit /b 1

                    docker logout
                    '''
                }
            }
        }

        stage('Verify Local Container') {
            steps {
                bat '''
                docker rm -f foodwaste-test 2>NUL
                docker run -d --name foodwaste-test -p 18080:80 %DOCKER_IMAGE%:%BUILD_NUMBER%
                if errorlevel 1 exit /b 1

                powershell -NoProfile -Command "$ok = $false; for ($i=0; $i -lt 12; $i++) { try { $r = Invoke-WebRequest -Uri 'http://localhost:18080/' -UseBasicParsing -TimeoutSec 3; if ($r.StatusCode -eq 200 -and $r.Content.Contains('Food Waste Tracking')) { $ok = $true; break } } catch {}; Start-Sleep -Seconds 2 }; if (-not $ok) { exit 1 }"
                if errorlevel 1 exit /b 1

                docker rm -f foodwaste-test
                '''
            }
        }

        stage('Deploy to Kubernetes') {
            when {
                expression {
                    return params.DEPLOY_TO_K8S
                }
            }

            steps {
                withCredentials([
                    file(
                        credentialsId: "${KUBE_CREDENTIALS}",
                        variable: 'KUBECONFIG'
                    )
                ]) {
                    script {
                        def stableImage =
                            "${env.DOCKER_IMAGE}:${env.BUILD_NUMBER}"

                        def deploymentImage = params.INTRODUCE_FAILURE
                            ? "${env.DOCKER_IMAGE}:faulty-${env.BUILD_NUMBER}"
                            : stableImage

                        withEnv([
                            "DEPLOY_IMAGE=${deploymentImage}",
                            "STABLE_IMAGE=${stableImage}"
                        ]) {
                            bat '''
                            powershell -NoProfile -Command "$yaml = Get-Content deployment.yaml -Raw; $yaml = $yaml.Replace('kurellapoojitha/foodwaste:latest', $env:DEPLOY_IMAGE); Set-Content -Path deployment-rendered.yaml -Value $yaml -Encoding ascii"

                            kubectl --kubeconfig "%KUBECONFIG%" apply -f deployment-rendered.yaml
                            if errorlevel 1 exit /b 1
                            '''

                            if (params.INTRODUCE_FAILURE) {
                                echo 'Fault injection enabled: waiting for the invalid image rollout to fail.'

                                int faultyStatus = bat(
                                    returnStatus: true,
                                    script: '''
                                    kubectl --kubeconfig "%KUBECONFIG%" rollout status deployment/foodwaste-portal --timeout=90s
                                    '''
                                )

                                if (faultyStatus == 0) {
                                    error('The deliberately faulty rollout unexpectedly succeeded. Check the test setup.')
                                }

                                echo 'Failed rollout detected. Rolling back to the previous stable Kubernetes revision.'

                                bat '''
                                kubectl --kubeconfig "%KUBECONFIG%" rollout undo deployment/foodwaste-portal
                                if errorlevel 1 exit /b 1
                                '''

                                bat '''
                                kubectl --kubeconfig "%KUBECONFIG%" rollout status deployment/foodwaste-portal --timeout=180s
                                if errorlevel 1 exit /b 1
                                '''

                                bat '''
                                kubectl --kubeconfig "%KUBECONFIG%" get deployment foodwaste-portal
                                kubectl --kubeconfig "%KUBECONFIG%" get pods -l app=foodwaste-portal
                                kubectl --kubeconfig "%KUBECONFIG%" get service foodwaste-portal-service
                                '''

                                echo 'Rollback completed. The restored deployment is healthy.'
                            } else {
                                bat '''
                                kubectl --kubeconfig "%KUBECONFIG%" rollout status deployment/foodwaste-portal --timeout=180s
                                if errorlevel 1 exit /b 1

                                kubectl --kubeconfig "%KUBECONFIG%" get deployment foodwaste-portal
                                kubectl --kubeconfig "%KUBECONFIG%" get pods -l app=foodwaste-portal
                                '''

                                echo "Successfully deployed ${stableImage}"
                            }
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            bat 'docker rm -f foodwaste-test 2>NUL'
            echo 'Food Waste Portal CI/CD pipeline finished.'
        }

        success {
            echo 'Build, tests and requested deployment/rollback checks succeeded.'
        }

        failure {
            echo 'Pipeline failed. Review Jenkins Console Output for the failing stage.'
        }
    }
}
