repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

task.wait(6)

-- inventory
local holder = player.PlayerGui
:WaitForChild("Inventory")
:WaitForChild("CanvasGroup")
:WaitForChild("backpack_frame")
:WaitForChild("enlarging_frame")
:WaitForChild("holder")

-- live folder
local liveFolder = workspace:WaitForChild("Live")

-- item folder (สำคัญมาก เร็วกว่า scan ทั้งแมพ)
local itemsFolder = workspace:FindFirstChild("Items") or workspace

-- remote
local useArrow = ReplicatedStorage
:WaitForChild("requests")
:WaitForChild("character")
:WaitForChild("use_item")

local function getRoot()
    local char = player.Character or player.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart")
end

local function summonStand()

    local char = player.Character or player.CharacterAdded:Wait()

    char:WaitForChild("client_character_controller")
    :WaitForChild("SummonStand")
    :FireServer()

end

local function getStand()

    local char = liveFolder:FindFirstChild(player.Name)

    if char then
        return char:GetAttribute("SummonedStand")
    end

end

local function rollStand()

    local args = {"Stand Arrow"}
    useArrow:FireServer(unpack(args))

end

local function getArrowAmount()

    local slot = holder:FindFirstChild("Stand Arrow")

    if slot then
        local text = slot.Holder.Holder.Number.Text
        return tonumber(text:match("%d+")) or 0
    end

    return 0
end

-- หา Arrow ที่ใกล้ที่สุด (เฉพาะ Items folder)
local function getNearestArrow()

    local root = getRoot()
    local nearest = nil
    local dist = math.huge

    for _,v in pairs(itemsFolder:GetChildren()) do

        if v.Name == "Stand Arrow" then

            local part = v:IsA("BasePart") and v or v:FindFirstChildWhichIsA("BasePart")

            if part then

                local d = (root.Position - part.Position).Magnitude

                if d < dist then
                    dist = d
                    nearest = part
                end

            end

        end

    end

    return nearest
end


local function collectArrow(arrow)

    local root = getRoot()

    root.CFrame = arrow.CFrame + Vector3.new(0,3,0)

    task.wait(0.3)

    local prompt = arrow:FindFirstChildWhichIsA("ProximityPrompt",true)

    if prompt then
        fireproximityprompt(prompt)
    end

end


local function serverHop()

    warn("Server hopping...")
    TeleportService:Teleport(game.PlaceId)

end


-- เช็คตอนเข้าเซิร์ฟก่อน
local startStand = getStand()

if startStand == "Whitesnake" then
    warn("Already have Whitesnake")
    return
end


while task.wait(0.5) do

    local arrow = getNearestArrow()

    if arrow then

        collectArrow(arrow)

    else

        local amount = getArrowAmount()

        if amount <= 0 then

            warn("Arrow empty, waiting 10 seconds")

            task.wait(10)

            if getArrowAmount() <= 0 then
                serverHop()
                break
            end

        end

        rollStand()

        task.wait(2)

        summonStand()

        task.wait(1)

        local stand = getStand()

        print("Current Stand:",stand)

        if stand == "Whitesnake" then

            warn("WHITESNAKE FOUND")
            break

        end

    end

end
