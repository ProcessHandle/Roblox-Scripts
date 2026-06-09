local SpawnFunc = nil

for _, func in pairs(getrenv()._G) do
    if type(func) == "function" then
        local success, consts = pcall(getconstants, func)
        if success and consts then
            for _, c in pairs(consts) do
                if type(c) == "string" and c:find("badapple321") then -- Grab the spawn function right from this stupid 'password' thats in plaintext loool. Gotta love constants..
                    SpawnFunc = func
                    break
                end
            end
        end
    end
    if SpawnFunc then break end
end

if not SpawnFunc then
    for _, func in ipairs(getgc(true)) do
        if type(func) == "function" and islclosure(func) then
            local success, consts = pcall(getconstants, func)
            if success and consts then
                for _, c in pairs(consts) do
                    if type(c) == "string" and c:find("badapple321") then
                        SpawnFunc = func
                        break
                    end
                end
            end
        end
        if SpawnFunc then break end
    end
end

print(SpawnFunc and "Spawn function found!" or "Spawn function not found!")

if SpawnFunc then
    local client = game:GetService("Players").LocalPlayer
    local control = client.PlayerScripts:FindFirstChild("Control Script")

    local CONFIG = getgenv().POKEMON_CONFIG
    
    local function dprint(...)
        if CONFIG.Debug then
            print(...)
        end
    end

    local success, err = pcall(function()
        local oldEnv = getfenv(1)
        setfenv(1, setmetatable({ script = control }, { __index = getrenv() }))

        local spawnedMon = nil

        repeat
            local requirementsMet = true

            local results = {SpawnFunc(CONFIG.PokemonName, client.CreaturePIayer, CONFIG.PokemonLevel, true)}
            spawnedMon = results[1]
            dprint("Spawned:", spawnedMon)

            if CONFIG.CheckItem then
                local heldItemObj = spawnedMon:FindFirstChild("HeldItem")
                if heldItemObj then
                    local heldItem = heldItemObj.Value
                    if heldItem == CONFIG.ItemToFind then
                        dprint("Correct item:", heldItem)
                    else
                        dprint("Wrong item:", heldItem, "(Expected:", CONFIG.ItemToFind .. ")")
                        requirementsMet = false
                    end
                else
                    dprint("No HeldItem found")
                    requirementsMet = false
                end
            else
                dprint("Item check skipped")
            end

            if CONFIG.CheckReskin then
                if spawnedMon:FindFirstChild("Form") then
                    dprint("Has reskin!")
                else
                    dprint("No reskin found for " .. CONFIG.PokemonName)
                    requirementsMet = false
                end
            else
                dprint("Reskin check skipped")
            end

            if CONFIG.CheckSecretShiny then
                local secretShiny = spawnedMon:FindFirstChild("SecretShiny")
                if secretShiny and secretShiny:IsA("BoolValue") and secretShiny.Value == true then
                    dprint("Is Secret Shiny!")
                else
                    dprint("Not Secret Shiny")
                    requirementsMet = false
                end
            else
                dprint("Secret Shiny check skipped")
            end

            if requirementsMet then
                print("Successfully obtained:", CONFIG.PokemonName, "| Level:", CONFIG.PokemonLevel)
                if CONFIG.CheckItem then
                    print("Item:", spawnedMon.HeldItem.Value)
                end
                if CONFIG.CheckReskin then
                    print("Has reskin!")
                end
                if CONFIG.CheckSecretShiny then
                    print("Is Secret Shiny!")
                end
                break
            else
                dprint("Requirements not met - releasing...")
                game:GetService("Teams").LocationEvent.PCFunctions.Releaserz:FireServer(spawnedMon)
            end

            task.wait(0.09)

        until false

        setfenv(1, oldEnv)
    end)

    if not success then
        warn("Error occurred: " .. tostring(err))
    end
end
