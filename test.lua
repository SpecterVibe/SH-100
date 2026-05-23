-- ══════════════════════════════════════════════════
--    MM2 MENU  ·  Self-Contained  ·  2D + 3D ESP
--    No external library required
-- ══════════════════════════════════════════════════

if game.CoreGui:FindFirstChild("MM2MenuV3") then
    game:GetService("StarterGui"):SetCore("SendNotification",{
        Title="MM2 Menu",Text="Already loaded! Rejoin to re-execute.",Duration=5})
    return
end

-- ─── SERVICES ──────────────────────────────────────
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local Lighting          = game:GetService("Lighting")
local Camera            = workspace.CurrentCamera
local plr               = Players.LocalPlayer
local Mouse             = plr:GetMouse()

-- ─── CLEANUP REGISTRY ──────────────────────────────
-- Everything that needs to be destroyed on kill goes here
local Connections = {}
local function Track(conn) table.insert(Connections, conn) return conn end
local function KillAll()
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    -- Remove all 2D drawings
    for _, t in pairs(ESP2DObjects or {}) do
        for _, d in pairs(t) do pcall(function()
            if type(d)~="string" then d:Remove() end
        end) end
    end
    -- Remove all 3D SelectionBoxes
    for _, sb in pairs(ESP3DObjects or {}) do
        pcall(function() sb:Destroy() end)
    end
    -- Remove the GUI
    local g = game.CoreGui:FindFirstChild("MM2MenuV3")
    if g then g:Destroy() end
    -- Reset game state
    pcall(function()
        workspace.FallenPartsDestroyHeight = -500
        workspace.FogEnd   = 100000
        workspace.FogStart = 0
        workspace.GlobalShadows = true
        Lighting.Brightness = 2
        local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = 16
            hum.JumpPower = 50
            hum.PlatformStand = false
        end
        -- Remove any fly BodyMovers
        local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        if root then
            for _, v in ipairs(root:GetChildren()) do
                if v:IsA("BodyGyro") or v:IsA("BodyVelocity") then v:Destroy() end
            end
        end
    end)
    print("[MM2 Menu] Killed.")
end

-- ─── ESP STATE ─────────────────────────────────────
local ESP2DObjects = {}
local ESP3DObjects = {}
local ESP = {
    E2D=false, E3D=false,
    Names=true, Health=true, Dist=false, Roles=false,
    TeamCol=true, MaxDist=500,
    Thickness3D=0.05, Trans3D=0.8,
}
local Toggles = {
    Fly=false, AntiAFK=false, CoinCollect=false,
    NoFog=false, FullBright=false, InfStamina=false, VoidProt=false,
}
local FlySpeed=50; local flyRunning=false
local flyCtrl={f=0,b=0,l=0,r=0}; local flyLast={f=0,b=0,l=0,r=0}; local flySpd=0
local flyKD, flyKU

-- ─── HELPERS ───────────────────────────────────────
local function Notify(t,m,d)
    game:GetService("StarterGui"):SetCore("SendNotification",{Title=t,Text=m,Duration=d or 4})
end
local function Tween(o,g,t) TweenService:Create(o,TweenInfo.new(t or .18,Enum.EasingStyle.Quad),g):Play() end
local function roleCol(p)
    local ok,tc=pcall(function() return p.TeamColor end)
    if not ok then return Color3.fromRGB(80,255,120) end
    if tc==BrickColor.new("Bright red")  then return Color3.fromRGB(255,55,55)  end
    if tc==BrickColor.new("Bright blue") then return Color3.fromRGB(55,155,255) end
    return Color3.fromRGB(80,255,120)
end
local function roleStr(p)
    local ok,tc=pcall(function() return p.TeamColor end)
    if not ok then return "INNOCENT" end
    if tc==BrickColor.new("Bright red")  then return "MURDERER" end
    if tc==BrickColor.new("Bright blue") then return "SHERIFF"  end
    return "INNOCENT"
end

