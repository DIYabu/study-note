#!/bin/sh
#-------------------------------------------------------------------------------------------------------------
#jstorm的进程监控脚本,自动监控/启动nimbus和supervisor进程
#* * * * * /bin/sh /home/jstorm/jstorm-0.9.6.2/shell/jstorm_manager.sh nimbus start >> /tmp/jstorm.log 2>&1
#* * * * * /bin/sh /home/jstorm/jstorm-0.9.6.2/shell/jstorm_manager.sh supervisor start >> /tmp/jstorm.log 2>&1
#
#-------------------------------------------------------------------------------------------------------------

#引入环境变量,防止crontab的环境变量找不到
source /etc/profile
source ~/.bashrc

#进程名
#PROGRESS_NAME=WTV3_Headquarters.jar
PROGRESS_NAME=$1

#-------------------------------------------------------------------------------------------------------------
#getPID()-->获取Java应用的PID
#说明:通过JDK自带的JPS命令及grep命令,准确查找Java应用的PID
#其中:[jps -l]表示显示Java主程序的完整包路径
#     awk命令可以分割出PID($1部分)及Java主程序名称($2部分)
#例子:[$JAVA_HOME/bin/jps -l | grep $APP_MAIN]-->>[5775 com.cucpay.tradeportal.MainApp]
#另外:用这个命令也可以直接取到程序的PID-->>[ps aux|grep java|grep $APP_MAIN|grep -v grep|awk '{print $2}']
#-------------------------------------------------------------------------------------------------------------
#初始化全局变量PID,用于标识交易前置系统的PID,0表示未启动
PID=0

getPID(){
    javaps=`jps -l | grep $PROGRESS_NAME`
    if [ -n "$javaps" ]; then
        PID=`echo $javaps | awk '{print $1}'`
    else
        PID=0
    fi
}

#
#启动进程
#
start(){
    getPID
    echo "======================================================================================"
    if [ $PID -ne 0 ]; then
        echo "$PROGRESS_NAME already started(PID=$PID)"
        echo "======================================================================================"
    else
        nohup jstorm $PROGRESS_NAME >/dev/null 2>&1 &
        echo "======================================================================================"
        
        getPID
        
        int=1
        while [ $PID -eq 0 ] && [ $int -le 5 ]
        do
            echo "======================================================================================"
            echo "please wait for $PROGRESS_NAME starting"
            sleep 1
            getPID
            let "int++"
        done
        
        getPID
        if [ $PID -ne 0 ]; then
            echo "started $PROGRESS_NAME success/(PID=$PID)"
            echo "======================================================================================"
        else
            echo "[Failed]"
            echo "======================================================================================"
        fi
    fi
}


###################################
#读取脚本的第一个参数($2)，进行判断
#参数取值范围：{start|stop|restart|status|info}
#如参数不在指定范围之内，则打印帮助信息
###################################
case "$2" in
   'start')
      start
      ;;
  *)
     echo "Usage: $0 {Java package name} {start}"
     exit 1
esac
exit 0