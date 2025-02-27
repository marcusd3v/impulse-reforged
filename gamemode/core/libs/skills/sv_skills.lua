--- @class Player
--- @field impulseSkills table<string, number>

---@class Player
local PLAYER = FindMetaTable("Player")

--- @param name string
---@return number?
function PLAYER:GetSkillXP(name)
    local skills = self.impulseSkills
    if not skills then return end

    if skills[name] then
        return skills[name]
    else
        return 0
    end
end

---@param self Player
---@param name string
---@param value number
function PLAYER:SetSkillXP(name, value)
    if not self.impulseSkills then return end
    if not impulse.Skills.Skills[name] then return end

    value = math.Round(value)

    self.impulseSkills[name] = value

    local data = util.TableToJSON(self.impulseSkills)

    if data then
        local query = mysql:Update("impulse_players")
        query:Update("skills", data)
        query:Where("steamid", self:SteamID64())
        query:Execute()
    end

    self:NetworkSkill(name, value)
end

---@param name string
---@param value number
function PLAYER:NetworkSkill(name, value)
    net.Start("impulseSkillUpdate")
    net.WriteUInt(impulse.Skills.Skills[name], 4)
    net.WriteUInt(value, 16)
    net.Send(self)
end

---@param name string
---@param value number
function PLAYER:AddSkillXP(name, value)
    if not self.impulseSkills then return end

    local cur = self:GetSkillXP(name)
    local new = math.Round(math.Clamp(cur + value, 0, 4500))

    if cur != new then
        self:SetSkillXP(name, new)
        hook.Run("PlayerAddSkillXP", self, new, name)
    end
end

---@param name string
---@param value number
function PLAYER:TakeSkillXP(name, value)
    if not self.impulseSkills then return end

    local cur = self:GetSkillXP(name)
    local new = math.Round(math.Clamp(cur - value, 0, 4500))

    if cur != new then
        self:SetSkillXP(name, new)
        hook.Run("PlayerTakeSkillXP", self, new, name)
    end
end