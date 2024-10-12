log.info("shell -- file -- key_irq -- start")

--local _mqtt_send      = require("_mqtt_send")
--配置gpio7为输入模式，下拉，并会触发中断
--请根据实际需求更改gpio编号和上下拉
local KEYX = {17,19,18,2,16}

local key_timer = 100
local key_irq = "KeyOP"

-- 自检锁按下3S计时开始标志
local lock_start_time = 0

local Self_Check = 0

-- 联网状态标识
local function Set_Self_Check(DATA) 
    Self_Check = DATA
    if fskv.get("LOCK_FLAG") == "1" then
        Self_Check = 0 -- 自检灯常亮
    end
    log.debug("Self_Check",DATA)
    
end
local function Get_Self_Check() return Self_Check end

------------------------------------------------------
gpio.setup(KEYX[1] , nil)  --输入模式
------------------------------------------------------

gpio.debounce(KEYX[2], key_timer, 1)
gpio.setup(KEYX[2], function()
    log.debug(" -------------------------------", KEYX[2])
    if _led.Get_Electromagnetic_ChX(1) == 1 then 
        sys.publish("LED_Chx",key_irq,1,0)
    elseif _led.Get_Electromagnetic_ChX(1) == 0 then
        sys.publish("LED_Chx",key_irq,1,1)
    end
end, gpio.PULLUP,gpio.FALLING,4)

gpio.debounce(KEYX[3], key_timer, 1)
gpio.setup(KEYX[3], function()
    log.debug(" -------------------------------", KEYX[3])
    if _led.Get_Electromagnetic_ChX(2) == 1 then 
        sys.publish("LED_Chx",key_irq,2,0)
    elseif _led.Get_Electromagnetic_ChX(2) == 0 then
        sys.publish("LED_Chx",key_irq,2,1)
    end
end, gpio.PULLUP,gpio.FALLING,4)

gpio.debounce(KEYX[4], key_timer, 1)
gpio.setup(KEYX[4], function()
    log.debug(" -------------------------------", KEYX[4])
    if _led.Get_Electromagnetic_ChX(3) == 1 then 
        sys.publish("LED_Chx",key_irq,3,0)
    elseif _led.Get_Electromagnetic_ChX(3) == 0 then
        sys.publish("LED_Chx",key_irq,3,1)
    end
end, gpio.PULLUP,gpio.FALLING)

gpio.debounce(KEYX[5], key_timer, 1)
gpio.setup(KEYX[5], function()
    log.debug(" -------------------------------", KEYX[5])
    if _led.Get_Electromagnetic_ChX(4) == 1 then 
        sys.publish("LED_Chx",key_irq,4,0)
    elseif _led.Get_Electromagnetic_ChX(4) == 0 then
        sys.publish("LED_Chx",key_irq,4,1)
    end
end, gpio.PULLUP,gpio.FALLING)

-- 处理自检按键
sys.taskInit(function()
    local lock_num = 0
    local Self = 0
    sys.wait(1000)
    while true do
        -- 自检按键按下后
        if 1 == gpio.get(KEYX[1]) then
            lock_num = 0
        elseif 0 == gpio.get(KEYX[1]) then
            lock_num = lock_num + 1
            if (lock_num > 30) then
                lock_num = 0
                if (fskv.get("LOCK_FLAG") == "0") then
                    fskv.set("LOCK_FLAG", "1")
                    sys.wait(100)
                    Self_Check = 0 -- 自检灯常亮
                    -- 关闭所有电磁阀、灯

                    for i = 1,4,1 do
                        if _led.Get_Electromagnetic_ChX(i) == 1 then --电磁阀开启菜上报数据
                            sys.publish("LED_Chx","LockOP",i,0)
                        end
                    end 

                    sys.publish("DeviceWarn_Status","Lock", 0, "1", "", "")
                    log.debug("锁上--------------",fskv.get("LOCK_FLAG"))
                elseif (fskv.get("LOCK_FLAG") == "1") then -- 处于加锁状态
                    fskv.set("LOCK_FLAG", "0") -- 与按键状态不一样，这个时在开机10S使用，按键保存时5S，放在一起会导致未使用就保存初始值
                    sys.wait(100)
                    Self_Check = _mqtt_send.get_mqtt_connect_flag() -- 更新灯状态

                    for i = 1,4,1 do
                        if _led.Get_Electromagnetic_ChX(i) == 1 then --电磁阀开启菜上报数据
                            sys.publish("LED_Chx","Lock",i,0)
                        end
                    end 
                    sys.publish("DeviceWarn_Status","Lock", 0, "0", "", "")
                    
                    
                    log.debug("解锁--------------",fskv.get("LOCK_FLAG"))
                end
            end
        end
        sys.wait(100)
    end
end)

---------------------------------------------------
-- 开机还原关机保留的电磁阀状态
---------------------------------------------------
local function SYS_START_SET_Electromagnetic_Chx()
    --刚开机时设置系统为锁定状态
    --不需要把锁定状态上报给服务器，因为此时未联网，不需要上报
    sys.wait(15000)
    for i = 1,4,1 do
        if fskv.get("ElE_CHX")["_" .. tostring(i)] == "1" then 
            local r = crypto.trng(4)
            local _, ir = pack.unpack(r, "I")
            log.debug("延时",(ir%2500))
            sys.wait((ir%2500))
        
            sys.publish("LED_Chx","SysOP",i,tonumber(fskv.get("ElE_CHX")["_" .. tostring(i)]))
        end
    end
    sys.wait(90000)
    for i = 1,4,1 do
        sys.publish("BL6552_Chx","GetChx", i, _led.Get_Electromagnetic_ChX(i), "0")
    end
end

sys.taskInit(SYS_START_SET_Electromagnetic_Chx)

log.info("shell -- file -- key_irq -- end")
-- 用户代码已结束---------------------------------------------
------供外部文件调用的函数
return {
    Set_Self_Check       = Set_Self_Check,
    Get_Self_Check       = Get_Self_Check,
}
--
