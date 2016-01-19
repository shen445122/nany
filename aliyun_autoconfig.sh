#!/bin/sh
##################################################################
#                                                                #
#阿里云服务器配置专用脚本                                        #
#   #Author：shen.szr@alibaba-inc.com                            #
#                                                                #
# 使用说明：                                                     #
# 1、若需要接入puppet，先将ip给宁冠加白名单                      #
# 2、直接运行脚本                                                #
# 3、主机名修改分为交互式修改（默认）和主机列表修改              #
#    主机列表会检查同目录是否存在文件：host.list                 #
#        文件格式为：主机名  外网卡IP                            #
# 3、默认会添加nagios,nemo用户,默认密码：ucweb@2015              #
# 4、选择安装常用软件包                                          #
# 5、检测是否安装了puppet，没有则安装                            #
##################################################################
. ~/.bash_profile

### 获取服务器信息######################################################
echo "自动获取参数..."
HOSTNAME_ORG=`hostname`
in_ip=`ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:"| head -n 1`
out_ip=`ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:"| tail -n 1`
in_mask=`ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $4}'|tr -d "Mask:"|head -n 1`
out_make=`ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $4}'|tr -d "Mask:"|tail -n 1`
in_mac=`ifconfig -a|grep HWaddr|awk '{print $5}'| head -n 1`
out_mac=`ifconfig -a|grep HWaddr|awk '{print $5}'| tail -n 1`
gateway=`grep "GATEWAY" /etc/sysconfig/network|awk -F= '{print $2}'`
########################################################################

### 修改主机名：交互式修改
Change_hostname_inter(){
    #输入主机名作为第一个参数
    echo "使用交互方式修改主机名..."
    HOSTNAME_NEW=$1
    if [ ${HOSTNAME_NEW} ];then
        echo "@修改主机名"
        sleep 1
        if [ -f /etc/hosts ] ; then 
            grep ${HOSTNAME_NEW} /etc/hosts > /dev/null 2>&1
            RET_Check_host=$?
            if [ "${RET_Check_host}" -eq "0" ];then
                echo "【Warning】 主机名已经修改完成，跳过..."
            else
                sed -i "s/${HOSTNAME_ORG}/${HOSTNAME_NEW}/g" /etc/hosts 
            fi
        else
            echo "【Error】 /etc/hosts文件不存在"
            exit 1
        fi
        
        if [ -f /etc/sysconfig/network ];then
            grep ${HOSTNAME_NEW} /etc/sysconfig/network > /dev/null 2>&1
            RET_Check_host_net=$?
            if [ "${RET_Check_host_net}" -eq "0" ];then
                echo "【Warning】 主机名已经修改完成，跳过..."
            else
                sed -i "s/${HOSTNAME_ORG}/${HOSTNAME_NEW}/g" /etc/sysconfig/network 
            fi
        else
            echo "【Error】 /etc/sysconfig/network文件不存在"
            exit 1
        fi
        hostname ${HOSTNAME_NEW}
        grep ${HOSTNAME_NEW} /etc/hosts && echo "【OK】 修改/etc/hosts成功" || (echo "【Error】 修改/etc/hosts失败" ; exit 3)
        grep ${HOSTNAME_NEW} /etc/sysconfig/network && echo "【OK】 修改/etc/sysconfig/network成功" || (echo "【Error】 修改/etc/sysconfig/network失败" ; exit 3)
        echo "【OK】主机名修改成功"
    fi
}


