RegisterServerEvent("player:getItems")
RegisterServerEvent("item:giveItem")

local invTable = {}
local inventory = {}
data = inventory

AddEventHandler('redemrp_inventory:getData', function(cb)
    cb(data)
end)

RegisterServerEvent("redemrp_inventory:LoadItems")
AddEventHandler("redemrp_inventory:LoadItems", function()
    local _source = source

    TriggerEvent("player:getItems", _source, _source)
end)


AddEventHandler("player:getItems", function(target , src)
    local _source = tonumber(src or source)

    local _target = tonumber(target)
    local check = false
    TriggerEvent('redemrp:getPlayerFromId', _target, function(user)
        if user ~= nil then
            local identifier = user.getIdentifier()
            local charid = user.getSessionVar("charid")

            if(invTable[identifier .. "_" .. charid])then
                if _target ==  _source  then
                    TriggerClientEvent("gui:getItems", _target, k.inventory)
                else
                    TriggerClientEvent("gui:getOtherItems", _source, k.inventory)
                end
                if _target ==  _source  then
                    TriggerClientEvent("item:LoadPickups", _target, Pickups)
                    TriggerClientEvent("player:loadWeapons", _target)
                end
                check = true
            end

            if check == false then
                MySQL.Async.fetchAll('SELECT * FROM user_inventory WHERE `identifier`=@identifier AND `charid`=@charid;', {identifier = identifier, charid = charid}, function(inventory)
                    if inventory[1] ~= nil then
                        local inv = json.decode(inventory[1].items)
                        invTable[identifier .. "_" .. charid] = {id = identifier, charid = charid , inventory = inv}
                        TriggerClientEvent("gui:getItems", _target, inv)
                        TriggerClientEvent("item:LoadPickups", _target, Pickups)
                        TriggerClientEvent("player:loadWeapons", _target)
                    else
                        local test = {
                            ["water"] = 3,
                            ["bread"] = 3,
                        }
                        MySQL.Async.execute('INSERT INTO user_inventory (`identifier`, `charid`, `items`) VALUES (@identifier, @charid, @items);',
                            {
                                identifier = identifier,
                                charid = charid,
                                items = json.encode(test)
                            }, function(rowsChanged)
                            end)

                        invTable[identifier .. "_" .. charid] = {id = identifier, charid = charid , inventory = test}
                        TriggerClientEvent("gui:getItems", _target, test)
                        TriggerClientEvent("item:LoadPickups", _target, Pickups)
                    end
                end)
            end
        end
    end)
end)

RegisterServerEvent("weapon:saveAmmo")
AddEventHandler("weapon:saveAmmo", function(data)
    local _data = data
    local _source = source
    TriggerEvent("player:savInvSv", _source, _data)
end)

RegisterServerEvent("player:savInvSv")
AddEventHandler('player:savInvSv', function(source, data)
    local _source = source
    local _data = data
    local eq
    TriggerEvent('redemrp:getPlayerFromId', _source, function(user)
        if user ~= nil then
            local identifier = user.getIdentifier()
            local charid = user.getSessionVar("charid")

            if(invTable[identifier .. "_" .. charid])then
                eq = invTable[identifier .. "_" .. charid].inventory
                local itemCount = 0
                for name,value in pairs(invTable[identifier .. "_" .. charid].inventory) do
                    if name ~= nil then
                        itemCount = itemCount + 1
                    end
                    if itemCount > 1 then
                        if tonumber(value) ~= nil then
                            if value < 1 then
                                eq[name] = nil
                            end
                        end
                    end
                end
                if _data ~= nil then
                    eq = _data
                    invTable[identifier .. "_" .. charid].inventory = _data
                end
                MySQL.Async.execute('UPDATE user_inventory SET items = @items WHERE identifier = @identifier AND charid = @charid', {
                    ['@identifier']  = identifier,
                    ['@charid']  = charid,
                    ['@items'] = json.encode(eq)
                }, function (rowsChanged)
                    if rowsChanged == 0 then
                        print(('user_inventory: Something went wrong saving %s!'):format(identifier .. ":" .. charid))
                    end
                end)
            end
        end

    end)
end)

AddEventHandler('playerDropped', function()
    local _source = source
    TriggerEvent("player:savInvSv", _source)
    TriggerEvent('redemrp:getPlayerFromId', _source, function(user)
        if user ~= nil then
            local identifier = user.getIdentifier()
            local charid = user.getSessionVar("charid")

            if(invTable[identifier .. "_" .. charid])then
                invTable[identifier .. "_" .. charid] = nil
            end
        end
    end)
end)



