Hooks = Hooks or {}

local fridgePattern = "fridge"
local durabilityIncrease = 2

local cache = {} --[[ @as table<string, { degrade: number } | false> ]]

---@param itemname string
---@return { degrade: number } | boolean
local function hasDegrade(itemname)
	if cache[itemname] then return cache[itemname] end

	local item = exports.ox_inventory:Items(itemname)
	if not item then return false end

	cache[itemname] = type(item.degrade) == 'number' and { degrade = item.degrade } or false

	return cache[itemname]
end

Hooks.Fridge = function ()
	exports.ox_inventory:registerHook('swapItems',
	---@param payload SwapItemsPayload
	---@return boolean
	function (payload)
		lib.print.info('swap item data', payload)

		-- boolean values
		local toFridge = type(payload.toInventory) == "string" and type(payload.toInventory:match(fridgePattern)) == "string"
		local fromFridge = type(payload.fromInventory) == "string" and type(payload.fromInventory:match(fridgePattern)) == "string"

		-- indicates that the items stayed in the originating inventory
		if toFridge == fromFridge then
			return true
		end

		local item = payload.fromSlot
		local degradeable = hasDegrade(item.name)

		lib.print.info({ item = item.name, degradeable = degradeable, toFridge = toFridge, fromFridge = fromFridge })

		if not degradeable or item.metadata.durability == 0 then return true end

		local currentTime = os.time()
		local secondsLeft = item.metadata.durability - currentTime
		if secondsLeft <= 0 then return true end

		lib.print.info('Item is subject to degrade update')

		local inventory = payload.toInventory
		local slotId = type(payload.toSlot) == "number" and payload.toSlot or payload.toSlot.slot --[[ @as number ]]

		local newDegrade = toFridge and (
			degradeable.degrade * durabilityIncrease
		) or (
			degradeable.degrade
		)

		local newDurability = math.floor(currentTime + (
			toFridge and (
				secondsLeft * durabilityIncrease
			) or (
				secondsLeft / durabilityIncrease
			)
		))

		Citizen.SetTimeout(100, function ()
			lib.print.info('cur meta for item', item.metadata)
			local newMeta = item.metadata

			newMeta.degrade = newDegrade
			newMeta.durability = newDurability

			lib.print.info('new meta for item', newMeta)

			exports.ox_inventory:SetMetadata(
				inventory, slotId, newMeta
			)
		end)

		return true
	end, {
		inventoryFilter = {
			fridgePattern,
		}
	})

	lib.print.info('Initialized Fridge inventory hook')
end
