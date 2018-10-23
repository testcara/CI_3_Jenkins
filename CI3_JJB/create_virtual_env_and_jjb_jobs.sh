#!/bin/bash
# The script is used to prepare the virtual enviroment for JJB.
# 2 parameters are needed:
#  1): JJB action like 'test' 'update' 'delete'
#  2): Jenkins YAML or JSON file of your target jenkins job
# The general usesage demo: filename.sh test ci_job_1.yaml
# Note: 'PATHONHTTPSVERIFY=1' ignores the ssl check of your target jenkins.

set -ef
if ! [[ -s "jjb_project_virtualenv" ]];
then

	virtualenv jjb_project_virtualenv
fi
source jjb_project_virtualenv/bin/activate
pwd
pip install -r requirement.txt
sleep 10
PATHONHTTPSVERIFY=1 jenkins-jobs --conf etc/jenkins_jobs.ini "$1" "$2"