###修改主机名：配置文件修改#############################################
#（host.list文件格式为:主机名  外网卡IP）
Change_hostname_file(){
    echo "使用文件列表方式修改主机名..."
    if [ -e host.list ];then
        echo "@修改主机名"
        echo "@@检测到文件:[host.list]"
        sleep 1
        HOSTNAME_NEW=`grep ${out_ip} host.list | awk '{print $1}'`
        sed -i '/HOSTNAME=/d' /etc/sysconfig/network
        sed -i "/NETWORKING=yes/a HOSTNAME=${HOSTNAME_NEW}" /etc/sysconfig/network
        sed -i "/${in_ip}/d" /etc/hosts
        echo "${in_ip}    ${HOSTNAME_NEW}" >> /etc/hosts
        hostname ${HOSTNAME_NEW}
        grep ${HOSTNAME_NEW} /etc/hosts && echo "【OK】 修改/etc/hosts成功" || (echo "【Error】 修改/etc/hosts失败" ; exit 1)
        grep ${HOSTNAME_NEW} /etc/sysconfig/network && echo "【OK】 修改/etc/hosts成功" || (echo "【Error】 修改/etc/sysconfig/network失败" ; exit 1)
        echo "【OK】主机名修改成功"
    else
        echo "【Error】 检测不到list.list文件，不通过配置文件修改hostname"
        exit 1
    fi
}

### 修改系统配置项######################################################
Change_sysconf(){
    # 备份系统文件
    echo "@修改系统配置项..."
    sleep 1
    if [ -f "sysctl.conf" ];then
        if [ -f "/etc/sysctl.conf" ];then
            mv /etc/sysctl.conf /etc/sysctl.conf.save
            cp sysctl.conf /etc/
        else
            echo "【Error】 系统文件不存在：[/etc/sysctl.conf]"
            exit 1
        fi
    else
        echo "【Error】 本地文件不存在：[sysctl.conf]"
        exit 1
    fi

    if [ -f "limits.conf" ];then
        if [ -f "/etc/security/limits.conf" ];then
            mv /etc/security/limits.conf /etc/security/limits.conf.save
            cp limits.conf /etc/security/
        else
            echo "【Error】 系统文件不存在：[/etc/security/limits.conf]"
            exit 1
        fi
    else
        echo "【Error】 本地文件不存在：[limits.conf]"
        exit 1
    fi

    if [ -f "90-nproc.conf" ];then
        if [ -f "/etc/security/limits.d/90-nproc.conf" ];then
            mv /etc/security/limits.d/90-nproc.conf /etc/security/limits.d/90-nproc.conf.save
            cp 90-nproc.conf /etc/security/limits.d/
        else
            echo "【Error】 系统文件不存在：[/etc/security/limits.d/90-nproc.conf]"
            exit 1
        fi
    else
        echo "【Error】 本地文件不存在：[90-nproc.conf]"
        exit 1
    fi
    echo "【OK】成功修改系统配置项"
}

### SSH安全配置#########################################################
Change_sshd(){
    echo "@修改SSH安全配置"
    sleep 1
    if [ -f "/etc/ssh/sshd_config" ];then
        sed -i 's/#Port 22/Port 9922/g' /etc/ssh/sshd_config
        sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
    else
        echo "【Error】 系统文件不存在：[/etc/ssh/sshd_config]"
    fi
    echo "【OK】成功修改SSH安全配置"
}

### 修改网络配置########################################################
Change_ntework(){
    echo "@修改网络配置"
    sleep 1
    if [ -f /etc/sysconfig/network ];then
        grep "IPV6INIT=no" /etc/sysconfig/network > /dev/null
        if [ "$?" -eq "0" ];then
            echo "ipv6 参数已经配置:/etc/sysconfig/network，跳过.."
        else
            echo "IPV6INIT=no" >> /etc/sysconfig/network
        fi
    else
        echo "【Error】 系统文件不存在：[/etc/sysconfig/network]"
        exit 1
    fi

    if [ -f /etc/modprobe.d/disable_ipv6.conf ];then
        grep "alias ipv6 off" /etc/modprobe.d/disable_ipv6.conf > /dev/null
        if [ "$?" -eq "0" ];then
            echo "ipv6 参数已经配置:/etc/modprobe.d/disable_ipv6.conf，跳过.."
        else
            echo echo "alias ipv6 off" >> /etc/modprobe.d/disable_ipv6.conf
        fi
    else
        echo "【Error】 系统文件不存在：[/etc/modprobe.d/disable_ipv6.conf]"
        exit 1
    fi

    if [ -f /etc/modprobe.d/disable-ipv6.conf ];then
        echo "ipv6 参数已经配置:/etc/modprobe.d/disable-ipv6.conf，跳过.."
    else
        echo echo "options ipv6 disable=1" >> /etc/modprobe.d/disable-ipv6.conf
    fi

    chkconfig ip6tables off

    echo "options ipv6 disable=1" >>  /etc/modprobe.d/disable-ipv6.conf
    echo "【OK】成功修改网络配置"
}

