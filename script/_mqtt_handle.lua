log.info("shell -- file -- mqtt_handle -- start")
local  Device_SN      = fskv.get("Device_SN")
--------------------------------------------------------------
-- OTA更新回调函数
local function fota_cb(ret)
    log.info("fota", ret)
    if ret == 0 then
        rtos.reboot()
    end
end

local function Mqtt_Handle_Whole(tjsondata)
    if tjsondata["Chx"] ~= 0 or tjsondata["Data"] == nil then
        return false
    end

    if tjsondata["Cmd"] == "Reg" and tjsondata["Data"] == "" then --
        sys.publish("DeviceResponse_Status","Reg", tjsondata["Chx"], tjsondata["Data"], _mqtt_send.get_mqttc(), "1")
    end

    -------------------------------------------更新
    if tjsondata["Cmd"] == "Update" then --
        if tjsondata["Data"] ~= "" then
            sys.publish("DeviceResponse_Status",tjsondata["Cmd"], tjsondata["Chx"], tjsondata["Data"], "", "")
            libfota.request(fota_cb, tjsondata["Data"])
            
        end
    -------------------------------------------重启
    elseif tjsondata["Cmd"] == "Restart" then --
        if tjsondata["Data"] == "" then
            sys.publish("DeviceResponse_Status",tjsondata["Cmd"], tjsondata["Chx"], tjsondata["Data"], "", "")
            rtos.reboot()
            
        end
    -------------------------------------------获取详细版本号
    elseif tjsondata["Cmd"] == "GetVer" then --
        if tjsondata["Data"] == "" then
            sys.publish("DeviceResponse_Status",tjsondata["Cmd"], tjsondata["Chx"], fskv.get("SW"), "", "")
        end
    -------------------------------------------复位
    elseif tjsondata["Cmd"] == "Reset" then --
        if tjsondata["Data"] == "" then
            fskv.set("I_SCALE_ENABLE_CHX_CONFIG", {_1 = "1",_2 = "1",_3 = "1",_4 = "1"})
            fskv.set("I_SCALE_NUM_CHX_CONFIG",{_1 = "40",_2 = "40",_3 = "40",_4 = "40"})
            fskv.set("I_NUM_CHX_CONFIG", {_1 = "20",_2 = "20",_3 = "20",_4 = "20"})
            fskv.set("V_NUM_CHX_CONFIG",{_1 = "430",_2 = "430",_3 = "430",_4 = "430"})
            fskv.set("IV_NUM_ENABLE_CHX_CONFIG", {_1 = "1",_2 = "1",_3 = "1",_4 = "1"})
            fskv.set("ZXTO_ENABLE_CHX_CONFIG",{_1 = "1",_2 = "1",_3 = "1",_4 = "1"})
            fskv.set("VVVF_ENABLE_CHX_CONFIG", {_1 = "0",_2 = "0",_3 = "0",_4 = "0"})
            fskv.set("TEMPERATURE_NUM_CONFIG", "80.00")
            fskv.set("START_Time_CHX_CONFIG",  {_1 = "0",_2 = "0",_3 = "0",_4 = "0"})
            fskv.set("CLOSE_Time_CHX_CONFIG",  {_1 = "0",_2 = "0",_3 = "0",_4 = "0"})
            fskv.set("Time_ENABLE_CHX_CONFIG", {_1 = "0",_2 = "0",_3 = "0",_4 = "0"})
            fskv.set("POWER_CLOSE_ENABLE_CONFIG", "1")
            fskv.set("ElE_CHX", {_1 = "0",_2 = "0",_3 = "0",_4 = "0"})
            fskv.set("LOCK_FLAG", "0")
            fskv.set("TimeSync_CONFIG", "")
            sys.publish("DeviceResponse_Status",tjsondata["Cmd"], tjsondata["Chx"], tjsondata["Data"], "", "")
        end
        -------------------------------------------设置温度阈值
    elseif tjsondata["Cmd"] == "Prof_MaxTemp" then
        if tonumber(tjsondata["Data"]) > 0 and tonumber(tjsondata["Data"]) < 200 then
            fskv.set("TEMPERATURE_NUM_CONFIG", tjsondata["Data"])
            -- 检测板子温度是否报警  
            --[[
            if tonumber(fskv.get("TEMPERATURE_NUM_CONFIG")) <= (math.floor(100 * tonumber(_adc.Get_Temperature())) / 100) then
                sys.publish("DeviceWarn_Status","Alert_Hot", 0, string.format("%.2f",(math.floor(100 * tonumber(_adc.Get_Temperature())) / 100)), "", "0")
                for i = 1,4,1 do
                    if _led.Get_Electromagnetic_ChX(i) == 1 then --电磁阀开启菜上报数据
                        sys.publish("LED_Chx","AlertOP",i,0)
                    end
                end 
            end
            ]]
            sys.publish("DeviceResponse_Status",tjsondata["Cmd"], tjsondata["Chx"], tjsondata["Data"], "", "")
        end
        -------------------------------------------掉电告警是否开启
    elseif tjsondata["Cmd"] == "Prof_PowerLost" then
        if tjsondata["Data"] == "1" or tjsondata["Data"] == "0" then
            fskv.set("POWER_CLOSE_ENABLE_CONFIG",tjsondata["Data"])
            sys.publish("DeviceResponse_Status","Prof_PowerLost", tjsondata["Chx"], tjsondata["Data"], "", "")
        end
    elseif tjsondata["Cmd"] == "Set_Server_Addr" then --
        if tjsondata["Data"] == "0" then 
            fskv.set("MQTT_HOST", "accesstest.360xlink.com") --国内 测试版

        elseif tjsondata["Data"] == "1" then 
            fskv.set("MQTT_HOST", "m2m.iyhl.com.my") --国外 正式版
        
        end
        sys.publish("DeviceResponse_Status","Set_Server_Addr", tjsondata["Chx"], tjsondata["Data"], "", "")
    end
    return true
