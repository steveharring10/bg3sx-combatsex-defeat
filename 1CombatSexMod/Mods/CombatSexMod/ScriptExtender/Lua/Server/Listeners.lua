-- On save load/new game
Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function(_, _)
    -- initialise persistent variables (should only be necessary if a variable was added in a version update)
    if not PersistentVars.Pairings then
        PersistentVars.Pairings = {}
    end
    if not PersistentVars.OriginalTemplates then
        PersistentVars.OriginalTemplates = {}
    end
    -- if not PersistentVars.CurrentTemplates then -- TODO replace this with planned iteration to conserve state of undress across save
    --     PersistentVars.CurrentTemplates = {}
    -- else
    --     -- Loads stripping status of NPCs
    --     local vrID
    --     for target, template in pairs(PersistentVars.CurrentTemplates) do
    --         if template then
    --             vrID = Ext.Entity.Get(target).ServerCharacter.Template.CharacterVisualResourceID
    --             Ext.Resource.Get(vrID,"CharacterVisual").VisualSet.Slots = template
    --             local payload = {dressed = template, resource = vrID}
    --             Ext.Net.BroadcastMessage("CombatSex_NPCUpdate", Ext.Json.Stringify(payload))
    --         end
    --     end
    -- end
    -- Gives passives and spells to player characters
    Setup()
end)

Ext.Osiris.RegisterListener("CharacterJoinedParty", 1, "after", function(character)
    -- Gives passives and spells to new player characters
    Setup()
end)

CombatSexPairs = {}
Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(target, status, caster, _)
    for _, pair in pairs(CombatSexPairs) do
        if (pair.aggressor == target) or (pair.victim == target) then
            Ext.Timer.WaitFor(1000, function()
                pair.scene:TogglePause()
            end)
            Ext.Timer.WaitFor(1500, function()
                pair.scene:TogglePause()
            end)
            break
        end
    end
	if status == "CombatSex_Assaulted" then
        -- If a character is marked as assaulted by player spell or enemy reaction, trigger the assault
        Assault(target, caster)
        Osi.RemoveStatus(target, "CombatSex_Assaulted")
	end
end)

Ext.Osiris.RegisterListener("HitpointsChanged", 2, "after", function(target, _)
    for _, pair in pairs(CombatSexPairs) do
        if (pair.aggressor == target) or (pair.victim == target) then
            Ext.Timer.WaitFor(1000, function()
                pair.scene:TogglePause()
            end)
            Ext.Timer.WaitFor(1500, function()
                pair.scene:TogglePause()
            end)
            break
        end
    end
end)

Ext.Osiris.RegisterListener("KilledBy", 4, "after", function(target, _, _, _)
    for i, pair in pairs(CombatSexPairs) do
        if (pair.aggressor == target) or (pair.victim == target) then
            AssaultEnd(i, pair)
            break
        end
    end
end)

Ext.Osiris.RegisterListener("StatusRemoved", 4, "before", function(aggressor, status, _, _)
    -- If the aggressor timer runs out, end the assault
    if status == "CombatSex_Aggressor" then
        local cas = string.sub(aggressor, -36)
        for i, pair in pairs(CombatSexPairs) do
            if pair.aggressor == cas then
                AssaultEnd(i, pair)
                break
            end
        end
    end
end)

Ext.Osiris.RegisterListener("StatusRemoved", 4, "before", function(victim, status, _, _)
    if status == "CombatSex_Victim" then
        local tar = string.sub(victim, -36)
        for _, pair in pairs(CombatSexPairs) do
            if pair.victim == tar and (Osi.HasActiveStatus(pair.aggressor, "CombatSex_Aggressor") == 1) then
                -- Resist roll handled here now because the tick roll on the status was disrupting the animations now that BG3SX doesn't use Actors
                -- if (Osi.GetHostCharacter() == pair.victim) then
                --     Osi.RequestActiveRollVersusSkill(pair.victim, pair.aggressor, "SavingThrow", "Strength", "Strength", 0, 1, "Resist")
                -- else
                Osi.RequestPassiveRollVersusSkill(pair.victim, pair.aggressor, "SavingThrow", "Strength", "Strength", 0, 1, "Resist")
                -- end
                break
            end
        end
    end
end)

