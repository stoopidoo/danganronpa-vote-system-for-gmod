if SERVER then
    util.AddNetworkString("ShowBlueScreen")
    util.AddNetworkString("PlayerModelSelected")
    util.AddNetworkString("VoteResults")

    -- Table to track votes
    local voteCounts = {}
    local playerVotes = {} -- Associates each player with their current vote

    -- Server command for admins
    concommand.Add("vote", function(ply)
        print(ply:IsSuperAdmin())
        -- Ensure the player is valid and a super admin
        if not IsValid(ply) or not ply:IsValid() or not ply:IsSuperAdmin() then
            if IsValid(ply) then
                ply:ChatPrint("Cette commande est réservée aux administrateurs.")
            end
            return
        end

        -- Collect connected player information
        local playerInfo = {}
        for _, v in ipairs(player.GetAll()) do
            local role = v:getDarkRPVar("job") -- Get DarkRP job
            if role ~= "MONOKUMERS" and role ~= "MONOKUMA" then
                -- Additional safety checks
                local playerName = v:Nick() or "Unknown"
                local playerModel = v:GetModel() or "models/error.mdl"
                
                table.insert(playerInfo, { 
                    name = playerName, 
                    model = playerModel 
                })
                voteCounts[playerName] = 0 -- Initialize vote counts
            end
        end

        -- Reset previous votes
        playerVotes = {}

        -- Send data to all clients
        net.Start("ShowBlueScreen")
        net.WriteTable(playerInfo)
        net.Broadcast()
    end)

    -- Receive player's choice on the server
    net.Receive("PlayerModelSelected", function(len, ply)
        if not IsValid(ply) then return end

        local selectedPlayerName = net.ReadString()
        
        if not selectedPlayerName or voteCounts[selectedPlayerName] == nil then return end

        local steamID = ply:SteamID()
        local previousVote = playerVotes[steamID]
        
        if previousVote then
            -- Remove the previous vote
            voteCounts[previousVote] = math.max(0, (voteCounts[previousVote] or 0) - 1)
        end

        -- Add the new vote
        voteCounts[selectedPlayerName] = (voteCounts[selectedPlayerName] or 0) + 1
        playerVotes[steamID] = selectedPlayerName

        -- Send vote results to admins
        for _, admin in ipairs(player.GetAll()) do
            if admin:IsSuperAdmin() then
                net.Start("VoteResults")
                net.WriteTable(voteCounts)
                net.Send(admin)
            end
        end
        print("[SERVER] " .. ply:Nick() .. " a voté pour " .. selectedPlayerName)
    end)