-- ─── 2D ESP OBJECTS ────────────────────────────────
local function make2D(p)
    if p==plr or ESP2DObjects[p] then return end
    local t={}
    local function D(cls,props)
        local d=Drawing.new(cls)
        for k,v in pairs(props) do d[k]=v end
        t[#t+1]=d; return d
    end
    t.BoxOL  = D("Square",{Visible=false,Thickness=3,Filled=false,Color=Color3.new(0,0,0)})
    t.Box    = D("Square",{Visible=false,Thickness=1.5,Filled=false,Color=Color3.new(1,1,1)})
    t.Name   = D("Text",  {Visible=false,Size=13,Center=true,Outline=true,Font=Drawing.Fonts.UI,Color=Color3.new(1,1,1)})
    t.Role   = D("Text",  {Visible=false,Size=11,Center=true,Outline=true,Font=Drawing.Fonts.UI,Color=Color3.new(1,1,1)})
    t.Dist   = D("Text",  {Visible=false,Size=11,Center=true,Outline=true,Font=Drawing.Fonts.UI,Color=Color3.fromRGB(200,200,200)})
    t.HpBG   = D("Square",{Visible=false,Filled=true,Color=Color3.fromRGB(20,20,20)})
    t.Hp     = D("Square",{Visible=false,Filled=true,Color=Color3.fromRGB(60,220,60)})
    ESP2DObjects[p]=t
end
local function hide2D(t)
    for _,d in pairs(t) do pcall(function()
        if type(d)~="number" then d.Visible=false end
    end) end
end
local function remove2D(p)
    if ESP2DObjects[p] then
        for _,d in pairs(ESP2DObjects[p]) do pcall(function() d:Remove() end) end
        ESP2DObjects[p]=nil
    end
end

-- ─── 3D ESP OBJECTS ────────────────────────────────
local function make3D(p)
    if p==plr or ESP3DObjects[p] then return end
    local sb=Instance.new("SelectionBox")
    sb.LineThickness=ESP.Thickness3D
    sb.SurfaceTransparency=ESP.Trans3D
    sb.Color3=Color3.new(1,1,1)
    sb.SurfaceColor3=Color3.new(1,1,1)
    sb.Parent=workspace
    ESP3DObjects[p]=sb
end
local function remove3D(p)
    if ESP3DObjects[p] then ESP3DObjects[p]:Destroy(); ESP3DObjects[p]=nil end
end

-- Init existing players
for _,p in ipairs(Players:GetPlayers()) do make2D(p); make3D(p) end
Track(Players.PlayerAdded:Connect(function(p) make2D(p); make3D(p) end))
Track(Players.PlayerRemoving:Connect(function(p) remove2D(p); remove3D(p) end))

-- ─── FLY ───────────────────────────────────────────
local function stopFly()
    Toggles.Fly=false; flyRunning=false
    pcall(function()
        local root=plr.Character.HumanoidRootPart
        for _,v in ipairs(root:GetChildren()) do
            if v:IsA("BodyGyro") or v:IsA("BodyVelocity") then v:Destroy() end
        end
        plr.Character.Humanoid.PlatformStand=false
    end)
    if flyKD then pcall(function() flyKD:Disconnect() end) end
    if flyKU then pcall(function() flyKU:Disconnect() end) end
    flyCtrl={f=0,b=0,l=0,r=0}; flyLast={f=0,b=0,l=0,r=0}; flySpd=0
end
local function startFly()
    if flyRunning then return end
    flyRunning=true
    local root=plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if not root then flyRunning=false; return end
    local bg=Instance.new("BodyGyro",root)
    bg.P=9e4; bg.MaxTorque=Vector3.new(9e9,9e9,9e9); bg.CFrame=root.CFrame
    local bv=Instance.new("BodyVelocity",root)
    bv.Velocity=Vector3.new(0,.1,0); bv.MaxForce=Vector3.new(9e9,9e9,9e9)
    flyKD=Mouse.KeyDown:Connect(function(k)
        k=k:lower()
        if k=="w" then flyCtrl.f=1 elseif k=="s" then flyCtrl.b=-1
        elseif k=="a" then flyCtrl.l=-1 elseif k=="d" then flyCtrl.r=1 end
    end)
    flyKU=Mouse.KeyUp:Connect(function(k)
        k=k:lower()
        if k=="w" then flyCtrl.f=0 elseif k=="s" then flyCtrl.b=0
        elseif k=="a" then flyCtrl.l=0 elseif k=="d" then flyCtrl.r=0 end
    end)
    task.spawn(function()
        repeat task.wait()
            pcall(function()
                plr.Character.Humanoid.PlatformStand=true
                local mv=(flyCtrl.f+flyCtrl.b~=0 or flyCtrl.l+flyCtrl.r~=0)
                flySpd = mv and math.min(flySpd+FlySpeed*.1,FlySpeed) or math.max(flySpd-FlySpeed*.1,0)
                local cam=Camera.CoordinateFrame
                local d=(mv and flyCtrl or flyLast)
                bv.Velocity = (d.f+d.b~=0 or d.l+d.r~=0)
                    and ((cam.LookVector*(d.f+d.b))+((cam*CFrame.new(d.l+d.r,(d.f+d.b)*.2,0)).Position-cam.Position))*flySpd
                    or Vector3.new(0,.1,0)
                bg.CFrame=cam*CFrame.Angles(-math.rad((flyCtrl.f+flyCtrl.b)*50*flySpd/(FlySpeed==0 and 1 or FlySpeed)),0,0)
                if mv then flyLast={f=flyCtrl.f,b=flyCtrl.b,l=flyCtrl.l,r=flyCtrl.r} end
            end)
        until not flyRunning
        pcall(function() bg:Destroy(); bv:Destroy() end)
    end)
end

-- ─── ANTI AFK ──────────────────────────────────────
local afkConn
local function setAntiAFK(v)
    if v then
        afkConn=Track(plr.Idled:Connect(function()
            game:GetService("VirtualUser"):CaptureController()
            game:GetService("VirtualUser"):ClickButton2(Vector2.new())
        end))
    elseif afkConn then afkConn:Disconnect(); afkConn=nil end
end

-- ─── COIN COLLECT ──────────────────────────────────
local function collectCoins()
    local root=plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    for _,obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name:lower():find("coin") then
            root.CFrame=obj.CFrame+Vector3.new(0,2,0)
        end
    end
end

-- ══════════════════════════════════════════════════
--  GUI BUILDER
-- ══════════════════════════════════════════════════
local SG=Instance.new("ScreenGui")
SG.Name="MM2MenuV3"; SG.ResetOnSpawn=false
SG.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
SG.IgnoreGuiInset=true
pcall(function() SG.Parent=game.CoreGui end)
if not SG.Parent then SG.Parent=plr:WaitForChild("PlayerGui") end

-- Palette
local P={
    bg     =Color3.fromRGB(12,12,18),
    panel  =Color3.fromRGB(20,20,30),
    panel2 =Color3.fromRGB(26,26,38),
    accent =Color3.fromRGB(220,50,80),
    accent2=Color3.fromRGB(50,180,255),
    kill   =Color3.fromRGB(200,40,50),
    text   =Color3.fromRGB(230,230,240),
    sub    =Color3.fromRGB(130,130,155),
    on     =Color3.fromRGB(55,200,90),
    off    =Color3.fromRGB(60,60,82),
    border =Color3.fromRGB(38,38,55),
}

local function Corner(p,r) local c=Instance.new("UICorner",p); c.CornerRadius=UDim.new(0,r or 8); return c end
local function Stroke(p,c,t) local s=Instance.new("UIStroke",p); s.Color=c; s.Thickness=t or 1; return s end
local function Label(p,t,s,col,xa,ya)
    local l=Instance.new("TextLabel",p)
    l.BackgroundTransparency=1; l.Text=t; l.TextSize=s or 13
    l.TextColor3=col or P.text; l.Font=Enum.Font.GothamSemibold
    l.TextXAlignment=xa or Enum.TextXAlignment.Left
    l.TextYAlignment=ya or Enum.TextYAlignment.Center
    l.TextWrapped=true; l.Size=UDim2.new(1,0,1,0); return l
end

-- Main window
local Win=Instance.new("Frame",SG)
Win.Size=UDim2.new(0,390,0,470)
Win.Position=UDim2.new(0.5,-195,0.5,-235)
Win.BackgroundColor3=P.bg; Win.BorderSizePixel=0
Corner(Win,12); Stroke(Win,P.border,1.5)

-- Title bar
local TBar=Instance.new("Frame",Win)
TBar.Size=UDim2.new(1,0,0,44)
TBar.BackgroundColor3=P.panel; TBar.BorderSizePixel=0
Corner(TBar,12)
local TFix=Instance.new("Frame",TBar)
TFix.Size=UDim2.new(1,0,0,12); TFix.Position=UDim2.new(0,0,1,-12)
TFix.BackgroundColor3=P.panel; TFix.BorderSizePixel=0

-- Gradient stripe
local StripeF=Instance.new("Frame",TBar)
StripeF.Size=UDim2.new(0,3,1,0); StripeF.BackgroundColor3=P.accent; StripeF.BorderSizePixel=0
local SG2=Instance.new("UIGradient",StripeF)
SG2.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,P.accent),ColorSequenceKeypoint.new(1,P.accent2)}
SG2.Rotation=90

