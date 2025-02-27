--- Allows interactions with the players inventory
-- @module impulse.Inventory

INVENTORY_NIL = 0
INVENTORY_PLAYER = 1
INVENTORY_STORAGE = 2

impulse.Inventory = impulse.Inventory or {}
impulse.Inventory.Data = impulse.Inventory.Data or {}
impulse.Inventory.Data[0] = impulse.Inventory.Data[0] or {}
impulse.Inventory.Items = impulse.Inventory.Items or {}
impulse.Inventory.ItemsStored = impulse.Inventory.ItemsStored or {}
impulse.Inventory.ItemsQW = impulse.Inventory.ItemsQW or {}
impulse.Inventory.Benches = impulse.Inventory.Benches or {}
impulse.Inventory.Mixtures = impulse.Inventory.Mixtures or {}
impulse.Inventory.MixturesStored = impulse.Inventory.MixturesStored or {}
impulse.Inventory.CraftInfo = impulse.Inventory.CraftInfo or {}

if (CLIENT) then
    impulse.Inventory.Data[0][INVENTORY_PLAYER] = impulse.Inventory.Data[0][INVENTORY_PLAYER] or {}
    impulse.Inventory.Data[0][INVENTORY_STORAGE] = impulse.Inventory.Data[0][INVENTORY_STORAGE] or {}
end

local count = 1
local countX = 1

--- Registers a new inventory item
--- @realm shared
--- @param item impulse.Inventory.ItemData
--- @internal
function impulse.Inventory:RegisterItem(item)
    local class = item.WeaponClass
    local attachmentClass = item.AttachmentClass

    if (class) then
        function item:OnEquip(ply, data, uid, sec)
            local weapon = ply:Give(class)
            if (IsValid(weapon)) then
                weapon:SetClip1(item.WeaponOverrideClip or self.clip or 0)

                if (item.WeaponOverrideClip) then
                    weapon.PairedItem = uid
                end
            end
        end

        function item:UnEquip(ply)
            local weapon = ply:GetWeapon(class)
            if (IsValid(weapon)) then
                self.clip = weapon:Clip1()
                ply:StripWeapon(class)
            end

            if (ply.InvAttachments) then
                local uid = ply.InvAttachments[class]

                if uid and ply:HasInventoryItemSpecific(uid) then
                    ply.doForcedInvEquip = true
                    ply:SetInventoryItemEquipped(uid, false)
                end
            end
        end
    elseif (attachmentClass) then
        function item:CanEquip(ply)
            if (ply.doForcedInvEquip) then
                ply.doForcedInvEquip = nil
                return true -- hacky needs replacement
            end

            for k, v in pairs(ply:GetWeapons()) do
                if (IsValid(v) and v.IsLongsword and v.Attachments and v.Attachments[attachmentClass]) then
                    return true
                end
            end

            return false
        end

        function item:OnEquip(ply, class, uid)
            local weapon = ply:GetActiveWeapon()

            weapon:GiveAttachment(attachmentClass)

            ply.InvAttachments = ply.InvAttachments or {}
            ply.InvAttachments[weapon:GetClass()] = uid
        end

        function item:UnEquip(ply, class, uid)
            for k, v in pairs(ply:GetWeapons()) do
                if (IsValid(v) and v.IsLongsword and v.Attachments and v.Attachments[attachmentClass] and v:HasAttachment(attachmentClass)) then
                    v:TakeAttachment(attachmentClass)
                    ply.InvAttachments[v:GetClass()] = nil
                    return
                end
            end

            ply.InvAttachments = {} -- if the loop fails clear attach table
        end
    end

    local craftSound = item.CraftSound
    local craftTime = item.CraftTime

    if (craftSound or craftTime) then
        impulse.Inventory.CraftInfo[item.UniqueID] = {
            time = craftTime or nil,
            sound = craftSound or nil
        }
    end

    impulse.Inventory.Items[count] = item -- this is done the wrong way round yea yea ik
    impulse.Inventory.ItemsStored[item.UniqueID] = count
    impulse.Inventory.ItemsQW[item.UniqueID] = (item.Weight or 1)

    count = count + 1
