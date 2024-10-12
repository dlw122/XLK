-- LuaTools需要PROJECT和VERSION这两个信息
PROJECT = "XLK"
VERSION = "1.0.0"
log.info("shell -- file -- main -- start")

log.setLevel("WARN")
print("log level: ",log.getLevel())

-- sys库是标配
_G.sys = require("sys")
--[[特别注意, 使用mqtt库需要下列语句]]
_G.sysplus = require("sysplus")

--[[本demo需要lbsLoc库与libnet库, 库位于script\libs, 需require]]
lbsLoc = require("lbsLoc")
libnet = require "libnet"
libfota = require "libfota"
netLed =  require("netLed")


if wdt then
    --添加硬狗防止程序卡死，在支持的设备上启用这个功能
    wdt.init(9000)--初始化watchdog设置为9s
    sys.timerLoopStart(wdt.feed, 3000)--3s喂一次狗
end

-- 系统掉电保存
_init = require("_init") 

-- 电磁阀定时器
_timer = require("_timer") 

-- 初始化计量
_bl6552_spi   = require("_bl6552_spi")
_bl6552_irq   = require("_bl6552_irq")
_bl6552_data  = require("_bl6552_data")
-- 初始化LED
_led = require("_led")

-- 初始化温度
_adc = require("_adc")

-- 初始化按键-20231224-待完善-自检锁
_key_irq = require("_key_irq")

--初始化串口
_uart  = require("_uart")
_uart  = require("_uart_debug")
--初始化掉电中断
_power_irq  = require("_power_irq")

--初始化网络连接LED
_net_led = require("_net_led")

--初始化电话卡信息
_mobile  = require("_mobile")

--初始化MQTT
_mqtt           = require("_mqtt")
_mqtt_send      = require("_mqtt_send")
_mqtt_handle    = require ("_mqtt_handle")
--初始化基站定位
_lbsLoc  = require("_lbsLoc")

-- 打印根分区的信息
log.info("fsstat--------------------------------", fs.fsstat("/"))

-- Air780E的AT固件默认会为开机键防抖, 导致部分用户刷机很麻烦
if rtos.bsp() == "EC618" and pm and pm.PWK_MODE then
    pm.power(pm.PWK_MODE, false)
end



log.info("shell -- file -- main -- end")
log.info("----------     sys.run     ----------")
-- 用户代码已结束---------------------------------------------
-- 结尾总是这一句
sys.run()
-- sys.run()之后后面不要加任何语句!!!!!


--  [日期：20240222]
--_led
--sys.timerStart(sys.publish, 62100,"BL6552_Chx", tData.tEvent, tData.tChx, tData.tData, "2")

--_bl6552_data
--if BL6552_Elect_VB_RMS_Chx[Chx] < _ZXTO_IN_NUM then ZXTO_IN_B_Chx[Chx] = 1 end

