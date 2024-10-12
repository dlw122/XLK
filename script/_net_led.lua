log.info("shell -- file -- _net_led -- start")

--LED引脚判断赋值结束

local LEDA= gpio.setup(27, 0, gpio.PULLUP)
local LED_NET= 27
---------------------------------------------------
-- 自检灯状态刷新
---------------------------------------------------
sys.taskInit(function()
    while true do
        sys.wait(100)
    end
end)

sys.taskInit(function()
    log.info("mobile.status()", mobile.status())
    while true do
        if 0 == _key_irq.Get_Self_Check() then -- 开机
            gpio.set(LED_NET, 1)
        elseif 1 == _key_irq.Get_Self_Check() then -- 联网中
            gpio.set(LED_NET, 0)
            sys.wait(100)
            gpio.set(LED_NET, 1)
        elseif 2 == _key_irq.Get_Self_Check() then -- 已经联上网
            gpio.set(LED_NET, 0)
            sys.wait(1000)
            gpio.set(LED_NET, 1)
            sys.wait(900)
        end
        sys.wait(100)
    end



end)

log.info("shell -- file -- _net_led -- end")
