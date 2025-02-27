local logs = impulse.Logs

util.AddNetworkString("impulseATMDeposit")
util.AddNetworkString("impulseATMOpen")
util.AddNetworkString("impulseATMWithdraw")
util.AddNetworkString("impulseAchievementGet")
util.AddNetworkString("impulseAchievementSync")
util.AddNetworkString("impulseBenchUse")
util.AddNetworkString("impulseBuyItem")
util.AddNetworkString("impulseChangeRPName")
util.AddNetworkString("impulseCharacterCreate")
util.AddNetworkString("impulseCharacterEdit")
util.AddNetworkString("impulseCharacterEditorOpen")
util.AddNetworkString("impulseChatMessage")
util.AddNetworkString("impulseChatState")
util.AddNetworkString("impulseCinematicMessage")
util.AddNetworkString("impulseClassChange")
util.AddNetworkString("impulseChatText")
util.AddNetworkString("impulseConfiscateCheck")
util.AddNetworkString("impulseDoConfiscate")
util.AddNetworkString("impulseDoorAdd")
util.AddNetworkString("impulseDoorBuy")
util.AddNetworkString("impulseDoorLock")
util.AddNetworkString("impulseDoorRemove")
util.AddNetworkString("impulseDoorSell")
util.AddNetworkString("impulseDoorUnlock")
util.AddNetworkString("impulseGetButtons")
util.AddNetworkString("impulseGetRefund")
util.AddNetworkString("impulseGroupDoCreate")
util.AddNetworkString("impulseGroupDoDelete")
util.AddNetworkString("impulseGroupDoInvite")
util.AddNetworkString("impulseGroupDoInviteAccept")
util.AddNetworkString("impulseGroupDoLeave")
util.AddNetworkString("impulseGroupDoRankAdd")
util.AddNetworkString("impulseGroupDoRankRemove")
util.AddNetworkString("impulseGroupDoRemove")
util.AddNetworkString("impulseGroupDoSetColor")
util.AddNetworkString("impulseGroupDoSetInfo")
util.AddNetworkString("impulseGroupDoSetRank")
util.AddNetworkString("impulseGroupInvite")
util.AddNetworkString("impulseGroupMember")
util.AddNetworkString("impulseGroupMemberRemove")
util.AddNetworkString("impulseGroupMetadata")
util.AddNetworkString("impulseGroupRank")
util.AddNetworkString("impulseGroupRanks")
util.AddNetworkString("impulseJoinData")
util.AddNetworkString("impulseMixDo")
util.AddNetworkString("impulseMixTry")
util.AddNetworkString("impulseNotify")
util.AddNetworkString("impulseQuizForce")
util.AddNetworkString("impulseQuizSubmit")
util.AddNetworkString("impulseRagdollLink")
util.AddNetworkString("impulseReadNote")
util.AddNetworkString("impulseRequestWhitelists")
util.AddNetworkString("impulseScenePVS")
util.AddNetworkString("impulseSellAllDoors")
util.AddNetworkString("impulseSkillUpdate")
util.AddNetworkString("impulseSurfaceSound")
util.AddNetworkString("impulseTeamChange")
util.AddNetworkString("impulseUnRestrain")
util.AddNetworkString("impulseUpdateDefaultModelSkin")
util.AddNetworkString("impulseUpdateOOCLimit")
util.AddNetworkString("impulseVendorBuy")
util.AddNetworkString("impulseVendorSell")
util.AddNetworkString("impulseVendorUse")
util.AddNetworkString("impulseVendorUseDownload")
util.AddNetworkString("impulseViewWhitelists")
util.AddNetworkString("impulseZoneUpdate")
util.AddNetworkString("impulsePlayGesture")
util.AddNetworkString("impulseClearWorkbar")
util.AddNetworkString("impulseMakeWorkbar")

local AUTH_FAILURE = "Invalid argument (rejoin to continue)"

net.Receive("impulseCharacterCreate", function(len, ply)
    if (ply.NextCreate or 0) > CurTime() then return end
    ply.NextCreate = CurTime() + 10

    local charName = net.ReadString()
    local charModel = net.ReadString()
    local charSkin = net.ReadUInt(8)

    local plyID = ply:SteamID64()
    local timestamp = math.floor(os.time())
    local canUseName, filteredName = impulse.CanUseName(charName)

    if canUseName then
        charName = filteredName
    else
        return ply:Kick(AUTH_FAILURE)
    end

    if (! table.HasValue(impulse.Config.DefaultMaleModels, charModel) && ! table.HasValue(impulse.Config.DefaultFemaleModels, charModel)) then
        return ply:Kick(AUTH_FAILURE)
    end

    if (impulse.Config.DefaultSkinBlacklist) then
        local skinBlacklist = impulse.Config.DefaultSkinBlacklist[charModel]
        if skinBlacklist and table.HasValue(skinBlacklist, charSkin) then
            return ply:Kick(AUTH_FAILURE)
        end
    end

    local query = mysql:Select("impulse_players")
    query:Where("steamid", plyID)
    query:Callback(function(result)
        -- If we already have a rp name, we can't create a new character
        if istable(result) and #result > 0 and result[1].rpname and result[1].rpname != "" then
            logs:Info(ply:SteamName() .. " attempted to create a new character when they already have one.")
            ply:Kick("You already have a character, stop trying to exploit.")
            return
        end

        local insertQuery = mysql:Update("impulse_players")
        insertQuery:Update("steamid", plyID)
        insertQuery:Update("steamname", ply:SteamName())
        insertQuery:Update("group", "user")
        insertQuery:Update("xp", 0)
        insertQuery:Update("money", impulse.Config.StartingMoney)
        insertQuery:Update("bankmoney", impulse.Config.StartingBankMoney)
        insertQuery:Update("model", charModel)
        insertQuery:Update("skin", charSkin)
        insertQuery:Update("firstjoin", timestamp)
        insertQuery:Update("lastjoin", timestamp)
        insertQuery:Update("data", "[]")
        insertQuery:Update("skills", "[]")
        insertQuery:Update("rpgroup", 0)
        insertQuery:Update("rpgrouprank", "[]")
        insertQuery:Update("address", "[]")
        insertQuery:Update("playtime", 0)
        insertQuery:Where("steamid", plyID)
        insertQuery:Callback(function(result, status, lastID)
            if IsValid(ply) then
                ---@type impulse.DataModels.Player
                local setupData = {
                    id = tonumber(lastID),
                    steamid = plyID,
                    steamname = ply:SteamName(),
                    group = "user",
                    xp = 0,
                    money = impulse.Config.StartingMoney,
                    bankmoney = impulse.Config.StartingBankMoney,
                    model = charModel,
                    data = {
                        rp_names = {
                            [NAMEGROUP_DEFAULT] = charName --[[@as string]]
                        }
                    },
                    ammo = {},
                    skills = {},
                    skin = charSkin,
                    firstjoin = timestamp,
                    lastjoin = timestamp,
                    rpgroup = 0,
                    rpgrouprank = "",
                    address = "",
                    playtime = 0
                }

                logs:Debug(ply:SteamName() .. " has created their character with the name \"" .. charName .. "\".")

                ply:Freeze(false)
                ply:AllowScenePVSControl(false) -- stop cutscene
                ply:SetRPName(charName, false)

                hook.Run("PlayerSetup", ply, setupData)
            end
        end)
        insertQuery:Execute()
    end)
    query:Execute()
end)

