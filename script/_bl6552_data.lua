log.info("shell -- file -- _bl6552_data -- start")

--------------------------------------------
--------------------------------------------

local _ZXTO_IN_NUM = 40  --输入缺相系数
local _ZXTO_OUT_NUM = 4  --输出缺相系数
----------------------------------通道1
-- 电流
local BL6552_Elect_IA_RMS_Chx = {0,0,0,0}
local BL6552_Elect_IB_RMS_Chx = {0,0,0,0}
local BL6552_Elect_IC_RMS_Chx = {0,0,0,0}
-- 电压
local BL6552_Elect_VA_RMS_Chx = {0,0,0,0}
local BL6552_Elect_VB_RMS_Chx = {0,0,0,0}
local BL6552_Elect_VC_RMS_Chx = {0,0,0,0}
-- 视在功率
local BL6552_Elect_VI_RMS_Chx = {0,0,0,0}
-- 电量
local BL6552_Elect_POWER_Chx = {0,0,0,0}

-- 电量时间

local BL6552_Elect_POWER_TIME_Chx = {0,0,0,0}
-- 芯片读写是否正常  1表示正常 2错误
local BL6552_WR_Flag_Chx = {0,0,0,0}
-- 输入缺相（各相电压）
local ZXTO_IN_A_Chx = {0,0,0,0}
local ZXTO_IN_B_Chx = {0,0,0,0}
local ZXTO_IN_C_Chx = {0,0,0,0}
-- 输出缺相（各项电流）
local ZXTO_OUT_A_Chx = {0,0,0,0}
local ZXTO_OUT_B_Chx = {0,0,0,0}
local ZXTO_OUT_C_Chx = {0,0,0,0}
-- 三相失衡标志
local I_SCALE_Chx = {0,0,0,0}
-- 三相失衡比例
local I_SCALE_Chx_Num = {0,0,0,0} 
-- 过流过压标志
local V_OVER_Chx = {0,0,0,0}
local I_OVER_Chx = {0,0,0,0}
----------------------------------------
--健康状态上报标志  0 上报告警状态 1 上报健康状态
local H_BL6552_WR_Flag_Chx = {0,0,0,0}
-- 输入缺相（各相电压）
local H_ZXTO_IN_A_Chx = {0,0,0,0}
local H_ZXTO_IN_B_Chx = {0,0,0,0}
local H_ZXTO_IN_C_Chx = {0,0,0,0}
-- 输出缺相（各项电流）
local H_ZXTO_OUT_A_Chx = {0,0,0,0}
local H_ZXTO_OUT_B_Chx = {0,0,0,0}
local H_ZXTO_OUT_C_Chx = {0,0,0,0}
-- 三相失衡标志
local H_I_SCALE_Chx = {0,0,0,0}
-- 过流过压标志
local H_V_OVER_Chx = {0,0,0,0}
local H_I_OVER_Chx = {0,0,0,0}
----------------------------------------
--------------------------------------------

----------------------------------------test获取电流电压
local function test_data(Chx)
    return BL6552_Elect_IA_RMS_Chx[Chx], BL6552_Elect_IB_RMS_Chx[Chx],
            BL6552_Elect_IC_RMS_Chx[Chx], BL6552_Elect_VA_RMS_Chx[Chx],
            BL6552_Elect_VB_RMS_Chx[Chx], BL6552_Elect_VC_RMS_Chx[Chx],
            BL6552_Elect_VI_RMS_Chx[Chx]
end

------时间计数
sys.taskInit(function()
    while true do
        local res,time_min_sync = sys.waitUntil("Server_Time_Min")
        for i = 1, 4, 1 do
            BL6552_Elect_POWER_TIME_Chx[i] = BL6552_Elect_POWER_TIME_Chx[i] + 1
        end
    end
end)

--------------------------------------------
-- 计量中断队列
--------------------------------------------
local ExtimsgQuene = {} -- 外部中断事件的队列

local function Check_Event_Exist(ExtiChx) -- 检测事件是否已经在队列中(中断消抖)
    for i = 1, #ExtimsgQuene, 1 do
        -- 约束条件 【事件】 【通道】
        if ExtiChx["tEvent"] == ExtimsgQuene[i]["tEvent"] and ExtiChx["tChx"] == ExtimsgQuene[i]["tChx"] then 
            return true  -- 事件已经在队列中
        end
    end
    return false
end
local function ExtiinsertMsg(ExtiChx) -- 外部中断事件插入函数
    if Check_Event_Exist(ExtiChx)  == false then --检查事件是否已经存在
        table.insert(ExtimsgQuene, ExtiChx)
    end
end

local function waitForExtiMsg() 
    return #ExtimsgQuene > 0 
end

