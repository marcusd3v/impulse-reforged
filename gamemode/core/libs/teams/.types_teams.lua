---@class impulse.Teams.TeamData.Class
---@field name string Class name
---@field description string Class description
---@field doorGroup table A table of door groups that this class has access to  
---@field xp number The amount of XP required to play as this class
---@field itemsAdd table A table of items to add to the player's inventory when they become this class
---@field bodygroups table<number, number> A table of bodygroups to apply to the player when they become this class
---@field noMenu boolean Whether or not this class should be hidden from the F4 menu
---@field nomodel boolean Whether or not this class should not have a model
---@field noSubMats boolean? Whether or not this class should not have submaterials
---@field whitelistUID string The UID of the whitelist that this class requires
---@field whitelistLevel number The level of the whitelist that this class requires
---@field whitelistFailMessage string The message to display when a player fails the whitelist check
---@field customCheck function A custom check function to determine if a player can become this class
---@field ambientSounds table A table of ambient sounds that this class has
---@field percentLimit boolean Whether or not the limit is a percentage of the server population
---@field limit number The maximum amount of players that can be on this class
---@field loadoutAdd string[] A table of weapons to give to the player when they become this team
---@field skin number?
---@field model string? The model to give to the player when they become this class
---@field armour number? The amount of armour to give to the player when they become this class
---@field onBecome fun(player: Player) A function to run when the player becomes this rank

---@class impulse.Teams.TeamData.Rank
---@field name string Rank name
---@field description string Rank description
---@field doorGroup table A table of door groups that this rank has access to
---@field xp number The amount of XP required to play as this rank
---@field itemsAdd table A table of items to add to the player's inventory when they become this rank
---@field bodygroupOverrides table<number, number>|table<number, table<number, number>> A table of bodygroup overrides to apply to the player when they become this rank
---@field loadoutAdd string[] A table of weapons to give to the player when they become this team
---@field skin number?
---@field subMaterial table<number, string>? A table of submaterials to apply to the player when they become this rank
---@field spawns table<Vector>
---@field ambientSounds table A table of ambient sounds that this rank has
---@field whitelistLevel number The level of the whitelist that this rank requires
---@field customCheck function A custom check function to determine if a player can become this rank
---@field percentLimit boolean Whether or not the limit is a percentage of the server population
---@field limit number The maximum amount of players that can be on this rank. Or a percentage if percentLimit is true
---@field whitelistFailMessage string The message to display when a player fails the whitelist check
---@field model string? The model to give to the player when they become this rank
---@field onBecome fun(player: Player) A function to run when the player becomes this rank

---@class impulse.Teams.TeamData
---@field name string Team name
---@field color Color Team color
---@field donatorOnly boolean Whether or not this team is donator only
---@field xp number The amount of XP required to play as this team
---@field cp boolean Whether or not this team is a CP team
---@field limit number The maximum amount of players that can be on this team
---@field percentLimit boolean Whether or not the limit is a percentage of the server population
---@field customCheck function A custom check function to determine if a player can become this team
---@field classes impulse.Teams.TeamData.Class[] A table of classes that this team has
---@field ranks impulse.Teams.TeamData.Rank[] A table of ranks that this team has
---@field ambientSounds table A table of ambient sounds that this team has
---@field whitelistUID string The UID of the whitelist that this team requires
---@field whitelistLevel number The level of the whitelist that this team requires
---@field whitelistFailMessage string The message to display when a player fails the whitelist check
---@field rankRequired boolean Whether or not a rank is required to play as this team
---@field rankRef table A table of rank references
---@field classRef table A table of class references
---@field codeName string The code name of the team
---@field index number The index of the team
---@field ClassRef table A table of class references
---@field RankRef table A table of rank references
---@field bodygroups table<number, number>? A table of bodygroups to apply to the player when they become this team
---@field loadoutAdd string[] A table of weapons to give to the player when they become this team
---@field skin number?
---@field model string|function<Player>? The model to give to the player when they become this team
---@field spawns? table<Vector> A table of spawn points for this team
---@field itemsAdd table[] A table of items to give to the player when they become this team
---@field doorGroup number? The door group that this team has access to
---@field runSpeed number? The run speed of the player when they become this team
---@field onBecome fun(player: Player) A function to run when the player becomes this team
---@field max number? The maximum amount of players that can be on this team

---@class impulse.Teams.WhitelistDBEntry
---@field id number
---@field steamid string
---@field team string
---@field level number