end

local function Mqtt_Handle_Pass_Set(tjsondata)
    if tjsondata["Chx"] ~= 1 and tjsondata["Chx"] ~= 2 and tjsondata["Chx"] ~= 3 and tjsondata["Chx"] ~= 4 then
        return false
    end
    
    if tonumber(tjsondata["Data"]) == nil and string.len(tjsondata["Data"]) < 5 then
        return false
    end
    
    -------------------------------------------服务器控制按键
    if tjsondata["Cmd"] == "SvrOP" then --

        if fskv.get("LOCK_FLAG") == "1" then
            sys.publish("DeviceWarn_Status","Lock", 0, "1", "", "")  
        elseif  fskv.get("LOCK_FLAG") == "0" then 
            if tjsondata["Data"] == "1" or tjsondata["Data"] == "0" then
                sys.publish("LED_Chx","SvrOP",tjsondata["Chx"], tonumber(tjsondata["Data"]))
                sys.publish("DeviceResponse_Status",tjsondata["Cmd"], tjsondata["Chx"], tjsondata["Data"], "", "")
            end
        end   
    -------------------------------------------设置电压阈值
    elseif tjsondata["Cmd"] == "Prof_MaxVolt" then --
        if tonumber(tjsondata["Data"]) > 0 and tonumber(tjsondata["Data"]) < 30000 then
            fskv.sett("V_NUM_CHX_CONFIG","_" .. tostring(tjsondata["Chx"]),tjsondata["Data"])
            _bl6552_spi.BL6552_Init(tjsondata["Chx"]) --重新初始化BL6552 
            -- 状态改变即刻读取数据
            sys.publish("DeviceResponse_Status","Prof_MaxVolt", tjsondata["Chx"], tjsondata["Data"], "", "")
        end
    -------------------------------------------设置电流阈值
    elseif tjsondata["Cmd"] == "Prof_MaxAmp" then --
        if tonumber(tjsondata["Data"]) > 0 and tonumber(tjsondata["Data"]) < 30000 then
            fskv.sett("I_NUM_CHX_CONFIG", "_" .. tostring(tjsondata["Chx"]),tjsondata["Data"])
            _bl6552_spi.BL6552_Init(tjsondata["Chx"]) 
            sys.publish("DeviceResponse_Status","Prof_MaxAmp", tjsondata["Chx"], tjsondata["Data"], "", "")
        end
    -------------------------------------------设置非变频/变频    0   /   1
    elseif tjsondata["Cmd"] == "Prof_VVVF" then --
        if tjsondata["Data"] == "1" or tjsondata["Data"] == "0" then
            fskv.sett("VVVF_ENABLE_CHX_CONFIG", "_" .. tostring(tjsondata["Chx"]), tjsondata["Data"])
            sys.publish("DeviceResponse_Status","Prof_VVVF", tjsondata["Chx"], tjsondata["Data"], "", "")
        end
    -------------------------------------------设置电流比例
    elseif tjsondata["Cmd"] == "Prof_MaxSCALE" then -- 设置电流比例
        if tonumber(tjsondata["Data"]) > 0 and tonumber(tjsondata["Data"]) < 100 then
            fskv.sett("I_SCALE_NUM_CHX_CONFIG", "_" .. tostring(tjsondata["Chx"]),tjsondata["Data"])
            -- 状态改变即刻读取数据
            sys.publish("BL6552_Chx","GetChx", tjsondata["Chx"], _led.Get_Electromagnetic_ChX(tjsondata["Chx"]), "0")
            sys.publish("DeviceResponse_Status","Prof_MaxSCALE", tjsondata["Chx"], tjsondata["Data"], "", "")
        end
    -------------------------------------------定时
    elseif tjsondata["Cmd"] == "Prof_TimeOn" then
        print("string.len(tjsondata[\"Data\"]) ==" ,string.len(tjsondata["Data"]))
        if string.len(tjsondata["Data"]) % 5 == 0 then -- 接收的数据检验
            fskv.sett("START_Time_CHX_CONFIG", "_" .. tostring(tjsondata["Chx"]),tjsondata["Data"])
            sys.publish("DeviceResponse_Status","Prof_TimeOn", tjsondata["Chx"], tjsondata["Data"], "", "")
        end
    elseif tjsondata["Cmd"] == "Prof_TimeOff" then --
        if string.len(tjsondata["Data"]) % 5 == 0 then
            fskv.sett("CLOSE_Time_CHX_CONFIG", "_" .. tostring(tjsondata["Chx"]),tjsondata["Data"])
            sys.publish("DeviceResponse_Status","Prof_TimeOff", tjsondata["Chx"], tjsondata["Data"], "", "")
        end  
    end