--供外部调用的的函数，读取 电流 电压 功率 的值，需求插入数据读取队列
local function BL6552_Chx(Event,Chx,Data,Tag)    --Chx = 1,event = "key" or "bl6553_irq" or "timer" or "mqtt"
    local t = 
    {        
        tEvent  =  Event,
        tChx    =  Chx, 
        tData   =  Data,
        tTag    =  Tag,
    }
    ExtiinsertMsg(t)
end

--更新 Chx 通道的 电压 电流 有功功率
local function BL6552_Update_Data_Chx(Event,Chx,Data,Tag)
    if Data == 0 then

        --电流 A B C 电压 A B C 功率 电量(原始计数值)
        BL6552_Elect_IA_RMS_Chx[Chx], BL6552_Elect_IB_RMS_Chx[Chx],
        BL6552_Elect_IC_RMS_Chx[Chx], BL6552_Elect_VA_RMS_Chx[Chx],
        BL6552_Elect_VB_RMS_Chx[Chx], BL6552_Elect_VC_RMS_Chx[Chx],
        BL6552_Elect_VI_RMS_Chx[Chx] = _bl6552_spi.BL6552_Elect_Proc(Chx)
        if Tag == "2" then --只对电磁阀进行操作的测量采取处理电量
            BL6552_Elect_POWER_Chx[Chx] = _bl6552_spi.get_power(Chx,0)
        end

        log.warn("bl6552 Chx:", Chx, "data")
        log.warn("电流 A B C : ", BL6552_Elect_IA_RMS_Chx[Chx], BL6552_Elect_IB_RMS_Chx[Chx], BL6552_Elect_IC_RMS_Chx[Chx])
        log.warn("电压 A B C : ", BL6552_Elect_VA_RMS_Chx[Chx], BL6552_Elect_VB_RMS_Chx[Chx], BL6552_Elect_VC_RMS_Chx[Chx])
        log.warn("功率 : ",       BL6552_Elect_VI_RMS_Chx[Chx], "电量:",                       BL6552_Elect_POWER_Chx[Chx])
    elseif Data == 1 then

        BL6552_Elect_IA_RMS_Chx[Chx], BL6552_Elect_IB_RMS_Chx[Chx],
        BL6552_Elect_IC_RMS_Chx[Chx], BL6552_Elect_VA_RMS_Chx[Chx],
        BL6552_Elect_VB_RMS_Chx[Chx], BL6552_Elect_VC_RMS_Chx[Chx],
        BL6552_Elect_VI_RMS_Chx[Chx] = _bl6552_spi.BL6552_Elect_Proc(Chx)

        if Tag == "2" then --只对电磁阀进行操作的测量采取处理电量
            --读取电量  （为了清零）
            BL6552_Elect_POWER_Chx[Chx] = _bl6552_spi.get_power(Chx,0)
        elseif Tag == "0" then --
            --读取电量  （不清零，为了定时上报获取数据）
            BL6552_Elect_POWER_Chx[Chx] = _bl6552_spi.get_power(Chx,1)
        end
        
        log.warn("bl6552 Chx:", Chx, "data")
        log.warn("电流 A B C : ", BL6552_Elect_IA_RMS_Chx[Chx], BL6552_Elect_IB_RMS_Chx[Chx], BL6552_Elect_IC_RMS_Chx[Chx])
        log.warn("电压 A B C : ", BL6552_Elect_VA_RMS_Chx[Chx], BL6552_Elect_VB_RMS_Chx[Chx], BL6552_Elect_VC_RMS_Chx[Chx])
        log.warn("功率 : ",       BL6552_Elect_VI_RMS_Chx[Chx], "电量:",                       BL6552_Elect_POWER_Chx[Chx])
    end
end

