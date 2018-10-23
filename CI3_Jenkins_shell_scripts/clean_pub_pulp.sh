#!/bin/bash
echo "== Begin to clean the pulp env ${server_name} =="
echo "== first prepare the env =="
for package in python-devel  python-virtualenv yum-utils
do
        if ! [[ $( rpm -qa | grep ${package} ) =~ "${package}" ]];then
                yum install -y ${package}
        else
                echo $( rpm -qa | grep ${package})
        fi
done
# in one-click env, we need to upgrade 'koji' before we can install brewkoji
if ! [[ $( rpm -qa | grep 'brewkoji') =~ "brewkoji" ]];then
        yum upgrade koji
        yum install -y brewkoji
else
        echo $( rpm -qa | grep 'brewkoji' )
fi
if [[ -e content-delivery-qe ]]; then
        echo "do nothing"
       rm -rf content-delivery-qe
fi
curl -L -O http://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-rhel-7-server.repo
echo "== second get the clean scripts =="
git clone git://git.app.eng.bos.redhat.com/content-delivery-qe
cd content-delivery-qe
echo "== run the cases of clean data =="
virtualenv --system-site-packages ~/testpython
. ~/testpython/bin/activate
pip install -r test-requirements.txt
# change the host of the config
sudo sed -i "s/pub.host.qe.eng.pek2.redhat.com/pub-e2e.usersys.redhat.com/g" /root/content-delivery-qe/unit_tests/configs/QA_01.conf
sudo sed -i "s/pub-02.host.qe.eng.pek2.redhat.com/pub-e2e.usersys.redhat.com/g" /root/content-delivery-qe/unit_tests/configs/QA_01.conf
sudo sed -i "s/pub-test.usersys.redhat.com/pub-e2e.usersys.redhat.com/g" /root/content-delivery-qe/unit_tests/configs/QA_01.conf
sudo sed -i "s/pulp-02.host.qe.eng.pek2.redhat.com/pulp-e2e.usersys.redhat.com/g" /root/content-delivery-qe/unit_tests/configs/QA_01.conf
sudo sed -i "s/pulp-03.host.qe.eng.pek2.redhat.com/pulp-docker-e2e.usersys.redhat.com/g" /root/content-delivery-qe/unit_tests/configs/QA_01.conf
sudo sed -i "s/password=redhat/password=errata/g" /root/content-delivery-qe/unit_tests/configs/QA_01.conf
# disable some lines which bring some errors
sudo sed -i 's/"errata"/#"errata"/g'  /root/content-delivery-qe/unit_tests/helpers/constants.py
sudo sed -i 's/"pulp"/#"pulp"/g'  /root/content-delivery-qe/unit_tests/helpers/constants.py
# disable one useless testing types
sed -i "/clear_akamai_cdn/d" /root/content-delivery-qe/unit_tests/helpers/test_run_helper.py
# clean the pulp and pulp-docker data
cd /root/content-delivery-qe
py.test -v unit_tests/tests/clean_data.py::CleanData::test_clean_rhsm_pulp_data
py.test -v unit_tests/tests/clean_data.py::CleanData::test_clean_docker_pulp_data
echo "== The pulp env is clean =="
