-- [[ 1. รอจนกว่าเกมและตัวละครจะโหลดเสร็จ ]]
repeat task.wait() until game:IsLoaded()
repeat task.wait() until game.Players.LocalPlayer.Character

-- [[ 2. ตั้งค่า WEBHOOK ตรงนี้ ]] --
local WEBHOOK_URL = "https://discord.com/api/webhooks/1479380422713409577/fTqx3VvsvwIQTked1qTNEoLQ_HVbaETnRjyEaVlrR0891T-NaMZJCel9zC3XBejPxJ9-" 
local FILE_NAME = "Gacha_ID_" .. game.Players.LocalPlayer.UserId .. ".txt"

local rollCount = 0 
local last_msg_id = nil

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local player = Players.LocalPlayer

-- [[ 3. ระบบจัดการไฟล์ ID ข้ามเซิร์ฟเวอร์ ]]
local function saveMsgId(id)
    if writefile then pcall(function() writefile(FILE_NAME, id) end) end
end

local function loadMsgId()
    if isfile and isfile(FILE_NAME) then
        local success, content = pcall(function() return readfile(FILE_NAME) end)
        return success and content or nil
    end
    return nil
end

last_msg_id = loadMsgId()

-- [[ 4. ฟังก์ชันดึงข้อมูล (Anti-Nil) ]]
local function getAmount(itemName)
    local amount = "0x"
    pcall(function()
        local holder = player.PlayerGui.Inventory.CanvasGroup.backpack_frame.enlarging_frame.holder
        local item = holder:FindFirstChild(itemName)
        if item then amount = item.Holder.Holder.Number.Text end
    end)
    return amount
end

local function getStand()
    local val = "None"
    pcall(function()
        val = workspace.Live[player.Name]:GetAttribute("SummonedStand") or "None"
    end)
    return val
end

local function isWhitesnake()
    return getStand() == "Whitesnake"
end

-- [[ 5. ระบบ Webhook Update (Compact & Live) ]]
local function updateWebhook(standName, status)
    if not WEBHOOK_URL:find("http") then return end

    local headshotUrl = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. player.UserId .. "&width=150&height=150&format=png"
    
    local data = {
        ["embeds"] = {{
            ["author"] = {
                ["name"] = "Account: ||" .. player.Name .. "||",
                ["icon_url"] = headshotUrl
            },
            ["title"] = "✨ Whitesnake Gacha Monitor",
            ["color"] = (status == "SUCCESS") and 0x00ff00 or 0xff8c00,
            ["fields"] = {
                {["name"] = "🧬 Stand", ["value"] = "**" .. standName .. "**", ["inline"] = true},
                {["name"] = "📊 Total Rolls", ["value"] = "**" .. rollCount .. "**", ["inline"] = true},
                {["name"] = "🏹 Inventory", ["value"] = "Arrows: **" .. getAmount("Stand Arrow") .. "** | Lucky: **" .. getAmount("Lucky Arrow") .. "**", ["inline"] = false},
                {["name"] = "🚩 Status", ["value"] = (status == "SUCCESS") and "✅ **FOUND!**" or "🔄 **Rolling...**", ["inline"] = true}
            },
            ["footer"] = {["text"] = "Server: " .. game.JobId:sub(1,8) .. " | Update: " .. os.date("%X")},
        }}
    }

    pcall(function()
        local requestFunc = (syn and syn.request) or (http_request) or (request)
        local jsonData = HttpService:JSONEncode(data)
        if not last_msg_id then
            local resp = requestFunc({Url = WEBHOOK_URL .. "?wait=true", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = jsonData})
            if resp.Success then last_msg_id = HttpService:JSONDecode(resp.Body).id saveMsgId(last_msg_id) end
        else
            requestFunc({Url = WEBHOOK_URL .. "/messages/" .. last_msg_id, Method = "PATCH", Headers = {["Content-Type"] = "application/json"}, Body = jsonData})
        end
    end)
end

-- [[ 6. ฟังก์ชันการสุ่มและย้ายเซิร์ฟ ]]
local function serverHop()
    local placeId, jobId = game.PlaceId, game.JobId
    local servers = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..placeId.."/servers/Public?sortOrder=Asc&limit=100")).data
    for _, s in pairs(servers) do
        if s.id ~= jobId and s.playing < s.maxPlayers then
            TeleportService:TeleportToPlaceInstance(placeId, s.id, player)
            break
        end
    end
end

local function performRoll()
    local useItem = ReplicatedStorage:WaitForChild("requests"):WaitForChild("character"):WaitForChild("use_item")
    local arrowAmt = tonumber(getAmount("Stand Arrow"):match("%d+")) or 0

    if arrowAmt > 0 then
        rollCount = rollCount + 1
        useItem:FireServer("Stand Arrow")
        task.wait(7)
        local controller = player.Character:FindFirstChild("client_character_controller")
        if controller then controller.SummonStand:FireServer() end
        task.wait(2)
    else
        serverHop() -- ถ้าลูกธนูหมดให้ย้ายเซิร์ฟทันที
    end
end

-- [[ 7. Main Loop ทุก 3 วินาที ]]
print("--- [ Whitesnake Bot Final Started ] ---")

while true do
    local currentStand = getStand()
    local success = isWhitesnake()

    updateWebhook(currentStand, success and "SUCCESS" or "ROLLING")

    if success then 
        print("🎉 FOUND WHITESNAKE!")
        break 
    end

    performRoll()
    task.wait(3)
end
