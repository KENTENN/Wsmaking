-- [[ 1. ระบบรอโหลดเกมและตั้งค่าพื้นฐาน ]]
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

-- [[ 2. ระบบจัดการไฟล์ ID ข้ามเซิร์ฟเวอร์ ]]
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

-- [[ 3. ฟังก์ชันดึงข้อมูลแบบปลอดภัย (Anti-Nil) ]]
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

-- [[ 4. ระบบ Webhook Update (Live Stats) ]]
local function updateWebhook(standName, status)
    if not WEBHOOK_URL:find("http") then return end

    local data = {
        ["embeds"] = {{
            ["author"] = {
                ["name"] = "Account: ||" .. player.Name .. "||",
                ["icon_url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. player.UserId .. "&width=150&height=150&format=png"
            },
            ["title"] = "✨ Whitesnake Monitor - Live",
            ["color"] = (status == "SUCCESS") and 0x00ff00 or 0xff8c00,
            ["fields"] = {
                {["name"] = "🧬 Stand", ["value"] = "**" .. standName .. "**", ["inline"] = true},
                {["name"] = "📊 Total Rolls", ["value"] = "**" .. rollCount .. "**", ["inline"] = true},
                {["name"] = "🏹 Inventory", ["value"] = "Arrows: **" .. getAmount("Stand Arrow") .. "** | Lucky: **" .. getAmount("Lucky Arrow") .. "**", ["inline"] = false},
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

-- [[ 5. ฟังก์ชัน Server Hop ตัวใหม่ที่คุณส่งมา (อัปเกรดแล้ว) ]]
local function hopServer()
    local servers = {}
    local cursor = ""
    local success, result
    local gameId = game.PlaceId

    repeat
        success, result = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&cursor=%s", gameId, cursor)))
        end)

        if success and result and result.data then
            for _, server in ipairs(result.data) do
                if server.playing < server.maxPlayers and server.id ~= game.JobId then
                    table.insert(servers, server.id)
                end
            end
            cursor = result.nextPageCursor or ""
        else
            break
        end
    until cursor == "" or #servers >= 10 -- ค้นหาจนกว่าจะเจอเซิร์ฟเวอร์จำนวนหนึ่งเพื่อสุ่ม

    if #servers > 0 then
        local targetServer = servers[math.random(1, #servers)]
        TeleportService:TeleportToPlaceInstance(gameId, targetServer, player)
    else
        warn("No available servers found.")
    end
end

-- [[ 6. ฟังก์ชันการสุ่มอัตโนมัติ ]]
local function performRoll()
    local useItem = ReplicatedStorage:WaitForChild("requests"):WaitForChild("character"):WaitForChild("use_item")
    local arrowStr = getAmount("Stand Arrow")
    local arrowAmt = tonumber(arrowStr:match("%d+")) or 0

    if arrowAmt > 0 then
        rollCount = rollCount + 1
        useItem:FireServer("Stand Arrow")
        task.wait(7)
        local char = player.Character
        if char and char:FindFirstChild("client_character_controller") then
            char.client_character_controller.SummonStand:FireServer()
        end
        task.wait(2)
    else
        print("Out of arrows, hopping...")
        hopServer() -- ใช้ฟังก์ชันใหม่เมื่อของหมด
    end
end

-- [[ 7. Main Execution Loop ทุก 3 วินาที ]]
while true do
    local currentStand = getStand()
    local success = (currentStand == "Whitesnake")

    updateWebhook(currentStand, success and "SUCCESS" or "ROLLING")

    if success then break end
    
    performRoll()
    task.wait(3)
end