net.Receive("impulseScenePVS", function(len, ply)
    if (ply.nextPVSTry or 0) > CurTime() then return end
    ply.nextPVSTry = CurTime() + 0.1

    if ply:Team() == 0 or ply.allowPVS then -- this code needs to be looked at later on, it trusts client too much, pvs locations should be stored in a shared tbl
        local pos = net.ReadVector()
        local last = ply.lastPVS or 1

        if last == 1 then
            ply.extraPVS = pos
            ply.lastPVS = 2
        else
            ply.extraPVS2 = pos
            ply.lastPVS = 1
        end

        timer.Simple(1.33, function()
            if not IsValid(ply) then return end

            if last == 1 then
                ply.extraPVS2 = nil
            else
                ply.extraPVS = nil
            end
        end)
    end
end)

net.Receive("impulseChatMessage", function(len, ply) -- should implement a check on len here instead of string.len
    if (ply.nextChat or 0) < CurTime() then
        if len > 15000 then
            ply.nextChat = CurTime() + 0.1
            return
        end

        local text = net.ReadString()
        ply.nextChat = CurTime() + 0.3 + math.Clamp(#text / 300, 0, 4)

        text = string.sub(text, 1, 1024)
        text = string.Replace(text, "\n", "")
        hook.Run("PlayerSay", ply, text, false, true)
    end
end)

net.Receive("impulseATMWithdraw", function(len, ply)
    if (ply.nextATM or 0) > CurTime() or not ply.currentATM then return end
    if not IsValid(ply.currentATM) or (ply:GetPos() - ply.currentATM:GetPos()):LengthSqr() > (120 ^ 2) then return end

    local amount = net.ReadUInt(32)
    if not isnumber(amount) or amount < 1 or amount >= 1 / 0 or amount > 1000000000 then return end

    amount = math.floor(amount)

    if ply:CanAffordBank(amount) then
        ply:TakeBankMoney(amount)
        ply:AddMoney(amount)
        ply:Notify("You have withdrawn " .. impulse.Config.CurrencyPrefix .. amount .. " from your bank account.")
    else
        ply:Notify("You cannot afford to withdraw this amount of money.")
    end
    ply.nextATM = CurTime() + 0.1
end)

net.Receive("impulseATMDeposit", function(len, ply)
    if (ply.nextATM or 0) > CurTime() or not ply.currentATM then return end
    if not IsValid(ply.currentATM) or (ply:GetPos() - ply.currentATM:GetPos()):LengthSqr() > (120 ^ 2) then return end

    local amount = net.ReadUInt(32)
    if not isnumber(amount) or amount < 1 or amount >= 1 / 0 or amount > 10000000000 then return end

    amount = math.floor(amount)

    if ply:CanAfford(amount) then
        ply:TakeMoney(amount)
        ply:AddBankMoney(amount)
        ply:Notify("You have deposited " .. impulse.Config.CurrencyPrefix .. amount .. " to your bank account.")
    else
        ply:Notify("You cannot afford to deposit this amount of money.")
    end
    ply.nextATM = CurTime() + 0.1
end)

net.Receive("impulseTeamChange", function(len, ply)
    if (ply.lastTeamTry or 0) > CurTime() then return end
    ply.lastTeamTry = CurTime() + 0.1

    local teamChangeTime = impulse.Config.TeamChangeTime

    if ply:IsDonator() or ply:IsAdmin() then
        teamChangeTime = impulse.Config.TeamChangeTimeDonator
    end

    if ply.lastTeamChange and ply.lastTeamChange + teamChangeTime > CurTime() then
        ply:Notify("Wait " ..
            math.ceil((ply.lastTeamChange + teamChangeTime) - CurTime()) .. " seconds before switching team again.")
        return
    end

    local teamID = net.ReadUInt(8)
    local teamData = impulse.Teams:FindTeam(teamID)

    if teamData then
        if ply:CanBecomeTeam(teamID, true) then
            if teamData.quiz then
                local data = ply:GetNetVar(DATA_QUIZ)

                if not data or not data[teamData.codeName] then
                    if ply.nextQuiz and ply.nextQuiz > CurTime() then
                        ply:Notify("Wait" ..
                            string.NiceTime(math.ceil(CurTime() - ply.nextQuiz)) ..
                            " before attempting to retry the quiz.")
                        return
                    end

                    ply.quizzing = true
                    net.Start("impulseQuizForce")
                    net.WriteUInt(teamID, 8)
                    net.Send(ply)
                    return
                end
            end

            ply:SetTeam(teamID)
            ply.lastTeamChange = CurTime()
            ply:Notify("You have changed your team to " .. team.GetName(teamID) .. ".")
            ply:EmitSound("items/ammo_pickup.wav")
        end
    end
end)

net.Receive("impulseClassChange", function(len, ply)
    if (ply.lastTeamTry or 0) > CurTime() then return end
    ply.lastTeamTry = CurTime() + 0.1

    if ply:GetNetVar(NET_IS_INCOGNITO, false) then return end

    local classChangeTime = impulse.Config.ClassChangeTime

    if ply:IsAdmin() then
        classChangeTime = 5
    end

    if ply.lastClassChange and ply.lastClassChange + classChangeTime > CurTime() then
        ply:Notify("Wait " ..
            math.ceil((ply.lastClassChange + classChangeTime) - CurTime()) .. " seconds before switching class again.")
        return
    end

    local classID = net.ReadUInt(8)
    local classes = impulse.Teams.Stored[ply:Team()].classes

    if classID and isnumber(classID) and classID > 0 and classes and classes[classID] and ! classes[classID].noMenu then
        if ply:CanBecomeTeamClass(classID, true) then
            ply:SetTeamClass(classID)
            ply.lastClassChange = CurTime()
            ply:Notify("You have changed your class to " .. classes[classID].name .. ".")
        end
    end
end)

net.Receive("impulseBuyItem", function(len, ply)
    if (ply.nextBuy or 0) > CurTime() then return end
    ply.nextBuy = CurTime() + 0.1

    if ply:GetNetVar(NET_IS_INCOGNITO, false) or not ply:Alive() then return end

    local buyableID = net.ReadUInt(8)

    local buyableName = impulse.Business.Stored[buyableID]
    local buyable = impulse.Business.Data[buyableName]

    if buyable and ply:CanBuy(buyableName) and ply:CanAfford(buyable.price) then
        local item = buyable.item

        if item and ! ply:CanHoldItem(item) then
            ply:Notify("You do not have the inventory space to hold this item.")
            return
        end

        if not item then
            local count = 0

            ply.BusinessSpawnCount = ply.BusinessSpawnCount or {}

            for v, k in pairs(ply.BusinessSpawnCount) do
                if IsValid(k) then
                    count = count + 1
                else
                    ply.BusinessSpawnCount[v] = nil
                end
            end

            if count >= impulse.Config.BuyableSpawnLimit then
                ply:Notify("You have reached the buyable spawn limit.")
                return
            end
        end

        ply:TakeMoney(buyable.price)

        if item then
            ply:GiveItem(item)
        else
            local trace = {}
            trace.start = ply:EyePos()
            trace.endpos = trace.start + ply:GetAimVector() * 85
            trace.filter = ply

            local tr = util.TraceLine(trace)

            local ang = Angle(0, 0, 0)

            local ent = impulse.Business:SpawnBuyable(tr.HitPos, ang, buyable, ply)

            table.insert(ply.BusinessSpawnCount, ent)
        end

        ply:Notify("You have purchased " .. buyableName .. " for " .. impulse.Config.CurrencyPrefix .. buyable.price ..
            ".")

        hook.Run("PlayerBuyablePurchase", ply, buyableName)
    else
        ply:Notify("You cannot afford this purchase.")
    end
end)

net.Receive("impulseChatState", function(len, ply)
    if ((ply.impulseNextChatState or 0) > CurTime()) then return end
    ply.impulseNextChatState = CurTime() + 0.02

    local isTyping = net.ReadBool()
    local state = ply:GetNetVar(NET_IS_TYPING, false)

    if (state != isTyping) then
        ply:SetNetVar(NET_IS_TYPING, isTyping)

        hook.Run("ChatStateChanged", ply, state, isTyping)
    end
end)

net.Receive("impulseDoorBuy", function(len, ply)
    if (ply.nextDoorBuy or 0) > CurTime() then return end
    if not ply:Alive() or ply:GetNetVar(NET_IS_INCOGNITO, false) then return end

    local trace = {}
    trace.start = ply:EyePos()
    trace.endpos = trace.start + ply:GetAimVector() * 85
    trace.filter = ply

    local traceEnt = util.TraceLine(trace).Entity

    if IsValid(traceEnt) and ply:CanBuyDoor(traceEnt:GetNetVar(NET_DOOR_OWNERS, nil), traceEnt:GetNetVar(NET_IS_DOOR_BUYABLE, true)) and hook.Run("CanEditDoor", ply, traceEnt) != false then
        if ply:CanAfford(impulse.Config.DoorPrice) then
            ply:TakeMoney(impulse.Config.DoorPrice)
            ply:SetDoorMaster(traceEnt)

            ply:Notify("You have bought a door for " .. impulse.Config.CurrencyPrefix .. impulse.Config.DoorPrice .. ".")

            hook.Run("PlayerPurchaseDoor", ply, traceEnt)
        else
            ply:Notify("You cannot afford to buy this door.")
        end
    end
    ply.nextDoorBuy = CurTime() + 0.1
end)

net.Receive("impulseDoorSell", function(len, ply)
    if (ply.nextDoorSell or 0) > CurTime() then return end
    if not ply:Alive() or ply:GetNetVar(NET_IS_INCOGNITO, false) then return end

    local trace = {}
    trace.start = ply:EyePos()
    trace.endpos = trace.start + ply:GetAimVector() * 85
    trace.filter = ply

    local traceEnt = util.TraceLine(trace).Entity

    if IsValid(traceEnt) and ply:IsDoorOwner(traceEnt:GetNetVar(NET_DOOR_OWNERS, nil)) and traceEnt:GetDoorMaster() == ply and hook.Run("CanEditDoor", ply, traceEnt) != false then
        ply:RemoveDoorMaster(traceEnt)
        ply:AddMoney(impulse.Config.DoorPrice - 2)

        ply:Notify("You have sold a door for " .. impulse.Config.CurrencyPrefix .. (impulse.Config.DoorPrice - 2) .. ".")

        hook.Run("PlayerSellDoor", ply, traceEnt)
    end
    ply.nextDoorSell = CurTime() + 0.1
end)

net.Receive("impulseDoorLock", function(len, ply)
    if (ply.nextDoorLock or 0) > CurTime() then return end
    if not ply:Alive() or ply:GetNetVar(NET_IS_INCOGNITO, false) then return end

    local trace = {}
    trace.start = ply:EyePos()
    trace.endpos = trace.start + ply:GetAimVector() * 85
    trace.filter = ply

    local traceEnt = util.TraceLine(trace).Entity

    if IsValid(traceEnt) and traceEnt:IsDoor() then
        local doorOwners, doorGroup = traceEnt:GetNetVar(NET_DOOR_OWNERS, nil), traceEnt:GetNetVar(NET_DOOR_GROUP, nil)

        if ply:CanLockUnlockDoor(doorOwners, doorGroup) then
            traceEnt:DoorLock()
            traceEnt:EmitSound("doors/latchunlocked1.wav")
        end
    end

    ply.nextDoorLock = CurTime() + 0.1
end)

net.Receive("impulseDoorUnlock", function(len, ply)
    if (ply.nextDoorUnlock or 0) > CurTime() then return end
    if not ply:Alive() or ply:GetNetVar(NET_IS_INCOGNITO, false) then return end

    local trace = {}
    trace.start = ply:EyePos()
    trace.endpos = trace.start + ply:GetAimVector() * 85
    trace.filter = ply

    local traceEnt = util.TraceLine(trace).Entity

    if IsValid(traceEnt) and traceEnt:IsDoor() then
        local doorOwners, doorGroup = traceEnt:GetNetVar(NET_DOOR_OWNERS, nil), traceEnt:GetNetVar(NET_DOOR_GROUP, nil)

        if ply:CanLockUnlockDoor(doorOwners, doorGroup) then
            traceEnt:DoorUnlock()
            traceEnt:EmitSound("doors/latchunlocked1.wav")
        end
    end

    ply.nextDoorUnlock = CurTime() + 0.1
end)

net.Receive("impulseDoorAdd", function(len, ply)
    if (ply.nextDoorChange or 0) > CurTime() then return end
    ply.nextDoorChange = CurTime() + 0.1

    if not ply:Alive() or ply:GetNetVar(NET_IS_INCOGNITO, false) then return end

    local target = net.ReadEntity()

    if not IsValid(target) or not target:IsPlayer() or not ply.impulseBeenSetup then return end

    local cost = math.ceil(impulse.Config.DoorPrice / 2)

    if not ply:CanAfford(cost) then
        return ply:Notify("You cannot afford to add a player to this door.")
    end

    local trace = {}
    trace.start = ply:EyePos()
    trace.endpos = trace.start + ply:GetAimVector() * 85
    trace.filter = ply

    local traceEnt = util.TraceLine(trace).Entity
    local owners = traceEnt:GetNetVar(NET_DOOR_OWNERS, nil)

    if IsValid(traceEnt) and ply:IsDoorOwner(owners) and traceEnt:GetDoorMaster() == ply then
        if target == ply then return end

        if target.impulseOwnedDoors and target.impulseOwnedDoors[traceEnt] then return end

        if table.Count(owners) > 9 then
            return ply:Notify("Door user limit reached (9).")
        end

        ply:TakeMoney(cost)
        target:SetDoorUser(traceEnt)

        ply:Notify("You have added " .. target:Nick() .. " to this door for " .. impulse.Config.CurrencyPrefix ..
            cost .. ".")

        hook.Run("PlayerAddUserToDoor", ply, owners)
    end
end)

net.Receive("impulseDoorRemove", function(len, ply)
    if (ply.nextDoorChange or 0) > CurTime() then return end
    ply.nextDoorChange = CurTime() + 0.1

    if not ply:Alive() or ply:GetNetVar(NET_IS_INCOGNITO, false) then return end

    local target = net.ReadEntity()

    if not IsValid(target) or not target:IsPlayer() or not ply.impulseBeenSetup then return end

    local trace = {}
    trace.start = ply:EyePos()
    trace.endpos = trace.start + ply:GetAimVector() * 85
    trace.filter = ply

    local traceEnt = util.TraceLine(trace).Entity

    if IsValid(traceEnt) and ply:IsDoorOwner(traceEnt:GetNetVar(NET_DOOR_OWNERS, nil)) and traceEnt:GetDoorMaster() == ply then
        if target == ply then return end

        if not target.impulseOwnedDoors or not target.impulseOwnedDoors[traceEnt] then return end

        if traceEnt:GetDoorMaster() == target then
            return ply:Notify("The door's master cannot be removed.")
        end

        target:RemoveDoorUser(traceEnt)

        ply:Notify("You have removed " .. target:Nick() .. " from this door.")
    end
end)

net.Receive("impulseQuizSubmit", function(len, ply)
    if not ply.quizzing then return end
    ply.quizzing = false

    local teamID = net.ReadUInt(8)
    if not impulse.Teams.Stored[teamID] or not impulse.Teams.Stored[teamID].quiz then return end

    local quizPassed = net.ReadBool()

    if not quizPassed then
        ply.nextQuiz = CurTime() + (impulse.Config.QuizWaitTime * 60)
        return ply:Notify("Quiz failed. You may retry the quiz in " .. impulse.Config.QuizWaitTime .. " minutes.")
    end

    local data = ply:GetNetVar(DATA_QUIZ) or {}
    data[impulse.Teams.Stored[teamID].codeName] = true

    ply:SetNetVar(DATA_QUIZ, data)

    ply:Notify("You have passed the quiz. You will not need to retake it again.")

    if ply:CanBecomeTeam(teamID, true) then
        ply:SetTeam(teamID)
        ply:Notify("You have changed your team to " .. team.GetName(teamID) .. ".")
    else
        ply:Notify("You passed the quiz, however " ..
            team.GetName(teamID) .. " cannot be joined right now. Rejoin the team when it is available to play again.")
    end
end)

net.Receive("impulseSellAllDoors", function(len, ply)
    if (ply.nextSellAllDoors or 0) > CurTime() then return end
    ply.nextSellAllDoors = CurTime() + 5
    if not ply.impulseOwnedDoors or table.Count(ply.impulseOwnedDoors) == 0 then return end

    local sold = 0
    for v, k in pairs(ply.impulseOwnedDoors) do
        if IsValid(v) and hook.Run("CanEditDoor", ply, v) != false then
            if v:GetDoorMaster() == ply then
                local noUnlock = v.NoDCUnlock or false
                ply:RemoveDoorMaster(v, noUnlock)
                sold = sold + 1
            else
                ply:RemoveDoorUser(v)
            end
        end
    end

    ply.impulseOwnedDoors = {}

    local amount = sold * (impulse.Config.DoorPrice - 2)
    ply:AddMoney(amount)
    ply:Notify("You have sold all your doors for " .. impulse.Config.CurrencyPrefix .. amount .. ".")
end)

net.Receive("impulseChangeRPName", function(len, ply)
    if not ply.impulseBeenSetup then return end
    if (ply.nextRPNameTry or 0) > CurTime() then return end
    ply.nextRPNameTry = CurTime() + 0.1

    if impulse.Teams.Stored[ply:Team()] and impulse.Teams.Stored[ply:Team()].blockNameChange then
        return ply:Notify("Your team can not change their name.")
    end

    if (ply.nextRPNameChange or 0) > CurTime() then
        return ply:Notify("You must wait " ..
            string.NiceTime(ply.nextRPNameChange - CurTime()) .. " before changing your name again.")
    end

    local name = net.ReadString()

    if ply:CanAfford(impulse.Config.RPNameChangePrice) then
        local canUseName, output = impulse.CanUseName(name)

        if canUseName then
            ply:TakeMoney(impulse.Config.RPNameChangePrice)
            ply:SetRPName(output, true)

            hook.Run("PlayerChangeRPName", ply, output)

            ply.nextRPNameChange = CurTime() + 240
            ply:Notify("You have changed your name to " ..
                output .. " for " .. impulse.Config.CurrencyPrefix .. impulse.Config.RPNameChangePrice .. ".")
        else
            ply:Notify("Name rejected: " .. output)
        end
    else
        ply:Notify("You cannot afford to change your name.")
    end
end)

net.Receive("impulseCharacterEdit", function(len, ply)
    if not ply.impulseBeenSetup then return end
    if (ply.nextCharEditTry or 0) > CurTime() then return end
    ply.nextCharEditTry = CurTime() + 3

    if not ply.currentCosmeticEditor or not IsValid(ply.currentCosmeticEditor) or ply.currentCosmeticEditor:GetPos():DistToSqr(ply:GetPos()) > (120 ^ 2) then return end

    if ply:Team() != impulse.Config.DefaultTeamId then
        impulse.Logs:Debug("%s attempted to edit their character while not in the default team.", ply:SteamName())
        return
    end

    local newIsFemale = false
    local newModel = net.ReadString()
    local newSkin = net.ReadUInt(8)
    local cost = 0
    local isCurFemale = ply:IsCharacterFemale()
    local curModel = ply.impulseDefaultModel
    local curSkin = ply.impulseDefaultSkin

    if not table.HasValue(impulse.Config.DefaultMaleModels, newModel) and ! table.HasValue(impulse.Config.DefaultFemaleModels, newModel) then return end

    if table.HasValue(impulse.Config.DefaultFemaleModels, newModel) then
        newIsFemale = true
    end

    local skinBlacklist = impulse.Config.DefaultSkinBlacklist[newModel]

    if skinBlacklist and table.HasValue(skinBlacklist, newSkin) then return end

    if newIsFemale != isCurFemale then
        cost = cost + impulse.Config.CosmeticGenderPrice
    end

    if curModel != newModel or curSkin != newSkin then
        cost = cost + impulse.Config.CosmeticModelSkinPrice
    end

    if cost == 0 then return end

    if ply:CanAfford(cost) then
        local query = mysql:Update("impulse_players")
        query:Update("skin", newSkin)
        query:Update("model", newModel)
        query:Where("steamid", ply:SteamID64())
        query:Execute()

        ply.impulseDefaultModel = newModel
        ply.impulseDefaultSkin = newSkin

        ply:UpdateDefaultModelSkin()

        local oldBodyGroupsTemp = {}
        local oldBodyGroups = ply:GetBodyGroups()

        for v, k in pairs(oldBodyGroups) do
            oldBodyGroupsTemp[k.id] = ply:GetBodygroup(k.id)
        end

        ply:SetModel(ply.impulseDefaultModel)
        ply:SetSkin(ply.impulseDefaultSkin)

        for v, k in pairs(oldBodyGroups) do
            ply:SetBodygroup(k.id, oldBodyGroupsTemp[k.id])
        end

        ply:TakeMoney(cost)
        ply:Notify("You have changed your appearance for " .. impulse.Config.CurrencyPrefix .. cost .. ".")
    else
        ply:Notify("You cannot afford to change your appearance.")
    end

    ply.currentCosmeticEditor = nil
end)

net.Receive("impulseDoConfiscate", function(len, ply)
    if (ply.nextDoConfiscate or 0) > CurTime() then return end
    if not ply:IsCP() then return end

    local item = ply.ConfiscatingItem

    if not item or not IsValid(item) then return end

    local itemName = item.Item.Name

    if item:GetPos():DistToSqr(ply:GetPos()) < (200 ^ 2) then
        ply:Notify("You have confiscated a " .. itemName .. ".")
        item:Remove()
    end

    ply.nextDoConfiscate = CurTime() + 0.1
end)

net.Receive("impulseMixTry", function(len, ply)
    if (ply.nextMixTry or 0) > CurTime() then return end
    ply.nextMixTry = CurTime() + 0.1

    if ply.IsCrafting then
        return -- already crafting
    end

    if not ply:Alive() or ply:GetNetVar(NET_IS_INCOGNITO, false) then
        return -- ded or arrested
    end

    if ply:IsCP() then
        return -- is cp
    end

    local bench = ply.currentBench

    if not bench or not IsValid(bench) or bench:GetPos():DistToSqr(ply:GetPos()) > (120 ^ 2) then
        return -- bench not real or too far from
    end

    if bench.InUse then
        return ply:Notify("This workbench is already in use.")
    end

    local benchEnt = bench

    local mix = net.ReadUInt(8)
    local mixClass = impulse.Inventory.MixturesStored[mix]

    if not mixClass then return end

    local bench = mixClass[1]
    mix = mixClass[2]

    mixClass = impulse.Inventory.Mixtures[bench][mix]

    local output = mixClass.Output
    local takeWeight = 0

    if not ply:CanMakeMix(mixClass) then -- checks input items + craft level
        return
    end

    local oWeight = impulse.Inventory.ItemsQW[output]

    for v, k in pairs(mixClass.Input) do
        local iWeight = impulse.Inventory.ItemsQW[v]

        if iWeight then
            iWeight = iWeight * k.take
        end

        takeWeight = takeWeight + iWeight
    end

    if (ply.InventoryWeight - takeWeight) + oWeight >= impulse.Config.InventoryMaxWeight then
        return ply:Notify("You do not have the inventory space to craft this item.")
    end

    benchEnt.InUse = true

    local startTeam = ply:Team()
    local time, sounds = impulse.Inventory:GetCraftingTime(mixClass)
    ply.CraftFail = false

    for v, k in pairs(sounds) do
        timer.Simple(k[1], function()
            if not IsValid(ply) or not IsValid(benchEnt) or not ply:Alive() or ply:GetNetVar(NET_IS_INCOGNITO, false) or ply.CraftFail or benchEnt:GetPos():DistToSqr(ply:GetPos()) > (120 ^ 2) then
                if IsValid(ply) then
                    ply.CraftFail = true
                end

                return
            end

            local crafttype = k[2]
            local snd = impulse.Inventory:PickRandomCraftSound(crafttype)

            benchEnt:EmitSound(snd, 100)
        end)
    end

    hook.Run("PlayerStartCrafting", ply, mixClass.Output)

    if benchEnt.Bench.OnCraft then
        benchEnt.Bench.OnCraft(benchEnt, ply, mixClass)
    end

    timer.Simple(time, function()
        if IsValid(benchEnt) then
            benchEnt.InUse = false
        end

        if IsValid(ply) and ply:Alive() and IsValid(benchEnt) and ply:CanMakeMix(mixClass) then
            if benchEnt:GetPos():DistToSqr(ply:GetPos()) > (120 ^ 2) then return end

            if ply.CraftFail then return end

            if ply:GetNetVar(NET_IS_INCOGNITO, false) or ply:IsCP() then return end

            if startTeam != ply:Team() then return end

            local item = impulse.Inventory.Items[impulse.Inventory:ClassToNetID(mixClass.Output)]

            for v, k in pairs(mixClass.Input) do
                ply:TakeInventoryItemClass(v, nil, k.take)
            end

            local amount = mixClass.OutputAmount or 1

            for i = 1, amount do
                ply:GiveItem(mixClass.Output)
            end

            if (amount > 1) then
                ply:Notify("You have crafted a " .. item.Name .. ".")
            else
                ply:Notify("You have crafted " .. amount .. " " .. item.Name .. "es .")
            end

            local xp = 28 + ((math.Clamp(mixClass.Level, 2, 9) * 1.8) * 2) -- needs balancing

            if mixClass.XPMultiplier then
                xp = xp * mixClass.XPMultiplier
            end

            ply:AddSkillXP("craft", xp)

            hook.Run("PlayerCraftItem", ply, mixClass.Output)
        end
    end)

    net.Start("impulseMixDo") -- send response to allow crafting to client
    net.Send(ply)
end)

net.Receive("impulseVendorBuy", function(len, ply)
    if (ply.nextVendorBuy or 0) > CurTime() then return end
    ply.nextVendorBuy = CurTime() + 0.1

    if not ply.currentVendor or not IsValid(ply.currentVendor) then return end

    local vendor = ply.currentVendor

    if (ply:GetPos() - vendor:GetPos()):LengthSqr() > (120 ^ 2) then return end

    if ply:GetNetVar(NET_IS_INCOGNITO, false) or not ply:Alive() then return end

    local canUse = hook.Run("CanUseInventory", ply)

    if canUse != nil and canUse == false then return end

    if vendor.Vendor.CanUse and vendor.Vendor.CanUse(vendor, ply) == false then return end

    local class = net.ReadString()

    if string.len(class) > 128 then return end

    local sellData = vendor.Vendor.Sell[class]

    if not sellData then return end

    if sellData.Cost and ! ply:CanAfford(sellData.Cost) then return end

    if sellData.Max then
        local hasItem, amount = ply:HasInventoryItem(class)

        if hasItem and amount >= sellData.Max then return end
    end

    if sellData.CanBuy and sellData.CanBuy(ply) == false then return end

    if not ply:CanHoldItem(class) then
        return ply:Notify("You don't have enough inventory space to hold this item.")
    end

    if sellData.Cooldown then
        ply.VendorCooldowns = ply.VendorCooldowns or {}
        local cooldown = ply.VendorCooldowns[class]

        if cooldown and cooldown > CurTime() then
            return ply:Notify("Please wait " ..
                string.NiceTime(cooldown - CurTime()) .. " before attempting to purchase this item again.")
        else
            ply.VendorCooldowns[class] = CurTime() + sellData.Cooldown
        end
    end

    if sellData.BuyMax then
        ply.VendorBuyMax = ply.VendorBuyMax or {}
        local tMax = ply.VendorBuyMax[class]

        if tMax then
            if tMax.Cooldown and tMax.Cooldown > CurTime() then
                local cooldown = tMax.Cooldown

                return ply:Notify("This vendor has no more of this item to give you. Come back in " ..
                    string.NiceTime(cooldown - CurTime()) .. " for more.")
            elseif tMax.Cooldown then
                ply.VendorBuyMax[class] = {
                    Count = 0,
                    Cooldown = nil
                }
            end

            if ply.VendorBuyMax[class].Count >= sellData.BuyMax then
                local cooldown = CurTime() + sellData.TempCooldown
                ply.VendorBuyMax[class].Cooldown = cooldown

                return ply:Notify("This vendor has no more of this item to give you. Come back in " ..
                    string.NiceTime(cooldown - CurTime()) .. " for more.")
            end
        else
            ply.VendorBuyMax[class] = {
                Count = 0
            }
        end

        tMax = ply.VendorBuyMax[class]

        ply.VendorBuyMax[class].Count = ((tMax and tMax.Count) or 0) + 1

        if tMax then
            if ply.VendorBuyMax[class].Count >= sellData.BuyMax then
                local cooldown = CurTime() + sellData.TempCooldown
                ply.VendorBuyMax[class].Cooldown = cooldown
            end
        end
    end

    local item = impulse.Inventory.Items[impulse.Inventory:ClassToNetID(class)]

    if sellData.Cost then
        ply:TakeMoney(sellData.Cost)
        ply:Notify("You have purchased " .. item.Name .. " for " .. impulse.Config.CurrencyPrefix .. sellData.Cost .. ".")
    else
        ply:Notify("You have acquired a " .. item.Name .. ".")
    end

    ply:GiveItem(class, 1, sellData.Restricted or false)

    if vendor.Vendor.OnItemPurchased then
        vendor.Vendor.OnItemPurchased(vendor, class, ply)
    end

    hook.Run("PlayerVendorBuy", ply, vendor, class, sellData.Cost or 0)
end)

net.Receive("impulseVendorSell", function(len, ply)
    if (ply.nextVendorSell or 0) > CurTime() then return end
    ply.nextVendorSell = CurTime() + 0.1

    if not ply.currentVendor or not IsValid(ply.currentVendor) then return end

    local vendor = ply.currentVendor

    if (ply:GetPos() - vendor:GetPos()):LengthSqr() > (120 ^ 2) then return end

    if ply:GetNetVar(NET_IS_INCOGNITO, false) or not ply:Alive() then return end

    local canUse = hook.Run("CanUseInventory", ply)

    if canUse != nil and canUse == false then return end

    if vendor.Vendor.CanUse and vendor.Vendor.CanUse(vendor, ply) == false then return end

    if vendor.Vendor.MaxBuys and (vendor.Buys or 0) >= vendor.Vendor.MaxBuys then
        return ply:Notify("This vendor can not afford to purchase this item.")
    end

    local itemid = net.ReadUInt(16)
    local hasItem, itemData = ply:HasInventoryItemSpecific(itemid)

    if not hasItem then return end

    if itemData.restricted then return end

    local class = itemData.class

    local buyData = vendor.Vendor.Buy[class]
    local itemName = impulse.Inventory.Items[impulse.Inventory:ClassToNetID(class)].Name

    if not buyData then return end

    if buyData.CanBuy and buyData.CanBuy(ply) == false then return end

    if vendor.Vendor.MaxBuys then
        vendor.Buys = (vendor.Buys or 0) + 1
    end

    ply:TakeInventoryItem(itemid)

    if buyData.Cost then
        ply:AddMoney(buyData.Cost)
        ply:Notify("You have sold a " .. itemName .. " for " .. impulse.Config.CurrencyPrefix .. buyData.Cost .. ".")
    else
        ply:Notify("You have handed over a " .. itemName .. ".")
    end

    hook.Run("PlayerVendorSell", ply, vendor, class, buyData.Cost or "free")
end)

net.Receive("impulseRequestWhitelists", function(len, ply)
    if (ply.nextWhitelistReq or 0) > CurTime() then return end
    ply.nextWhitelistReq = CurTime() + 5

    local id = net.ReadUInt(8)
    local targ = Entity(id)

    if targ and IsValid(targ) and targ:IsPlayer() and targ.Whitelists then
        local whitelists = targ.Whitelists
        local count = 0

        for v, k in pairs(whitelists) do
            if isnumber(v) then
                count = count + 1
            end
        end

        net.Start("impulseViewWhitelists")
        net.WriteUInt(count, 4)

        for v, k in pairs(whitelists) do
            if isnumber(v) then
                net.WriteUInt(v, 8)
                net.WriteUInt(k, 8)
            end
        end

        net.Send(ply)
    end
end)

net.Receive("impulseUnRestrain", function(len, ply)
    if (ply.nextUnRestrain or 0) > CurTime() then return end
    ply.nextUnRestrain = CurTime() + 0.1

    local trace = {}
    trace.start = ply:EyePos()
    trace.endpos = trace.start + ply:GetAimVector() * 85
    trace.filter = ply

    local tr = util.TraceLine(trace)
    local ent = tr.Entity

    if not ent or not IsValid(ent) then return end

    if not ent:IsPlayer() or ent:GetNetVar(NET_IS_INCOGNITO, false) == false or not ply:CanArrest(ent) then return end

    if ent.impulseBeingJailed then return end

    if ent.InJail then
        return ply:Notify("You can't unrestrain someone who is in jail.")
    end

    ent:UnArrest()

    ply:Notify("You have released " .. ent:Name() .. ".")
    ent:Notify("You have been released by " .. ply:Name() .. ".")

    hook.Run("PlayerUnArrested", ent, ply)
    hook.Run("PlayerUnRestrain", ply, ent)
end)

net.Receive("impulseInvContainerCodeReply", function(len, ply)
    if (ply.nextPassCodeTry or 0) > CurTime() then return end
    ply.nextPassCodeTry = CurTime() + 3

    local container = ply.currentContainerPass

    if not container or not IsValid(container) then return end

    if not ply:Alive() then return end

    if (ply:GetPos() - container:GetPos()):LengthSqr() > (120 ^ 2) then return end

    local code = net.ReadUInt(16)
    code = math.floor(code)

    if code < 0 then return end

    if code == container.Code then
        container:AddAuthorised(ply)
        container:AddUser(ply)

        ply:Notify("Passcode accepted.")
    else
        ply:Notify("Incorrect container passcode.")
    end
end)

net.Receive("impulseInvContainerClose", function(len, ply)
    local container = ply.currentContainer

    if container then
        if IsValid(container) and container.Users[ply] then
            container:RemoveUser(ply)
        else
            ply.currentContainer = nil
        end
    end
end)

net.Receive("impulseInvContainerDoMove", function(len, ply)
    if (ply.nextInvMove or 0) > CurTime() then return end
    ply.nextInvMove = CurTime() + 0.1

    local container = ply.currentContainer

    if not container or not IsValid(container) then return end

    if container:GetPos():DistToSqr(ply:GetPos()) > (120 ^ 2) then return end

    local isLoot = container.GetLoot and container:GetLoot() or false
    if isLoot then
        if ply:IsCP() then return end
    elseif container.Code and ! container.Authorised[ply] then
        return
    end

    if ply:GetNetVar(NET_IS_INCOGNITO, false) or not ply:Alive() then return end

    local canUse = hook.Run("CanUseInventory", ply)

    if canUse != nil and canUse == false then return end

    local itemid = net.ReadUInt(16)
    local from = net.ReadUInt(4)
    local to = 1

    if from != 1 and from != 2 then return end

    if from == 1 then
        to = 2
    end

    if from == 2 then
        local item = impulse.Inventory.Items[itemid]
        if not item then return end

        local class = impulse.Inventory.Items[itemid].UniqueID

        if not container.Inventory[class] then return end

        if not ply:CanHoldItem(class) then
            return ply:Notify("Item is too heavy to hold.")
        end

        if item.Illegal and ply:IsCP() then
            container:TakeItem(class)
            return ply:Notify(item.Name .. " (illegal item) destroyed.")
        end

        container:TakeItem(class, 1, true)
        ply:GiveItem(class)
        container:UpdateUsers()
    elseif from == 1 then
        local hasItem, item = ply:HasInventoryItemSpecific(itemid, 1)

        if not hasItem then return end

        if item.restricted then
            return ply:Notify("You cannot store a restricted item.")
        end

        if not container:CanHoldItem(item.class) then
            return ply:Notify("Item is too heavy to store.")
        end

        ply:TakeInventoryItem(itemid)
        container:AddItem(item.class)
    end
end)

net.Receive("impulseInvContainerRemovePadlock", function(len, ply)
    if (ply.nextPadlockBreak or 0) > CurTime() then return end
    ply.nextPadlockBreak = CurTime() + 6

    if not ply:IsCP() then return end

    local trace = {}
    trace.start = ply:EyePos()
    trace.endpos = trace.start + ply:GetAimVector() * 85
    trace.filter = ply

    local tr = util.TraceLine(trace)
    local ent = tr.Entity

    if not ent or not IsValid(ent) then return end

    if ent:GetClass() != "impulse_container" then return end

    ent:SetCode(nil)
    ply:Notify("Padlock removed from container.")
end)

net.Receive("impulseInvContainerDoSetCode", function(len, ply)
    if (ply.nextSetContCode or 0) > CurTime() then return end
    ply.nextSetContCode = CurTime() + 0.1

    if not ply.ContainerCodeSet or not IsValid(ply.ContainerCodeSet) then return end

    local container = ply.ContainerCodeSet

    if container:CPPIGetOwner() != ply then return end

    local passcode = net.ReadUInt(16)
    passcode = math.floor(passcode)

    if passcode < 1000 or passcode > 9999 then return end

    container:SetCode(passcode)
    ply.ContainerCodeSet = nil

    ply:Notify("You have set the containers passcode to " .. passcode .. ".")

    hook.Run("ContainerPasscodeSet", ply, container)
end)

local NCHANGE_ANTISPAM = NCHANGE_ANTISPAM or {}
net.Receive("impulseGroupDoRankAdd", function(len, ply)
    if (ply.nextRPGroupRankEdit or 0) > CurTime() then return end
    ply.nextRPGroupRankEdit = CurTime() + 0.1

    if ply:IsCP() then return end

    local name = ply:GetNetVar(NET_GROUP_NAME, nil)
    local rank = ply:GetNetVar(NET_GROUP_RANK, nil)

    if not name or not rank then return end

    local groupData = impulse.Group.Groups[name]

    if not groupData then return end

    if not ply:GroupHasPermission(6) then return end

    local rankName = net.ReadString()
    local nChange = net.ReadBool()
    local newName
    if nChange then
        if NCHANGE_ANTISPAM[name] and NCHANGE_ANTISPAM[name] > CurTime() then
            return ply:Notify("Wait a few seconds before changing a ranks name...")
        else
            NCHANGE_ANTISPAM[name] = CurTime() + 7
        end

        newName = string.sub(net.ReadString(), 1, 32)

        if string.Trim(newName, " ") == "" then
            return ply:Notify("Invalid rank name.")
        end

        if groupData.Ranks[newName] then
            return ply:Notify("This rank name is already in use.")
        end
    end

    local permissions = {}
    local isDefault = false
    local isOwner = false

    local r = groupData.Ranks[rankName]
    if r then
        if r[99] then
            isOwner = true
        end

        if r[0] then
            isDefault = true
        end
    else
        local isBig = false
        if groupData.MemberCount >= 30 then
            isBig = true
        end

        if isBig then
            if table.Count(groupData.Ranks) >= impulse.Config.GroupMaxRanksVIP then
                return ply:Notify("Max ranks reached.")
            end
        elseif table.Count(groupData.Ranks) >= impulse.Config.GroupMaxRanks then
            return ply:Notify("Max ranks reached. (once the group reaches 30 members you will unlock more)")
        end

        rankName = string.sub(rankName, 1, 32)

        if string.Trim(rankName, " ") == "" then
            return ply:Notify("Invalid rank name.")
        end
    end

    for v, k in pairs(RPGROUP_PERMISSIONS) do
        local permId = net.ReadUInt(8)
        local enabled = net.ReadBool()

        -- protected permissions that can not be changed
        if permId == 0 or permId == 99 then
            if isOwner then
                permissions[99] = true
            end

            if isDefault then
                permissions[0] = true
            end

            continue
        end

        if enabled then
            permissions[permId] = true
        end
    end

    if nChange then
        impulse.Group.Groups[name].Ranks[rankName] = nil
    end

    impulse.Group.Groups[name].Ranks[newName or rankName] = permissions

    if nChange then
        impulse.Group:RankShift(name, rankName, newName)
    end

    impulse.Group:NetworkRanksToOnline(name)
    impulse.Group:UpdateRanks(groupData.ID, impulse.Group.Groups[name].Ranks)
end)

local INVITE_ANTISPAM = INVITE_ANTISPAM or {}
net.Receive("impulseGroupDoInvite", function(len, ply)
    if (ply.nextRPGroupRankInv or 0) > CurTime() then return end
    ply.nextRPGroupRankInv = CurTime() + 0.1

    if ply:IsCP() then return end

    local name = ply:GetNetVar(NET_GROUP_NAME, nil)
    local rank = ply:GetNetVar(NET_GROUP_RANK, nil)

    if not name or not rank then return end

    local groupData = impulse.Group.Groups[name]

    if not groupData then return end

    if not ply:GroupHasPermission(3) then return end

    local targ = net.ReadEntity()

    if not IsValid(targ) or not targ:IsPlayer() or not targ.impulseBeenSetup or targ:GetNetVar(NET_GROUP_NAME, nil) then return end

    if targ.GroupInvites and targ.GroupInvites[name] then
        return ply:Notify("This player already has a pending invite for this group.")
    end

    if groupData.MemberCount >= groupData.MaxSize then
        return ply:Notify("This group is full.")
    end

    if INVITE_ANTISPAM[name] and INVITE_ANTISPAM[name].Amount > 8 then
        if INVITE_ANTISPAM[name].Expire > CurTime() then
            return ply:Notify("Please wait a while before sending more invites.")
        end

        INVITE_ANTISPAM[name].Amount = 0
    end

    INVITE_ANTISPAM[name] = INVITE_ANTISPAM[name] or {}

    INVITE_ANTISPAM[name].Amount = (INVITE_ANTISPAM[name].Amount or 0) + 1
    INVITE_ANTISPAM[name].Expire = CurTime() + 360

    targ.GroupInvites = targ.GroupInvites or {}
    targ.GroupInvites[name] = true

    net.Start("impulseGroupInvite")
    net.WriteString(name)
    net.WriteString(ply:Nick())
    net.Send(targ)

    ply:Notify("You invited " .. targ:Nick() .. " to your group.")
end)

net.Receive("impulseGroupDoInviteAccept", function(len, ply)
    if (ply.nextRPGroupRankAccept or 0) > CurTime() then return end
    ply.nextRPGroupRankAccept = CurTime() + 6

    if ply:IsCP() then return end

    local name = ply:GetNetVar(NET_GROUP_NAME, nil)
    local rank = ply:GetNetVar(NET_GROUP_RANK, nil)

    if name or rank then return end

    local name = net.ReadString()

    local groupData = impulse.Group.Groups[name]

    if not groupData then return end

    if not ply.GroupInvites or not ply.GroupInvites[name] then return end

    if groupData.MemberCount >= groupData.MaxSize then
        return ply:Notify("This group is full.")
    end

    ply.GroupInvites[name] = nil

    ply:GroupAdd(name)
    ply:Notify("You have joined the " .. name .. " group.")
end)

net.Receive("impulseGroupDoRankRemove", function(len, ply)
    if (ply.nextRPGroupRankEdit or 0) > CurTime() then return end
    ply.nextRPGroupRankEdit = CurTime() + 0.1

    if ply:IsCP() then return end

    local name = ply:GetNetVar(NET_GROUP_NAME, nil)
    local rank = ply:GetNetVar(NET_GROUP_RANK, nil)

    if not name or not rank then return end

    local groupData = impulse.Group.Groups[name]

    if not groupData then return end

    if not ply:GroupHasPermission(6) then return end

    local rankName = net.ReadString()
    local r = groupData.Ranks[rankName]

    if not r then return end

    if r[99] or r[0] then return end

    impulse.Group:RankShift(name, rankName, impulse.Group:GetDefaultRank(name))
    impulse.Group.Groups[name].Ranks[rankName] = nil
    impulse.Group:NetworkRanksToOnline(name)
    impulse.Group:UpdateRanks(groupData.ID, impulse.Group.Groups[name].Ranks)
end)

net.Receive("impulseGroupDoSetRank", function(len, ply)
    if (ply.nextRPGroupRankSet or 0) > CurTime() then return end
    ply.nextRPGroupRankSet = CurTime() + 0.1

    if ply:IsCP() then return end

    local name = ply:GetNetVar(NET_GROUP_NAME, nil)
    local rank = ply:GetNetVar(NET_GROUP_RANK, nil)

    if not name or not rank then return end

    local groupData = impulse.Group.Groups[name]

    if not groupData then return end

    if not ply:GroupHasPermission(5) then return end

    local targ = net.ReadString()

    if not targ or not groupData.Members[targ] then return end

    local memberData = groupData.Members[targ]

    if groupData.Ranks[memberData.Rank][99] then -- its the owner!!!
        return ply:Notify("You can not change the rank of the group owner.")
    end

    local targEnt = player.GetBySteamID(targ)
    local rankName = net.ReadString()
    local r = groupData.Ranks[rankName]

    if not r then return end

    if r[99] then return end

    if rankName == memberData.Rank then
        return ply:Notify("This player is already set to this rank.")
    end

    local n = targ

    if IsValid(targEnt) then
        targEnt:GroupAdd(name, rankName)
        targEnt:Notify(ply:Nick() .. " set your group rank to " .. rankName .. ".")
        n = targEnt:Nick()
    else
        impulse.Group:UpdatePlayerRank(targ, rankName)
        impulse.Group.Groups[name].Members[targ].Rank = rankName
        impulse.Group:NetworkMemberToOnline(name, targ)
    end

    ply:Notify("You set the group rank of " .. n .. " to " .. rankName .. ".")
end)

net.Receive("impulseGroupDoRemove", function(len, ply)
    if (ply.nextRPGroupRankSet or 0) > CurTime() then return end
    ply.nextRPGroupRankSet = CurTime() + 0.1

    if ply:IsCP() then return end

    local name = ply:GetNetVar(NET_GROUP_NAME, nil)
    local rank = ply:GetNetVar(NET_GROUP_RANK, nil)

    if not name or not rank then return end

    local groupData = impulse.Group.Groups[name]

    if not groupData then return end

    if not ply:GroupHasPermission(4) then return end

    local targ = net.ReadString()

    if not targ or not groupData.Members[targ] then return end

    local memberData = groupData.Members[targ]

    if groupData.Ranks[memberData.Rank][99] then -- its the owner!!!
        return ply:Notify("You can not remove the group owner.")
    end

    if targ == ply:SteamID64() then
        return ply:Notify("You can not remove yourself.")
    end

    local targEnt = player.GetBySteamID(targ)
    local n = targ

    if IsValid(targEnt) then
        targEnt:GroupRemove(name)
        targEnt:Notify(ply:Nick() .. " has removed you from the " .. name .. " group.")
        n = targEnt:Nick()
    else
        impulse.Group:RemovePlayer(targ, groupData.ID)
        impulse.Group.Groups[name].Members[targ] = nil
        impulse.Group:NetworkMemberRemoveToOnline(name, targ)
    end

    ply:Notify("You removed " .. n .. " from the group.")
end)

net.Receive("impulseGroupDoCreate", function(len, ply)
    if (ply.nextRPGroupCreate or 0) > CurTime() then return end
    ply.nextRPGroupCreate = CurTime() + 4

    if not ply.impulseID then return end

    if ply:IsCP() then return end

    if ply:GetXP() < impulse.Config.GroupXPRequirement then return end

    if not ply:CanAfford(impulse.Config.GroupMakeCost) then return end

    local curName = ply:GetNetVar(NET_GROUP_NAME, nil)
    local rank = ply:GetNetVar(NET_GROUP_RANK, nil)

    if name or curName then return end

    local name = string.Trim(string.sub(net.ReadString(), 1, 32), " ")

    if name == "" then
        return ply:Notify("Invalid group name.")
    end

    if impulse.Group.Groups[name] then
        return ply:Notify("This group name is already in use.")
    end

    local slots = ply:IsDonator() and impulse.Config.GroupMaxMembersVIP or impulse.Config.GroupMaxMembers

    impulse.Group:Create(name, ply.impulseID, slots, 30, nil, function(groupid)
        if not IsValid(ply) then return end

        if not groupid then
            return ply:Notify("This group name is already in use.")
        end

        ply:TakeMoney(impulse.Config.GroupMakeCost)

        impulse.Group:AddPlayer(ply:SteamID64(), groupid, "Owner", function()
            if not IsValid(ply) then return end

            ply:GroupLoad(groupid, "Owner")
            ply:Notify("You have created a new group called " .. name .. ".")
        end)
    end)
end)

net.Receive("impulseGroupDoDelete", function(len, ply)
    if (ply.nextRPGroupDelete or 0) > CurTime() then return end
    ply.nextRPGroupDelete = CurTime() + 3

    if ply:IsCP() then return end

    local name = ply:GetNetVar(NET_GROUP_NAME, nil)
    local rank = ply:GetNetVar(NET_GROUP_RANK, nil)

    if not name or not rank then return end

    local groupData = impulse.Group.Groups[name]

    if not groupData or not groupData.ID then return end

    if not ply:GroupHasPermission(99) then return end

    for v, k in pairs(groupData.Members) do
        local targEnt = player.GetBySteamID(v)

        if IsValid(targEnt) then
            targEnt:SetNetVar(NET_GROUP_NAME, nil)
            targEnt:SetNetVar(NET_GROUP_RANK, nil)
            targEnt:Notify("You were removed from the " .. name .. " group as it has been deleted by the owner.")
        end
    end

    impulse.Group.Groups[name] = nil
    impulse.Group:Remove(groupData.ID)
    impulse.Group:RemovePlayerMass(groupData.ID)

    ply:Notify("You deleted the " .. name .. " group.")
end)

net.Receive("impulseGroupDoLeave", function(len, ply)
    if (ply.nextRPGroupDelete or 0) > CurTime() then return end
    ply.nextRPGroupDelete = CurTime() + 3

    if ply:IsCP() then return end

    local name = ply:GetNetVar(NET_GROUP_NAME, nil)
    local rank = ply:GetNetVar(NET_GROUP_RANK, nil)

    if not name or not rank then return end

    local groupData = impulse.Group.Groups[name]

    if not groupData then return end

    if ply:GroupHasPermission(99) then return end

    ply:GroupRemove(name)
    ply:Notify("You have left the " .. name .. " group.")
end)

net.Receive("impulseGroupDoSetColor", function(len, ply)
    if (ply.nextRPGroupDataSet or 0) > CurTime() then return end
    ply.nextRPGroupDataSet = CurTime() + 0.1

    if ply:IsCP() then return end

    local name = ply:GetNetVar(NET_GROUP_NAME, nil)
    local rank = ply:GetNetVar(NET_GROUP_RANK, nil)

    if not name or not rank then return end

    local groupData = impulse.Group.Groups[name]

    if not groupData then return end

    if not ply:GroupHasPermission(99) then return end

    local col = net.ReadColor()

    if not col then return end

    col.a = 255

    impulse.Group:SetMetaData(name, nil, col)
    impulse.Group:NetworkMetaDataToOnline(name)

    ply:Notify("You have updated the colour of your group.")
end)

net.Receive("impulseGroupDoSetInfo", function(len, ply)
    if (ply.nextRPGroupDataSet or 0) > CurTime() then return end
    ply.nextRPGroupDataSet = CurTime() + 3

    if ply:IsCP() then return end

    local name = ply:GetNetVar(NET_GROUP_NAME, nil)
    local rank = ply:GetNetVar(NET_GROUP_RANK, nil)

    if not name or not rank then return end

    local groupData = impulse.Group.Groups[name]

    if not groupData then return end

    if not ply:GroupHasPermission(8) then return end

    local info = net.ReadString()

    if not info then return end

    info = string.sub(info, 1, 1024)

    impulse.Group:SetMetaData(name, info)
    impulse.Group:NetworkMetaDataToOnline(name)

    ply:Notify("You have updated the info for your group.")
end)
