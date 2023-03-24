
function CreateItem (name, amount, meta)
    local self = {}
    self.data = Config.Items[name]
    self.name = name
    self.amount = amount
    self.meta = meta

    local rTable = {}

    rTable.getAmount = function()
        return self.amount
    end
	
	rTable.getName = function()
        return self.name
    end

    rTable.addAmount = function(number)
        if number > 0 then
            self.amount = self.amount + tonumber(number)
        end
    end
	
	rTable.setAmount = function(number)
        if number >= 0 then
            self.amount =  tonumber(number)
        end
    end
  
    rTable.setMeta = function(meta)
         self.meta = meta
    end

    rTable.removeAmount = function(number)
        if number > 0 and self.amount - tonumber(number) >= 0 then
            self.amount = self.amount - tonumber(number)
        end
        if self.data.type == "item_standard" then
            if self.amount == 0 then
                return true
            else
                return false
            end
        end
    end

    rTable.getData = function()
        return self.data
    end

    rTable.getMeta = function()
        return self.meta
    end

    if self.meta.expire then 
        rTable.getExpireHours = function()
            local year, month, day, hour, minute = tonumber(os.date('%Y')), tonumber(os.date('%m')), tonumber(os.date('%d')), tonumber(os.date('%H')), tonumber(os.date('%M'))
            local a = os.time{year=self.meta.expire.year, month=self.meta.expire.month, day=self.meta.expire.day, hour=self.meta.expire.hour,min=self.meta.expire.min}
            local current = os.time{year=year, month=month, day=day,hour=hour,min=minute}
            local diff_hours = (os.difftime(a, current))/3600
            return diff_hours
        end
    end

    return rTable
end



function CreateInventory(items)
    local items_table = {}
    local weight = 0.0
    for i,k in pairs(items) do
        local meta = k.meta or {}
	local name = i
        if type(i) ~= "string" then
           name = k.name
        end
		if Config.Items[name] then
            table.insert(items_table, CreateItem(name, k.amount, meta))
            if items_table[#items_table].getData().type == "item_standard" then
                weight = weight + items_table[#items_table].getData().weight * k.amount
            else
                weight = weight + items_table[#items_table].getData().weight
            end
		end
    end
    return items_table, weight 
end


function PrepareToOutput(items)
    local items_table = {}
	local _items = items or {}
	local id = 0
    for i,k in pairs(_items) do
        local desc = k.getData().description
        local m = k.getMeta()
        if m.expire then 
            local showmonth = m.expire.month
            if showmonth < 10 then showmonth = "0"..showmonth end
            local showday= m.expire.day
            if showday < 10 then showday = "0"..showday end
            local showhour = m.expire.hour
            if showhour < 10 then showhour = "0"..showhour end
            local showmin = m.expire.min
            if showmin < 10 then showmin = "0"..showmin end
            local diff_hours = k.getExpireHours()
            print(diff_hours)
            local color = "white"
            if diff_hours < 1 then color = "red" elseif diff_hours > 0 and diff_hours < 24 then color = "orange" elseif diff_hours >= 24 then color = "green" end
            desc = desc.."<br><span style='color:"..color.."'>Expire: "..m.expire.year..". "..showmonth..". "..showday.."., "..showhour..":"..showmin.."</span>"
        end
		table.insert(items_table ,{name = k.getName(), amount = k.getAmount(), meta = k.getMeta(), label = k.getData().label , type = k.getData().type , weaponHash = k.getData().weaponHash ,  weight = k.getData().weight , description = desc, imgsrc = k.getData().imgsrc})
	end
    return items_table
end
