#!/bin/bash
#查询爱快路由器WAN 是否存在10段的IP，如果存在推送消息到微信
#食用方法如下：
#1.替换IP地址192.168.5.1为你爱快路由器的实际IP 我的是192.168.6.1
#2.注意使用浏览器F12抓包获取你自己的爱快用户username "raymand"(默认用户admin),passwd密码"8f5428afabcb11b2545ea4335ccc1cf3", pass数据"c2FsdF8xMWJiZ0AxMDMzMDE="，此2数据经过观察是固定不变的
#3.推送pushplus 消息，微信关注pushplus， 微信授权登陆官网http://www.pushplus.plus绑定获取token， 订阅激活消息， 替换token值即可


#openwrt 特殊说明  安装下载链接 https 不通可以替换为http 如无法安装可wget 下载3个包，然后本地安装
#### openwrt 需要安装依赖包,先执行opkg update
#opkg install https://openwrt.proxy.ustclug.org/snapshots/packages/x86_64/packages/jq_1.6-2_x86_64.ipk 
#opkg install  https://openwrt.proxy.ustclug.org/snapshots/packages/x86_64/packages/libcurl4_7.82.0-2_x86_64.ipk 
#opkg install https://openwrt.proxy.ustclug.org/snapshots/packages/x86_64/base/libwolfssl5.1.1.5fb91bea_5.1.1-stable-2_x86_64.ipk
#上传到/root/ikuai_adsl_up_down_check.sh   ，执行 chmod 777 /root/ikuai_adsl_up_down_check.sh
#控制台--->系统--->计划任务中添加*/30  * * * * /root/ikuai_adsl_up_down_check.sh >>ikuai_up_down_check.log



#检查是否有同个脚本在跑 ---青龙注释掉 ,opwenwrt 可打开
#PROCCESS_NUM=`ps|grep \`basename $0\`|grep -v grep|wc -l`
#if [ $PROCCESS_NUM -gt 2 ];then
 # echo "PROCCESS_NUM=$PROCCESS_NUM"
  #echo "over one `basename $0` pid is running."
  #echo "`ps|grep \`basename $0\`|grep -v grep`"
  #exit 0
#fi


cookieFile="/tmp/cookie.tmp.$$"

trap "rm -f $cookieFile" 0

CheckWan(){
curl -sSf 'http://192.168.6.1/Action/login' \
 -H 'Connection: keep-alive' \
 -H 'Pragma: no-cache' \
 -H 'Cache-Control: no-cache' \
 -H 'Accept: application/json, text/plain, */*' \
 -H 'DNT: 1' \
 -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.198 Safari/537.36' \
 -H 'Content-Type: application/json;charset=UTF-8' \
 -H 'Origin: http://192.168.6.1' \
 -H 'Referer: http://192.168.6.1/login' \
 -H 'Accept-Language: zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7,de;q=0.6,zh-TW;q=0.5' \
 --data-binary '{"username":"raymand","passwd":"8d804a5c53b69a7342c5c3c7ddc5364d","pass":"c2FsdF8xMWFkbWluIzEyMw==","remember_password":"true"}' \
 --cookie-jar $cookieFile 

if [ $? -ne 0 ];then
   echo "[`date "+%Y-%m-%d %H:%M:%S"`]err!"
   return 1
fi

waninfo=$(curl -sSfL 'http://192.168.6.1/Action/call' \
 -H 'Connection: keep-alive' \
 -H 'Pragma: no-cache' \
 -H 'Cache-Control: no-cache' \
 -H 'Accept: application/json, text/plain, */*' \
 -H 'DNT: 1' \
 -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.198 Safari/537.36' \
 -H 'Content-Type: application/json;charset=UTF-8' \
 -H 'Origin: http://192.168.6.1' \
 -H 'Referer: http://192.168.6.1/' \
 -H 'Accept-Language: zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7,de;q=0.6,zh-TW;q=0.5' \
 --data-binary '{"func_name":"wan","action":"show","param":{"TYPE":"vlan_data,vlan_total","ORDER_BY":"vlan_name","ORDER":"asc","vlan_internet":2,"interface":"'$1'","limit":"0,20"}}' \
 -b $cookieFile)


if [ $? -ne 0 ];then
  echo "[`date "+%Y-%m-%d %H:%M:%S"`]err!"
  return 1
fi

wanips=$(echo ${waninfo}|jq -r '.Data.vlan_data[] | select(.enabled == "yes") | .pppoe_ip_addr')
wanids=$(echo ${waninfo}|jq -r '.Data.vlan_data[] | select(.enabled == "yes") | .id')
needrebootip=0
#注释详细日志
#echo "[`date "+%Y-%m-%d %H:%M:%S"`][waninfo]["$waninfo"]bug"
echo "[`date "+%Y-%m-%d %H:%M:%S"`][wanips]["$wanips"]bug"
echo "[`date "+%Y-%m-%d %H:%M:%S"`][wanids]["$wanids"]bug"

for ip in $wanips
do
  ipsub=`echo $ip|awk -F'.' '{printf $1}'`
  ipsub2=`echo $ip|cut -c 1-7`
  if [ "a$ipsub" == "a" -o "a$ipsub" == "anull" -o "a$ipsub" == "a10" -o "a$ipsub" == "a172" -o "a$ipsub2" == "a192.168" ]; then
    echo "[`date "+%Y-%m-%d %H:%M:%S"`][ip][$ip] wrong ip!"
    needrebootip=1
    echo "${wanids}" > rebootnet$1.data
    break
  else
    echo "[`date "+%Y-%m-%d %H:%M:%S"`][ip][$ip] ok ip!"
  fi
done

if [ "a" == "a$wanids" ];then
  wanids=`cat rebootnet$1.data`
  if [ $? -eq 0 -a "a" != "a$wanids" ];then
    needrebootip=1
    echo "[`date "+%Y-%m-%d %H:%M:%S"`][oldids][$oldid] hove no ids need old ids reboot!"
  else
    echo "[`date "+%Y-%m-%d %H:%M:%S"`][oldids][$oldid] hove no ids and old ids need not reboot!"
    return 0
  fi
else if [ "a" != "a$wanids" -a "a" == "a$wanips" ];then
       echo "[`date "+%Y-%m-%d %H:%M:%S"`] no ip connect reboot!"
       needrebootip=1
       echo "${wanids}" > rebootnet$1.data
     fi
fi


if [ $needrebootip -eq 1 -o "a$needrebootip" == "a1" ];then
   
   curl -sSfL 'http://www.pushplus.plus/api/send' \
   -H 'Connection: keep-alive' \
   -H 'Pragma: no-cache' \
   -H 'Cache-Control: no-cache' \
   -H 'Accept: application/json, text/plain, */*' \
   -H 'DNT: 1' \
   -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.198 Safari/537.36' \
   -H 'Content-Type: application/json;charset=UTF-8' \
   -H 'Origin: http://www.pushplus.plus' \
   -H 'Referer: http://www.pushplus.plus/push1.html' \
   -H 'Accept-Encoding: gzip, deflate' \
   -H 'Accept-Language: zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7,de;q=0.6,zh-TW;q=0.5' \
   --data-binary '{"token":"c207657d4e064ce8bc97dc25ce0ab3df","title":"翡翠园线路告警","content":"'`echo "$(date +%Y-%m-%d%H:%M:%S)"`'翡翠园线路告警 存在10线路","template":"html","channel":"wechat","webhook":""}' \
   -b $cookieFile
fi
return 0
}

CheckWan wan1
#多wan 时 追加
sleep 10

CheckWan wan2
