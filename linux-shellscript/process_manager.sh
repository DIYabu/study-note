#!/bin/sh
#-------------------------------------------------------------------------------------------------------------
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#特别注意,如果你用的git没有配置SafeCrLf=true,请配置了在下载,否则git会自己转换回车换行符导致本脚本在linux环境下运行出错
#git配置方法:
#1,右击项目--->2,点击TortoiseGit选项--->3,点击Settings--->4,点击左侧git菜单--->5,设置SafeCrLf选项为true
#
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#
#
#
#使用例子:
#用法1:先将脚本放于跟jar包相同目录下，进入jar目录执行：sh process_manager.sh 进程名 动作(start|stop|restart|status|info|deploy|fallbackVersion)
#	   如启动WTV3_Headquarters4V3进程命令:sh process_manager.sh WTV3_Headquarters4V3.jar start
#	   如重启WTV3_Headquarters4V3进程命令:sh process_manager.sh WTV3_Headquarters4V3.jar restart
#	   如部署WTV3_Headquarters4V3进程命令:sh process_manager.sh WTV3_Headquarters4V3.jar deploy
#           部署的时候需要将#要部署的jar包#命名为WTV3_Headquarters4V3.jar.new,旧的jar包不用管
#           部署会将旧的jar包放到./jar_backup目录下,并在末尾加上时间戳
#           如需版本回退的时候,到./jar_backup找相应的jar包即可
#      如回退版本WTV3_Headquarters4V3进程命令:sh process_manager.sh WTV3_Headquarters4V3.jar@20150331_14_30_12 fallbackVersion
#           回退版本的命令,输入为在./jar_backup目录下,需要回退的那个jar包
#
#	   #关于脚本使用说明:
#	   #1)本管理脚本默认的启动的JVM配置为-Duser.timezone=GMT+8 -server -Xms1024m -Xmx1024m,分别代表时区,即时编译器为server,jvm 内存,jvm最大内存
#	   	#如需JVM调优,请自行修改JAVA_OPTS,如要增大启动的内存,请修改JAVA_OPTS中的-Xms -Xmx参数.
#	   #2)如需改动脚本,请直接在Linux/UNIX上面创建并编写shell脚本
#	   	#这是因为Windows下编写的*.sh文档格式和编码，是Linux/UNIX所不能完全承认的
#	   	#最直接的体现就是使用过程中会遇到很多似是而非的错误，这曾经搞疯了一大片人

#用法2:放入crontab中执行
#	   每分钟执行一次start动作的crontab的命令如下
#      * * * * * cd /home/bruce;/bin/sh /home/bruce/process_manager.sh WTV3_Headquarters4V3.jar start >>/tmp/headquarters.log 2>&1
#	   #关于crontab说明几点:
#	   #1)命令中的/home/bruce代表项目的根目录,用实际项目的根目录替换即可
#	   #2)WTV3_Headquarters4V3.jar为实际的jar包名
#	   #3)/tmp/headquarters.log为脚本运行的输出目录,crontab执行脚本的输出都在这,排查问题时可用
#	   #4)start动作已加入是否进程已经启动的判断

#另
#1)若有新需求或者bug,及时反馈给脚本开发者,王峰
#
#       hava fun
#       edited by bruce.chen
#-------------------------------------------------------------------------------------------------------------

#引入环境变量,防止crontab的环境变量找不到
source /etc/profile

#Java程序主体所在的目录,即classes的上一级目录
APP_HOME=`pwd`
if [ ! -f "$APP_HOME/$1" ] && [ "$2"x != "fallbackVersion"x ];then
    echo  "Please enter the Java package directory and enter the correct jar package name"
	echo  "your jar package directory is $APP_HOME/$1"
    exit 1
fi

#进入app 目录,防止shell执行的地方不对,导致jar包无法读取配置文件
#cd $APP_HOME

#Java程序日志所在的目录
APP_LOG=$APP_HOME/logs

#Java jar包名字
#APP_JAR_NAME=WTV3_Headquarters.jar
APP_JAR_NAME=$1

#java主程序名字
APP_NAME=`echo $1|cut -d '.' -f 1`