----------------------------------------------------------------------
--电磁阀端口数据处理并且更新告警标志位
----------------------------------------------------------------------
local function _BL6552_Update_I_SCALE_Chx(Chx)
    if math.floor(((BL6552_Elect_IA_RMS_Chx[Chx] + 0.01) / (BL6552_Elect_IB_RMS_Chx[Chx] + 0.01)) * 100) < tonumber(fskv.get("I_SCALE_NUM_CHX_CONFIG")["_" .. tostring(Chx)]) then
        I_SCALE_Chx[Chx] = 1
        I_SCALE_Chx_Num[Chx] = math.floor(((BL6552_Elect_IA_RMS_Chx[Chx] + 0.01) / (BL6552_Elect_IB_RMS_Chx[Chx] + 0.01)) * 100)
    end
    if math.floor(((BL6552_Elect_IB_RMS_Chx[Chx] + 0.01) / (BL6552_Elect_IA_RMS_Chx[Chx] + 0.01)) * 100) < tonumber(fskv.get("I_SCALE_NUM_CHX_CONFIG")["_" .. tostring(Chx)]) then
        I_SCALE_Chx[Chx] = 1
        I_SCALE_Chx_Num[Chx] = math.floor(((BL6552_Elect_IB_RMS_Chx[Chx] + 0.01) / (BL6552_Elect_IA_RMS_Chx[Chx] + 0.01)) * 100)
    end
    if math.floor(((BL6552_Elect_IA_RMS_Chx[Chx] + 0.01) / (BL6552_Elect_IC_RMS_Chx[Chx] + 0.01)) * 100) < tonumber(fskv.get("I_SCALE_NUM_CHX_CONFIG")["_" .. tostring(Chx)]) then
        I_SCALE_Chx[Chx] = 1
        I_SCALE_Chx_Num[Chx] = math.floor(((BL6552_Elect_IA_RMS_Chx[Chx] + 0.01) / (BL6552_Elect_IC_RMS_Chx[Chx] + 0.01)) * 100)
    end
    if math.floor(((BL6552_Elect_IC_RMS_Chx[Chx] + 0.01) / (BL6552_Elect_IA_RMS_Chx[Chx] + 0.01)) * 100) < tonumber(fskv.get("I_SCALE_NUM_CHX_CONFIG")["_" .. tostring(Chx)]) then
        I_SCALE_Chx[Chx] = 1
        I_SCALE_Chx_Num[Chx] = math.floor(((BL6552_Elect_IC_RMS_Chx[Chx] + 0.01) / (BL6552_Elect_IA_RMS_Chx[Chx] + 0.01)) * 100)
    end
    if math.floor(((BL6552_Elect_IC_RMS_Chx[Chx] + 0.01) / (BL6552_Elect_IB_RMS_Chx[Chx] + 0.01)) * 100) < tonumber(fskv.get("I_SCALE_NUM_CHX_CONFIG")["_" .. tostring(Chx)]) then
        I_SCALE_Chx[Chx] = 1
        I_SCALE_Chx_Num[Chx] = math.floor(((BL6552_Elect_IC_RMS_Chx[Chx] + 0.01) / (BL6552_Elect_IB_RMS_Chx[Chx] + 0.01)) * 100)
    end
    if math.floor(((BL6552_Elect_IB_RMS_Chx[Chx] + 0.01) / (BL6552_Elect_IC_RMS_Chx[Chx] + 0.01)) * 100) < tonumber(fskv.get("I_SCALE_NUM_CHX_CONFIG")["_" .. tostring(Chx)]) then
        I_SCALE_Chx[Chx] = 1
        I_SCALE_Chx_Num[Chx] = math.floor(((BL6552_Elect_IB_RMS_Chx[Chx] + 0.01) / (BL6552_Elect_IC_RMS_Chx[Chx] + 0.01)) * 100)
    end
end

----------------------------------------------------------------------------------------------------
local function _BL6552_Update_ZXTO_IN_Chx(Chx)
    --------------------------------------
    -- 电压大小判断是否缺相
    if BL6552_Elect_VA_RMS_Chx[Chx] < _ZXTO_IN_NUM then ZXTO_IN_A_Chx[Chx] = 1 end
    --if BL6552_Elect_VB_RMS_Chx[Chx] < _ZXTO_IN_NUM then ZXTO_IN_B_Chx[Chx] = 1 end
    if BL6552_Elect_VC_RMS_Chx[Chx] < _ZXTO_IN_NUM then ZXTO_IN_C_Chx[Chx] = 1 end
    --------------------------------------
end

