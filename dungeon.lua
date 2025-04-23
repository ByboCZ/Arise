-- // Services //
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- // Variables //
local player = Players.LocalPlayer
local gPlr = player
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")
local enemiesFolder = Workspace:WaitForChild("__Main"):WaitForChild("__Enemies"):WaitForChild("Client")
local remote = ReplicatedStorage:WaitForChild("BridgeNet2"):WaitForChild("dataRemoteEvent")

-- Farm Method Selection Dropdown
local Fluent
local SaveManager
local InterfaceManager

local success, err = pcall(function()
    Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
    SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
    InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()
end)

if not success then
    warn("Error loading Fluent library: " .. tostring(err))
    -- Try loading from backup URL
    pcall(function()
        Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Fluent.lua"))()
        SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
        InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()
    end)
end

if not Fluent then
    error("Failed to load Fluent library. Please check your internet connection or executor.")
    return
end

local teleportEnabled = false
local killedNPCs = {}
local dungeonkill = {}
local selectedMobName = ""
local movementMethod = "Tween" -- Default movement method
local farmingStyle = "Default" -- Default farming style
local attackCooldown = 0.1
local autoAttackEnabled = false
local autoDetect = true


-- // Configuration System //
local ConfigSystem = {}
ConfigSystem.Folder = "ByboScripts"
ConfigSystem.SubFolder = "AriseCrossover"
ConfigSystem.FileName = player.Name .. "_Dungeon.json"
ConfigSystem.FilePath = ConfigSystem.Folder .. "/" .. ConfigSystem.SubFolder .. "/" .. ConfigSystem.FileName
ConfigSystem.DefaultConfig = {
    SelectedMobName = "",
    FarmSelectedMob = false,
    AutoFarmNearestNPCs = false,
    MainAutoDestroy = false,
    MainAutoArise = false,
    FarmingMethod = "Tween",
    DamageMobs = false,
    AutoAttackEnabled = false,
    GamepassShadowFarm = false,
    AntiAfk = false,
    AutoFarmDungeon = false,
}
ConfigSystem.CurrentConfig = {}


-- // Reset Velocity Function //
local function resetVelocity()
    if hrp and hrp:IsA("BasePart") then
        hrp.Velocity = Vector3.zero
        hrp.RotVelocity = Vector3.zero
    end
end

resetVelocity()

-- // Saving Config//
-- Function to create folders for config files
ConfigSystem.CreateFolders = function()
    -- Try different methods to create folders across various executors
    local success = pcall(function()
        if makefolder then
            if not isfolder(ConfigSystem.Folder) then
                makefolder(ConfigSystem.Folder)
            end
            
            if not isfolder(ConfigSystem.Folder .. "/" .. ConfigSystem.SubFolder) then
                makefolder(ConfigSystem.Folder .. "/" .. ConfigSystem.SubFolder)
            end
        end
    end)

    return success
end

-- Function to save the config (tries multiple methods)
ConfigSystem.SaveConfig = function()
    -- Ensure the folders exist
    ConfigSystem.CreateFolders()

    -- Encode the configuration as a JSON string
    local jsonData = HttpService:JSONEncode(ConfigSystem.CurrentConfig)

    -- Try different save methods
    local success, err = pcall(function()
        -- Method 1: Direct writefile (Synapse X, KRNL, Script-Ware)
        if writefile then
            writefile(ConfigSystem.FilePath, jsonData)
            return true
        end

        -- Method 2: Using SaveInstance (some other executors)
        if saveinstance then
            saveinstance(ConfigSystem.FilePath, jsonData)
            return true
        end

        -- Method 3: Fluxus and some other executors
        if fluxus and fluxus.save_file then
            fluxus.save_file(ConfigSystem.FilePath, jsonData)
            return true
        end

        -- Method 4: Delta and some other executors
        if delta_config and delta_config.save then
            delta_config.save(ConfigSystem.FilePath, jsonData)
            return true
        end

        -- Method 5: Codex
        if writefile and getrenv().writefile then
            getrenv().writefile(ConfigSystem.FilePath, jsonData)
            return true
        end

        return false
    end)

    if success then
        -- Save succeeded
    else
        warn("Failed to save config:", err)
    end
