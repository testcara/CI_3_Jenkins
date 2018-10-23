#!/bin/bash
# first, get the product version of pub & pulp
# second, get the installed pub & pulp version on e2e env
# finally, do the upgrade/downgrade to make sure the two kinds of version are the same
set -eo pipefail

confluence_wikiurl="https://docs.engineering.redhat.com"
e2e_version_page="Version of Applications in E2E"
e2e_version_page_space="~lzhuang"
#install sshpass
install_sshpass() {
	if [[ -z $(rpm -qa | grep sshpass) ]]; then
		echo "== Install the sshpass =="
		sudo su
		yum install sshpass -y
	else
		echo "== sshpass has been installed =="
	fi
}

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

get_all_product_versions_content() {
	confluence-cli --wikiurl=${confluence_wikiurl} -u ${username} -p ${password}  getpagecontent -n "${e2e_version_page}"  -s ${e2e_version_page_space} > pub_pulp_version_content.txt
}

# check the pub version
get_build_installed_on_server() {
	echo $(ssh root@${1} "rpm -qa | grep ${2} | sed 's/.noarch//'")
}

download_ci_files() {
	tmp_dir="/tmp/$(date +'%s')"
	mkdir -p ${tmp_dir}
	cd ${tmp_dir}
	echo "=============== Download the CI files under $(pwd) =========="
	wget http://github.com/testcara/RC_CI/archive/master.zip
	unzip master.zip
	cd ${tmp_dir}/RC_CI-master/auto_testing_CI
}

initialize_ansible_related_varables(){
	pub_product_version=""
	pub_deploy=false
	pulp_for_rpm_production=""
	pulp_for_rpm_deploy=false
	pulp_for_rpm_deploy_downgrade=false
	pulp_rpm_production=""
	pulp_rpm_deploy=false
	pulp_cdn_distributor_production=""
	pulp_cdn_deploy=false
	pulp_for_docker_deploy=false
	pulp_for_docker_production=""
	pulp_docker_production=""
	pulp_docker_deploy=false
	pulp_docker_server_ansible=""
	pulp_rpm_server_ansible=""
	pub_ansible=""
	pulp_for_rpm_ansible=""
	pulp_rpm_ansible=""
	pulp_cdn_deploy_ansible=""
	pulp_for_docker_ansible=""
	pulp_docker_ansible=""
}