----------------------------------------------------------------------------------------------------
local function _BL6552_Update_ZXTO_OUT_Chx(Chx)
    
    ZXTO_OUT_A_Chx[Chx] = 0
    ZXTO_OUT_B_Chx[Chx] = 0
    ZXTO_OUT_C_Chx[Chx] = 0

    --------------------------------------
    if math.floor(((BL6552_Elect_IA_RMS_Chx[Chx] + 0.01) / (BL6552_Elect_IB_RMS_Chx[Chx] + 0.01)) * 100) < tonumber(fskv.get("I_SCALE_NUM_CHX_CONFIG")["_" .. tostring(Chx)]) then
        ZXTO_OUT_A_Chx[Chx] = 1
        
    end
    if math.floor(((BL6552_Elect_IB_RMS_Chx[Chx] + 0.01) / (BL6552_Elect_IA_RMS_Chx[Chx] + 0.01)) * 100) < tonumber(fskv.get("I_SCALE_NUM_CHX_CONFIG")["_" .. tostring(Chx)]) then
        ZXTO_OUT_A_Chx[Chx] = 1
        
    end
    
    if math.floor(((BL6552_Elect_IA_RMS_Chx[Chx] + 0.01) / (BL6552_Elect_IC_RMS_Chx[Chx] + 0.01)) * 100) < tonumber(fskv.get("I_SCALE_NUM_CHX_CONFIG")["_" .. tostring(Chx)]) then
        ZXTO_OUT_B_Chx[Chx] = 1
        
    end
    if math.floor(((BL6552_Elect_IC_RMS_Chx[Chx] + 0.01) / (BL6552_Elect_IA_RMS_Chx[Chx] + 0.01)) * 100) < tonumber(fskv.get("I_SCALE_NUM_CHX_CONFIG")["_" .. tostring(Chx)]) then
        ZXTO_OUT_B_Chx[Chx] = 1
        
    end

    if math.floor(((BL6552_Elect_IC_RMS_Chx[Chx] + 0.01) / (BL6552_Elect_IB_RMS_Chx[Chx] + 0.01)) * 100) < tonumber(fskv.get("I_SCALE_NUM_CHX_CONFIG")["_" .. tostring(Chx)]) then
        ZXTO_OUT_C_Chx[Chx] = 1
    
    end
    if math.floor(((BL6552_Elect_IB_RMS_Chx[Chx] + 0.01) / (BL6552_Elect_IC_RMS_Chx[Chx] + 0.01)) * 100) < tonumber(fskv.get("I_SCALE_NUM_CHX_CONFIG")["_" .. tostring(Chx)]) then
        ZXTO_OUT_C_Chx[Chx] = 1
        
    end
    --------------------------------------
end

--------------------------更新输入缺相-输出缺相-三相失衡 标志
-- 各相电流比  如  AB BC CA 
local function BL6552_Update_I_SCALE_Chx(Event,Chx,Data,Tag)
    I_SCALE_Chx[Chx] = 0
    I_SCALE_Chx_Num[Chx] = 0
    if Data == 1 and _led.Get_Electromagnetic_ChX(Chx) == 1 then  --重新计算标志前也要清除标志
        _BL6552_Update_I_SCALE_Chx(Chx)
    end
end
-- 各相电压 A和C的电压，由于参考电压B B电压为0 
local function BL6552_Update_ZXTO_IN_Chx(Event,Chx,Data,Tag)
    ZXTO_IN_A_Chx[Chx] = 0
    ZXTO_IN_B_Chx[Chx] = 0
    ZXTO_IN_C_Chx[Chx] = 0
    if Data == 1 and _led.Get_Electromagnetic_ChX(Chx) == 1 then  --重新计算标志前也要清除标志
        _BL6552_Update_ZXTO_IN_Chx(Chx)
    end
end

-- 各相电流  A B C 的电流
local function BL6552_Update_ZXTO_OUT_Chx(Event,Chx,Data,Tag)
    --电磁阀关闭状态时要清除标志
    ZXTO_OUT_A_Chx[Chx] = 0
    ZXTO_OUT_B_Chx[Chx] = 0
    ZXTO_OUT_C_Chx[Chx] = 0
    if Data == 1 and _led.Get_Electromagnetic_ChX(Chx) == 1 then  --重新计算标志前也要清除标志
        _BL6552_Update_ZXTO_OUT_Chx(Chx)
    end
end

----------------------------------------------------------------------
--MQTT上报状态与告警函数（具体错误）
----------------------------------------------------------------------
local function _MQTT_Warn_I_SCALE_Chx(Chx)
    if fskv.get("I_SCALE_ENABLE_CHX_CONFIG")["_" .. tostring(Chx)] == "1" then  --确实报警使能
        if I_SCALE_Chx[Chx] == 1 then
            sys.publish("DeviceWarn_Status","Alert_SCALE", Chx, string.format("%.2f_%.2f_%.2f", BL6552_Elect_IA_RMS_Chx[Chx], BL6552_Elect_IB_RMS_Chx[Chx], BL6552_Elect_IC_RMS_Chx[Chx]), "", "0")
            H_I_SCALE_Chx[Chx] = 1
            if fskv.get("VVVF_ENABLE_CHX_CONFIG")["_" .. tostring(Chx)] == "0" then -- 非变频
                sys.publish("LED_Chx","AlertOP",Chx,0)
            end 
        elseif I_SCALE_Chx[Chx] == 0 and H_I_SCALE_Chx[Chx] == 1 then --无报警 且 可以上报 健康
            H_I_SCALE_Chx[Chx] = 0
            sys.publish("DeviceWarn_Status","Alert_SCALE", Chx, string.format("%.2f_%.2f_%.2f", BL6552_Elect_IA_RMS_Chx[Chx], BL6552_Elect_IB_RMS_Chx[Chx], BL6552_Elect_IC_RMS_Chx[Chx]), "", "1")
        end
    end
end

