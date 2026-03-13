-- [[ 1. รอโหลดพื้นฐาน ]]
repeat task.wait() until game:IsLoaded()
repeat task.wait() until game.Players.LocalPlayer.Character

local WEBHOOK_URL = "https://discord.com/api/webhooks/1479380422713409577/fTqx3VvsvwIQTked1qTNEoLQ_HVbaETnRjyEaVlrR0891T-NaMZJCel9zC3XBejPxJ9-" 
local FILE_NAME = "Gacha_ID_" .. game.Players.LocalPlayer.UserId .. ".txt"

local rollCount = 0 
local last_msg_id = nil
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local player = Players.LocalPlayer

-- [[ 2. ระบบจำ ID Webhook ข้ามเซิร์ฟ ]]
local function saveMsgId(id) if writefile then pcall(function() writefile(FILE_NAME, id) end) end end
local function loadMsgId() if isfile and isfile(FILE_NAME) then local success, content = pcall(function() return readfile(FILE_NAME) end) return success and content or nil end return nil end
last_msg_id = loadMsgId()

-- [[ 3. ฟังก์ชันดึงค่าไอเทม (ปรับปรุงให้รอโหลด) ]]
local function getAmount(itemName)
    local amount = nil
    -- ให้เวลา UI โหลดตัวเลข 5 วินาที
    for i = 1, 10 do
        pcall(function()
            local holder = player.PlayerGui.Inventory.CanvasGroup.backpack_frame.enlarging_frame.holder
            local item = holder:FindFirstChild(itemName)
            if item and item.Holder.Holder.Number.Text ~= "" then
                amount = item.Holder.Holder.Number.Text
            end
        end)
        if amount then break end
        task.wait(0.5)
    end
    return amount or "0x"
end

-- [[ 4. ระบบ Webhook Update ]]
local function updateWebhook(standName, status)
    if not WEBHOOK_URL:find("http") then return end
    local data = {
        ["embeds"] = {{
            ["author"] = {["name"] = "Account: ||" .. player.Name .. "||", ["icon_url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. player.UserId .. "&width=150&height=150&format=png"},
            ["title"] = "✨ Whitesnake Monitor - Live",
            ["color"] = (status == "SUCCESS") and 0x00ff00 or 0xff8c00,
            ["fields"] = {
                {["name"] = "🧬 Stand", ["value"] = "**" .. standName .. "**", ["inline"] = true},
                {["name"] = "📊 Total Rolls", ["value"] = "**" .. rollCount .. "**", ["inline"] = true},
                {["name"] = "🏹 Inventory", ["value"] = "Arrows: **" .. getAmount("Stand Arrow") .. "**", ["inline"] = false},
                {["name"] = "🚩 Status", ["value"] = (status == "SUCCESS") and "✅ FOUND!" or "🔄 Rolling...", ["inline"] = true}
            },
            ["footer"] = {["text"] = "Server: " .. game.JobId:sub(1,8) .. " | " .. os.date("%X")},
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

-- [[ 5. ระบบ Server Hop (ฟังก์ชันที่คุณส่งมา) ]]
local function hopServer()
    local servers = {}
    local cursor = ""
    local gameId = game.PlaceId
    repeat
        local success, result = pcall(function() return HttpService:JSONDecode(game:HttpGet(string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&cursor=%s", gameId, cursor))) end)
        if success and result and result.data then
            for _, server in ipairs(result.data) do
                if server.playing < server.maxPlayers and server.id ~= game.JobId then table.insert(servers, server.id) end
            end
            cursor = result.nextPageCursor or ""
        else break end
    until cursor == "" or #servers >= 20
    if #servers > 0 then TeleportService:TeleportToPlaceInstance(gameId, servers[math.random(1, #servers)], player) end
end

-- [[ 6. ฟังก์ชันการสุ่ม ]]
local function performRoll()
    local arrowStr = getAmount("Stand Arrow")
    local arrowAmt = tonumber(arrowStr:match("%d+")) or 0

    if arrowAmt > 0 then
        rollCount = rollCount + 1
        ReplicatedStorage.requests.character.use_item:FireServer("Stand Arrow")
        task.wait(7)
        pcall(function() player.Character.client_character_controller.SummonStand:FireServer() end)
        task.wait(2)
        return true
    end
    return false
end

-- [[ 7. Main Loop ]]
while task.wait(3) do
    local currentStand = "None"
    pcall(function() currentStand = workspace.Live[player.Name]:GetAttribute("SummonedStand") or "None" end)
    
    updateWebhook(currentStand, (currentStand == "Whitesnake") and "SUCCESS" or "ROLLING")
    if currentStand == "Whitesnake" then break end

    -- พยายามสุ่ม
    local successRoll = performRoll()
    
    -- ถ้าสุ่มไม่ได้ (ของหมดจริงหลังเช็คซ้ำแล้ว) ค่อย Hop
    if not successRoll then
        print("Out of items after retries, hopping...")
        hopServer()
        break
    end
end
