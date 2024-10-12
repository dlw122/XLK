log.info("shell -- file -- mobile -- start")


sys.taskInit(function()

    local APN = fskv.get("APN")
    if APN == nil then
        fskv.set("APN", "sxzcat1")
        APN = fskv.get("APN")
    end
    --设置国内外统一用此APN
    mobile.apn(0,1,APN,"","",1,3) -- 使用默认APN激活CID2
    sys.wait(2000)
    while 1 do

        sys.wait(15000)
    end
end)


log.info("shell -- file -- mobile -- end")
-- 用户代码已结束---------------------------------------------
