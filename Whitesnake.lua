repeat task.wait() until game:IsLoaded()

-- [ ส่วนการตั้งค่า ] --
local WEBHOOK_URL = "https://discord.com/api/webhooks/1479380422713409577/fTqx3VvsvwIQTked1qTNEoLQ_HVbaETnRjyEaVlrR0891T-NaMZJCel9zC3XBejPxJ9-" -- <--- วาง URL ที่ก๊อปมาตรงนี้

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local placeId = game.PlaceId
local jobId = game.JobId

-- [ ฟังก์ชันส่ง Webhook ] --
local function sendWebhook(standName, status)
    local data = {
        ["content"] = "",
        ["embeds"] = {{
            ["title"] = "✨ Stand Gacha Log",
            ["description"] = "บอทสุ่มสแตนด์ให้คุณแล้ว!",
            ["color"] = (status == "SUCCESS") and 0x00ff00 or 0xff8c00, -- สีเขียวถ้าเจอ WS, สีส้มถ้าตัวอื่น
            ["fields"] = {
                {["name"] = "Player", ["value"] = player.Name, ["inline"] = true},
                {["name"] = "Result", ["value"] = "**" .. standName .. "**", ["inline"] = true},
                {["name"] = "Status", ["value"] = (status == "SUCCESS") and "✅ FOUND WHITESNAKE!" or "🔄 Rolling...", ["inline"] = false}
            },
            ["footer"] = {["text"] = "Time: " .. os.date("%X")},
            ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }
    
    local jsonData = HttpService:JSONEncode(data)
    
    -- ส่งข้อมูลไปยัง Discord
    pcall(function()
        (syn and syn.request or http_request or request)({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = jsonData
        })
    end)
end

-- [ Path & Logic อื่นๆ เหมือนเดิม ] --
local holder = player.PlayerGui:WaitForChild("Inventory"):WaitForChild("CanvasGroup"):WaitForChild("backpack_frame"):WaitForChild("enlarging_frame"):WaitForChild("holder")
local live = workspace:WaitForChild("Live")
local useItem = ReplicatedStorage:WaitForChild("requests"):WaitForChild("character"):WaitForChild("use_item")

local function getStand()
    local char = live:FindFirstChild(player.Name)
    return char and char:GetAttribute("SummonedStand") or "None"
end

local function isWhitesnake()
    local current = getStand()
    if current == "Whitesnake" then return true end
    local char = live:FindFirstChild(player.Name)
    if char then
        for _, v in pairs(char:GetChildren()) do
            if v:IsA("Model") and v.Name == "Whitesnake" then return true end
        end
    end
    return false
end

-- [ Main Loop ] --
if isWhitesnake() then 
    sendWebhook("Whitesnake", "SUCCESS")
    return 
end

while task.wait(1) do
    local arrowInMap = nil -- (ใส่ Logic findArrow เหมือนเดิมของคุณ)
    
    -- สมมติว่านี่คือจุดที่สุ่มได้แล้ว:
    -- หลังใช้ Arrow และ Summon Stand เสร็จ
    task.wait(10) -- รอให้สแตนด์เกิด
    local result = getStand()
    
    if result == "Whitesnake" or isWhitesnake() then
        sendWebhook("Whitesnake", "SUCCESS")
        warn("FOUND WHITESNAKE!")
        break
    else
        sendWebhook(result, "ROLLING")
        print("Logged to Discord: " .. result)
    end
    
    -- (Logic ย้ายเซิร์ฟเวอร์/หาของต่อ...)
end
