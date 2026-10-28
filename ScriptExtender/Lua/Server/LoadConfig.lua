local authorConfigFilePathPattern = string.gsub("Mods/%s/ScriptExtender/AbsoluteDefeat.AuthorConfig.json", "'", "\'")
local playerConfigFilePathPattern = string.gsub("Mods/%s/ScriptExtender/AbsoluteDefeat.PlayerConfig.json", "'", "\'")

function RestorePlayerConfig()
	local modData = Ext.Mod.GetMod(ModuleUUID)
	local playerFilePath = playerConfigFilePathPattern:format(modData.Info.Directory)
	local authorFilePath = authorConfigFilePathPattern:format(modData.Info.Directory)
	local config = Ext.IO.LoadFile(playerFilePath)
	if config == nil then
		Ext.Utils.PrintWarning("Could not find config file at: " .. playerFilePath .. " creating one.")
		local authorContent = Ext.IO.LoadFile(authorFilePath, "data")
		if authorContent ~= nil then
			local authorConfig = Ext.Json.Parse(authorContent)
			if not authorConfig or not authorConfig.Scenarios then
				Ext.Utils.PrintError("Invalid config structure in " .. authorFilePath)
				return
			end

			local playerConfig = {
				FileVersion = 1,
				ModGuid = ModuleUUID,
				Scenarios = {}
			}

			for _, scenario in pairs(authorConfig.Scenarios) do
				playerConfig.Scenarios[scenario.Id] = { Weight = scenario.Weight }
			end

			-- encode to JSON
			SaveJSONFile(playerFilePath, playerConfig)
		else
			Ext.Utils.PrintError("Could not find config file at: " .. authorFilePath)
		end
	end
end

--- Saves the given content to a JSON file.
--- @param filePath string The file path to save the content to.
--- @param content table The table with content to save to the file.
function SaveJSONFile(filePath, content)
    local fileContent = Ext.Json.Stringify(content, { Beautify = true })
    Ext.IO.SaveFile(filePath, fileContent)
    Utils.Debug("[SaveJSONFile] File saved to " .. filePath)
end

RestorePlayerConfig()