### 修改配色方案########################################################
Change_color(){
    echo "@修改配色方案"
    sleep 1
    if [ -f /etc/bashrc ];then
        grep "color=auto" /etc/bashrc
        RET_color=$?        
        if [ "${RET_color}" -eq "0" ];then
            echo "颜色方案已经配置，跳过.."
        else
            echo "alias grep='grep --color=auto'" >> /etc/bashrc
        fi
    else
        echo "【Error】 系统文件不存在：[/etc/bashrc]"
        exit 1
    fi
    echo "【OK】成功修改修改配色方案"
}

###常用配置#############################################################
Change_vim(){
    echo "@修改Vi使用"
    echo "@检查系统是否已经安装vim..."
    rpm -qa | grep vim  && echo "【OK】" 系统已经安装vim || yum install vim  
    sleep 1
    if [ -L /bin/vi ];then
        echo "@@vim使用已经添加，跳过..."
    else
        mv /bin/vi /bin/vi.bak
        cd /bin
        ln -s /usr/bin/vim  vi
        echo "【OK】成功修改vim"
    fi
}

###设置SSH登陆白名单####################################################
Change_ssh_allow_deny(){
    echo "设置SSH登陆白名单"
    sleep 1
    grep '14.152.64.16' /etc/hosts.allow > /dev/null
    RET_hostsallow=$?
    if [ "${RET_hostsallow}" -eq "0" ];then
        echo "SSH登陆白名单已经设置，跳过"
    else
cat << EOFF >> /etc/hosts.allow
sshd:10.0.0.0/255.0.0.0:allow
sshd:119.147.225.101:allow
sshd:119.147.225.234:allow
sshd:14.152.64.22:allow
sshd:209.9.128.40/255.255.255.248:allow
sshd:183.61.109.192/255.255.255.240:allow
sshd:183.61.109.208/255.255.255.248:allow
sshd:14.152.64.72/255.255.255.248:allow
sshd:58.248.176.176/255.255.255.240:allow
sshd:122.13.84.72/255.255.255.248:allow
sshd:183.232.46.72/255.255.255.248:allow
sshd:14.152.64.96/255.255.255.240:allow
sshd:122.13.84.96/255.255.255.240:allow
sshd:183.232.46.96/255.255.255.240:allow
sshd:70.39.184.21:allow
sshd:70.39.184.36:allow
sshd:183.6.170.154:allow
sshd:14.152.64.16/255.255.255.240:allow
sshd:122.225.222.0/255.255.255.0:allow
sshd:119.147.225.0/255.255.255.0:allow
EOFF
    fi

    echo "设置SSH登陆黑名单"
    grep "sshd:all" /etc/hosts.deny > /dev/null
    RET_hostsdeny=$?
    if [ "${RET_hostsdeny}" -eq "0" ];then
        echo "SSH登陆黑名单已经设置，跳过"
    else
        echo "sshd:all" >> /etc/hosts.deny 
    fi

    echo "【OK】成功设置SSH登陆白名单"
}

