-- Dandy Retro | ESP, auto skill check e corrida sem gasto | RetroBox API 2 Stable
local created

local function main()
    assert(game.GameId == 5569032992, "Este script é para Dandy's World.")
    if type(setthreadidentity) == "function" then setthreadidentity(8) end
    local URL = "https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/dist/bootstrap/v2.lua"
    local loaded, Library = pcall(function()
        assert(type(loadstring) == "function", "O executor não oferece loadstring.")
        local ok, getter = pcall(function() return game.HttpGet end)
        assert(ok and type(getter) == "function", "O executor não oferece game:HttpGet.")
        local source = game:HttpGet(URL)
        assert(type(source) == "string" and #source > 0, "O raw retornou uma fonte vazia.")
        local chunk, err = loadstring(source)
        assert(chunk, err)
        return chunk({Channel = "stable"})
    end)
    assert(loaded, "Falha ao carregar RetroBox: " .. tostring(Library))
    assert(type(Library) == "table" and Library.APIVersion == 2 and type(Library.CreateWindow) == "function",
        "O bootstrap não retornou uma RetroBox compatível com a API 2.")

    local Players = game:GetService("Players")
    local RS = game:GetService("ReplicatedStorage")
    local player = assert(Players.LocalPlayer, "Jogador indisponível.")
    local modules = RS:WaitForChild("Modules", 10)
    assert(modules, "Módulos do jogo ainda não carregados.")
    local gameContext = require(modules.Core.GameContext)
    local input = require(RS.SharedUtils.InputService)
    local circle = require(modules.Gameplay.CircleSkillCheckHandler)
    local taps = require(modules.Gameplay.TreadmillTapSkillCheck)
    local sprint = require(modules.ClientUI.SprintController)
    local sprintRemote = RS.Events.SprintEvent
    local getUps = getupvalues or (debug and debug.getupvalues)
    local setUp = setupvalue or (debug and debug.setupvalue)
    local env = type(getgenv) == "function" and getgenv() or _G
    if env.DandyRetro then env.DandyRetro:Destroy() end

    local hub = {alive = true, inputs = 0, lastResult = "—", autoStatus = "Auto minigame desligado",
        staminaStatus = "Corrida normal", libraryVersion = Library:GetVersion(),
        counts = {Items = 0, Generators = 0, Monsters = 0, Players = 0}}
    local window = Library:CreateWindow({
        Id = "DandyRetro-" .. game.GameId, Title = "Dandy Retro",
        Subtitle = "Dandy Retro · ESP, extração e stamina", Icon = "eye",
        Theme = "Retro98", Locale = "pt-BR", Settings = true, ShowProfile = true,
        Launcher = true, LauncherText = "UI", ToggleKey = Enum.KeyCode.RightShift, DestroyOnClose = false,
        PixelIcons = true, PixelDecorations = true, Tooltips = true, TooltipDelay = .2,
        Parent = player:WaitForChild("PlayerGui"), ConfigFolder = "RetroBox/DandyRetro/" .. game.GameId,
        ConfigVersion = 1, SmoothDragging = false,
        CallbackExecutor = function(callback, args)
            if type(setthreadidentity) == "function" then setthreadidentity(8) end
            return callback(table.unpack(args, 1, args.n))
        end,
    })
    created, hub.window, env.DandyRetro = hub, window, hub
    if typeof(window.Launcher) == "Instance" then window.Launcher.AutoLocalize = false end
    function hub:Destroy()
        self.alive = false
        self.window:Destroy()
        if env.DandyRetro == self then env.DandyRetro = nil end
    end
    window:Manage(function()
        hub.alive = false
        if env.DandyRetro == hub then env.DandyRetro = nil end
    end)

    local espTab = window:CreateTab({Title = "ESP", Icon = "eye", Columns = 1})
    local espSection = espTab:CreateSection({Title = "Objetos do andar", Icon = "map"})
    local categories = {
        {key = "Items", id = "items", title = "ESP de itens", icon = "backpack", color = Color3.fromRGB(75, 235, 125)},
        {key = "Generators", id = "machines", title = "ESP de máquinas", icon = "tools", color = Color3.fromRGB(70, 205, 255)},
        {key = "Monsters", id = "monsters", title = "ESP de monstros", icon = "skull", color = Color3.fromRGB(255, 80, 100)},
        {key = "Players", id = "players", title = "ESP de jogadores e corações", icon = "user", color = Color3.fromRGB(245, 235, 125)},
    }
    local colors = {}
    for _, category in ipairs(categories) do
        colors[category.key] = category.color
        espSection:AddToggle({Id = "dw.esp." .. category.id, Title = category.title, Icon = category.icon, Default = true,
            Tooltip = category.key == "Players" and "Mostra os outros jogadores, a distância e a vida atual em corações durante a partida. No lobby mostra vida normal."
                or "Mostra nome, distância e contorno através das paredes. Atualiza quando o andar muda."})
        category.picker = espSection:AddColorPicker({Id = "dw.color." .. category.id,
            Title = category.key == "Generators" and "Cor · máquinas de linha" or "Cor · " .. category.title, Icon = "palette",
            Default = category.color, AllowRainbow = false, AllowOpacity = false,
            Callback = function(color) colors[category.key] = color end})
    end
    local circleColor = Color3.fromRGB(195, 135, 255)
    local circlePicker = espSection:AddColorPicker({Id = "dw.color.machine-circle", Title = "Cor · máquinas de bolinha", Icon = "palette",
        Default = circleColor, AllowRainbow = false, AllowOpacity = false,
        Tooltip = "Cor do tipo Circle. A porcentagem de extração tem destaque e cor próprios.",
        Callback = function(color) circleColor = color end})
    window:Manage(window:GetFlagState("dw.color.machine-circle"):Subscribe(function()
        circleColor = circlePicker:GetColor()
    end, true), "Disconnect")
    espSection:AddToggle({Id = "dw.esp.completed", Title = "Mostrar máquinas concluídas", Icon = "success", Default = true,
        Tooltip = "As máquinas concluídas aparecem com a indicação CONCLUÍDA."})
    espSection:AddSlider({Id = "dw.esp.distance", Title = "Distância máxima", Icon = "sliders",
        Min = 50, Max = 4000, Step = 50, Default = 1500, Suffix = " studs",
        Tooltip = "Limite de distância dos contornos e nomes; a atualização usa apenas os objetos das pastas do andar."})
    espSection:AddSlider({Id = "dw.esp.text", Title = "Tamanho dos nomes", Icon = "sliders",
        Min = 10, Max = 22, Step = 1, Default = 13,
        Tooltip = "Tamanho do texto dos marcadores no mundo."})
    local espStatus = espSection:AddLabel({Id = "dw.esp.status", Title = "Objetos detectados", Icon = "info", Default = "Carregando..."})
    local overlay = Instance.new("Folder")
    overlay.Name = "DandyRetro_ESP"
    overlay.Parent = workspace
    window:Manage(overlay)
    local entries = {}
    local function discard(model)
        local entry = entries[model]
        if not entry then return end
        entry.highlight:Destroy(); entry.gui:Destroy(); entries[model] = nil
    end
    window:Manage(function()
        for model in pairs(entries) do discard(model) end
    end)
    local function rootOf(model)
        if model:IsA("BasePart") then return model end
        if not model:IsA("Model") then return nil end
        return model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
            or model:FindFirstChild("Origin") or model:FindFirstChildWhichIsA("BasePart", true)
    end
    local function entryFor(model, root)
        local entry = entries[model]
        if entry then entry.gui.Adornee = root; return entry end
        local highlight = Instance.new("Highlight")
        highlight.Name = "DandyRetroHighlight"; highlight.Adornee = model
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillTransparency = .8; highlight.OutlineTransparency = 0
        highlight.Parent = overlay
        local gui = Instance.new("BillboardGui")
        gui.Name = "DandyRetroName"; gui.Adornee = root; gui.AlwaysOnTop = true
        gui.Size = UDim2.fromOffset(290, 86); gui.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
        gui.Parent = overlay
        local label = Instance.new("TextLabel")
        label.Name = "Caption"; label.Size = UDim2.new(1, 0, 1, -9); label.BackgroundTransparency = 1
        label.Font = Enum.Font.Code; label.TextSize = 13; label.TextWrapped = true
        label.RichText = true; label.AutoLocalize = false
        label.TextStrokeTransparency = .15; label.TextStrokeColor3 = Color3.new(0, 0, 0)
        label.Parent = gui
        local bar = Instance.new("Frame")
        bar.Name = "ProgressBar"; bar.AnchorPoint = Vector2.new(.5, 1)
        bar.Position = UDim2.new(.5, 0, 0, 69); bar.Size = UDim2.fromOffset(96, 3)
        bar.BackgroundColor3 = Color3.fromRGB(25, 25, 32); bar.BorderSizePixel = 0; bar.Visible = false; bar.Parent = gui
        local fill = Instance.new("Frame")
        fill.Name = "Fill"; fill.Size = UDim2.fromScale(0, 1); fill.BorderSizePixel = 0; fill.Parent = bar
        entry = {highlight = highlight, gui = gui, label = label, bar = bar, fill = fill}
        entries[model] = entry
        return entry
    end
    local function escape(value)
        return tostring(value):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
    end
    local function colored(text, color, bold, size)
        text = escape(text)
        if bold then text = "<b>" .. text .. "</b>" end
        return string.format('<font color="#%s"%s>%s</font>', color:ToHex(), size and (' size="' .. size .. '"') or "", text)
    end
    local function progressColor(ratio)
        return Color3.fromHSV(.04 + .29 * math.clamp(ratio, 0, 1), .72, 1)
    end
    local function machineText(model)
        local stats = model:FindFirstChild("Stats")
        local done = stats and stats:FindFirstChild("Completed")
        local finished = done and done.Value == true or model:GetAttribute("FloorCompletionCounted") == true
        local types, used = {}, {}
        local function addType(kind)
            if type(kind) ~= "string" or used[kind] then return end
            used[kind] = true; types[#types + 1] = kind
        end
        addType(model:GetAttribute("MinigameType"))
        for slot = 2, 8 do addType(model:GetAttribute("Prompt" .. slot .. "MinigameType")) end
        if #types == 0 then
            local list = model:GetAttribute("MinigameTypes")
            if type(list) == "string" then for kind in list:gmatch("[%w_]+") do addType(kind) end end
        end
        local names = {Original = "LINHA", Circle = "BOLINHA", MovementTreadmill = "TOQUES", Barnaby = "ARCADE"}
        local labels = {}
        for _, kind in ipairs(types) do labels[#labels + 1] = names[kind] or kind end
        local name = "Máquina · " .. (#labels > 0 and table.concat(labels, " + ") or "TIPO PENDENTE")
        local amount = stats and stats:FindFirstChild("CurrentAmount")
        local required = stats and stats:FindFirstChild("RequiredAmount")
        local ratio
        if finished then ratio = 1
        elseif amount and required and required.Value > 0 then ratio = math.clamp(amount.Value / required.Value, 0, 1) end
        local progress = finished and "CONCLUÍDA · 100%" or ratio and string.format("EXTRAÇÃO · %.0f%%", ratio * 100) or "PROGRESSO PENDENTE"
        return name, finished, ratio, progress, used.Circle and not used.Original
    end
    local function playerText(other, model, humanoid)
        local health, max = math.max(0, humanoid.Health), math.max(1, humanoid.MaxHealth)
        local color = progressColor(health / max)
        local stats = model:FindFirstChild("Stats")
        local toonHealth = stats and stats:FindFirstChild("Health")
        local life
        if toonHealth and max <= 8 then
            local full, total = math.clamp(math.ceil(health), 0, math.ceil(max)), math.ceil(max)
            life = string.rep("♥", full) .. string.rep("♡", total - full) .. string.format("  %.0f/%.0f", health, max)
        else life = string.format("VIDA · %.0f/%.0f", health, max) end
        local shields = model:GetAttribute("ShieldHearts")
        if type(shields) == "number" and shields > 0 then life ..= "  +" .. math.floor(shields) .. " escudo(s)" end
        return other.DisplayName, colored(life, color, true)
    end
    local function renderESP(model, category, seen, position, other)
        local anchor = rootOf(model)
        if not anchor then return end
        local distance = position and (anchor.Position - position).Magnitude or 0
        if not window:GetFlag("dw.esp." .. category.id) or distance > window:GetFlag("dw.esp.distance") then return end
        local text, finished, ratio, detail = model.Name, false, nil, nil
        local color = colors[category.key]
        local size = window:GetFlag("dw.esp.text")
        if category.key == "Generators" then
            local circleOnly
            text, finished, ratio, detail, circleOnly = machineText(model)
            if finished and not window:GetFlag("dw.esp.completed") then return end
            if circleOnly then color = circleColor end
            detail = colored(detail, ratio and progressColor(ratio) or Color3.fromRGB(220, 220, 230), true, size + 4)
        elseif category.key == "Monsters" then text = "Twisted " .. model.Name:gsub("Monster$", "")
        elseif category.key == "Players" then
            local humanoid = model:FindFirstChildOfClass("Humanoid")
            if not humanoid or not other then return end
            text, detail = playerText(other, model, humanoid)
        end
        seen[model] = true
        local entry = entryFor(model, anchor)
        entry.gui.Size = UDim2.fromOffset(290, math.max(86, (size + 4) * 4 + 12))
        entry.highlight.FillColor = color; entry.highlight.OutlineColor = color
        entry.label.TextColor3 = color; entry.label.TextSize = size
        entry.label.Text = colored(text, color, true) .. (detail and ("\n" .. detail) or "")
            .. "\n" .. colored(string.format("%.0f studs", distance), Color3.fromRGB(235, 235, 245), false)
        entry.bar.Visible = ratio ~= nil
        if ratio then
            entry.fill.Size = UDim2.fromScale(ratio, 1); entry.fill.BackgroundColor3 = progressColor(ratio)
            local labelHeight = entry.gui.Size.Y.Offset - 9
            local textHeight = entry.label.TextBounds.Y
            if textHeight <= 0 then textHeight = (size + 2) * 3 end
            entry.bar.Position = UDim2.new(.5, 0, 0, math.min(entry.gui.Size.Y.Offset - 1,
                (labelHeight + math.min(textHeight, labelHeight)) * .5 + 7))
        end
    end
    local function updateESP(ctx)
        ctx:ThrowIfCancelled()
        local seen, counts = {}, {Items = 0, Generators = 0, Monsters = 0, Players = 0}
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local position = root and root.Position or workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position
        local rooms = workspace:FindFirstChild("CurrentRoom")
        if rooms then
            for _, room in ipairs(rooms:GetChildren()) do
                for _, category in ipairs(categories) do
                    local sources = {room:FindFirstChild(category.key)}
                    if category.key == "Items" then
                        local holiday = room:FindFirstChild("HolidayPickups")
                        if holiday then sources[#sources + 1] = holiday end
                    end
                    for _, source in ipairs(sources) do
                        for _, model in ipairs(source:GetChildren()) do
                            local anchor = rootOf(model)
                            if anchor then
                                counts[category.key] += 1
                                renderESP(model, category, seen, position)
                            end
                        end
                    end
                end
            end
        end
        local playerCategory = categories[4]
        for _, other in ipairs(Players:GetPlayers()) do
            local model = other.Character
            if other ~= player and model and model.Parent and model:FindFirstChildOfClass("Humanoid") and rootOf(model) then
                counts.Players += 1
                renderESP(model, playerCategory, seen, position, other)
            end
        end
        for model in pairs(entries) do if not seen[model] or not model.Parent then discard(model) end end
        hub.counts = counts
        espStatus:SetText(string.format("Itens: %d · Máquinas: %d · Monstros: %d · Jogadores: %d",
            counts.Items, counts.Generators, counts.Monsters, counts.Players))
    end
    window:CreateTask({Id = "dw.esp.update", Interval = .2, Start = true, OnError = "Continue", Callback = updateESP})
    for _, category in ipairs(categories) do
        window:Manage(window:GetFlagState("dw.color." .. category.id):Subscribe(function()
            colors[category.key] = category.picker:GetColor()
        end, true), "Disconnect")
    end

    local automation = window:CreateTab({Title = "Extração", Icon = "tools", Columns = 1})
    local extract = automation:CreateSection({Title = "Auto minigame", Icon = "target"})
    local autoToggle = extract:AddToggle({Id = "dw.auto.skill", Title = "Ativar auto minigame", Icon = "target", Default = false,
        Tooltip = "Aciona a calibração nativa na área dourada da barra/círculo e completa os toques da esteira. Inicie a extração da máquina normalmente.",
        Floating = {Text = "AUTO", MobileOnly = true, Position = Vector2.new(.04, .65)}})
    local autoLabel = extract:AddLabel({Id = "dw.auto.status", Title = "Estado", Icon = "info", Default = hub.autoStatus})
    extract:AddLabel({Id = "dw.auto.help", Title = "Uso", Icon = "info",
        Default = "Inicie a extração normalmente e ative Auto minigame.\nSuporte: barra, círculo e sequência de toques.\nA automação só age durante a extração de uma máquina."})
    local countsState = window:CreateState(0)
    extract:AddStatCard({Id = "dw.auto.inputs", Title = "Calibrações acionadas", Icon = "keyboard",
        State = countsState, TwoWay = false, Format = "Raw", Subtitle = "Entradas enviadas à ação nativa"})
    local fired = setmetatable({}, {__mode = "k"})
    local lastTap = 0
    local function pressSkill()
        local action = input._actions and input._actions.SkillCheckTap
        assert(action and action:IsA("InputAction"), "Ação SkillCheckTap indisponível.")
        assert(type(firesignal) == "function", "Auto minigame requer firesignal.")
        firesignal(action.Pressed)
        hub.inputs += 1
        countsState:Set(hub.inputs)
    end
    local function skillStep(ctx)
        ctx:ThrowIfCancelled()
        local generator = gameContext.currentgenerator
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not generator or not generator.Parent or not generator:FindFirstChild("Stats")
            or not humanoid or humanoid.Health <= 0 then hub.autoStatus = "Aguardando extração de máquina"; return end
        if not gameContext.skillchecking then
            fired = setmetatable({}, {__mode = "k"})
            hub.autoStatus = "Aguardando skill check"; return
        end
        if input:IsTyping() then hub.autoStatus = "Pausado enquanto você digita"; return end
        local circular = circle.ActiveSkillCheck
        local tapping = taps.ActiveSkillCheck
        if tapping and tapping.ui and tapping.isActive and tapping.isActive() then
            hub.autoStatus = "Completando sequência de toques"
            if os.clock() - lastTap >= .1 then ctx:ThrowIfCancelled(); lastTap = os.clock(); pressSkill() end
        elseif circular and circular.ui then
            hub.autoStatus = "Aguardando área dourada do círculo"
            local ui = circular.ui
            if ui.Frame.Visible and not fired[circular] then
                local size = ui.ShrinkingCircle.Size.X.Offset
                local inner, outer = ui.Zones.black.size, ui.Zones.yellow.size
                if size >= inner + (outer - inner) * .2 and size <= inner + (outer - inner) * .65 then
                    ctx:ThrowIfCancelled(); fired[circular] = true; pressSkill()
                end
            end
        else
            local gui = gameContext.Gui
            local menu = gui and gui:FindFirstChild("Menu")
            local frame = menu and menu:FindFirstChild("SkillCheckFrame")
            local marker = frame and frame:FindFirstChild("Marker")
            local gold = frame and frame:FindFirstChild("GoldArea")
            if frame and frame.Visible and marker and gold then
                hub.autoStatus = "Aguardando área dourada da barra"
                local active = type(getUps) == "function" and getUps(require(modules.ClientUI.SkillCheckController).abortActive)[1]
                local key = active or marker
                if not fired[key] then
                    local x, left, width = marker.Position.X.Scale, gold.Position.X.Scale, gold.Size.X.Scale
                    if x >= left + width * .2 and x <= left + width * .8 then
                        ctx:ThrowIfCancelled(); fired[key] = true; pressSkill()
                    end
                end
            else hub.autoStatus = "Aguardando minigame suportado" end
        end
    end
    local skillJob = window:CreateTask({Id = "dw.auto.worker", Interval = .03, Start = false, OnError = "Stop", Callback = skillStep})
    hub.skillJob = skillJob
    autoToggle:BindTask(skillJob)
    window:Manage(window:GetFlagState("dw.auto.skill"):Subscribe(function(enabled)
        if not enabled then hub.autoStatus = "Auto minigame desligado" end
    end), "Disconnect")

    local movement = window:CreateTab({Title = "Stamina", Icon = "rocket", Columns = 1})
    local staminaSection = movement:CreateSection({Title = "Corrida sem gasto", Icon = "rocket"})
    local staminaToggle = staminaSection:AddToggle({Id = "dw.stamina.enabled", Title = "Infinite stamina · experimental",
        Icon = "rocket", Default = false,
        Tooltip = "Usa a velocidade de corrida do personagem enquanto mantém desligado o sprint que consome stamina no servidor. A barra continua mostrando o valor real. Usa seu botão/atalho de sprint normal."})
    local staminaLabel = staminaSection:AddLabel({Id = "dw.stamina.status", Title = "Estado", Icon = "info", Default = hub.staminaStatus})
    staminaSection:AddLabel({Id = "dw.stamina.help", Title = "Funcionamento", Icon = "info",
        Default = "Ative e use o sprint normalmente.\nO recurso respeita extração, efeitos de fadiga e mudanças de personagem.\nDesligar restaura o controlador de sprint e a velocidade.\nNão altera o número de stamina para disfarçar consumo."})
    local staminaState = window:CreateState("—")
    staminaSection:AddStatCard({Id = "dw.stamina.amount", Title = "Stamina observada", Icon = "rocket",
        State = staminaState, TwoWay = false, Format = "Raw", Subtitle = "CurrentStamina / Stamina do personagem"})
    local staminaScope = staminaToggle:CreateScope({CancelOnFalse = true})
    local proxy, speedOwner, speedWritten
    local function releaseSpeed()
        if speedOwner and speedOwner.Parent and speedOwner.WalkSpeed == speedWritten then
            local stats = speedOwner.Parent:FindFirstChild("Stats")
            local walk = stats and stats:FindFirstChild("WalkSpeed")
            local modifier = stats and stats:FindFirstChild("SpeedModifier")
            if walk then speedOwner.WalkSpeed = walk.Value * (modifier and modifier.Value or 1) end
        end
        speedOwner, speedWritten = nil, nil
    end
    local function installSprintProxy()
        assert(type(getUps) == "function" and type(setUp) == "function", "Corrida sem gasto requer getupvalues e setupvalue.")
        local original = getUps(sprint.init)[2]
        assert(original == sprintRemote, "O controlador de sprint foi alterado; reinicie o script.")
        proxy = {OnClientEvent = sprintRemote.OnClientEvent, FireServer = function()
            sprintRemote:FireServer(false)
        end}
        setUp(sprint.init, 2, proxy)
        staminaScope:Add(function()
            if getUps(sprint.init)[2] == proxy then setUp(sprint.init, 2, original) end
            sprintRemote:FireServer(false)
            sprint.resetState()
            releaseSpeed()
            proxy = nil
            hub.staminaStatus = "Corrida normal"
        end, nil, "sprint-restore")
        sprintRemote:FireServer(false)
    end
    local function staminaStep(ctx)
        ctx:ThrowIfCancelled()
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local stats = character and character:FindFirstChild("Stats")
        if not humanoid or humanoid.Health <= 0 or not stats or not stats:FindFirstChild("RunSpeed") then
            releaseSpeed(); hub.staminaStatus = "Aguardando personagem da partida"; return
        end
        if not proxy then installSprintProxy() end
        if getUps(sprint.init)[2] ~= proxy then
            staminaScope:Clean(); installSprintProxy()
        end
        local decoding = character:FindFirstChild("Decoding")
        if gameContext.currentgenerator or decoding and decoding.Value or input:IsGameplaySuspended()
            or character:GetAttribute("StaminaFatigued") or character:GetAttribute("TreadmillDazed")
            or character:FindFirstChild("BoxAbilityActive") then
            releaseSpeed(); hub.staminaStatus = "Pausado durante interação/efeito"; return
        end
        if not sprint.isSprinting() then releaseSpeed(); hub.staminaStatus = "Ativo · aguardando sprint"; return end
        local run = stats:FindFirstChild("RunSpeed")
        local modifier = stats:FindFirstChild("RunSpeedModifier")
        if run then
            local speed = run.Value * (modifier and modifier.Value or 1)
            assert(speed == speed and speed >= 0 and speed < math.huge, "Velocidade de corrida inválida.")
            if speedOwner ~= humanoid then releaseSpeed() end
            speedOwner, speedWritten = humanoid, speed
            humanoid.WalkSpeed = speed
            hub.staminaStatus = "Corrida sem gasto ativa · " .. string.format("%.1f", speed)
        end
    end
    local staminaJob = window:CreateTask({Id = "dw.stamina.worker", Interval = .05, Start = false, OnError = "Stop", Callback = staminaStep})
    hub.staminaJob = staminaJob
    staminaToggle:BindTask(staminaJob)
    window:Manage(window:GetFlagState("dw.stamina.enabled"):Subscribe(function(enabled)
        if not enabled then staminaScope:Clean() end
    end), "Disconnect")
    if type(getUps) ~= "function" or type(setUp) ~= "function" then
        staminaToggle:SetDisabled(true)
        staminaToggle:SetTooltip("Este executor não oferece getupvalues/setupvalue; corrida sem gasto indisponível.")
    end

    window:CreateTask({Id = "dw.telemetry", Interval = .25, Start = true, Callback = function(ctx)
        ctx:ThrowIfCancelled()
        autoLabel:SetText(skillJob:GetStatus().LastError and "Erro: " .. tostring(skillJob:GetStatus().LastError) or hub.autoStatus)
        staminaLabel:SetText(staminaJob:GetStatus().LastError and "Erro: " .. tostring(staminaJob:GetStatus().LastError) or hub.staminaStatus)
        local character = player.Character
        local stats = character and character:FindFirstChild("Stats")
        local current = stats and stats:FindFirstChild("CurrentStamina")
        local max = stats and stats:FindFirstChild("Stamina")
        staminaState:Set(current and max and string.format("%.0f / %.0f", current.Value, max.Value) or "—")
    end})
    local row = extract:CreateRow({Gap = 10, StackAt = 440})
    function hub:Stop()
        window:SetFlags({["dw.esp.items"] = false, ["dw.esp.machines"] = false, ["dw.esp.monsters"] = false,
            ["dw.esp.players"] = false, ["dw.auto.skill"] = false, ["dw.stamina.enabled"] = false})
        for model in pairs(entries) do discard(model) end
    end
    function hub:GetSnapshot()
        return {alive = self.alive, counts = self.counts, inputs = self.inputs,
            auto = window:GetFlag("dw.auto.skill"), autoStatus = self.autoStatus,
            staminaEnabled = window:GetFlag("dw.stamina.enabled"), staminaStatus = self.staminaStatus,
            stamina = staminaState:Get(), libraryVersion = self.libraryVersion, diagnostics = window:GetDiagnostics()}
    end
    row:AddButton({Id = "dw.stop", Title = "Parar tudo", Text = "PARAR", Icon = "close",
        Tooltip = "Remove os ESPs, para o auto minigame e restaura o sprint.", Callback = function() hub:Stop(); return true end})
    row:AddButton({Id = "dw.unload", Title = "Encerrar script", Text = "ENCERRAR", Icon = "close",
        Tooltip = "Destrói a janela e limpa todos os recursos do script.", Callback = function() hub:Destroy(); return true end})
    window:Notify({Title = "Dandy Retro", Content = "ESP pronto. Auto minigame e stamina são ativados nas suas abas.",
        Kind = "success", Icon = "eye", Duration = 5})
    print("[DandyRetro] pronto · RetroBox " .. hub.libraryVersion .. " · API 2 Stable")
end

task.defer(function()
    local ok, err = xpcall(main, function(message) return debug.traceback(tostring(message), 2) end)
    if not ok then
        if created then pcall(function() created:Destroy() end) end
        warn("Dandy Retro: " .. tostring(err))
    end
end)
