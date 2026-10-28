SexScenario = {}

-- Pairing rules are built from the MCM settings so the player can
-- enable/disable each victim/captor bodytype combination.
SexScenario.PairingRuleOrder = {
    { id = "pairing_mf", victim = "Male", captor = "Female" },
    { id = "pairing_fm", victim = "Female", captor = "Male" },
    { id = "pairing_mm", victim = "Male", captor = "Male" },
    { id = "pairing_ff", victim = "Female", captor = "Female" }
}

-- Returns the pairings enabled by the MCM checkboxes.
function SexScenario.GetEnabledPairings()
    local enabled = {}
    for _, rule in ipairs(SexScenario.PairingRuleOrder) do
        if Utils.MCMGet(rule.id) then
            table.insert(enabled, { rule.victim, rule.captor })
        end
    end

    if #enabled == 0 then
        Utils.Warn("All gender pairings are disabled in the MCM, no sex scenes will start")
    end

    return enabled
end

-- Single entry point for pairing victims with captors.
-- Randomly pairs each victim with a captor from any enabled pairing rule,
-- so captor genders stay mixed while the enabled rules are respected.
function SexScenario.MakePairs(victims, captors)
    local enabled = SexScenario.GetEnabledPairings()
    return make_pairs_random(victims, captors, enabled)
end

