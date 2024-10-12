log.info("shell -- file -- _timer -- start")

-- 在定时器开启电磁阀的时候标志位为1，如果有其他单元有关闭电磁阀，此区间的定时器关闭失效标志位为 0  
local Elec_Timer_Chx_Flag = {0,0,0,0}

local time_data_num        = {0,0,0,0}  --时间，数值化
local time_data_num_base        = {0,0,0,0}  --时间，数值化
local time_data_num_real        = {0,0,0,0}  --时间，数值化

local time_in_double = {0,0,0,0}
local time_in_start_or_close = {-1,-1,-1,-1}

local function Elec_Timer_Chx_Clear(Event,Chx,Data)
    -- if Event ~= "TimeOP" and Event ~= "SysOP" then
    --     Elec_Timer_Chx_Flag[Chx] = 2
    -- elseif Event ~= "Prof_Time" then
    --     Elec_Timer_Chx_Flag[Chx] = 0
    -- end
    if Data == 0 then
        Elec_Timer_Chx_Flag[Chx] = 0
    end
end

---------------------------------------------------
-- 设备时间
---------------------------------------------------
local Server_time = {hour = 23, min = 58}

--输入时间字符串 "10:07"
local function Set_Time(time_sync)
    Server_time["hour"]  = tonumber(string.sub(time_sync, 1, 2))
    Server_time["min"]   = tonumber(string.sub(time_sync, 4, 5))
    log.info("Set_Time",Server_time["hour"],Server_time["min"])
end

---------------------------------------------------
-- 控制电磁阀定时开关
---------------------------------------------------
local function _Timer_Control_Chx(Chx,time)

    local time_num        = 0  --几个定时单元

    local time_open_data  = "" --第几个定时单元定时开启数据
    local time_close_data = "" --第几个定时单元定时关闭数据

    local start_time_table = {0,0,0,0,0,0,0,0,0,0}
    local close_time_table = {0,0,0,0,0,0,0,0,0,0}



    if fskv.get("Time_ENABLE_CHX_CONFIG")["_" .. tostring(Chx)] == "1" then

        --时间结构为 "10:00" 5字符
        local Start_time = fskv.get("START_Time_CHX_CONFIG")["_" .. tostring(Chx)] --定时器开启时间序
        local Close_time = fskv.get("CLOSE_Time_CHX_CONFIG")["_" .. tostring(Chx)] --定时器关闭时间序
        local Time_OP = "TimeOP"  -- 驱动电磁阀单元符号

        if string.len(Start_time) == string.len(Close_time) and string.len(Start_time) <= 50 then
            time_num = string.len(Start_time) / 5 -- 获取定时器开启电磁阀的时间数据
        else
            log.debug("时间长度不一致!")
            return
        end

        --两天时间转换为数字

        ----------------时间预处理

        time_data_num_real[Chx] = (tonumber(string.sub(time, 1, 2))*60 +tonumber(string.sub(time, 4, 5)))/1
        if time_in_double[Chx] == time_in_start_or_close[Chx] and time_data_num_real[Chx] == 0 then 
            
            time_data_num_base[Chx] = 1440
        end
        time_data_num[Chx] = time_data_num_base[Chx] + time_data_num_real[Chx]

        log.debug("通道",Chx,"时间----数字",time_data_num[Chx])

        ----------------定时开关时间预处理
        time_in_double[Chx] = 0
        for i = 1, time_num, 1 do
            time_open_data = string.sub(Start_time,(i - 1) * 5 + 1, i * 5)
            time_close_data = string.sub(Close_time,(i - 1) * 5 + 1, i * 5)
            --时间字符转数字
            local time_open_data_num = tonumber(string.sub(time_open_data, 1, 2))*60 +tonumber(string.sub(time_open_data, 4, 5))
            local time_close_data_num = tonumber(string.sub(time_close_data, 1, 2))*60 +tonumber(string.sub(time_close_data, 4, 5))
            if time_open_data_num < time_close_data_num then -- 时间区间不跨天
                start_time_table[i] = time_open_data_num
                close_time_table[i] = time_close_data_num
            elseif time_open_data_num > time_close_data_num then -- 时间区间跨天
                start_time_table[i] = time_open_data_num
                close_time_table[i] = time_close_data_num + 1440
                time_in_double[Chx] = i --0 1 2 3 ....
                log.debug("时间",i,"开--独立数字",start_time_table[i])
                log.debug("时间",i,"关--独立数字",close_time_table[i])
            end
        end 


        --时间区间判定  -1 1 2 3 ....
        time_in_start_or_close[Chx] = -1
        for i = 1, time_num, 1 do
            if start_time_table[i] <= time_data_num[Chx] and time_data_num[Chx] < close_time_table[i] then 
                time_in_start_or_close[Chx] = i
                break
            end
            if time_in_double[Chx] == i then
                if start_time_table[i] <= time_data_num[Chx] + 1440 and time_data_num[Chx] + 1440  < close_time_table[i] then 
                    time_in_start_or_close[Chx] = i
                    break
                end
            end
        end 

        --判断时间区域是否为跨天时区
        time_data_num_base[Chx] = 0
        if time_in_double[Chx] == time_in_start_or_close[Chx] then--在跨天的时区time_in_double[Chx]

            if time_data_num_real[Chx] < start_time_table[time_in_double[Chx]] then
                time_data_num_base[Chx] = 1440
            end
            
        end

        log.debug("开--区间",time_in_start_or_close[Chx])   
        log.debug("----区间跨天",time_in_double[Chx]) 
        log.debug("----区间控制",Elec_Timer_Chx_Flag[Chx]) 
        if time_in_start_or_close[Chx] ~= -1 then -- 
            -- 定时器开启电磁阀
            --使能变化清零
            --除定时器控制电磁阀也要清零
            --定时器关要清零
            if Elec_Timer_Chx_Flag[Chx] == 0 then
                sys.publish("LED_Chx","TimeOP",Chx,1)
                -- 使能 - 定时关闭
                Elec_Timer_Chx_Flag[Chx] = 1
            end
        else
            -- 定时器开启电磁阀
            if Elec_Timer_Chx_Flag[Chx] == 1 or Elec_Timer_Chx_Flag[Chx] == 2 then
                sys.publish("LED_Chx","TimeOP",Chx,0)
                -- 使能 - 定时关闭
                Elec_Timer_Chx_Flag[Chx] = 0
            end
        end
    end