end

local function Mqtt_Handle_Pass_Enable(tjsondata)
    if tjsondata["Chx"] ~= 1 and tjsondata["Chx"] ~= 2 and tjsondata["Chx"] ~= 3 and tjsondata["Chx"] ~= 4 then
        return false
    end

    if tjsondata["Data"] ~= "1" and tjsondata["Data"] ~= "0"then
        return false
    end
    ------------------------------------------- 电流比例使能选项
    if tjsondata["Cmd"] == "Prof_SCALE" and (tjsondata["Data"] == "1" or tjsondata["Data"] =="0") then 
        fskv.sett("I_SCALE_ENABLE_CHX_CONFIG", "_" .. tostring(tjsondata["Chx"]), tjsondata["Data"])
        -- 使能状态改变即可读取数据
        sys.publish("BL6552_Chx","GetChx", tjsondata["Chx"], _led.Get_Electromagnetic_ChX(i), "0")   
        sys.publish("DeviceResponse_Status","Prof_SCALE", tjsondata["Chx"], tjsondata["Data"], "", "")
    ------------------------------------------- 定时器使能选项
    elseif tjsondata["Cmd"] == "Prof_Time" then --
        fskv.sett("Time_ENABLE_CHX_CONFIG", "_" .. tostring(tjsondata["Chx"]), tjsondata["Data"])
        _timer.Elec_Timer_Chx_Clear("0",tjsondata["Chx"],"0") --定时器标志清除
        sys.publish("DeviceResponse_Status","Prof_Time", tjsondata["Chx"], tjsondata["Data"], "", "")

    -------------------------------------------最大电流电压是否开启
    elseif tjsondata["Cmd"] == "Prof_IV" then -- 最大电流，电压是否开启
        fskv.sett("IV_NUM_ENABLE_CHX_CONFIG", "_" .. tostring(tjsondata["Chx"]),tjsondata["Data"])
        -- 使能状态改变即可读取数据
        sys.publish("BL6552_Chx","GetChx", tjsondata["Chx"], _led.Get_Electromagnetic_ChX(i), "0")
        sys.publish("DeviceResponse_Status","Prof_IV", tjsondata["Chx"], tjsondata["Data"], "", "")
    -------------------------------------------缺相是否开启
    elseif tjsondata["Cmd"] == "Prof_ZXTO" then -- 缺相
        fskv.sett("ZXTO_ENABLE_CHX_CONFIG", "_" .. tostring(tjsondata["Chx"]), tjsondata["Data"])
        -- 使能状态改变即可读取数据
        sys.publish("BL6552_Chx","GetChx", tjsondata["Chx"], _led.Get_Electromagnetic_ChX(i), "0")     
        sys.publish("DeviceResponse_Status","Prof_ZXTO", tjsondata["Chx"], tjsondata["Data"], "", "")
    -------------------------------------------启/停用调速
    elseif tjsondata["Cmd"] == "Prof_Speed" then --
        fskv.sett("SPEED_CHX_ENABLE", "_" .. tostring(tjsondata["Chx"]), tjsondata["Data"])
        sys.publish("DeviceResponse_Status","Prof_Speed", tjsondata["Chx"], tjsondata["Data"], "", "")
    end
