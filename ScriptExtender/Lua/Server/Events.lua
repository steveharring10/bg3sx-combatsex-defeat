

Ext.Osiris.RegisterListener("StatusApplied", 4, "before", function(object, status, causee, storyActionID)
    if status ~= "INSURFACE" then
        --Utils.Debug("STATUS APPLIED: ".. status)
    end

    if status == "BG3SXDEFEAT_SEX_POSITIONS" then
        Ext.Timer.WaitFor(100, function ()
            SceneManager.Realign(object)
        end)
    end
    
    if status == "BG3SXDEFEAT_REQ_CHANGE_POSITION" then
        Ext.Timer.WaitFor(100, function ()
            SceneManager.Realign(object)
            Ext.Timer.WaitFor(100, function ()
                SceneManager.ChangeSceneAnimationRandomly(object)
            end)
        end)
    end

    if status == "AD_ACTION_VICTIM_BG3SXDEFEAT_SEX_POSITIONS" then
        if Osi.GetHitpoints(object) == 0 then
            Osi.SetHitpoints(object, 1)
        end
    end

    if status == "AD_ACTION_VICTIM_ORGASMED" then
        local sexCaptor = Osi.GetVarFixedString(object, "AD_CurrentCaptor")
        if sexCaptor ~= nil and sexCaptor ~= "" then
            local dialog = Dialogs["Orgasm_" .. SexScenario.GetSexPairCode(object, sexCaptor)]
            -- small delay so orgasmed status text doesn't obscure
            Ext.Timer.WaitFor(1500, function()
                Osi.QRY_StartDialogCustom_Fixed(dialog[Osi.Random(#dialog) + 1], sexCaptor, "NULL_00000000-0000-0000-0000-000000000000", "NULL_00000000-0000-0000-0000-000000000000", "NULL_00000000-0000-0000-0000-000000000000", "NULL_00000000-0000-0000-0000-000000000000", "NULL_00000000-0000-0000-0000-000000000000", 1, 1, -1, 1 )
            end)
        end
    end

    
end)

Ext.Osiris.RegisterListener("AnimationEvent", 3, "after", function(object, eventName, wasFromLoad)
    --_P("ANIMATIONEVENT: " .. tostring(object) .. " " .. tostring(eventName))
end)

Ext.Osiris.RegisterListener("StatusRemoved", 4, "after", function(object, status, causee, applyStoryActionID)
   --_P("STATUS REMOVED: ".. status)
end)

Ext.Osiris.RegisterListener("UsingSpellOnTarget", 6, "after", function(caster, target, spell, _, _, _)
    if spell == "Target_BG3SXDefeat_Assault" then
        Osi.RemoveStatus(target, "AD_DEFEATED")
        Osi.SetHitpoints(target, 1)
        Ext.Timer.WaitFor(300, function()
            Osi.PlayAnimation(target, "379d4f19-68df-61be-a802-9db20f5aa872", "")
            -- if MCM Strip on Defeat enabled
            SexScenario.Strip(target)
            SceneManager.CreateBG3SXScene(target, caster)
        end)
    end
end)