local TLabel=Label(TBar,"⚔  MM2 Menu  v3",15,P.text)
TLabel.Size=UDim2.new(1,-140,1,0); TLabel.Position=UDim2.new(0,14,0,0)
TLabel.Font=Enum.Font.GothamBold

-- Kill button
local KillBtn=Instance.new("TextButton",TBar)
KillBtn.Size=UDim2.new(0,68,0,26)
KillBtn.Position=UDim2.new(1,-80,0.5,-13)
KillBtn.BackgroundColor3=P.kill; KillBtn.BorderSizePixel=0
KillBtn.Text="✕ KILL"; KillBtn.TextColor3=Color3.new(1,1,1)
KillBtn.Font=Enum.Font.GothamBold; KillBtn.TextSize=12
Corner(KillBtn,6)
KillBtn.MouseButton1Click:Connect(KillAll)
KillBtn.MouseEnter:Connect(function() Tween(KillBtn,{BackgroundColor3=Color3.fromRGB(255,60,70)},.1) end)
KillBtn.MouseLeave:Connect(function() Tween(KillBtn,{BackgroundColor3=P.kill},.1) end)

-- Tab bar
local TabBar=Instance.new("Frame",Win)
TabBar.Size=UDim2.new(1,-16,0,32)
TabBar.Position=UDim2.new(0,8,0,50)
TabBar.BackgroundColor3=P.panel2; TabBar.BorderSizePixel=0
Corner(TabBar,8)
local TabList=Instance.new("UIListLayout",TabBar)
TabList.FillDirection=Enum.FillDirection.Horizontal
TabList.Padding=UDim.new(0,2)
TabList.SortOrder=Enum.SortOrder.LayoutOrder
TabList.VerticalAlignment=Enum.VerticalAlignment.Center
Instance.new("UIPadding",TabBar).PaddingLeft=UDim.new(0,4)

