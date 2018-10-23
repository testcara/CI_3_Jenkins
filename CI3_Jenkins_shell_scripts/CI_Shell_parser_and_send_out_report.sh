#!/bin/bash
set -eo pipefail

debug_mode=true
debug_useage() {
  username=$1
  password=$2
  et_build_name_or_id=$3
  space='~wlin'
  parent_page=30869307
  send_report_ci_name="Send_Testing_Report"
}

prepare_scripts(){
  mkdir -p ${1}
  cd ${1}
  echo "===============Download the CI files under $(pwd)=========="
  wget http://github.com/testcara/RC_CI/archive/master.zip
  unzip master.zip
  cd ${1}/RC_CI-master/auto_testing_CI
  # first check the page exists or not, if not, generate for all content
  echo "==============All files had beeen Download==============="
  echo "=============Firstly, let us check the page existing or not"
}

if [[ "${debug_mode}" == "true" ]]; then
  debug_useage $1 $2 $3
fi

tmp_dir="/tmp/$(date +'%s')"
prepare_scripts ${tmp_dir}
source CI_Shell_prepare_env_and_scripts.sh
source CI_Shell_common_usage.sh
clean_env_mess
et_build_version=""
install_scripts_env
et_build_version=$(initial_et_build_version ${et_build_name_or_id})
title="ET Testing Reports For Build ${et_build_version}"
echo "===== Title ==="
echo ${title}
sudo python talk_to_jenkins_to_parser_results_and_send_reports.py ${username} ${password} ${et_build_version} "${title}" "${space}" "${send_report_ci_name}"
clean_env_mess
echo "====done==="