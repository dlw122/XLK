log.info("shell -- file -- mqtt -- start")

--根据自己的服务器修改以下参数


local mqtt_port = 1883
local mqtt_isssl = false
local client_id = "test"
local user_name = "YT01"
local password = "YTMQTT"

local pub_topic = "/XLK/SFS10/send"
local sub_topic = "/XLK/SFS10/receive"

local mqttc = nil

local mqtt_lat = ""
local mqtt_lng = ""

-- 统一联网函数
sys.taskInit(function()
    _key_irq.Set_Self_Check(1)  -- 设备自检灯-连网络....
    local device_id = mcu.unique_id():toHex()
    -----------------------------
    -- 统一联网函数, 可自行删减
    ----------------------------
	if mobile then
        -- Air780E/Air600E系列
        --mobile.simid(2) -- 自动切换SIM卡
        -- LED = gpio.setup(27, 0, gpio.PULLUP)
        device_id = mobile.imei()
		log.info("统一联网函数:", "device_id",device_id)
    elseif socket or mqtt then
        -- 适配的socket库也OK
        -- 没有其他操作, 单纯给个注释说明
    else
        -- 其他不认识的bsp, 循环提示一下吧
        while 1 do
            sys.wait(1000)
            log.info("bsp", "本bsp可能未适配网络层, 请查证")
        end
    end
    -- 默认都等到联网成功
    sys.waitUntil("IP_READY")
    sys.publish("net_ready", device_id)
end)

-------------------接收队列
local recvQuene = {}
-------------------消息处理
sys.taskInit(function()

    while true do
        local ret, inMsg = sys.waitUntil("mqtt_payload")
        if ret == true then
            local tjsondata, jsonresult, errinfo = json.decode(inMsg)
            if jsonresult then
                -------------------------------------------更新

                _mqtt_handle.Mqtt_Handle(tjsondata)
            end
        end
    end

end)



sys.taskInit(function()
    -- 等待联网
    local ret, device_id = sys.waitUntil("net_ready")
    
    -- 下面的是mqtt的参数均可自行修改
    client_id = device_id

    -- 打印一下上报(pub)和下发(sub)的topic名称
    -- 上报: 设备 ---> 服务器
    -- 下发: 设备 <--- 服务器
    -- 可使用mqtt.x等客户端进行调试
    log.debug("mqtt", "pub", pub_topic)
    log.debug("mqtt", "sub", sub_topic)
	log.debug("网络已经连接成功！！")
    -- 打印一下支持的加密套件, 通常来说, 固件已包含常见的99%的加密套件
    -- if crypto.cipher_suites then
    --     log.info("cipher", "suites", json.encode(crypto.cipher_suites()))
    -- end
    if mqtt == nil then
        while 1 do
            sys.wait(1000)
            log.info("bsp", "本bsp未适配mqtt库, 请查证")
        end
    end





    -------------------------------------
    -------- MQTT 演示代码 --------------
    -------------------------------------
    --local mqtt_host = "accesstest.360xlink.com"
    --local mqtt_host = "m2m.iyhl.com.my"
    local mqtt_host = fskv.get("MQTT_HOST")
    if mqtt_host == nil then
        fskv.set("MQTT_HOST", "accesstest.360xlink.com")
        mqtt_host = fskv.get("MQTT_HOST")
    end
    mqttc = mqtt.create(nil,mqtt_host , mqtt_port, mqtt_isssl, ca_file)

    mqttc:auth(client_id,user_name,password) -- client_id必填,其余选填
    -- mqttc:keepalive(240) -- 默认值240s
    mqttc:autoreconn(true, 3000) -- 自动重连机制

    mqttc:on(function(mqtt_client, event, data, payload)
        -- 用户自定义代码
        log.debug("mqtt", "event", event, mqtt_client, data, payload)
        if event == "conack" then
            -- 联上了
            sys.publish("mqtt_conack")
            mqtt_client:subscribe(sub_topic)--单主题订阅
            -- 循环处理接收和发送的数据
            _key_irq.Set_Self_Check(2)  -- 设备自检灯-连网络....
            -- mqtt_client:subscribe({[topic1]=1,[topic2]=1,[topic3]=1})--多主题订阅
        elseif event == "recv" then
            --table.insert(recvQuene, payload)
            --log.debug("mqtt", "downlink", "topic", data, "payload", payload)
            sys.publish("mqtt_payload",payload)
        elseif event == "sent" then
            -- log.debug("mqtt", "sent", "pkgid", data)
        elseif event == "disconnect" then
            -- 非自动重连时,按需重启mqttc
            -- mqtt_client:connect()
            log.info("mqtt_recon", "网络重连中...")
            sys.publish("mqtt_recon")
            _key_irq.Set_Self_Check(1)  -- 设备自检灯-连网络....
        end
    end)

    -- mqttc自动处理重连, 除非自行关闭
    mqttc:connect()
	sys.waitUntil("mqtt_conack")
    while true do
        -- 演示等待其他task发送过来的上报信息
        local ret, topic, data, qos = sys.waitUntil("mqtt_pub", 300000)
        if ret then
            -- 提供关闭本while循环的途径, 不需要可以注释掉
            if topic == "close" then break end
            mqttc:publish(topic, data, qos)
        end
        -- 如果没有其他task上报, 可以写个空等待
        --sys.wait(60000000)
    end
    mqttc:close()
    mqttc = nil
end)


-- 数据发送的消息队列
local msgQuene = {}

-- 插入发送的数据 
local function insertMsg(payload)
    local topic = pub_topic -- 发送主题
    if mqttc and mqttc:ready() then
        table.insert(msgQuene, {t = topic, p = payload})
        sys.publish("APP_SOCKET_SEND_DATA")
    end
end

-----------------数据发送
sys.taskInit(function()
    while true do
        local res, payload = sys.waitUntil("mqtt_send")
        if mqttc and mqttc:ready() then
            log.debug("mqtt","发送的数据!")
			if res == true then 
                insertMsg(payload)
			end
        end
    end
end)

sys.taskInit(function()
    sys.wait(3000)
	local qos = 1 -- QOS0不带puback, QOS1是带puback的
    local result
    while true do
        sys.waitUntil("APP_SOCKET_SEND_DATA") --有数据需要发送
        if mqttc and mqttc:ready() then
            while #msgQuene > 0 do -- 数组大于零？执行到将数据发送完
                local outMsg = table.remove(msgQuene, 1) -- 取出并删除一个元素
                result = mqttc:publish(outMsg.t, outMsg.p, qos) -- 推送对应的mqtt消息
                if result == false then 
                    log.debug("Send Message Error!")
                else
                    log.debug("Send Message:", outMsg.t, ":", outMsg.p)
                    if outMsg.user and outMsg.user.cb then -- 如果存在回调函数
                        outMsg.user.cb(result, outMsg.user.para) -- 执行回调函数
                    end
                end
            end
        end
    end
end)

sys.taskInit(function ()
    while true do
        sys.wait(3000)
        local res, data, lat, lng = sys.waitUntil("lbsloc_result")

        log.info("定位数据", lat, lng)
        if data == 0 then 
            mqtt_lat = lat
            mqtt_lng = lng
        end
        log.debug("lua", rtos.meminfo())
        log.debug("sys", rtos.meminfo("sys"))
    end
end)




log.info("shell -- file -- mqtt -- end")
-- 用户代码已结束---------------------------------------------
------供外部文件调用的函数
return {
    insertMsg = insertMsg,
}