-- Content area
local Content=Instance.new("Frame",Win)
Content.Size=UDim2.new(1,-16,1,-100)
Content.Position=UDim2.new(0,8,0,90)
Content.BackgroundTransparency=1; Content.BorderSizePixel=0
Content.ClipsDescendants=true

local Tabs={}; local ActiveTab=nil

local function makeScroll()
    local sf=Instance.new("ScrollingFrame",Content)
    sf.Size=UDim2.new(1,0,1,0); sf.BackgroundTransparency=1
    sf.BorderSizePixel=0; sf.ScrollBarThickness=3
    sf.ScrollBarImageColor3=P.accent; sf.CanvasSize=UDim2.new(0,0,0,0)
    sf.AutomaticCanvasSize=Enum.AutomaticSize.Y; sf.Visible=false
    local ul=Instance.new("UIListLayout",sf)
    ul.Padding=UDim.new(0,5); ul.SortOrder=Enum.SortOrder.LayoutOrder
    Instance.new("UIPadding",sf).PaddingTop=UDim.new(0,4)
    return sf
end

local function setActiveTab(name)
    ActiveTab=name
    for n,t in pairs(Tabs) do
        t.Scroll.Visible=(n==name)
        Tween(t.Btn,{BackgroundColor3=n==name and P.accent or Color3.fromRGB(0,0,0)},.15)
        Tween(t.Btn,{BackgroundTransparency=n==name and 0 or .7},.15)
    end
end

