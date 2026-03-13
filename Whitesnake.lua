repeat task.wait() until game:IsLoaded()

-- [[ ตั้งค่า WEBHOOK ตรงนี้ ]] --
local WEBHOOK_URL = "https://discord.com/api/webhooks/1479380422713409577/fTqx3VvsvwIQTked1qTNEoLQ_HVbaETnRjyEaVlrR0891T-NaMZJCel9zC3XBejPxJ9" 
local FILE_NAME = "Gacha_ID_" .. game.Players.LocalPlayer.UserId .. ".txt" -- แยกไฟล์ตามไอดีเพื่อไม่ให้ตีกัน

local rollCount = 0 
local last_msg_id = nil

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

-- [[ ระบบจัดการไฟล์ ID ]] --
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

-- [[ Path Settings ]] --
local holder = player.PlayerGui:WaitForChild("Inventory"):WaitForChild("CanvasGroup"):WaitForChild("backpack_frame"):WaitForChild("enlarging_frame"):WaitForChild("holder")
local live = workspace:WaitForChild("Live")
local useItem = ReplicatedStorage:WaitForChild("requests"):WaitForChild("character"):WaitForChild("use_item")

-- [[ ฟังก์ชันเสริม ]] --
local function getStand()
    local char = live:FindFirstChild(player.Name)
    local val = char and char:GetAttribute("SummonedStand")
    return (val and val ~= "") and val or "None"
end

local function isWhitesnake()
    if getStand() == "Whitesnake" then return true end
    local char = live:FindFirstChild(player.Name)
    return char and char:FindFirstChild("Whitesnake") ~= nil
end

local function getItemAmount(itemName)
    local slot = holder:FindFirstChild(itemName)
    if slot then
        local success, result = pcall(function() return slot.Holder.Holder.Number.Text:match("%d+") or "0" end)
        return success and result or "0"
    end
    return "0"
end

-- [[ Webhook Update - Compact Version ]] --
local function sendWebhookUpdate(standName, status)
    if not WEBHOOK_URL or WEBHOOK_URL == "" or not WEBHOOK_URL:find("http") then return end

    local headshotUrl = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. player.UserId .. "&width=150&height=150&format=png"
    
    local data = {
        ["embeds"] = {{
            ["author"] = {
                ["name"] = "Account: ||" .. player.Name .. "||",
                ["icon_url"] = headshotUrl
            },
            ["color"] = (status == "SUCCESS") and 0x00ff00 or 0x2b2d31, -- สีเขียวถ้าได้ WS, สีเทาเข้มถ้ากำลังสุ่ม (ดูสะอาดตา)
            ["fields"] = {
                {["name"] = "🧬 Stand", ["value"] = "**" .. standName .. "**", ["inline"] = true},
                {["name"] = "📊 Rolls", ["value"] = "**" .. rollCount .. "**", ["inline"] = true},
                {["name"] = "🏹 Arrows", ["value"] = "**" .. getItemAmount("Stand Arrow") .. "**", ["inline"] = true},
                {["name"] = "🚩 Status", ["value"] = (status == "SUCCESS") and "✅ **FOUND!**" or "🔄 Rolling...", ["inline"] = false}
            },
            ["footer"] = {["text"] = "Server: " .. game.JobId:sub(1,8) .. " | " .. os.date("%X")},
        }}
    }

    local jsonData = HttpService:JSONEncode(data)
    local requestFunc = (syn and syn.request) or (http_request) or (request)

    pcall(function()
        if not last_msg_id then
            local response = requestFunc({Url = WEBHOOK_URL .. "?wait=true", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = jsonData})
            if response.Success then
                last_msg_id = HttpService:JSONDecode(response.Body).id
                saveMsgId(last_msg_id)
            end
        else
            local response = requestFunc({Url = WEBHOOK_URL .. "/messages/" .. last_msg_id, Method = "PATCH", Headers = {["Content-Type"] = "application/json"}, Body = jsonData})
            if not response.Success and response.StatusCode == 404 then
                last_msg_id = nil
                sendWebhookUpdate(standName, status)
            end
        end
    end)
end

--------------------------------------------------
-- [ Main Execution ] --
--------------------------------------------------

task.wait(5)
sendWebhookUpdate(getStand(), "ROLLING")

while task.wait(1) do
    if isWhitesnake() then
        sendWebhookUpdate(getStand(), "SUCCESS")
        break
    end

    local arrowInMap = findArrow() -- ฟังก์ชันเดิมที่คุณมี
    if arrowInMap then
        collectArrow() -- ฟังก์ชันเดิมที่คุณมี
        task.wait(2)
        sendWebhookUpdate(getStand(), "ROLLING")
    else
        local arrowAmt = tonumber(getItemAmount("Stand Arrow")) or 0
        if arrowAmt > 0 then
            rollCount = rollCount + 1
            useItem:FireServer("Stand Arrow")
            task.wait(8)
            
            local char = player.Character or player.CharacterAdded:Wait()
            local controller = char:FindFirstChild("client_character_controller")
            if controller and controller:FindFirstChild("SummonStand") then
                controller.SummonStand:FireServer()
            end
            
            task.wait(2)
            sendWebhookUpdate(getStand(), isWhitesnake() and "SUCCESS" or "ROLLING")
            if isWhitesnake() then break end
        else
            task.wait(2)
            if not findArrow() then
                serverHop() -- ฟังก์ชันเดิมที่คุณมี
                break
            end
        end
    end
end
