local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local player = Players.LocalPlayer

local ImGui = loadstring(game:HttpGet("https://raw.githubusercontent.com/depthso/Roblox-ImGUI/main/ImGui.lua"))()

local RARITIES = { Mythical = true, Secret = true, Exclusive = true }
local STATE = {
    running = false,
    capturing = false,
    clicking = false,
    capturedCount = 0,
}

local function log(msg)
    print(string.format("[%s] %s", os.date("%H:%M:%S"), msg))
end

local function serverHop()
    log("Procurando novo servidor...")
    local currentJobId = game.JobId
    local success, servers = pcall(function()
        return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
    end)
    if not success or not servers or not servers.data then
        log("Erro ao buscar servidores, tentando qualquer um...")
        task.wait(3)
        TeleportService:Teleport(game.PlaceId, player)
        return
    end
    local validServers = {}
    for _, server in ipairs(servers.data) do
        if server.id ~= currentJobId and server.playing < server.maxPlayers - 5 then
            table.insert(validServers, server.id)
        end
    end
    if #validServers > 0 then
        local targetServer = validServers[math.random(1, #validServers)]
        log("Servidor encontrado! Teleportando...")
        TeleportService:TeleportToPlaceInstance(game.PlaceId, targetServer, player)
    else
        log("Nenhum servidor disponivel, tentando qualquer um...")
        TeleportService:Teleport(game.PlaceId, player)
    end
end

local function GetPetByRarity()
    for _, v in workspace.RoamingPets.Pets:GetChildren() do
        if v:IsA("Model") and RARITIES[v:GetAttribute("Rarity")] then
            return v
        end
    end
end

local function equipLasso()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.One, false, game)
    task.wait(0.05)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.One, false, game)
    task.wait(0.3)
end

local function startAutoClick()
    STATE.clicking = true
    task.spawn(function()
        local vp = workspace.CurrentCamera.ViewportSize
        local cx, cy = vp.X / 2, vp.Y / 2
        while STATE.clicking do
            VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
            task.wait(0.01)
            VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
            task.wait(0.08)
        end
    end)
end

local function stopAutoClick()
    STATE.clicking = false
end

local function startAimbot(pet)
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not pet.Parent or not STATE.capturing then
            conn:Disconnect()
            return
        end
        local character = player.Character
        if not character then return end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local petPos = pet:GetPrimaryPartCFrame().Position
        hrp.CFrame = CFrame.new(hrp.Position, Vector3.new(petPos.X, hrp.Position.Y, petPos.Z))
    end)
end

local function capturePet(pet)
    if STATE.capturing then return false end
    STATE.capturing = true
    log(string.format("ALVO: %s [%s]", pet.Name, pet:GetAttribute("Rarity")))
    equipLasso()
    local character = player.Character
    if not character then STATE.capturing = false return false end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then STATE.capturing = false return false end
    local petPos = pet:GetPrimaryPartCFrame().Position
    local dist = (petPos - hrp.Position).Magnitude
    if dist > 10 then
        hrp.CFrame = CFrame.new(petPos + Vector3.new(0, 8, 0))
        task.wait(0.2)
    end
    if not pet.Parent then
        STATE.capturing = false
        return false
    end
    startAimbot(pet)
    startAutoClick()
    task.wait(0.2)
    local startTime = tick()
    while (tick() - startTime) < 5 do
        if not pet.Parent then
            stopAutoClick()
            STATE.capturedCount = STATE.capturedCount + 1
            log(string.format("CAPTURADO! Total: %d", STATE.capturedCount))
            STATE.capturing = false
            return true
        end
        task.wait(0.1)
    end
    stopAutoClick()
    log("Timeout na captura")
    STATE.capturing = false
    return false
end

local function mainLoop()
    log("SERVER HOP FARM INICIADO!")
    log("Alvos: Mythical, Secret, Exclusive")
    while STATE.running do
        task.wait(1)
        local targetPet = GetPetByRarity()
        if not targetPet then
            log("Nenhum alvo encontrado. Trocando servidor em 1s...")
            task.wait(1)
            serverHop()
            break
        end
        if capturePet(targetPet) then
            log("Trocando servidor em 1s...")
            task.wait(1)
            serverHop()
            break
        end
    end
end

local Window = ImGui:CreateWindow({
    Title = "Server Hop Farm",
    Size = UDim2.new(0, 300, 0, 200),
    Position = UDim2.new(0.5, 0, 0, 50)
})
Window:Center()

local Tab = Window:CreateTab({ Name = "Farm" })
Tab:Label({ Text = "Server Hop Auto Farm" })
Tab:Label({ Text = "Mythical, Secret, Exclusive" })
Tab:Separator()

local statusLabel = Tab:Label({ Text = "Status: Parado" })
local capturedLabel = Tab:Label({ Text = "Capturados: 0" })

Tab:Separator()
Tab:Button({
    Text = "INICIAR",
    Callback = function()
        STATE.running = true
        statusLabel.Text = "Status: RODANDO"
        task.spawn(mainLoop)
    end
})

Tab:Button({
    Text = "PARAR",
    Callback = function()
        STATE.running = false
        statusLabel.Text = "Status: PARADO"
    end
})

task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(function()
            capturedLabel.Text = "Capturados: " .. STATE.capturedCount
            if STATE.capturing then
                statusLabel.Text = "Status: CAPTURANDO..."
            elseif STATE.running then
                statusLabel.Text = "Status: PROCURANDO..."
            end
        end)
    end
end)

log("GUI carregada! Clique em INICIAR para começar.")
