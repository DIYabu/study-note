#!/bin/sh
#-------------------------------------------------------------------------------------------------------------
#注意:由于日志清理跟日志所在目录的目录结构相关,所以,该脚本跟process_manager.sh脚本绑定.
#     如果未和process_manager.sh一起使用,也没有关系,但是,需要将日志打到 工程根目录/logs 目录下,
#         本脚本会清理 工程根目录/logs 下的所有日志,按天保存
#使用例子:
#	1)将脚本放到项目的根目录
#	2)将此脚本放进crontab进程，如:每天0点0分执行命令如下
#		"0 0 * * * /bin/sh /home/bruce/del_log.sh /home/bruce 2 >/dev/null 2>&1"
#		其中/home/bruce是jar包目录路径，数字2是要保留日志文件的数量,使用范围2-9 
#		"0 0 * * * /bin/sh /opt/tomcat/del_log.sh /opt/tomcat 2 >/dev/null 2>&1"
#		其中/opt/tomcat是tomcat的目录路径，数字2是要保留日志文件的数量,使用范围2-9 

#1)若有新需求或者bug,及时反馈给脚本开发者,王峰

#-------------------------------------------------------------------------------------------------------------
APP_JAR_PATH=$1
num=$[$2-2]
num02=$2
yDay=`date -d yesterday +%Y-%m-%d`
xnDay=`date -d"-$num02 day" +%F`

rm_nohup(){
       cp nohup.out nohup_${yDay}.out
       /bin/cat /dev/null > nohup.out
        if [ -f nohup_${xnDay}.out ]; then
                rm -rf  nohup_${xnDay}.out
        fi
}

rm_log(){
        find ./  -mtime +"$num" -type f -exec rm -rf {} \;
}

delete_log(){
        
        if [ -d "$APP_JAR_PATH/logs" ];then
            cd $APP_JAR_PATH/logs

            if [ -f "./nohup.out" ];then
                echo "======================================================================================"
                echo "remove logs in directory $APP_JAR_PATH/logs/nohup.out, and remain $num02 days logs"
                rm_nohup
                echo "======================================================================================"
            fi
            
            echo "======================================================================================"
            echo "remove logs in directory $APP_JAR_PATH/logs , and remain $num02 days logs"
            rm_log
            echo "======================================================================================"
                       
        fi
        
        if [ -d "$APP_JAR_PATH/log4j" ];then
            echo "======================================================================================"
            echo "remove logs in directory $APP_JAR_PATH/log4j, and remain $num02 days logs"
            cd $APP_JAR_PATH/log4j
            rm_log
            echo "======================================================================================"
        fi
        
        if [ -d "$APP_JAR_PATH/log4j_error" ];then
            echo "======================================================================================"
            echo "remove logs in directory $APP_JAR_PATH/log4j_error, and remain $num02 days logs"
            cd $APP_JAR_PATH/log4j_error
            rm_log
            echo "======================================================================================"
        fi
}

case "$2" in
[2-9])
delete_log
;;
*)
echo "Usage: $0 {Java package's path} {2-9}"
exit 1
;;
esac
exit 0