----------------------------------------------------------------------------------------------------
local function _MQTT_Warn_ZXTO_IN_Chx(Chx)
    -- 先报输入缺相（电压）
    if fskv.get("ZXTO_ENABLE_CHX_CONFIG")["_" .. tostring(Chx)] == "1" then -- 对应通道缺相判断使能
        --缺相使能后即可上报缺相错误
        if ZXTO_IN_A_Chx[Chx] == 1 then
            sys.publish("DeviceWarn_Status","Alert_ZXTO", 0, "A", "", "0")
            H_ZXTO_IN_A_Chx[Chx] = 1
        elseif ZXTO_IN_A_Chx[Chx] == 0 and H_ZXTO_IN_A_Chx[Chx] == 1 then --无报警 且 可以上报 健康
            H_ZXTO_IN_A_Chx[Chx] = 0
            sys.publish("DeviceWarn_Status","Alert_ZXTO", 0, "A", "", "1")
        end    

        if ZXTO_IN_B_Chx[Chx] == 1 then
            sys.publish("DeviceWarn_Status","Alert_ZXTO", 0, "B", "", "0") 
            H_ZXTO_IN_B_Chx[Chx] = 1
        elseif ZXTO_IN_B_Chx[Chx] == 0 and H_ZXTO_IN_B_Chx[Chx] == 1 then --无报警 且 可以上报 健康
            H_ZXTO_IN_B_Chx[Chx] = 0
            sys.publish("DeviceWarn_Status","Alert_ZXTO", 0, "B", "", "1")
        end 

        if ZXTO_IN_C_Chx[Chx] == 1 then
            sys.publish("DeviceWarn_Status","Alert_ZXTO", 0, "C", "", "0")
            H_ZXTO_IN_C_Chx[Chx] = 1
        elseif ZXTO_IN_C_Chx[Chx] == 0 and H_ZXTO_IN_C_Chx[Chx] == 1 then --无报警 且 可以上报 健康
            H_ZXTO_IN_C_Chx[Chx] = 0
            sys.publish("DeviceWarn_Status","Alert_ZXTO", 0, "C", "", "1")
        end 
        
        if ZXTO_IN_A_Chx[Chx] == 1 or ZXTO_IN_B_Chx[Chx] == 1 or ZXTO_IN_C_Chx[Chx] == 1 then
            -- 输出缺相（电流比例去判断）
            -- 关闭电磁阀 - 事件 同统一为 ： Event = "AlertOP"
            if fskv.get("VVVF_ENABLE_CHX_CONFIG")["_" .. tostring(Chx)] == "0" then -- 非变频模式需要关闭电磁阀
                sys.publish("LED_Chx","AlertOP",Chx,0)
            end 
        end       
    end
end
----------------------------------------------------------------------------------------------------
local function _MQTT_Warn_ZXTO_OUT_Chx(Chx)
    -- 先报输入缺相（电压）
    if fskv.get("ZXTO_ENABLE_CHX_CONFIG")["_" .. tostring(Chx)] == "1" then -- 对应通道缺相判断使能
        --缺相使能后即可上报缺相错误

        if ZXTO_OUT_A_Chx[Chx] == 1 then
            sys.publish("DeviceWarn_Status","Alert_ZXTO", Chx, "A", "", "0")
            H_ZXTO_OUT_A_Chx[Chx] = 1
        elseif ZXTO_OUT_A_Chx[Chx] == 0 and H_ZXTO_OUT_A_Chx[Chx] == 1 then --无报警 且 可以上报 健康
            ZXTO_OUT_A_Chx[Chx] = 0
            sys.publish("DeviceWarn_Status","Alert_ZXTO", Chx, "A", "", "1")
        end 

        if ZXTO_OUT_B_Chx[Chx] == 1 then
            sys.publish("DeviceWarn_Status","Alert_ZXTO", Chx, "B", "", "0") 
            H_ZXTO_OUT_B_Chx[Chx] = 1
        elseif ZXTO_OUT_B_Chx[Chx] == 0 and H_ZXTO_OUT_B_Chx[Chx] == 1 then --无报警 且 可以上报 健康
            ZXTO_OUT_B_Chx[Chx] = 0
            sys.publish("DeviceWarn_Status","Alert_ZXTO", Chx, "B", "", "1")
        end 

        if ZXTO_OUT_C_Chx[Chx] == 1 then
            sys.publish("DeviceWarn_Status","Alert_ZXTO", Chx, "C", "", "0")
            H_ZXTO_OUT_C_Chx[Chx] = 1
        elseif ZXTO_OUT_C_Chx[Chx] == 0 and H_ZXTO_OUT_C_Chx[Chx] == 1 then --无报警 且 可以上报 健康
            ZXTO_OUT_C_Chx[Chx] = 0
            sys.publish("DeviceWarn_Status","Alert_ZXTO", Chx, "C", "", "1")
        end 

        if ZXTO_OUT_A_Chx[Chx] == 1 or ZXTO_OUT_B_Chx[Chx] == 1 or ZXTO_OUT_C_Chx[Chx] == 1 then
            -- 输出缺相（电流比例去判断）
            -- 关闭电磁阀 - 事件 同统一为 ： Event = "AlertOP"
            --（暂时不用上报电流 20240403）sys.publish("DeviceWarn_Status","Alert_ZXTO", Chx, string.format("%.2f_%.2f_%.2f", BL6552_Elect_IA_RMS_Chx[Chx], BL6552_Elect_IB_RMS_Chx[Chx], BL6552_Elect_IC_RMS_Chx[Chx]), "", "")
            if fskv.get("VVVF_ENABLE_CHX_CONFIG")["_" .. tostring(Chx)] == "0" then -- 非变频模式需要关闭电磁阀
                sys.publish("LED_Chx","AlertOP",Chx,0)
            end 
        end       
    end
