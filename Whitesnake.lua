repeat task.wait() until game:IsLoaded()

-- [[ ตั้งค่า WEBHOOK ตรงนี้ ]] --
local WEBHOOK_URL = "https://discord.com/api/webhooks/1479380422713409577/fTqx3VvsvwIQTked1qTNEoLQ_HVbaETnRjyEaVlrR0891T-NaMZJCel9zC3XBejPxJ9-" 
local last_msg_id = nil 
local rollCount = 0 -- ตัวนับจำนวนครั้งที่สุ่ม

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local placeId = game.PlaceId
local jobId = game.JobId

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
    if char then
        for _, v in pairs(char:GetChildren()) do
            if v:IsA("Model") and v.Name == "Whitesnake" then return true end
        end
    end
    return false
end

local function getItemAmount(itemName)
    local slot = holder:FindFirstChild(itemName)
    if slot then
        local success, result = pcall(function()
            return slot.Holder.Holder.Number.Text:match("%d+") or "0"
        end)
        return success and result or "0"
    end
    return "0"
end

-- [[ Webhook Update (เพิ่ม Roll Count ใน Field) ]] --
local function sendWebhookUpdate(standName, status)
    if not WEBHOOK_URL or WEBHOOK_URL == "" or not WEBHOOK_URL:find("http") then return end

    local arrowCount = getItemAmount("Stand Arrow")
    local luckyCount = getItemAmount("Lucky Arrow")
    
    local data = {
        ["embeds"] = {{
            ["title"] = "✨ Stand Gacha Live Monitor",
            ["color"] = (status == "SUCCESS") and 0x00ff00 or 0xff8c00,
            ["fields"] = {
                {["name"] = "👤 Player", ["value"] = "||" .. player.Name .. "||", ["inline"] = true},
                {["name"] = "🧬 Current Stand", ["value"] = "**" .. standName .. "**", ["inline"] = true},
                {["name"] = "📊 Statistics", ["value"] = "Total Rolls: **" .. rollCount .. "**", ["inline"] = true},
                {["name"] = "🏹 Inventory", ["value"] = "Stand Arrows: **" .. arrowCount .. "** | Lucky Arrows: **" .. luckyCount .. "**", ["inline"] = false},
                {["name"] = "🚩 Status", ["value"] = (status == "SUCCESS") and "✅ **FOUND WHITESNAKE!**" or "🔄 **Rolling...**", ["inline"] = true}
            },
            ["footer"] = {["text"] = "Server: " .. jobId .. " | Last Update: " .. os.date("%X")},
            ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }

    pcall(function()
        local requestFunc = (syn and syn.request) or (http_request) or (request)
        if not last_msg_id then
            local resp = requestFunc({Url = WEBHOOK_URL .. "?wait=true", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
            if resp.Success then last_msg_id = HttpService:JSONDecode(resp.Body).id end
        else
            requestFunc({Url = WEBHOOK_URL .. "/messages/" .. last_msg_id, Method = "PATCH", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
        end
    end)
end

-- [[ Logic ฟาร์ม ]] --

local function findArrow()
    for _,v in pairs(workspace:GetChildren()) do
        if v:FindFirstChild("Stand Arrow") then return v["Stand Arrow"] end
    end
    return nil
end

local function collectArrow()
    local arrow = findArrow()
    if arrow then
        local char = player.Character or player.CharacterAdded:Wait()
        local root = char:WaitForChild("HumanoidRootPart")
        root.CFrame = arrow.CFrame + Vector3.new(0, 3, 0)
        task.wait(0.5)
        local prompt = arrow:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then fireproximityprompt(prompt) end
        return true
    end
    return false
end

local function serverHop()
    print("No items left. Hopping...")
    local cursor = ""
    while true do
        local success, data = pcall(function()
            return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..placeId.."/servers/Public?sortOrder=Asc&limit=100&cursor="..cursor))
        end)
        if success and data then
            for _, server in pairs(data.data) do
                if server.playing < server.maxPlayers and server.id ~= jobId then
                    TeleportService:TeleportToPlaceInstance(placeId, server.id, player)
                    return
                end
            end
            cursor = data.nextPageCursor
            if not cursor then break end
        end
        task.wait(1)
    end
end

-- [[ Main Execution ]] --

task.wait(5)
if isWhitesnake() then
    sendWebhookUpdate(getStand(), "SUCCESS")
    return
end

while task.wait(1) do
    if isWhitesnake() then
        sendWebhookUpdate(getStand(), "SUCCESS")
        break
    end

    local arrowInMap = findArrow()
    if arrowInMap then
        collectArrow()
        task.wait(2)
    else
        local arrowAmt = tonumber(getItemAmount("Stand Arrow")) or 0
        if arrowAmt > 0 then
            -- เพิ่มจำนวน Roll เมื่อกดใช้
            rollCount = rollCount + 1
            print("Rolling... Count: " .. rollCount)
            
            useItem:FireServer("Stand Arrow")
            task.wait(8)
            
            local char = player.Character or player.CharacterAdded:Wait()
            local controller = char:FindFirstChild("client_character_controller")
            if controller and controller:FindFirstChild("SummonStand") then
                controller.SummonStand:FireServer()
            end
            
            task.wait(2)
            local res = getStand()
            sendWebhookUpdate(res, isWhitesnake() and "SUCCESS" or "ROLLING")
            
            if isWhitesnake() then break end
        else
            task.wait(2)
            if not findArrow() then
                serverHop()
                break
            end
        end
    end
end
