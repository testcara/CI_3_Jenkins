#!/bin/bash
set -eo pipefail

need_deploy=true
initial_et_build_version(){
	if [[ ${et_build_name_or_id} =~ "-" ]]; then
		echo "=== ET build name has been provided: ${et_build_name} =="
		et_build_version=$( echo ${et_build_name_or_id} | cut -d '-' -f 2| cut -d '.' -f 2 )
	else
		echo "=== ET build id is provided =="
		et_build_version=${et_build_name_or_id}
	fi
	echo "=== [INFO] expect ET version: ${et_build_version} ==="
}

compare_current_et_to_rc_et() {
	et_testing_server_version=$(curl http://${ET_Testing_Server}/system_version.json | cut -d "-" -f 2- | cut -d '.' -f 2)
	echo "=== [INFO] current ET version: ${et_build_version}"
	if [[ "${et_testing_server_version}"  -eq  "${et_build_version}" ]]; then
		echo "=== [INFO] The current testing version deployed is the specific new version, will do nothing ======"
		echo "==== Done ===="
		need_deploy=false
	fi
}

compare_current_et_product_et() {
	et_product_version_on_brew=$(curl http://${ET_Production_Server}/system_version.json  | tr -d '"'| cut -d "-" -f 1)
	et_product_version=$(echo ${et_product_version_on_brew} | tr -d '"'| cut -d "-" -f 1 | tr -d '.')
	et_testing_server_version=$(curl http://${ET_Testing_Server}/system_version.json  | tr -d \" | cut -d "-" -f 1 | tr -d '.')
	if [[ "${#et_product_version}" -gt "${#et_testing_server_version}" ]]
		then
		echo "=== The product et version is one sub version #{et_product_version}, but the testing et version is one big version ${et_testing_server_version} ==="
		et_product_version=$(echo ${et_product_version} | cut -c -4)
	fi
	if [[ "${et_product_version}" -gt "${et_testing_server_version}" ]]
		then
		echo "=== [INFO] === ET production version is newer than the testing server!"
		echo "=== Upgrading the testing server ===="
	elif [[ "${et_product_version}" -eq "${et_testing_server_version}" ]]
		then
		echo "=== [INFO] === ET production version is the same as the testing server!"
		echo "=== Nothing to do ==="
		need_deploy=false
		exit
	else
		echo "=== [INFO] === ET production version is older than the testing server!"
		echo "=== Downgrading the testing server ==="
		downgrade_flag=true
	fi
}

get_ansible_commands(){
	ansible_command_part_1="ansible-playbook -vv --user root --skip-tags 'et-application-config'"
	ansible_command_part_2=" --limit ${ET_Testing_Server} -e errata_jenkins_build=${et_build_version}"
	ansible_command_part_3=" playbooks/errata-tool/qe/deploy-errata-qe.yml"
	ansible_command="${ansible_command_part_1} ${ansible_command_part_2} ${ansible_command_part_3}"
}

e2e_env_workaround() {
    if [[ ${E2E_Env} == true ]]
    then
        # e2e env has some problem which would raise 2 errors
        # the workaround 1 to fix the e2e env kinit ansible problem
        echo "  ignore_errors: yes" >> ${WORKSPACE}/playbooks/errata-tool/qe/roles/errata-tool/restart-application/tasks/refresh-kerb-ticket.yml
        # the workaround 2 to make sure the system version can be updated successfully
        echo "  ignore_errors: yes" >> ${WORKSPACE}/playbooks/errata-tool/qe/roles/errata-tool/verify-deploy/tasks/main.yml
    fi
}

update_setting() {
	if [[ ${Perf_Env} == true ]]
		then
		echo "=== [INFO] Custom the brew & bugzilla settings of testing server ==="
		ssh root@${ET_Testing_Server} 'cd ~;./check_stub.sh'
	fi

	if [[ ${E2E_Env} == true ]]
		then
		echo "=== [INFO] Custom the pub & bugzilla settings of testing server ==="
		ssh root@${ET_Testing_Server} 'sed -i "s/bz-qgong.usersys.redhat.com/bz-e2e.usersys.redhat.com/" /var/www/errata_rails/config/initializers/credentials/bugzilla.rb'
		ssh root@${ET_Testing_Server} 'sed -i "s/pub-devopsqe.usersys.redhat.com/pub-e2e.usersys.redhat.com/" /var/www/errata_rails/config/initializers/credentials/pub.rb' 
		ssh root@${ET_Testing_Server} 'sed -i "s/pdc-et.host.qe.eng.pek2.redhat.com/pdc.engineering.redhat.com/" /var/www/errata_rails/config/initializers/credentials/pub.rb'
	fi
	# clean the cache for all testing servers
	ssh root@${ET_Testing_Server} 'rm -rf /var/www/errata_rails/tmp/cache/*'
	# enable qe menu for all testing servers
	ssh root@${ET_Testing_Server} "sed -i \"s/errata.app.qa.eng.nay.redhat.com/${ET_Testing_Server}/g\" /var/www/errata_rails/app/controllers/concerns/user_authentication.rb"
}

restart_service() {
	echo "=== [INFO] Restarting the services on the testing server =="
	ssh root@${ET_Testing_Server} '/etc/init.d/httpd24-httpd restart'
	ssh root@${ET_Testing_Server} '/etc/init.d/delayed_job restart'
	ssh root@${ET_Testing_Server} '/etc/init.d/messaging_service restart'
}

et_build_version=""
if ! [[ -z "${et_build_name_or_id}" ]]; then
    echo "the et_build_name_or_id is setted, will check the parameter"
	initial_et_build_version
	compare_current_et_to_rc_et
else
    echo "the et_build_name_or_id is not setted, will do nothing"
    need_deploy=false
fi

if [[ ${need_deploy} == "true" ]]; then
	echo "=== [INFO] Upgrading the testing server to the ET new Build ${et_build_name_or_id} ==="
	ansible_command=""
	compare_current_et_product_et
	set -x
	env
	cd playbooks/errata-tool
	make clean-roles
	make qe-roles
	e2e_env_workaround
	cd $WORKSPACE
	pwd
	get_ansible_commands
	echo ${ansible_command}
	${ansible_command}
	update_setting
    restart_service
fi
