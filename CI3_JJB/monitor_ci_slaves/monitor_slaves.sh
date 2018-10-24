#!/bin/bash
# set -eo pipefail
pub_ansible_slave_host=${1}
perf_jmeter_slave_host=${2}
umb_broker_slave_host=${3}
offline_slave_count=0
offline_slaves=""
unavilabed_services_count=0
unavilable_services=""

check_single_slave_online(){
	result=$(ping -c 1 $1)
	if [[ ${result} =~ "1 received" ]]; then
		echo "The slave ${1} is online"
	else
		echo "Error: The slave ${1} is offline"
		offline_slave_count=$((${offline_slave_count}+1))
		offline_slaves="${offline_slaves} ${1}"
	fi
}

check_slaves_online(){
	for slave in "${pub_ansible_slave_host}" "${perf_jmeter_slave_host}" "${umb_broker_slave_host}"
	do
		check_single_slave_online ${slave}
	done
}


check_perf_slave_service_status(){
	echo curl "http://${perf_jmeter_slave_host}/RPC2"
	result=$(curl "http://${perf_jmeter_slave_host}/RPC2")
	if [[ ${result} =~ "Method Not Allowed" ]]; then
		echo "The jmeter mocker service is ready"
	else
		echo "Error: The jmeter mocker server is unavilable"
		unavilable_services="${unavilable_services} perf_mocker_slave_service"
		unavilabed_services_count=$((${unavilabed_services_count}+1))
	fi
}

check_umb_broker_service_status(){
	echo curl -I http://10.8.241.108:8161/
	result=$(curl -I http://10.8.241.108:8161/)
	if [[ ${result} =~ "HTTP/1.1 200 OK" ]]; then
		echo "The umb broker service is ready"
	else
		echo "Error: The umb broker server is unavilable"
		unavilable_services="${unavilable_services} umb_broker_service"
		unavilabed_services_count=$((${unavilabed_services_count}+1))
	fi
}

check_all_slaves_and_summary_monitor_results(){
	echo "===== Checking the slaves and services status"
	check_slaves_online
	check_perf_slave_service_status
	check_umb_broker_service_status
	echo "===== Slave Status Summary Begin ======"
	if [[ "${offline_slave_count}" -gt "0" ]]; then
		echo "== Error: There are ${offline_slave_count} slaves offline"
		echo "== The offline slaves are:${offline_slaves}"
		exit 1
	else
		echo "== All slaves are online "
	fi
	if [[ "${unavilabed_services_count}" -gt "0" ]]; then
		echo "== Error: There are ${unavilabed_services_count} services unavilable"
		echo "== The unavilable services are:${unavilable_services}"
		exit 1
	else
		echo "== All services are ready"
	fi
	echo "===== Slave Status Summary End ====== "
}

check_all_slaves_and_summary_monitor_results
