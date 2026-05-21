Hooks = Hooks or {}

local adminAcePerms = {
	'hooks:admininv',
}

for i = 1, #adminAcePerms do
	lib.addAce('group.admin', adminAcePerms[i])
end

local adminInvStashId

local function canUseAdminInv(src)
	for j = 1, #adminAcePerms do
		if IsPlayerAceAllowed(src, adminAcePerms[j]) then
			return true
		end
	end

	return false
end

local function registerAdminInvStash()
	local itemList = lib.require('@ox_inventory.modules.items.shared')
	local itemCount = 0
	local maxWeight = 0
	local items = {}

	lib.print.info('loaded inventory item list')

	for item, data in pairs(itemList) do
		if item == 'identification' then goto continue end

		local count = 50

		if data.stack == false then
			count = 1
		end

		items[#items+1] = { item, count }
		maxWeight += data.weight * count
		itemCount += 1

	    ::continue::
	end

	local id = exports.ox_inventory:CreateTemporaryStash({
		label = 'Admin Item Inventory',
		slots = itemCount,
		maxWeight = maxWeight,
		items = items,
	})

	adminInvStashId = id
end

---@param payload SwapItemsPayload
---@return boolean
local function idealHandlePreSwap(payload)
	if not canUseAdminInv(payload.source) then
		lib.print.warn(('Player %d tried to use admin inventory when not ace allowed !'):format(payload.source))
		return false
	end

	if payload.action == 'swap' then
		lib.notify(payload.source, {
			title = 'Action Denied',
			description = 'You can not swap items with this inventory',
			type = 'warning'
		})
	end

	return false
end

---@param success boolean
---@param payload SwapItemsPayload
local function idealHandlePostSwap(success, payload)
	-- shouldn't succeed
	if success then return end
	-- no swapping
	if payload.action == 'swap' then return end

	local src = payload.source
	local count = payload.count
	local item = payload.fromSlot

	local addSuccess = exports.ox_inventory:AddItem(src, item.name, count)

	if not addSuccess then
		lib.notify(payload.source, {
			title = 'Action Failed',
			description = 'Something went wrong',
			type = 'error'
		})
	end
end

---@param payload SwapItemsPayload
---@return boolean
local function unidealHandleSwap(payload)
	if not canUseAdminInv(payload.source) then
		lib.print.warn(('Player %d tried to use admin inventory when not ace allowed !'):format(payload.source))
		return false
	end

	if payload.action == 'swap' then
		lib.notify(payload.source, {
			title = 'Action Denied',
			description = 'You can not swap items with this inventory',
			type = 'warning'
		})
		return false
	end

	local src = payload.source
	local count = payload.count
	local item = payload.fromSlot

	Citizen.SetTimeout(100, function()
        local addSuccess = exports.ox_inventory:AddItem(src, item.name, count)

		if not addSuccess then
			lib.notify(payload.source, {
				title = 'Action Failed',
				description = 'Something went wrong',
				type = 'error'
			})
		end
    end)

	return true
end

Hooks.AdminInvOpen = function ()
	if not adminInvStashId then
		registerAdminInvStash()

		while not adminInvStashId do Wait(50) end
	end

	---@param payload OpenInventoryPayload
	RegisterHookAction('openInventory', function (payload)
		if not canUseAdminInv(payload.source) then
			lib.print.warn(('Player %d tried to open admin inventory when not ace allowed !'):format(payload.source))
			return false
		end

		return true
	end, nil, { adminInvStashId })

	lib.print.info('Initialized Admin inventory openInventory hook')
end

Hooks.AdminInvSwap = function ()
	if not adminInvStashId then
		registerAdminInvStash()

		while not adminInvStashId do Wait(50) end
	end

    local useIdeal = IsInventoryMinimumVersion()
    local before, after

    if useIdeal then
		before = idealHandlePreSwap
        after = idealHandlePostSwap
    else
        before = unidealHandleSwap
    end

    RegisterHookAction('swapItems', before, after, { adminInvStashId })

	lib.print.info('Initialized Admin inventory swapItems hook')
end

lib.addCommand('adminitems', {
	help = 'Open inventory with all items',
	restricted = 'group.admin',
}, function (source, args, raw)
	exports.ox_inventory:forceOpenInventory(source, 'stash', adminInvStashId)
end)