end

local function Mqtt_Handle_Pass_Get(tjsondata)
    if tjsondata["Chx"] ~= 1 and tjsondata["Chx"] ~= 2 and tjsondata["Chx"] ~= 3 and tjsondata["Chx"] ~= 4 then
        return false
    end

    if tjsondata["Data"] ~= "1" then
        return false
    end
    ------------------------------------------- 获取功率电压电流
    if tjsondata["Cmd"] == "GetChx_WVIP" and tjsondata["Data"] == "1" then
        local _P =  _bl6552_spi.get_power(tjsondata["Chx"],1)
        sys.publish("DeviceResponse_Status","GetChx_WVIP", tjsondata["Chx"], string.format("%.4f",_P), "", "")
    end
end

--BL6552_Data_Chx
local function Mqtt_Handle_Lock(tjsondata)
    print("Mqtt_Handle_Lock \r\n")
    print("SN = ", tjsondata["SN"])
    print("Cmd = ", tjsondata["Cmd"])
    print("Data = ", tjsondata["Data"])
    Mqtt_Handle_Whole(tjsondata)
    Mqtt_Handle_Pass_Set(tjsondata)
    Mqtt_Handle_Pass_Enable(tjsondata)
    Mqtt_Handle_Pass_Get(tjsondata)
end

--------------------------------------------------------------
local function Mqtt_Handle_Device(tjsondata)
    Mqtt_Handle_Lock(tjsondata)
end

--------------------------------------------------------------
local function Mqtt_Handle_TimeSync(tjsondata)
    fskv.set("TimeSync_CONFIG", tjsondata["Data"])

    if string.len(tjsondata["Data"]) == 5 then

        sys.publish("TimeSync",string.sub(tjsondata["Data"],1,5)) -- 系统时间已经同步
    end
end



--------------------------------------------------------------
local function Mqtt_Handle(tjsondata)
-------------------------------------------与服务器时间同步
    if tjsondata["Cmd"] == "TimeSync" then --
        Mqtt_Handle_TimeSync(tjsondata)
        return
    end

    if tjsondata["SN"] == Device_SN then
        if (tjsondata["Chx"] == 0 or tjsondata["Chx"] == 1 or tjsondata["Chx"] == 2 or tjsondata["Chx"] == 3 or tjsondata["Chx"] == 4) then -- 设备ID
            Mqtt_Handle_Device(tjsondata)
        end
    end
end

log.info("shell -- file -- mqtt_handle -- end")
-- 用户代码已结束---------------------------------------------
------供外部文件调用的函数
return {
    Mqtt_Handle = Mqtt_Handle,
}
