#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

script_dir=""
install_scripts_env(){
	sudo pip install --upgrade pip
	sudo pip install confluence-py
	sudo pip install python-jenkins
	sudo pip install scp
	yum install wget -y
	yum install git -y
}

initial_et_build_version(){
	if [[ ${et_build_name_or_id} =~ "-" ]]; then
		echo "=== ET build name has been provided: ${et_build_name} =="
		et_build_version=$( echo ${et_build_name_or_id} | cut -d '-' -f 2| cut -d '.' -f 2 )
	else
		echo "=== ET build id is provided =="
		et_build_version=${et_build_name_or_id}
	fi
}

download_ci_scripts(){
	tmp_dir="/tmp/$(date +'%s')"
	mkdir -p ${tmp_dir}
	cd ${tmp_dir}
	echo "===============Download the CI files under $(pwd)=========="
	wget http://github.com/testcara/RC_CI/archive/master.zip
	unzip master.zip
	cd ${tmp_dir}/RC_CI-master/auto_testing_CI
	script_dir=$(pwd)
}

run_target_scripts(){
	sudo python ${script_dir}/talk_to_rc_jenkins_to_parser_perf_report.py ${username} ${password} ${et_build_version} ${tolerance} ${perf_jmeter_slave_server}
}

clean_mess(){
	rm -rf ${script_dir}/*.json

}

install_scripts_env
initial_et_build_version
download_ci_scripts
run_target_scripts
clean_mess