else
    local blueScreenFrame

    net.Receive("ShowBlueScreen", function()
        if IsValid(blueScreenFrame) then
            blueScreenFrame:Remove()
        end

        -- Create full-screen blue screen
        blueScreenFrame = vgui.Create("DFrame")
        blueScreenFrame:SetSize(ScrW(), ScrH())
        blueScreenFrame:SetTitle("")
        blueScreenFrame:ShowCloseButton(false)
        blueScreenFrame:SetDraggable(false)
        blueScreenFrame:MakePopup()
        blueScreenFrame:SetBackgroundBlur(true)
        blueScreenFrame:SetPaintBackgroundEnabled(false)

        -- Blue background
        function blueScreenFrame:Paint(w, h)
            -- Added fallback for missing material
            local bgMaterial = Material("conradd/background.png")
            if not bgMaterial or bgMaterial:IsError() then
                surface.SetDrawColor(0, 0, 255)
                surface.DrawRect(0, 0, w, h)
            else
                surface.SetDrawColor(255, 255, 255)
                surface.SetMaterial(bgMaterial)
                surface.DrawTexturedRect(0, 0, w, h)
            end
        end

        -- Timer
        local timeRemaining = 3
        local timerLabel = vgui.Create("DLabel", blueScreenFrame)
        timerLabel:SetFont("DermaLarge")
        timerLabel:SetTextColor(Color(255, 255, 255))
        timerLabel:SetContentAlignment(5)
        timerLabel:SetSize(300, 50)
        timerLabel:SetPos((ScrW() - 300) / 2, ScrH() - 100)
        timerLabel:SetText("Temps restant : " .. timeRemaining .. " secondes")

        timer.Create("BlueScreenTimer", 1, timeRemaining, function()
            timeRemaining = timeRemaining - 1
            timerLabel:SetText("Temps restant : " .. timeRemaining .. " secondes")
            if timeRemaining <= 0 then
                blueScreenFrame:Remove()
                timer.Remove("BlueScreenTimer")
            end
        end)

        -- Player information
        local playerInfo = net.ReadTable()

        -- Left side grid panel
        local gridPanel = vgui.Create("DScrollPanel", blueScreenFrame)
        gridPanel:SetSize(ScrW() / 2, ScrH() - 100)
        gridPanel:SetPos(50, 50)

        -- Dimensions of cells
        local previewWidth, previewHeight = ScrW() / 2, ScrH() - ScrH() / 2
        local cellWidth, cellHeight = previewWidth / 2 - 30, previewHeight / 2 - 30
        local spacing = 10
        local cols = 2

        -- Right side preview panel
        local previewPanel = vgui.Create("DPanel", blueScreenFrame)
        previewPanel:SetSize(previewWidth, previewHeight)
        previewPanel:SetPos(ScrW() / 2 + 50, 50)
        previewPanel:SetBackgroundColor(Color(0, 0, 0, 150))

        -- Label to display nickname above preview
        local nameLabel = vgui.Create("DLabel", blueScreenFrame)
        nameLabel:SetFont("DermaLarge")
        nameLabel:SetTextColor(Color(255, 255, 255))
        nameLabel:SetContentAlignment(5)
        nameLabel:SetSize(previewWidth, 30)
        nameLabel:SetPos(ScrW() / 2 + 50, 10)
        nameLabel:SetText("") -- Empty by default

        -- Button to save choice
        local selectButton = vgui.Create("DButton", blueScreenFrame)
        selectButton:SetSize(previewWidth, 50)
        selectButton:SetPos(ScrW() / 2 + 50, 50 + previewHeight + 10)
        selectButton:SetText("Voter pour ce joueur")
        selectButton:SetEnabled(false) -- Disabled by default
        selectButton.DoClick = function()
            local selectedPlayerName = selectButton.SelectedPlayer
            if selectedPlayerName then
                net.Start("PlayerModelSelected")
                net.WriteString(selectedPlayerName)
                net.SendToServer()
                chat.AddText(Color(0, 255, 0), "Vote enregistré pour : " .. selectedPlayerName)
            end
        end

        local previewModelPanel = nil

        -- Add players to the grid
        for i, info in ipairs(playerInfo) do
            local row = math.floor((i - 1) / cols)
            local col = (i - 1) % cols

            -- Cell panel
            local playerPanel = vgui.Create("DPanel", gridPanel)
            playerPanel:SetSize(cellWidth, cellHeight)
            playerPanel:SetPos(col * (cellWidth + spacing), row * (cellHeight + spacing))
            playerPanel:SetBackgroundColor(Color(0, 0, 0, 150))

            -- 3D Model
            local modelPanel = vgui.Create("DModelPanel", playerPanel)
            modelPanel:SetSize(cellWidth - 20, cellHeight - 40)
            modelPanel:SetPos(10, 10)
            
            -- Additional error handling for model
            local success, err = pcall(function()
                modelPanel:SetModel(info.model or "models/error.mdl")
            end)
            
            if not success then
                print("Error setting model: " .. tostring(err))
                modelPanel:SetModel("models/error.mdl")
            end

            -- Camera adjustment
            local bone = modelPanel.Entity:LookupBone("ValveBiped.Bip01_Head1")
            local eyepos = bone and modelPanel.Entity:GetBonePosition(bone) or modelPanel.Entity:GetPos()
            modelPanel:SetLookAt(eyepos)
            modelPanel:SetCamPos(eyepos - Vector(-50, 0, 0))

            function modelPanel:LayoutEntity(ent)
                -- Prevent model animation
            end

            -- Click to show in preview panel
            modelPanel:SetMouseInputEnabled(true)
            modelPanel.DoClick = function()
                if IsValid(previewModelPanel) then
                    previewModelPanel:Remove()
                end

                previewModelPanel = vgui.Create("DModelPanel", previewPanel)
                previewModelPanel:SetSize(previewPanel:GetWide(), previewPanel:GetTall())
                
                -- Additional error handling for preview model
                local success, err = pcall(function()
                    previewModelPanel:SetModel(info.model or "models/error.mdl")
                end)
                
                if not success then
                    print("Error setting preview model: " .. tostring(err))
                    previewModelPanel:SetModel("models/error.mdl")
                end

                local bone = previewModelPanel.Entity:LookupBone("ValveBiped.Bip01_Head1")
                local eyepos = bone and previewModelPanel.Entity:GetBonePosition(bone) or previewModelPanel.Entity:GetPos()
                previewModelPanel:SetLookAt(eyepos)
                previewModelPanel:SetCamPos(eyepos - Vector(-50, 0, 0))

                function previewModelPanel:LayoutEntity(ent)
                    -- Prevent model animation
                end

                -- Update nickname above preview
                nameLabel:SetText(info.name)

                -- Enable button and store selected player
                selectButton:SetEnabled(true)
                selectButton.SelectedPlayer = info.name
            end
        end

        -- Update votes
        net.Receive("VoteResults", function()
            local voteResults = net.ReadTable()
            chat.AddText(Color(255, 255, 0), "Votes actuels :")
            for name, count in pairs(voteResults) do
                chat.AddText(Color(255, 255, 255), name .. ": " .. count .. " votes")
            end
        end)
    end)
end