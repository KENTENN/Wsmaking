repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local player = Players.LocalPlayer

-- Remote ใช้ลูกธนู
local useArrow = game:GetService("ReplicatedStorage")
:WaitForChild("requests")
:WaitForChild("character")
:WaitForChild("use_item")

-- inventory
local holder = player.PlayerGui
:WaitForChild("Inventory")
:WaitForChild("CanvasGroup")
:WaitForChild("backpack_frame")
:WaitForChild("enlarging_frame")
:WaitForChild("holder")

-- หา HumanoidRootPart
local function getRoot()
    local char = player.Character or player.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart")
end

-- เช็คจำนวน Stand Arrow
local function getStandArrow()

    local slot = holder:FindFirstChild("Stand Arrow")

    if slot then
        local text = slot.Holder.Holder.Number.Text
        local amount = tonumber(text:match("%d+")) or 0
        return amount
    end

    return 0
end

-- หา Stand Arrow ในแมพ
local function getNearestArrow()

    local root = getRoot()
    local nearest = nil
    local dist = math.huge

    for _,v in pairs(workspace:GetDescendants()) do

        if v.Name == "Stand Arrow" and v:IsA("BasePart") then

            local d = (root.Position - v.Position).Magnitude

            if d < dist then
                dist = d
                nearest = v
            end

        end

    end

    return nearest
end

-- เก็บ Arrow
local function collectArrow(arrow)

    local root = getRoot()

    root.CFrame = arrow.CFrame + Vector3.new(0,3,0)

    task.wait(0.4)

    local prompt = arrow:FindFirstChildWhichIsA("ProximityPrompt",true)

    if prompt then
        fireproximityprompt(prompt)
    end

end

-- ใช้ Stand Arrow
local function rollStand()

    local args = {"Stand Arrow"}
    useArrow:FireServer(unpack(args))

end

-- เช็ค Stand ที่ได้
local function getStand()

    local effects = workspace:FindFirstChild("Effects")

    if effects then
        local stand = effects:FindFirstChild(player.Name.."'s Stand")

        if stand then
            return stand:GetAttribute("Stand")
        end
    end

end

-- server hop
local function serverHop()

    TeleportService:Teleport(game.PlaceId)

end


while task.wait(1) do

    local arrow = getNearestArrow()

    -- มี Arrow ในแมพ
    if arrow then

        collectArrow(arrow)

    else

        -- ไม่มี Arrow ในแมพ
        local amount = getStandArrow()

        if amount > 0 then

            rollStand()

            task.wait(2)

            local stand = getStand()

            print("Current Stand:",stand)

            if stand == "Whitesnake" then
                warn("GOT WHITESNAKE")
                break
            end

        else

            warn("No Arrow -> Server Hop")

            serverHop()

        end

    end

end