end

-- Function to load the config (tries multiple methods)
ConfigSystem.LoadConfig = function()
    -- Try different read methods
    local success, content = pcall(function()
        -- Method 1: Standard readfile (Synapse X, KRNL, Script-Ware)
        if readfile and isfile and isfile(ConfigSystem.FilePath) then
            return readfile(ConfigSystem.FilePath)
        end

        -- Method 2: Fluxus
        if fluxus and fluxus.read_file and fluxus.file_exists and fluxus.file_exists(ConfigSystem.FilePath) then
            return fluxus.read_file(ConfigSystem.FilePath)
        end

        -- Method 3: Delta
        if delta_config and delta_config.load and delta_config.exists and delta_config.exists(ConfigSystem.FilePath) then
            return delta_config.load(ConfigSystem.FilePath)
        end

        -- Method 4: Codex
        if readfile and getrenv().readfile and isfile and getrenv().isfile and getrenv().isfile(ConfigSystem.FilePath) then
            return getrenv().readfile(ConfigSystem.FilePath)
        end

        return nil
    end)

    if success and content then
        local data
        success, data = pcall(function()
            return HttpService:JSONDecode(content)
        end)

        if success and data then
            ConfigSystem.CurrentConfig = data
            print("Loaded Config:", ConfigSystem.CurrentConfig) 
            return true
        else
            warn("Error parsing config, creating a new one.")
        end
    end

    -- If reading failed or there was an error, create a default config
    ConfigSystem.CurrentConfig = table.clone(ConfigSystem.DefaultConfig)
    ConfigSystem.SaveConfig()
    print("Initialized new config")
    return false
end

-- Create a separate auto-save system
local function setupAutoSave()
    spawn(function()
        while wait(5) do -- Save every 5 seconds
            pcall(function()
                ConfigSystem.SaveConfig()
            end)
        end
    end)
end

-- Load config on startup
ConfigSystem.LoadConfig()
setupAutoSave() -- Start auto-save

-- Update function to save immediately when a value changes
local function setupSaveEvents()
    for _, tab in pairs(Tabs) do
        if tab and tab._components then
            for _, element in pairs(tab._components) do
                if element and element.OnChanged then
                    element.OnChanged:Connect(function()
                        pcall(function()
                            ConfigSystem.SaveConfig()
                        end)
                    end)
                end
            end
        end
    end
end

-- Change how config is saved/loaded
local function AutoSaveConfig()
    local configName = "AutoSave_" .. playerName

    -- Auto-save current config
    task.spawn(function()
        while task.wait(5) do -- Save every 5 seconds
            pcall(function()
                SaveManager:Save(configName)
            end)
        end
    end)

    -- Load saved config if available
    pcall(function()
        SaveManager:Load(configName)
    end)
end

-- Add event listener to save immediately when a value changes
local function setupSaveEvents()
    for _, tab in pairs(Tabs) do
        if tab and tab._components then -- Check if the tab and tab._components exist
            for _, element in pairs(tab._components) do
                if element and element.OnChanged then -- Check if the element and its OnChanged event exist
                    element.OnChanged:Connect(function()
                        pcall(function()
                            SaveManager:Save("AutoSave_" .. playerName)
                        end)
                    end)
                end
            end
        end
    end
end


-- Setup SaveManager and InterfaceManager folders for Fluent compatibility
local playerName = game:GetService("Players").LocalPlayer.Name
if InterfaceManager then
    InterfaceManager:SetFolder("ByboScripts/AriseCrossover/" .. playerName)
end
if SaveManager then
    SaveManager:SetFolder("ByboScripts/AriseCrossover/" .. playerName)
end

