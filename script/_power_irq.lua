log.info("shell -- file --_power_irq -- start")
--配置gpio7为输入模式，下拉，并会触发中断
--请根据实际需求更改gpio编号和上下拉
local KEY_POWER =24
local uartid = 1
local power_irq_timer = 50

gpio.debounce(KEY_POWER, power_irq_timer,1)
gpio.setup(KEY_POWER, function()
    log.info("KEY_POWER - ", KEY_POWER)
    if fskv.get("POWER_CLOSE_ENABLE_CONFIG") == "1" then
        sys.publish("DeviceWarn_Status","Alert_PowerLost", 0, "", "", "0")
    end
    local str1 = string.char( 0xA5, 0xA5, 2, 0x05)
    local crc1 = 0
    for i = 1, #str1 do
        crc1 = crc1 + str1:byte(i)
    end
    crc1 = (crc1)%256
    local str_crc = string.char(crc1)
    uart.write(uartid, str1 .. str_crc)

end, gpio.PULLDOWN,gpio.FALLING)

log.info("shell -- file -- _power_irq -- end")