#JVM启动参数
#-server:一定要作为第一个参数,在多个CPU时性能佳
#-Xloggc:记录GC日志,这里建议写成绝对路径,如此便可在任意目录下执行该shell脚本
#JAVA_OPTS="-ms512m -mx512m -Xmn256m -Djava.awt.headless=true -XX:MaxPermSize=128m"
JAVA_OPTS="-Duser.timezone=GMT+8 -server -Xms1024m -Xmx1024m -Xloggc:$APP_LOG/gc.log"


#若以主类启动,需要的配置,以jar包启动,不需要修改--------------------------------------------------------------------------------------

#Java主程序,即main(String[] args)方法类
#APP_MAIN=com.cucpay.tradeportal.MainApp
#
##classpath参数,包括指定lib目录下的所有jar
#CLASSPATH=$APP_HOME/classes
#
#for tradePortalJar in "$APP_HOME"/lib/*.jar
#do
#   CLASSPATH="$CLASSPATH":"$tradePortalJar"
#done

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
    javaps=`jps -l | grep $APP_JAR_NAME`
    if [ -n "$javaps" ]; then
        PID=`echo $javaps | awk '{print $1}'`
    else
        PID=0
    fi
}

#-------------------------------------------------------------------------------------------------------------
#start()-->启动Java应用程序
#步骤:1)调用getPID()函数,刷新$PID全局变量
#     2)若程序已经启动($PID不等于0),则提示程序已启动
#     3)若程序未被启动,则执行启动命令
#     4)启动命令执行后,再次调用getPID()函数
#     5)若步骤4执行后,程序的PID不等于0,则打印[Success],否则打印[Failed]
#注意:[echo -n]表示打印字符后,不换行
#注意:[nohup command > /path/nohup.out &]是将作业输出到nohup.out,否则它会输出到该脚本目录下的nohup.out中
#-------------------------------------------------------------------------------------------------------------
start(){
    getPID
    echo "======================================================================================"
    if [ $PID -ne 0 ]; then
        echo "$APP_NAME already started(PID=$PID)"
        echo "======================================================================================"
    else
        echo  "Starting $APP_NAME"
        if [ ! -d "$APP_LOG" ];then
            mkdir "$APP_LOG"
        fi
        nohup java $JAVA_OPTS -jar $APP_HOME/$APP_JAR_NAME > $APP_LOG/nohup.out 2>&1 &
        
        getPID
        
        int=1
        while [ $PID -eq 0 ] && [ $int -le 5 ]
        do
            echo "======================================================================================"
            echo "please wait for $APP_NAME starting"
            sleep 1
            getPID
            let "int++"
        done
		
        getPID
        if [ $PID -ne 0 ]; then
            echo "(PID=$PID)...[Success]"
            echo "======================================================================================"
        else
            echo "[Failed]"
            echo "======================================================================================"
        fi
        
        tailNohup
    fi
}

#-------------------------------------------------------------------------------------------------------------
#shutdown()-->停止Java应用程序
#步骤:1)调用getPID()函数,刷新$PID全局变量
#     2)若程序已经启动($PID不等于0),则开始执行停止程序操作,否则提示程序未运行
#     3)使用[kill -9 PID]命令强制杀掉进程
#     4)使用[$?]获取上一句命令的返回值,若其为0,表示程序已停止运行,则打印[Success],反之则打印[Failed]
#     5)为防止Java程序被启动多次,这里增加了反复检查程序进程的功能,通过递归调用shutdown()函数的方式,反复kill
#注意:Shell编程中,[$?]表示上一句命令或者上一个函数的返回值
#-------------------------------------------------------------------------------------------------------------
shutdown(){
    getPID
    echo "======================================================================================"
    if [ $PID -ne 0 ]; then
        echo -n "Stopping $APP_NAME(PID=$PID)..."
        kill -9 $PID
        if [ $? -eq 0 ]; then
            echo "[Success]"
            echo "======================================================================================"
        else
            echo "[Failed]"
            echo "======================================================================================"
        fi
        getPID
        if [ $PID -ne 0 ]; then
            shutdown
        fi
    else
        echo "$APP_NAME is not running"
        echo "======================================================================================"
    fi
}

#-------------------------------------------------------------------------------------------------------------
#getServerStatus()-->检查程序运行状态
#-------------------------------------------------------------------------------------------------------------
getServerStatus(){
    getPID
    echo "======================================================================================"
    if [ $PID -ne 0 ]; then
        echo "$APP_NAME is running(PID=$PID)"
        echo "======================================================================================"
    else
        echo "$APP_NAME is not running"
        echo "======================================================================================"
    fi
}

