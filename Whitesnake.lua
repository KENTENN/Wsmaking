-- [[ 1. ตั้งค่าเป้าหมาย ]]
local rawTarget = getgenv().TargetStand or "Whitesnake"
local targets = {}
if type(rawTarget) == "table" then targets = rawTarget else targets = {rawTarget} end

print("🎯 ล็อคเป้าหมาย: " .. table.concat(targets, ", "))

local function isTargetMet(currentStand)
    for _, name in pairs(targets) do if currentStand == name then return true end end
    return false
end

-- [[ 2. Setup ]]
repeat task.wait() until game:IsLoaded()
repeat task.wait() until game.Players.LocalPlayer.Character

local WEBHOOK_URL = "https://discord.com/api/webhooks/1479380422713409577/fTqx3VvsvwIQTked1qTNEoLQ_HVbaETnRjyEaVlrR0891T-NaMZJCel9zC3XBejPxJ9-" 
local player = game.Players.LocalPlayer
local ROLL_FILE = "TotalRolls_" .. player.UserId .. ".txt"

local rollCount = 0 
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

-- [[ 3. สถิติสะสมจากไฟล์ ]]
if isfile and isfile(ROLL_FILE) then
    rollCount = tonumber(readfile(ROLL_FILE)) or 0
end
print("📊 สถิติเดิม: สุ่มไปแล้ว " .. rollCount .. " รอบ")

-- [[ 4. Webhook แบบเดิม (ส่งใหม่ทุกครั้งตามที่คุณต้องการ) ]]
local function sendWebhook(standName, status)
    if not WEBHOOK_URL:find("https://") then return end
    local data = {
        ["content"] = nil,
        ["embeds"] = {{
            ["title"] = "✨ Gacha Monitor Status",
            ["description"] = "Account: **" .. player.Name .. "**\nStand: **" .. standName .. "**\nTotal Rolls: **" .. rollCount .. "**\nStatus: **" .. status .. "**",
            ["color"] = (status == "SUCCESS") and 65280 or 16744448,
            ["footer"] = { ["text"] = "Server: " .. game.JobId:sub(1,8) .. " | " .. os.date("%X") }
        }}
    }
    pcall(function()
        local requestFunc = (syn and syn.request) or (http_request) or (request)
        requestFunc({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end)
end

-- [[ 5. ระบบเก็บลูกธนู (รื้อทุก Model ใน Workspace) ]]
local function teleportToItems()
    local itemFound = false
    for _, item in pairs(workspace:GetDescendants()) do
        if item.Name == "Stand Arrow" or item.Name == "Lucky Arrow" then
            local prompt = item:FindFirstChildOfClass("ProximityPrompt") or (item.Parent and item.Parent:FindFirstChildOfClass("ProximityPrompt"))
            if prompt then
                local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    print("✨ เจอของ! กำลังไปเก็บ...")
                    root.CFrame = item:IsA("BasePart") and item.CFrame or item.Parent.CFrame
                    task.wait(0.3)
                    fireproximityprompt(prompt)
                    itemFound = true
                    task.wait(0.5)
                end
            end
        end
    end
    return itemFound
end

-- [[ 6. Server Hop ]]
local function hopServer()
    print("🔄 กำลังหาเซิร์ฟเวอร์ใหม่...")
    if writefile then writefile(ROLL_FILE, tostring(rollCount)) end
    while task.wait(5) do
        local success, result = pcall(function() 
            return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")) 
        end)
        if success and result.data then
            for _, server in ipairs(result.data) do
                if server.id ~= game.JobId and server.playing < server.maxPlayers then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, player)
                end
            end
        end
    end
end

-- [[ 7. Main Loop ]]
print("🎬 เริ่มการทำงาน...")
while task.wait(3) do
    local currentStand = "None"
    pcall(function() currentStand = workspace.Live[player.Name]:GetAttribute("SummonedStand") or "None" end)
    print("🧬 Stand ปัจจุบัน: " .. currentStand)

    if isTargetMet(currentStand) then 
        sendWebhook(currentStand, "SUCCESS")
        print("🎉 ภารกิจสำเร็จ!")
        break 
    end

    -- ขั้นตอนที่ 1: เก็บลูกธนู
    teleportToItems()
    
    -- ขั้นตอนที่ 2: เช็คของในกระเป๋า
    local arrow = player.PlayerGui.Inventory.CanvasGroup.backpack_frame.enlarging_frame.holder:FindFirstChild("Stand Arrow")
    local amount = 0
    if arrow then amount = tonumber(arrow.Holder.Holder.Number.Text:match("%d+")) or 0 end
    
    if amount > 0 then
        -- ขั้นตอนที่ 3: สุ่ม
        rollCount = rollCount + 1
        if writefile then writefile(ROLL_FILE, tostring(rollCount)) end
        
        sendWebhook(currentStand, "ROLLING (" .. rollCount .. ")")
        print("🎲 สุ่มรอบที่: " .. rollCount)
        
        ReplicatedStorage.requests.character.use_item:FireServer("Stand Arrow")
        task.wait(8) -- รอแอนิเมชัน
        pcall(function() player.Character.client_character_controller.SummonStand:FireServer() end)
        task.wait(2)
    else
        -- ขั้นตอนที่ 4: ย้ายเซิร์ฟเวอร์
        hopServer()
        break
    end
end