end
----------------------------------------------------------------------------------------------------
local function _MQTT_Warn_VI_OVER_Chx(Chx)
    -- 过压 过流报警
    if fskv.get("IV_NUM_ENABLE_CHX_CONFIG")["_" .. tostring(Chx)] == "1" then -- 对应通道缺相判断使能
        log.warn("_MQTT_Warn_V_OVER_Chx -ABC- ",BL6552_Elect_VA_RMS_Chx[Chx],BL6552_Elect_VC_RMS_Chx[Chx],tonumber(fskv.get("V_NUM_CHX_CONFIG")["_" .. tostring(Chx)]))
        log.warn("_MQTT_Warn_I_OVER_Chx -- ",BL6552_Elect_IA_RMS_Chx[Chx],BL6552_Elect_IB_RMS_Chx[Chx],BL6552_Elect_IC_RMS_Chx[Chx],tonumber(fskv.get("I_NUM_CHX_CONFIG")["_" .. tostring(Chx)]))
        if BL6552_Elect_VA_RMS_Chx[Chx] > tonumber(fskv.get("V_NUM_CHX_CONFIG")["_" .. tostring(Chx)]) then 
            sys.publish("DeviceWarn_Status","Alert_VF", Chx, string.format("%.2f", BL6552_Elect_VA_RMS_Chx[Chx]), "", "0")
            sys.publish("LED_Chx","AlertOP",Chx,0)
            V_OVER_Chx[Chx] = 0
            H_V_OVER_Chx[Chx] = 0
        elseif BL6552_Elect_VC_RMS_Chx[Chx] > tonumber(fskv.get("V_NUM_CHX_CONFIG")["_" .. tostring(Chx)]) then
            sys.publish("DeviceWarn_Status","Alert_VF", Chx, string.format("%.2f", BL6552_Elect_VC_RMS_Chx[Chx]), "", "0")
            sys.publish("LED_Chx","AlertOP",Chx,0)
            V_OVER_Chx[Chx] = 0
            H_V_OVER_Chx[Chx] = 0
        end
        
        if BL6552_Elect_IB_RMS_Chx[Chx] > tonumber(fskv.get("I_NUM_CHX_CONFIG")["_" .. tostring(Chx)]) then
            sys.publish("DeviceWarn_Status","Alert_IF", Chx, string.format("%.2f", BL6552_Elect_IB_RMS_Chx[Chx]), "", "0")
            sys.publish("LED_Chx","AlertOP",Chx,0)
            I_OVER_Chx[Chx] = 0
            H_I_OVER_Chx[Chx] = 0
        end
    end
end
--------------------------发送输入缺相-输出缺相-三相失衡 告警
-- 各相电流比  如  AB BC CA 
local function MQTT_Warn_I_SCALE_Chx(Chx)
    _MQTT_Warn_I_SCALE_Chx(Chx)
end

-- 各相电压 A和C的电压，由于参考电压B B电压为0 
local function MQTT_Warn_ZXTO_IN_Chx(Chx)
    _MQTT_Warn_ZXTO_IN_Chx(Chx)
end

-- 各相电流  A B C 的电流
local function MQTT_Warn_ZXTO_OUT_Chx(Chx)
    _MQTT_Warn_ZXTO_OUT_Chx(Chx)
end

-- 各电磁阀过流过压告警
local function MQTT_Warn_VI_OVER_Chx(Chx)
    _MQTT_Warn_VI_OVER_Chx(Chx)
