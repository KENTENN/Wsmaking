-- [[ 1. CONFIGURATION ]]
local WEBHOOK_URL = "https://discord.com/api/webhooks/1479380422713409577/fTqx3VvsvwIQTked1qTNEoLQ_HVbaETnRjyEaVlrR0891T-NaMZJCel9zC3XBejPxJ9-"

local USER_LIST = {
    ["6245R"] = { "Gold Experience", "Whitesnake" },

}

-- [[ 2. INITIALIZATION ]]
repeat task.wait() until game:IsLoaded()
repeat task.wait() until game.Players.LocalPlayer.Character

local player = game.Players.LocalPlayer
local ROLL_FILE = "TotalRolls_" .. player.UserId .. ".txt"
local MSG_FILE = "WebhookID_" .. player.UserId .. ".txt"

local rollCount = isfile(ROLL_FILE) and tonumber(readfile(ROLL_FILE)) or 0
local last_msg_id = isfile(MSG_FILE) and readfile(MSG_FILE) or nil

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

-- [[ 3. WEBHOOK SYSTEM (Edit Mode) ]]
local function updateWebhook(standName, status)
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

    local requestFunc = (syn and syn.request) or (http_request) or (request)
    local payload = HttpService:JSONEncode(data)

    if not last_msg_id then
        local res = requestFunc({Url = WEBHOOK_URL .. "?wait=true", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload})
        if res.Success then
            last_msg_id = HttpService:JSONDecode(res.Body).id
            writefile(MSG_FILE, last_msg_id)
        end
    else
        requestFunc({Url = WEBHOOK_URL .. "/messages/" .. last_msg_id, Method = "PATCH", Headers = {["Content-Type"] = "application/json"}, Body = payload})
    end
end

-- [[ 4. AUTO-COLLECT ]]
local function collectItems()
    local descendants = workspace:GetDescendants()
    for _, item in ipairs(descendants) do
        if (item.Name == "Stand Arrow" or item.Name == "Lucky Arrow") and item:FindFirstChildOfClass("ProximityPrompt") then
            local root = player.Character:FindFirstChild("HumanoidRootPart")
            if root then
                print("✨ เจอของ! กำลังวาร์ปไปเก็บ: " .. item.Name)
                root.CFrame = item:IsA("BasePart") and item.CFrame or item.Parent.CFrame
                task.wait(0.3)
                fireproximityprompt(item:FindFirstChildOfClass("ProximityPrompt"))
                task.wait(0.5)
            end
        end
    end
end

-- [[ 5. STABLE SERVER HOP (Loop + Delay) ]]
local function serverHop()
    print("🔄 ของหมด! กำลังเข้าสู่ระบบย้ายเซิร์ฟเวอร์...")
    local api_url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
    
    while task.wait(5) do -- หน่วงเวลา 5 วินาทีในแต่ละรอบเพื่อกันบัค
        local success, result = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(api_url)).data
        end)
        
        if success and result then
            for _, s in ipairs(result) do
                if s.id ~= game.JobId and s.playing < s.maxPlayers then
                    print("🚀 เจอเซิร์ฟเวอร์ใหม่: " .. s.id .. " กำลังวาร์ป...")
                    local teleportSuccess, teleportErr = pcall(function()
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, player)
                    end)
                    if not teleportSuccess then
                        print("❌ วาร์ปล้มเหลว: " .. tostring(teleportErr) .. " กำลังลองใหม่...")
                    end
                end
            end
        else
            print("⚠️ ไม่พบข้อมูลเซิร์ฟเวอร์หรือ API Error (กำลังรอสุ่มใหม่...)")
        end
    end
end

-- [[ 6. MAIN LOOP ]]
print("🎬 ระบบเริ่มทำงาน (Single Message Edit Mode)...")
while task.wait(3) do
    local currentStand = "None"
    pcall(function() currentStand = workspace.Live[player.Name]:GetAttribute("SummonedStand") or "None" end)
    print("🧬 Stand ปัจจุบัน: " .. currentStand)

    local targets = USER_LIST[player.Name] or { "Whitesnake" }
    local found = false
    for _, t in pairs(targets) do if currentStand == t then found = true break end end
    
    updateWebhook(currentStand, found and "SUCCESS" or "ROLLING")
    if found then print("🎉 สำเร็จ! ได้ตัวที่ต้องการแล้ว") break end

    collectItems()
    
    local arrow = player.PlayerGui.Inventory.CanvasGroup.backpack_frame.enlarging_frame.holder:FindFirstChild("Stand Arrow")
    local amount = arrow and tonumber(arrow.Holder.Holder.Number.Text:match("%d+")) or 0
    
    if amount > 0 then
        rollCount = rollCount + 1
        writefile(ROLL_FILE, tostring(rollCount))
        print("🎲 รอบที่: " .. rollCount)
        
        ReplicatedStorage.requests.character.use_item:FireServer("Stand Arrow")
        task.wait(8)
        pcall(function() player.Character.client_character_controller.SummonStand:FireServer() end)
        task.wait(2)
    else
        serverHop() -- เข้าสู่ลูปย้ายเซิร์ฟเวอร์แบบไม่หลุด
        break
    end
end
