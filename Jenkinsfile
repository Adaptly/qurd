#!/usr/bin/env groovy
def releases = [:]
def chartReleases = [:]
def kubectlContext = ''

pipeline {
  agent none 
  libraries {
    lib('adaptly')
  }
  options {
    timestamps()
  }
  stages {
    stage('build') {
      when { not { changeRequest() } }
      stages {
        stage('staging') {
          when { branch 'master' }
          environment {
            A5Y_ENV = 'staging'
          }

          stages {

            // env vars only persist within the stage block they're defined in
            stage('set kubectlContext') {
              steps { script { kubectlContext = env.A5Y_ENV } }
            }

            stage('qurd') {
              environment {
                IMAGE_NAME = 'qurd'
              }
              steps {
                script {
                  buildTemplate() {
                    gitCheckout()
                    chartReleases[env.IMAGE_NAME] = kubectlChartReleases(image: env.IMAGE_NAME,
                                                                         kubectlContext: env.A5Y_ENV)
                    releases[env.IMAGE_NAME] = buildPushImage(buildEnv: env.A5Y_ENV)
                  }
                }
              }

            }
          }
        }

        stage('zoo') {
          when { not { branch 'master' } }
          environment {
            A5Y_ENV = 'zoo'
          }

          stages {
            // env vars only persist within the stage block they're defined in
            stage('set kubectlContext') {
              steps { script { kubectlContext = env.A5Y_ENV } }
            }

            stage('qurd') {
              environment {
                IMAGE_NAME = 'qurd'
              }
              steps {
                script {
                  buildTemplate() {
                    gitCheckout()
                    chartReleases[env.IMAGE_NAME] = kubectlChartReleases(image: env.IMAGE_NAME,
                                                                         kubectlContext: env.A5Y_ENV)
                    releases[env.IMAGE_NAME] = buildPushImage(buildEnv: env.A5Y_ENV)
                  }
                }
              }
            }
          }
        }
      }
    }

    stage('pull request') {
      when { changeRequest() }
      steps {
        unitTests(image: 'ruby', tag: '2.4-buster', branch: env.CHANGE_BRANCH, repo: 'qurd')
      }
    }

  }

  post {
    success {
      script {
        releases.each { image, sha ->
          echo "deploying ${image}:${sha} to ${kubectlContext} branch ${env.GIT_BRANCH}"
          buildHelmDeployImage(
            kubectlContext: kubectlContext,
            kubernetesGitBranch: env.GIT_BRANCH,
            imageTag: sha,
            releases: chartReleases[image],
          )
          notifySlack(status: 'success',
                      message: "SUCCESSFUL: Job ${env.JOB_NAME} " +
                               "[${image}:${sha}, ${env.BUILD_NUMBER}] (${env.BUILD_URL})")
        }
      }
    }

    failure {
      notifySlack(status: 'failure',
                  message: "FAILURE: Job ${env.JOB_NAME} " +
                           "[${env.BUILD_NUMBER}] (${env.BUILD_URL})")
    }
  }
}