end
----------------------------------------------------------------------
--MQTT上报告警函数
----------------------------------------------------------------------
-- BL6552-告警处理函数
local function BL6552_Mqtt_Warn_Chx(Event,Chx,Data,Tag)
    if Data == 1 and _led.Get_Electromagnetic_ChX(Chx) == 1 then
        if Event == "SysOP" or Event == "SvrOP" or  Event == "KeyOP" or Event == "TimeOP" then  
            -- MQTT 处理告警事件
            if Tag == "2" then
                MQTT_Warn_ZXTO_IN_Chx(Chx)
                MQTT_Warn_ZXTO_OUT_Chx(Chx)
            elseif Tag == "1" then
                MQTT_Warn_I_SCALE_Chx(Chx)
            end
        end

        if Event == "GetChx" then  
            MQTT_Warn_I_SCALE_Chx(Chx)
        end
    elseif Data == 0 and _led.Get_Electromagnetic_ChX(Chx) == 1 then
        if Event == "Prof_IV" then  ---过压过流中断
            -- 告警  安装上面的写法  20231230  待完成
            MQTT_Warn_VI_OVER_Chx(Chx)
        end 
    end
end

----------------------------------------------------------------------
--MQTT上报状态函数
----------------------------------------------------------------------
local function BL6552_Data_Chx(Chx)
    return  BL6552_Elect_IA_RMS_Chx[Chx], BL6552_Elect_IB_RMS_Chx[Chx],
            BL6552_Elect_IC_RMS_Chx[Chx], BL6552_Elect_VA_RMS_Chx[Chx],
            BL6552_Elect_VB_RMS_Chx[Chx], BL6552_Elect_VC_RMS_Chx[Chx],
            BL6552_Elect_VI_RMS_Chx[Chx],BL6552_Elect_POWER_Chx[Chx]
end

-- BL6552-上报状态函数
local function BL6552_Mqtt_Report_Chx(Event,Chx,Data,Tag)
    -- MQTT 处理事件
    local _data
    local _IA,_IB,_IC,_VA,_VB,_VC,_W,_P = BL6552_Data_Chx(Chx)

    --事件触发是多样的
    log.warn("BL6552_Mqtt_Report_Chx事件处理---------",Event,Chx,Data,Tag)
    Event = "GetChx"  --数据上报，统一为GetChx
    
    if Data == 1 and _led.Get_Electromagnetic_ChX(Chx) == 1 then

        if V_OVER_Chx[Chx] == 1 and  H_V_OVER_Chx[Chx] == 1 then  --如果上报 过 过压告警
            -- 业务逻辑 (上报过压告警 恢复)
            if BL6552_Elect_VA_RMS_Chx[Chx] < tonumber(fskv.get("V_NUM_CHX_CONFIG")["_" .. tostring(Chx)]) and BL6552_Elect_VC_RMS_Chx[Chx] < tonumber(fskv.get("V_NUM_CHX_CONFIG")["_" .. tostring(Chx)]) then 
                sys.publish("DeviceWarn_Status","Alert_VF", Chx, string.format("%.2f", BL6552_Elect_VA_RMS_Chx[Chx]), "", "1")
                H_V_OVER_Chx[Chx] = 0
            end
        end

        if I_OVER_Chx[Chx] == 1 and  H_I_OVER_Chx[Chx] == 1 then  --如果上报 过 过流告警
            -- 业务逻辑 (上报过流告警 恢复)
            if BL6552_Elect_IB_RMS_Chx[Chx] < tonumber(fskv.get("I_NUM_CHX_CONFIG")["_" .. tostring(Chx)]) then
                sys.publish("DeviceWarn_Status","Alert_IF", Chx, string.format("%.2f", BL6552_Elect_IB_RMS_Chx[Chx]), "", "1")
                H_I_OVER_Chx[Chx] = 0
            end
        end

        --业务逻辑
        if Tag == "0" then --
            _data = string.format("%.2f_%.2f_%.2f_%.2f_%.2f_%.2f_%.2f",_W,_VA,_VB,_VC,_IA,_IB,_IC,_P) -- 上报数据
            sys.publish("DeviceResponse_Status",Event, Chx, _data, "1", Tag)   -----------
        elseif Tag == "1" then
            _data = string.format("%.2f_%.2f_%.2f_%.2f_%.2f_%.2f_%.2f",_W,_VA,_VB,_VC,_IA,_IB,_IC,_P) -- 上报数据
            sys.publish("DeviceResponse_Status",Event, Chx, _data, "1", Tag)   -----------
        elseif Tag == "2" then
            BL6552_Elect_POWER_TIME_Chx[Chx] =  0 -- 电量计时清零
            _data = string.format("%.2f_%.2f_%.2f_%.2f_%.2f_%.2f_%.2f",_W,_VA,_VB,_VC,_IA,_IB,_IC,_P) -- 上报数据
            sys.publish("DeviceResponse_Status",Event, Chx, _data, "1", Tag)   -----------
        end
    elseif Data == 0 and _led.Get_Electromagnetic_ChX(Chx) == 0 then

        --业务逻辑
        if Tag == "0" then --
            --不上报
        elseif Tag == "1" then
            --不上报
        elseif Tag == "2" then
            _data = string.format("%.4f",_P) -- 保存数据
            local _f = math.floor(BL6552_Elect_POWER_TIME_Chx[Chx]) -- 计算电量分钟数
            _data = _data .. "_" .. tostring(_f)
            sys.publish("DeviceResponse_Status","GetEnergy", Chx, _data, "0", Tag) -----------
        end

    end
