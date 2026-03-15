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

local WEBHOOK_URL = "ใส่_URL_ตรงนี้" 
local player = game.Players.LocalPlayer
local ROLL_FILE = "TotalRolls_" .. player.UserId .. ".txt"

local rollCount = 0 
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

-- [[ 3. สถิติสะสม ]]
if isfile and isfile(ROLL_FILE) then
    rollCount = tonumber(readfile(ROLL_FILE)) or 0
end
print("📊 สถิติเดิม: " .. rollCount .. " รอบ")

-- [[ 4. ระบบ Webhook แบบเดิม (ส่งใหม่ทุกครั้ง) ]]
local function sendWebhook(standName, status)
    if not WEBHOOK_URL:find("https://discord.com/api/webhooks/1479380422713409577/fTqx3VvsvwIQTked1qTNEoLQ_HVbaETnRjyEaVlrR0891T-NaMZJCel9zC3XBejPxJ9-") then return end
    local data = {
        ["content"] = nil,
        ["embeds"] = {{
            ["title"] = "✨ Gacha Monitor Status",
            ["description"] = "บัญชี: **" .. player.Name .. "**\nสแตนด์ที่สุ่มได้: **" .. standName .. "**\nจำนวนรอบทั้งหมด: **" .. rollCount .. "**\nสถานะ: **" .. status .. "**",
            ["color"] = (status == "SUCCESS") and 65280 or 16744448,
            ["footer"] = { ["text"] = os.date("%X") }
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

-- [[ 5. ระบบเก็บลูกธนู (รื้อทุก Model แบบเดิมที่ทำงานได้ดีที่สุด) ]]
local function teleportToItems()
    local itemFound = false
    for _, item in pairs(workspace:GetDescendants()) do
        if item.Name == "Stand Arrow" or item.Name == "Lucky Arrow" then
            local prompt = item:FindFirstChildOfClass("ProximityPrompt") or (item.Parent and item.Parent:FindFirstChildOfClass("ProximityPrompt"))
            if prompt then
                local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    print("✨ เจอของ! กำลังวาร์ปไปเก็บ...")
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
    print("🔄 กำลังย้ายเซิร์ฟเวอร์...")
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
    print("🧬 Stand: " .. currentStand)

    if isTargetMet(currentStand) then 
        sendWebhook(currentStand, "SUCCESS")
        print("🎉 สำเร็จ!")
        break 
    end

    teleportToItems()
    
    local arrow = player.PlayerGui.Inventory.CanvasGroup.backpack_frame.enlarging_frame.holder:FindFirstChild("Stand Arrow")
    local amount = 0
    if arrow then amount = tonumber(arrow.Holder.Holder.Number.Text:match("%d+")) or 0 end
    
    if amount > 0 then
        rollCount = rollCount + 1
        if writefile then writefile(ROLL_FILE, tostring(rollCount)) end
        
        sendWebhook(currentStand, "ROLLING (" .. rollCount .. ")") -- ส่งฮุคทุกรอบที่สุ่ม
        print("🎲 รอบที่: " .. rollCount)
        
        ReplicatedStorage.requests.character.use_item:FireServer("Stand Arrow")
        task.wait(8)
        pcall(function() player.Character.client_character_controller.SummonStand:FireServer() end)
        task.wait(2)
    else
        hopServer()
        break
    end
end
