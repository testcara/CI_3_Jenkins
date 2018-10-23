Introduction
===
The project is used to track Jenkins related files for [CI3](https://gitlab.cee.redhat.com/wlin/CI3), like [JJB](https://media.readthedocs.org/pdf/jenkins-job-builder/latest/jenkins-job-builder.pdf) files, Jenkinsfile for [pipeline](https://jenkins.io/doc/book/pipeline/) and Jenkins shell scripts.

CI3 Jenkins Desgin
===
- All Jenkins job are tracked by JJB files
- The build strategy of high-level Jenkins jobs are pipelines
- The nodes of Jenkins Job are instant containers
- Some shell scripts are used to call CI3 basic python libs
- Some shell scripts are used to call ansible staffs

Files list and Descriptions
===
- CI3_Jenkinsfiles
  - bug_regression_testing # specific testing type
    - Jenkinsfile  # Jenkinsfiles for the specifc testing type
  - perf_testing
    - Jenkinsfile
  - and so on
    - Jenkinsfile
- CI3_Jenkins_shell_scripts # shell scripts used by Jenkins
  - CI_Shell_common_usage.sh
  - CI_Shell_Upgrade_Pulp_Pub.sh
  - and so on
- CI3_JJB
  - create_virtual_env_and_jjb_jobs.sh # Prepare virtual env to run JJB to test/update/create/delete Jenkins jobs
  - etc # JJB configuration files
  - jenkins_jobs.ini
  - requirement.txt # The requirement file to create python virtual environment for JJB
  - bug_regression_pipline # specific testing type
    - bug_regression_pipline.yaml  # JJB YAML file for the specifc testing type
  - and so on
