-- CREDIT: MegaMatt8 of the HaarlepUnleashed mod for the scenecontrol hider and scene setup code
SceneManager = {}

-- Create event channels for client communication (hide/show scene control)
local HideSceneControlEvent = Ext.Net.CreateChannel(ModuleUUID, "HideSceneControl")
local ShowSceneControlEvent = Ext.Net.CreateChannel(ModuleUUID, "ShowSceneControl")

-- Expose events globally
if not Mods.BG3SXDefeat then
    Mods.BG3SXDefeat = {}
end
Mods.BG3SXDefeat.HideSceneControlEvent = HideSceneControlEvent
Mods.BG3SXDefeat.ShowSceneControlEvent = ShowSceneControlEvent

-- Get a random paired animation from BG3SX
function SceneManager.GetRandomAnimation(bottomGender, topGender)
    Utils.Debug("Looking for animation - topGender: " .. tostring(bottomGender) .. ", bottomGender: " .. tostring(topGender))
    
    -- Determine scene type
    local sceneType
    if bottomGender == topGender then
        sceneType = (bottomGender == "Male") and "Gay" or "Lesbian"
    else
        sceneType = "Straight"
    end
    Utils.Debug("Scene type: " .. sceneType)

    local filterPropAnimations = Utils.MCMGet("filter_prop_animations")

    -- block solo and sfw animations
    local blacklist_tags = {
        ["SoloV"] = true,
        ["SoloP"] = true,
        ["SFW"] = true
    }

    -- anims where it doesn't make sense for dominant males
    local maleTopBlacklist = {
        ["Fisting"] = true, -- female will be fisting the male
        ["Milking"] = true, -- female milks the male
        ["Facesitting"] = true -- female sits on the top male's face
    }

    -- majority of F/M animations are male dominant, so use a whitelist here (until bg3sx adds DomF, DomM tags)
    local femaleTopWhitelist = {
        ["Fisting"] = true,
        ["Milking"] = true,
        ["Facesitting"] = true,
        ["Squatting Cowgirl"] = true,
        ["Sixty Nine"] = true,
        ["Rusty Trombone"] = true,
        ["Riding St. George"] = true,
        ["Reverse Squat"] = true,
        ["Reverse Cowgirl"] = true,
        ["KneelingHandy"] = true,
        ["Itadakimasu"] = true,
        ["Gamahuche"] = true,
        ["Foot Job"] = true,
        ["EatPussy"] = true,
        ["Cowgirl"] = true,
        ["Convivial Coitus"] = true,
        ["ButtMunch"] = true,
        ["Barstool Blowjob"] = true
    }

    local availableAnims = {}
    
    -- Check if BG3SX Data exists
    if not Mods.BG3SX then
        Utils.Debug("ERROR: Mods.BG3SX not found!")
        return nil, nil
    end
    
    if not Mods.BG3SX.Data then
        Utils.Debug("ERROR: Mods.BG3SX.Data not found!")
        return nil, nil
    end
    
    -- Try Data.Animations (the main animation registry)
    if Mods.BG3SX.Data.Animations then
        Utils.Debug("Found Data.Animations, searching...")
        local animCount = 0
        Utils.Debug("Top: " .. topGender .. " Bottom: " .. bottomGender)
        for modUUID, modAnims in pairs(Mods.BG3SX.Data.Animations) do
            for animName, animData in pairs(modAnims) do
                animCount = animCount + 1

                -- skip anims with blacklisted tags (solo/sfw)
                if animData.Categories then
                    for tag, _ in pairs(blacklist_tags) do
                        if Utils.tableContains(animData.Categories, tag) then
                            Utils.Debug("Skipping animation with blacklisted tag (" .. tag .. "): " .. animName)
                            goto continue
                        end
                    end
                end

                -- skip animations where the female would be dominant over a male top
                if topGender == "Male" and maleTopBlacklist[animName] then
                    Utils.Debug("Skipping male-top blacklisted animation: " .. animName)
                    goto continue
                end

                -- for a female top on a male bottom, only allow animations known to be female dominant
                if topGender == "Female" and bottomGender == "Male" and not femaleTopWhitelist[animName] then
                    Utils.Debug("Skipping animation not whitelisted for female top: " .. animName)
                    goto continue
                end

                -- optionally block animations that require props (MCM setting)
                if filterPropAnimations and animData.Props then
                    Utils.Debug("Skipping propped animation: " .. animName)
                    goto continue
                end

                if animData.Heightmatching then
                    local hm = animData.Heightmatching

                    -- Check for paired animation (has both top and bottom fallbacks)
                    if hm.fallbackTop and hm.fallbackBottom then
                        -- STRICT check: animation must have the specific sceneType in its Categories
                        -- This matches how BG3SX's SceneControl filters animations
                        if animData.Categories and Utils.tableContains(animData.Categories, sceneType) then
                            table.insert(availableAnims, {data = animData, name = animName, mod = modUUID})
                        end
                    end
                end

                ::continue::
            end
        end
        
        Utils.Debug("Scanned " .. animCount .. " total animations, found " .. #availableAnims .. " suitable for " .. sceneType)
    else
        Utils.Warn("Data.Animations not found, trying IntroAnimations...")
    end
    
    -- If no suitable animations found in Data.Animations, try IntroAnimations as fallback
    if #availableAnims == 0 and Mods.BG3SX.Data.IntroAnimations then
        Utils.Warn("Trying IntroAnimations as fallback...")
        
        for modUUID, modAnims in pairs(Mods.BG3SX.Data.IntroAnimations) do
            for animName, animData in pairs(modAnims) do

                -- skip anims with blacklisted tags (solo/sfw)
                if animData.Categories then
                    for tag, _ in pairs(blacklist_tags) do
                        if Utils.tableContains(animData.Categories, tag) then
                            Utils.Debug("Skipping intro animation with blacklisted tag (" .. tag .. "): " .. animName)
                            goto continue
                        end
                    end
                end

                -- skip animations where the female would be dominant over a male top
                if topGender == "Male" and maleTopBlacklist[animName] then
                    Utils.Debug("Skipping male-top blacklisted intro animation: " .. animName)
                    goto continue
                end

                -- for a female top on a male bottom, only allow animations known to be female dominant
                if topGender == "Female" and bottomGender == "Male" and not femaleTopWhitelist[animName] then
                    Utils.Debug("Skipping intro animation not whitelisted for female top: " .. animName)
                    goto continue
                end

                -- optionally block animations that require props (MCM setting)
                if filterPropAnimations and animData.Props then
                    Utils.Debug("Skipping propped intro animation: " .. animName)
                    goto continue
                end

                if animData.Heightmatching then
                    local hm = animData.Heightmatching
                    if hm.fallbackTop and hm.fallbackBottom then

                        if animData.Categories and Utils.tableContains(animData.Categories, sceneType) then
                            table.insert(availableAnims, {data = animData, name = animName, mod = modUUID})
                            Utils.Debug("Found IntroAnimation: " .. animName)
                        end
                    end
                end

                ::continue::
            end
        end
    end

    -- Select random animation
    if #availableAnims > 0 then
        local selected = availableAnims[math.random(1, #availableAnims)]
        Utils.Debug("Selected animation: " .. selected.name)
        return selected.data, selected.name
    end
    
    Utils.Debug("No suitable animations found!")
    return nil, nil
end

function SceneManager.GetRandomSoloAnimation(targetGender)
    Utils.Debug("Looking for solo animation - targetGender: " .. tostring(targetGender))
    
    -- Determine scene type
    local sceneType = "SoloV"
    if targetGender == "Male" then
        sceneType = "SoloP"
    end
    Utils.Debug("Scene type: " .. sceneType)
    
    local availableAnims = {}
    
    -- Check if BG3SX Data exists
    if not Mods.BG3SX then
        Utils.Debug("ERROR: Mods.BG3SX not found!")
        return nil, nil
    end
    
    if not Mods.BG3SX.Data then
        Utils.Debug("ERROR: Mods.BG3SX.Data not found!")
        return nil, nil
    end
    
    -- Try Data.Animations (the main animation registry)
    if Mods.BG3SX.Data.Animations then
        Utils.Debug("Found Data.Animations, searching...")
        local animCount = 0
        
        for modUUID, modAnims in pairs(Mods.BG3SX.Data.Animations) do
            for animName, animData in pairs(modAnims) do
                animCount = animCount + 1
                
                if animData.Categories and Utils.tableContains(animData.Categories, sceneType) then
                    table.insert(availableAnims, {data = animData, name = animName, mod = modUUID})
                end
            end
        end
        
        Utils.Debug("Scanned " .. animCount .. " total animations, found " .. #availableAnims .. " suitable for " .. sceneType)
    else
        Utils.Debug("Data.Animations not found, trying IntroAnimations...")
    end
    
    -- If no suitable animations found in Data.Animations, try IntroAnimations as fallback
    if #availableAnims == 0 and Mods.BG3SX.Data.IntroAnimations then
        Utils.Debug("Trying IntroAnimations as fallback...")
        
        for modUUID, modAnims in pairs(Mods.BG3SX.Data.Animations) do
            for animName, animData in pairs(modAnims) do

                if animData.Categories and Utils.tableContains(animData.Categories, sceneType) then
                    table.insert(availableAnims, {data = animData, name = animName, mod = modUUID})
                    Utils.Debug("Found IntroAnimation: " .. animName)
                end
            end
        end
    end

    -- Select random animation
    if #availableAnims > 0 then
        local selected = availableAnims[math.random(1, #availableAnims)]
        Utils.Debug("Selected animation: " .. selected.name)
        return selected.data, selected.name
    end
    
    Utils.Debug("No suitable animations found!")
    return nil, nil
end

function SceneManager.CreateBG3SXSoloScene(targetCharacter)
    Utils.Debug("Creating BG3SX Scene")
    Utils.Debug("Target character: " .. tostring(targetCharacter))
    -- Verify target exists
    if not targetCharacter or not Osi.Exists(targetCharacter) then
        Utils.Error("Creating BG3SX Scene failed - Target character doesn't exist")
        return false
    end

    -- Check BG3SX availability
    if not Mods.BG3SX then
        Utils.Error("Creating BG3SX Scene failed - BG3SX mod not loaded")
        return false
    end

    if not Mods.BG3SX.Scene then
        Utils.Error("Creating BG3SX Scene failed - BG3SX.Scene not available")
        return false
    end

    -- Check if target is already in a BG3SX scene (Let other bg3sx mods take precedence.))
    local existingScene = Mods.BG3SX.Scene.FindSceneByEntity(targetCharacter)
    if existingScene then
        Utils.Error("Creating BG3SX Scene failed - Target already in BG3SX scene (UUID: " .. tostring(existingScene.Uuid) .. ").")
        return false
    end

    -- Check whitelist
    if Mods.BG3SX.Entity and Mods.BG3SX.Entity.IsWhitelisted then
        local whitelisted = Mods.BG3SX.Entity:IsWhitelisted(targetCharacter)
        Utils.Debug("Target whitelisted: " .. tostring(whitelisted))
        if not whitelisted then
            Utils.Error("Creating BG3SX Scene failed - Target is not WhiteListed")
            return false
        end
    end

    local targetGender = Utils.GetCharacterGender(targetCharacter)
    Utils.Debug("Target gender: " .. tostring(targetGender))


    local animationPreference = "All Animations"

    local animData, animName = SceneManager.GetRandomSoloAnimation(targetGender)
        
    if not animData then
        Utils.Error("Creating BG3SX Scene failed - No animation found")
        return false
    end
    --Osi.ApplyStatus(casterCharacter, "BG3SXDEFEAT_SEX_TECHNICAL",)
    -- Assigning genitals needed for existing NPCs? Hmm.

    Ext.Timer.WaitFor(550, function()
        DebugLog("Creating BG3SX scene...")
        if Mods.BG3SX.Entity and Mods.BG3SX.Entity.ClearActionQueue then
            Mods.BG3SX.Entity:ClearActionQueue(targetCharacter)
            Utils.Debug("Cleared action queues")
        end

        -- Create scene
        local success, err = pcall(function()
            local scene = Mods.BG3SX.Scene:New({
                Type = "NSFW",
                Entities = {targetCharacter},
                Animation = animData,
                Fade = 0
            })
            
            Utils.Debug("Scene:New completed, calling Init...")
            scene:Init()
            
            Utils.Debug("Init completed, calling PlayAnimation...")
            scene:PlayAnimation(animData)
            
            Utils.Debug("=== Scene created successfully! ===")
            --Osi.ApplyStatus(targetCharacter, "TRAPPED_BASIC", 10, 10)
            -- Our own AI overrides the enemy
        end)
        
        if not success then
            Utils.Error("ERROR creating scene: " .. tostring(err))
        end
    end)

    return true
end


function SceneManager.CreateBG3SXScene(targetCharacter, casterCharacter)
    Utils.Debug("Creating BG3SX Scene")
    Utils.Debug("Target character: " .. tostring(targetCharacter))
    -- Verify target exists
    if not targetCharacter or not Osi.Exists(targetCharacter) then
        Utils.Error("Creating BG3SX Scene failed - Target character doesn't exist")
        return false
    end

    -- Check BG3SX availability
    if not Mods.BG3SX then
        Utils.Error("Creating BG3SX Scene failed - BG3SX mod not loaded")
        return false
    end

    if not Mods.BG3SX.Scene then
        Utils.Error("Creating BG3SX Scene failed - BG3SX.Scene not available")
        return false
    end

    -- Check if target is already in a BG3SX scene (Let other bg3sx mods take precedence.))
    local existingScene = Mods.BG3SX.Scene.FindSceneByEntity(targetCharacter)
    if existingScene then
        Utils.Error("Creating BG3SX Scene failed - Target already in BG3SX scene (UUID: " .. tostring(existingScene.Uuid) .. ").")
        return false
    end

    -- Check whitelist
    if Utils.MCMGet("whitelist_enabled") then
        if Mods.BG3SX.Entity and Mods.BG3SX.Entity.IsWhitelisted then
            local whitelisted = Mods.BG3SX.Entity:IsWhitelisted(targetCharacter)
            Utils.Debug("Target whitelisted: " .. tostring(whitelisted))
            if not whitelisted then
                Utils.Error("Creating BG3SX Scene failed - Target is not WhiteListed")
                return false
            end
        end
    end

    local targetGender = Utils.GetCharacterGender(targetCharacter)
    Utils.Debug("Target gender: " .. tostring(targetGender))


    local animationPreference = "All Animations"
    local casterGender = Utils.GetCharacterGender(casterCharacter)
    Utils.Debug("Caster gender: " .. casterGender)
    local animData, animName = SceneManager.GetRandomAnimation(targetGender, casterGender)
        
    if not animData then
        Utils.Error("Creating BG3SX Scene failed - No animation found")
        return false
    end
    --Osi.ApplyStatus(casterCharacter, "BG3SXDEFEAT_SEX_TECHNICAL",)
    -- Assigning genitals needed for existing NPCs? Hmm.

    Ext.Timer.WaitFor(550, function()
        DebugLog("Creating BG3SX scene...")
        if Mods.BG3SX.Entity and Mods.BG3SX.Entity.ClearActionQueue then
            Mods.BG3SX.Entity:ClearActionQueue(targetCharacter)
            Mods.BG3SX.Entity:ClearActionQueue(casterCharacter)
            Utils.Debug("Cleared action queues")
        end

        local swaps = { -- for animations that improperly swap the top and bottom order
            ["Facesitting"] = true,
        }
    
        local entities
        if targetGender == "Male" then
            entities = {targetCharacter, casterCharacter}
        else
            entities = {casterCharacter, targetCharacter}
        end

        -- gay animations have top/bottom reversed for some reason
        if swaps[animData.Name] or Utils.tableContains(animData.Categories, "Gay") then
            Utils.Debug("Swapping Entity order for animation: " .. tostring(animData.Name))
            local oldTop = entities[1]
            entities[1] = entities[2]
            entities[2] = oldTop
        end
        Utils.Debug("Entity order: " .. entities[1] .. " (top), " .. entities[2] .. " (bottom)")

        -- Create scene
        local success, err = pcall(function()
            local scene = Mods.BG3SX.Scene:New({
                Type = "NSFW",
                Entities = entities,
                Animation = animData,
                Fade = 0
            })
            
            Utils.Debug("Scene:New completed, calling Init...")
            scene:Init()
            
            Utils.Debug("Init completed, calling PlayAnimation...")
            scene:PlayAnimation(animData)
            
            Utils.Debug("=== Scene created successfully! ===")
            --Osi.ApplyStatus(targetCharacter, "TRAPPED_BASIC", 10, 10)
            -- Our own AI overrides the enemy
        end)
        
        if not success then
            Utils.Error("ERROR creating scene: " .. tostring(err))
        end
    end)

    return true
end

function SceneManager.ChangeSceneAnimationRandomly(topCharacter)
    local existingScene = Mods.BG3SX.Scene.FindSceneByEntity(topCharacter)
    if not existingScene then
        Utils.Error("ChangeSceneAnimation Failed - Target ( " .. tostring(topCharacter) .. " ) is not in a scene.")
        return false
    end

    local bottomCharacter
    for _,character in pairs(existingScene.entities) do

        if character ~= topCharacter then
            bottomCharacter = character
        end
    end

    if bottomCharacter == nil then
        Utils.Error("ChangeSceneAnimation Failed - Could not find a partner.")
        return false
    end
    Utils.Debug("Found pairing: " ..tostring(topCharacter) .. " " ..tostring(bottomCharacter))
    local topGender = Utils.GetCharacterGender(topCharacter)
    local bottomGender = Utils.GetCharacterGender(bottomCharacter)
    Utils.Debug("Pairing Genders: " ..tostring(topGender) .. " " ..tostring(bottomGender))
    local animData, animName = SceneManager.GetRandomAnimation(bottomGender, topGender)

    if not animData then
        Utils.Error("ChangeSceneAnimation failed - No animation found")
        return false
    end

    Utils.Debug("Successfully fetched a new animation: " .. animName)
    existingScene:PlayAnimation(animData)
    return true
end

function SceneManager.DestroyCharacterScene(targetCharacter)
    local ongoingScene = Mods.BG3SX.Scene.FindSceneByEntity(targetCharacter)
    if not ongoingScene then
        Utils.Warn("DestroyCharacterScene Failed - Target ( " .. tostring(targetCharacter) .. " ) is not in a scene.")
        return false
    end 

    pcall(function()
        ongoingScene:Destroy()
    end)
    return true
end

function SceneManager.Realign(targetCharacter)
    local ongoingScene = Mods.BG3SX.Scene.FindSceneByEntity(targetCharacter)
    if not ongoingScene then
        Utils.Error("RealignAnimation Failed - Target ( " .. tostring(targetCharacter) .. " ) is not in a scene.")
        return false
    end
    local doRelocate = false
    local distanceThreshold = 2.5 -- characters should be standing on top of eachother

    -- Compare each pair of scene characters. If any two are too far apart,
    -- flag the scene for relocation before re-aligning.
    for i = 1, #ongoingScene.entities do
        for j = i + 1, #ongoingScene.entities do
            local charA = ongoingScene.entities[i]
            local charB = ongoingScene.entities[j]
            if Osi.Exists(charA) and Osi.Exists(charB) then
                local distance = Osi.GetDistanceTo(charA, charB)
                Utils.Warn("Realign: distance between " .. tostring(charA) .. " and " .. tostring(charB) .. " is " .. tostring(distance))
                if distance > distanceThreshold then
                    doRelocate = true
                end
            end
        end
    end

    Utils.Warn("Realign: doRelocate = " .. tostring(doRelocate))

    pcall(function()
        ongoingScene:RotateScene(ongoingScene.rootPosition)
        if doRelocate then
            ongoingScene:MoveSceneToLocation(ongoingScene.rootPosition)
        end
    end)
    Utils.Debug("Successfully re-aligned the scene")
    return true
end

function SceneManager.Reset(targetCharacter)
    local ongoingScene = Mods.BG3SX.Scene.FindSceneByEntity(targetCharacter)
    if not ongoingScene then
        Utils.Error("ResetAnimation Failed - Target ( " .. tostring(targetCharacter) .. " ) is not in a scene.")
        return false
    end
    pcall(function()
        ongoingScene:ResetAnimation(targetCharacter)
    end)
    Utils.Debug("Successfully resetted the scene")
    return true
end

function SceneManager.onSceneCreated(e)
    Utils.Debug("Scene created")
    local scene = e[1]
    if not scene or not scene.entities then return end
    
    -- Check if Defeat scene

    local sexCaptor = Osi.GetVarFixedString(scene.entities[1], "AD_CurrentCaptor")
    if sexCaptor == nil or sexCaptor == "" then
        sexCaptor = Osi.GetVarFixedString(scene.entities[2], "AD_CurrentCaptor")
    end

    if sexCaptor == nil or sexCaptor == "" then
        return false
    end
    
    Utils.Debug("Defeat scene detected in SceneCreated event")
    -- Hide/close the BG3SX scene control popup for BG3SXDefeat scenes
    -- The SceneControl is created on client side via Event.NewScene handler
    -- We need to broadcast to clients to hide/close it

    Ext.Timer.WaitFor(200, function()
        Utils.Debug("Broadcasting HideSceneControl event for BG3SXDefeat scene")
        HideSceneControlEvent:Broadcast({
            SceneUuid = scene.Uuid,
            Entities = scene.entities
        })
    end)
end

function SceneManager.onSceneDestroyed(e)

end
