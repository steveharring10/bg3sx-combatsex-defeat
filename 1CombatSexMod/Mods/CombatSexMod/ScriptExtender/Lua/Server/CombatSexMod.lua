PersistentVars = {
    ["Pairings"] = {},               -- Participants in an assault scene
    ["OriginalTemplates"] = {},      -- NPCs' original clothes
}

-- Get the sex of a character for genital handling
function GetSex(character)
    local entity = Ext.Entity.Get(character)
    -- If character with genitals
    if entity.Tag then
        local tags = entity.Tag.Tags
        for _, tag in pairs(tags) do
            if tag == "a0738fdf-ca0c-446f-a11d-6211ecac3291" then
                return "Female"
            elseif tag == "d27831df-2891-42e4-b615-ae555404918b" then
                return "Male"
            end
        end
    end
    -- If NPC (assume 'Other' gender is exclusive to players)
    return Osi.GetGender(character, 0)
end

-- Remove equipment from a player or companion
function Unequip(character, slots)
    local item
    for _, slot in pairs(slots) do
        item = Osi.GetEquippedItem(character, slot)
        if item then
            Osi.Unequip(character, item)
        end
    end
end

-- Gives passives and spells to player characters
function Setup()
    local party = Osi.DB_PartyMembers:Get(nil)
    local karlach = false
    for _, member in pairs(party) do
        -- Is Karlach in party
        if (string.sub(member[1], -36) == "2c76687d-93a2-477b-8b18-8a14b549304c") then
            karlach = true
        end
        -- Add the assault immunity passive
        if Mods.BG3SX.Entity:IsPlayable(member[1]) then
            Osi.AddPassive(member[1], "CombatSex_Unassailable")
        end
        -- Add the assault spell
        if Mods.BG3SX.Entity:IsWhitelisted(member[1]) and Mods.BG3SX.Entity:IsPlayable(member[1]) then
            Osi.AddSpell(member[1], "CombatSex_Assault")
            Osi.AddSpell(member[1], "CombatSex_Container")
        end
    end
    -- Handle Karlach pre-engine repair
    if karlach then
        if (Osi.HasPassive("2c76687d-93a2-477b-8b18-8a14b549304c", "CombatSex_KarlachEngine") == 1) or (Mods.BG3MCM and Mods.BG3MCM.MCMAPI:GetSettingValue("karlachEngine", ModuleUUID)) then
            Osi.RemovePassive("2c76687d-93a2-477b-8b18-8a14b549304c", "CombatSex_Unsexable")
        else
            Osi.AddPassive("2c76687d-93a2-477b-8b18-8a14b549304c", "CombatSex_Unsexable")
        end
    end
end

