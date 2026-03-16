-- [[ 1. CONFIGURATION ]]
local WEBHOOK_URL = "https://discord.com/api/webhooks/1479380422713409577/fTqx3VvsvwIQTked1qTNEoLQ_HVbaETnRjyEaVlrR0891T-NaMZJCel9zC3XBejPxJ9-"

local USER_LIST = {
    ["6245R"] = { "Gold Experience", "Whitesnake" },
    ["TopKen_001"] = { "XE", "YEID" },
}

-- [[ 2. SETUP & DATA LOADING ]]
print("⏳ Loading script...")
repeat task.wait() until game:IsLoaded()
repeat task.wait() until game.Players.LocalPlayer.Character

local player = game.Players.LocalPlayer
local ROLL_FILE = "TotalRolls_" .. player.UserId .. ".txt"
local MSG_FILE = "WebhookID_" .. player.UserId .. ".txt"

local rollCount = isfile(ROLL_FILE) and tonumber(readfile(ROLL_FILE)) or 0
local last_msg_id = isfile(MSG_FILE) and readfile(MSG_FILE) or nil

print("📊 สถิติเดิม: สุ่มไปแล้ว " .. rollCount .. " รอบ")

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

-- [[ 4. AUTO-COLLECT (With Logs) ]]
local function collectItems()
    local descendants = workspace:GetDescendants()
    if not descendants then return end
    
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

-- [[ 5. MAIN LOOP ]]
print("🎬 เริ่มการทำงาน...")
while task.wait(3) do
    local currentStand = "None"
    pcall(function() currentStand = workspace.Live[player.Name]:GetAttribute("SummonedStand") or "None" end)
    print("🧬 Stand ปัจจุบัน: " .. currentStand)

    local targets = USER_LIST[player.Name] or { "Whitesnake" }
    local found = false
    for _, t in pairs(targets) do if currentStand == t then found = true break end end
    
    updateWebhook(currentStand, found and "SUCCESS" or "ROLLING")
    if found then print("🎉 ภารกิจสำเร็จ! ได้แสตนด์ที่ต้องการแล้ว") break end

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
        print("🔄 ของหมด! กำลังย้ายเซิร์ฟเวอร์...")
        local success, result = pcall(function()
            return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")).data
        end)
        
        if success and result then
            for _, s in ipairs(result) do
                if s.id ~= game.JobId and s.playing < s.maxPlayers then
                    print("🚀 เจอเซิร์ฟเวอร์ใหม่: " .. s.id)
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, player)
                    break
                end
            end
        else
            print("❌ ไม่พบเซิร์ฟเวอร์ใหม่ หรือเกิด Error ใน API")
        end
        break
    end
end
