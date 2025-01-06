--- Handles the creation and editing of player groups
-- @module impulse.Group

impulse.Group = impulse.Group or {}
impulse.Group.Groups = impulse.Group.Groups or {}
impulse.Group.Invites = impulse.Group.Invites or {}

RPGROUP_PERMISSIONS = {
    [0] = "Is default group",
    [2] = "Post to group chat",
    [3] = "Can add members",
    [4] = "Can remove members",
    [5] = "Can promote/demote members",
    [6] = "Can edit ranks",
    [8] = "Can edit info page",
    [99] = "Is owner group"
    --[7] = "Access group storage",
    --[8] = ""
}

local PLAYER = FindMetaTable("Player")

function PLAYER:GroupHasPermission(act)
    local group = self:GetNetVar("groupName", nil)
    local rank = self:GetNetVar("groupRank", nil)

    if not group or not rank then return false end

    local groupData = impulse.Group.Groups[group]

    if ( CLIENT ) then
        groupData = impulse.Group.Groups[1]
    end

    if not groupData then return false end

    if not groupData.Ranks then return false end
    
    if not groupData.Ranks[rank] then return false end

    if groupData.Ranks[rank][99] then -- is owner
        return true
    end

    if not groupData.Ranks[rank][act] then return false end

    return true
end