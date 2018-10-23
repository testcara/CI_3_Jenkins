Introduction
===
The project is used to track the CI_3 JJB files.
[JJB(Jenkins Job Builder)](https://media.readthedocs.org/pdf/jenkins-job-builder/latest/jenkins-job-builder.pdf) takes simple descriptions of Jenkins jobs in YAML or JSON format and uses them to configure Jenkins. We create JJB files to make sure CI_3 of Errata QE can be maintained well and migrated easily across different Jenkins.

Files list and Descriptions
===
- create_virtual_env_and_jjb_jobs.sh # Prepare virtual env to run JJB to test/update/create/delete Jenkins jobs
- etc # JJB configuration files
  - jenkins_jobs.ini
- monitor_ci_slaves # jenkins project 'monitor_ci_slaves'
  - monitor_ci_slaves.yaml  # The jenkins job yaml file
  - monitor_slaves.sh # Files for monitor_ci_slaves jenkins jobs
- requirement.txt # The requirement file to create python virtual environment for JJB
