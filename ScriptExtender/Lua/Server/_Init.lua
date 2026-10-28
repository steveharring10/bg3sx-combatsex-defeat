local deps = {
    AbsoluteDefeatUUID = "755a8a72-407f-4f0d-9a33-274ac0f0b53d"
}

if not Ext.Mod.IsModLoaded(deps.AbsoluteDefeatUUID) then
    Ext.Utils.Error("[BG3SXDefeat] AbsoluteDefeat Depenency is missing.")
end

RequireFiles("Server/", {
    "Utils",
    "Dialogs",
    "SexPositions",
    "SexScenario",
    "SceneManager",
    "LoadConfig",
    "ModEvents",
    "Events",
})