local function addTab(name,icon)
    local btn=Instance.new("TextButton",TabBar)
    btn.Size=UDim2.new(0,75,0,26)
    btn.BackgroundColor3=Color3.fromRGB(0,0,0); btn.BackgroundTransparency=.7
    btn.BorderSizePixel=0; btn.Text=(icon or "")..name
    btn.TextColor3=P.text; btn.Font=Enum.Font.GothamSemibold; btn.TextSize=11
    Corner(btn,6)
    local scroll=makeScroll()
    Tabs[name]={Btn=btn,Scroll=scroll}
    btn.MouseButton1Click:Connect(function() setActiveTab(name) end)
    return scroll
end

-- ─── WIDGET BUILDERS ───────────────────────────────
local function addSection(scroll, title)
    local f=Instance.new("Frame",scroll)
    f.Size=UDim2.new(1,-8,0,24); f.BackgroundTransparency=1; f.BorderSizePixel=0
    local l=Label(f,("  ╴ %s"):format(title:upper()),10,P.accent)
    l.Font=Enum.Font.GothamBold
    local div=Instance.new("Frame",scroll)
    div.Size=UDim2.new(1,-8,0,1); div.BackgroundColor3=P.border; div.BorderSizePixel=0
end

local function addToggle(scroll, label, key, tbl, callback)
    local row=Instance.new("Frame",scroll)
    row.Size=UDim2.new(1,-8,0,36); row.BackgroundColor3=P.panel; row.BorderSizePixel=0
    Corner(row,7)

    local lbl=Label(row,label,13,P.text)
    lbl.Size=UDim2.new(1,-60,1,0); lbl.Position=UDim2.new(0,12,0,0)

    local pill=Instance.new("Frame",row)
    pill.Size=UDim2.new(0,38,0,20); pill.Position=UDim2.new(1,-50,0.5,-10)
    pill.BackgroundColor3=(tbl[key] and P.on or P.off); pill.BorderSizePixel=0
    Corner(pill,10)
    local knob=Instance.new("Frame",pill)
    knob.Size=UDim2.new(0,14,0,14)
    knob.Position=tbl[key] and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7)
    knob.BackgroundColor3=Color3.new(1,1,1); knob.BorderSizePixel=0; Corner(knob,10)

    local btn=Instance.new("TextButton",row)
    btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1; btn.Text=""
    btn.MouseButton1Click:Connect(function()
        tbl[key]=not tbl[key]
        Tween(pill,{BackgroundColor3=tbl[key] and P.on or P.off},.18)
        Tween(knob,{Position=tbl[key] and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7)},.18)
        if callback then callback(tbl[key]) end
    end)
    btn.MouseEnter:Connect(function() Tween(row,{BackgroundColor3=Color3.fromRGB(28,28,42)},.1) end)
    btn.MouseLeave:Connect(function() Tween(row,{BackgroundColor3=P.panel},.1) end)
    return row
end

local function addButton(scroll, label, col, callback)
    local row=Instance.new("Frame",scroll)
    row.Size=UDim2.new(1,-8,0,36); row.BackgroundColor3=P.panel; row.BorderSizePixel=0
    Corner(row,7)
    local btn=Instance.new("TextButton",row)
    btn.Size=UDim2.new(1,-16,0,26); btn.Position=UDim2.new(0,8,0.5,-13)
    btn.BackgroundColor3=col or P.accent2; btn.BorderSizePixel=0
    btn.Text=label; btn.TextColor3=Color3.new(1,1,1)
    btn.Font=Enum.Font.GothamSemibold; btn.TextSize=12
    Corner(btn,6)
    btn.MouseButton1Click:Connect(callback)
    btn.MouseEnter:Connect(function() Tween(row,{BackgroundColor3=Color3.fromRGB(28,28,42)},.1) end)
    btn.MouseLeave:Connect(function() Tween(row,{BackgroundColor3=P.panel},.1) end)
    return row
end

