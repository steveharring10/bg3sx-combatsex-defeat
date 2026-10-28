Ext.Events.NetMessage:Subscribe(function(e)
    if (e.Channel == "CombatSex_NPCStrip") then
        local strip = Ext.Json.Parse(e.Payload)
        local entity = Ext.Entity.Get(strip.target)
        Mods.BG3SX.Visual.removeVisualSetBySlot(entity, strip.remove)
    end
    -- if (e.Channel == "CombatSex_NPCUpdate") then
    --     local dress = Ext.Json.Parse(e.Payload)
    --     Ext.Resource.Get(dress.resource,"CharacterVisual").VisualSet.Slots = dress.dressed
    -- end
end)