function SexScenario.DefeatScenarioStarted(e)
    Utils.Debug("Context: ")
    Utils.PrintTable(e)
    local victims = e.victims
    Utils.Debug("victims: ")
    Utils.PrintTable(victims)
    local captors, extras = getBG3SXWhiteListed(e.captors)
    Utils.Debug("captors: ")
    Utils.PrintTable(captors)
    Utils.Debug("Extras: ")
    Utils.PrintTable(extras)
    if #extras == #e.captors or (Utils.MCMGet("exclude_tav") and #victims == 1 and victims[1] == Osi.DB_Avatars:Get(nil)[1][1]) then
        Utils.Debug("Switch to alt scenario")
        
        local mainPerp = e.captors[Osi.Random(#e.captors)+1]
        local mainVictim = e.victims[Osi.Random(#e.victims)+1]
        Utils.Debug("PERP: " .. mainPerp)
        Utils.Debug("VICTIM: " .. mainVictim)
        Osi.ApplyStatus(mainPerp, "AD_ACTION_CAPTOR_BG3SXDEFEAT_SHOW_WALKTO", 120, 1, mainVictim)
        return
    end

    -- for _,victim in pairs(victims) do
    --     Osi.SetCanJoinCombat(victim, 0)
    -- end

    -- Osi.DB_Avatars:Get(nil)[1][1] (tav)
    if Utils.MCMGet("exclude_tav") then
        local replace_victims = {}
        for _,victim in pairs(victims) do
            if victim == Osi.DB_Avatars:Get(nil)[1][1] then
                table.insert(extras, victim)
            else
                table.insert(replace_victims, victim)
            end
        end
        victims = replace_victims
    end

    Utils.PrintTable(victims)

    local pairings, leftovers = SexScenario.MakePairs(victims, captors)
    Utils.Debug("PAIRS:")
    Utils.PrintTable(pairings)
    for i, p in pairs(pairings) do
        Osi.ApplyStatus(p.captor, "AD_ACTION_CAPTOR_BG3SXDEFEAT_WALKTO", 360, 1, p.victim)
        Osi.SetVarFixedString(p.victim, "AD_CurrentCaptor", p.captor)
        Utils.Debug("SETTING FIXED STRING: " .. p.captor)
    end

    Utils.Debug("LEFTOVERS: ")
    Utils.PrintTable(leftovers)
    for i, l in pairs(leftovers.captors) do
        local v = victims[Osi.Random(#victims)+1]
        Osi.ApplyStatus(l, "AD_ACTION_CAPTOR_BG3SXDEFEAT_BYSTANDER", 360, 1, v)
    end

    for _,extra in pairs(extras) do
        Osi.ApplyStatus(extra, "AD_ACTION_CAPTOR_BG3SXDEFEAT_BYSTANDER", 360, 1, victims[Osi.Random(#victims)+1])
    end
end

-- fuck eachother for the enemy (cos bg3sx doesn't support goblins/etc)
function DoShowScenario(e)
    local victims = e.victims
    local captors = e.captors
    local victimFirstHalf, victimSecHalf = split_in_two(victims)
    -- pair up players freely by gender
    local pairs, leftovers = SexScenario.MakePairs(victimFirstHalf, victimSecHalf)

    Utils.Debug("PAIRS")
    Utils.PrintTable(pairs)

    Utils.Debug("LEFTOVERS")
    Utils.PrintTable(leftovers)

    for i, p in ipairs(pairs) do
        -- Osi.SetCanJoinCombat(p.victim, 0)
        -- Osi.SetCanJoinCombat(p.captor, 0)
        Osi.RemoveStatus(p.victim, "AD_DEFEATED")
        Osi.RemoveStatus(p.captor, "AD_DEFEATED")
        Osi.ApplyStatus(p.captor, "AD_ACTION_CAPTOR_BG3SXDEFEAT_WALKTO", 360, 1, p.victim)
        Osi.SetVarFixedString(p.victim, "AD_CurrentCaptor", p.captor)
    end

    for i, l in ipairs(leftovers.captors) do
        Osi.RemoveStatus(l, "AD_DEFEATED")
        Osi.ApplyStatus(l, "AD_ACTION_VICTIM_BG3SXDEFEAT_MASTURBATE", 360, 1, l) -- masturbation for leftover players
        Osi.SetVarFixedString(l, "AD_CurrentCaptor", l)
    end

    if next(pairs) ~= nil then
        for _,c in ipairs(captors) do
            Osi.ApplyStatus(c, "AD_ACTION_CAPTOR_BG3SXDEFEAT_BYSTANDER", 360, 1, pairs[Osi.Random(#pairs)+1].victim)
        end
    end
    if next(leftovers.captors) ~= nil and next(leftovers.victims) ~= nil then
        for _,c in ipairs(captors) do
            if Osi.Random(10) < 3 then
                Osi.ApplyStatus(c, "AD_ACTION_CAPTOR_BG3SXDEFEAT_BYSTANDER", 360, 1, leftovers.captors[Osi.Random(#leftovers.captors)+1])
            end
        end
    end
end

function SexScenario.DefeatScenarioActionStarted(e)
    local status = e.status
    local victim = e.victim
    local captor = e.captor
    local defeatContext = e.defeatContext

    if status == "AD_ACTION_VICTIM_BG3SXDEFEAT_SHOWTIME" then
        DoShowScenario(defeatContext)
    end

    if status == "AD_ACTION_VICTIM_BG3SXDEFEAT_MASTURBATE" then
        SceneManager.CreateBG3SXSoloScene(victim)
    end


    if status == "AD_ACTION_CAPTOR_BG3SXDEFEAT_SEX_POSITIONS_TECHNICAL" then
        local cap = Osi.GetVarFixedString(victim, "AD_CurrentCaptor")
        Utils.Debug("ADACTION CALLED TIME TO CHANGE")
        if cap == nil then
            Utils.Warn("Captor doesn't exist")
        end
        Ext.Timer.WaitFor(100, function ()
            SceneManager.ChangeSceneAnimationRandomly(cap)
        end)
        
    end

    -- if status == "AD_ACTION_VICTIM_BG3SXDEFEAT_MASTURBATE" then
    --     Osi.UseSpell(victim, "BG3SX_StartMasturbating", captor)
    -- end

    if status == "AD_ACTION_CAPTOR_BG3SXDEFEAT_WALKTO" then
        local sexCaptor = Osi.GetVarFixedString(victim, "AD_CurrentCaptor")
        if sexCaptor ~= nil and sexCaptor ~= "" then
            local dialog = Dialogs["Begin_" .. SexScenario.GetSexPairCode(victim, sexCaptor)]
            Osi.QRY_StartDialogCustom_Fixed(dialog[Osi.Random(#dialog) + 1], captor, "NULL_00000000-0000-0000-0000-000000000000", "NULL_00000000-0000-0000-0000-000000000000", "NULL_00000000-0000-0000-0000-000000000000", "NULL_00000000-0000-0000-0000-000000000000", "NULL_00000000-0000-0000-0000-000000000000", 1, 1, -1, 1 )
        end
    end

    if status == "AD_ACTION_CAPTOR_BG3SXDEFEAT_DIALOG" then
        local sexCaptor = Osi.GetVarFixedString(victim, "AD_CurrentCaptor")
        if sexCaptor ~= nil and sexCaptor ~= "" then
            local dialog = Dialogs["Sex_" .. SexScenario.GetSexPairCode(victim, sexCaptor)]
            if Osi.HasActiveStatus(victim, "BG3SXDEFEAT_ORGASM_BLOCK") == 1 then
                dialog = Dialogs["CrowdOrgasm_" .. SexScenario.GetSexPairCode(victim, sexCaptor)]
            end
            Osi.QRY_StartDialogCustom_Fixed(dialog[Osi.Random(#dialog) + 1], captor, "NULL_00000000-0000-0000-0000-000000000000", "NULL_00000000-0000-0000-0000-000000000000", "NULL_00000000-0000-0000-0000-000000000000", "NULL_00000000-0000-0000-0000-000000000000", "NULL_00000000-0000-0000-0000-000000000000", 1, 1, -1, 1 )
        end
    end
end

function SexScenario.DefeatScenarioActionCompleted(e)
    local status = e.status
    local victim = e.victim
    local captor = e.captor
    local defeatContext = e.defeatContext

    if status == "AD_ACTION_VICTIM_BG3SXDEFEAT_SEX_POSITIONS_MASTURBATION" then
        Osi.UseSpell(victim, "BG3SX_StopAction", victim)
        SexScenario.CleanUpDefeat(defeatContext)
    end

    if status == "AD_ACTION_VICTIM_BG3SXDEFEAT_SEX_POSITIONS" then
        if Osi.GetVarFixedString(victim, "AD_CurrentCaptor") ~= nil and Osi.GetVarFixedString(victim, "AD_CurrentCaptor") ~= "" then
           SceneManager.DestroyCharacterScene(victim)
        end
    end
end

function SexScenario.DefeatScenarioRequestEnd(defeatContext)
    SexScenario.CleanUpDefeat(defeatContext)
end

function SexScenario.TryEndDefeat(defeatContext)
    for _,v in pairs(defeatContext.victims) do
        --Osi.RemoveStatus(v, "AD_ACTION_VICTIM_BG3SXDEFEAT_SEX_POSITIONS")
    end
end

function SexScenario.CleanUpDefeat(defeatContext)
    Utils.Debug("CLEANING UP DEFEAT SCENARIO [" .. defeatContext.scenarioId .. "] FOR COMBAT: " .. defeatContext.combatGuid)
    local victims = defeatContext.victims
    local captors = defeatContext.captors

    for _,v in pairs(victims) do
        Osi.ApplyStatus(v, "AD_SPARED_TEMP", 36, 1)
        Osi.RemoveStatus(v, "AD_ACTION_VICTIM_BG3SXDEFEAT_SEX_POSITIONS")
        Osi.RemoveStatus(v, "BG3SXDEFEAT_SEX_TECHNICAL")

        SceneManager.DestroyCharacterScene(v)

        Osi.RemoveStatus(v, "AD_ACTION_VICTIM_BG3SXDEFEAT_MASTURBATE")
        Osi.RemoveStatus(v, "BG3SXDEFEAT_SEX_POSITIONS")
        Osi.RemoveStatus(v, "BG3SXDEFEAT_REQ_CHANGE_POSITION")
        Osi.RemoveStatus(v, "BG3SXDEFEAT_REQ_CHANGE_POSITION_BLOCK")

        if Osi.GetVarFixedString(v, "AD_CurrentCaptor") ~= nil and Osi.GetVarFixedString(v, "AD_CurrentCaptor") ~= "" then
            Osi.UseSpell(Osi.GetVarFixedString(v, "AD_CurrentCaptor"), "BG3SX_StopAction", v)
        end
    end

    for _, c in pairs(captors) do
        Osi.RemoveStatus(c, "AD_ACTION_CAPTOR_BG3SXDEFEAT_BYSTANDER")
        Osi.RemoveStatus(c, "AD_ACTION_CAPTOR_BG3SXDEFEAT_SEX_POSITIONS")
        Osi.RemoveStatus(c, "BG3SXDEFEAT_SEX_POSITIONS")
        Osi.RemoveStatus(c, "BG3SXDEFEAT_REQ_CHANGE_POSITION")
        Osi.RemoveStatus(c, "BG3SXDEFEAT_REQ_CHANGE_POSITION_BLOCK")
        Osi.RemoveStatus(c, "BG3SXDEFEAT_SEX_TECHNICAL")

        SceneManager.DestroyCharacterScene(c)
    end
    
    Ext.Timer.WaitFor(10, function()
        for _,v in pairs(victims) do
            Osi.SetCanJoinCombat(v, 1)
            Osi.SetVarFixedString(v, "AD_CurrentCaptor", "")
        end

        Mods.AbsoluteDefeat.AD.CleanUpDefeat(defeatContext.combatGuid)
    end)
end

function getBG3SXWhiteListed(captors)
    local whitelisted = {}
    local blacklisted = {}
    for _,captor in pairs(captors) do
        if Mods.BG3SX.Entity:IsWhitelisted(captor) then
            table.insert(whitelisted, captor)
        else
            Utils.Debug("[BG3SXDefeat] Blacklisted NPC detected: " .. captor)
            table.insert(blacklisted, captor)
        end
    end
    return whitelisted, blacklisted
end

-- [[ PAIR MAKING UTILS ]]

-- Shuffle helper
function shuffle(t)
    for i = #t, 2, -1 do
        local j = Osi.Random(i) + 1
        t[i], t[j] = t[j], t[i]
    end
end

function split_in_two(t)
    shuffle(t)
    local half = math.floor(#t / 2)

    local first_half = {}
    local second_half = {}

    for i = 1, half do
        table.insert(first_half, t[i])
    end

    for i = half + 1, #t do
        table.insert(second_half, t[i])
    end

    return first_half, second_half
end

-- Pairs each victim with a captor chosen at random from any enabled
-- victim/captor combination, so captor genders stay mixed instead of one
-- gender consuming every victim first.
function make_pairs_random(victims, captors, enabled_rules)
    local groupsC = {}
    for _, s in ipairs(captors) do
        local t = Osi.GetBodyType(s, 1)
        groupsC[t] = groupsC[t] or {}
        table.insert(groupsC[t], s)
    end
    for _, g in pairs(groupsC) do shuffle(g) end

    local shuffledVictims = {}
    for _, v in ipairs(victims) do table.insert(shuffledVictims, v) end
    shuffle(shuffledVictims)

    local pairings = {}
    local leftovers = { victims = {}, captors = {} }

    for _, victim in ipairs(shuffledVictims) do
        local vType = Osi.GetBodyType(victim, 1)

        local candidates = {}
        for _, rule in ipairs(enabled_rules) do
            local cGroup = groupsC[rule[2]] or {}
            if rule[1] == vType and #cGroup > 0 then
                table.insert(candidates, rule[2])
            end
        end

        if #candidates > 0 then
            local cType = candidates[Osi.Random(#candidates) + 1]
            local cGroup = groupsC[cType]
            local captor = table.remove(cGroup, Osi.Random(#cGroup) + 1)
            table.insert(pairings, { victim = victim, captor = captor })
        else
            table.insert(leftovers.victims, victim)
        end
    end

    for _, g in pairs(groupsC) do
        for _, c in ipairs(g) do table.insert(leftovers.captors, c) end
    end

    return pairings, leftovers
end

function SexScenario.Strip(char)
    -- MCM option: strip armor on defeat (default enabled)
    if Utils.MCMGet("keep_armor") then
        return
    end

    local armorSlots =  {"Helmet", "Breast", "Cloak", "Boots", "Gloves", "Underwear", "MusicalInstrument", "VanityBody", "VanityBoots", "Melee Main Weapon", "Melee Offhand Weapon", "Ranged Main Weapon", "Ranged Offhand Weapon"}
    -- Unequip all armor
    for _,slot in pairs(armorSlots) do
        local item = Osi.GetEquippedItem(char, slot)

        if item ~= nil then
            Osi.Unequip(char, item)
        end
    end
end

function SexScenario.GetSexPairCode(sub, dom)
    Utils.PrintTable({sub = sub, dom = dom})
    if dom == nil or dom == sub then 
        if Osi.GetBodyType(sub, 1) == "Female" then
            if Osi.IsTagged(sub, "GENITAL_PENIS_d27831df-2891-42e4-b615-ae555404918b") == 1 then
                return 'Masturbate_FP'
            else
                return 'Masturbate_FV'
            end
        elseif Osi.GetBodyType(sub, 1) == "Male" then
            if Osi.IsTagged(sub, "GENITAL_VULVA_a0738fdf-ca0c-446f-a11d-6211ecac3291") == 1 then
                return 'Masturbate_MV'
            else
                return 'Masturbate_MP'
            end
        end
    end

    if Osi.IsTagged(sub, "GENITAL_VULVA_a0738fdf-ca0c-446f-a11d-6211ecac3291") == 1 and (Osi.GetBodyType(dom, 1) == "Male" or Osi.IsTagged(dom, "GENITAL_PENIS_d27831df-2891-42e4-b615-ae555404918b") == 1) then
        return 'MF'
    elseif Osi.IsTagged(sub, "GENITAL_PENIS_d27831df-2891-42e4-b615-ae555404918b") == 1 and Osi.GetBodyType(dom, 1) == "Female" then
        return 'FM'
    elseif Osi.IsTagged(sub, "GENITAL_VULVA_a0738fdf-ca0c-446f-a11d-6211ecac3291") == 1 and Osi.GetBodyType(dom, 1) == "Female" and Osi.IsTagged(dom, "GENITAL_PENIS_d27831df-2891-42e4-b615-ae555404918b") ~= 1 then
        return 'FF'
    else
        return 'MM'
    end
end

function SexScenario.KickOutVictims(victims)
    for _,v in pairs(victims) do
        Osi.QRY_CombatFlee_TryFleeToCamp(v)
        Osi.ApplyStatus(v, "", 12, 1)
    end
end

return SexScenario