local function addSlider(scroll, label, min, max, default, callback)
    local row=Instance.new("Frame",scroll)
    row.Size=UDim2.new(1,-8,0,54); row.BackgroundColor3=P.panel; row.BorderSizePixel=0
    Corner(row,7)
    local lbl=Label(row,label.."  ["..default.."]",12,P.text)
    lbl.Size=UDim2.new(1,-16,0,22); lbl.Position=UDim2.new(0,12,0,4)

    local track=Instance.new("Frame",row)
    track.Size=UDim2.new(1,-24,0,6); track.Position=UDim2.new(0,12,0,32)
    track.BackgroundColor3=P.off; track.BorderSizePixel=0; Corner(track,3)

    local fill=Instance.new("Frame",track)
    fill.Size=UDim2.new((default-min)/(max-min),0,1,0)
    fill.BackgroundColor3=P.accent2; fill.BorderSizePixel=0; Corner(fill,3)

    local knob=Instance.new("Frame",track)
    knob.Size=UDim2.new(0,12,0,12); knob.AnchorPoint=Vector2.new(0.5,0.5)
    knob.Position=UDim2.new((default-min)/(max-min),0,0.5,0)
    knob.BackgroundColor3=Color3.new(1,1,1); knob.BorderSizePixel=0; Corner(knob,6)

    local dragging=false
    local function update(x)
        local abs=track.AbsolutePosition.X; local sz=track.AbsoluteSize.X
        local t=math.clamp((x-abs)/sz,0,1)
        local v=math.floor(min+(max-min)*t)
        fill.Size=UDim2.new(t,0,1,0)
        knob.Position=UDim2.new(t,0,0.5,0)
        lbl.Text=label.."  ["..v.."]"
        if callback then callback(v) end
    end

    local ib=Instance.new("TextButton",track)
    ib.Size=UDim2.new(1,0,0,20); ib.Position=UDim2.new(0,0,0.5,-10)
    ib.BackgroundTransparency=1; ib.Text=""
    ib.MouseButton1Down:Connect(function() dragging=true end)
    Track(UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
            update(i.Position.X)
        end
    end))
    Track(UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
    end))
    return row
end

-- ══════════════════════════════════════════════════
--  BUILD TABS
-- ══════════════════════════════════════════════════

-- ── ESP TAB ─────────────────────────────────────
local espScroll=addTab("ESP","👁 ")
addSection(espScroll,"2D ESP")
addToggle(espScroll,"Enable 2D ESP","E2D",ESP,function(v)
    if not v then for _,t in pairs(ESP2DObjects) do hide2D(t) end end
end)
addToggle(espScroll,"Show Names","Names",ESP)
addToggle(espScroll,"Show Health Bar","Health",ESP)
addToggle(espScroll,"Show Distance","Dist",ESP)
addToggle(espScroll,"Show Role Tag","Roles",ESP)
addToggle(espScroll,"Role-Based Colors","TeamCol",ESP)
addSlider(espScroll,"Max Distance",50,2000,500,function(v) ESP.MaxDist=v end)

addSection(espScroll,"3D ESP")
addToggle(espScroll,"Enable 3D ESP","E3D",ESP,function(v)
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=plr and ESP3DObjects[p] then
            ESP3DObjects[p].Adornee=v and p.Character or nil
        end
    end
end)
addSlider(espScroll,"Box Thickness (x100)",1,20,5,function(v)
    ESP.Thickness3D=v/100
    for _,sb in pairs(ESP3DObjects) do sb.LineThickness=v/100 end
end)
addSlider(espScroll,"Surface Transparency",0,100,80,function(v)
    ESP.Trans3D=v/100
    for _,sb in pairs(ESP3DObjects) do sb.SurfaceTransparency=v/100 end
end)

-- ── PLAYER TAB ─────────────────────────────────
local playerScroll=addTab("Player","🎮 ")
addSection(playerScroll,"Movement")
addToggle(playerScroll,"Fly (WASD to move)","Fly",Toggles,function(v)
    if v then startFly() else stopFly() end
end)
addSlider(playerScroll,"Fly Speed",10,300,50,function(v) FlySpeed=v end)
addToggle(playerScroll,"Infinite Stamina","InfStamina",Toggles)
addSlider(playerScroll,"Walk Speed",1,300,16,function(v)
    pcall(function() plr.Character.Humanoid.WalkSpeed=v end)
end)
addSlider(playerScroll,"Jump Power",1,250,50,function(v)
    pcall(function() plr.Character.Humanoid.JumpPower=v end)
end)
addButton(playerScroll,"Respawn",Color3.fromRGB(180,60,60),function()
    pcall(function() plr.Character.Humanoid.Health=0 end)
end)