-- Automatically detect a new HumanoidRootPart when the player respawns
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    hrp = newCharacter:WaitForChild("HumanoidRootPart")
end)


-- // GUI Setup //
local Window = Fluent:CreateWindow({
    Title = "ByboScripts | Arise Crossover",
    SubTitle = "",
    TabWidth = 140,
    Size = UDim2.fromOffset(600, 500),
    Acrylic = false,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Info = Window:AddTab({
        Title = "Info",
        Icon = "rbxassetid://101695740876438"
    }),
    Main = Window:AddTab({
        Title = "Main",
        Icon = "rbxassetid://127490035777686"
    }),
    Dungeon = Window:AddTab({
        Title = "Dungeon ",
        Icon = "rbxassetid://71538155155717"
    }),
    Settings = Window:AddTab({
        Title = "Settings",
        Icon = "rbxassetid://103484168808307"
    })
}

Window:SelectTab(1)

Fluent:Notify({
    Title = "ByboScripts",
    Content = "Script loaded! Config is auto-saving under player name: " .. playerName,
    Duration = 3
})

-- // Anti-Cheat Fix //
local function anticheat()
    local player = game.Players.LocalPlayer
    if player and player.Character then
        local characterScripts = player.Character:FindFirstChild("CharacterScripts")
        
        if characterScripts then
            local flyingFixer = characterScripts:FindFirstChild("FlyingFixer")
            if flyingFixer then
                flyingFixer:Destroy()
            end

            local characterUpdater = characterScripts:FindFirstChild("CharacterUpdater")
            if characterUpdater then
                characterUpdater:Destroy()
            end
        end
    end
end


local function anticheat()
    local player = game.Players.LocalPlayer
    if player and player.Character then
        local characterScripts = player.Character:FindFirstChild("CharacterScripts")
        
        if characterScripts then
            local flyingFixer = characterScripts:FindFirstChild("FlyingFixer")
            if flyingFixer then
                flyingFixer:Destroy()
            end

            local characterUpdater = characterScripts:FindFirstChild("CharacterUpdater")
            if characterUpdater then
                characterUpdater:Destroy()
            end
        end
    end
end

local function isEnemyDead(enemy)
    local healthBar = enemy:FindFirstChild("HealthBar")
    if healthBar and healthBar:FindFirstChild("Main") and healthBar.Main:FindFirstChild("Bar") then
        local amount = healthBar.Main.Bar:FindFirstChild("Amount")
        if amount and amount:IsA("TextLabel") and amount.ContentText == "0 HP" then
            return true
        end
    end
    return false
end

local function getAnyEnemy()
    local nearestEnemy, shortestDistance = nil, math.huge
    local playerPosition = hrp.Position
    local maxSearchDistance = 1000 -- Increased from 100 to 1000 to find distant enemies

    -- First pass: Search within the initial range
    for _, enemy in ipairs(enemiesFolder:GetChildren()) do
        if enemy:IsA("Model") and enemy:FindFirstChild("HumanoidRootPart") and not dungeonkill[enemy.Name] then
            local distance = (playerPosition - enemy.HumanoidRootPart.Position).Magnitude
            if distance < shortestDistance and distance <= maxSearchDistance then
                shortestDistance = distance
                nearestEnemy = enemy
            end
        end
    end

    -- Second pass: Expand the range if no enemy is found
    if not nearestEnemy then
        maxSearchDistance = 5000 -- Dramatically expand the search range (from 1000 to 5000)
        for _, enemy in ipairs(enemiesFolder:GetChildren()) do
            if enemy:IsA("Model") and enemy:FindFirstChild("HumanoidRootPart") and not dungeonkill[enemy.Name] then
                local distance = (playerPosition - enemy.HumanoidRootPart.Position).Magnitude
                if distance < shortestDistance then
                    shortestDistance = distance
                    nearestEnemy = enemy
                end
            end
        end
    end

    return nearestEnemy
end


-- Send ShowPets event to server
local function fireShowPetsRemote()
    local args = {
        [1] = {
            [1] = {
                ["Event"] = "ShowPets"
            },
            [2] = "\t"
        }
    }
    remote:FireServer(unpack(args))
end

local function getNearestEnemy()
    local nearestEnemy, shortestDistance = nil, math.huge
    local playerPosition = hrp.Position

    for _, enemy in ipairs(enemiesFolder:GetChildren()) do
        if enemy:IsA("Model") and enemy:FindFirstChild("HumanoidRootPart") and not killedNPCs[enemy.Name] then
            local distance = (playerPosition - enemy:GetPivot().Position).Magnitude
            if distance < shortestDistance then
                shortestDistance = distance
                nearestEnemy = enemy
            end
        end
    end
    return nearestEnemy
end


local function moveToTarget(target)
    if not target or not target:FindFirstChild("HumanoidRootPart") then return end
    local enemyHrp = target.HumanoidRootPart

    if movementMethod == "Teleport" then
        hrp.CFrame = enemyHrp.CFrame * CFrame.new(0, 0, 6)
    elseif movementMethod == "Tween" then
        local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear)
        local tween = TweenService:Create(hrp, tweenInfo, {CFrame = enemyHrp.CFrame * CFrame.new(0, 0, 6)})
        tween:Play()
    elseif movementMethod == "Walk" then
        hrp.Parent:MoveTo(enemyHrp.Position)
    end