end

----------------------------------------------------------------------
--  BL6552 -> MQTT  统一处理函数
----------------------------------------------------------------------
local function Update_Chx_Status(Event, Chx, Data, Tag) 
    if Event == "SysOP" or Event == "SvrOP" or  Event == "KeyOP" or Event == "TimeOP" or Event == "GetChx" or Event == "LockOP" or Event == "Prof_IV" or Event == "AlertOP" then  
        if Chx == 1 or Chx == 2 or Chx == 3 or Chx == 4 then
            if Tag == "0" or Tag == "1" or Tag == "2" then     --上报状态方式（Tag）--后续出现其他的情况，添加处理函数即可
                if Data == 1 or Data == 0 then
                    
                    BL6552_Mqtt_Report_Chx(Event,Chx,Data,Tag)

                    BL6552_Mqtt_Warn_Chx(Event,Chx,Data,Tag)    
                end
            end
        end
    end
end
-------------------------------------------- 【处理】外部事件 --------------------------------------------
sys.taskInit(function()
    local ExtiChx
    local result

    --等待BL6552芯片初始化完成
    result,BL6552_WR_Flag_Chx[1],BL6552_WR_Flag_Chx[2],BL6552_WR_Flag_Chx[3],BL6552_WR_Flag_Chx[4] = sys.waitUntil("bl6552_enable")
    sys.wait(5000)
    log.warn("BL6552事件处理开始!")
    log.info("BL6552_WR_Flag_Chx:",BL6552_WR_Flag_Chx[1],BL6552_WR_Flag_Chx[2],BL6552_WR_Flag_Chx[3],BL6552_WR_Flag_Chx[4])
    while true do
        if waitForExtiMsg() then
            while #ExtimsgQuene > 0 do -- 数组大于零？
                sys.wait(1)  -- GIAO
                local tData = table.remove(ExtimsgQuene, 1) -- 取出并删除一个元素  

                log.warn("BL6552事件处理",tData.tEvent,tData.tChx,tData.tData,tData.tTag)
                -- 参数 判断
                if BL6552_WR_Flag_Chx[tData.tChx] == 1 then --对应芯片正常
                
                    BL6552_Update_Data_Chx(tData.tEvent,tData.tChx,tData.tData,tData.tTag)     -- 【1】更新 电压 电流 有效功率
                    
                    --设置对应告警标志
                    BL6552_Update_I_SCALE_Chx(tData.tEvent,tData.tChx,tData.tData,tData.tTag)  -- 【2.1】更新是否三相失衡
            
                    BL6552_Update_ZXTO_IN_Chx(tData.tEvent,tData.tChx,tData.tData,tData.tTag)  -- 【2.2】更新是否输入缺相

                    BL6552_Update_ZXTO_OUT_Chx(tData.tEvent,tData.tChx,tData.tData,tData.tTag) -- 【2.3】更新是否输出缺相

                    -- 【3】以下函数都需要放置在Update_Chx_Status 中  具体的端口更新分为 服务器修改配置  5分钟定时上报 （按键，服务器，定时器，告警）控制电磁阀
                    --三相失衡 输出缺相 输入缺相   具体需要报什么警告  Tag 判断
                    Update_Chx_Status(tData.tEvent,tData.tChx,tData.tData,tData.tTag)
                elseif BL6552_WR_Flag_Chx[tData.tChx] == 2 then
                    log.info("BL6552 --------INIT error!!!  ",tData.tEvent,tData.tChx,tData.tData,tData.tTag)
                end
            end
        else
            sys.wait(200)
        end
    end
end)


-------------------------------------------- 【接收】外部事件 --------------------------------------------
sys.taskInit(function()
    sys.wait(2000) -- 等待2S再处理数据
    ExtimsgQuene = {} -- 清空队列，清除之前的队列消息
    log.info("BL6552 开始接受接收外部事件!")
    while true do
        local result,Event,Chx,Data,Tag = sys.waitUntil("BL6552_Chx") --接收事件内容
        if result then -- 正确接收事件内容
            BL6552_Chx(Event,Chx,Data,Tag) --将内容保存到队列
        end
    end
end)

--------------------------------------------
log.info("shell -- file -- _bl6552_data -- end")
------供外部文件调用的函数
return {
    BL6552_Chx = BL6552_Chx,
    test_data  = test_data,
    BL6552_Data_Chx = BL6552_Data_Chx
}