end

---------------------------------------------------
-- 控制电磁阀所有定时开关
---------------------------------------------------
local function Timer_Control_Chx()
    local time
    -- 判断时间已经同步过
    sys.waitUntil("Mqtt_Set_Timer")
    while true do
        -- 获取当前时间
        time = string.format("%02d:%02d", Server_time["hour"], Server_time["min"]) 
        log.debug("sys time :",time)
        _Timer_Control_Chx(1,time)
        _Timer_Control_Chx(2,time)
        _Timer_Control_Chx(3,time)
        _Timer_Control_Chx(4,time)
        sys.wait(5000)
    end

end

--Mqtt 设置同步更新时间
local function Mqtt_Set_Timer_Control()
    local sec = 0
    local res,time_sync = sys.waitUntil("TimeSync") -- 等待服务器同步本机时间（至少同步一次）
    Set_Time(time_sync)    --设置本机时间
    sys.publish("Mqtt_Set_Timer")    --通知定时器任务更新时间
    while true do        --本地更新时间
        res,time_sync = sys.waitUntil("TimeSync",10000) -- 等待服务器同步本机时间（至少同步一次）
        if res == true then
            Set_Time(time_sync)    --设置本机时间
            sec = 0
            --设置本机时间  --等待10S 后续也可以计数增加10S
        elseif res == false then
            -- 时间 + 10S
            sec = sec + 10
            if sec > 59 then
                sec = 0
                sys.publish("Server_Time_Min",Server_time)    --发送分钟更新事件
                Server_time["min"] = Server_time["min"] + 1
                if Server_time["min"] > 59 then
                    Server_time["min"] = 0
                    Server_time["hour"] = Server_time["hour"] + 1
                    if Server_time["hour"] > 23 then Server_time["hour"] = 0 end
                end
            end
        end
        --清除电量
        if Server_time["hour"] == 23 and Server_time["min"] == 59 and sec == 0 then
            for i = 1, 4, 1 do
                local _P = _bl6552_spi.get_power(i,0)
                sys.publish("DeviceResponse_Status","GetEnergy", i, string.format("%.4f",_P), "", "")
            end
        end
        log.warn("-----------------------------sys time :",string.format("%02d:%02d:%02d", Server_time["hour"], Server_time["min"],sec))
    end
end

---------------------------------------信号触发顺序---------------------------------------
--【1】 TimeSync  Mqtt更新时间
--【2】 Mqtt_Set_Timer  启动本地时间更新  启动定时功能

sys.taskInit(Timer_Control_Chx)--保证断网时也能正常处理
sys.taskInit(Mqtt_Set_Timer_Control)--保证断网时也能正常处理


log.info("shell -- file -- _timer -- end")
-- 用户代码已结束---------------------------------------------
------供外部文件调用的函数
return {
    Elec_Timer_Chx_Clear = Elec_Timer_Chx_Clear,
} 
