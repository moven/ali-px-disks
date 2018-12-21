#!/usr/bin/env groovy

podTemplate(label: 'docker',
    containers: [
      containerTemplate(name: 'docker', image: 'docker:18.03', ttyEnabled: true, command: 'cat'),
      containerTemplate(name: 'kubectl-helm', image: 'dtzar/helm-kubectl:2.9.1', ttyEnabled: true, command: 'cat'),
    ],
    volumes: [hostPathVolume(hostPath: '/var/run/docker.sock', mountPath: '/var/run/docker.sock')]
  ) {

    node('docker') {
      def projectName = 'moven'
      def scmVars = checkout scm
      def branchName = scmVars.GIT_BRANCH
      def shortCommit = scmVars.GIT_COMMIT.take(7)
      int unixEpoch = System.currentTimeMillis()/1000
      def buildTag = "${branchName}-${shortCommit}-${unixEpoch}"

      stage('Build Docker Image') {
        container('docker') {
          sh "docker build --no-cache -t moven/${projectName}:${buildTag} ."
        }
      }

      if (!branchName.startsWith("PR-")) {
        stage('Push Docker Image to Registry') {

              def secrets = [
                [$class: 'VaultSecret', path: 'secret/jenkins/docker-registry', secretValues: [
                [$class: 'VaultSecretValue', envVar: 'DOCKER_USERNAME', vaultKey: 'username'],
                [$class: 'VaultSecretValue', envVar: 'DOCKER_PASSWORD', vaultKey: 'password']
                ]]
              ]

            container('docker') {
              wrap([$class: 'VaultBuildWrapper', vaultSecrets: secrets]) {
                sh "docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD"
                sh "docker push moven/${projectName}:${buildTag}"
                }
              }
            }

            milestone()

            def kubeconfig = [
                [$class: 'VaultSecret', path: 'secret/jenkins/tech.kubeconfig', secretValues: [
                    [$class: 'VaultSecretValue', envVar: 'KUBE_TOKEN', vaultKey: 'token'],
                ]]
            ]

            def namespace = "test-core"
            stage("Promote to CI environment: ${namespace}") {
                container('kubectl-helm') {
                    wrap([$class: 'VaultBuildWrapper', vaultSecrets: kubeconfig]) {
                        sh "kubectl config set-cluster ci --server=https://817FA3AE9522FD97B1C89472CB9ACF61.sk1.us-east-1.eks.amazonaws.com --insecure-skip-tls-verify"
                        sh "kubectl config set-credentials ci --token=$KUBE_TOKEN"
                        sh "kubectl config set-context ci --user=ci --cluster=ci --namespace ${namespace}"
                        sh "kubectl config use-context ci"
                        sh "helm upgrade ${projectName} chart/ --install --wait --namespace ${namespace} --set image.tag=${buildTag} --set ingress.hosts[0]=${namespace}.moven.com --set ingress.tls[0].secretName=moven-tls --set ingress.tls[0].hosts[0]=${namespace}.moven.com"
                    }
                }
            }

            stage('Integration Tests') {
                // run integration tests
            }

            stage('Helm Chart') {
                container('kubectl-helm') {
                    println("INFO: checking charts.moven.us for ${projectName}")
                    def chartMuseumResponse = sh (
                        script: "apk -q add --update curl && curl --fail https://charts.moven.us/api/charts/${projectName}",
                        returnStdout: true
                    )
                    println("INFO: ChartMuseum response size: ${chartMuseumResponse.length()}")
                    if (chartMuseumResponse.length() == 0) {
                        println("WARNING: No existing chart for ${projectName}")
                    } else {
                        def currentVersion = new groovy.json.JsonSlurper().parseText(chartMuseumResponse)[0].version
                        def patch = currentVersion.replaceAll(/[0-9]*[.][0-9]*[.]([0-9]*)[0-9A-Za-z-]*/, /$1/).toInteger() + 1
                        def updatedVersion = currentVersion.replaceAll(/([0-9]*)[.]([0-9]*)[.]([0-9]*)([0-9A-Za-z-]*)/, /$1.$2.${patch}$4/)
                        println("INFO ${projectName} current version=${currentVersion}, updated version=${updatedVersion}")
                        sh "sed --in-place --expression='s/^version: .*\$/version: ${updatedVersion}/' chart/Chart.yaml"
                    }

                    // update image.tag
                    sh "sed --in-place --expression='s/^  tag: .*\$/  tag: ${buildTag}/' chart/values.yaml"

                    //install and configure helm client
                    sh "helm init --client-only"
                    sh "helm plugin install https://github.com/chartmuseum/helm-push"
                    sh "helm repo add moven https://charts.moven.us"

                    //need chartmuseum write credentials from vault
                    def helmWriteCreds = [
                        [$class: 'VaultSecret', path: 'secret/jenkins/charts.moven.us', secretValues: [
                            [$class: 'VaultSecretValue', envVar: 'HELM_REPO_USERNAME', vaultKey: 'username'],
                            [$class: 'VaultSecretValue', envVar: 'HELM_REPO_PASSWORD', vaultKey: 'password'],
                        ]]
                    ]

                    wrap([$class: 'VaultBuildWrapper', vaultSecrets: helmWriteCreds]) {
                        //push new chart version to chart museum"
                        sh "helm push chart/ moven"
                    }
                    println("INFO: helm push complete!")
                }
                milestone()
            }
            

            stage('Promote to Staging environment(s)') {
                println "To promote this to built to a staging envionment: helm upgrade ${projectName} moven/${projectName} --install --wait --set image.tag=${buildTag}"
          }
        }
    }
}