addSection(playerScroll,"Utility")
addToggle(playerScroll,"Anti AFK","AntiAFK",Toggles,function(v) setAntiAFK(v) end)
addToggle(playerScroll,"Void Protection","VoidProt",Toggles,function(v)
    workspace.FallenPartsDestroyHeight=v and 0/0 or -500
end)
addToggle(playerScroll,"No Fog","NoFog",Toggles)
addToggle(playerScroll,"Full Bright","FullBright",Toggles,function(v)
    workspace.GlobalShadows=not v
    Lighting.Brightness=v and 3 or 2
end)

-- ── GAME TAB ───────────────────────────────────
local gameScroll=addTab("Game","⚔ ")
addSection(gameScroll,"Coins")
addToggle(gameScroll,"Auto Collect Coins","CoinCollect",Toggles)
addButton(gameScroll,"Collect Now",P.accent2,function() collectCoins(); Notify("MM2","Coins collected!",3) end)

addSection(gameScroll,"Teleports")
local tps={
    {"Cannon 1",  -61,34,-228},
    {"Cannon 2",  50, 34,-228},
    {"Cannon 3",  -6, 35,-106},
    {"Minefield", -65,23,-151},
    {"Balloon",   -118,23,-126},
    {"Stairs Top",-6, 203,-496},
    {"Skyscraper",142,1033,-192},
    {"Pool",      -133,65,-321},
}
for _,tp in ipairs(tps) do
    local name,x,y,z=tp[1],tp[2],tp[3],tp[4]
    addButton(gameScroll,"⬆ TP: "..name,P.panel2,function()
        for i=1,25 do task.wait()
            pcall(function() plr.Character.HumanoidRootPart.CFrame=CFrame.new(x,y,z) end)
        end
    end)
end

-- ── MISC TAB ───────────────────────────────────
local miscScroll=addTab("Misc","🔧 ")
addSection(miscScroll,"Visuals")
addButton(miscScroll,"☀ Day Time",Color3.fromRGB(220,170,40),function()
    Lighting.ClockTime=14
end)
addButton(miscScroll,"🌙 Night Time",Color3.fromRGB(40,60,140),function()
    Lighting.ClockTime=20
end)
addButton(miscScroll,"✨ Enable Shaders",Color3.fromRGB(80,60,180),function()
    local b=Instance.new("BloomEffect",Lighting); b.Intensity=0.3; b.Size=10; b.Threshold=0.8
    local c=Instance.new("ColorCorrectionEffect",Lighting); c.Contrast=0.1; c.Saturation=0.2
    local s=Instance.new("SunRaysEffect",Lighting); s.Intensity=0.08; s.Spread=0.7
    Notify("MM2","Shaders enabled!",3)
end)
addButton(miscScroll,"Clear Shaders",P.panel2,function()
    for _,v in ipairs(Lighting:GetChildren()) do
        if v:IsA("BloomEffect") or v:IsA("ColorCorrectionEffect")
          or v:IsA("SunRaysEffect") or v:IsA("BlurEffect") then v:Destroy() end
    end
end)
addSection(miscScroll,"Server")
addButton(miscScroll,"🔄 Rejoin",Color3.fromRGB(60,120,200),function()
    game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId,game.JobId,plr)
end)
addButton(miscScroll,"⏩ Server Hop",Color3.fromRGB(60,120,200),function()
    local http=syn and syn.request or http_request or request
    if not http then Notify("MM2","No HTTP found.",4) return end
    local ok,res=pcall(http,{Url=("https://games.roblox.com/v1/games/%d/servers/Public?limit=100"):format(game.PlaceId)})
    if ok then
        local d=game:GetService("HttpService"):JSONDecode(res.Body)
        local srv={}
        for _,v in ipairs(d.data or {}) do
            if v.playing<v.maxPlayers and v.id~=game.JobId then table.insert(srv,v.id) end
        end
        if #srv>0 then
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId,srv[math.random(1,#srv)],plr)
        else Notify("MM2","No servers found.",4) end
    end
end)

addSection(miscScroll,"Kill Script")
addButton(miscScroll,"💀 DESTROY MENU + STOP ALL",P.kill,KillAll)

-- ── ACTIVATE FIRST TAB ─────────────────────────
setActiveTab("ESP")

-- ─── DRAG ──────────────────────────────────────────
do
    local dragging,dragStart,startPos
    TBar.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            dragging=true; dragStart=i.Position; startPos=Win.Position
        end
    end)
    Track(UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
            local d=i.Position-dragStart
            Win.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
        end
    end))
    Track(UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
    end))
