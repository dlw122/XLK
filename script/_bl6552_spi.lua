log.info("shell -- file -- _bl6552_spi -- start")

--------------------------------------------
-- 供外部调用
--------------------------------------------
-- 电流
--------------------------------------------
local BL6552_Elect_IA_RMS = 0
local BL6552_Elect_IB_RMS = 0
local BL6552_Elect_IC_RMS = 0
-- 电压
local BL6552_Elect_VA_RMS = 0
local BL6552_Elect_VB_RMS = 0
local BL6552_Elect_VC_RMS = 0
-- 视在功率
local BL6552_Elect_VA = 0
--------------------------------------------
--------------------------------------------

--spi编号，请按实际情况修改！
local spiId = 0
--cs脚，请按需修改！
local CS_INIT = {gpio.setup(7, 0, gpio.PULLUP),gpio.setup(6, 0, gpio.PULLUP),gpio.setup(3, 0, gpio.PULLUP),gpio.setup(8, 0, gpio.PULLUP)}

local CSX = {7,6,3,8}

--------------------------------------------
-- 计量芯片是否可正常使用  0(初始状态) 1(正常) 2(错误)
--------------------------------------------
local init = 0
local Ok   = 1
local No   = 2
--------------------------------------------
-- 计量芯片是否可正常使用  0(初始状态) 1(正常) 2(错误)
--------------------------------------------
local BL6552_WR_Flag_Chx = {0,0,0,0}
--------------------------------------------
-- 存放小于1度电的脉冲底数
local Eng_CFCnt_A_CNT = 0
local Eng_CFCnt_B_CNT = 0
local Eng_CFCnt_C_CNT = 0
local Eng_CFCnt_CNT = 0

--------------------------------------------
-- 用于电能计算的中间数据
local Eng_Cal_Energy001 -- 1度以上的电累积
local Eng_Cal_cnt_remainder -- <1度电的脉冲底数
--------------------------------------------

------------------------------------------test data
local function test_data(Chx)
    return  BL6552_WR_Flag_Chx[Chx]
end
-- 
local function CS_L(cs)
    gpio.set(CSX[cs], 0)
end

--
local function CS_H(cs)
    gpio.set(CSX[1], 1)
    gpio.set(CSX[2], 1)
    gpio.set(CSX[3], 1)
    gpio.set(CSX[4], 1)
end


-- 读数据
local function bl6552_read(cs,addr) --11001001
    local str_read
    CS_L(cs)
    spi.send(spiId, string.char(0x82, addr))
    str_read = spi.recv(spiId, 4)
    CS_H(cs)
    if str_read:byte(4) == bit.band(bit.bnot(bit.band((0x82 + addr + str_read:byte(1) + str_read:byte(2) + str_read:byte(3)),0xff)),0xff) then
        return str_read:byte(1) * 65536 + str_read:byte(2) * 256 + str_read:byte(3)
    else
        return -1
    end
end

-- 
local function bl6552_write(cs,addr,data_H, data_M, data_L)
    local Chksum = bit.bnot(bit.band((0x81 + addr + data_H + data_M + data_L),0xff)) --	Chksum=~((0x81+Addr+Data_H+Data_M+Data_L)&0xFF)
    Chksum = bit.band(Chksum, 0xff) -- Chksum & 0xff
    CS_L(cs)
    spi.send(spiId,string.char(0x81, addr,data_H, data_M, data_L, Chksum))
    CS_H(cs)
end

------------------------------------------------------------
-- 是否允许对BL6552进行写入操作    1表示打开写   0表示关闭写
------------------------------------------------------------
local function BL6552_WR_Enable(cs,WR_Status)
    if WR_Status == 1 then -- 打开写保护
        bl6552_write(cs,0x9E, 0x00, 0x55, 0x55)
        bl6552_write(cs,0xE1, 0x00, 0x09, 0x50)
        bl6552_write(cs,0xDD, 0x00, 0x0D, 0x82)
    elseif WR_Status == 0 then -- 关闭写保护
        bl6552_write(cs,0xDD, 0x00, 0x00, 0x00)
        bl6552_write(cs,0xE1, 0x00, 0x00, 0x00)
    end
end