###新增用户，重置密码###################################################
Add_user(){
    echo "新增用户，重置密码"
    sleep 1
    USERS="nagios nemo readonly navi napi"
    for USER in ${USERS} 
    do
        if [ "${USER}" == "readonly" ];then
            useradd readonly
            echo 'readonly:$1$f7BMpnAk$o/5kbobIsra5y57/Hyhly0'|chpasswd -e
        fi

        if [ "${USER}" == "nagios" ];then
            useradd nagios
            echo 'nagios:$1$2xP.Ss2v$l100l3y4.MACiCYMpVwTk/'|chpasswd -e
        fi

        if [ "${USER}" == "navi" ];then
            useradd navi
            echo 'navi:$1$9hNOwZFR$odfSdDHZZ3BfJAtzdy/M7.'|chpasswd -e
        fi

        if [ "${USER}" == "napi" ];then
            useradd napi
            echo 'napi:$1$9hNOwZFR$odfSdDHZZ3BfJAtzdy/M7.'|chpasswd -e
        fi

        if [ "${USER}" == "nemo" ];then
            useradd nemo
            echo 'nemo:$1$4fg7QakJ$9jxwlCfZNWvIerzKjt5DR0'|chpasswd -e
        fi
    done
    echo "【OK】已经新增用户:${USER}"

}

# 安装监控agent#########################################################
Install_monitor_agent(){
    echo "@安装监控agent"
    crontab -u nagios -l | grep 'nrpe_dog.sh' > /dev/null
    RET_nrpe=$?
    if [ "${RET_nrpe}" -eq "0" ];then
        echo "监控agent已经安装，跳过.."
    else
        su - nagios -c "curl -s http://dl.ucmo.ucweb.com:8080/install/nrpe/install_nrpe.sh | bash -s install"
    fi
    echo "【OK】成功安装监控agent"
}
########################################################################

# 安装puppet############################################################
Install_puppet(){
    echo "@安装puppet"
    crontab -l | grep 'Puppet Name' > /dev/null
    RET_puppet=$?
    if [ "${RET_puppet}" -eq "0" ];then
        echo "puppet已经安装，跳过.."
    else
        curl -s http://mirrors.ucweb.com/packages/puppet-uc/osg_puppet/update_puppet_install | bash -s
        sed -i 's/master.puppet.uc.local/puppetmaster.ucweb.com/g' /home/puppet-uc/conf/puppet.conf
        sed -i 's/mc.puppet.uc.local/puppetmq.ucweb.com/g' /home/puppet-uc/conf/mcollective.cfg 
    fi
    
    crontab -l | grep Puppet  > /dev/null && echo "【OK】 Puppet安装成功" || echo "【Error】Puppet安装失败"
}

###安装常用软件包#######################################################
Install_rpm(){
    echo "安装常用软件包"
    yum -y install libevent-devel libevent fcgi-devel.x86_64 fcgi libhugetlbfs*
    echo "【OK】安装常用软件包"
}
########################################################################

###分区#################################################################
##！！！分区的时候注意Last cylinder：21.5G=2611，107.4G=13054，具体看系统配置的云盘大小

