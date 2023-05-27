--[[ --------------------------------------------------------------------------------
					Add to ox_inventory/modules/items/client.lua
					Add these near the bottom of the list, but above the 
					exports for items & itemlist
-------------------------------------------------------------------------------- ]]--

Item('rc-bandito', function(data, slot)
    ox_inventory:useItem(data, function(data)
        if data then
            TriggerEvent('mth-rc:client:SpawnRcCar')
        end
    end)
end)


--[[ --------------------------------------------------------------------------------
					Add to ox_inventory/data/items.lua
-------------------------------------------------------------------------------- ]]--

['rc-bandito'] = {
    label = 'RC Bandito',
    description = 'A remote controlled car',
    weight = 2000,
    stack = false,
},