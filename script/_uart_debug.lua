log.info("shell -- file -- _uart -- start")

local uartid = 1 -- 根据实际设备选取不同的uartid

-- 收取数据会触发回调, 这里的"receive" 是固定值
uart.on(uartid, "receive", function(id, len)
    local s = ""

    repeat
        -- 如果是air302, len不可信, 传1024
        -- s = uart.read(id, 1024)
        s = uart.read(id, 2)
        if #s > 0 then -- #s 是取字符串的长度
            -- 如果传输二进制/十六进制数据, 部分字符不可见, 不代表没收到
            -- 关于收发hex值,请查阅 https://doc.openluat.com/article/583
            log.warn("uart", "receive", id, #s, s:toHex())
            if s:byte(1) == 0xA5 and s:byte(2) == 0xA5 then
                --log.warn("uart", "receive", "----------接收到数据头")
                s = uart.read(id, 1)
                --log.warn("uart", "receive", "----------接收到数据长度",s:byte(1))
                local data = uart.read(id, s:byte(1))
                --log.warn("uart", "data", id, #data, data:toHex())
                local crc = 0
                for i = 1, #data - 1 do
                    -- 处理数据 
                    crc = crc + data:byte(i)
                end
                crc = (crc + s:byte(1) + 0xA5 + 0xA5)%256
                --log.warn("uart", "receive", "----------CRC 计算", crc,data:byte(#data))
                if crc == data:byte(#data) then
                    --log.warn("uart", "receive", "----------CRC 成功")
                    uart.rxClear(id) -- 清除接收缓存
                    if data:byte(1) == 1 then --写设备号
                        fskv.set("Device_SN", data:sub(4,#data - 1))
                        fskv.set("APN_TYPE", data:byte(2))
                        fskv.set("Module_TYPE", data:byte(3))
                        log.warn("uart", "写设备号", "国内",data:sub(4,#data - 1))
                        if data:byte(2) == 1 then --国内
                            fskv.set("APN", "SXZ01.GZM2MAPN") --设置国外APN
                            fskv.set("MQTT_HOST", "access.360xlink.com")
                            if data:byte(3) == 1 then     --XLK8023
                                log.warn("uart", "写设备号", "XLK8023")
                                fskv.set("Module", "XLK8023")
                                fskv.set("I_NUM_CHX_CONFIG", {_1 = "6",_2 = "6",_3 = "6",_4 = "6"})
                                fskv.set("V_NUM_CHX_CONFIG",{_1 = "420",_2 = "420",_3 = "420",_4 = "420"})
                            elseif data:byte(3) == 2 then --XLK8025
                                log.warn("uart", "写设备号", "XLK8025")
                                fskv.set("Module", "XLK8025")
                                fskv.set("I_NUM_CHX_CONFIG", {_1 = "10",_2 = "10",_3 = "10",_4 = "10"})
                                fskv.set("V_NUM_CHX_CONFIG",{_1 = "420",_2 = "420",_3 = "420",_4 = "420"})
                            elseif data:byte(3) == 3 then --XLK8026
                                log.warn("uart", "写设备号", "XLK8026")
                                fskv.set("Module", "XLK8026")
                                fskv.set("I_NUM_CHX_CONFIG", {_1 = "12",_2 = "12",_3 = "12",_4 = "12"})
                                fskv.set("V_NUM_CHX_CONFIG",{_1 = "420",_2 = "420",_3 = "420",_4 = "420"})
                            elseif data:byte(3) == 4 then --XLK8028
                                log.warn("uart", "写设备号", "XLK8028")
                                fskv.set("Module", "XLK8028")
                                fskv.set("I_NUM_CHX_CONFIG", {_1 = "16",_2 = "16",_3 = "16",_4 = "16"})
                                fskv.set("V_NUM_CHX_CONFIG",{_1 = "420",_2 = "420",_3 = "420",_4 = "420"})
                            elseif data:byte(3) == 5 then --XLK8023E
                                log.warn("uart", "写设备号", "XLK8023E")
                                fskv.set("Module", "XLK8023E")
                                fskv.set("I_NUM_CHX_CONFIG", {_1 = "6",_2 = "6",_3 = "6",_4 = "6"})
                                fskv.set("V_NUM_CHX_CONFIG",{_1 = "420",_2 = "420",_3 = "420",_4 = "420"})
                            end
                        elseif data:byte(2) == 2 then --国外
                            fskv.set("APN", "sxzcat1") --设置国外APN
                            fskv.set("MQTT_HOST", "m2m.iyhl.com.my")
                            log.warn("uart", "写设备号", "国外",data:sub(4,#data - 1))
                            if data:byte(3) == 1 then     --XLK8023
                                log.warn("uart", "写设备号", "XLK8023")
                                fskv.set("Module", "XLK8023")
                                fskv.set("I_NUM_CHX_CONFIG", {_1 = "6",_2 = "6",_3 = "6",_4 = "6"})
                                fskv.set("V_NUM_CHX_CONFIG",{_1 = "460",_2 = "460",_3 = "460",_4 = "460"})
                            elseif data:byte(3) == 4 then --XLK8028
                                log.warn("uart", "写设备号", "XLK8028")
                                fskv.set("Module", "XLK8028")
                                fskv.set("I_NUM_CHX_CONFIG", {_1 = "16",_2 = "16",_3 = "16",_4 = "16"})
                                fskv.set("V_NUM_CHX_CONFIG",{_1 = "460",_2 = "460",_3 = "460",_4 = "460"})
                            elseif data:byte(3) == 6 then --iYHL3000
                                log.warn("uart", "写设备号", "iYHL3000")
                                fskv.set("Module", "iYHL3000")
                                fskv.set("I_NUM_CHX_CONFIG", {_1 = "6",_2 = "6",_3 = "6",_4 = "6"})
                                fskv.set("V_NUM_CHX_CONFIG",{_1 = "460",_2 = "460",_3 = "460",_4 = "460"})
                            elseif data:byte(3) == 7 then --iYHL5000
                                log.warn("uart", "写设备号", "iYHL5000")
                                fskv.set("Module", "iYHL5000")
                                fskv.set("I_NUM_CHX_CONFIG", {_1 = "10",_2 = "10",_3 = "10",_4 = "10"})
                                fskv.set("V_NUM_CHX_CONFIG",{_1 = "460",_2 = "460",_3 = "460",_4 = "460"})
                            elseif data:byte(3) == 8 then --iYHL8000
                                log.warn("uart", "写设备号", "iYHL8000")
                                fskv.set("Module", "iYHL8000")
                                fskv.set("I_NUM_CHX_CONFIG", {_1 = "16",_2 = "16",_3 = "16",_4 = "16"})
                                fskv.set("V_NUM_CHX_CONFIG",{_1 = "460",_2 = "460",_3 = "460",_4 = "460"})
                            end    
                        end
                        
                    local str =  "SN ".. fskv.get("Device_SN")..",Module ".. fskv.get("Module")..",HW ".. fskv.get("HW")..",SW ".. fskv.get("SW")..",IMEI ".. mobile.imei()..",IMSI ".. mobile.imsi()..",ICCID ".. mobile.iccid()
                    local str1 = string.char( 0xA5, 0xA5, string.len(str) + 2, 0x01) .. str
                    log.warn("str len ------",string.len(str) + 2)
                    local crc1 = 0
                    for i = 1, #str1 do
                        crc1 = crc1 + str1:byte(i)
                    end
                    crc1 = (crc1)%256
                    log.warn("crc1 ------",crc1)
                    local str_crc = string.char(crc1)
                    uart.write(uartid, str1 .. str_crc)

                    log.warn("uart", "发送设备号回复",(str1 .. str_crc):toHex())
                    elseif data:byte(1) == 2 then --初始化设备
                        log.warn("uart", "初始化设备", "----------")
                        fskv.set("I_SCALE_ENABLE_CHX_CONFIG", {_1 = "1",_2 = "1",_3 = "1",_4 = "1"})
                        fskv.set("I_SCALE_NUM_CHX_CONFIG",{_1 = "40",_2 = "40",_3 = "40",_4 = "40"})
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
                        local str1 = string.char( 0xA5, 0xA5, 2, 0x02)
                        local crc1 = 0
                        for i = 1, #str1 do
                            crc1 = crc1 + str1:byte(i)
                        end
                        crc1 = (crc1)%256
                        local str_crc = string.char(crc1)
                        uart.write(uartid, str1 .. str_crc)
                    elseif data:byte(1) == 3 then --数据测试
                        -- 电流
                        local BL6552_Elect_IA_RMS_Chx = {0,0,0,0}
                        local BL6552_Elect_IB_RMS_Chx = {0,0,0,0}
                        local BL6552_Elect_IC_RMS_Chx = {0,0,0,0}
                        -- 电压
                        local BL6552_Elect_VA_RMS_Chx = {0,0,0,0}
                        local BL6552_Elect_VB_RMS_Chx = {0,0,0,0}
                        local BL6552_Elect_VC_RMS_Chx = {0,0,0,0}
                        local BL6552_WR_Flag_Chx = {0,0,0,0}
                        -- 视在功率
                        local BL6552_Elect_VI_RMS_Chx = {0,0,0,0}

                        local str_x = {"","","",""}

                        for i = 1,4 do
                            BL6552_Elect_IA_RMS_Chx[i], BL6552_Elect_IB_RMS_Chx[i],
                            BL6552_Elect_IC_RMS_Chx[i], BL6552_Elect_VA_RMS_Chx[i],
                            BL6552_Elect_VB_RMS_Chx[i], BL6552_Elect_VC_RMS_Chx[i],
                            BL6552_Elect_VI_RMS_Chx[i] = _bl6552_data.test_data(i)

                            BL6552_WR_Flag_Chx[i] = _bl6552_spi.test_data(i)

                            str_x[i] =  string.format("%05d",math.floor(BL6552_Elect_IA_RMS_Chx[i]*100)) .. 
                                        string.format("%05d",math.floor(BL6552_Elect_IB_RMS_Chx[i]*100)) .. 
                                        string.format("%05d",math.floor(BL6552_Elect_IC_RMS_Chx[i]*100)) .. 
                                        string.format("%03d",math.floor(BL6552_Elect_VA_RMS_Chx[i])) .. 
                                        string.format("%03d",math.floor(BL6552_Elect_VB_RMS_Chx[i])) .. 
                                        string.format("%03d",math.floor(BL6552_Elect_VC_RMS_Chx[i])) ..
                                        string.format("%04d",math.floor(BL6552_Elect_VI_RMS_Chx[i]*10)) ..
                                        string.char(BL6552_WR_Flag_Chx[i])
                        end
                        
                        log.warn("uart", "数据测试" , str_x[1] .. str_x[2] .. str_x[3] .. str_x[4])
                        local str1 = string.char( 0xA5, 0xA5, 118, 0x03) ..str_x[1] .. str_x[2] .. str_x[3] .. str_x[4] 
                        local crc1 = 0
                        for i = 1, #str1 do
                            crc1 = crc1 + str1:byte(i)
                        end
                        crc1 = (crc1)%256
                        local str_crc = string.char(crc1)
                        uart.write(uartid, str1 .. str_crc)
                    elseif data:byte(1) == 4 then --DTU信息获取
                        log.warn("uart", "DTU信息获取", "----------")
                        local str1 = string.char( 0xA5, 0xA5, 28, 0x04,fskv.get("APN_TYPE"),fskv.get("Module_TYPE")) .. fskv.get("Device_SN") .. fskv.get("HW") .. fskv.get("SW")
                        local crc1 = 0
                        for i = 1, #str1 do
                            crc1 = crc1 + str1:byte(i)
                        end
                        crc1 = (crc1)%256
                        local str_crc = string.char(crc1)
                        uart.write(uartid, str1 .. str_crc)
                        log.warn("DTU信息获取", str1)
                    end
                end
            end
        end
        if #s == len then
            break
        end
    until s == ""

end)

--初始化
local result = uart.setup(uartid, 9600, 8, 1, uart.NONE,uart.LSB, 1024)
-- 并非所有设备都支持sent事件
uart.on(uartid, "sent", function(id)
    log.info("uart", "sent", id)
end)

log.info("shell -- file -- _uart -- end")
