#!/bin/sh
# the CI is quite simple, just to upgrade pub&pulp packages

get_build_installed_on_server() {
	echo $(ssh root@${1} "rpm -qa | grep ${2} | sed 's/.noarch//'")
}

initialize_env(){
	pub_deploy_failed=""
	pulp_rpm_deploy_failed=""
	pulp_docker_deploy_failed=""
}

upgrade_pub(){
	pub_ansible=""
	if [[ ! -z ${pub_jenkins_build} ]]; then
		echo "== will upgrade the pub env =="
		pub_ansible="ansible-playbook -u root -i ${WORKSPACE}/inventory/pub ${WORKSPACE}/playbooks/pub/e2e/deploy-pub-e2e.yml -e pub_jenkins_build=${pub_jenkins_build}"
		${pub_ansible}
		if [[ $(echo $?) == "0" ]]; then
			echo "== Pub is ready =="
			pub_installed=$( get_build_installed_on_server ${pub_server} pub-hub)
			echo "== The pub installed is:"
			echo "== ${pub_installed}"
		else
			pub_deploy_failed=true
		fi
	fi
}


upgrade_pulp_rpm(){
	pulp_rpm_ansible=""
	pulp_rpm_build_ansible=""
	pulp_build_for_rpm_ansible=""
	pulp_cdn_distributor_build_ansible=""
	pulp_rpm_ansible_part=""
	if [[ ! -z ${pulp_build_for_rpm} ]]; then
		pulp_build_for_rpm_ansible=" -e pulp_build=${pulp_build_for_rpm}"
	fi
	if [[ ! -z ${pulp_rpm_build} ]]; then
		pulp_rpm_build_ansible=" -e pulp_rpm_build=${pulp_rpm_build} "
	fi
	if [[ ! -z ${pulp_cdn_distributor_build} ]]; then
		pulp_cdn_distributor_build_ansible=" -e pulp_cdn_distributor_build=${pulp_cdn_distributor_build}"
	fi
	pulp_rpm_ansible_part="${pulp_build_for_rpm_ansible}${pulp_rpm_build_ansible}${pulp_cdn_distributor_build_ansible}"
	if [[ ! -z ${pulp_rpm_ansible_part} ]]; then
		pulp_rpm_ansible="ansible-playbook -u root -i ${WORKSPACE}/inventory/pulp ${WORKSPACE}/playbooks/pulp/deploy-pulp-rpm-e2e.yml ${pulp_rpm_ansible_part}"
		${pulp_rpm_ansible}
		if [[ $(echo $?) == "0" ]]; then
			echo "== Pulp-rpm is ready =="
			echo "== All related pulp packages installed are: =="
			echo $( get_build_installed_on_server ${pulp_rpm_server} pulp-server)
			echo $( get_build_installed_on_server ${pulp_rpm_server} pulp-rpm-plugins)
			echo $( get_build_installed_on_server ${pulp_rpm_server} pulp-cdn-distributor-plugins)
		else
			pulp_rpm_deploy_failed=true
		fi
	fi
}


upgrade_pulp_docker(){
	pulp_docker_ansible=""
	pulp_docker_build_ansible=""
	pulp_build_for_docker_ansible=""
	pulp_docker_ansible_part=""
	if [[ ! -z ${pulp_build_for_docker} ]]; then
		pulp_build_for_rpm_ansible=" -e pulp_build=${pulp_build_for_docker}"
	fi
	if [[ ! -z ${pulp_docker_build} ]]; then
		pulp_rpm_build_ansible=" -e pulp_docker_build=${pulp_docker_build} "
	fi
	pulp_docker_ansible_part="${pulp_build_for_docker_ansible}${pulp_docker_build_ansible}"
	if [[ ! -z ${pulp_docker_ansible_part} ]];then
		pulp_docker_ansible="ansible-playbook -u root -i ${WORKSPACE}/inventory/pulp ${WORKSPACE}/playbooks/pulp/deploy-pulp-docker-e2e.yml ${pulp_rpm_ansible_part}"
		${pulp_docker_ansible}
		if [[ $(echo $?) == "0" ]]; then
			echo "== Pulp-docker is ready =="
			echo "== All related pulp packages installed are: =="
			echo $( get_build_installed_on_server ${pulp_docker_server} pulp-server)
			echo $( get_build_installed_on_server ${pulp_docker_server} pulp-docker-plugins)
		else
			pulp_docker_deploy_failed=true
		fi
	fi
}


initialize_env
upgrade_pub
upgrade_pulp_rpm
upgrade_pulp_docker
if [[ ${pub_deploy_failed} == "true" ]] || [[ ${pulp_rpm_deploy_failed} == "true" ]] || [[ ${pulp_docker_deploy_failed} == "true" ]]; then
	echo "==== Upgrade failed ===="
	exit 1
else
	echo "== Done =="
fi