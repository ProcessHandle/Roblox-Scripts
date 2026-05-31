getgenv().POKEMON_CONFIG = {
    PokemonName = "Squirtle",
    CheckItem = true,
    RequiredItem = "Tintifier",
    CheckReskin = false
}

local SpawnFunc = nil

for _, func in pairs(getrenv()._G) do
    if type(func) == "function" then
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
    
    local oldEnv = getfenv()
    setfenv(1, setmetatable({ script = control }, { __index = getrenv() }))
    
    local spawnedMon = nil
    
    repeat
        local results = {SpawnFunc(getgenv().POKEMON_CONFIG.PokemonName, client.CreaturePIayer, 80, true)}
        spawnedMon = results[1]
        
        print("Spawned:", spawnedMon)
        
        local requirementsMet = true
        
        if getgenv().POKEMON_CONFIG.CheckItem then
            if spawnedMon:FindFirstChild("HeldItem") then
                local heldItem = spawnedMon.HeldItem.Value
                if heldItem == getgenv().POKEMON_CONFIG.RequiredItem then
                    print("Correct item:", heldItem)
                else
                    print("Wrong item:", heldItem, "(Expected:", getgenv().POKEMON_CONFIG.RequiredItem, ")")
                    requirementsMet = false
                end
            else
                print("No HeldItem found")
                requirementsMet = false
            end
        else
            print("Item check skipped")
        end
        
        if requirementsMet and getgenv().POKEMON_CONFIG.CheckReskin then
            if spawnedMon:FindFirstChild("Form") then
                print("Has reskin!")
            else
                print("No reskin found for " .. getgenv().POKEMON_CONFIG.PokemonName)
                requirementsMet = false
            end
        elseif not getgenv().POKEMON_CONFIG.CheckReskin and requirementsMet then
            print("Reskin check skipped")
        end
        
        if requirementsMet then
            print("All requirements met! Keeping Pokemon.")
            break
        else
            print("Requirements not met - releasing...")
            game:GetService("Teams").LocationEvent.PCFunctions.Releaserz:FireServer(spawnedMon)
        end
        
        wait()
        
    until spawnedMon and requirementsMet
    
    setfenv(1, oldEnv)
    
    if spawnedMon and requirementsMet then
        print("Successfully obtained:", getgenv().POKEMON_CONFIG.PokemonName)
        if getgenv().POKEMON_CONFIG.CheckItem then
            print("Item:", spawnedMon.HeldItem.Value)
        end
        if getgenv().POKEMON_CONFIG.CheckReskin then
            print("Has reskin!")
        end
    end
end