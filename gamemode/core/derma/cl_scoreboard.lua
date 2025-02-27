local PANEL = {}

function PANEL:Init()
    self:SetSize(SizeW(900), SizeH(900))
    self:Center()
    self:SetTitle("Scoreboard")
    self:ShowCloseButton(false)
    self:SetDraggable(false)
    self:MakePopup()
     self:MoveToFront()

     self.scrollPanel = vgui.Create("DScrollPanel", self)
    self.scrollPanel:Dock(FILL)

    local playerList = {}
    for v, k in player.Iterator() do
        if k:IsAdmin() and k:GetNetVar(NET_IS_INCOGNITO, false) then continue end

        table.insert(playerList, k)
    end

    table.sort(playerList, function(a,b)
        return a:Team() > b:Team()
    end)
    
    for v, k in ipairs(playerList) do
        local playerCard = self.scrollPanel:Add("impulseScoreboardCard")
        playerCard:SetPlayer(k)
        playerCard:SetHeight(60)
        playerCard:Dock(TOP)
        playerCard:DockMargin(0,0,0,0)
    end
end


vgui.Register("impulseScoreboard", PANEL, "DFrame")
