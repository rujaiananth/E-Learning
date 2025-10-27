pipeline {
  agent any
  stages {
    stage('Checkout') {
      steps {
        // Checkout this repository where the DSL script lives
        checkout([$class: 'GitSCM', branches: [[name: '*/main']], userRemoteConfigs: [[url: 'https://github.com/rujaiananth/E-Learning']]])
      }
    }

    stage('Run Job DSL') {
      steps {
        // Run the Job DSL script that creates the pipeline job
        jobDsl targets: 'jenkins/job-dsl/create_elearning_pipeline.groovy',
               removedJobAction: 'IGNORE',
               removedViewAction: 'IGNORE'
      }
    }
  }
}
