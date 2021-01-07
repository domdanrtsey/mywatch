#!/bin/bash
ipaddress=`ip a|grep "global"|awk '{print $2}' |awk -F/ '{print $1}'`
file_output=${ipaddress}'os_mysql_simple_summary.html'
td_str=''
th_str=''
myuser="root"
mypasswd="XXXXX"
myip="localhost"
myport="3306"
mysql_cmd="mysql -u${myuser} -p${mypasswd} -h${myip} -P${myport} --protocol=tcp --silent"
#yum -y install bc sysstat net-tools
create_html_css(){
  echo -e "<html>
<head>
<style type="text/css">
    body        {font:12px Courier New,Helvetica,sansserif; color:black; background:White;}
    table,tr,td {font:12px Courier New,Helvetica,sansserif; color:Black; background:#FFFFCC; padding:0px 0px 0px 0px; margin:0px 0px 0px 0px;} 
    th          {font:bold 12px Courier New,Helvetica,sansserif; color:White; background:#0033FF; padding:0px 0px 0px 0px;} 
    h1          {font:bold 12pt Courier New,Helvetica,sansserif; color:Black; padding:0px 0px 0px 0px;} 
</style>
</head>
<body>"
}
create_html_head(){
echo -e "<h1>$1</h1>"
}
create_table_head1(){
  echo -e "<table width="68%" border="1" bordercolor="#000000" cellspacing="0px" style="border-collapse:collapse">"
}
create_table_head2(){
  echo -e "<table width="100%" border="1" bordercolor="#000000" cellspacing="0px" style="border-collapse:collapse">"
}
create_td(){
    td_str=`echo $1 | awk 'BEGIN{FS="|"}''{i=1; while(i<=NF) {print "<td>"$i"</td>";i++}}'`
}
create_th(){
    th_str=`echo $1|awk 'BEGIN{FS="|"}''{i=1; while(i<=NF) {print "<th>"$i"</th>";i++}}'`
}
create_tr1(){
  create_td "$1"
  echo -e "<tr>
    $td_str
  </tr>" >> $file_output
}
create_tr2(){
  create_th "$1"
  echo -e "<tr>
    $th_str
  </tr>" >> $file_output
}
create_tr3(){
  echo -e "<tr><td>
  <pre style=\"font-family:Courier New; word-wrap: break-word; white-space: pre-wrap; white-space: -moz-pre-wrap\" >
  `cat $1`
  </pre></td></tr>" >> $file_output
}
create_table_end(){
  echo -e "</table>"
}
create_html_end(){
  echo -e "</body></html>"
}
NAME_VAL_LEN=12
name_val () {
   printf "%+*s | %s\n" "${NAME_VAL_LEN}" "$1" "$2"
}
get_netinfo(){
   echo "interface | status | ipadds     |      mtu    |  Speed     |     Duplex" >>/tmp/tmpnet_h1_`date +%y%m%d`.txt
   for ipstr in `ifconfig -a|grep ": flags"|awk  '{print $1}'|sed 's/.$//'`
   do
      ipadds=`ifconfig ${ipstr}|grep -w inet|awk '{print $2}'`
      mtu=`ifconfig ${ipstr}|grep mtu|awk '{print $NF}'`
      speed=`ethtool ${ipstr}|grep Speed|awk -F: '{print $2}'`
      duplex=`ethtool ${ipstr}|grep Duplex|awk -F: '{print $2}'`
      echo "${ipstr}"  "up" "${ipadds}" "${mtu}" "${speed}" "${duplex}"\
      |awk '{print $1,"|", $2,"|", $3,"|", $4,"|", $5,"|", $6}'  >>/tmp/tmpnet1_`date +%y%m%d`.txt
   done
 }
my_base_info(){
  ${mysql_cmd} -e "select now(),current_user(),version()\G"
  ${mysql_cmd} -e "show global variables like 'autocommit';"|grep -i ^auto|awk '{print $1,":",$2}'
  ${mysql_cmd} -e "show variables like '%binlog%';"|awk '{print $1,":",$2}'
  ${mysql_cmd} -e "show variables like 'innodb_flush%';"|awk '{print $1,":",$2}'
}
my_stat_info(){
   ${mysql_cmd} -e status >>/tmp/tmpmy_stat_`date +%y%m%d`.txt
}
my_param_info(){
  echo "Variable_name|Value" >>/tmp/tmpmy_param_h1_`date +%y%m%d`.txt
  ${mysql_cmd} -e "show global variables"|egrep -w "innodb_buffer_pool_size|innodb_file_per_table|innodb_flush_log_at_trx_commit|innodb_io_capacity|\
  innodb_lock_wait_timeout|innodb_data_home_dir|innodb_log_file_size|innodb_log_files_in_group|log_slave_updates|long_query_time|lower_case_table_names|\
  max_connections|max_connect_errors|max_user_connections|query_cache_size|query_cache_type |server_id|slow_query_log|slow_query_log_file|innodb_temp_data_file_path|\
  sql_mode|gtid_mode|enforce_gtid_consistency|expire_logs_days|sync_binlog|open_files_limit|myisam_sort_buffer_size|myisam_max_sort_file_size"\
  |awk '{print $1,"|",$2}' >>/tmp/tmpmy_param_t1_`date +%y%m%d`.txt
}
create_html(){
  rm -rf $file_output
  touch $file_output
  create_html_css >> $file_output

  create_html_head "Network Info Summary" >> $file_output
  create_table_head1 >> $file_output
  get_netinfo
  while read line
  do
    create_tr2 "$line" 
  done < /tmp/tmpnet_h1_`date +%y%m%d`.txt
  while read line
  do
    create_tr1 "$line" 
  done < /tmp/tmpnet1_`date +%y%m%d`.txt
  create_table_end >> $file_output

  create_html_head "Basic Database && binlog Information" >> $file_output
  create_table_head1 >> $file_output
  my_base_info >>/tmp/tmpmy_base_`date +%y%m%d`.txt
  sed -i -e '1d' -e 's/:/|/g' /tmp/tmpmy_base_`date +%y%m%d`.txt
  while read line
  do
    create_tr1 "$line" 
  done </tmp/tmpmy_base_`date +%y%m%d`.txt
  create_table_end >> $file_output

  create_html_head "Running Status of Database" >> $file_output
  create_table_head1 >> $file_output
  my_stat_info  
  create_tr3 "/tmp/tmpmy_stat_`date +%y%m%d`.txt"
  create_table_end >> $file_output

  create_html_head "Important Parameters" >> $file_output
  create_table_head1 >> $file_output
  my_param_info
  while read line
  do
    create_tr2 "$line" 
  done < /tmp/tmpmy_param_h1_`date +%y%m%d`.txt
  while read line
  do
    create_tr1 "$line" 
  done < /tmp/tmpmy_param_t1_`date +%y%m%d`.txt
  create_table_end >> $file_output 
  
  create_html_end >> $file_output
  sed -i 's/BORDER=1/width="68%" border="1" bordercolor="#000000" cellspacing="0px" style="border-collapse:collapse"/g' $file_output
  rm -rf /tmp/tmp*_`date +%y%m%d`.txt
}
# This script must be executed as root
RUID=`id|awk -F\( '{print $1}'|awk -F\= '{print $2}'`
if [ ${RUID} != "0" ];then
    echo"This script must be executed as root"
    exit 1
fi
PLATFORM=`uname`
if [ ${PLATFORM} = "HP-UX" ] ; then
    echo "This script does not support HP-UX platform for the time being"
exit 1
elif [ ${PLATFORM} = "SunOS" ] ; then
    echo "This script does not support SunOS platform for the time being"
exit 1
elif [ ${PLATFORM} = "AIX" ] ; then
    echo "This script does not support AIX platform for the time being"
exit 1
elif [ ${PLATFORM} = "Linux" ] ; then
echo -e "
###########################################################################################
#Make sure that the following parameters at the beginning of the script are correct.
#myuser="root"      (Database Account)
#mypasswd="XXXXXX"  (Database password)
#myip="localhost"   (Database native IP)
#myport="3306"      (Database port)
#--> Otherwise, the script cannot be executed properly.
#GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' identified by 'XXXXX' WITH GRANT OPTION;
#flush privileges;
###########################################################################################
"
  create_html
fi