------------------------------------------------------------
-- BL6552校准参数下发
-- 校准参数保存在EEPROM中，每次上电时加载到BL6552中
-- 考虑运行时的可靠，定时检查校准参数是否丢失
------------------------------------------------------------
local function BL6552_CalSET_Proc(cs)
    -- 防潜动阈值设置
    -- 防潜动阈值设置为0.002Ib（0.01A）对应的功率值600左右，600/2=300（0x12C）
    bl6552_write(cs,0x88, 0x12, 0xc1, 0x2c)

    -- 增益 Ib 1.0修正参数
    -- 合相常数3600
    bl6552_write(cs,0xA3, 0x00, 0xfd, 0xac)
    bl6552_write(cs,0xA2, 0x00, 0xfe, 0x1d)
    bl6552_write(cs,0xA1, 0x00, 0xfe, 0xe5)
    bl6552_write(cs,0x64, 0x19, 0x19, 0x19)
    bl6552_write(cs,0x65, 0x19, 0x19, 0x19)
    bl6552_write(cs,0x66, 0x19, 0x19, 0x19)

    bl6552_write(cs,0x67, 0x00, 0x00, 0x00)
    bl6552_write(cs,0x68, 0x00, 0x00, 0x00)
    bl6552_write(cs,0x69, 0x00, 0x00, 0x00)
    -- 有功功率小信号修正 0.05Ib 1.0
    bl6552_write(cs,0xC2, 0x00, 0x00, 0x00)
    bl6552_write(cs,0xC3, 0x00, 0x00, 0x00)
    bl6552_write(cs,0xC4, 0x00, 0x00, 0x00)
end
    -- local _I_RMS_Correct    = 122
    -- local _V_RMS_Correct    = 522
------------------------------------------------------------
-- 根据设计的电表的参数进行上电配置，校准参数下发
------------------------------------------------------------
local function BL6552_Init(cs)
    BL6552_WR_Enable(cs,1) -- 打开写保护
    -- 设置各通道电流电压阈值
    log.warn("BL6552_Init chx:",cs)
    local vi_setL  = bit.band(math.floor(tonumber(fskv.get("V_NUM_CHX_CONFIG")["_" .. tostring(cs)]) * 2.4322), 0X0000FF)
    local vi_setM1 = bit.band(math.floor(tonumber(fskv.get("I_NUM_CHX_CONFIG")["_" .. tostring(cs)]) * 29.615), 0X00000F) * 16 
    local vi_setM2 = bit.rshift( bit.band( math.floor( tonumber(fskv.get("V_NUM_CHX_CONFIG")["_" .. tostring(cs)]) * 2.4322), 0X000F00), 8)
    local vi_setM  = vi_setM1 + vi_setM2
    local vi_setH  = bit.rshift(bit.band(math.floor(tonumber(fskv.get("I_NUM_CHX_CONFIG")["_" .. tostring(cs)]) * 29.615), 0X000FF0), 4)

    log.warn("H", vi_setH)
    log.warn("M", vi_setM)
    log.warn("L", vi_setL)
    bl6552_write(cs,0x8C, vi_setH, vi_setM, vi_setL) -- 250V--20A
    bl6552_write(cs,0x9A, 0xF8, 0x1F, 0xFF) -- 中断使能
    --bl6552_write(cs,0x8E, 0x04, 0x13, 0x88) -- 缺相超时检测时间设置
    bl6552_write(cs,0x93, 0x00, 0x00, 0xc3)  --使能ADC通道
    --bl6552_write(cs,0x98, 0x00, 0x92, 0x00)  --使能电量统计
    bl6552_write(cs,0x9D,0x00,0x00,0x08) --Bit[23:0]设置为 1 时，电能相关寄存器 Reg46~2F 设置为读后清零。
    BL6552_CalSET_Proc(cs)

    -- 电参数运算系统复位（外部读取寄存器），Reg3B~2F清零
    bl6552_write(cs,0x9F, 0x5a, 0x5a, 0x5a)
    sys.wait(15)
    BL6552_WR_Enable(cs,0)
    return 0
end

------------------------------------------------------------
-- 检查芯片是否OK
------------------------------------------------------------
local function BL6552_Check_(cs)
    -- 读写保护寄存器，确认是否出现异常复位情况。如果有则重新初始化,

    if (bl6552_read(cs,0x9E) ~= 0x005555) then
        BL6552_Init(cs)
        if (bl6552_read(cs,0x9E) ~= 0x005555) then
            print("BL6552_Init   ERROR***********************************************   ", cs)
            BL6552_Init(cs)
            return false
        end
    end
    
    return true
end

------------------------------------------------------------
-- 读取BL6552的相关电参数寄存器，转换为实际电参数
-- 数据运算为整数除法运算，转换后的数据为整数；
-- 实际电参数解析：
-- 电流需要/1000 安培，0.001A/LSB；电压需要/100 伏，0.01V/LSB，频率需要/100 Hz，0.01Hz/LSB，功率需要/10 瓦，0.1瓦/LSB
-- 电能=BL6552_Elect_Energy_1+Eng_CFCnt_Cnt1/Energy_K 度电，0.001度电/LSB
-- 实际使用中根据应用场景要求在EEPROM中自行保存电能数据，防止掉电丢失
-- SPI方式通信
------------------------------------------------------------2088