end

local function teleportAndTrackDeath()
    while teleportEnabled do
        local target = getNearestEnemy()
        if target and target.Parent then
            anticheat()
            moveToTarget(target)
            task.wait(0.5)
            fireShowPetsRemote()
            remote:FireServer({{
                ["PetPos"] = {},
                ["AttackType"] = "All",
                ["Event"] = "Attack",
                ["Enemy"] = target.Name
            }, "\7"})

            while teleportEnabled and target.Parent and not isEnemyDead(target) do
                task.wait(0.1)
            end

            killedNPCs[target.Name] = true
        end
        task.wait(0.2)
    end
end


local function teleportDungeon()
    local lastEnemyPosition = nil
    local secondLastEnemyPosition = nil
    local thirdLastEnemyPosition = nil
    local lastEnemy = nil

    while teleportEnabled do
        local target = getAnyEnemy()

        if target and target.Parent then
            -- If the target is new, shift last to secondLast, then update
            if target ~= lastEnemy and not isEnemyDead(target) then
                thirdLastEnemyPosition = secondLastEnemyPosition
                secondLastEnemyPosition = lastEnemyPosition
                lastEnemyPosition = target.HumanoidRootPart.Position
                lastEnemy = target
            end

            -- Check distance to the target
            local distance = (hrp.Position - target.HumanoidRootPart.Position).Magnitude
            
            -- Perform actions on the target
            anticheat()
            moveToTarget(target)
            
            -- Add a distance-based wait time - farther enemies might need more time to load properly
            if distance > 500 then
                task.wait(1) -- Longer wait for distant enemies
            else
                task.wait(0.5)
            end
            
            fireShowPetsRemote()
            remote:FireServer({{
                ["PetPos"] = {},
                ["AttackType"] = "All",
                ["Event"] = "Attack",
                ["Enemy"] = target.Name
            }, "\7"})

            -- Wait until the target is defeated with a timeout to prevent getting stuck
            local startTime = tick()
            repeat
                task.wait(0.3)
                -- Break out after 10 seconds to prevent getting stuck on a single enemy
                if tick() - startTime > 10 then
                    print("[DEBUG] Timeout waiting for enemy to be defeated")
                    break
                end
            until not target.Parent or isEnemyDead(target)

            dungeonkill[target.Name] = true
        else
            -- Enhanced search pattern if no enemy is found
            print("[DEBUG] No enemies found, searching in different locations...")
            
            -- First try second last position
            if secondLastEnemyPosition then
                hrp.CFrame = CFrame.new(secondLastEnemyPosition)
                task.wait(2) -- Wait for enemies to load
                
                -- Check for enemies at second position
                local secondTarget = getAnyEnemy()
                if not secondTarget or isEnemyDead(secondTarget) then
                    -- No enemy found at second position, teleport to third position
                    if thirdLastEnemyPosition then
                        hrp.CFrame = CFrame.new(thirdLastEnemyPosition)
                        task.wait(2) -- Wait for enemies to load
                    else
                        -- If no third position, try random exploration
                        local randomOffset = Vector3.new(math.random(-100, 100), 0, math.random(-100, 100))
                        hrp.CFrame = CFrame.new(hrp.Position + randomOffset)
                        task.wait(3)
                    end
                end
            else
                -- If we don't have previous positions, do some exploration
                local randomOffset = Vector3.new(math.random(-150, 150), 0, math.random(-150, 150))
                hrp.CFrame = CFrame.new(hrp.Position + randomOffset)
                task.wait(3)
            end
        end

        task.wait(0.2)
    end