-- Listen for the result of the resist roll
Ext.Osiris.RegisterListener("RollResult", 6, "after", function(name, roller, subject, result, _, crit)
    if (name == "Resist") then
        local tar = string.sub(roller, -36)
        if result == 1 then
            -- If the victim successfully rolls to resist, end the assault
            for i, pair in pairs(CombatSexPairs) do
                if pair.victim == tar then
                    Ext.Timer.WaitFor(200, function()
                        AssaultEnd(i, pair)
                    end)
                    break
                end
            end
        else
            for i, pair in pairs(CombatSexPairs) do
                if pair.victim == tar then
                    pair.scene:PlayAnimation(pair.scene.AnimationData)
                    Osi.ApplyStatus(roller, "CombatSex_Victim", 6, 0, subject)
                    break
                end
            end
        end
    end
end)

local popuphandle = "baf46772-aaf5-4893-8bde-a954a12287c2"
local popupkey = "CombatSex_Popup"
Ext.Osiris.RegisterListener("UsingSpellOnTarget", 6, "after", function(caster, target, spell, _, _, _)
    -- Check for consent
	if spell == "CombatSex_ConsentWrapper" then
        local consent = false
        local tar = string.sub(target, -36)
        local cas = string.sub(caster, -36)
        -- If NPC with Attitude (traders), and it's high enough
        if Osi.GetAttitudeTowardsPlayer(target, caster) >= 75 then
            consent = true
        end
        -- If triggered specific dialog with or between companions
        for _, pairing in pairs(PersistentVars.Pairings) do
            if ((tar == pairing[1]) and (cas == pairing[2])) or ((tar == pairing[2]) and (cas == pairing[1])) then
                consent = true
            end
        end
        if consent then
            StartSex({cas, tar}, Mods.BG3SX.Data.IntroAnimations[Mods.BG3SX.ModuleUUID]["Hug or Carry"])
        else
            local msg = "Target Declined"
            _P(msg)
            Ext.Loca.UpdateTranslatedString(popuphandle, msg)
            Osi.OpenMessageBox(Osi.GetHostCharacter(), popupkey)
        end
	end
end)

Ext.Osiris.RegisterListener("UsingSpell", 5, "after", function(caster, spell, _, _, _)
    if spell == "CombatSex_StartMasturbating" then
        StartSex({caster}, Mods.BG3SX.Data.IntroAnimations[Mods.BG3SX.ModuleUUID]["Start Masturbating"])
    end
end)

Ext.Osiris.RegisterListener("UsingSpellOnTarget", 6, "after", function(caster, target, spell, _, _, _)
	if spell == "CombatSex_Assault" then
        -- Reduce NPC attitude and companion approval if you assaulted them
        local attitudeLoss = 20
        if Mods.BG3MCM then
            attitudeLoss = Mods.BG3MCM.MCMAPI:GetSettingValue("attitudeMulti", ModuleUUID)
        end
        Osi.AddAttitudeTowardsPlayer(target, caster, -attitudeLoss)
        Osi.ChangeApprovalRating(target, caster, 0, -attitudeLoss)
    end
end)

