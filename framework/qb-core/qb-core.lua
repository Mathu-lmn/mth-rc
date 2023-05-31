--[[ --------------------------------------------------------------------------------
					Add to qb-smallresources/server/consumables.lua
                    I added it to Tools, other location may or may not work 
-------------------------------------------------------------------------------- ]]--

QBCore.Functions.CreateUseableItem("rc-bandito", function(source)
    TriggerClientEvent("mth-rc:client:SpawnRcCar", source)
end)


--[[ --------------------------------------------------------------------------------
					Add to qb-core/shared/items.lua
-------------------------------------------------------------------------------- ]]--

['rc-bandito'] 						 = {['name'] = 'rc-bandito', 			 	  	  	['label'] = 'RC Bandito', 	['weight'] = 200, 		['type'] = 'item', 		['image'] = 'rc-bandito.png', 				['unique'] = false, 	['useable'] = true, 	['shouldClose'] = true,   ['combinable'] = nil,   ['description'] = 'A remote controlled car'},