###################################
#(函数)打印系统环境参数
###################################
info() {
   echo "System Information:"
   echo "****************************"
   echo `head -n 1 /etc/issue`
   echo `uname -a`
   echo
   echo "JAVA_HOME=$JAVA_HOME"
   echo `java -version`
   echo
   echo "APP_HOME=$APP_HOME"
   echo "APP_JAR_NAME=$APP_NAME"
   echo "****************************"
}


#jar包备份的目录
APP_JAR_BAK_HOME="$APP_HOME/jar_backup"
###################################
#部署进程
###################################
deploy(){

    if [ ! -d "$APP_JAR_BAK_HOME" ];then
        mkdir "$APP_JAR_BAK_HOME"
        echo "======================================================================================"
        echo "##deploy##create backup directory $APP_JAR_BAK_HOME"
        echo "======================================================================================"
    fi
    
    timestamp=`date +%Y%m%d_%H_%M_%S`
    
    if [ ! -f "$APP_HOME/$APP_JAR_NAME.new" ];then
        echo "======================================================================================"
        echo  "##deploy## WARNNING!! no new jar package need to deploy,the jar package must named by JAR_NAME.new  EXIT!"
        echo "======================================================================================"
        exit 1
    else
        echo  echo "======================================================================================"
        mv -n $APP_JAR_NAME $APP_JAR_BAK_HOME/$APP_JAR_NAME@$timestamp
        echo  "##deploy##moved $APP_JAR_NAME to $APP_JAR_BAK_HOME/$APP_JAR_NAME@$timestamp"
        echo  echo "======================================================================================"
        echo  echo "======================================================================================"
        mv -n $APP_JAR_NAME.new $APP_JAR_NAME
        echo  "##deploy##moved $APP_JAR_NAME.new to $APP_JAR_NAME"
        echo  echo "======================================================================================"
        shutdown
        start
    fi
    
}

###################################
#回退版本
###################################
fallbackVersion(){

    if [ ! -f "$APP_JAR_BAK_HOME/$APP_JAR_NAME" ];then
        echo "======================================================================================"
        echo "##fallbackVersion## WARNNING!! the backup jar does not exist! $APP_JAR_BAK_HOME/$APP_JAR_NAME  EXIT!"
        echo "======================================================================================"
        exit 1   
    else
        APP_JAR_NAME_ORIGIN=`echo $APP_JAR_NAME|cut -d '@' -f 1`
        echo  "======================================================================================"
        mv -n $APP_JAR_NAME_ORIGIN $APP_JAR_NAME_ORIGIN.new
        echo  "##fallbackVersion##moved $APP_JAR_NAME_ORIGIN to $APP_JAR_NAME_ORIGIN.new"
        echo  "======================================================================================"
        
        echo  "======================================================================================"
        mv -n $APP_JAR_BAK_HOME/$APP_JAR_NAME $APP_JAR_NAME_ORIGIN
        echo  "##fallbackVersion##moved $APP_JAR_BAK_HOME/$APP_JAR_NAME to $APP_JAR_NAME_ORIGIN"
        echo  "======================================================================================"
        APP_JAR_NAME=$APP_JAR_NAME_ORIGIN
        shutdown
        start
    fi
    
}

###################################
#打印nohup.out日志
###################################
tailNohup(){
    echo  "======================================================================================"
    echo  "打印日志"
    tail -100f $APP_LOG/nohup.out
    echo  "======================================================================================"
}


###################################
#读取脚本的第一个参数($1)，进行判断
#参数取值范围：{start|stop|restart|status|info}
#如参数不在指定范围之内，则打印帮助信息
###################################
case "$2" in
   'start')
      start
      ;;
   'stop')
     shutdown
     ;;
   'restart')
     shutdown
     start
     ;;
   'status')
     getServerStatus
     ;;
   'info')
     info
     ;;
   'deploy')
     deploy
     ;;
   'fallbackVersion')
     fallbackVersion
     ;;
  *)
     echo "Usage: $0 {Java package name} {start|stop|restart|status|info|deploy|fallbackVersion}"
     exit 1
esac
exit 0

