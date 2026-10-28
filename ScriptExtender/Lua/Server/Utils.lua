Utils = {}

function Utils.MCMGet(settingID)
    return Mods.BG3MCM.MCMAPI:GetSettingValue(settingID, ModuleUUID)
end

function Utils.Debug(text, debugLevel)
    if debugLevel == nil then
        debugLevel = 1
    end
    if Utils.MCMGet("debug_level") >= debugLevel then
        _P("BG3SXDefeat: " .. text)
    end
end

function Utils.tableContains(tbl, value)
    if not tbl then return false end
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

function Utils.Error(text)
    Ext.Utils.PrintError("BG3SXDefeat: [ERROR] " .. text)
end

function Utils.Warn(text)
    Ext.Utils.PrintWarning("BG3SXDefeat: [WARN] " .. text)
end

function Utils.PrintTable(tbl, indent)
    if Utils.MCMGet("debug_level") == 0 then
        return
    end
    if not indent then indent = 0 end

    for k, v in pairs(tbl) do
        local formatting = string.rep("  ", indent) .. k .. ": "

        if type(v) == "table" then
            print(formatting)
            Utils.PrintTable(v, indent+1)
        else
            print(formatting .. tostring(v))
        end
    end
end

-- Character utility functions
function Utils.GetCharacterGender(character)
    if not character then
        return nil
    end
    
    local success, entity = pcall(Ext.Entity.Get, character)
    if not success or not entity then
        local gender = Osi.GetGender(character, 0)
        return gender
    end
    
    if entity.BodyType then
        local bodyType = entity.BodyType.BodyType
        if bodyType == 1 then
            return "Female"
        elseif bodyType == 0 then
            return "Male"
        end
    end
    
    local gender = Osi.GetGender(character, 0)
    return gender
end

return Utils