-- Handle Dialog flag changes
Ext.Osiris.RegisterListener("DialogEnded", 2, "after", function (flag, _)
    -- On Karlach repair scene, enable her for sex
    if flag == "GLO_ForgingOfTheHeart_OM_Karlach_AOM_OOM_COM_e31f3936-c198-cf82-bd8f-e26efba691f1" then
        Osi.AddPassive("2c76687d-93a2-477b-8b18-8a14b549304c", "CombatSex_KarlachEngine")
        Osi.RemovePassive("2c76687d-93a2-477b-8b18-8a14b549304c", "CombatSex_Unsexable")
        Osi.AddSpell("2c76687d-93a2-477b-8b18-8a14b549304c", "CombatSex_Assault")
        Osi.AddSpell("2c76687d-93a2-477b-8b18-8a14b549304c", "CombatSex_Container")
    else
        -- On consensual sex scene, give consent between those characters
        local pair
        local participants = SCENES[flag]
        if participants then
            pair = {}
            for _, participant in pairs(participants) do
                if participant == "PLAYER" then
                    table.insert(pair, Osi.GetHostCharacter())
                else
                    table.insert(pair, participant)
                end
            end
            table.insert(PersistentVars.Pairings, pair)
        end
    end
end)

Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(target, status, _, _)
    -- When the NPC's redress timer expires, attempt to redress
    if status == "CombatSex_Redress" then
        Osi.RemoveStatus(target, "CombatSex_Redress")
        -- Redressing is blocked in combat or knocked out
        if (Osi.IsInCombat(target) == 1) or (Osi.HasAppliedStatusOfType(target, "INCAPACITATED") == 1) then
            -- Reset the redress timer so in 1 turn the NPC will attempt to redress again
            Osi.ApplyStatus(target, "CombatSex_Stripped", 6)
        else
            -- Redress the NPC
            local entity = Ext.Entity.Get(target)
            local clothes = Mods.BG3SX.SexUserVars.GetNPCClothes(entity)
            if clothes then
                Mods.BG3SX.Event.SyncNPCDress:Broadcast({Uuid = entity.Uuid.EntityUuid, Visuals = clothes})
                Mods.BG3SX.NPC.Redress(entity, clothes)
                Mods.BG3SX.SexUserVars.SetNPCClothes(nil, entity)
                Mods.BG3SX.NPC.RemoveGenitals(entity)
            end
        end
    end
end)

Ext.Osiris.RegisterListener("AttackedBy", 7, "after", function(target, caster, _, damageType, damage, cause, _)
    if (
        -- Check attack for eligibility
        (not (target == caster))
        and (Osi.IsPlayer(caster) == 0)
        and (not (damageType == ""))
        and ((cause == "Attack") or (cause == "Offhand"))
        and (Osi.GetDistanceTo(caster, target) <= 3.0)
        and (Osi.HasPassive(target, "CombatSex_Unsexable") == 0) and (Osi.HasActiveStatus(target, "CombatSex_Disabled") == 0)
        -- Triggers
        and (
            (Osi.HasAppliedStatusOfType(target, "SG_Unconscious") == 1)
            or (Osi.HasAppliedStatusOfType(target, "SG_Prone") == 1)
            or (Osi.HasAppliedStatusOfType(target, "SG_Incapacitated") == 1)
            or (Osi.HasAppliedStatusOfType(target, "SG_Paralyzed") == 1)
            or (Osi.HasAppliedStatusOfType(target, "SG_Restrained") == 1)
            -- Configurables
            or (
                Mods.BG3MCM
                and (
                    -- Random chance (default 0)
                    (math.random(100) <= Mods.BG3MCM.MCMAPI:GetSettingValue("assaultChance", ModuleUUID))
                    -- Damage threshold (default 999)
                    or (damage >= Mods.BG3MCM.MCMAPI:GetSettingValue("assaultDamage", ModuleUUID))
                )
            )
        )
    ) then
        Osi.ApplyStatus(target, "CombatSex_Assaulted", -1, 100, caster)
        -- TODO disable user's control over scenes if NPC initiated - should probably leave this for a while so user can emergency exit a scene if softlocked
        -- local scenePicker = Mods.BG3SX.SceneControl:FindInstanceByEntity(target)
        -- scenePicker.HidePicker()
    end
end)

Ext.Osiris.RegisterListener("CriticalHitBy", 4, "after", function(target, caster, _, _)
    if (
        -- Check attack for eligibility
        (not target == caster)
        and (Osi.IsPlayer(caster) == 0)
        and (Osi.GetDistanceTo(caster, target) <= 3.0)
        and (Osi.HasPassive(target, "CombatSex_Unsexable") == 0) and (Osi.HasActiveStatus(target, "CombatSex_Disabled") == 0)
    ) then
        Osi.ApplyStatus(target, "CombatSex_Assaulted", -1, 100, caster)
        -- TODO disable user's control over scenes if NPC initiated - should probably leave this for a while so user can emergency exit a scene if softlocked
        -- local scenePicker = Mods.BG3SX.SceneControl.SceneControl:FindInstanceByEntity(target)
        -- scenePicker.HidePicker()
    end
end)