# check pub related
check_and_initialize_pub() {
	pub_installed=$( get_build_installed_on_server ${pub_server} pub-hub )
	echo "=== pub installed =="
	echo ${pub_installed}
	pub_product=$( sudo python get_pub_pulp_product_version.py ${current_dir}/pub_pulp_version_content.txt pub )
	echo "== pub production =="
	echo ${pub_product}
	if [[ ${pub_installed} =~ ${pub_product} ]]; then
		echo "== The pub installed is the same as the production, no need to update it =="
	else
		pub_deploy=true
	    echo "== we need to update the pub version =="
	    pub_product_version=$( echo ${pub_product} | cut -d "-" -f 3- | cut -d '.' -f 1-3 )
	    echo "== will initialize the pub server with pub version ${pub_product_version}"
	    pub_installed_version=$( echo ${pub_installed} |  cut -d "-" -f 3- | cut -d '.' -f 1-3 )
	    pub_product_sub_version=$( echo ${pub_product_version} | cut -d '-' -f 2 )
	    pub_product_ansible_version=$( echo ${pub_product_version} | cut -d '-' -f 1 | cut -d '-' -f 1)
	    if [[ ${pub_product_sub_version} -gt 1 ]]; then
	    	pub_ansible="ansible-playbook -u root -i ${WORKSPACE}/inventory/pub ${WORKSPACE}/playbooks/pub/e2e/deploy-pub-e2e.yml -e pub_version=${pub_product_ansible_version} -e pub_release=${pub_product_sub_version}"
	    else
	    	pub_ansible="ansible-playbook -u root -i ${WORKSPACE}/inventory/pub ${WORKSPACE}/playbooks/pub/e2e/deploy-pub-e2e.yml -e pub_version=${pub_product_ansible_version}"
	    fi
        pub_product_version_integer=$(echo ${pub_product_version} | sed "s/[^0-9]*//g")
        pub_installed_version_integer=$(echo ${pub_installed_version} | sed "s/[^0-9]*//g" | cut -c 1-${#pub_product_version_integer})

	    if [[ ${pub_installed_version_integer} -gt ${pub_product_version_integer} ]]; then
	    	echo "== The installed pub is newer to production pub, we need to downgrade it =="
	    	pub_ansible="${pub_ansible} -e pub_downgrade=true"
	    fi
	fi
	if [[ ${pub_deploy} == "true" ]]; then
		echo "Ansible: ${pub_ansible}"
		${pub_ansible}
		echo "== Now the pub installed is: =="
		echo $( get_build_installed_on_server ${pub_server} pub-hub )
	fi
}

# check pulp-rpm related
check_and_initialize_pulp_rpm() {
	pulp_for_rpm_installed=$( get_build_installed_on_server ${pulp_rpm_server}  pulp-server )
	echo "== pulp installed on pulp-rpm server =="
	echo ${pulp_for_rpm_installed}
	pulp_for_rpm_production=$( sudo python get_pub_pulp_product_version.py ${current_dir}/pub_pulp_version_content.txt pulp_for_rpm )
	echo "== pulp production =="
	echo ${pulp_for_rpm_production}

	if [[ ${pulp_for_rpm_installed} =~ ${pulp_for_rpm_production} ]]; then
		echo "== The pulp server installed is the same as the pulp production, no need to update it =="
	else
		pulp_for_rpm_deploy=true
		pulp_for_rpm_production_name=$( echo ${pulp_for_rpm_production} | sed "s/-server//" )
		pulp_for_rpm_ansible=" -e pulp_build=${pulp_for_rpm_production_name}"
		pulp_for_rpm_production_integer=$(echo ${pulp_for_rpm_production} | sed "s/[^0-9]*//g")
		pulp_for_rpm_installed_integer=$(echo ${pulp_for_rpm_installed} | sed "s/[^0-9]*//g" | cut -c "1-${#pulp_for_rpm_production_integer}")
		if [[ ${pulp_for_rpm_installed_integer} -gt ${pulp_for_rpm_production_integer} ]];then
			pulp_for_rpm_ansible=${pulp_for_rpm_ansible}+" -e pulp_downgrade=true"
		fi
	fi

	pulp_rpm_installed=$( get_build_installed_on_server ${pulp_rpm_server} pulp-rpm-plugins)
	echo "== pulp-rpm installed on pulp-rpm server =="
	echo ${pulp_rpm_installed}
	pulp_rpm_production=$( sudo python get_pub_pulp_product_version.py ${current_dir}/pub_pulp_version_content.txt pulp-rpm-plugins )
	echo "== pulp-rpm production =="
	echo ${pulp_rpm_production}

	if [[ ${pulp_rpm_installed} =~ ${pulp_rpm_production} ]]; then
		echo "== The pulp-rpm  installed is the same as the pulp production, no need to update it =="
	else
		pulp_rpm_deploy=true
		pulp_rpm_production_name=$( echo ${pulp_rpm_production} | sed "s/-plugins//" )
		pulp_rpm_ansible=" -e pulp_rpm_build=${pulp_rpm_production_name}"
		pulp_rpm_production_integer=$(echo ${pulp_rpm_production} | sed "s/[^0-9]*//g")
		pulp_rpm_installed_integer=$(echo ${pulp_rpm_installed}   | sed "s/[^0-9]*//g" | cut -c "1-${#pulp_rpm_production_integer}")
		if [[ ${pulp_rpm_installed_integer} -gt ${pulp_rpm_production_integer} ]];then
			pulp_rpm_ansible="${pulp_rpm_ansible} -e pulp_downgrade=true"
		fi
	fi

	pulp_cdn_distributor_installed=$( get_build_installed_on_server ${pulp_rpm_server} pulp-cdn-distributor-plugins)
	echo "== pulp-cdn-distributor-plugins installed on pulp-rpm server =="
	echo ${pulp_cdn_distributor_installed}
	pulp_cdn_distributor_production=$( sudo python get_pub_pulp_product_version.py ${current_dir}/pub_pulp_version_content.txt pulp-cdn-distributor-plugins )
	echo "== pulp-cdn-distributor-plugin production =="
	echo ${pulp_cdn_distributor_installed}
	if [[ ${pulp_cdn_distributor_installed} =~ ${pulp_cdn_distributor_production} ]]; then
		echo "== The pulp-cdn-distributor-plugins installed is the same as the pulp production, no need to update it =="
	else
		pulp_cdn_deploy=true
		pulp_cdn_distributor_build_name=$(echo ${pulp_cdn_distributor_production} | sed "s/-plugins//")
		pulp_cdn_deploy_ansible=" -e pulp_cdn_distributor_build=${pulp_cdn_distributor_build_name}"
		pulp_cdn_distributor_production_integer=$(echo ${pulp_cdn_distributor_production} | sed "s/[^0-9]*//g")
		pulp_cdn_distributor_installed_integer=$(echo ${pulp_cdn_distributor_installed} | sed "s/[^0-9]*//g" | cut -c "1-${#pulp_cdn_distributor_production_integer}")

		if [[ ${pulp_cdn_distributor_installed_integer} -gt ${pulp_cdn_distributor_production_integer} ]];then
			pulp_cdn_deploy_ansible="${pulp_cdn_deploy_ansible} -e pulp_downgrade=true"
		fi
	fi
	pulp_rpm_server_ansible="ansible-playbook -u root -i ${WORKSPACE}/inventory/pulp ${WORKSPACE}/playbooks/pulp/deploy-pulp-rpm-e2e.yml \
                         ${pulp_for_rpm_ansible} ${pulp_rpm_ansible} ${pulp_cdn_deploy_ansible}"
    if [[ ${pulp_for_rpm_deploy} == "true" ]] || [[ ${pulp_rpm_deploy} == "true" ]] || [[ ${pulp_cdn_deploy} == "true" ]];then
    	echo "== Ansible: ${pulp_rpm_server_ansible} =="
    	${pulp_rpm_server_ansible}
    	echo "== Now the pulp-rpm related builds installed are:"
    	echo $( get_build_installed_on_server ${pulp_rpm_server}  pulp-server )
    	echo $( get_build_installed_on_server ${pulp_rpm_server} pulp-rpm-plugins)
    	echo $( get_build_installed_on_server ${pulp_rpm_server} pulp-cdn-distributor-plugins)
    fi
}
# check pulp-docker related
check_and_initialize_pulp_docker() {
	pulp_for_docker_installed=$( get_build_installed_on_server ${pulp_docker_server} ${server_password} pulp-server )
	echo "== pulp installed on pulp-docker server =="
	echo ${pulp_for_docker_installed}pulp_for_docker_production=$( sudo python get_pub_pulp_product_version.py ${current_dir}/pub_pulp_version_content.txt pulp_for_docker )
	echo "== pulp production =="
	echo ${pulp_for_docker_production}
	if [[ ${pulp_for_docker_installed} =~ ${pulp_for_docker_production} ]]; then
		echo "== The pulp server installed is the same as the pulp production, no need to update it =="
	else
		pulp_for_docker_deploy=true
		pulp_for_docker_ansible=" -e pulp_build=${pulp_for_docker_production}"
		pulp_for_docker_production_integer=$(echo ${pulp_for_docker_production} | sed "s/[^0-9]*//g")
		pulp_for_docker_installed_integer=$(echo ${pulp_for_docker_installed} | sed "s/[^0-9]*//g" | cut -c "1-${#pulp_for_docker_production_integer}")
		if [[ ${pulp_for_docker_installed_integer} -gt ${pulp_for_docker_production_integer} ]];then
			pulp_for_docker_ansible=${pulp_for_docker_ansible}+" -e pulp_downgrade=true"
		fi
	fi

	pulp_docker_installed=$( get_build_installed_on_server ${pulp_docker_server} ${server_password} pulp-docker-plugins)
	echo "== pulp-docker installed on pulp-docker server =="
	echo ${pulp_docker_installed}
	pulp_docker_production=$( sudo python get_pub_pulp_product_version.py ${current_dir}/pub_pulp_version_content.txt pulp-docker-plugins )
	echo "== pulp-docker production =="
	echo ${pulp_docker_production}

	if [[ ${pulp_docker_installed} =~ ${pulp_docker_production} ]]; then
		echo "== The pulp-docker  installed is the same as the pulp production, no need to update it =="
	else
		pulp_docker_deploy=true
		pulp_docker_ansible=" -e pulp_docker_build=${pulp_docker_production}"
		pulp_docker_production_integer=$(echo ${pulp_docker_production} | sed "s/[^0-9]*//g")
		pulp_docker_installed_integer=$(echo ${pulp_docker_installed}   | sed "s/[^0-9]*//g" | cut -c "1-${#pulp_docker_production_integer}")
		if [[ ${pulp_docker_installed_integer} -gt ${pulp_docker_production_integer} ]];then
			pulp_docker_ansible=${pulp_docker_ansible}+" -e pulp_downgrade=true"
		fi
	fi

	pulp_docker_server_ansible="ansible-playbook -u root -i ${WORKSPACE}/inventory/pulp ${WORKSPACE}/playbooks/pulp/deploy-pulp-docker-e2e.yml \
    ${pulp_for_docker_ansible} ${pulp_docker_ansible}"
    if [[ ${pulp_docker_deploy} == "true" ]] || [[ ${pulp_for_docker_deploy} == "true" ]];then
    	echo "== Ansible: ${pulp_docker_server_ansible} =="
    	${pulp_docker_server_ansible}
    	
    	echo "== Now the pulp-docker related builds installed are: =="
    	echo $( get_build_installed_on_server ${pulp_docker_server} pulp-server )
    	echo $( get_build_installed_on_server ${pulp_docker_server} pulp-docker-plugins)
    fi
}

# for each e2e testing run, the dbs and other files have been cleaned on pulp-rpm and pulp-docker servers
run_clean_pulp_env(){
	echo "=== Cleaning the pulp environment"
	pwd
	sudo cp "clean_pub_pulp.sh" /root
	cd /root
	sudo ./clean_pub_pulp.sh
	if [[ $( echo $? ) -eq 0 ]]; then
		echo "== All things are finished =="
	else
		echo "== Fail to clean pulp enviroment =="
	fi
}

install_scripts_env
install_sshpass
download_ci_files
initialize_ansible_related_varables
current_dir=$( echo `pwd` )
get_all_product_versions_content
check_and_initialize_pub
check_and_initialize_pulp_rpm
check_and_initialize_pulp_docker
run_clean_pulp_env