end

--- Registers a new workbench
-- @realm shared
-- @param benchData Bench data
-- @internal
function impulse.Inventory:RegisterBench(bench)
    local class = bench.Class

    impulse.Inventory.Benches[class] = bench
    impulse.Inventory.Mixtures[class] = {}
end

--- Registers a new mixture
-- @realm shared
-- @param mixData Mixture data
-- @internal
function impulse.Inventory:RegisterMixture(mix)
    local class = mix.Class
    local bench = mix.Bench

    mix.NetworkID = countX

    impulse.Inventory.Mixtures[bench][class] = mix
    impulse.Inventory.MixturesStored[countX] = { bench, class }

    countX = countX + 1
end

--- Used to convert the class to the item's NetID (or table ref)
-- @realm shared
-- @string class Item class name
-- @treturn int Item net ID
function impulse.Inventory:ClassToNetID(class)
    return impulse.Inventory.ItemsStored[class]
end

--- Used to get the crafting time and the sounds to play
-- @realm shared
-- @string class Item class name
-- @treturn int Time
-- @treturn table Table of sounds
function impulse.Inventory:GetCraftingTime(mix)
    local items = mix.Input
    local time = 0
    local sounds = {}

    for k, v in pairs(items) do
        local hasCustom = impulse.Inventory.CraftInfo[k]

        for i = 1, v.take do
            if (hasCustom and hasCustom.sound) then
                table.insert(sounds, { time, hasCustom.sound })
            else
                table.insert(sounds, { time, "generic" })
            end

            time = time + ((hasCustom and hasCustom.time) or 3)
        end
    end

    return time, sounds
end

--- A collection of crafting types, each uses a different set of sounds
-- @realm client
-- @table CraftingTypes
local sounds = {
    ["chemical"] = 3,
    ["electronics"] = 3,
    ["fabric"] = 6,
    ["fuel"] = 3,
    ["generic"] = 3,
    ["gunmetal"] = 3,
    ["metal"] = 3,
    ["nuclear"] = 2,
    ["plastic"] = 4,
    ["powder"] = 3,
    ["rock"] = 4,
    ["water"] = 3,
    ["wood"] = 6
}

--- Used to pick a random crafting sound for the correct crafting type
-- @realm shared
-- @string[opt=generic] craftType Crafting type
-- @see CraftingTypes
-- @treturn string The random crafting sound based on the crafting type (eg: if type is wood then return wood2.wav)
function impulse.Inventory:PickRandomCraftSound(crafttype)
    local max = sounds[crafttype]
    if (! max) then
        crafttype = "generic"
    end

    return "impulse-reforged/craft/" .. crafttype .. "/" .. math.random(1, max) .. ".wav"
end

--- Player class methods
-- @classmod Player

local PLAYER = FindMetaTable("Player")

--- Returns the max capacity of the players storage box
-- @realm shared
-- @treturn int Capacity (in kg)
function PLAYER:GetMaxInventoryStorage()
    if self:IsDonator() then
        return impulse.Config.InventoryStorageMaxWeightDonator
    end

    return impulse.Config.InventoryStorageMaxWeight
end

if (CLIENT) then
    --- Returns if a client has an inventory item and how much they have
    -- @realm client
    -- @int itemId Item Network ID (use impulse.Inventory:ClassToNetID)
    -- @see impulse.Inventory:ClassToNetID
    -- @treturn bool Has item
    -- @treturn int Amount
    function PLAYER:HasInventoryItem(id)
        if (self:Team() == 0) then
            return false
        end

        local inv = impulse.Inventory.Data[0][INVENTORY_PLAYER]
        local has = false
        local count

        for k, v in pairs(inv) do
            if (v.id == id) then
                has = true
                count = (count or 0) + 1
            end
        end

        return has, count
    end
end
