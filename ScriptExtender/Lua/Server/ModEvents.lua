local handlers = {
    ["SexScenario_5f97de42-a995-478d-abbf-8bec78bcb754"] = SexScenario,
}

Ext.ModEvents.AbsoluteDefeat.DefeatScenarioStarted:Subscribe(function (e)
    Utils.Debug("[BG3SXDefeat][Events] DefeatScenarioStarted")
    if handlers[e.scenarioId] ~= nil then
        handlers[e.scenarioId].DefeatScenarioStarted(e)
    end
end)

Ext.ModEvents.AbsoluteDefeat.DefeatScenarioActionStarted:Subscribe(function (e)
    Utils.Debug("[BG3SXDefeat][Events] DefeatScenarioActionStarted")
    if handlers[e.scenarioId] ~= nil then
        handlers[e.scenarioId].DefeatScenarioActionStarted(e)
    end
end)

Ext.ModEvents.AbsoluteDefeat.DefeatScenarioActionCompleted:Subscribe(function (e)
    Utils.Debug("[BG3SXDefeat][Events] DefeatScenarioActionCompleted")
    if handlers[e.scenarioId] ~= nil then
        handlers[e.scenarioId].DefeatScenarioActionCompleted(e)
    end
end)

Ext.ModEvents.AbsoluteDefeat.DefeatScenarioRequestEnd:Subscribe(function (e)
    Utils.Debug("[BG3SXDefeat][Events] DefeatScenarioRequestEnd")
    Utils.PrintTable(e)
    if handlers[e.scenarioId] ~= nil then
        handlers[e.scenarioId].DefeatScenarioRequestEnd(e)
    end
end)

Ext.ModEvents.BG3SX.ActorDressed:Subscribe(function (e)
    Utils.Debug("[BG3SXDefeat][Events] ActorDressed received with PayLoad: ")
end)

Ext.ModEvents.BG3SX.ActorInit:Subscribe(function (e)
    Osi.SetCanJoinCombat(e[1], 0)
    Osi.AddBoosts(e[1], "StatusImmunity(SG_Blinded)", "", "")
    Osi.AddBoosts(e[1], "IgnoreSurfaceCover(SurfaceDarknessCloud)", "", "")
    Osi.SetTag(e[1], "b47643e0-583c-4808-b108-f6d3b605b0a9")
end)

Ext.ModEvents.BG3SX.SceneCreated:Subscribe(function (e)
    local entities = e[1].entities
    Utils.Debug("[EVENTS] SCENE CREATED")
    Utils.PrintTable(entities)

    local victim = nil
    local captor = Osi.GetVarFixedString(e[1].entities[1], "AD_CurrentCaptor")

    if captor ~= nil and captor ~= "" then
        victim = e[1].entities[1]
    else
        captor = e[1].entities[1]
        victim = e[1].entities[2]
    end

    if Osi.HasActiveStatus(captor, "AD_ACTION_CAPTOR_BG3SXDEFEAT_WALKTO") == 1 then
        Osi.ApplyStatus(captor, "BG3SXDEFEAT_SEX_POSITIONS", -1, 100, victim)
        Osi.ApplyStatus(victim, "AD_ACTION_VICTIM_BG3SXDEFEAT_SEX_POSITIONS", -1, 100, captor)
    end

    SceneManager.onSceneCreated(e)
end)

Ext.ModEvents.BG3SX.SceneDestroyed:Subscribe(function (e)

    SceneManager.onSceneDestroyed(e)
end)