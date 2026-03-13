-- [[ 1. ตั้งค่าพื้นฐานและรอโหลด ]]
repeat task.wait() until game:IsLoaded()
repeat task.wait() until game.Players.LocalPlayer.Character

local WEBHOOK_URL = "https://discord.com/api/webhooks/1479380422713409577/fTqx3VvsvwIQTked1qTNEoLQ_HVbaETnRjyEaVlrR0891T-NaMZJCel9zC3XBejPxJ9-" -- ตรวจสอบว่าต้องมี https:// นำหน้าเสมอ
local FILE_NAME = "Gacha_ID_" .. game.Players.LocalPlayer.UserId .. ".txt"

local rollCount = 0 
local last_msg_id = nil
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local player = Players.LocalPlayer

-- [[ 2. ระบบจำ ID Webhook เพื่อกัน "น้ำตก" ]]
local function saveMsgId(id) if writefile then pcall(function() writefile(FILE_NAME, id) end) end end
local function loadMsgId() if isfile and isfile(FILE_NAME) then local success, content = pcall(function() return readfile(FILE_NAME) end) return success and content or nil end return nil end
last_msg_id = loadMsgId()

-- [[ 3. ฟังก์ชันดึงค่าไอเทม (แก้ไขให้แม่นยำขึ้น) ]]
local function getAmount(itemName)
    local amount = nil
    pcall(function()
        local holder = player.PlayerGui.Inventory.CanvasGroup.backpack_frame.enlarging_frame.holder
        local item = holder:FindFirstChild(itemName)
        if item then
            local text = item.Holder.Holder.Number.Text
            amount = text:match("%d+") -- ดึงเฉพาะตัวเลข
        end
    end)
    return tonumber(amount) or 0
end

-- [[ 4. ระบบ Webhook (เพิ่มระบบเช็ค Protocol) ]]
local function updateWebhook(standName, status)
    if not WEBHOOK_URL or not WEBHOOK_URL:find("https://") then return end -- ป้องกัน Error Invalid Protocol
    
    local data = {
        ["embeds"] = {{
            ["author"] = {["name"] = "Account: ||" .. player.Name .. "||", ["icon_url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. player.UserId .. "&width=150&height=150&format=png"},
            ["title"] = "✨ Whitesnake Monitor - Live",
            ["color"] = (status == "SUCCESS") and 0x00ff00 or 0xff8c00,
            ["fields"] = {
                {["name"] = "🧬 Stand", ["value"] = "**" .. standName .. "**", ["inline"] = true},
                {["name"] = "📊 Total Rolls", ["value"] = "**" .. rollCount .. "**", ["inline"] = true},
                {["name"] = "🏹 Arrows", ["value"] = "**" .. getAmount("Stand Arrow") .. "**", ["inline"] = true},
                {["name"] = "🚩 Status", ["value"] = (status == "SUCCESS") and "✅ FOUND!" or "🔄 Rolling...", ["inline"] = false}
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

-- [[ 5. ระบบ Server Hop (แบบบังคับวาร์ป) ]]
local function hopServer()
    print("Searching for new server...")
    local gameId = game.PlaceId
    local servers = {}
    local cursor = ""
    
    repeat
        local success, result = pcall(function() 
            return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. gameId .. "/servers/Public?sortOrder=Asc&limit=100&cursor=" .. cursor)) 
        end)
        if success and result and result.data then
            for _, server in ipairs(result.data) do
                if server.playing < server.maxPlayers and server.id ~= game.JobId then
                    table.insert(servers, server.id)
                end
            end
            cursor = result.nextPageCursor or ""
        else break end
    until cursor == "" or #servers >= 30

    if #servers > 0 then
        print("Hopping to: " .. servers[1])
        TeleportService:TeleportToPlaceInstance(gameId, servers[math.random(1, #servers)], player)
    else
        warn("No servers found, retrying in 5s...")
        task.wait(5)
        hopServer()
    end
end

-- [[ 6. Main Logic ]]
while task.wait(3) do
    local currentStand = "None"
    pcall(function() currentStand = workspace.Live[player.Name]:GetAttribute("SummonedStand") or "None" end)
    
    updateWebhook(currentStand, (currentStand == "Whitesnake") and "SUCCESS" or "ROLLING")
    if currentStand == "Whitesnake" then break end

    local arrows = getAmount("Stand Arrow")
    if arrows > 0 then
        rollCount = rollCount + 1
        ReplicatedStorage.requests.character.use_item:FireServer("Stand Arrow")
        task.wait(7)
        pcall(function() player.Character.client_character_controller.SummonStand:FireServer() end)
        task.wait(2)
    else
        -- ถ้าไม่มีของ ให้รอเช็คซ้ำอีก 2 รอบเพื่อความชัวร์ก่อน Hop
        print("Inventory empty, checking again...")
        task.wait(5)
        if getAmount("Stand Arrow") == 0 then
            print("Confirmed empty. Hopping now!")
            hopServer()
            break
        end
    end
end
