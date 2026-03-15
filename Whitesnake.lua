-- [[ 1. CONFIGURATION - ตั้งค่าที่นี่ ]]
local WEBHOOK_URL = "https://discord.com/api/webhooks/1479380422713409577/fTqx3VvsvwIQTked1qTNEoLQ_HVbaETnRjyEaVlrR0891T-NaMZJCel9zC3XBejPxJ9-"

local USER_LIST = {
    ["TopKen_001"] = { "XE", "YEID" },
    ["asdzxc, fawfzxvczv"] = { "XE", "WSMK" },
    -- เพิ่มชื่อผู้เล่นและเป้าหมายได้ตามต้องการ
}

-- [[ 2. INITIALIZATION - ระบบเตรียมความพร้อม ]]
repeat task.wait() until game:IsLoaded()
repeat task.wait() until game.Players.LocalPlayer.Character

local player = game.Players.LocalPlayer
local ROLL_FILE = "TotalRolls_" .. player.UserId .. ".txt"
local rollCount = 0

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

-- [[ 3. DATA LOADING - โหลดสถิติเดิม ]]
if isfile and isfile(ROLL_FILE) then
    rollCount = tonumber(readfile(ROLL_FILE)) or 0
end
print("📊 สถิติเดิม: สุ่มไปแล้ว " .. rollCount .. " รอบ")

-- [[ 4. WEBHOOK SYSTEM - ระบบแจ้งเตือนแบบ Embed ]]
local function sendWebhook(standName, status)
    if not WEBHOOK_URL:find("https://") then return end
    
    local targets = USER_LIST[player.Name] or { "Whitesnake" }
    local data = {
        ["embeds"] = {{
            ["title"] = "✨ Gacha Monitor - Multi-Target Mode",
            ["description"] = "Account: ||" .. player.Name .. "||",
            ["color"] = (status == "SUCCESS") and 65280 or 16744448,
            ["fields"] = {
                {["name"] = "🧬 Current Stand", ["value"] = "**" .. standName .. "**", ["inline"] = true},
                {["name"] = "🎯 Targets", ["value"] = "**" .. table.concat(targets, ", ") .. "**", ["inline"] = true},
                {["name"] = "📊 Total Rerolls", ["value"] = "**" .. rollCount .. "**", ["inline"] = true},
                {["name"] = "🚩 Status", ["value"] = (status == "SUCCESS") and "✅ FOUND!" or "🔄 Searching...", ["inline"] = false}
            },
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

-- [[ 5. ITEM COLLECTION - ระบบรื้อแมพเก็บลูกธนู ]]
local function teleportToItems()
    for _, item in pairs(workspace:GetDescendants()) do
        if item.Name == "Stand Arrow" or item.Name == "Lucky Arrow" then
            local prompt = item:FindFirstChildOfClass("ProximityPrompt") or (item.Parent and item.Parent:FindFirstChildOfClass("ProximityPrompt"))
            if prompt and player.Character:FindFirstChild("HumanoidRootPart") then
                print("✨ เจอของ! กำลังวาร์ปไปเก็บ...")
                player.Character.HumanoidRootPart.CFrame = item:IsA("BasePart") and item.CFrame or item.Parent.CFrame
                task.wait(0.3)
                fireproximityprompt(prompt)
                task.wait(0.5)
            end
        end
    end
end

-- [[ 6. SERVER HOP - ระบบย้ายเซิร์ฟเวอร์ ]]
local function hopServer()
    print("❌ ของหมด! ทำการย้ายเซิร์ฟเวอร์...")
    if writefile then writefile(ROLL_FILE, tostring(rollCount)) end
    local servers = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")).data
    for _, server in ipairs(servers) do
        if server.id ~= game.JobId and server.playing < server.maxPlayers then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, player)
            break
        end
    end
end

-- [[ 7. MAIN LOOP - ลูปการทำงานหลัก ]]
print("🎬 เริ่มการทำงาน...")
while task.wait(3) do
    local currentStand = workspace.Live[player.Name]:GetAttribute("SummonedStand") or "None"
    local targets = USER_LIST[player.Name] or { "Whitesnake" }
    
    -- ตรวจสอบเป้าหมาย
    local found = false
    for _, t in pairs(targets) do if currentStand == t then found = true break end end
    if found then sendWebhook(currentStand, "SUCCESS") break end

    -- เก็บของและเช็คจำนวน
    teleportToItems()
    local arrow = player.PlayerGui.Inventory.CanvasGroup.backpack_frame.enlarging_frame.holder:FindFirstChild("Stand Arrow")
    local amount = arrow and tonumber(arrow.Holder.Holder.Number.Text:match("%d+")) or 0
    
    if amount > 0 then
        rollCount = rollCount + 1
        if writefile then writefile(ROLL_FILE, tostring(rollCount)) end
        
        print("🎲 รอบที่: " .. rollCount .. " | Stand: " .. currentStand)
        sendWebhook(currentStand, "ROLLING")
        
        ReplicatedStorage.requests.character.use_item:FireServer("Stand Arrow")
        task.wait(8)
        pcall(function() player.Character.client_character_controller.SummonStand:FireServer() end)
    else
        hopServer()
        break
    end
end