Partition(){
    #需要输入挂载磁盘的设备名称作为第一参数,cylin数量作为第二参数输入
    echo "@开始进行分区"
    DISK_NEW=$1
    CYLIN_NEW=$2
    if [ -e ${DISK_NEW}"1" ];then
      echo "【Error】${DISK_NEW}1 已存在，停止分区"
      exit 1
    else
      echo "【OK】3秒后将对${DISK_NEW}分区，并格式化...."
      sleep 3
      fdisk ${DISK_NEW} << EOF
n
p
1
1
${CYLIN_NEW}
p
w
EOF
    fi
   
##格式化
    DISK1=${DISK_NEW}"1"
    echo "新分区名称为:${DISK1}"

    if [ -e ${DISK1} ];then
        mkfs.ext4 ${DISK1}
        mv /home /home.bak
        mkdir /home
        mount ${DISK1} /home
        cp -a /home.bak/* /home/
        e2label ${DISK1} home
        echo "LABEL=home              /home                   ext4    defaults        0 0" >> /etc/fstab
    else
        echo "【Error】 ${DISK1} 不存在"
        exit 1
    fi
    echo "【OK】分区已完成"
}
########################################################################

Check_result(){
    echo "======================="
    echo "初始化信息报告:"
    echo "主机名变更：${HOSTNAME_ORG} -- > ${HOSTNAME_NEW}"
    grep  ${HOSTNAME_NEW} /etc/hosts > /dev/null && echo "【OK】修改主机名成功：/etc/hosts" || echo "【Error】系统配置修改失败：/etc/hosts"
    grep 'net.ipv4.tcp_timestamps' /etc/sysctl.conf > /dev/null && echo "【OK】系统配置修改成功：/etc/sysctl.conf" || echo "【Error】系统配置修改失败：/etc/sysctl.conf"
    grep '131070' /etc/security/limits.conf > /dev/null && echo "【OK】系统配置修改成功：/etc/security/limits.conf" || echo "【Error】系统配置修改失败：/etc/security/limits.conf"
    grep '65535' /etc/security/limits.d/90-nproc.conf > /dev/null && echo "【OK】系统配置修改成功：/etc/security/limits.d/90-nproc.conf" || echo "【Error】系统配置修改失败：/etc/security/limits.d/90-nproc.conf"
    grep '9922' /etc/ssh/sshd_config > /dev/null && echo "【OK】SSH安全配置修改成功" || echo "【Error】SSH安全配置修改失败"
    grep 'IPV6INIT=no' /etc/sysconfig/network > /dev/null && echo "【OK】IPV6禁用修改成功" || echo "【Error】IPV6禁用修改失败"
    grep 'options ipv6 disable=1' /etc/modprobe.d/disable_ipv6.conf > /dev/null && echo "【OK】IPV6配置修改成功" || echo "【Error】IPV6配置修改失败"
    grep 'grep --color=auto' /etc/bashrc > /dev/null && echo "【OK】配色方案修改成功" || echo "【Error】配色方案修改失败"
    if [ -L '/bin/vi' ];then
        echo "【OK】配色方案修改成功" 
    else 
        echo "【Error】配色方案修改失败" 
    fi
    grep '14.152.64.72' /etc/hosts.allow > /dev/null && echo "【OK】SSH登陆白名单设置成功" || echo "【Error】SSH登陆白名单设置失败"
    grep 'sshd:all' /etc/hosts.deny > /dev/null && echo "【OK】SSH登陆黑名单设置成功" || echo "【Error】SSH登陆黑名单设置失败"
    if [ ${DISK} ];then
        echo "【OK】分区已完成: 新磁盘大小：`fdisk -l | grep '/dev/vdb:' | awk '{print $3$4}'`"
    else
        echo "【OK】不需要进行分区！"
    fi
    grep '6777' /home/nagios/ucmon_nrpe/etc/nrpe_ucmon.cfg > /dev/null && echo "【OK】监控agent安装成功" || echo "【Error】监控agent安装失败"
    grep 'Puppet' /var/spool/cron/root > /dev/null && echo "【OK】Puppet安装成功" || echo "【Error】Puppet安装失败"
    echo "【OK】新增以下用户：" ; grep '/bin/bash' /etc/passwd | grep -v root | awk -F: '{print $1}' | xargs echo 
}

Main(){
### 获取参数############################################################
#DISK=$1
    
    echo "使用脚本前请确保服务器ip已经接入puppet白名单，否则先将ip给【宁冠】添加白名单"
    echo "使用脚本前请确保服务器ip已经接入uae白名单，先将ip给【黄家胜】加白名单"

    read -p "是否继续运行脚本(y/n)[回车默认：y]:" USER_IS_CONT
    if [ "${USER_IS_CONT}" == "n" ];then
        echo "用户终止脚本运行..."
        exit 1
    elif [ "${USER_IS_CONT}" == "y" ];then
        echo "继续运行脚本..."
    else
        echo "【Error】输入有误，退出运行！"
        exit 1
    fi

    echo "@获取参数："
    read -p "@@磁盘是否需要分区(y/n)[回车默认：y]:" USER_IS_FDISK

    if [ "${USER_IS_FDISK}" == "" ];then
        USER_IS_FDISK="y"
    fi

    DEV_NUM=`fdisk -l | grep Units | wc -l`
    if [ "${DEV_NUM}" -eq "2" ];then
        UNITS=`fdisk -l | grep Units | tail -n 1 | awk '{print $9}'`
    else
        echo "@设备检测异常，请确认只有一块磁盘需要挂载..."
        exit 1
    fi 

    if [ "${USER_IS_FDISK}" == "y" ];then
        NEW_DISK_NAME=`fdisk -l | grep "vdb" | awk '{print $2}' | awk -F: '{print $1}'`
        read -p "@@@输入磁盘设备名[回车默认：${NEW_DISK_NAME}]:" USER_DISK_NAME
        if [ "${USER_DISK_NAME}" == "" ];then
            DISK_NAME="${NEW_DISK_NAME}"
        else
            DISK_NAME="${USER_DISK_NAME}"
        fi

        fdisk -l | grep ${DISK_NAME} > /dev/null 
        RET_DISK=$?
        if [ "${RET_DISK}" -ne "0" ];then
            echo "【Error】找不到目标设备：${USER_DISK_NAME}"
            exit 1
        fi

        BYTES=`fdisk -l | grep ${DISK_NAME} | awk '{print $5}'`
        NEW_CYLIN=$((${BYTES}/${UNITS}))

        read -p "@@@输入磁盘:[自动识别：${NEW_CYLIN}]" CYLIN_INPUT
        if [ "${CYLIN_INPUT}" == "" ];then
            CYLIN=${NEW_CYLIN}
        else
            CYLIN=${CYLIN_INPUT}
        fi

    elif [ "${USER_IS_FDISK}" == "n" ]; then
        echo "【OK】不需要进行分区！"
    else
        echo "【Error】 输入错误"
        exit 1
    fi


##############Start#####
#HOSTNAME=${2}
    read -p "@@是否修改主机名(y/n)[回车默认：y]:" USER_IS_CHANGEHOST
    if [ "${USER_IS_CHANGEHOST}" == "" ];then
        USER_IS_CHANGEHOST="y"
    fi

    if [ "${USER_IS_CHANGEHOST}" == "y" ];then
        echo "@@修改主机名..."
        read -p "@@是否使用手动输入方式修改主机名(y/n)[回车默认：y]:" USER_IS_MANUAL

        if [ "${USER_IS_MANUAL}" == "" ];then
            USER_IS_MANUAL="y"
        fi

        if [ "${USER_IS_MANUAL}" == "y" ];then
            read -p "@@@输入主机名:" USER_HOST
            Change_hostname_inter ${USER_HOST}
        elif [ "${USER_IS_MANUAL}" == "n" ];then
            echo "【OK】主机名不需要手动输入变更！"
            Change_hostname_file
        else
        echo "【Error】 输入错误"
        exit 1
        fi
    elif [ "${USER_IS_CHANGEHOST}" == "n" ];then
        echo "@@不需要修改主机名..."
    else
        echo "【Error】 输入错误"
        exit 1
    fi

    if [ "${USER_IS_FDISK}" == "y" ]; then
        Partition ${DISK_NAME} ${CYLIN}
    fi

    Change_sysconf
    Change_sshd
    Change_ntework
    Change_color
    Change_vim
    Change_ssh_allow_deny
    Add_user
    Install_monitor_agent
    Install_puppet
    Install_rpm
}

Main
Check_result