end


local function fireDestroy()
    while autoDestroy do
        task.wait(0.3)
        for _, enemy in ipairs(enemiesFolder:GetChildren()) do
            if enemy:IsA("Model") then
                local rootPart = enemy:FindFirstChild("HumanoidRootPart")
                local DestroyPrompt = rootPart and rootPart:FindFirstChild("DestroyPrompt")
                if DestroyPrompt then
                    DestroyPrompt:SetAttribute("MaxActivationDistance", 100000)
                    fireproximityprompt(DestroyPrompt)
                end
            end
        end
    end
end

-- Function to trigger ArisePrompt
local function fireArise()
    while autoArise do
        task.wait(0.3)
        for _, enemy in ipairs(enemiesFolder:GetChildren()) do
            if enemy:IsA("Model") then
                local rootPart = enemy:FindFirstChild("HumanoidRootPart")
                local arisePrompt = rootPart and rootPart:FindFirstChild("ArisePrompt")
                if arisePrompt then
                    arisePrompt:SetAttribute("MaxActivationDistance", 100000)
                    fireproximityprompt(arisePrompt)
                end
            end
        end
    end
end

-- Update HRP when character respawns
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    hrp = character:WaitForChild("HumanoidRootPart")
end)

-- Function to trigger DestroyPrompt
local enemiesFolder = workspace:WaitForChild("__Main"):WaitForChild("__Enemies"):WaitForChild("Client")

local VirtualUser = game:GetService("VirtualUser")
local antiAfkConnection




local function tweenCharacter(targetCFrame)
    if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = player.Character.HumanoidRootPart
        local tweenService = game:GetService("TweenService")
        local tweenInfo = TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local tween = tweenService:Create(hrp, tweenInfo, {
            CFrame = targetCFrame
        })
        tween:Play()
    end
end


local enemyContainer = workspace:WaitForChild("__Main"):WaitForChild("__Enemies"):WaitForChild("Client")
local networkEvent = game:GetService("ReplicatedStorage"):WaitForChild("BridgeNet2"):WaitForChild("dataRemoteEvent")

local autoFarmActive = false
local defeatedEnemies = {}

local function isTargetDefeated(target)
    local healthUI = target:FindFirstChild("HealthBar")
    if healthUI and healthUI:FindFirstChild("Main") and healthUI.Main:FindFirstChild("Bar") then
        local healthText = healthUI.Main.Bar:FindFirstChild("Amount")
        if healthText and healthText:IsA("TextLabel") and healthText.ContentText == "0 HP" then
            return true
        end
    end
    return false
end


local function triggerPetVisibility()
    local arguments = {
        [1] = {
            [1] = {
                ["Event"] = "ShowPets"
            },
            [2] = "\t"
        }
    }
    game:GetService("ReplicatedStorage"):WaitForChild("BridgeNet2"):WaitForChild("dataRemoteEvent"):FireServer(unpack(
        arguments))
end


-- // Info Tab // --

