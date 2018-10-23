#!/bin/bash
set -eo pipefail

debug_mode=false
debug_useage() {
  username=$1
  password=$2
  et_build_name_or_id=$3
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

run_ansible(){
	ansible_command=""
	set -x
	env
	cd ${WORKSPACE}/playbooks/errata-tool
	make clean-roles
	make qe-roles
	e2e_env_workaround
	${ansible_command}
}

if [[ "${debug_mode}" == "true" ]]; then
  debug_useage $1 $2 $3
fi

tmp_dir="/tmp/$(date +'%s')"
prepare_scripts ${tmp_dir}
source ${tmp_dir}/RC_CI-master/auto_testing_CI/CI_Shell_prepare_env_and_scripts.sh
source  ${tmp_dir}/RC_CI-master/auto_testing_CI/CI_Shell_common_usage.sh
et_build_version=""
install_scripts_env
et_build_version=$(initial_et_build_version ${et_build_name_or_id})

downgrade_flag="false"
ansible_command=""
need_initalize=$(check_et_for_initial_et_ci ${1})
if [[ "${need_initalize}" == "false" ]]; then
	echo "=== There is no need to do the initalize ==="
	exit
elif [[ "${need_initalize}" == "downgrade" ]]; then
	downgrade_flag="true"
fi

# when the script runs here, it means we need to deploy the enviroments with the product version
# The deploy process is:
# for perf env: restore the db, then deploy the env, then update the settings and restart the services
# for e2e env: ansible workaround, deploy the env, then update the settings and restart the services
# for others: deploy the env, then update the settings and restart the services

perf_restore_db ${ET_Testing_Server}
get_ansible_commands ${ET_Testing_Server}  ${et_build_version} ${downgrade_flag}
run_ansible
update_setting ${ET_Testing_Server}
restart_service ${ET_Testing_Server}
