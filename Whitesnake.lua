-- [[ 1. CONFIGURATION ]]
local WEBHOOK_URL = "https://discord.com/api/webhooks/1479380422713409577/fTqx3VvsvwIQTked1qTNEoLQ_HVbaETnRjyEaVlrR0891T-NaMZJCel9zC3XBejPxJ9-"

local USER_LIST = {
    ["6245R"] = { "Gold Experience", "Whitesnake" },
    [""] = { "" },
}

-- [[ 2. SETUP & DATA ]]
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

-- [[ 4. STABLE SERVER HOP ]]
local function serverHop()
    print("🔄 ของหมด! วนลูปหาเซิร์ฟเวอร์ใหม่...")
    local api_url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
    while task.wait(5) do
        local success, result = pcall(function() return HttpService:JSONDecode(game:HttpGet(api_url)).data end)
        if success and result then
            for _, s in ipairs(result) do
                if s.id ~= game.JobId and s.playing < s.maxPlayers then
                    print("🚀 กำลังวาร์ปไป: " .. s.id)
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, player)
                end
            end
        end
    end
end

-- [[ 5. MAIN LOGIC ]]
print("🎬 เริ่มระบบ (Reliable Start Mode)...")

-- *** STEP 1: ลูป Summon จนกว่าค่าจะไม่ใช่ None ***
local currentStand = "None"
repeat
    print("⏳ พยายามเรียกแสตนด์เพื่อเช็คค่า...")
    pcall(function() player.Character.client_character_controller.SummonStand:FireServer() end)
    task.wait(4) -- เวลารอแอนิเมชันและ Attribute อัปเดต
    currentStand = workspace.Live[player.Name]:GetAttribute("SummonedStand") or "None"
until currentStand ~= "None"

print("✅ ตรวจสอบสำเร็จ! แสตนด์ปัจจุบันคือ: " .. currentStand)

-- *** STEP 2: เข้าลูปทำงานหลัก ***
while task.wait(3) do
    currentStand = workspace.Live[player.Name]:GetAttribute("SummonedStand") or "None"
    local targets = USER_LIST[player.Name] or { "Whitesnake" }
    
    local found = false
    for _, t in pairs(targets) do if currentStand == t then found = true break end end
    
    updateWebhook(currentStand, found and "SUCCESS" or "ROLLING")
    if found then print("🎉 ภารกิจสำเร็จ!") break end

    -- เก็บของ
    for _, item in ipairs(workspace:GetDescendants()) do
        if (item.Name == "Stand Arrow" or item.Name == "Lucky Arrow") and item:FindFirstChildOfClass("ProximityPrompt") then
            local root = player.Character:FindFirstChild("HumanoidRootPart")
            if root then
                root.CFrame = item:IsA("BasePart") and item.CFrame or item.Parent.CFrame
                task.wait(0.3)
                fireproximityprompt(item:FindFirstChildOfClass("ProximityPrompt"))
                task.wait(0.5)
            end
        end
    end

    -- เช็คไอเทมเพื่อสุ่ม
    local arrow = player.PlayerGui.Inventory.CanvasGroup.backpack_frame.enlarging_frame.holder:FindFirstChild("Stand Arrow")
    local amount = arrow and tonumber(arrow.Holder.Holder.Number.Text:match("%d+")) or 0
    
    if amount > 0 then
        rollCount = rollCount + 1
        writefile(ROLL_FILE, tostring(rollCount))
        print("🎲 รอบที่: " .. rollCount .. " | Stand: " .. currentStand)
        
        ReplicatedStorage.requests.character.use_item:FireServer("Stand Arrow")
        task.wait(8)
        
        -- ลูป Summon หลังสุ่มเพื่อให้แน่ใจว่าได้ค่าใหม่
        repeat
            pcall(function() player.Character.client_character_controller.SummonStand:FireServer() end)
            task.wait(4)
            currentStand = workspace.Live[player.Name]:GetAttribute("SummonedStand") or "None"
        until currentStand ~= "None"
    else
        serverHop()
        break
    end
end