Tabs.Info:AddParagraph({
    Title = "🎉 Welcome to ByboScripts!",
})

Tabs.Info:AddButton({
    Title = "Copy Discord Link",
    Description = "Copies the Discord invite link to clipboard",
    Callback = function()
        setclipboard("https://discord.gg/6sdNs2xKzx")
        Fluent:Notify({
            Title = "Copied!",
            Content = "The Discord link has been copied to your clipboard.",
            Duration = 3
        })
    end
})



-- // Main Tab // --

Tabs.Main:AddToggle("AutoDestroy", {
    Title = "Arise Or Destroy",
    Description = "Off = Auto Destroy | On = Auto Arise",
    Default = ConfigSystem.CurrentConfig.MainAutoArise or false, -- Keep only this Default
    Callback = function(state)
        if state then
            -- Arise Mode

            ConfigSystem.CurrentConfig.MainAutoArise = true
            ConfigSystem.CurrentConfig.MainAutoDestroy = false
            ConfigSystem.SaveConfig()
            task.spawn(fireArise)
        else
            -- Destroy Mode
            ConfigSystem.CurrentConfig.MainAutoArise = false
            ConfigSystem.CurrentConfig.MainAutoDestroy = true
            ConfigSystem.SaveConfig()
            task.spawn(fireDestroy)
        end
    end
})

function startAutoDestroy()
    
    if not ConfigSystem.CurrentConfig.MainAutoArise then
        fireDestroy()
    else
        fireArise()
    end
end
startAutoDestroy()



Tabs.Main:AddToggle("AutoAttackToggle", {
    Title = "Auto Attack Mobs",
    Default = ConfigSystem.CurrentConfig.AutoAttackEnabled or false,
    Callback = function(state)
        autoAttackEnabled = state
        ConfigSystem.CurrentConfig.AutoAttackEnabled = state
        ConfigSystem.SaveConfig()

        if state then
            task.spawn(function()
                while autoAttackEnabled do
                    local targetEnemy

                    if ConfigSystem.CurrentConfig.FarmSelectedMob and selectedMobName ~= "" then
                        targetEnemy = getNearestSelectedEnemy()
                    else
                        targetEnemy = getNearestEnemy()
                    end

                    if targetEnemy then
                        local args = {
                            [1] = {
                                [1] = {
                                    ["Event"] = "PunchAttack",
                                    ["Enemy"] = targetEnemy.Name
                                },
                                [2] = "\4"
                            }
                        }
                        remote:FireServer(unpack(args))
                    end
                    task.wait(attackCooldown)
                end
            end)
        end
    end
})

Tabs.Main:AddToggle("GamepassShadowFarm", {
    Title = "Gamepass Shadow farm",
    Default = ConfigSystem.CurrentConfig.GamepassShadowFarm or false,
    Callback = function(state)
        ConfigSystem.CurrentConfig.GamepassShadowFarm = state -- Save to CurrentConfig
        ConfigSystem.SaveConfig()
        local attackatri = game:GetService("Players").LocalPlayer.Settings
        local atri = attackatri:GetAttribute("AutoAttack")

        if state then
            -- Enable the feature
            if atri == false then
                attackatri:SetAttribute("AutoAttack", true)
            end
        else
            -- Disable the feature
            attackatri:SetAttribute("AutoAttack", false)
        end
    end
})

Tabs.Main:AddParagraph({
    Title = " ",
    Size = UDim2.new(0, 150, 0, 0),
})

local AntiAfkToggle = Tabs.Main:AddToggle("AntiAfk", {
    Title = "Anti AFK",
    Description = "Prevents you from being kicked for being idle",
    Default = ConfigSystem.CurrentConfig.AntiAfk or false,
    Callback = function(enabled)
        ConfigSystem.CurrentConfig.AntiAfk = enabled
        ConfigSystem.SaveConfig()
        if enabled then
            if not antiAfkConnection then
                antiAfkConnection = player.Idled:Connect(function()
                    VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                    task.wait(1)
                    VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                end)
            end
        else
            if antiAfkConnection then
                antiAfkConnection:Disconnect()
                antiAfkConnection = nil
            end
        end
    end
})


