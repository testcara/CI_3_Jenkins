#!/bin/bash +x
install_scripts_env() {
	sudo pip install --upgrade pip
	sudo pip install confluence-py
	sudo pip install python-jenkins
	if [[ $(wget --version | head -1) =~ "GNU Wget" ]]; then
		echo "=====wget has been installed======";
	else
		echo "=====wget has not been installed, Would intall git======"
		sudo yum install wget -y
	fi
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

et_build_version=""
initial_et_build_version
install_scripts_env
tmp_dir="/tmp/$(date +'%s')"
mkdir -p ${tmp_dir}
cd ${tmp_dir}
# Wget the files
echo "===============Download the CI files under $(pwd)=========="
wget http://github.com/testcara/RC_CI/archive/master.zip
unzip master.zip
cd ${tmp_dir}/RC_CI-master/auto_testing_CI
# Run the script
echo "==============Start the testing==============="
echo sudo python talk_to_rc_jenkins_to_manage_TS2_testing.py ${username} ${password} ${CI_1_ts2_uat_jenkins_build_name} ${et_build_version} ${ts2_uat_expect_run_time}
sudo python talk_to_rc_jenkins_to_manage_TS2_testing.py ${username} ${password} ${CI_1_ts2_uat_jenkins_build_name} ${et_build_version} ${ts2_uat_expect_run_time}
testing_result_code=$(echo $?)
if [[ ${testing_result_code} -gt 0 ]]; then
	exit ${testing_result_code}
fi

echo "====removing the useless files===="
rm -rf ${tmp_dir}