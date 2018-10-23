initial_et_build_id(){
	if [[ "${1}" =~ 'git' ]]; then
		et_build_id=$( echo "${1}" | cut -d '-' -f 2| cut -d '.' -f 2 )
	elif [[ "${1}" =~ '-' ]]; then
		et_build_id=$(echo "${1}" | cut -d '-' -f 1 | sed 's/\.//g')
	else
		et_build_id=${1}
	fi
	echo "${et_build_id}"
}

initial_et_build_version(){
	echo "${1}" | cut -d "-" -f 1 | sed 's/\.//g'
}

get_system_raw_version(){
	curl http://"${1}"/system_version.json | sed 's/"//g'
}

get_et_product_version(){
	et_product_version_on_brew=$(get_system_raw_version "${1}")
	et_product_version=$(initial_et_build_version "${et_product_version_on_brew}")
	echo "${et_product_version}"
}

get_deployed_et_version(){
	et_testing_server_raw_version=$(get_system_raw_version "${1}")
	et_testing_server_version=$(initial_et_build_version "${et_testing_server_raw_version}")
	echo "${et_testing_server_version}"
}

get_deployed_et_id(){
	et_testing_server_raw_version=$(get_system_raw_version "${1}")
	et_testing_server_version_id=$(initial_et_build_id "${et_testing_server_raw_version}")
	echo "${et_testing_server_version_id}"
}

get_ansible_commands_with_product_et_version(){
	ansible_command_part_1="ansible-playbook -vv --user root --skip-tags 'et-application-config'"
	ansible_command_part_2=" --limit ${1} -e errata_version=${2} -e errata_fetch_brew_build=true"
	ansible_command_part_3=""
	if [[ "${3}" == "downgrade" ]]
    then
		ansible_command_part_3="-e errata_downgrade=true"
	fi
	ansible_command_part_4=" playbooks/errata-tool/qe/deploy-errata-qe.yml"
	ansible_command="${ansible_command_part_1} ${ansible_command_part_2} ${ansible_command_part_3} ${ansible_command_part_4}"
	echo "${ansible_command}"
}


get_ansible_commands_with_build_id(){
	ansible_command_part_1="ansible-playbook -vv --user root --skip-tags 'et-application-config'"
	ansible_command_part_2=" --limit ${1} -e errata_jenkins_build=${2} "
	ansible_command_part_3=" playbooks/errata-tool/qe/deploy-errata-qe.yml"
	ansible_command="${ansible_command_part_1} ${ansible_command_part_2} ${ansible_command_part_3}"
	echo "${ansible_command}"
}


compare_version_or_id(){
	if [[ "${1}" == "${2}" ]]; then
		echo "same"
	elif [[ "${1}" -lt "${2}" ]]; then
		echo "upgrade"
	else
		echo "downgrade"
	fi
}

perf_restore_db() {
	if [[ "${1}" =~ "perf"  ]]
		then
		echo "=== [INFO] === Restoring the perf db"
		ssh  root@errata-stage-perf-db.host.stage.eng.bos.redhat.com "cd /var/lib;./restore_db.sh"
	fi
}

e2e_env_workaround() {
	echo "I am in ---"
	echo ${1}
    if [[ "${1}" =~ "e2e" ]]; then
    	echo "== Running the e2e env ansible workaround to ignore the kinit ansible problems"
        # e2e env has some problem which would raise 2 errors
        # the workaround 1 to fix the e2e env kinit ansible problem
        echo "  ignore_errors: yes" >> ${2}/playbooks/errata-tool/qe/roles/errata-tool/restart-application/tasks/refresh-kerb-ticket.yml
        # the workaround 2 to make sure the system version can be updated successfully
        echo "  ignore_errors: yes" >> ${2}/playbooks/errata-tool/qe/roles/errata-tool/verify-deploy/tasks/main.yml
        # the workaround 3 is to make sure the key tab related error can be ignored
        sed -i '/name: copy over krb5.conf/a \  ignore_errors: True' ${2}/playbooks/errata-tool/qe/roles/kerberos/tasks/main.yml
        sed -i '/copy host keytab/a \  ignore_errors: True' ${2}/playbooks/errata-tool/qe/roles/kerberos/tasks/main.yml
        sed -i '/install kerberos client packages on RedHat based platforms/a \  ignore_errors: True' ${2}/playbooks/errata-tool/qe/roles/kerberos/tasks/main.yml
    fi
}

update_setting() {
	if [[ "${1}" =~ "perf" ]]; then
		echo "=== [INFO] Custom the brew & bugzilla settings of testing server ==="
		ssh root@errata-stage-perf.host.stage.eng.bos.redhat.com 'cd ~;./check_stub.sh'
	fi

	if [[ "${1}" =~ "e2e" ]]; then
		echo "=== [INFO] Custom the pub & bugzilla settings of testing server ==="
		ssh root@et-e2e.usersys.redhat.com 'sed -i "s/bz-qgong.usersys.redhat.com/bz-e2e.usersys.redhat.com/" /var/www/errata_rails/config/initializers/credentials/bugzilla.rb'
		ssh root@et-e2e.usersys.redhat.com 'sed -i "s/pub-devopsqe.usersys.redhat.com/pub-e2e.usersys.redhat.com/" /var/www/errata_rails/config/initializers/credentials/pub.rb'
		ssh root@et-e2e.usersys.redhat.com 'sed -i "s/pdc-et.host.qe.eng.pek2.redhat.com/pdc.engineering.redhat.com/" /var/www/errata_rails/config/initializers/credentials/pub.rb'
	fi
	# clean the cache for all testing servers
	ssh root@"${1}" 'rm -rf /var/www/errata_rails/tmp/cache/*'
	# enable qe menu for all testing servers
	ssh root@"${1}" "sed -i \"s/errata.app.qa.eng.nay.redhat.com/${1}/g\" /var/www/errata_rails/app/controllers/concerns/user_authentication.rb"
}

restart_service() {
	echo "=== [INFO] Restarting the services on the testing server =="
	ssh root@"${1}" '/etc/init.d/httpd24-httpd restart'
	ssh root@"${1}" '/etc/init.d/delayed_job restart'
	ssh root@"${1}" '/etc/init.d/messaging_service restart'
}