Citizen.CreateThread(function()
    while true do
        Wait(600000)
        local eq
        local saved  = 0
        for i,k in pairs(invTable) do
            eq = k.inventory
            local itemCount = 0
            for name,value in pairs(k.inventory) do
                if name ~= nil then
                    itemCount = itemCount + 1
                end
                if itemCount > 1 then
                    if value == 0 then
                        eq[name] = nil
                    end
                end
            end
            saved = saved + 1
            MySQL.Async.execute('UPDATE user_inventory SET items = @items WHERE identifier = @identifier AND charid = @charid', {
                ['@identifier']  = k.id,
                ['@charid']  = k.charid,
                ['@items'] = json.encode(eq)
            }, function (rowsChanged)
                if rowsChanged == 0 then
                    print(('user_inventory: Something went wrong saving %s!'):format(k.id .. ":" .. k.charid))
                end
            end)
            Wait(150)
        end
    end

end)



AddEventHandler("item:add", function(source, arg)
    local _source = source
    local name = tostring(arg[1])
    local amount = arg[2]
    local hash2 = arg[3]
    local hash
    if tonumber(hash2) == nil then
        hash = GetHashKey(hash2)
    else
        hash = hash2
    end
    TriggerEvent('redemrp:getPlayerFromId', _source, function(user)
        local identifier = user.getIdentifier()
        local charid = user.getSessionVar("charid")

        if(invTable[identifier .. "_" .. charid])then
            if hash == 1 then
                if inventory.checkItem(_source, name) + amount <= inventory.checkLimit(_source,name) then
                    if k.inventory[name] ~= nil then
                        local val = invTable[identifier .. "_" .. charid]["inventory"][name]
                        newVal = val + amount
                        invTable[identifier .. "_" .. charid]["inventory"][name]= tonumber(newVal)
                    else
                        invTable[identifier .. "_" .. charid]["inventory"][name]= tonumber(amount)
                    end
                else
                    local drop = (inventory.checkItem(_source, name) + amount) - inventory.checkLimit(_source, name)
                    invTable[identifier .. "_" .. charid]["inventory"][name]= tonumber(inventory.checkLimit(_source, name))
                    TriggerClientEvent('item:pickup',_source, name, drop , 1)
                end
            else
                invTable[identifier .. "_" .. charid]["inventory"][name]= {tonumber(amount)  , hash}
                TriggerClientEvent("player:giveWeapon", _source, tonumber(amount) , hash )
            end
            TriggerClientEvent("gui:getItems", _source, k.inventory)
        end

    end)
end)
AddEventHandler("item:delete", function(source, arg)
    local _source = source
    local name = tostring(arg[1])
    local amount = tonumber(arg[2])
    TriggerEvent('redemrp:getPlayerFromId', _source, function(user)
        local identifier = user.getIdentifier()
        local charid = user.getSessionVar("charid")

        if(invTable[identifier .. "_" .. charid])then
            local inventory = invTable[identifier .. "_" .. charid]
            if tonumber(inventory[name]) ~= nil then
                local val = inventory[name]
                newVal = val - amount
                inventory[name]= tonumber(newVal)
            else
                inventory[name]= nil
                TriggerClientEvent("player:removeWeapon", _source, tonumber(amount) , hash )
            end
            TriggerClientEvent("gui:getItems", _source, inventory)
            TriggerClientEvent('gui:ReloadMenu', _source)
        end
    end)
end)


RegisterServerEvent("item:onpickup")
AddEventHandler("item:onpickup", function(id)
    local _source = source
    local pickup  = Pickups[id]
    TriggerEvent("item:add", _source ,{pickup.name, pickup.amount ,pickup.hash})
    TriggerClientEvent("item:Sharepickup", -1, pickup.name, pickup.obj , pickup.amount, x, y, z, 2)
    TriggerClientEvent('item:removePickup', -1, pickup.obj)
    Pickups[id] = nil
    TriggerClientEvent('player:anim', _source)
    TriggerClientEvent('gui:ReloadMenu', _source)
end)



RegisterCommand('giveitem', function(source, args)
    local _source = source
    TriggerEvent('redemrp:getPlayerFromId', _source, function(user)
        if user.getGroup() == 'superadmin' and _source ~= 0 then
            local identifier = user.getIdentifier()
            local charid = user.getSessionVar("charid")

            if(invTable[identifier .. "_" .. charid])then
                local item = args[1]
                local amount = args[2]
                local test = 1
                TriggerEvent("item:add", _source, {item, amount, test}, identifier , charid)
                TriggerClientEvent('gui:ReloadMenu', _source)
            end
        end
    end)
end)