end

-- ─── INSERT KEY TOGGLE ─────────────────────────────
Track(UserInputService.InputBegan:Connect(function(i,g)
    if g then return end
    if i.KeyCode==Enum.KeyCode.Insert then Win.Visible=not Win.Visible end
end))

-- ─── MAIN RENDER LOOP ──────────────────────────────
Track(RunService.RenderStepped:Connect(function()
    local myChar=plr.Character
    local myRoot=myChar and myChar:FindFirstChild("HumanoidRootPart")

    if Toggles.InfStamina and myChar then
        local h=myChar:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed=math.max(h.WalkSpeed,50) end
    end
    if Toggles.NoFog then workspace.FogEnd=1e6; workspace.FogStart=1e6 end
    if Toggles.CoinCollect then collectCoins() end

    for _,player in ipairs(Players:GetPlayers()) do
        if player==plr then continue end
        local char=player.Character
        local root=char and char:FindFirstChild("HumanoidRootPart")
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        local alive=hum and hum.Health>0
        local col=ESP.TeamCol and roleCol(player) or Color3.new(1,1,1)

        -- 3D
        local sb=ESP3DObjects[player]
        if sb then
            if ESP.E3D and char and alive then
                sb.Adornee=char
                if ESP.TeamCol then sb.Color3=col; sb.SurfaceColor3=col end
            else sb.Adornee=nil end
        end

        -- 2D
        local t=ESP2DObjects[player]
        if not t then continue end
        if not (ESP.E2D and root and alive) then hide2D(t); continue end

        local sp,onS,depth=Camera:WorldToViewportPoint(root.Position)
        local dist=myRoot and (myRoot.Position-root.Position).Magnitude or 0
        if not onS or depth<=0 or dist>ESP.MaxDist then hide2D(t); continue end

        local scale=1/(depth*0.009)
        local bw=math.clamp(scale*40,20,220)
        local bh=math.clamp(scale*65,30,310)
        local bx=sp.X-bw/2; local by=sp.Y-bh/2

        t.BoxOL.Visible=true; t.BoxOL.Size=Vector2.new(bw+2,bh+2); t.BoxOL.Position=Vector2.new(bx-1,by-1)
        t.Box.Visible=true; t.Box.Color=col; t.Box.Size=Vector2.new(bw,bh); t.Box.Position=Vector2.new(bx,by)

        t.Name.Visible=ESP.Names; t.Name.Text=player.DisplayName
        t.Name.Color=col; t.Name.Position=Vector2.new(sp.X,by-15)

        local hp=hum.Health; local mx=hum.MaxHealth; local ratio=mx>0 and hp/mx or 1
        local barH=math.max(bh*ratio,2)
        t.HpBG.Visible=ESP.Health; t.HpBG.Size=Vector2.new(4,bh); t.HpBG.Position=Vector2.new(bx-8,by)
        t.Hp.Visible=ESP.Health
        t.Hp.Color=Color3.fromRGB(math.floor(255*(1-ratio)),math.floor(255*ratio),30)
        t.Hp.Size=Vector2.new(4,barH); t.Hp.Position=Vector2.new(bx-8,by+bh-barH)

        t.Dist.Visible=ESP.Dist; t.Dist.Text=("[%dm]"):format(math.floor(dist))
        t.Dist.Position=Vector2.new(sp.X,by+bh+3)

        t.Role.Visible=ESP.Roles; t.Role.Text="["..roleStr(player).."]"
        t.Role.Color=col; t.Role.Position=Vector2.new(sp.X,by+bh+(ESP.Dist and 16 or 3))
    end
end))

-- ─── RESPAWN HANDLER ───────────────────────────────
Track(plr.CharacterAdded:Connect(function()
    if Toggles.Fly then stopFly() end
end))

-- ─── OPEN ANIMATION ────────────────────────────────
Win.Size=UDim2.new(0,390,0,0)
Tween(Win,{Size=UDim2.new(0,390,0,470)},.35)

Notify("MM2 Menu","Loaded! No dependencies · INSERT to hide · ✕ KILL to destroy.",6)
