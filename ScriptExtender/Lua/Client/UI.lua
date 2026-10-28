UI = {}
-- CREDIT: MegaMatt8 of the HaarlepUnleashed mod for the scenecontrol hider code
-- BootstrapClient.lua for BG3SXDefeat
-- Handles client-side UI interactions, specifically hiding BG3SX scene control popups

-- Track which scenes are BG3SXDefeat-controlled
local BG3SXDefeatControlledScenes = {}
local BG3SXDefeatControlledEntities = {}

-- Set to true to enable debug logging, false for release
local DEBUG_ENABLED = true

-- Debug helper
local function DebugLog(message)
    if DEBUG_ENABLED then
        _P("[BG3SXDefeat Client] " .. message)
    end
end

DebugLog("Client bootstrap loading...")

-- Create event channel for hiding scene controls
local HideSceneControlEvent = Ext.Net.CreateChannel(ModuleUUID, "HideSceneControl")
local ShowSceneControlEvent = Ext.Net.CreateChannel(ModuleUUID, "ShowSceneControl")

-- Expose globally
if not Mods.BG3SXDefeat then
    Mods.BG3SXDefeat = {}
end
Mods.BG3SXDefeat.HideSceneControlEvent = HideSceneControlEvent
Mods.BG3SXDefeat.ShowSceneControlEvent = ShowSceneControlEvent