RegisterServerEvent("item:use")
AddEventHandler("item:use", function(val)
    local _source = source
    local name = val
    local amount = 1
    local DisplayName2 = name
    if Config.Labels[name] ~= nil then
        DisplayName2 = Config.Labels[name]
    end
    TriggerEvent("RegisterUsableItem:"..name, _source)
    TriggerClientEvent('redem_roleplay:NotifyLeft',_source, "Item used", DisplayName2, "generic_textures", "tick", tonumber(1000))
    TriggerClientEvent('gui:ReloadMenu', _source)


end)



RegisterServerEvent("item:drop")
AddEventHandler("item:drop", function(val, amount , hash)
    local _source = source
    local value
    local _hash = 1
    _hash = hash
    local name = val

    value = inventory.checkItem(_source, name)
    if _hash == 1 then

        local all = value-amount
        if all >= 0 then
            TriggerClientEvent('item:pickup',_source, name, amount , 1)
            TriggerEvent("item:delete", _source, {name , amount})
        end

    else

        TriggerClientEvent('item:pickup',_source, name, amount , _hash)
        TriggerEvent("item:delete", _source, {name , amount})
    end
    TriggerClientEvent('gui:ReloadMenu', _source)

end)


RegisterServerEvent("item:SharePickupServer")
AddEventHandler("item:SharePickupServer", function(name, obj , amount, x, y, z , hash)
    TriggerClientEvent("item:Sharepickup", -1, name, obj , amount, x, y, z, 1, hash)
    Pickups[obj] = {
        name = name,
        obj = obj,
        amount = amount,
        hash = hash,
        inRange = false,
        coords = {x = x, y = y, z = z}
    }
end)


function checkItem(_source, name)
    local value = 0
    TriggerEvent('redemrp:getPlayerFromId', _source, function(user)
        local identifier = user.getIdentifier()
        local charid = user.getSessionVar("charid")

        if(invTable[identifier .. "_" .. charid])then
            value = invTable[identifier .. "_" .. charid]["inventory"][name]

            if tonumber(value) == nil then
                value = 0
            end
        end
    end)
    return tonumber(value)
end

function inventory.checkItem(_source, name)
    local  value = checkItem(_source, name)
    return tonumber(value)
end

function inventory.checkLimit(_source, name)
    local value = 64
    if Config.Limit[name] ~= nil then
        value = Config.Limit[name]
    end
    return tonumber(value)
end

function inventory.addItem(_source, name , amount ,hash)
    TriggerEvent('redemrp:getPlayerFromId', _source, function(user)
        local identifier = user.getIdentifier()
        local charid = user.getSessionVar("charid")
        if hash == nil or hash == 0 then
            local test = 1
            TriggerEvent("item:add", _source ,{name, amount , test})
        else
            TriggerEvent("item:add", _source ,{name, amount , hash})
        end
    end)
end

function inventory.delItem(_source, name , amount)
    TriggerEvent('redemrp:getPlayerFromId', _source, function(user)
        local identifier = user.getIdentifier()
        local charid = user.getSessionVar("charid")

        TriggerEvent("item:delete", _source, {name , amount})
    end)
end

RegisterServerEvent("redemrp_inventory:deleteInv")
AddEventHandler("redemrp_inventory:deleteInv", function(charid, Callback)
    local _source = source
    local id
    for k,v in ipairs(GetPlayerIdentifiers(_source))do
        if string.sub(v, 1, string.len("steam:")) == "steam:" then
            id = v
            break
        end
    end


    if(invTable[id .. "_" .. charid])then
        invTable[identifier .. "_" .. charid] = nil
    end

    local Callback = callback
    MySQL.Async.fetchAll('DELETE FROM user_inventory WHERE `identifier`=@identifier AND `charid`=@charid;', {identifier = id, charid = charid}, function(result)
        if result then
        else
        end
    end)
end)

--------EXAMPLE---------Register Usable item---------------EXAMPLE
RegisterServerEvent("RegisterUsableItem:compass")
AddEventHandler("RegisterUsableItem:compass", function(source)
    TriggerClientEvent('redemrp_inventory:compass', source)
end)
------------------------EXAMPLE----------------------------EXAMPLE