-- Handles the assault action
function Assault(target, caster)
    local tar = string.sub(target, -36)
    -- Handle stripping/assaulting player (use the BG3SX method to check because it's more readable and it's a required dependency anyway)
    if Mods.BG3SX.Entity:IsPlayable(tar) then
        -- Strip the first layer (not sure if there's a way to check if camp clothing is toggled)
        if Osi.GetEquippedItem(tar, "Breast") or Osi.GetEquippedItem(tar, "VanityBody") then
            Unequip(tar, {"Breast", "VanityBody"})
            -- Strip underwear
        elseif Osi.GetEquippedItem(tar, "Underwear") then
            Osi.Unequip(tar, Osi.GetEquippedItem(tar, "Underwear"))
            -- If no blocking clothes equipped, start assault
        else
            AssaultStart(target, caster)
        end
    elseif Mods.BG3SX.Entity:IsWhitelisted(target) then
        -- Attempts to strip NPC, if they have no blocking clothes, start assault (some NPCs don't wear underwear, seems arbitrary)
        -- Known NPCs with underwear - female Bhaal cultists
        -- Known NPCs without underwear - male Bhaal cultists, Mizora, Volo
        if not StripNPC(tar) then
            -- Apply the stripped status so NPC has a timer for redressing
            Osi.ApplyStatus(tar, "CombatSex_Stripped", -1)
            AssaultStart(target, caster)
        end
    elseif Mods.BG3SX.Entity:IsWhitelisted(target) then
        AssaultStart(target, caster)
    end
end

-- Assault scene start
StoredGenitals = {}
function AssaultStart(target, caster)
    if Mods.BG3SX.Entity:IsWhitelisted(caster) then
        local cas = string.sub(caster, -36)
        local tar = string.sub(target, -36)

        -- determine the animation to use
        local desiredTags = {}
        desiredTags["Orientation"] = GetPairedOrientation({caster, target})
        desiredTags["Position"] = "Oral"
        local blackList = {"SoloP", "SoloV", "Test"}
        if GetSex(caster) == "Male" and math.random(1, 4) > 1 then
            desiredTags["Position"] = "Vaginal"
        end
        local anims = TagLookup(desiredTags, blackList)
        local rand = math.random(#anims)
        local anim = anims[rand]
        local animName = anim.Name or nil
        _D("Selecting animation " .. animName .. " at index: " .. rand .. " of " .. #anims .. " possible animations.")
        if Osi.HasAppliedStatusOfType(target, "DOWNED") == 1 then
            Osi.RemoveStatusesWithType(target, "DOWNED", "NULL_00000000-0000-0000-0000-000000000000")
            Osi.SetHitPoints(target, 1)
        end
        local scene = StartSex({cas, tar}, anim)
        -- Store the pairs so participants remember their partner
        table.insert(CombatSexPairs, {scene = scene, aggressor = cas, victim = tar})
        local length = 1
        if Mods.BG3MCM then
            length = Mods.BG3MCM.MCMAPI:GetSettingValue("durationMulti", ModuleUUID)
        end
        -- Add an additional turn outside of combat so victim has a chance to resist
        local combat = 6 * (1 - Osi.IsInCombat(caster))
        -- Applies the statuses for resist checks
        Osi.ApplyStatus(caster, "CombatSex_Aggressor", (6 * length + combat), 0, target)
        Osi.ApplyStatus(target, "CombatSex_Victim", 6, 0, caster)
        -- prevent redressing during sex
        for _, actor in pairs({caster, target}) do
            if Osi.HasActiveStatus(actor, "CombatSex_Stripped") == 1 then
                Osi.RemoveStatus(actor, "CombatSex_Stripped")
                Osi.ApplyStatus(actor, "CombatSex_Stripped", -1)
            end
        end
    end
end

-- Handles destroying the sex scene
function AssaultEnd(index, pairEntry)
    if Osi.HasActiveStatus(pairEntry.aggressor, "CombatSex_AssaultSuccess") == 0 then
        -- If status was removed by any way other than assault success
        local participants = {pairEntry.aggressor, pairEntry.victim}
        Ext.ModEvents.CombatSexMod.ResistSuccess:Throw(participants)
    end
    Ext.Timer.WaitFor(200, function()
        pairEntry.scene:Destroy()
        -- Remove whichever status didn't cause the scene to end
        Osi.RemoveStatus(pairEntry.aggressor, "CombatSex_Aggressor")
        Osi.RemoveStatus(pairEntry.victim, "CombatSex_Victim")
        Osi.ApplyStatus(pairEntry.aggressor, "CombatSex_PostSex", 6, 0, pairEntry.victim)
        if Osi.HasActiveStatus(pairEntry.aggressor, "CombatSex_AssaultSuccess") == 1 then
            Osi.RemoveStatus(pairEntry.aggressor, "CombatSex_AssaultSuccess")
            Ext.Timer.WaitFor(200, function()
                -- TODO custom downed effect (Be mindful of conflicts with BG3SX Defeat)
                -- Osi.ApplyStatus(pairEntry.victim, "DOWNED", -1)
                -- Osi.ApplyDamage(pairEntry.victim, 999, "Physical", pairEntry.victim)
                Osi.SetHitPoints(pairEntry.victim, 1)
            end)
        end
        for _, actor in pairs({pairEntry.aggressor, pairEntry.victim}) do
            if Osi.HasActiveStatus(actor, "CombatSex_Stripped") == 1 then
                Osi.RemoveStatus(actor, "CombatSex_Stripped")
                Osi.ApplyStatus(actor, "CombatSex_Stripped", 6)
                local entity = Ext.Entity.Get(actor)
                Mods.BG3SX.NPC.GiveGenitals(entity)
            end
        end
        table.remove(CombatSexPairs, index)
    end)
end

-- Handles NPC stripping - a lot of this comes from BG3SX, with alterations to allow stripping one piece at a time
function StripNPC(target)
    local remove = nil
    local entity = Ext.Entity.Get(target)
    local vrID = entity.ServerCharacter.Template.CharacterVisualResourceID
    local visualSet = Ext.Resource.Get(vrID, "CharacterVisual").VisualSet.Slots
    local serializedSlots = {}
    for _, slot in ipairs(visualSet) do
        -- Lua-friendly format (credit BG3SX)
        table.insert(serializedSlots, {Bone = slot.Bone, Slot = slot.Slot, VisualResource = slot.VisualResource})
    end
    -- Store clothes in persistent variable to persist across save, allows us to redress the NPC
    if not PersistentVars.OriginalTemplates[target] then
        PersistentVars.OriginalTemplates[target] = serializedSlots
    end
    local underwear = false
    for _, slot in pairs(serializedSlots) do
        -- Remove body slot first
        if not (slot.VisualResource == "") then
            if slot.Slot == "Body" then
                remove = "Body"
            elseif slot.Slot == "Underwear" then
                -- If no Body slot found, remove Underwear
                if not remove then
                    remove = "Underwear"
                end
                underwear = true
            end
        end
    end
    -- Remove the equipment in the slot
    if remove then
        _D("Removing equipment in " .. remove .. " slot from " .. target)
        -- update the stored clothes
        local clothes = Mods.BG3SX.SexUserVars.GetNPCClothes(entity)
        local removed = Mods.BG3SX.Visual.removeVisualSetBySlot(entity, remove)
        local clothes2
        if not clothes then
            clothes2 = {}
        else
            clothes2 = clothes[1]
        end
        for _, clothing in pairs(removed) do
            table.insert(clothes2, clothing)
        end
        Mods.BG3SX.SexUserVars.SetNPCClothes({clothes2}, entity)

        local payload = {target = target, remove = remove}
        Ext.Net.BroadcastMessage("CombatSex_NPCStrip", Ext.Json.Stringify(payload))

        -- Applies the stripped status for 1 turn, once ended, the NPC will attempt to redres if not in combat
        if Osi.HasActiveStatus(target, "CombatSex_Stripped") == 1 then
            Osi.RemoveStatus(target, "CombatSex_Stripped")
        end
        Osi.ApplyStatus(target, "CombatSex_Stripped", 6)
        -- Gives the NPC genitals (also updates the visuals)
        Mods.BG3SX.NPC.GiveGenitals(entity)
        if underwear then
            Mods.BG3SX.NPC.RemoveGenitals(entity)
        end
        return true
    else
        return false
    end
end

-- Gets the tags of the character's genitals
function GetGenitals(character)
    local tag, tags, exact
    local entity = Ext.Entity.Get(character)
    -- If custom character
    if entity.CharacterCreationAppearance then
        local uuids = entity.CharacterCreationAppearance.Visuals
        for _, uuid in pairs(uuids) do
            tags = Ext.StaticData.Get(uuid, "CharacterCreationAppearanceVisual")
            if tags then
                tag = tags.Tags[1]
                exact = uuid
                if tag == "a0738fdf-ca0c-446f-a11d-6211ecac3291" or tag == "d27831df-2891-42e4-b615-ae555404918b" then -- vulva or penis uuids
                    break
                end
            end
        end
    end
    if not tag then
        -- NPCs don't have genitals stored
        local npcGender = Osi.GetGender(character, 0)
        if npcGender == "Male" then
            tag = "d27831df-2891-42e4-b615-ae555404918b" -- penis uuid
            exact = Mods.BG3SX.Genital.GetFirstBestGenital(entity)
        else
            tag = "a0738fdf-ca0c-446f-a11d-6211ecac3291" -- vulva uuid
            exact = Mods.BG3SX.Genital.GetFirstBestGenital(entity)
        end
    end
    return tag, exact
end

function IsRace(uuid, races)
    local quickTagCheck = Mods.BG3SX.Entity:TryGetEntityValue(uuid, nil, {"ServerRaceTag", "Tags"})
    for _, race in pairs(races) do
        for _, quickTag in pairs(quickTagCheck) do
            if Mods.BG3SX.Data.AllowedTagsAndRaces[race] and (quickTag == Mods.BG3SX.Data.AllowedTagsAndRaces[race].TAG) then
                return true
            end
        end
    end
    return false
end

function StartSex(entities, animData)
    -- Check if entities are whitelisted
    for _, entity in pairs(entities) do
        if not VerifyEntity(entity) then
            return false
        end
    end
    -- Start the scene
    local scene = Mods.BG3SX.Scene:New({
        Type = "NSFW",
        Entities = entities,
        AnimationData = animData
    })
    scene:Init()
    for _, entity in pairs(entities) do
        Osi.SetCanJoinCombat(entity, 1) -- Prevent leaving combat
    end
    scene:PlayAnimation(scene.AnimationData)
    -- Pause and unpause the animation if in combat to prevent the characters breaking out
    if (Osi.IsInCombat(entities[1]) == 1) or ((entities[2]) and (Osi.IsInCombat(entities[2]) == 1)) then
        -- Fix some status effect remove animations causing desync
        Ext.Timer.WaitFor(200, function()
            scene:PlayAnimation(scene.AnimationData)
        end)
        Ext.Timer.WaitFor(1000, function()
            scene:TogglePause()
        end)
        Ext.Timer.WaitFor(1500, function()
            scene:TogglePause()
        end)
    end
    return scene
end

function VerifyEntity(entity)
    -- Verify target exists
    if not entity or not Osi.Exists(entity) then
        _D("Creating BG3SX Scene failed - Character doesn't exist")
        return false
    end

    -- Block dead entities
    if Osi.IsDead(entity) == 1 then
        _D("Creating BG3SX Scene failed - Character is dead")
        return false
    end

    -- Check if target is already in a BG3SX scene
    local ent = string.sub(entity, -36)
    local existingScene = Mods.BG3SX.Scene.FindSceneByEntity(ent)
    if existingScene then
        _D("Creating BG3SX Scene failed - Target already in BG3SX scene (UUID: " .. tostring(existingScene.Uuid) .. ").")
        return false
    end

    if not Mods.BG3SX.Entity:IsWhitelisted(entity) then
        _D("Creating BG3SX Scene failed - Target is not WhiteListed")
        return false
    end

    return true
end

function TagLookup(tags, blackList)
    -- Isolates the last tag
    local desiredTag = tags[#tags]
    local tags1 = tags
    tags1[#tags1] = nil
    -- if this isn't the first tag, recursively evaluate other tags
    local anims = {}
    -- TODO Don't like how many loops there are here, but it doesn't seem to cause enough lag atm to be a concern
    if tags1[1] then
        anims = TagLookup(tags1)
    else
        for _, module in pairs(Mods.BG3SX.Data.Animations) do
            for _, animData in pairs(module) do
                table.insert(anims, animData)
            end
        end
    end
    for _, animData in pairs(anims) do
        for _, tag in pairs(animData.Categories) do
            if tag == desiredTag then
                table.insert(anims, animData)
                break
            end
        end
    end
    for i, animData in pairs(anims) do
        for _, tag in pairs(animData.Categories) do
            for _, badTag in pairs(blackList) do
                if tag == badTag then
                    table.remove(anims, i)
                    break
                end
            end
        end
    end
    return anims
end

-- Gets Pairing's sexual orientation tag
function GetPairedOrientation(entities)
    local penises = 0
    local gen_tag
    for _, actor in pairs(entities) do
        gen_tag, _ = GetGenitals(actor)
        if gen_tag == "d27831df-2891-42e4-b615-ae555404918b" then
            penises = penises + 1
        end
    end
    -- TODO Hardcoded to pairs for now, since more than 3 actor scenes is currently not possible
    if penises == 0 then
        return "Lesbian"
    elseif penises == 1 then
        return "Straight"
    else
        return "Gay"
    end
end