-- // Dungeon Tab // --

-- Restore the Auto farm Dungeon tab
Tabs.Dungeon:AddToggle("TeleportMobs", {
    Title = "Auto Farm Dungeon",
    Default = ConfigSystem.CurrentConfig.AutoFarmDungeon or false,
    Callback = function(state)
        teleportEnabled = state
        ConfigSystem.CurrentConfig.AutoFarmDungeon = state
        ConfigSystem.SaveConfig()
        if state then
            ConfigSystem.CurrentConfig.GamepassShadowFarm = state -- Enable Gamepass Shadow Farm
            ConfigSystem.CurrentConfig.AutoAttackEnabled = state -- Enable Auto Attack Mobs
            task.spawn(teleportDungeon)
        end
    end
})



-- // Settings Tab // --

Tabs.Settings:AddParagraph({
    Title = "Auto Configuration",
    Content = "Your settings are being auto-saved under your character name: " .. playerName
})

Tabs.Settings:AddParagraph({
    Title = "Shortcut Keys",
    Content = "Press LeftControl to toggle the UI on/off"
})


-- Add a button to delete the current config
Tabs.Settings:AddButton({
    Title = "Save Current Config",
    Description = "Save your current settings to a config file",
    Callback = function()
        ConfigSystem.SaveConfig()
        Fluent:Notify({
            Title = "Config Saved",
            Content = "Your current settings have been saved successfully",
            Duration = 3
        })
    end
})

-- Add a button to delete the current config
Tabs.Settings:AddButton({
    Title = "Delete Current Config",
    Description = "Reset all settings to default",
    Callback = function()
        SaveManager:Delete("AutoSave_" .. playerName)
        Fluent:Notify({
            Title = "Config Deleted",
            Content = "All settings have been reset to default",
            Duration = 3
        })
    end
})

Tabs.Settings:AddParagraph({
    Title = " ",
    Size = UDim2.new(0, 150, 0, 0),
})

Tabs.Settings:AddButton({
    Title = "Server Hop",
    Description = "Switches to a different server",
    Callback = function()
        local PlaceID = game.PlaceId
        local AllIDs = {}
        local foundAnything = ""
        local actualHour = os.date("!*t").hour
        local File = pcall(function()
            AllIDs = game:GetService('HttpService'):JSONDecode(readfile("NotSameServers.json"))
        end)
        if not File then
            table.insert(AllIDs, actualHour)
            writefile("NotSameServers.json", game:GetService('HttpService'):JSONEncode(AllIDs))
        end
        local function TPReturner()
            local Site
            if foundAnything == "" then
                Site = game.HttpService:JSONDecode(game:HttpGet(
                    'https://games.roblox.com/v1/games/' .. PlaceID .. '/servers/Public?sortOrder=Asc&limit=100'))
            else
                Site = game.HttpService:JSONDecode(game:HttpGet(
                    'https://games.roblox.com/v1/games/' .. PlaceID .. '/servers/Public?sortOrder=Asc&limit=100&cursor=' ..
                        foundAnything))
            end
            for _, v in pairs(Site.data) do
                if tonumber(v.maxPlayers) > tonumber(v.playing) then
                    local ID = tostring(v.id)
                    local isNewServer = true
                    for _, existing in pairs(AllIDs) do
                        if ID == tostring(existing) then
                            isNewServer = false
                            break
                        end
                    end
                    if isNewServer then
                        table.insert(AllIDs, ID)
                        writefile("NotSameServers.json", game:GetService('HttpService'):JSONEncode(AllIDs))
                        game:GetService("TeleportService")
                            :TeleportToPlaceInstance(PlaceID, ID, game.Players.LocalPlayer)
                        return
                    end
                end
            end
        end
        TPReturner()
    end
})