local function BL6552_Elect_Proc(cs)
    --校验系数 电流 电压 有效功率

    local _IA_RMS_Correct    = 119343
    local _IB_RMS_Correct    = 118102
    local _IC_RMS_Correct    = 120017

    local _VA_RMS_Correct    = 10054
    local _VB_RMS_Correct    = 10000  -- B相为 基电压 不测量
    local _VC_RMS_Correct    = 9949

    local _VI_RMS_Correct   = 63

    -- 电流有效值转换
    local _IA_RMS = bl6552_read(cs,0x0F)
    local _IB_RMS = bl6552_read(cs,0x0E)
    local _IC_RMS = bl6552_read(cs,0x0D)

    -- 电压有效值转换
    local _VA_RMS = bl6552_read(cs,0x13)
    local _VB_RMS = bl6552_read(cs,0x14)
    local _VC_RMS = bl6552_read(cs,0x15)

    -- 有效功率
    local _VI_RMS = bl6552_read(cs,0x25)

    -- 数据校正 --
    -- 校准后的功率、电压、电流计算
    _VA_RMS = math.floor(_VA_RMS) / _VA_RMS_Correct
    _VB_RMS = math.floor(_VB_RMS) / _VB_RMS_Correct
    _VC_RMS = math.floor(_VC_RMS) / _VC_RMS_Correct
    _IA_RMS = math.floor(_IA_RMS) / _IA_RMS_Correct
    _IB_RMS = math.floor(_IB_RMS) / _IB_RMS_Correct
    _IC_RMS = math.floor(_IC_RMS) / _IC_RMS_Correct

    if _IA_RMS < 0.01 then _IA_RMS = 0 end
    if _IB_RMS < 0.01 then _IB_RMS = 0 end
    if _IC_RMS < 0.01 then _IC_RMS = 0 end

    -- 校准后计算功率
    _VI_RMS = math.floor(_VI_RMS) / _VI_RMS_Correct
    --_VI_RMS = 1.73205*((_VA_RMS + _VC_RMS)/2)*((_IA_RMS + _IB_RMS + _IC_RMS)/3)*0.8    -- 有功功率

    -- 数据校正 --
    ----------------------------

    ----------------------------
    return _IA_RMS,_IB_RMS,_IC_RMS,_VA_RMS,_VB_RMS,_VC_RMS,_VI_RMS
end

local all_powers = {0,0,0,0}
-- 由于寄存器的读会导致自动清零 现在用软件去统计电量
local function get_power(cs,flag)  
    local _POWER_RMS_Correct   = 2387
    local res_power = 0
    -- 读取合共功电量寄存器计数
    local _POWER_RMS = bl6552_read(cs,0x32)
    -- 此时值已经读取到内存中 芯片的值已经清零
    _POWER_RMS = math.floor(_POWER_RMS)/_POWER_RMS_Correct
    -- 将内存的电量值增加到总电量中
    all_powers[cs] = all_powers[cs] + _POWER_RMS --统计此区间电量
    res_power = all_powers[cs] --返回此区间电量
    if flag == 0 then
        all_powers[cs] = 0 --电量统计完成后 清零
    elseif flag == 1 then
        --只是读取电量 不清零
    end
    print("------------------get_power---------------------- " .. res_power)
    return res_power
end

-- 计量芯片复位引脚
local N_RST = gpio.setup(13, 1, gpio.PULLDOWN)

sys.taskInit(function()
    N_RST(0)  
    sys.wait(15)-- 计量芯片复位引脚下拉15ms
    N_RST(1)-- 计量芯片复位引脚上拉
    local result = spi.setup(
        spiId,--串口id
        nil,
        1,          --CPHA
        0,          --CPOL
        8,          --数据宽度
        100000,     --频率
        1           --高低位顺序    
        
        -- spi.master,--主模式     可选，默认主
        -- spi.full--全双工       可选，默认全双工
    )
    if result ~= 0 then--返回值为0，表示打开成功
        print("spi open error",result)
        return
    end
    -- 初始化   1-4片计量芯片
    for i = 1, 4, 1 do
        BL6552_Init(i)
        sys.wait(50)--等写入操作完成
        --检查芯片bl6552型号,并初始化
        if false == BL6552_Check_(i) then
            log.info("spi", i,"bl6552 error!")
            BL6552_WR_Flag_Chx[i] = No
        else
            BL6552_WR_Flag_Chx[i] = Ok
        end  
        log.info("BL6552_WR_Flag_Chx - ",i, BL6552_WR_Flag_Chx[i])
    end 
    
    sys.publish("bl6552_enable",BL6552_WR_Flag_Chx[1],BL6552_WR_Flag_Chx[2],BL6552_WR_Flag_Chx[3],BL6552_WR_Flag_Chx[4])
    log.info("BL6552 -------------------------------   START ")
    sys.waitUntil("mqtt_connect_flag") -- 等待MQTT握手完成再上报芯片错误
    for i = 1, 4, 1 do
        if BL6552_WR_Flag_Chx[i] == No then
            sys.publish("DeviceWarn_Status","Alert_IC", i, "ERROR", "", "")
        end
    end
end)

log.info("shell -- file -- _bl6552_spi -- end")
------供外部文件调用的函数
return {
    BL6552_Elect_Proc = BL6552_Elect_Proc,
    BL6552_Init = BL6552_Init,
    test_data = test_data,
    get_power = get_power
}