-- Function to find and hide scene control for given entities
local function hideSceneControlForEntities(entities, sceneUuid)
    if not entities or #entities == 0 then
        DebugLog("No entities provided")
        return false
    end
    
    -- Mark entities as BG3SXDefeat-controlled
    for _, entityUuid in pairs(entities) do
        BG3SXDefeatControlledEntities[entityUuid] = true
    end
    
    if sceneUuid then
        BG3SXDefeatControlledScenes[sceneUuid] = true
    end
    
    -- Try multiple ways to access the SceneControl
    local activeSceneControls = nil
    
    -- Method 1: Through Mods.BG3SX (if they expose it)
    if Mods.BG3SX and Mods.BG3SX.SceneControl and Mods.BG3SX.SceneControl.ActiveSceneControls then
        activeSceneControls = Mods.BG3SX.SceneControl.ActiveSceneControls
        DebugLog("Found SceneControl via Mods.BG3SX.SceneControl")
    end
    
    -- Method 2: Through global SceneControl (BG3SX may expose it globally)
    if not activeSceneControls and SceneControl and SceneControl.ActiveSceneControls then
        activeSceneControls = SceneControl.ActiveSceneControls
        DebugLog("Found SceneControl via global SceneControl")
    end
    
    -- Method 3: Through global UI (BG3SX's UI global)
    if not activeSceneControls and UI and UI.SceneControl and UI.SceneControl.ActiveSceneControls then
        activeSceneControls = UI.SceneControl.ActiveSceneControls
        DebugLog("Found SceneControl via global UI.SceneControl")
    end
    
    if not activeSceneControls then
        DebugLog("Could not find ActiveSceneControls through any method")
        return false
    end
    
    DebugLog("Found " .. tostring(#activeSceneControls) .. " active scene controls")
    
    local hiddenCount = 0
    
    for _, sceneControl in pairs(activeSceneControls) do
        -- Skip destroyed or invalid scene controls
        if not sceneControl then
            DebugLog("Skipping nil sceneControl")
            goto continue
        end
        
        if sceneControl.IsDestroyed then
            DebugLog("Skipping destroyed sceneControl (IsDestroyed=true)")
            goto continue
        end
        
        -- Check if this sceneControl's window is still valid before processing
        local windowIsValid = false
        pcall(function()
            if sceneControl.Window and sceneControl.Window.Open ~= nil then
                windowIsValid = true
            end
        end)
        
        if not windowIsValid then
            DebugLog("Skipping sceneControl with invalid/destroyed window")
            goto continue
        end
        
        if sceneControl.Scene and sceneControl.Scene.entities then
            -- Check if this scene control matches our entities
            local isOurScene = false
            for _, scEntity in pairs(sceneControl.Scene.entities) do
                for _, ourEntity in pairs(entities) do
                    if scEntity == ourEntity then
                        isOurScene = true
                        DebugLog("Found matching entity: " .. tostring(scEntity))
                        break
                    end
                end
                if isOurScene then break end
            end
            
            if isOurScene then
                DebugLog("Found matching SceneControl, hiding window")
                
                -- Close/hide the window
                local windowSuccess = pcall(function()
                    sceneControl.Window.Open = false
                end)
                
                if windowSuccess then
                    DebugLog("Set Window.Open = false")
                    hiddenCount = hiddenCount + 1
                else
                    DebugLog("Window.Open assignment failed - window may be destroyed")
                    goto continue  -- This sceneControl is invalid, try the next one
                end
                
                -- Hide the reference in scene tab
                pcall(function()
                    if sceneControl.Reference then
                        sceneControl.Reference.Visible = false
                        DebugLog("Set Reference.Visible = false")
                    end
                end)
                
                -- Mark as hidden by BG3SXDefeat
                sceneControl.BG3SXDefeatHidden = true
                
                DebugLog("Scene control hidden successfully")
            end
        end
        ::continue::
    end
    
    if hiddenCount > 0 then
        DebugLog("Successfully hidden " .. hiddenCount .. " scene control(s)")
        return true
    end
    
    DebugLog("No matching SceneControl found in active controls")
    return false
end

-- Handler for HideSceneControl event from server
HideSceneControlEvent:SetHandler(function(payload)
    DebugLog("Received HideSceneControl event")
    
    local sceneUuid = payload.SceneUuid
    local entities = payload.Entities
    
    -- Mark these entities immediately so we can catch the window when it's created
    if entities then
        for _, entityUuid in pairs(entities) do
            BG3SXDefeatControlledEntities[entityUuid] = true
            DebugLog("Marked entity as BG3SXDefeat-controlled: " .. tostring(entityUuid))
        end
    end
    if sceneUuid then
        BG3SXDefeatControlledScenes[sceneUuid] = true
    end
    
    -- Try to hide immediately
    local success = hideSceneControlForEntities(entities, sceneUuid)
    
    -- If not successful, retry with longer delays (window might not exist yet)
    if not success then
        local retryDelays = {100, 200, 400, 800, 1500, 3000}
        
        for i, delay in ipairs(retryDelays) do
            Ext.Timer.WaitFor(delay, function()
                if not BG3SXDefeatControlledEntities[entities[1]] then
                    -- Already handled or cleaned up
                    return
                end
                
                DebugLog("Retry attempt " .. i .. " (delay: " .. delay .. "ms)")
                if hideSceneControlForEntities(entities, sceneUuid) then
                    DebugLog("Successfully hidden on retry " .. i)
                end
            end)
        end
    end
end)

-- Handler for ShowSceneControl event
ShowSceneControlEvent:SetHandler(function(payload)
    DebugLog("Received ShowSceneControl event")
    
    local entities = payload.Entities
    local sceneUuid = payload.SceneUuid
    
    -- Clear from tracked
    if entities then
        for _, entityUuid in pairs(entities) do
            BG3SXDefeatControlledEntities[entityUuid] = nil
        end
    end
    if sceneUuid then
        BG3SXDefeatControlledScenes[sceneUuid] = nil
    end
    
    -- Try to find and show the scene control
    local activeSceneControls = nil
    if Mods.BG3SX and Mods.BG3SX.SceneControl then
        activeSceneControls = Mods.BG3SX.SceneControl.ActiveSceneControls
    elseif SceneControl then
        activeSceneControls = SceneControl.ActiveSceneControls
    elseif UI and UI.SceneControl then
        activeSceneControls = UI.SceneControl.ActiveSceneControls
    end
    
    if not activeSceneControls then return end
    
    for _, sceneControl in pairs(activeSceneControls) do
        if sceneControl.BG3SXDefeatHidden and sceneControl.Scene and sceneControl.Scene.entities then
            local isOurScene = false
            for _, scEntity in pairs(sceneControl.Scene.entities) do
                for _, ourEntity in pairs(entities) do
                    if scEntity == ourEntity then
                        isOurScene = true
                        break
                    end
                end
                if isOurScene then break end
            end
            
            if isOurScene then
                DebugLog("Showing previously hidden SceneControl")
                pcall(function()
                    if sceneControl.Window then
                        sceneControl.Window.Open = true
                    end
                end)
                pcall(function()
                    if sceneControl.Reference then
                        sceneControl.Reference.Visible = true
                    end
                end)
                sceneControl.BG3SXDefeatHidden = false
                break
            end
        end
    end
end)

DebugLog("Client bootstrap loaded successfully")

return UI