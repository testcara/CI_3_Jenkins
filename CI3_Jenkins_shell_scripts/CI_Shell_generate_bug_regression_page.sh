#!/bin/bash
set -eo pipefail
debug=false
if [[ ${debug} == "true" ]]; then
  username="wlin"
  password=${1}
  et_build_name_or_id="3416"
  parent_page="30869307"
  space="~wlin"
  bugs_link='https://bugzilla.redhat.com/buglist.cgi?bug_id=1138548%2C1375442%2C1380523%2C1396363%2C1401608%2C1442190%2C1442956%2C1465236%2C1468946%2C1468948%2C1468953%2C1483759%2C1493815%2C1524932%2C1530824%2C1557123%2C1560842%2C1564158%2C1564583%2C1566829%2C1567255%2C1568738%2C1569453%2C1572479%2C1573054%2C1573770%2C1569725&list_id=8848997'
fi

#1. get the bugs list
bugs=$(echo ${bugs_link} | cut -d "=" -f 2 | sed  "s/&list_id//" | sed 's/%2C/ /g')
echo "====Bugs: ${bugs}==================="
#2. set the bugzilla username, confluence username
bugzilla_username="${username}@redhat.com"
confluence_username=${username}
echo "The bugzilla account is ${bugzilla_username}, the confluence account is ${confluence_username}"
#3. first install the confluence-py, bugzilla module and wget package, then get and run script to generate the conflunce content for the bug page, finally create the page on confluence
prepare_scripts(){
  mkdir -p ${1}
  cd ${1}
  echo "===============Download the CI files under $(pwd)=========="
  wget http://github.com/testcara/RC_CI/archive/master.zip
  unzip master.zip
  cd ${1}/RC_CI-master/auto_testing_CI
  # first check the page exists or not, if not, generate for all content
  echo "==============All files had beeen Download==============="
}

#tmp_dir="/tmp/$(date +'%s')"
tmp_dir=$(echo pwd)
#prepare_scripts ${tmp_dir}
source CI_Shell_prepare_env_and_scripts.sh
source CI_Shell_common_usage.sh
et_build_version=""
#install_scripts_env
et_build_version=$(initial_et_build_version ${et_build_name_or_id})

title="Bug Regression Reports For Build ${et_build_version}"
#cd ${tmp_dir}/RC_CI-master/auto_testing_CI
pwd
echo "=== generating the bug content "
sudo python generate_confluence_page_for_bugs.py ${bugzilla_username} ${password} ${bugs}
echo "=== Adding/updating pages to confluence page"
content=$(cat content.txt)
sudo python confluence_client.py "${confluence_username}" "${password}" "${title}" "${space}" "${content}" "${parent_page}"

echo "========Removing the useless files==========="
rm -rf ${tmp_dir}
echo "====================Done=============="