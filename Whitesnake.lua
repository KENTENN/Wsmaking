-- [[ 1. ตั้งค่าเป้าหมาย (รองรับ Single/Table) ]]
local rawTarget = getgenv().TargetStand or "Whitesnake"
local targets = {}
if type(rawTarget) == "table" then targets = rawTarget else targets = {rawTarget} end

print("--------------------------------------")
print("🎯 TARGET LOCK: " .. table.concat(targets, ", "))
print("--------------------------------------")

local function isTargetMet(currentStand)
    for _, name in pairs(targets) do if currentStand == name then return true end end
    return false
end

-- [[ 2. Setup & Webhook Config ]]
repeat task.wait() until game:IsLoaded()
repeat task.wait() until game.Players.LocalPlayer.Character

local WEBHOOK_URL = "ใส่_URL_ตรงนี้" -- อย่าลืมใส่ URL ของคุณตรงนี้ครับ
local player = game.Players.LocalPlayer
local FILE_NAME = "WebhookID_" .. player.UserId .. ".txt"
local ROLL_FILE = "TotalRolls_" .. player.UserId .. ".txt"

local last_msg_id = nil
local rollCount = 0 

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

-- [[ 3. Data Persistence (โหลดค่าเดิม) ]]
local function saveData(file, data) if writefile then pcall(function() writefile(file, tostring(data)) end) end end
local function loadData(file) if isfile and isfile(file) then local success, content = pcall(function() return readfile(file) end) return success and content or nil end return nil end

last_msg_id = loadData(FILE_NAME)
rollCount = tonumber(loadData(ROLL_FILE)) or 0
print("📊 สถิติสะสม: สุ่มไปแล้ว " .. rollCount .. " รอบ")

-- [[ 4. ฟังก์ชันส่ง Webhook ]]
local function updateWebhook(standName, status)
    if not WEBHOOK_URL:find("https://discord.com/api/webhooks/1479380422713409577/fTqx3VvsvwIQTked1qTNEoLQ_HVbaETnRjyEaVlrR0891T-NaMZJCel9zC3XBejPxJ9-") then return end
    local targetText = table.concat(targets, ", ")
    local data = {
        ["embeds"] = {{
            ["author"] = {["name"] = "Account: " .. player.Name, ["icon_url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. player.UserId .. "&width=150&height=150&format=png"},
            ["title"] = "✨ Gacha Monitor Status",
            ["color"] = (status == "SUCCESS") and 0x00ff00 or 0xff8c00,
            ["fields"] = {
                {["name"] = "🧬 Current Stand", ["value"] = "**" .. standName .. "**", ["inline"] = true},
                {["name"] = "🎯 Targets", ["value"] = "**" .. targetText .. "**", ["inline"] = true},
                {["name"] = "📊 Total Rolls", ["value"] = "**" .. rollCount .. "**", ["inline"] = true},
                {["name"] = "🚩 Status", ["value"] = (status == "SUCCESS") and "✅ FOUND!" or "🔄 Rolling...", ["inline"] = true}
            },
            ["footer"] = {["text"] = "Server ID: " .. game.JobId:sub(1,8) .. " | " .. os.date("%X")},
        }}
    }
    pcall(function()
        local requestFunc = (syn and syn.request) or (http_request) or (request)
        local jsonData = HttpService:JSONEncode(data)
        if not last_msg_id then
            local resp = requestFunc({Url = WEBHOOK_URL .. "?wait=true", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = jsonData})
            if resp.Success then last_msg_id = HttpService:JSONDecode(resp.Body).id saveData(FILE_NAME, last_msg_id) end
        else
            requestFunc({Url = WEBHOOK_URL .. "/messages/" .. last_msg_id, Method = "PATCH", Headers = {["Content-Type"] = "application/json"}, Body = jsonData})
        end
    end)
end

-- [[ 5. ฟังก์ชันเก็บลูกธนู (ย้ำระบบรื้อ Model) ]]
local function teleportToItems()
    local itemFound = false
    print("📡 กำลังสแกนหาลูกธนูทั่วแมพ...")
    for _, item in pairs(workspace:GetDescendants()) do
        if item.Name == "Stand Arrow" or item.Name == "Lucky Arrow" then
            local prompt = item:FindFirstChildOfClass("ProximityPrompt") or (item.Parent and item.Parent:FindFirstChildOfClass("ProximityPrompt"))
            if prompt then
                local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    print("✨ เจอ " .. item.Name .. "! ใน " .. item.Parent.Name .. " กำลังวาร์ปไปเก็บ...")
                    root.CFrame = item:IsA("BasePart") and item.CFrame or item.Parent.CFrame
                    task.wait(0.3)
                    fireproximityprompt(prompt)
                    itemFound = true
                    task.wait(0.5)
                    print("✅ เก็บสำเร็จ!")
                end
            end
        end
    end
    return itemFound
end

-- [[ 6. Server Hop ]]
local function hopServer()
    print("🔄 ของหมด! กำลังย้ายเซิร์ฟเวอร์...")
    saveData(ROLL_FILE, rollCount)
    while task.wait(5) do
        local success, result = pcall(function() return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")) end)
        if success and result.data then
            for _, server in ipairs(result.data) do
                if server.id ~= game.JobId and server.playing < server.maxPlayers then
                    print("🚀 เจอเซิร์ฟเวอร์แล้ว! กำลังวาร์ป...")
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, player)
                end
            end
        end
    end
end

-- [[ 7. Main Loop ]]
print("🎬 เริ่มการทำงานหลัก...")
while task.wait(3) do
    local currentStand = "None"
    pcall(function() currentStand = workspace.Live[player.Name]:GetAttribute("SummonedStand") or "None" end)
    print("🧬 Stand ปัจจุบัน: " .. currentStand)

    local success = isTargetMet(currentStand)
    updateWebhook(currentStand, success and "SUCCESS" or "ROLLING")
    
    if success then 
        print("🎉 ภารกิจสำเร็จ!")
        saveData(ROLL_FILE, rollCount)
        break 
    end

    teleportToItems() -- เก็บของก่อนเสมอ
    
    local arrow = player.PlayerGui.Inventory.CanvasGroup.backpack_frame.enlarging_frame.holder:FindFirstChild("Stand Arrow")
    local amount = 0
    if arrow then amount = tonumber(arrow.Holder.Holder.Number.Text:match("%d+")) or 0 end
    print("🏹 ลูกธนูในกระเป๋า: " .. amount)

    if amount > 0 then
        rollCount = rollCount + 1
        saveData(ROLL_FILE, rollCount)
        print("🎲 สุ่มรอบที่: " .. rollCount)
        ReplicatedStorage.requests.character.use_item:FireServer("Stand Arrow")
        print("⏳ รอแอนิเมชัน 8 วินาที...")
        task.wait(8)
        pcall(function() player.Character.client_character_controller.SummonStand:FireServer() end)
        task.wait(2)
    else
        hopServer()
        break
    end
end
