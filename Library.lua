--[[
    VERDANT UI  ·  built from scratch
    Black theme · green accent · rounded modern layout
    API is Obsidian-compatible (CreateWindow / AddTab / AddLeftGroupbox / AddToggle ...)
]]

local cloneref = cloneref or clonereference or function(Instance_)
    return Instance_
end
local function Service(Name)
    return cloneref(game:GetService(Name))
end

local Players = Service("Players")
local RunService = Service("RunService")
local UserInputService = Service("UserInputService")
local TweenService = Service("TweenService")
local CoreGui = Service("CoreGui")
local TextService = Service("TextService")
local Teams = Service("Teams")

local getgenv = getgenv or function()
    return shared
end
local gethui = gethui or function()
    return CoreGui
end
local protectgui = protectgui or (syn and syn.protect_gui) or function() end

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

--// Unload a previous copy if the script is executed twice
do
    local Env = getgenv()
    if Env.VerdantLibrary and typeof(Env.VerdantLibrary.Unload) == "function" then
        pcall(Env.VerdantLibrary.Unload, Env.VerdantLibrary)
    end
end

--// Fonts (Inter if available, Gotham otherwise)
local function MakeFont(Weight, Fallback)
    local Ok, Result = pcall(function()
        return Font.new("rbxasset://fonts/families/Inter.json", Weight, Enum.FontStyle.Normal)
    end)
    if Ok and Result then
        return Result
    end
    return Font.fromEnum(Fallback)
end

local Fonts = {
    Regular = MakeFont(Enum.FontWeight.Regular, Enum.Font.Gotham),
    Medium = MakeFont(Enum.FontWeight.Medium, Enum.Font.GothamMedium),
    SemiBold = MakeFont(Enum.FontWeight.SemiBold, Enum.Font.GothamBold),
    Bold = MakeFont(Enum.FontWeight.Bold, Enum.Font.GothamBold),
}

--// Library table
local Library = {
    Version = "1.0.0",
    Toggled = true,
    Unloaded = false,

    Toggles = {},
    Options = {},
    Labels = {},
    Buttons = {},
    Tabs = {},

    Signals = {},
    UnloadSignals = {},
    Registry = {}, -- strong on purpose: Roblox may drop weak Instance keys that nothing references

    IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,
    DPIScale = 1,
    CornerRadius = 12,
    NotifySide = "Right",
    ToggleKeybind = nil,
    ForceCheckbox = false,
    ShowToggleFrameInKeybinds = true,
    ActivePopup = nil,
    Picking = false,
    Fonts = Fonts,

    Scheme = {
        BackgroundColor = Color3.fromRGB(11, 11, 11),
        MainColor = Color3.fromRGB(17, 17, 17),
        AccentColor = Color3.fromRGB(46, 213, 115),
        OutlineColor = Color3.fromRGB(38, 38, 38),
        FontColor = Color3.fromRGB(236, 236, 236),
        RedColor = Color3.fromRGB(255, 72, 90),
        DarkColor = Color3.fromRGB(0, 0, 0),
        WhiteColor = Color3.fromRGB(255, 255, 255),
        Font = Fonts.SemiBold,
    },
}

--// The scheme is wrapped so a theme manager can both write to it and replace it
--// (Obsidian's ThemeManager does `Library.Scheme = {...}` in SetDefaultTheme).
local SchemeData = Library.Scheme
Library.LockAccent = false -- set to true to stop themes from changing the accent colour
Library.LockFont = true -- keeps the menu font; set to false to let themes change it
Library.FontScale = 1.2

local SchemeProxy = setmetatable({}, {
    __index = SchemeData,
    __newindex = function(_, Key, Value)
        if Key == "AccentColor" and Library.LockAccent then
            return
        end
        if Key == "Font" and Library.LockFont then
            return
        end
        SchemeData[Key] = Value
    end,
})

Library.Scheme = nil
setmetatable(Library, {
    __index = function(_, Key)
        if Key == "Scheme" then
            return SchemeProxy
        end
        if Key == "ShowCustomCursor" then
            local Cur = rawget(Library, "Cursor")
            return Cur ~= nil and Cur.Enabled
        end
        return nil
    end,
    __newindex = function(Self, Key, Value)
        if Key == "ShowCustomCursor" then
            local Cur = rawget(Self, "Cursor")
            if Cur then
                Cur.Enabled = Value == true
                Cur:Update()
            end
            return
        end
        if Key == "Scheme" then
            if typeof(Value) == "table" and Value ~= SchemeProxy then
                for K, V in pairs(Value) do
                    SchemeProxy[K] = V
                end
                Library:UpdateColorsUsingRegistry()
            end
            return
        end
        rawset(Self, Key, Value)
    end,
})

local Scheme = SchemeProxy
getgenv().VerdantLibrary = Library

function Library:SetAccent(Color)
    if typeof(Color) == "Color3" then
        SchemeData.AccentColor = Color
        Library:UpdateColorsUsingRegistry()
    end
end

--// Colour helpers
local function Lerp(A, B, T)
    return A:Lerp(B, T)
end

function Library:GetLighterColor(Color)
    return Lerp(Color, Color3.new(1, 1, 1), 0.07)
end

function Library:GetDarkerColor(Color)
    return Lerp(Color, Color3.new(0, 0, 0), 0.35)
end

function Library:GetBetterColor(Color, Amount)
    Amount = Amount or 0
    if Amount >= 0 then
        return Lerp(Color, Color3.new(1, 1, 1), math.clamp(Amount / 255, 0, 1))
    end
    return Lerp(Color, Color3.new(0, 0, 0), math.clamp(-Amount / 255, 0, 1))
end

--// Colours that are derived from the main scheme (so themes keep working)
local Derived = {
    ElementColor = function()
        return Lerp(Scheme.MainColor, Color3.new(1, 1, 1), 0.045)
    end,
    HoverColor = function()
        return Lerp(Scheme.MainColor, Color3.new(1, 1, 1), 0.09)
    end,
    MutedColor = function()
        return Lerp(Scheme.FontColor, Scheme.BackgroundColor, 0.36)
    end,
    SubtleColor = function()
        return Lerp(Scheme.FontColor, Scheme.BackgroundColor, 0.58)
    end,
    SidebarColor = function()
        return Lerp(Scheme.BackgroundColor, Scheme.MainColor, 0.35)
    end,
}

local function Resolve(Key)
    if typeof(Key) == "function" then
        return Key()
    end
    if Derived[Key] then
        return Derived[Key]()
    end
    return Scheme[Key]
end

local ColorProps = {
    BackgroundColor3 = true,
    TextColor3 = true,
    ImageColor3 = true,
    BorderColor3 = true,
    Color = true,
    ScrollBarImageColor3 = true,
    PlaceholderColor3 = true,
}

function Library:AddToRegistry(Inst, Props)
    local Existing = Library.Registry[Inst]
    if not Existing then
        Existing = {}
        Library.Registry[Inst] = Existing
    end
    for Prop, Key in pairs(Props) do
        Existing[Prop] = Key
    end
end

function Library:RemoveFromRegistry(Inst)
    Library.Registry[Inst] = nil
end

function Library:UpdateColorsUsingRegistry()
    local Dead = {}
    local Root = Library.ScreenGui
    for Inst, Props in pairs(Library.Registry) do
        --// forget objects that have been destroyed (popups, notifications, ...)
        if Root and not Inst:IsDescendantOf(Root) then
            table.insert(Dead, Inst)
        else
            for Prop, Key in pairs(Props) do
                local Value = Resolve(Key)
                if Value ~= nil then
                    pcall(function()
                        Inst[Prop] = Value
                    end)
                end
            end
        end
    end
    for _, Inst in ipairs(Dead) do
        Library.Registry[Inst] = nil
    end
    if Library.Cursor then
        Library.Cursor:Update()
    end
end

function Library:SetFont(NewFont)
    if Library.LockFont then
        return
    end
    if typeof(NewFont) == "EnumItem" then
        NewFont = Font.fromEnum(NewFont)
    end
    Scheme.Font = NewFont
end

--// Instance factory
local TextClasses = { TextLabel = true, TextButton = true, TextBox = true }

local function New(Class, Props)
    local Inst = Instance.new(Class)
    local Reg = nil

    if TextClasses[Class] then
        Inst.FontFace = Scheme.Font
        Inst.TextSize = math.floor(14 * Library.FontScale + 0.5)
        Inst.RichText = false
        if Props.TextColor3 == nil then
            Inst.TextColor3 = Scheme.FontColor
            Reg = { TextColor3 = "FontColor" }
        end
        if Class == "TextLabel" or Class == "TextBox" then
            Inst.BackgroundTransparency = 1
        end
        if Class == "TextBox" then
            Inst.ClearTextOnFocus = false
        end
        if Class == "TextButton" then
            Inst.AutoButtonColor = false
            Inst.Text = ""
        end
    elseif Class == "ImageLabel" or Class == "ImageButton" then
        Inst.BackgroundTransparency = 1
        if Class == "ImageButton" then
            Inst.AutoButtonColor = false
        end
    elseif Class == "ScrollingFrame" then
        Inst.BackgroundTransparency = 1
        Inst.ScrollBarThickness = 2
        Inst.ScrollBarImageColor3 = Derived.SubtleColor()
        Reg = { ScrollBarImageColor3 = "SubtleColor" }
        Inst.ScrollingDirection = Enum.ScrollingDirection.Y
        Inst.CanvasSize = UDim2.new()
        Inst.AutomaticCanvasSize = Enum.AutomaticSize.Y
        Inst.ElasticBehavior = Enum.ElasticBehavior.Never
        Inst.VerticalScrollBarInset = Enum.ScrollBarInset.None
    end

    if Inst:IsA("GuiObject") then
        Inst.BorderSizePixel = 0
    end

    local Parent = nil
    for Prop, Value in pairs(Props) do
        if Prop == "Parent" then
            Parent = Value
        elseif Prop == "TextSize" then
            Inst.TextSize = math.floor(Value * Library.FontScale + 0.5)
        elseif ColorProps[Prop] and (typeof(Value) == "string" or typeof(Value) == "function") then
            local Resolved = Resolve(Value)
            if Resolved ~= nil then
                Inst[Prop] = Resolved
                Reg = Reg or {}
                Reg[Prop] = Value
            end
        else
            Inst[Prop] = Value
        end
    end

    if Reg then
        Library:AddToRegistry(Inst, Reg)
    end

    if Parent then
        Inst.Parent = Parent
    end
    return Inst
end

local function Corner(Parent, Radius)
    return New("UICorner", { CornerRadius = UDim.new(0, Radius or 8), Parent = Parent })
end

local function Round(Parent)
    return New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = Parent })
end

local function Stroke(Parent, Key, Thickness)
    return New("UIStroke", {
        Color = Key or "OutlineColor",
        Thickness = Thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = Parent,
    })
end

local function Pad(Parent, Top, Right, Bottom, Left)
    return New("UIPadding", {
        PaddingTop = UDim.new(0, Top or 0),
        PaddingRight = UDim.new(0, Right or Top or 0),
        PaddingBottom = UDim.new(0, Bottom or Top or 0),
        PaddingLeft = UDim.new(0, Left or Right or Top or 0),
        Parent = Parent,
    })
end

local function ListLayout(Parent, Padding, Direction)
    return New("UIListLayout", {
        Padding = UDim.new(0, Padding or 0),
        FillDirection = Direction or Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = Parent,
    })
end

local function Tween(Inst, Props, Time, Style, Direction)
    local Info = TweenInfo.new(
        Time or 0.16,
        Style or Enum.EasingStyle.Quad,
        Direction or Enum.EasingDirection.Out
    )
    local Created = TweenService:Create(Inst, Info, Props)
    Created:Play()
    return Created
end

local function SafeCall(Func, ...)
    if typeof(Func) ~= "function" then
        return
    end
    local Ok, Err = pcall(Func, ...)
    if not Ok then
        warn("[Verdant] callback error: " .. tostring(Err))
    end
end

function Library:GiveSignal(Connection)
    table.insert(Library.Signals, Connection)
    return Connection
end

function Library:OnUnload(Func)
    table.insert(Library.UnloadSignals, Func)
end

local function RandomName()
    local Chars = {}
    for Index = 1, 14 do
        Chars[Index] = string.char(math.random(97, 122))
    end
    return table.concat(Chars)
end

--// Root gui
local ScreenGui = New("ScreenGui", {
    Name = RandomName(),
    DisplayOrder = 999999,
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
pcall(protectgui, ScreenGui)
do
    local Ok = pcall(function()
        ScreenGui.Parent = gethui()
    end)
    if not Ok or not ScreenGui.Parent then
        local Ok2 = pcall(function()
            ScreenGui.Parent = CoreGui
        end)
        if not Ok2 or not ScreenGui.Parent then
            ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        end
    end
end
Library.ScreenGui = ScreenGui

--// Layers
local Overlay = New("Frame", {
    Name = "Overlay",
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
    ZIndex = 50,
    Parent = ScreenGui,
})
Library.Overlay = Overlay
Library.PopupParent = Overlay

local NotifyHolder = New("Frame", {
    Name = "Notifications",
    BackgroundTransparency = 1,
    Size = UDim2.new(0, 300, 1, -32),
    ZIndex = 100,
    Parent = ScreenGui,
})
local NotifyList = ListLayout(NotifyHolder, 8)

function Library:SetNotifySide(Side)
    Side = (Side == "Left") and "Left" or "Right"
    Library.NotifySide = Side
    if Side == "Left" then
        NotifyHolder.AnchorPoint = Vector2.new(0, 0)
        NotifyHolder.Position = UDim2.new(0, 16, 0, 16)
        NotifyList.HorizontalAlignment = Enum.HorizontalAlignment.Left
    else
        NotifyHolder.AnchorPoint = Vector2.new(1, 0)
        NotifyHolder.Position = UDim2.new(1, -16, 0, 16)
        NotifyList.HorizontalAlignment = Enum.HorizontalAlignment.Right
    end
end
Library:SetNotifySide("Right")

--// Modal element (frees the mouse while the menu is open)
local ModalElement = New("TextButton", {
    BackgroundTransparency = 1,
    Modal = false,
    Size = UDim2.fromScale(0, 0),
    Text = "",
    Parent = ScreenGui,
})

--// Icons (Lucide through Molto, with a fallback source)
local IconModule = nil

function Library:SetIconModule(Module)
    IconModule = Module
end

function Library:GetIcon(Name)
    if typeof(Name) ~= "string" or not IconModule then
        return nil
    end
    local Ok, Icon = pcall(IconModule.GetAsset, Name)
    if not Ok or not Icon then
        return nil
    end
    local Result = {
        Url = Icon.Url,
        ImageRectOffset = Icon.ImageRectOffset or Vector2.zero,
        ImageRectSize = Icon.ImageRectSize or Vector2.zero,
    }
    if IconModule.GetFontAsset then
        local Ok2, FontIcon = pcall(IconModule.GetFontAsset, Name)
        if Ok2 and FontIcon and FontIcon.FontFace and FontIcon.Text then
            Result.FontFace = FontIcon.FontFace
            Result.Text = FontIcon.Text
        end
    end
    return Result
end

--// Accepts a lucide name, an asset id, or an rbxassetid:// string
function Library:ResolveIcon(Name)
    if Name == nil or Name == "" then
        return nil
    end
    if tonumber(Name) then
        return { Url = "rbxassetid://" .. tostring(Name), ImageRectOffset = Vector2.zero, ImageRectSize = Vector2.zero, Custom = true }
    end
    if typeof(Name) == "string" and (Name:match("^rbxassetid://") or Name:match("^rbxasset://") or Name:match("^rbxthumb://")) then
        return { Url = Name, ImageRectOffset = Vector2.zero, ImageRectSize = Vector2.zero, Custom = true }
    end
    return Library:GetIcon(Name)
end

function Library:ApplyIcon(Image, Icon, Size)
    if not Image or not Icon then
        return
    end
    local FontLabel = Image:FindFirstChild("__font")

    if Icon.FontFace and Icon.Text then
        if not FontLabel then
            FontLabel = New("TextLabel", {
                Name = "__font",
                Size = UDim2.fromScale(1, 1),
                TextXAlignment = Enum.TextXAlignment.Center,
                TextYAlignment = Enum.TextYAlignment.Center,
                TextColor3 = Image.ImageColor3,
                Parent = Image,
            })
            Library:RemoveFromRegistry(FontLabel)
            Image:GetPropertyChangedSignal("ImageColor3"):Connect(function()
                FontLabel.TextColor3 = Image.ImageColor3
            end)
            Image:GetPropertyChangedSignal("ImageTransparency"):Connect(function()
                FontLabel.TextTransparency = Image.ImageTransparency
            end)
        end
        FontLabel.FontFace = Icon.FontFace
        FontLabel.Text = Icon.Text
        FontLabel.TextSize = Size or 16
        FontLabel.TextColor3 = Image.ImageColor3
        FontLabel.TextTransparency = Image.ImageTransparency
        Image.Image = ""
        return
    end

    if FontLabel then
        FontLabel:Destroy()
    end
    Image.Image = Icon.Url or ""
    Image.ImageRectOffset = Icon.ImageRectOffset or Vector2.zero
    Image.ImageRectSize = Icon.ImageRectSize or Vector2.zero
end

do
    local Sources = {
        { "https://raw.githubusercontent.com/notpoiu/Molto/refs/heads/main/source.lua", true },
        { "https://raw.githubusercontent.com/notpoiu/lucide-roblox-direct/refs/heads/main/source.lua", false },
    }
    local Loaded = false
    for _, Source in ipairs(Sources) do
        for _ = 1, 3 do
            local Ok, Module = pcall(function()
                return loadstring(game:HttpGet(Source[1]))()
            end)
            if Ok and Module then
                if Source[2] and Module.SetProvider then
                    pcall(Module.SetProvider, "lucide")
                end
                Library:SetIconModule(Module)
                Loaded = true
                break
            end
            task.wait(0.25)
        end
        if Loaded then
            break
        end
    end
end

--// Drawn glyphs (no icon pack needed, so they can never show the wrong shape)
local function Line(Parent, Length, Thickness, Rotation, X, Y, ColorKey)
    local Bar = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = ColorKey or "MutedColor",
        Position = UDim2.fromOffset(X, Y),
        Rotation = Rotation,
        Size = UDim2.fromOffset(Length, Thickness),
        Parent = Parent,
    })
    Round(Bar)
    return Bar
end

local function DrawChevron(Parent, ColorKey)
    local Box = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(12, 12),
        Parent = Parent,
    })
    Line(Box, 7.6, 2, 45, 3.8, 6.2, ColorKey)
    Line(Box, 7.6, 2, -45, 8.2, 6.2, ColorKey)
    return Box
end

local function DrawSearch(Parent, ColorKey)
    local Box = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(16, 16),
        Parent = Parent,
    })
    local Ring = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(1, 1),
        Size = UDim2.fromOffset(10, 10),
        Parent = Box,
    })
    Round(Ring)
    New("UIStroke", { Color = ColorKey or "MutedColor", Thickness = 1.6, Parent = Ring })
    Line(Box, 6, 1.8, 45, 12.4, 12.4, ColorKey)
    return Box
end

local function DrawCross(Parent, ColorKey)
    local Box = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(12, 12),
        Parent = Parent,
    })
    Line(Box, 14, 1.8, 45, 6, 6, ColorKey)
    Line(Box, 14, 1.8, -45, 6, 6, ColorKey)
    return Box
end

local function DrawCheck(Parent, ColorKey)
    local Box = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(18, 18),
        Parent = Parent,
    })
    local A = Line(Box, 5, 2, 45, 6.6, 10.8, ColorKey)
    local B = Line(Box, 9.5, 2, -45, 10.8, 8.6, ColorKey)
    return Box, { A, B }
end

local function DrawGrip(Parent, ColorKey)
    local Box = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(12, 12),
        Parent = Parent,
    })
    Line(Box, 12, 1.5, -45, 6, 6, ColorKey)
    Line(Box, 6, 1.5, -45, 8.5, 8.5, ColorKey)
    return Box
end

--// Popups (dropdowns, colour pickers, key modes)
local function IsInside(Gui, Position)
    if not Gui or not Gui.Parent then
        return false
    end
    local P, S = Gui.AbsolutePosition, Gui.AbsoluteSize
    return Position.X >= P.X and Position.X <= P.X + S.X and Position.Y >= P.Y and Position.Y <= P.Y + S.Y
end

function Library:ClosePopup()
    local Active = Library.ActivePopup
    if Active then
        Library.ActivePopup = nil
        if Active.Watch then
            Active.Watch:Disconnect()
        end
        if Active.Blocker then
            Active.Blocker:Destroy()
        end
        pcall(Active.Close)
    end
end

function Library:RegisterPopup(Frame, CloseFunc, Opener)
    Library:ClosePopup()
    local Entry = { Frame = Frame, Close = CloseFunc, Opener = Opener, Opened = os.clock() }

    --// An invisible button behind the popup catches any click outside of it.
    --// (The engine does the hit-testing, so no coordinate maths is involved.)
    local Blocker = New("TextButton", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(-3000, -3000),
        Size = UDim2.fromOffset(6000, 6000),
        ZIndex = 9,
        Parent = Frame.Parent,
    })
    local function Dismiss()
        if Library.ActivePopup == Entry then
            Library:ClosePopup()
        end
    end
    Blocker.MouseButton1Down:Connect(Dismiss)
    Blocker.MouseButton2Down:Connect(Dismiss)
    Entry.Blocker = Blocker

    --// close when whatever opened it moves (scrolling, dragging, resizing)
    if Opener then
        Entry.Watch = Opener:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
            if Library.ActivePopup == Entry and os.clock() - Entry.Opened > 0.25 then
                Library:ClosePopup()
            end
        end)
    end
    Library.ActivePopup = Entry
end

function Library:IsPopupOpenFor(Opener)
    return Library.ActivePopup ~= nil and Library.ActivePopup.Opener == Opener
end

--// Place a popup under (or above) an anchor, never on top of it.
--// Positions are worked out relative to the popup's parent, so any global
--// offset (GUI inset, container quirks) cancels out. If neither side has
--// room the popup is shortened and its list scrolls.
local function PlacePopup(Popup, Anchor, Width, Height, AlignRight)
    local Parent = Popup.Parent
    local Scale = 1
    local ScaleObject = Parent:FindFirstChildOfClass("UIScale")
    if ScaleObject then
        Scale = ScaleObject.Scale
    end

    local ViewSize = Overlay.AbsoluteSize
    local ParentPos = Parent.AbsolutePosition
    local AnchorPos, AnchorSize = Anchor.AbsolutePosition, Anchor.AbsoluteSize
    local Margin, Gap = 8, 6
    local PxWidth = Width * Scale
    local PxHeight = Height * Scale

    local X = AnchorPos.X
    if AlignRight then
        X = AnchorPos.X + AnchorSize.X - PxWidth
    end
    X = math.clamp(X, Margin, math.max(Margin, ViewSize.X - PxWidth - Margin))

    --// conservative vertical bounds (keeps clear of the top bar area)
    local Bottom = ViewSize.Y - 70
    local SpaceBelow = Bottom - (AnchorPos.Y + AnchorSize.Y + Gap)
    local SpaceAbove = AnchorPos.Y - Gap - 10

    local Y
    if PxHeight <= SpaceBelow then
        Y = AnchorPos.Y + AnchorSize.Y + Gap
    elseif PxHeight <= SpaceAbove then
        Y = AnchorPos.Y - Gap - PxHeight
    elseif SpaceBelow >= SpaceAbove then
        PxHeight = math.max(60 * Scale, SpaceBelow)
        Y = AnchorPos.Y + AnchorSize.Y + Gap
    else
        PxHeight = math.max(60 * Scale, SpaceAbove)
        Y = AnchorPos.Y - Gap - PxHeight
    end

    Popup.Position = UDim2.fromOffset((X - ParentPos.X) / Scale, (Y - ParentPos.Y) / Scale)
    Popup.Size = UDim2.fromOffset(Width, PxHeight / Scale)
end

--// Tooltip
local TooltipLabel = New("TextLabel", {
    AutomaticSize = Enum.AutomaticSize.XY,
    BackgroundTransparency = 0,
    BackgroundColor3 = "ElementColor",
    Size = UDim2.fromOffset(0, 0),
    TextSize = 12,
    TextColor3 = "FontColor",
    Visible = false,
    ZIndex = 200,
    Parent = ScreenGui,
})
Corner(TooltipLabel, 6)
Stroke(TooltipLabel)
Pad(TooltipLabel, 5, 8, 5, 8)

function Library:AddTooltip(Gui, Text)
    if not Gui or typeof(Text) ~= "string" or Text == "" then
        return
    end
    local Follow = nil
    local function Hide()
        if Follow then
            Follow:Disconnect()
            Follow = nil
        end
        TooltipLabel.Visible = false
    end
    Gui.MouseEnter:Connect(function()
        TooltipLabel.Text = Text
        TooltipLabel.Visible = true
        if Follow then
            Follow:Disconnect()
        end
        Follow = RunService.RenderStepped:Connect(function()
            local Mouse = UserInputService:GetMouseLocation()
            TooltipLabel.Position = UDim2.fromOffset(Mouse.X + 14, Mouse.Y + 10)
        end)
    end)
    Gui.MouseLeave:Connect(Hide)
    Gui.AncestryChanged:Connect(function()
        if not Gui.Parent then
            Hide()
        end
    end)
end

--// Notifications
function Library:Notify(Info, Time)
    if Library.Unloaded then
        return
    end
    if typeof(Info) == "string" then
        Info = { Description = Info, Time = Time }
    end
    Info = Info or {}

    local Duration = tonumber(Info.Time) or tonumber(Time) or 4
    local Title = Info.Title
    local Description = Info.Description or Info.Text or ""
    local Left = Library.NotifySide == "Left"

    local Wrapper = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Size = UDim2.new(1, 0, 0, 0),
        Parent = NotifyHolder,
    })
    local Card = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = "MainColor",
        Position = UDim2.new(Left and -1.1 or 1.1, 0, 0, 0),
        Size = UDim2.new(1, 0, 0, 0),
        Parent = Wrapper,
    })
    Corner(Card, 10)
    Stroke(Card)

    local Content = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        Parent = Card,
    })
    Pad(Content, 12, 14, 18, 14)
    ListLayout(Content, 3)

    if Title and Title ~= "" then
        New("TextLabel", {
            AutomaticSize = Enum.AutomaticSize.Y,
            FontFace = Fonts.SemiBold,
            LayoutOrder = 1,
            Size = UDim2.new(1, 0, 0, 0),
            Text = tostring(Title),
            TextSize = 14,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = Content,
        })
    end
    if Description ~= "" then
        New("TextLabel", {
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 2,
            Size = UDim2.new(1, 0, 0, 0),
            Text = tostring(Description),
            TextColor3 = "MutedColor",
            TextSize = 13,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = Content,
        })
    end

    local Track = New("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        BackgroundColor3 = "ElementColor",
        Position = UDim2.new(0, 14, 1, -8),
        Size = UDim2.new(1, -28, 0, 3),
        Parent = Card,
    })
    Round(Track)
    local Fill = New("Frame", {
        BackgroundColor3 = "AccentColor",
        Size = UDim2.fromScale(1, 1),
        Parent = Track,
    })
    Round(Fill)

    local Notification = {}
    local Closed = false

    function Notification:Destroy()
        if Closed then
            return
        end
        Closed = true
        Tween(Card, { Position = UDim2.new(Left and -1.1 or 1.1, 0, 0, 0) }, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        task.delay(0.28, function()
            Wrapper:Destroy()
        end)
    end

    Tween(Card, { Position = UDim2.new(0, 0, 0, 0) }, 0.3, Enum.EasingStyle.Back)
    Tween(Fill, { Size = UDim2.fromScale(0, 1) }, Duration, Enum.EasingStyle.Linear)
    task.delay(Duration, function()
        Notification:Destroy()
    end)

    return Notification
end

--// Unload
function Library:Unload()
    if Library.Unloaded then
        return
    end
    Library.Unloaded = true

    for _, Func in ipairs(Library.UnloadSignals) do
        pcall(Func)
    end
    for _, Connection in ipairs(Library.Signals) do
        pcall(function()
            Connection:Disconnect()
        end)
    end
    pcall(function()
        ModalElement.Modal = false
    end)
    ScreenGui:Destroy()

    if getgenv().VerdantLibrary == Library then
        getgenv().VerdantLibrary = nil
    end
end

--// Shared element tables (filled in by the element section below)
local Funcs = {}
local Addons = {}

--// Input helpers
local function KeyMatches(Input, KeyName)
    if KeyName == nil or KeyName == "None" then
        return false
    end
    if KeyName == "MB1" then
        return Input.UserInputType == Enum.UserInputType.MouseButton1
    elseif KeyName == "MB2" then
        return Input.UserInputType == Enum.UserInputType.MouseButton2
    elseif KeyName == "MB3" then
        return Input.UserInputType == Enum.UserInputType.MouseButton3
    end
    return Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == KeyName
end

local function InputToKeyName(Input)
    if Input.UserInputType == Enum.UserInputType.MouseButton1 then
        return "MB1"
    elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
        return "MB2"
    elseif Input.UserInputType == Enum.UserInputType.MouseButton3 then
        return "MB3"
    elseif Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode ~= Enum.KeyCode.Unknown then
        return Input.KeyCode.Name
    end
    return nil
end

local function IsPress(Input)
    return Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch
end

--// Container objects (groupbox / dependency box / tabbox page)
local function NewContainerObject(Tab, Owner, Container)
    local Object = {
        Tab = Tab,
        Owner = Owner,
        Container = Container,
        Order = 0,
        Type = "Groupbox",
    }
    return setmetatable(Object, { __index = Funcs })
end

--// Groupbox
local function BuildGroupbox(Tab, Column, Side, Name, IconName)
    Tab.Counts[Side] = Tab.Counts[Side] + 1

    local Holder = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = "MainColor",
        LayoutOrder = Tab.Counts[Side],
        Size = UDim2.new(1, 0, 0, 0),
        Parent = Column,
    })
    Corner(Holder, 12)
    Stroke(Holder)
    ListLayout(Holder, 0)

    local Header = New("Frame", {
        BackgroundTransparency = 1,
        LayoutOrder = 1,
        Size = UDim2.new(1, 0, 0, 40),
        Parent = Holder,
    })

    local TextX = 14
    local IconData = Library:ResolveIcon(IconName)
    if IconData then
        local Icon = New("ImageLabel", {
            AnchorPoint = Vector2.new(0, 0.5),
            ImageColor3 = IconData.Custom and "WhiteColor" or "AccentColor",
            Position = UDim2.new(0, 14, 0.5, 0),
            Size = UDim2.fromOffset(16, 16),
            Parent = Header,
        })
        Library:ApplyIcon(Icon, IconData, 16)
        TextX = 38
    else
        local Pill = New("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = "AccentColor",
            Position = UDim2.new(0, 14, 0.5, 0),
            Size = UDim2.fromOffset(3, 14),
            Parent = Header,
        })
        Round(Pill)
        TextX = 26
    end

    New("TextLabel", {
        FontFace = Fonts.SemiBold,
        Position = UDim2.fromOffset(TextX, 0),
        Size = UDim2.new(1, -(TextX + 10), 1, 0),
        Text = tostring(Name),
        TextSize = 14,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Header,
    })

    New("Frame", {
        BackgroundColor3 = "OutlineColor",
        LayoutOrder = 2,
        Size = UDim2.new(1, 0, 0, 1),
        Parent = Holder,
    })

    local Container = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 3,
        Size = UDim2.new(1, 0, 0, 0),
        Parent = Holder,
    })
    Pad(Container, 12, 12, 12, 12)
    ListLayout(Container, 10)

    local Groupbox = NewContainerObject(Tab, nil, Container)
    Groupbox.Owner = Groupbox
    Groupbox.Holder = Holder
    Groupbox.Name = tostring(Name)
    Groupbox.Entries = {}
    table.insert(Tab.Owners, Groupbox)
    table.insert(Tab.Groupboxes, Groupbox)

    function Groupbox:Resize() end
    function Groupbox:SetVisible(State)
        Holder.Visible = State == true
    end

    return Groupbox
end

--// Tabbox (several tabs inside one box)
local function BuildTabbox(Tab, Column, Side)
    Tab.Counts[Side] = Tab.Counts[Side] + 1

    local Holder = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = "MainColor",
        LayoutOrder = Tab.Counts[Side],
        Size = UDim2.new(1, 0, 0, 0),
        Parent = Column,
    })
    Corner(Holder, 12)
    Stroke(Holder)
    ListLayout(Holder, 0)

    local Bar = New("Frame", {
        BackgroundTransparency = 1,
        LayoutOrder = 1,
        Size = UDim2.new(1, 0, 0, 40),
        Parent = Holder,
    })
    ListLayout(Bar, 0, Enum.FillDirection.Horizontal)

    New("Frame", {
        BackgroundColor3 = "OutlineColor",
        LayoutOrder = 2,
        Size = UDim2.new(1, 0, 0, 1),
        Parent = Holder,
    })

    local Pages = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 3,
        Size = UDim2.new(1, 0, 0, 0),
        Parent = Holder,
    })

    local Tabbox = {
        Holder = Holder,
        Entries = {},
        Tabs = {},
        Name = "",
        Active = nil,
    }
    table.insert(Tab.Owners, Tabbox)

    local function Select(Target)
        Library:ClosePopup()
        Tabbox.Active = Target
        for _, Item in ipairs(Tabbox.Tabs) do
            local On = Item == Target
            Item.Container.Visible = On
            Item.Indicator.Visible = On
            Tween(Item.Button, { TextColor3 = On and Scheme.FontColor or Derived.MutedColor() }, 0.14)
        end
    end

    function Tabbox:AddTab(Name)
        local Button = New("TextButton", {
            BackgroundTransparency = 1,
            FontFace = Fonts.SemiBold,
            Text = tostring(Name),
            TextColor3 = "MutedColor",
            TextSize = 13,
            Size = UDim2.new(1, 0, 1, 0),
            Parent = Bar,
        })
        local Indicator = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 1),
            BackgroundColor3 = "AccentColor",
            Position = UDim2.new(0.5, 0, 1, 0),
            Size = UDim2.new(0.5, 0, 0, 2),
            Visible = false,
            Parent = Button,
        })
        Round(Indicator)

        local Container = New("Frame", {
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            Visible = false,
            Parent = Pages,
        })
        Pad(Container, 12, 12, 12, 12)
        ListLayout(Container, 10)

        local Page = NewContainerObject(Tab, Tabbox, Container)
        Page.Name = tostring(Name)
        Page.Button = Button
        Page.Indicator = Indicator

        table.insert(Tabbox.Tabs, Page)
        local Count = #Tabbox.Tabs
        for _, Item in ipairs(Tabbox.Tabs) do
            Item.Button.Size = UDim2.new(1 / Count, 0, 1, 0)
        end

        Button.MouseButton1Click:Connect(function()
            Select(Page)
        end)
        if Count == 1 then
            Select(Page)
        end

        function Page:Show()
            Select(Page)
        end

        return Page
    end

    function Tabbox:SetVisible(State)
        Holder.Visible = State == true
    end

    return Tabbox
end

--// Window
function Library:CreateWindow(Info)
    Info = Info or {}

    local Window = {
        Tabs = {},
        ActiveTab = nil,
        SearchQuery = "",
        Type = "Window",
    }

    local Title = tostring(Info.Title or "Verdant")
    local Footer = tostring(Info.Footer or "")
    local SidebarWidth = math.clamp(tonumber(Info.SidebarWidth) or 216, 150, 300)
    local TopHeight = 56
    local FooterHeight = 30
    local MinSize = Vector2.new(580, 380)

    if tonumber(Info.FontScale) then
        Library.FontScale = math.clamp(tonumber(Info.FontScale), 0.8, 2)
    end
    if Info.NotifySide then
        Library:SetNotifySide(Info.NotifySide)
    end
    if Info.Font then
        Library:SetFont(Info.Font)
    end
    if Info.ToggleKeybind ~= nil then
        Library.ToggleKeybind = Info.ToggleKeybind
    end
    if Library.ToggleKeybind == nil then
        Library.ToggleKeybind = Enum.KeyCode.RightControl
    end
    Library.UnlockMouse = Info.UnlockMouseWhileOpen ~= false

    local Camera = workspace.CurrentCamera
    local ViewSize = Camera and Camera.ViewportSize or Vector2.new(1280, 720)

    local RequestedSize = Info.Size or UDim2.fromOffset(760, 520)
    local Width = RequestedSize.X.Scale * ViewSize.X + RequestedSize.X.Offset
    local Height = RequestedSize.Y.Scale * ViewSize.Y + RequestedSize.Y.Offset
    Width = math.clamp(Width, MinSize.X, math.max(MinSize.X, ViewSize.X - 16))
    Height = math.clamp(Height, MinSize.Y, math.max(MinSize.Y, ViewSize.Y - 16))

    local StartPosition = UDim2.fromOffset(
        math.floor((ViewSize.X - Width) / 2),
        math.floor((ViewSize.Y - Height) / 2)
    )
    if Info.Center == false and Info.Position then
        StartPosition = Info.Position
    end

    local MainFrame = New("Frame", {
        Name = "Main",
        Active = true,
        BackgroundColor3 = "BackgroundColor",
        Position = StartPosition,
        Size = UDim2.fromOffset(Width, Height),
        Visible = false,
        Parent = ScreenGui,
    })
    Corner(MainFrame, 14)
    Stroke(MainFrame)
    Library.PopupParent = MainFrame
    local PopScale = New("UIScale", { Scale = Library.DPIScale, Parent = MainFrame })
    Library.ApplyDPI = function()
        Tween(PopScale, { Scale = Library.DPIScale }, 0.15)
    end

    --// Top bar
    local TopBar = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, TopHeight),
        Parent = MainFrame,
    })

    local Brand = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, SidebarWidth, 1, 0),
        Parent = TopBar,
    })
    local Logo = New("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = "AccentColor",
        Position = UDim2.new(0, 14, 0.5, 0),
        Size = UDim2.fromOffset(30, 30),
        Parent = Brand,
    })
    Corner(Logo, 9)
    New("TextLabel", {
        FontFace = Fonts.Bold,
        Size = UDim2.fromScale(1, 1),
        Text = string.upper(string.sub(Title, 1, 1)),
        TextColor3 = "BackgroundColor",
        TextSize = 16,
        Parent = Logo,
    })

    --// A custom icon only replaces the letter badge once it has really loaded
    local LogoIcon = Library:ResolveIcon(Info.Icon)
    if LogoIcon and LogoIcon.Custom then
        local Img = New("ImageLabel", {
            Size = UDim2.fromScale(1, 1),
            Visible = false,
            ZIndex = 2,
            Parent = Logo,
        })
        Corner(Img, 9)
        Library:ApplyIcon(Img, LogoIcon, 30)
        task.spawn(function()
            local Waited = 0
            while Img.Parent and not Img.IsLoaded and Waited < 4 do
                task.wait(0.2)
                Waited = Waited + 0.2
            end
            if Img.Parent and Img.IsLoaded then
                Img.Visible = true
                Logo.BackgroundTransparency = 1
                for _, Child in ipairs(Logo:GetChildren()) do
                    if Child:IsA("TextLabel") then
                        Child.Visible = false
                    end
                end
            end
        end)
    end

    --// The full title always fits: the text shrinks instead of being cut off
    local TitleLabel = New("TextLabel", {
        FontFace = Fonts.Bold,
        Position = UDim2.fromOffset(54, 0),
        Size = UDim2.new(1, -62, 1, 0),
        Text = Title,
        TextScaled = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Brand,
    })
    New("UITextSizeConstraint", {
        MaxTextSize = math.floor(16 * Library.FontScale + 0.5),
        MinTextSize = 10,
        Parent = TitleLabel,
    })

    local SearchHolder = New("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = "ElementColor",
        Position = UDim2.new(0, SidebarWidth + 16, 0.5, 0),
        Size = UDim2.new(1, -(SidebarWidth + 16 + 16 + 40), 0, 34),
        Parent = TopBar,
    })
    Corner(SearchHolder, 10)
    local SearchStroke = Stroke(SearchHolder)
    local SearchGlyph = DrawSearch(SearchHolder)
    SearchGlyph.Position = UDim2.new(0, 20, 0.5, 0)
    local SearchBox = New("TextBox", {
        PlaceholderColor3 = "MutedColor",
        PlaceholderText = "Search...",
        Position = UDim2.fromOffset(38, 0),
        Size = UDim2.new(1, -48, 1, 0),
        Text = "",
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = SearchHolder,
    })
    SearchBox.Focused:Connect(function()
        Tween(SearchStroke, { Color = Scheme.AccentColor }, 0.14)
    end)
    SearchBox.FocusLost:Connect(function()
        Tween(SearchStroke, { Color = Scheme.OutlineColor }, 0.14)
    end)

    local CloseButton = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = "ElementColor",
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(30, 30),
        Parent = TopBar,
    })
    Corner(CloseButton, 9)
    local CloseGlyph = DrawCross(CloseButton)
    CloseGlyph.Position = UDim2.fromScale(0.5, 0.5)
    CloseButton.MouseEnter:Connect(function()
        Tween(CloseButton, { BackgroundTransparency = 0 }, 0.12)
    end)
    CloseButton.MouseLeave:Connect(function()
        Tween(CloseButton, { BackgroundTransparency = 1 }, 0.12)
    end)
    CloseButton.MouseButton1Click:Connect(function()
        Library:Toggle(false)
    end)

    --// Divider lines
    New("Frame", {
        BackgroundColor3 = "OutlineColor",
        Position = UDim2.fromOffset(0, TopHeight),
        Size = UDim2.new(1, 0, 0, 1),
        Parent = MainFrame,
    })
    New("Frame", {
        BackgroundColor3 = "OutlineColor",
        Position = UDim2.fromOffset(SidebarWidth, TopHeight + 1),
        Size = UDim2.new(0, 1, 1, -(TopHeight + 1 + FooterHeight + 1)),
        Parent = MainFrame,
    })
    New("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        BackgroundColor3 = "OutlineColor",
        Position = UDim2.new(0, 0, 1, -FooterHeight),
        Size = UDim2.new(1, 0, 0, 1),
        Parent = MainFrame,
    })

    --// Sidebar
    local Sidebar = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, TopHeight + 1),
        Size = UDim2.new(0, SidebarWidth, 1, -(TopHeight + 1 + FooterHeight + 1)),
        Parent = MainFrame,
    })
    local ChipHeight = 58
    local TabScroll = New("ScrollingFrame", {
        ScrollBarThickness = 0,
        Size = UDim2.new(1, 0, 1, -ChipHeight),
        Parent = Sidebar,
    })
    Pad(TabScroll, 12, 12, 12, 12)
    ListLayout(TabScroll, 4)

    --// User card: hidden by default (streamer friendly), click it to reveal
    local Chip = New("TextButton", {
        AnchorPoint = Vector2.new(0, 1),
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, ChipHeight),
        Parent = Sidebar,
    })
    New("Frame", {
        BackgroundColor3 = "OutlineColor",
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -24, 0, 1),
        Parent = Chip,
    })
    local Avatar = New("ImageLabel", {
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = "ElementColor",
        BackgroundTransparency = 0,
        Position = UDim2.new(0, 14, 0.5, 0),
        Size = UDim2.fromOffset(34, 34),
        Parent = Chip,
    })
    Round(Avatar)
    local AvatarHidden = New("TextLabel", {
        FontFace = Fonts.Bold,
        Size = UDim2.fromScale(1, 1),
        Text = "?",
        TextColor3 = "MutedColor",
        TextSize = 15,
        Parent = Avatar,
    })
    local ChipName = New("TextLabel", {
        FontFace = Fonts.SemiBold,
        Position = UDim2.new(0, 56, 0.5, -17),
        Size = UDim2.new(1, -66, 0, 18),
        Text = "User hidden",
        TextSize = 13,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Chip,
    })
    local ChipHandle = New("TextLabel", {
        Position = UDim2.new(0, 56, 0.5, 2),
        Size = UDim2.new(1, -66, 0, 16),
        Text = "Click to show",
        TextColor3 = "MutedColor",
        TextSize = 11,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Chip,
    })

    local UserShown = false
    local AvatarLoaded = false
    local function SetUserShown(State)
        UserShown = State == true
        AvatarHidden.Visible = not UserShown
        Avatar.ImageTransparency = UserShown and 0 or 1
        if UserShown then
            ChipName.Text = LocalPlayer.DisplayName
            ChipHandle.Text = "@" .. LocalPlayer.Name
            if not AvatarLoaded then
                AvatarLoaded = true
                task.spawn(function()
                    local Ok, Image = pcall(function()
                        return Players:GetUserThumbnailAsync(
                            LocalPlayer.UserId,
                            Enum.ThumbnailType.HeadShot,
                            Enum.ThumbnailSize.Size100x100
                        )
                    end)
                    if Ok and Image and Avatar.Parent then
                        Avatar.Image = Image
                    end
                end)
            end
        else
            ChipName.Text = "User hidden"
            ChipHandle.Text = "Click to show"
        end
    end
    Chip.MouseButton1Click:Connect(function()
        SetUserShown(not UserShown)
    end)
    SetUserShown(Info.ShowUser == true)

    --// Content area
    local Content = New("Frame", {
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Position = UDim2.fromOffset(SidebarWidth + 1, TopHeight + 1),
        Size = UDim2.new(1, -(SidebarWidth + 1), 1, -(TopHeight + 1 + FooterHeight + 1)),
        Parent = MainFrame,
    })

    --// Footer
    local FooterFrame = New("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, FooterHeight),
        Parent = MainFrame,
    })
    local FooterLabel = New("TextLabel", {
        Size = UDim2.new(1, -80, 1, 0),
        Position = UDim2.fromOffset(40, 0),
        Text = Footer,
        TextColor3 = "SubtleColor",
        TextSize = 12,
        Parent = FooterFrame,
    })
    local Grip = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(22, 22),
        Visible = Info.Resizable ~= false,
        BackgroundTransparency = 1,
        Parent = FooterFrame,
    })
    local GripGlyph = DrawGrip(Grip, "SubtleColor")
    GripGlyph.Position = UDim2.fromScale(0.5, 0.5)

    --// Dragging
    do
        local Dragging, Origin, StartPos = false, nil, nil
        TopBar.InputBegan:Connect(function(Input)
            if IsPress(Input) then
                Dragging = true
                Origin = Input.Position
                StartPos = MainFrame.Position
                Library:ClosePopup()
            end
        end)
        Library:GiveSignal(UserInputService.InputChanged:Connect(function(Input)
            if Dragging and (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch) then
                local DeltaX = Input.Position.X - Origin.X
                local DeltaY = Input.Position.Y - Origin.Y
                MainFrame.Position = UDim2.new(
                    StartPos.X.Scale, StartPos.X.Offset + DeltaX,
                    StartPos.Y.Scale, StartPos.Y.Offset + DeltaY
                )
            end
        end))
        Library:GiveSignal(UserInputService.InputEnded:Connect(function(Input)
            if IsPress(Input) then
                Dragging = false
            end
        end))
    end

    --// Resizing
    do
        local Resizing, Origin, StartSize = false, nil, nil
        Grip.InputBegan:Connect(function(Input)
            if IsPress(Input) then
                Resizing = true
                Origin = Input.Position
                StartSize = MainFrame.AbsoluteSize / PopScale.Scale
                Library:ClosePopup()
            end
        end)
        Library:GiveSignal(UserInputService.InputChanged:Connect(function(Input)
            if Resizing and (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch) then
                local Zoom = PopScale.Scale
                local Screen = Overlay.AbsoluteSize / Zoom
                local NewW = math.clamp(StartSize.X + (Input.Position.X - Origin.X) / Zoom, MinSize.X, math.max(MinSize.X, Screen.X))
                local NewH = math.clamp(StartSize.Y + (Input.Position.Y - Origin.Y) / Zoom, MinSize.Y, math.max(MinSize.Y, Screen.Y))
                MainFrame.Size = UDim2.fromOffset(NewW, NewH)
            end
        end))
        Library:GiveSignal(UserInputService.InputEnded:Connect(function(Input)
            if IsPress(Input) then
                Resizing = false
            end
        end))
    end

    --// Showing / hiding
    function Window:_SetShown(State)
        MainFrame.Visible = State
        if State then
            PopScale.Scale = 0.96 * Library.DPIScale
            Tween(PopScale, { Scale = Library.DPIScale }, 0.2, Enum.EasingStyle.Quad)
        end
    end

    function Library:Toggle(Value)
        if typeof(Value) == "boolean" then
            Library.Toggled = Value
        else
            Library.Toggled = not Library.Toggled
        end
        Window:_SetShown(Library.Toggled)
        pcall(function()
            ModalElement.Modal = Library.Toggled and Library.UnlockMouse
        end)
        if not Library.Toggled then
            Library:ClosePopup()
            TooltipLabel.Visible = false
        end
        if Library.Cursor then
            Library.Cursor:Update()
        end
    end

    function Window:Show()
        Library:Toggle(true)
    end
    function Window:Hide()
        Library:Toggle(false)
    end
    function Window:Toggle(Value)
        Library:Toggle(Value)
    end
    function Window:SetTitle(Text)
        TitleLabel.Text = tostring(Text)
    end
    function Window:SetFooter(Text)
        FooterLabel.Text = tostring(Text)
    end
    function Window:Destroy()
        Library:Unload()
    end

    --// Searching
    function Window:ApplySearch(Query)
        Query = string.lower(tostring(Query or ""))
        Window.SearchQuery = Query
        local Tab = Window.ActiveTab
        if not Tab then
            return
        end
        for _, Owner in ipairs(Tab.Owners) do
            local OwnerMatch = Query == "" or (Owner.Name ~= nil and Owner.Name ~= "" and string.find(string.lower(Owner.Name), Query, 1, true) ~= nil)
            local Any = OwnerMatch
            for _, Entry in ipairs(Owner.Entries) do
                Entry.Matched = OwnerMatch or string.find(string.lower(Entry.Text), Query, 1, true) ~= nil
                Entry:Refresh()
                if Entry.Matched then
                    Any = true
                end
            end
            Owner.Holder.Visible = Any
        end
    end

    SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        Window:ApplySearch(SearchBox.Text)
    end)

    --// Tabs
    function Window:SelectTab(Target)
        if typeof(Target) == "string" then
            for _, Item in ipairs(Window.Tabs) do
                if Item.Name == Target then
                    Target = Item
                    break
                end
            end
        end
        if typeof(Target) ~= "table" or Window.ActiveTab == Target then
            return
        end
        Library:ClosePopup()
        local Old = Window.ActiveTab
        if Old then
            Old:_SetActive(false)
        end
        Window.ActiveTab = Target
        Target:_SetActive(true)
        Window:ApplySearch(Window.SearchQuery)
    end

    function Window:AddTab(Arg1, Arg2)
        local Name, IconName
        if typeof(Arg1) == "table" then
            Name, IconName = Arg1.Name, Arg1.Icon
        else
            Name, IconName = Arg1, Arg2
        end
        Name = tostring(Name or "Tab")

        local Tab = {
            Name = Name,
            Window = Window,
            Owners = {},
            Groupboxes = {},
            Counts = { Left = 0, Right = 0 },
            Active = false,
            Type = "Tab",
        }

        local Button = New("TextButton", {
            BackgroundColor3 = "ElementColor",
            BackgroundTransparency = 1,
            LayoutOrder = #Window.Tabs + 1,
            Size = UDim2.new(1, 0, 0, 38),
            Parent = TabScroll,
        })
        Corner(Button, 10)

        local Bar = New("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = "AccentColor",
            Position = UDim2.new(0, 0, 0.5, 0),
            Size = UDim2.fromOffset(3, 0),
            Parent = Button,
        })
        Round(Bar)

        local TextX = 14
        local IconImage = nil
        local IconData = Library:ResolveIcon(IconName)
        if IconData then
            IconImage = New("ImageLabel", {
                AnchorPoint = Vector2.new(0, 0.5),
                ImageColor3 = IconData.Custom and "WhiteColor" or "MutedColor",
                Position = UDim2.new(0, 14, 0.5, 0),
                Size = UDim2.fromOffset(18, 18),
                Parent = Button,
            })
            Library:ApplyIcon(IconImage, IconData, 18)
            TextX = 42
            if not IconData.Custom then
                Library:AddToRegistry(IconImage, {
                    ImageColor3 = function()
                        return Tab.Active and Scheme.AccentColor or Derived.MutedColor()
                    end,
                })
            end
        end

        local Label = New("TextLabel", {
            FontFace = Fonts.SemiBold,
            Position = UDim2.fromOffset(TextX, 0),
            Size = UDim2.new(1, -(TextX + 8), 1, 0),
            Text = Name,
            TextColor3 = "MutedColor",
            TextSize = 13,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = Button,
        })
        Library:AddToRegistry(Label, {
            TextColor3 = function()
                return Tab.Active and Scheme.FontColor or Derived.MutedColor()
            end,
        })

        local Page = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Visible = false,
            Parent = Content,
        })

        local function MakeColumn(IsLeft)
            local Column = New("ScrollingFrame", {
                Position = IsLeft and UDim2.new(0, 0, 0, 0) or UDim2.new(0.5, 0, 0, 0),
                Size = UDim2.new(0.5, 0, 1, 0),
                Parent = Page,
            })
            if IsLeft then
                Pad(Column, 14, 7, 14, 14)
            else
                Pad(Column, 14, 14, 14, 7)
            end
            ListLayout(Column, 12)
            return Column
        end
        Tab.Left = MakeColumn(true)
        Tab.Right = MakeColumn(false)
        Tab.Page = Page
        Tab.Button = Button

        function Tab:_SetActive(State)
            Tab.Active = State
            Page.Visible = State
            if State then
                Page.Position = UDim2.fromOffset(0, 10)
                Tween(Page, { Position = UDim2.fromOffset(0, 0) }, 0.22, Enum.EasingStyle.Quint)
            end
            Tween(Button, { BackgroundTransparency = State and 0 or 1 }, 0.16)
            Tween(Bar, { Size = UDim2.fromOffset(3, State and 18 or 0) }, 0.18)
            Tween(Label, { TextColor3 = State and Scheme.FontColor or Derived.MutedColor() }, 0.16)
            if IconImage and not IconData.Custom then
                Tween(IconImage, { ImageColor3 = State and Scheme.AccentColor or Derived.MutedColor() }, 0.16)
            end
        end

        Button.MouseEnter:Connect(function()
            if not Tab.Active then
                Tween(Button, { BackgroundTransparency = 0.6 }, 0.12)
            end
        end)
        Button.MouseLeave:Connect(function()
            if not Tab.Active then
                Tween(Button, { BackgroundTransparency = 1 }, 0.12)
            end
        end)
        Button.MouseButton1Click:Connect(function()
            Window:SelectTab(Tab)
        end)

        function Tab:Show()
            Window:SelectTab(Tab)
        end
        function Tab:SetVisible(State)
            Button.Visible = State == true
        end
        function Tab:UpdateWarningBox() end

        function Tab:AddLeftGroupbox(GroupName, GroupIcon)
            return BuildGroupbox(Tab, Tab.Left, "Left", GroupName, GroupIcon)
        end
        function Tab:AddRightGroupbox(GroupName, GroupIcon)
            return BuildGroupbox(Tab, Tab.Right, "Right", GroupName, GroupIcon)
        end
        function Tab:AddGroupbox(GroupInfo)
            GroupInfo = GroupInfo or {}
            local IsRight = GroupInfo.Side == 2 or GroupInfo.Side == "Right"
            if IsRight then
                return Tab:AddRightGroupbox(GroupInfo.Name, GroupInfo.IconName or GroupInfo.Icon)
            end
            return Tab:AddLeftGroupbox(GroupInfo.Name, GroupInfo.IconName or GroupInfo.Icon)
        end
        function Tab:AddLeftTabbox()
            return BuildTabbox(Tab, Tab.Left, "Left")
        end
        function Tab:AddRightTabbox()
            return BuildTabbox(Tab, Tab.Right, "Right")
        end
        function Tab:AddTabbox(TabboxInfo)
            TabboxInfo = TabboxInfo or {}
            if TabboxInfo.Side == 2 or TabboxInfo.Side == "Right" then
                return Tab:AddRightTabbox()
            end
            return Tab:AddLeftTabbox()
        end

        table.insert(Window.Tabs, Tab)
        table.insert(Library.Tabs, Tab)
        if #Window.Tabs == 1 then
            Window:SelectTab(Tab)
        end

        --// cursor settings go into the "UI Settings" tab automatically
        if Info.CursorMenu ~= false and not Library.CursorMenuBuilt and string.lower(Name) == "ui settings" then
            Library.CursorMenuBuilt = true
            local CursorBox = Tab:AddRightGroupbox("Cursor", "mouse-pointer-2")
            CursorBox.Holder.LayoutOrder = 100000 -- always last, so it sits below "Configuration"
            Library.Cursor:BuildMenu(CursorBox)
        end
        return Tab
    end

    --// Menu keybind
    Library:GiveSignal(UserInputService.InputBegan:Connect(function(Input)
        if Library.Unloaded or Library.Picking then
            return
        end
        if UserInputService:GetFocusedTextBox() then
            return
        end
        local Bind = Library.ToggleKeybind
        local Hit = false
        if typeof(Bind) == "EnumItem" then
            Hit = Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == Bind
        elseif typeof(Bind) == "table" and Bind.Value ~= nil then
            Hit = KeyMatches(Input, Bind.Value)
        elseif typeof(Bind) == "string" then
            Hit = KeyMatches(Input, Bind)
        end
        if Hit then
            Library:Toggle()
        end
    end))

    --// Mobile open button
    if Library.IsMobile then
        local Open = New("TextButton", {
            BackgroundColor3 = "AccentColor",
            Position = UDim2.new(0, 14, 0.5, -22),
            Size = UDim2.fromOffset(44, 44),
            Parent = ScreenGui,
        })
        Round(Open)
        New("TextLabel", {
            FontFace = Fonts.Bold,
            Size = UDim2.fromScale(1, 1),
            Text = string.upper(string.sub(Title, 1, 1)),
            TextColor3 = "BackgroundColor",
            TextSize = 18,
            Parent = Open,
        })
        Open.MouseButton1Click:Connect(function()
            Library:Toggle()
        end)
    end

    Library.Window = Window
    if Info.CustomCursor == false and Library.Cursor then
        Library.Cursor.Enabled = false
    end
    Library.Toggled = Info.AutoShow ~= false
    Window:_SetShown(Library.Toggled)
    pcall(function()
        ModalElement.Modal = Library.Toggled and Library.UnlockMouse
    end)
    if Library.Cursor then
        Library.Cursor:Update()
    end

    return Window
end

--// ============================================================
--//  ELEMENTS
--// ============================================================

local function PointerPos(Input)
    if Input.UserInputType == Enum.UserInputType.Touch then
        return Vector2.new(Input.Position.X, Input.Position.Y)
    end
    --// the mouse position is converted into the same space as AbsolutePosition
    return UserInputService:GetMouseLocation() + Overlay.AbsolutePosition
end

local function MakeDrag(Area, OnMove)
    Area.InputBegan:Connect(function(Input)
        if not IsPress(Input) then
            return
        end
        OnMove(PointerPos(Input))
        local MoveConn, EndConn
        MoveConn = UserInputService.InputChanged:Connect(function(Changed)
            if Changed.UserInputType == Enum.UserInputType.MouseMovement or Changed.UserInputType == Enum.UserInputType.Touch then
                OnMove(PointerPos(Changed))
            end
        end)
        EndConn = UserInputService.InputEnded:Connect(function(Ended)
            if IsPress(Ended) then
                MoveConn:Disconnect()
                EndConn:Disconnect()
            end
        end)
    end)
end

local function Animate(Inst, Props, Instant, Time)
    if Instant then
        for Prop, Value in pairs(Props) do
            Inst[Prop] = Value
        end
    else
        Tween(Inst, Props, Time or 0.16)
    end
end

local function NextOrder(Self)
    Self.Order = Self.Order + 1
    return Self.Order
end

local function MakeHolder(Self, Height)
    return New("Frame", {
        BackgroundTransparency = 1,
        LayoutOrder = NextOrder(Self),
        Size = UDim2.new(1, 0, 0, Height),
        Parent = Self.Container,
    })
end

local function RegisterEntry(Self, Holder, Text)
    local Entry = {
        Holder = Holder,
        Text = tostring(Text or ""),
        UserVisible = true,
        Matched = true,
    }
    function Entry:Refresh()
        Holder.Visible = Entry.UserVisible and Entry.Matched
    end
    table.insert(Self.Owner.Entries, Entry)
    return Entry
end

local function MakeSignal(Element, Info)
    Element.Listeners = {}
    function Element:OnChanged(Func)
        table.insert(Element.Listeners, Func)
    end
    function Element:RunChanged(...)
        for _, Func in ipairs(Element.Listeners) do
            SafeCall(Func, ...)
        end
    end
    if Info and typeof(Info.Changed) == "function" then
        Element:OnChanged(Info.Changed)
    end
end

--// Right-aligned container used for switches and add-ons
local function MakeRight(Holder, Height)
    local Right = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 0, 0, Height or 22),
        Parent = Holder,
    })
    local Layout = ListLayout(Right, 6, Enum.FillDirection.Horizontal)
    Layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    Layout.VerticalAlignment = Enum.VerticalAlignment.Center
    return Right
end

local function BindLabelWidth(Label, Right)
    local function Update()
        local Width = Right.AbsoluteSize.X
        local Y = Label.Size.Y
        Label.Size = UDim2.new(1, Width > 0 and -(Width + 8) or 0, Y.Scale, Y.Offset)
    end
    Right:GetPropertyChangedSignal("AbsoluteSize"):Connect(Update)
    Update()
end

local function AttachAddons(Element, Right)
    Element.Right = Right
    Element.AddonOrder = 0
    setmetatable(Element, { __index = Addons })
end

--// Label
function Funcs:AddLabel(Arg1, Arg2)
    local Idx, Info
    if typeof(Arg1) == "table" then
        Info = Arg1
    elseif typeof(Arg2) == "table" then
        Idx, Info = Arg1, Arg2
    else
        Info = { Text = Arg1, DoesWrap = Arg2 }
    end

    local Wrap = Info.DoesWrap == true
    local Label = {
        Type = "Label",
        Text = tostring(Info.Text or ""),
        Visible = Info.Visible ~= false,
    }

    local Holder = MakeHolder(self, 20)
    local Entry = RegisterEntry(self, Holder, Label.Text)
    if Wrap then
        Holder.AutomaticSize = Enum.AutomaticSize.Y
    end

    local TextLabel = New("TextLabel", {
        AutomaticSize = Wrap and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
        FontFace = Fonts.SemiBold,
        Size = UDim2.new(1, 0, 0, 20),
        Text = Label.Text,
        TextSize = 13,
        TextTruncate = Wrap and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd,
        TextWrapped = Wrap,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Holder,
    })
    local Right = MakeRight(Holder, 20)
    BindLabelWidth(TextLabel, Right)

    function Label:SetText(Text)
        Label.Text = tostring(Text)
        TextLabel.Text = Label.Text
        Entry.Text = Label.Text
    end
    function Label:SetVisible(State)
        Label.Visible = State == true
        Entry.UserVisible = Label.Visible
        Entry:Refresh()
    end

    Label.TextLabel = TextLabel
    Label.Holder = Holder
    Entry.UserVisible = Label.Visible
    Entry:Refresh()

    AttachAddons(Label, Right)
    if Idx then
        Library.Labels[Idx] = Label
    end
    return Label
end

--// Divider
function Funcs:AddDivider(Text)
    local HasText = Text ~= nil and tostring(Text) ~= ""
    local Holder = MakeHolder(self, HasText and 18 or 9)
    RegisterEntry(self, Holder, HasText and tostring(Text) or "")

    New("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = "OutlineColor",
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(1, 0, 0, 1),
        Parent = Holder,
    })
    if HasText then
        local Label = New("TextLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = "MainColor",
            BackgroundTransparency = 0,
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(0, 18),
            Text = tostring(Text),
            TextColor3 = "MutedColor",
            TextSize = 12,
            Parent = Holder,
        })
        Pad(Label, 0, 8, 0, 8)
    end
end

function Funcs:AddBlank(Height)
    MakeHolder(self, tonumber(Height) or 6)
end

--// Button
function Funcs:AddButton(Arg1, Arg2)
    local Info
    if typeof(Arg1) == "table" then
        Info = Arg1
    else
        Info = { Text = Arg1, Func = Arg2 }
    end

    local Holder = MakeHolder(self, 34)
    ListLayout(Holder, 8, Enum.FillDirection.Horizontal)
    local Entry = RegisterEntry(self, Holder, Info.Text)
    local Items = {}

    local function Relayout()
        local Count = 0
        for _, Item in ipairs(Items) do
            if Item.Button.Visible then
                Count = Count + 1
            end
        end
        if Count == 0 then
            return
        end
        local Gap = 8 * (Count - 1) / Count
        for _, Item in ipairs(Items) do
            Item.Button.Size = UDim2.new(1 / Count, -Gap, 1, 0)
        end
    end

    local function Make(ButtonInfo)
        local Item = {
            Type = "Button",
            Text = tostring(ButtonInfo.Text or "Button"),
            Func = ButtonInfo.Func or ButtonInfo.Callback,
            DoubleClick = ButtonInfo.DoubleClick == true,
            Disabled = ButtonInfo.Disabled == true,
            Visible = ButtonInfo.Visible ~= false,
            Armed = false,
        }

        local Button = New("TextButton", {
            BackgroundColor3 = "ElementColor",
            FontFace = Fonts.SemiBold,
            LayoutOrder = #Items + 1,
            Size = UDim2.new(1, 0, 1, 0),
            Text = Item.Text,
            TextSize = 13,
            Parent = Holder,
        })
        Corner(Button, 9)
        local ButtonStroke = Stroke(Button)
        Item.Button = Button
        table.insert(Items, Item)
        Relayout()

        local function Rest()
            Tween(Button, {
                BackgroundColor3 = Derived.ElementColor(),
                TextColor3 = Item.Armed and Scheme.AccentColor or Scheme.FontColor,
            }, 0.14)
            Tween(ButtonStroke, { Color = Scheme.OutlineColor }, 0.14)
        end

        Button.MouseEnter:Connect(function()
            if not Item.Disabled then
                Tween(Button, { BackgroundColor3 = Derived.HoverColor() }, 0.14)
                Tween(ButtonStroke, { Color = Scheme.AccentColor }, 0.14)
            end
        end)
        Button.MouseLeave:Connect(Rest)
        Button.MouseButton1Down:Connect(function()
            if not Item.Disabled then
                Tween(Button, { BackgroundColor3 = Scheme.AccentColor, TextColor3 = Scheme.BackgroundColor }, 0.08)
            end
        end)
        Button.MouseButton1Up:Connect(function()
            Tween(Button, { TextColor3 = Item.Armed and Scheme.AccentColor or Scheme.FontColor }, 0.12)
            Tween(Button, { BackgroundColor3 = Derived.HoverColor() }, 0.12)
        end)

        Button.MouseButton1Click:Connect(function()
            if Item.Disabled then
                return
            end
            if Item.DoubleClick then
                if not Item.Armed then
                    Item.Armed = true
                    Button.Text = "Click again to confirm"
                    Tween(Button, { TextColor3 = Scheme.AccentColor }, 0.12)
                    task.delay(2.2, function()
                        if Item.Armed then
                            Item.Armed = false
                            Button.Text = Item.Text
                            Tween(Button, { TextColor3 = Scheme.FontColor }, 0.12)
                        end
                    end)
                    return
                end
                Item.Armed = false
                Button.Text = Item.Text
                Tween(Button, { TextColor3 = Scheme.FontColor }, 0.12)
            end
            SafeCall(Item.Func)
        end)

        function Item:SetText(Text)
            Item.Text = tostring(Text)
            Button.Text = Item.Text
            Entry.Text = Item.Text
        end
        function Item:SetDisabled(State)
            Item.Disabled = State == true
            Button.TextTransparency = Item.Disabled and 0.55 or 0
        end
        function Item:SetVisible(State)
            Item.Visible = State == true
            Button.Visible = Item.Visible
            Relayout()
        end
        function Item:AddButton(NextArg1, NextArg2)
            local NextInfo
            if typeof(NextArg1) == "table" then
                NextInfo = NextArg1
            else
                NextInfo = { Text = NextArg1, Func = NextArg2 }
            end
            return Make(NextInfo)
        end

        Item:SetDisabled(Item.Disabled)
        Button.Visible = Item.Visible
        Relayout()
        Library:AddTooltip(Button, ButtonInfo.Tooltip)
        return Item
    end

    return Make(Info)
end

--// Toggle / Checkbox
local function BuildToggle(Self, Idx, Info, Style)
    Info = Info or {}
    local Toggle = {
        Type = "Toggle",
        Text = tostring(Info.Text or Idx or "Toggle"),
        Value = Info.Default == true,
        Disabled = Info.Disabled == true,
        Visible = Info.Visible ~= false,
        Risky = Info.Risky == true,
        Callback = Info.Callback,
    }
    MakeSignal(Toggle, Info)

    local Holder = MakeHolder(Self, 26)
    local Entry = RegisterEntry(Self, Holder, Toggle.Text)

    local Hit = New("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Parent = Holder,
    })
    local Label = New("TextLabel", {
        FontFace = Fonts.SemiBold,
        Size = UDim2.new(1, -50, 1, 0),
        Text = Toggle.Text,
        TextSize = 13,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Holder,
    })
    local Right = MakeRight(Holder, 24)
    BindLabelWidth(Label, Right)

    local Track, TrackStroke, Ball, CheckLines
    if Style == "Switch" then
        Track = New("Frame", {
            BackgroundColor3 = Derived.ElementColor(),
            LayoutOrder = 100,
            Size = UDim2.fromOffset(38, 20),
            Parent = Right,
        })
        Round(Track)
        TrackStroke = New("UIStroke", { Color = Scheme.OutlineColor, Parent = Track })
        Ball = New("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = "WhiteColor",
            Position = UDim2.new(0, 3, 0.5, 0),
            Size = UDim2.fromOffset(14, 14),
            Parent = Track,
        })
        Round(Ball)
    else
        Track = New("Frame", {
            BackgroundColor3 = Derived.ElementColor(),
            LayoutOrder = 100,
            Size = UDim2.fromOffset(20, 20),
            Parent = Right,
        })
        Corner(Track, 6)
        TrackStroke = New("UIStroke", { Color = Scheme.OutlineColor, Parent = Track })
        local _, Lines = DrawCheck(Track, "BackgroundColor")
        CheckLines = Lines
    end

    Library:AddToRegistry(Track, {
        BackgroundColor3 = function()
            return Toggle.Value and Scheme.AccentColor or Derived.ElementColor()
        end,
    })
    Library:AddToRegistry(TrackStroke, {
        Color = function()
            return Toggle.Value and Scheme.AccentColor or Scheme.OutlineColor
        end,
    })
    Library:AddToRegistry(Label, {
        TextColor3 = function()
            if Toggle.Risky then
                return Scheme.RedColor
            end
            return Toggle.Value and Scheme.FontColor or Derived.MutedColor()
        end,
    })

    function Toggle:Display(Instant)
        local On = Toggle.Value
        Animate(Track, { BackgroundColor3 = On and Scheme.AccentColor or Derived.ElementColor() }, Instant)
        Animate(TrackStroke, { Color = On and Scheme.AccentColor or Scheme.OutlineColor }, Instant)
        if Ball then
            Animate(Ball, { Position = On and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }, Instant)
        end
        if CheckLines then
            for _, Bar in ipairs(CheckLines) do
                Animate(Bar, { BackgroundTransparency = On and 0 or 1 }, Instant, 0.12)
            end
        end
        local LabelColor = Toggle.Risky and Scheme.RedColor or (On and Scheme.FontColor or Derived.MutedColor())
        Animate(Label, { TextColor3 = LabelColor }, Instant)
        Label.TextTransparency = Toggle.Disabled and 0.55 or 0
    end

    function Toggle:SetValue(Value)
        Value = Value == true
        if Toggle.Value == Value then
            return
        end
        Toggle.Value = Value
        Toggle:Display()
        SafeCall(Toggle.Callback, Value)
        Toggle:RunChanged(Value)
    end
    function Toggle:SetText(Text)
        Toggle.Text = tostring(Text)
        Label.Text = Toggle.Text
        Entry.Text = Toggle.Text
    end
    function Toggle:SetVisible(State)
        Toggle.Visible = State == true
        Entry.UserVisible = Toggle.Visible
        Entry:Refresh()
    end
    function Toggle:SetDisabled(State)
        Toggle.Disabled = State == true
        Toggle:Display(true)
    end
    function Toggle:SetRisky(State)
        Toggle.Risky = State == true
        Toggle:Display(true)
    end

    Hit.MouseButton1Click:Connect(function()
        if Toggle.Disabled then
            return
        end
        Toggle:SetValue(not Toggle.Value)
    end)
    Library:AddTooltip(Hit, Info.Tooltip)

    Toggle.Holder = Holder
    Toggle.Label = Label
    Entry.UserVisible = Toggle.Visible
    Entry:Refresh()
    Toggle:Display(true)

    AttachAddons(Toggle, Right)
    if Idx then
        Library.Toggles[Idx] = Toggle
    end
    return Toggle
end

function Funcs:AddToggle(Idx, Info)
    return BuildToggle(self, Idx, Info, Library.ForceCheckbox and "Checkbox" or "Switch")
end

function Funcs:AddCheckbox(Idx, Info)
    return BuildToggle(self, Idx, Info, "Checkbox")
end

--// Slider
function Funcs:AddSlider(Idx, Info)
    Info = Info or {}
    local Slider = {
        Type = "Slider",
        Text = tostring(Info.Text or Idx or "Slider"),
        Min = tonumber(Info.Min) or 0,
        Max = tonumber(Info.Max) or 100,
        Rounding = tonumber(Info.Rounding) or 0,
        Prefix = tostring(Info.Prefix or ""),
        Suffix = tostring(Info.Suffix or ""),
        Compact = Info.Compact == true,
        HideMax = Info.HideMax == true,
        Callback = Info.Callback,
        Disabled = Info.Disabled == true,
        Visible = Info.Visible ~= false,
    }
    MakeSignal(Slider, Info)
    Slider.Value = math.clamp(tonumber(Info.Default) or Slider.Min, Slider.Min, Slider.Max)

    local Holder = MakeHolder(self, 46)
    local Entry = RegisterEntry(self, Holder, Slider.Text)

    local Label = New("TextLabel", {
        FontFace = Fonts.SemiBold,
        Size = UDim2.new(1, -96, 0, 20),
        Text = Slider.Compact and "" or Slider.Text,
        TextSize = 13,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Holder,
    })
    local ValueLabel = New("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = Slider.Compact and UDim2.new(1, 0, 0, 20) or UDim2.new(0, 96, 0, 20),
        TextColor3 = Slider.Compact and "FontColor" or "MutedColor",
        TextSize = 12,
        TextXAlignment = Slider.Compact and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right,
        Parent = Holder,
    })

    local Hit = New("TextButton", {
        AnchorPoint = Vector2.new(0, 1),
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 22),
        Parent = Holder,
    })
    local Track = New("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = "OutlineColor",
        Position = UDim2.new(0, 7, 0.5, 0),
        Size = UDim2.new(1, -14, 0, 6),
        Parent = Hit,
    })
    Round(Track)
    local Fill = New("Frame", {
        BackgroundColor3 = "AccentColor",
        Size = UDim2.fromScale(0, 1),
        Parent = Track,
    })
    Round(Fill)
    local Thumb = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = "WhiteColor",
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        Parent = Fill,
    })
    Round(Thumb)
    New("UIStroke", { Color = "BackgroundColor", Thickness = 2, Parent = Thumb })

    local function Format(Value)
        return Slider.Prefix .. string.format("%." .. tostring(math.max(0, Slider.Rounding)) .. "f", Value) .. Slider.Suffix
    end

    function Slider:Display()
        local Range = Slider.Max - Slider.Min
        local Rel = Range == 0 and 0 or (Slider.Value - Slider.Min) / Range
        Fill.Size = UDim2.new(math.clamp(Rel, 0, 1), 0, 1, 0)
        local Text = Format(Slider.Value)
        if not Slider.HideMax then
            Text = Text .. " / " .. Format(Slider.Max)
        end
        if Slider.Compact then
            Text = Slider.Text .. ": " .. Text
        end
        ValueLabel.Text = Text
        Label.TextTransparency = Slider.Disabled and 0.55 or 0
        Fill.BackgroundTransparency = Slider.Disabled and 0.6 or 0
    end

    function Slider:SetValue(Value)
        Value = tonumber(Value)
        if not Value then
            return
        end
        Value = math.clamp(Value, Slider.Min, Slider.Max)
        local Mult = 10 ^ math.max(0, Slider.Rounding)
        Value = math.floor(Value * Mult + 0.5) / Mult
        if Value == Slider.Value then
            Slider:Display()
            return
        end
        Slider.Value = Value
        Slider:Display()
        SafeCall(Slider.Callback, Value)
        Slider:RunChanged(Value)
    end
    function Slider:SetMin(Value)
        Slider.Min = tonumber(Value) or Slider.Min
        Slider:SetValue(Slider.Value)
        Slider:Display()
    end
    function Slider:SetMax(Value)
        Slider.Max = tonumber(Value) or Slider.Max
        Slider:SetValue(Slider.Value)
        Slider:Display()
    end
    function Slider:SetPrefix(Value)
        Slider.Prefix = tostring(Value)
        Slider:Display()
    end
    function Slider:SetSuffix(Value)
        Slider.Suffix = tostring(Value)
        Slider:Display()
    end
    function Slider:SetText(Text)
        Slider.Text = tostring(Text)
        Label.Text = Slider.Compact and "" or Slider.Text
        Entry.Text = Slider.Text
        Slider:Display()
    end
    function Slider:SetVisible(State)
        Slider.Visible = State == true
        Entry.UserVisible = Slider.Visible
        Entry:Refresh()
    end
    function Slider:SetDisabled(State)
        Slider.Disabled = State == true
        Slider:Display()
    end

    MakeDrag(Hit, function(Pos)
        if Slider.Disabled then
            return
        end
        local Width = Track.AbsoluteSize.X
        if Width <= 0 then
            return
        end
        local Rel = math.clamp((Pos.X - Track.AbsolutePosition.X) / Width, 0, 1)
        Slider:SetValue(Slider.Min + (Slider.Max - Slider.Min) * Rel)
    end)
    Library:AddTooltip(Hit, Info.Tooltip)

    Slider.Holder = Holder
    Entry.UserVisible = Slider.Visible
    Entry:Refresh()
    Slider:Display()

    if Idx then
        Library.Options[Idx] = Slider
    end
    return Slider
end

--// Input
function Funcs:AddInput(Idx, Info)
    Info = Info or {}
    local HasLabel = Info.Text ~= nil and tostring(Info.Text) ~= ""
    local Input = {
        Type = "Input",
        Text = Info.Text,
        Value = tostring(Info.Default or ""),
        Numeric = Info.Numeric == true,
        Finished = Info.Finished == true,
        Callback = Info.Callback,
        Disabled = Info.Disabled == true,
        Visible = Info.Visible ~= false,
    }
    MakeSignal(Input, Info)

    local Holder = MakeHolder(self, HasLabel and 62 or 34)
    local Entry = RegisterEntry(self, Holder, Info.Text or Idx)

    local Label = nil
    if HasLabel then
        Label = New("TextLabel", {
            FontFace = Fonts.SemiBold,
            Size = UDim2.new(1, 0, 0, 20),
            Text = tostring(Info.Text),
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = Holder,
        })
    end

    local Box = New("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        BackgroundColor3 = "ElementColor",
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 34),
        Parent = Holder,
    })
    Corner(Box, 9)
    local BoxStroke = Stroke(Box)

    local TextBox = New("TextBox", {
        ClearTextOnFocus = Info.ClearTextOnFocus == true,
        PlaceholderColor3 = "SubtleColor",
        PlaceholderText = tostring(Info.Placeholder or ""),
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -24, 1, 0),
        Text = Input.Value,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Box,
    })

    local Setting = false
    local function Clean(Text)
        if Input.Numeric then
            Text = string.gsub(Text, "[^%d%.%-]", "")
        end
        if Info.MaxLength and #Text > Info.MaxLength then
            Text = string.sub(Text, 1, Info.MaxLength)
        end
        return Text
    end

    TextBox:GetPropertyChangedSignal("Text"):Connect(function()
        if Setting then
            return
        end
        local Text = Clean(TextBox.Text)
        if Text ~= TextBox.Text then
            Setting = true
            TextBox.Text = Text
            Setting = false
        end
        Input.Value = Text
        if not Input.Finished then
            SafeCall(Input.Callback, Text)
            Input:RunChanged(Text)
        end
    end)
    TextBox.Focused:Connect(function()
        Tween(BoxStroke, { Color = Scheme.AccentColor }, 0.14)
    end)
    TextBox.FocusLost:Connect(function(Enter)
        Tween(BoxStroke, { Color = Scheme.OutlineColor }, 0.14)
        if Input.Finished and Enter then
            Input.Value = TextBox.Text
            SafeCall(Input.Callback, Input.Value)
            Input:RunChanged(Input.Value)
        end
    end)

    function Input:SetValue(Text)
        Text = Clean(tostring(Text == nil and "" or Text))
        Setting = true
        TextBox.Text = Text
        Setting = false
        Input.Value = Text
        SafeCall(Input.Callback, Text)
        Input:RunChanged(Text)
    end
    function Input:SetText(Text)
        Input.Text = Text
        if Label then
            Label.Text = tostring(Text)
        end
        Entry.Text = tostring(Text)
    end
    function Input:SetVisible(State)
        Input.Visible = State == true
        Entry.UserVisible = Input.Visible
        Entry:Refresh()
    end
    function Input:SetDisabled(State)
        Input.Disabled = State == true
        TextBox.TextEditable = not Input.Disabled
        TextBox.TextTransparency = Input.Disabled and 0.55 or 0
    end
    Input:SetDisabled(Input.Disabled)

    Library:AddTooltip(Box, Info.Tooltip)
    Input.Holder = Holder
    Input.TextBox = TextBox
    Entry.UserVisible = Input.Visible
    Entry:Refresh()

    if Idx then
        Library.Options[Idx] = Input
    end
    return Input
end

--// Dropdown
function Funcs:AddDropdown(Idx, Info)
    Info = Info or {}
    local HasLabel = Info.Text ~= nil and tostring(Info.Text) ~= ""
    local Dropdown = {
        Type = "Dropdown",
        Text = Info.Text,
        Values = Info.Values or {},
        Multi = Info.Multi == true,
        AllowNull = Info.AllowNull == true,
        SpecialType = Info.SpecialType,
        ExcludeLocalPlayer = Info.ExcludeLocalPlayer == true,
        Callback = Info.Callback,
        Disabled = Info.Disabled == true,
        Visible = Info.Visible ~= false,
        Value = nil,
    }
    MakeSignal(Dropdown, Info)
    if Dropdown.Multi then
        Dropdown.Value = {}
    end

    local function SpecialValues()
        local Out = {}
        if Dropdown.SpecialType == "Player" then
            for _, Player in ipairs(Players:GetPlayers()) do
                if not (Dropdown.ExcludeLocalPlayer and Player == LocalPlayer) then
                    table.insert(Out, Player.Name)
                end
            end
            table.sort(Out)
            return Out
        elseif Dropdown.SpecialType == "Team" then
            for _, Team in ipairs(Teams:GetTeams()) do
                table.insert(Out, Team.Name)
            end
            table.sort(Out)
            return Out
        end
        return nil
    end
    do
        local Special = SpecialValues()
        if Special then
            Dropdown.Values = Special
        end
    end

    local Holder = MakeHolder(self, HasLabel and 62 or 34)
    local Entry = RegisterEntry(self, Holder, Info.Text or Idx)

    local Label = nil
    if HasLabel then
        Label = New("TextLabel", {
            FontFace = Fonts.SemiBold,
            Size = UDim2.new(1, 0, 0, 20),
            Text = tostring(Info.Text),
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = Holder,
        })
    end

    local Button = New("TextButton", {
        AnchorPoint = Vector2.new(0, 1),
        BackgroundColor3 = "ElementColor",
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 34),
        Parent = Holder,
    })
    Corner(Button, 9)
    local ButtonStroke = Stroke(Button)
    local ValueLabel = New("TextLabel", {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -40, 1, 0),
        TextSize = 13,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Button,
    })
    local Chevron = DrawChevron(Button, "MutedColor")
    Chevron.Position = UDim2.new(1, -18, 0.5, 0)

    local function IsSelected(Value)
        if Dropdown.Multi then
            return Dropdown.Value[Value] == true
        end
        return Dropdown.Value == Value
    end

    local function ValueText()
        if Dropdown.Multi then
            local Names = {}
            for _, Value in ipairs(Dropdown.Values) do
                if Dropdown.Value[Value] then
                    table.insert(Names, tostring(Value))
                end
            end
            if #Names == 0 then
                return "---"
            end
            return table.concat(Names, ", ")
        end
        if Dropdown.Value == nil then
            return "---"
        end
        return tostring(Dropdown.Value)
    end

    Library:AddToRegistry(ValueLabel, {
        TextColor3 = function()
            return ValueText() == "---" and Derived.MutedColor() or Scheme.FontColor
        end,
    })

    local Popup, Scroll = nil, nil
    local Refreshers = {}

    local function Close()
        if not Popup then
            return
        end
        local Old = Popup
        Popup = nil
        Scroll = nil
        Refreshers = {}
        Tween(Chevron, { Rotation = 0 }, 0.16)
        Tween(ButtonStroke, { Color = Scheme.OutlineColor }, 0.14)
        if Library.ActivePopup and Library.ActivePopup.Frame == Old then
            Library.ActivePopup = nil
        end
        Old:Destroy()
    end

    function Dropdown:Display()
        local Text = ValueText()
        ValueLabel.Text = Text
        ValueLabel.TextColor3 = (Text == "---") and Derived.MutedColor() or Scheme.FontColor
        for _, Refresh in ipairs(Refreshers) do
            Refresh()
        end
    end

    local function Apply(Value, Silent)
        if Dropdown.Multi then
            local Map = {}
            if typeof(Value) == "table" then
                for Key, Item in pairs(Value) do
                    if Item == true then
                        if table.find(Dropdown.Values, Key) then
                            Map[Key] = true
                        end
                    elseif Item ~= false then
                        if table.find(Dropdown.Values, Item) then
                            Map[Item] = true
                        elseif typeof(Item) == "number" and Dropdown.Values[Item] ~= nil then
                            Map[Dropdown.Values[Item]] = true
                        end
                    end
                end
            end
            Dropdown.Value = Map
        else
            if Value == nil then
                Dropdown.Value = nil
            elseif table.find(Dropdown.Values, Value) then
                Dropdown.Value = Value
            elseif typeof(Value) == "number" and Dropdown.Values[Value] ~= nil then
                Dropdown.Value = Dropdown.Values[Value]
            else
                return
            end
        end
        Dropdown:Display()
        if not Silent then
            SafeCall(Dropdown.Callback, Dropdown.Value)
            Dropdown:RunChanged(Dropdown.Value)
        end
    end

    function Dropdown:SetValue(Value)
        Apply(Value, false)
    end

    local function Build()
        if not Popup or not Scroll then
            return
        end
        Refreshers = {}
        for _, Child in ipairs(Scroll:GetChildren()) do
            if Child:IsA("TextButton") then
                Child:Destroy()
            end
        end
        for Index, Value in ipairs(Dropdown.Values) do
            local Item = New("TextButton", {
                BackgroundColor3 = "HoverColor",
                BackgroundTransparency = 1,
                LayoutOrder = Index,
                Size = UDim2.new(1, 0, 0, 30),
                Parent = Scroll,
            })
            Corner(Item, 7)
            local Name = New("TextLabel", {
                Position = UDim2.fromOffset(10, 0),
                Size = UDim2.new(1, -34, 1, 0),
                Text = tostring(Value),
                TextSize = 13,
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = Item,
            })
            local Dot = New("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = "AccentColor",
                Position = UDim2.new(1, -12, 0.5, 0),
                Size = UDim2.fromOffset(6, 6),
                Parent = Item,
            })
            Round(Dot)

            local function Refresh()
                local Selected = IsSelected(Value)
                Dot.Visible = Selected
                Name.TextColor3 = Selected and Scheme.AccentColor or Scheme.FontColor
            end
            Refresh()
            table.insert(Refreshers, Refresh)

            Item.MouseEnter:Connect(function()
                Tween(Item, { BackgroundTransparency = 0 }, 0.1)
            end)
            Item.MouseLeave:Connect(function()
                Tween(Item, { BackgroundTransparency = 1 }, 0.1)
            end)
            Item.MouseButton1Click:Connect(function()
                if Dropdown.Multi then
                    local Copy = {}
                    for Key, On in pairs(Dropdown.Value) do
                        Copy[Key] = On
                    end
                    if Copy[Value] then
                        Copy[Value] = nil
                    else
                        Copy[Value] = true
                    end
                    Apply(Copy, false)
                else
                    if Dropdown.Value == Value then
                        if Dropdown.AllowNull then
                            Apply(nil, false)
                        end
                    else
                        Apply(Value, false)
                    end
                    Library:ClosePopup()
                end
            end)
        end
    end

    local function Open()
        if Dropdown.Disabled or Popup then
            return
        end
        local Count = #Dropdown.Values
        local Rows = math.max(1, math.min(Count, 7))
        local Height = Rows * 30 + (Rows - 1) * 2 + 12

        Popup = New("Frame", {
            BackgroundColor3 = "MainColor",
            ZIndex = 10,
            Parent = Library.PopupParent,
        })
        Corner(Popup, 10)
        Stroke(Popup)
        PlacePopup(Popup, Button, Button.AbsoluteSize.X, Height, false)

        Scroll = New("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1),
            Parent = Popup,
        })
        Pad(Scroll, 6, 6, 6, 6)
        ListLayout(Scroll, 2)
        Build()

        Library:RegisterPopup(Popup, Close, Button)
        Tween(Chevron, { Rotation = 180 }, 0.16)
        Tween(ButtonStroke, { Color = Scheme.AccentColor }, 0.14)
    end

    Button.MouseButton1Click:Connect(function()
        if Library:IsPopupOpenFor(Button) then
            Library:ClosePopup()
        else
            Open()
        end
    end)

    function Dropdown:SetValues(NewValues)
        Dropdown.Values = NewValues or {}
        if Dropdown.Multi then
            local Map = {}
            for Key in pairs(Dropdown.Value) do
                if table.find(Dropdown.Values, Key) then
                    Map[Key] = true
                end
            end
            Dropdown.Value = Map
        elseif Dropdown.Value ~= nil and not table.find(Dropdown.Values, Dropdown.Value) then
            Dropdown.Value = nil
        end
        Dropdown:Display()
        if Popup then
            Build()
        end
    end
    function Dropdown:AddValues(Extra)
        if typeof(Extra) == "table" then
            for _, Value in ipairs(Extra) do
                table.insert(Dropdown.Values, Value)
            end
        else
            table.insert(Dropdown.Values, Extra)
        end
        Dropdown:SetValues(Dropdown.Values)
    end
    function Dropdown:GetActiveValues()
        if Dropdown.Multi then
            local Out = {}
            for _, Value in ipairs(Dropdown.Values) do
                if Dropdown.Value[Value] then
                    table.insert(Out, Value)
                end
            end
            return Out
        end
        if Dropdown.Value == nil then
            return {}
        end
        return { Dropdown.Value }
    end
    function Dropdown:SetText(Text)
        Dropdown.Text = Text
        if Label then
            Label.Text = tostring(Text)
        end
        Entry.Text = tostring(Text)
    end
    function Dropdown:SetVisible(State)
        Dropdown.Visible = State == true
        Entry.UserVisible = Dropdown.Visible
        Entry:Refresh()
    end
    function Dropdown:SetDisabled(State)
        Dropdown.Disabled = State == true
        ValueLabel.TextTransparency = Dropdown.Disabled and 0.55 or 0
        if Dropdown.Disabled then
            Library:ClosePopup()
        end
    end

    if Dropdown.SpecialType == "Player" or Dropdown.SpecialType == "Team" then
        local function Refresh()
            local Fresh = SpecialValues()
            if Fresh then
                Dropdown:SetValues(Fresh)
            end
        end
        Library:GiveSignal(Players.PlayerAdded:Connect(Refresh))
        Library:GiveSignal(Players.PlayerRemoving:Connect(function()
            task.delay(0.15, Refresh)
        end))
    end

    if Info.Default ~= nil then
        Apply(Info.Default, true)
    end
    Dropdown:Display()
    Library:AddTooltip(Button, Info.Tooltip)
    Dropdown:SetDisabled(Dropdown.Disabled)

    Dropdown.Holder = Holder
    Entry.UserVisible = Dropdown.Visible
    Entry:Refresh()

    if Idx then
        Library.Options[Idx] = Dropdown
    end
    return Dropdown
end

--// Dependency box (shows only while its toggles/dropdowns match)
function Funcs:AddDependencyBox()
    local Container = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = NextOrder(self),
        Size = UDim2.new(1, 0, 0, 0),
        Parent = self.Container,
    })
    ListLayout(Container, 10)

    local Box = NewContainerObject(self.Tab, self.Owner, Container)
    Box.Type = "DependencyBox"
    Box.Dependencies = {}

    function Box:Update()
        local Show = true
        for _, Dependency in ipairs(Box.Dependencies) do
            local Element, Wanted = Dependency[1], Dependency[2]
            if Element == nil or Element.Value ~= Wanted then
                Show = false
                break
            end
        end
        Container.Visible = Show
    end

    function Box:SetupDependencies(Dependencies)
        Box.Dependencies = Dependencies or {}
        for _, Dependency in ipairs(Box.Dependencies) do
            local Element = Dependency[1]
            if Element and typeof(Element.OnChanged) == "function" then
                Element:OnChanged(function()
                    Box:Update()
                end)
            end
        end
        Box:Update()
    end

    return Box
end

--// ============================================================
--//  ADD-ONS  (colour picker + key picker, attached to labels / toggles)
--// ============================================================

function Addons:AddColorPicker(Idx, Info)
    Info = Info or {}
    local Parent = self

    local Picker = {
        Type = "ColorPicker",
        Title = tostring(Info.Title or "Color"),
        Value = Info.Default or Color3.new(1, 1, 1),
        Transparency = Info.Transparency,
        Callback = Info.Callback,
        Parent = Parent,
    }
    MakeSignal(Picker, Info)
    Picker.Hue, Picker.Sat, Picker.Vib = Picker.Value:ToHSV()

    Parent.AddonOrder = (Parent.AddonOrder or 0) + 1
    local Swatch = New("TextButton", {
        BackgroundColor3 = Picker.Value,
        LayoutOrder = Parent.AddonOrder,
        Size = UDim2.fromOffset(28, 16),
        Parent = Parent.Right,
    })
    Corner(Swatch, 5)
    Stroke(Swatch)

    local Popup, SV, SVCursor, HueCursor, AlphaFill, AlphaCursor, HexBox

    local function Update(Silent)
        Picker.Value = Color3.fromHSV(Picker.Hue, Picker.Sat, Picker.Vib)
        Swatch.BackgroundColor3 = Picker.Value
        if Popup then
            SV.BackgroundColor3 = Color3.fromHSV(Picker.Hue, 1, 1)
            SVCursor.Position = UDim2.fromScale(Picker.Sat, 1 - Picker.Vib)
            HueCursor.Position = UDim2.fromScale(Picker.Hue, 0.5)
            if AlphaFill then
                AlphaFill.BackgroundColor3 = Picker.Value
                AlphaCursor.Position = UDim2.fromScale(Picker.Transparency or 0, 0.5)
            end
            if HexBox and not HexBox:IsFocused() then
                HexBox.Text = "#" .. Picker.Value:ToHex()
            end
        end
        if not Silent then
            SafeCall(Picker.Callback, Picker.Value)
            Picker:RunChanged(Picker.Value)
        end
    end

    function Picker:SetValue(HSV, Transparency)
        if typeof(HSV) == "table" then
            Picker.Hue = math.clamp(HSV[1] or 0, 0, 1)
            Picker.Sat = math.clamp(HSV[2] or 0, 0, 1)
            Picker.Vib = math.clamp(HSV[3] or 0, 0, 1)
        end
        if Transparency ~= nil then
            Picker.Transparency = math.clamp(Transparency, 0, 1)
        end
        Update(false)
    end
    function Picker:SetValueRGB(Color, Transparency)
        if typeof(Color) ~= "Color3" then
            return
        end
        Picker.Hue, Picker.Sat, Picker.Vib = Color:ToHSV()
        if Transparency ~= nil then
            Picker.Transparency = math.clamp(Transparency, 0, 1)
        end
        Update(false)
    end
    function Picker:Display()
        Update(true)
    end

    local function Close()
        if not Popup then
            return
        end
        local Old = Popup
        Popup = nil
        if Library.ActivePopup and Library.ActivePopup.Frame == Old then
            Library.ActivePopup = nil
        end
        Old:Destroy()
    end

    local function Open()
        if Popup then
            return
        end
        local HasAlpha = Picker.Transparency ~= nil
        local Width = 224
        local Height = 24 + 16 + 124 + 12 + 30 + 10 * 3
        if HasAlpha then
            Height = Height + 12 + 10
        end

        Popup = New("Frame", {
            BackgroundColor3 = "MainColor",
            ZIndex = 10,
            Parent = Library.PopupParent,
        })
        Corner(Popup, 12)
        Stroke(Popup)
        PlacePopup(Popup, Swatch, Width, Height, true)
        Pad(Popup, 12, 12, 12, 12)
        ListLayout(Popup, 10)

        New("TextLabel", {
            FontFace = Fonts.SemiBold,
            LayoutOrder = 1,
            Size = UDim2.new(1, 0, 0, 16),
            Text = Picker.Title,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = Popup,
        })

        --// Saturation / value square
        SV = New("Frame", {
            BackgroundColor3 = Color3.fromHSV(Picker.Hue, 1, 1),
            LayoutOrder = 2,
            Size = UDim2.new(1, 0, 0, 124),
            Parent = Popup,
        })
        Corner(SV, 8)
        local White = New("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1),
            Size = UDim2.fromScale(1, 1),
            Parent = SV,
        })
        Corner(White, 8)
        New("UIGradient", {
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(1, 1),
            }),
            Parent = White,
        })
        local Black = New("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0),
            Size = UDim2.fromScale(1, 1),
            Parent = SV,
        })
        Corner(Black, 8)
        New("UIGradient", {
            Rotation = 90,
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(1, 0),
            }),
            Parent = Black,
        })
        SVCursor = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Position = UDim2.fromScale(Picker.Sat, 1 - Picker.Vib),
            Size = UDim2.fromOffset(12, 12),
            Parent = SV,
        })
        Round(SVCursor)
        New("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Parent = SVCursor })
        local SVHit = New("TextButton", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 3,
            Parent = SV,
        })
        MakeDrag(SVHit, function(Pos)
            local P, S = SV.AbsolutePosition, SV.AbsoluteSize
            Picker.Sat = math.clamp((Pos.X - P.X) / S.X, 0, 1)
            Picker.Vib = 1 - math.clamp((Pos.Y - P.Y) / S.Y, 0, 1)
            Update(false)
        end)

        --// Hue bar
        local HueBar = New("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1),
            LayoutOrder = 3,
            Size = UDim2.new(1, 0, 0, 12),
            Parent = Popup,
        })
        Round(HueBar)
        local Stops = {}
        for Step = 0, 6 do
            table.insert(Stops, ColorSequenceKeypoint.new(Step / 6, Color3.fromHSV(math.min(Step / 6, 0.999), 1, 1)))
        end
        New("UIGradient", { Color = ColorSequence.new(Stops), Parent = HueBar })
        HueCursor = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Color3.new(1, 1, 1),
            Position = UDim2.fromScale(Picker.Hue, 0.5),
            Size = UDim2.fromOffset(14, 14),
            Parent = HueBar,
        })
        Round(HueCursor)
        New("UIStroke", { Color = Color3.new(0.05, 0.05, 0.05), Thickness = 2, Parent = HueCursor })
        local HueHit = New("TextButton", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 3,
            Parent = HueBar,
        })
        MakeDrag(HueHit, function(Pos)
            local P, S = HueBar.AbsolutePosition, HueBar.AbsoluteSize
            Picker.Hue = math.clamp((Pos.X - P.X) / S.X, 0, 1)
            Update(false)
        end)

        --// Optional transparency bar
        AlphaFill, AlphaCursor = nil, nil
        if HasAlpha then
            local AlphaBar = New("Frame", {
                BackgroundColor3 = "ElementColor",
                LayoutOrder = 4,
                Size = UDim2.new(1, 0, 0, 12),
                Parent = Popup,
            })
            Round(AlphaBar)
            AlphaFill = New("Frame", {
                BackgroundColor3 = Picker.Value,
                Size = UDim2.fromScale(1, 1),
                Parent = AlphaBar,
            })
            Round(AlphaFill)
            New("UIGradient", {
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0),
                    NumberSequenceKeypoint.new(1, 0.92),
                }),
                Parent = AlphaFill,
            })
            AlphaCursor = New("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Color3.new(1, 1, 1),
                Position = UDim2.fromScale(Picker.Transparency or 0, 0.5),
                Size = UDim2.fromOffset(14, 14),
                Parent = AlphaBar,
            })
            Round(AlphaCursor)
            New("UIStroke", { Color = Color3.new(0.05, 0.05, 0.05), Thickness = 2, Parent = AlphaCursor })
            local AlphaHit = New("TextButton", {
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                ZIndex = 3,
                Parent = AlphaBar,
            })
            MakeDrag(AlphaHit, function(Pos)
                local P, S = AlphaBar.AbsolutePosition, AlphaBar.AbsoluteSize
                Picker.Transparency = math.clamp((Pos.X - P.X) / S.X, 0, 1)
                Update(false)
            end)
        end

        --// Hex input
        local HexHolder = New("Frame", {
            BackgroundColor3 = "ElementColor",
            LayoutOrder = 5,
            Size = UDim2.new(1, 0, 0, 30),
            Parent = Popup,
        })
        Corner(HexHolder, 8)
        local HexStroke = Stroke(HexHolder)
        HexBox = New("TextBox", {
            Size = UDim2.fromScale(1, 1),
            Text = "#" .. Picker.Value:ToHex(),
            TextSize = 13,
            Parent = HexHolder,
        })
        HexBox.Focused:Connect(function()
            Tween(HexStroke, { Color = Scheme.AccentColor }, 0.14)
        end)
        HexBox.FocusLost:Connect(function()
            Tween(HexStroke, { Color = Scheme.OutlineColor }, 0.14)
            local Text = string.gsub(HexBox.Text, "#", "")
            local Ok, Color = pcall(Color3.fromHex, Text)
            if Ok and typeof(Color) == "Color3" then
                Picker.Hue, Picker.Sat, Picker.Vib = Color:ToHSV()
                Update(false)
            end
            HexBox.Text = "#" .. Picker.Value:ToHex()
        end)

        Library:RegisterPopup(Popup, Close, Swatch)
    end

    Swatch.MouseButton1Click:Connect(function()
        if Library:IsPopupOpenFor(Swatch) then
            Library:ClosePopup()
        else
            Open()
        end
    end)
    Library:AddTooltip(Swatch, Info.Tooltip)

    if Idx then
        Library.Options[Idx] = Picker
    end
    return Parent
end

function Addons:AddKeyPicker(Idx, Info)
    Info = Info or {}
    local Parent = self

    local Picker = {
        Type = "KeyPicker",
        Value = "None",
        Mode = Info.Mode or "Toggle",
        Modes = Info.Modes or { "Always", "Toggle", "Hold" },
        SyncToggleState = Info.SyncToggleState == true,
        Text = tostring(Info.Text or Idx or "Keybind"),
        NoUI = Info.NoUI == true,
        Callback = Info.Callback,
        ChangedCallback = Info.ChangedCallback,
        State = false,
        Picking = false,
        ClickListeners = {},
        Parent = Parent,
    }
    MakeSignal(Picker, Info)
    if typeof(Info.Clicked) == "function" then
        table.insert(Picker.ClickListeners, Info.Clicked)
    end

    local function KeyName(Key)
        if typeof(Key) == "EnumItem" then
            return Key.Name
        end
        if Key == nil or Key == "" or Key == "Unknown" then
            return "None"
        end
        return tostring(Key)
    end
    Picker.Value = KeyName(Info.Default)

    Parent.AddonOrder = (Parent.AddonOrder or 0) + 1
    local Button = New("TextButton", {
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = "ElementColor",
        FontFace = Fonts.SemiBold,
        LayoutOrder = Parent.AddonOrder,
        Size = UDim2.fromOffset(0, 22),
        TextColor3 = "MutedColor",
        TextSize = 12,
        Parent = Parent.Right,
    })
    Corner(Button, 7)
    local ButtonStroke = Stroke(Button)
    Pad(Button, 0, 9, 0, 9)
    New("UISizeConstraint", { MinSize = Vector2.new(40, 22), Parent = Button })

    local function Display()
        if Picker.Picking then
            Button.Text = "..."
            Button.TextColor3 = Scheme.AccentColor
            ButtonStroke.Color = Scheme.AccentColor
        else
            Button.Text = Picker.Value
            Button.TextColor3 = Picker.Value == "None" and Derived.SubtleColor() or Derived.MutedColor()
            ButtonStroke.Color = Scheme.OutlineColor
        end
    end

    function Picker:GetState()
        if Picker.Mode == "Always" then
            return true
        end
        return Picker.State
    end

    local function Fired(State)
        SafeCall(Picker.Callback, State)
        for _, Func in ipairs(Picker.ClickListeners) do
            SafeCall(Func, State)
        end
        if Picker.SyncToggleState and Parent.Type == "Toggle" then
            Parent:SetValue(State)
        end
    end

    local function Activate(Pressed)
        if Picker.Mode == "Toggle" then
            if Pressed then
                Picker.State = not Picker.State
                Fired(Picker.State)
            end
        elseif Picker.Mode == "Hold" then
            Picker.State = Pressed
            Fired(Pressed)
        elseif Picker.Mode == "Press" then
            if Pressed then
                Fired(true)
            end
        end
    end

    function Picker:SetValue(Data)
        if typeof(Data) == "string" or typeof(Data) == "EnumItem" then
            Data = { Data }
        end
        if typeof(Data) ~= "table" then
            return
        end
        if Data[1] ~= nil then
            Picker.Value = KeyName(Data[1])
        end
        if Data[2] ~= nil and table.find(Picker.Modes, Data[2]) then
            Picker.Mode = Data[2]
        end
        Picker.State = false
        Display()
        SafeCall(Picker.ChangedCallback, Picker.Value, Picker.Mode)
        Picker:RunChanged(Picker.Value, Picker.Mode)
    end
    function Picker:SetMode(Mode)
        Picker:SetValue({ nil, Mode })
    end
    function Picker:OnClick(Func)
        table.insert(Picker.ClickListeners, Func)
    end
    function Picker:DoClick()
        Activate(true)
        if Picker.Mode == "Hold" then
            Activate(false)
        end
    end

    Button.MouseButton1Click:Connect(function()
        if Library:IsPopupOpenFor(Button) then
            Library:ClosePopup()
        end
        Picker.Picking = true
        Library.Picking = true
        Display()
    end)

    --// Right click: choose the activation mode
    local ModePopup = nil
    local function CloseModes()
        if not ModePopup then
            return
        end
        local Old = ModePopup
        ModePopup = nil
        if Library.ActivePopup and Library.ActivePopup.Frame == Old then
            Library.ActivePopup = nil
        end
        Old:Destroy()
    end
    Button.MouseButton2Click:Connect(function()
        if Library:IsPopupOpenFor(Button) then
            Library:ClosePopup()
            return
        end
        if Picker.Picking then
            return
        end
        local Count = #Picker.Modes
        ModePopup = New("Frame", {
            BackgroundColor3 = "MainColor",
            ZIndex = 10,
            Parent = Library.PopupParent,
        })
        Corner(ModePopup, 10)
        Stroke(ModePopup)
        PlacePopup(ModePopup, Button, 120, Count * 30 + (Count - 1) * 2 + 12, true)
        Pad(ModePopup, 6, 6, 6, 6)
        ListLayout(ModePopup, 2)
        for Index, Mode in ipairs(Picker.Modes) do
            local Item = New("TextButton", {
                BackgroundColor3 = "HoverColor",
                BackgroundTransparency = 1,
                LayoutOrder = Index,
                Size = UDim2.new(1, 0, 0, 30),
                Parent = ModePopup,
            })
            Corner(Item, 7)
            New("TextLabel", {
                Position = UDim2.fromOffset(10, 0),
                Size = UDim2.new(1, -20, 1, 0),
                Text = Mode,
                TextColor3 = Picker.Mode == Mode and "AccentColor" or "FontColor",
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = Item,
            })
            Item.MouseEnter:Connect(function()
                Tween(Item, { BackgroundTransparency = 0 }, 0.1)
            end)
            Item.MouseLeave:Connect(function()
                Tween(Item, { BackgroundTransparency = 1 }, 0.1)
            end)
            Item.MouseButton1Click:Connect(function()
                Picker:SetValue({ nil, Mode })
                Library:ClosePopup()
            end)
        end
        Library:RegisterPopup(ModePopup, CloseModes, Button)
    end)

    Library:GiveSignal(UserInputService.InputBegan:Connect(function(Input)
        if Library.Unloaded then
            return
        end
        if Picker.Picking then
            local Name = InputToKeyName(Input)
            if Name == nil then
                return
            end
            Picker.Picking = false
            Library.Picking = false
            if Name == "Escape" then
                Name = "None"
            end
            Picker:SetValue({ Name })
            return
        end
        if Library.Picking or UserInputService:GetFocusedTextBox() then
            return
        end
        if KeyMatches(Input, Picker.Value) then
            Activate(true)
        end
    end))
    Library:GiveSignal(UserInputService.InputEnded:Connect(function(Input)
        if Picker.Mode == "Hold" and KeyMatches(Input, Picker.Value) then
            Activate(false)
        end
    end))

    Display()
    Library:AddTooltip(Button, Info.Tooltip)

    if Idx then
        Library.Options[Idx] = Picker
    end
    return Parent
end

--// Features that Obsidian-style scripts (Example.lua) expect to exist
function Library:SetDPIScale(Value)
    Value = tonumber(Value) or 100
    if Value > 4 then
        Value = Value / 100
    end
    Library.DPIScale = math.clamp(Value, 0.5, 2)
    if Library.ApplyDPI then
        Library.ApplyDPI()
    end
end

Library.KeybindFrame = { Visible = false } -- placeholder: there is no keybind list in this UI

function Library:AddDraggableLabel(Text)
    local Frame = New("Frame", {
        Active = true,
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = "MainColor",
        Position = UDim2.fromOffset(20, 20),
        Size = UDim2.fromOffset(0, 30),
        Parent = ScreenGui,
    })
    Corner(Frame, 9)
    Stroke(Frame)
    Pad(Frame, 0, 12, 0, 12)
    local Label = New("TextLabel", {
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 30),
        Text = tostring(Text),
        TextSize = 13,
        Parent = Frame,
    })

    local Dragging, Origin, Start = false, nil, nil
    Frame.InputBegan:Connect(function(Input)
        if IsPress(Input) then
            Dragging = true
            Origin = Input.Position
            Start = Frame.Position
        end
    end)
    Library:GiveSignal(UserInputService.InputChanged:Connect(function(Input)
        if Dragging and (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch) then
            Frame.Position = UDim2.new(
                Start.X.Scale, Start.X.Offset + (Input.Position.X - Origin.X),
                Start.Y.Scale, Start.Y.Offset + (Input.Position.Y - Origin.Y)
            )
        end
    end))
    Library:GiveSignal(UserInputService.InputEnded:Connect(function(Input)
        if IsPress(Input) then
            Dragging = false
        end
    end))

    local Object = { Frame = Frame }
    function Object:SetText(NewText)
        Label.Text = tostring(NewText)
    end
    function Object:SetVisible(State)
        Frame.Visible = State == true
    end
    function Object:Destroy()
        Frame:Destroy()
    end
    return Object
end

function Library:UpdateDependencyBoxes() end
function Library:SetWatermark() end
function Library:SetWatermarkVisibility() end
function Library:SetCursorVisible() end


--// ============================================================
--//  CUSTOM CURSOR  (replaces the mouse pointer while the menu is open)
--// ============================================================

local Cursor = {
    Enabled = true,
    Style = "Windows", -- "Windows", "Dot + Ring", "Dot", "Ring", "Plus"
    ArrowSize = 2, -- size of the Windows arrow (1 = real Windows size)
    Size = 6,
    RingSize = 24,
    Thickness = 2,
    Outline = true,
    FollowAccent = false, -- white like Windows; turn on to tint it with the accent
    Color = Color3.fromRGB(255, 255, 255),
    Transparency = 0,
    ShowAlways = false, -- also replace the pointer when the menu is closed
    Offset = Vector2.new(0, 0), -- nudge if the cursor ever looks shifted
    _Taken = false,
    _Original = true,
}
Library.Cursor = Cursor

local CursorRoot = New("Frame", {
    Name = "Cursor",
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(-100, -100),
    Size = UDim2.fromOffset(0, 0),
    Visible = false,
    ZIndex = 1000,
    Parent = ScreenGui,
})
local CursorScale = New("UIScale", { Scale = 1, Parent = CursorRoot })

local function CursorPart(Name, Rounded)
    local Part = New("Frame", {
        Name = Name,
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.new(1, 1, 1),
        Position = UDim2.fromOffset(0, 0),
        Parent = CursorRoot,
    })
    if Rounded then
        Round(Part)
    end
    local Edge = New("UIStroke", {
        Color = Color3.new(0, 0, 0),
        Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = Part,
    })
    return Part, Edge
end

--// ring = a thick black ring drawn under a thinner coloured ring
local RingBack, RingBackStroke = CursorPart("RingBack", true)
RingBack.BackgroundTransparency = 1
local Ring, RingStroke = CursorPart("Ring", true)
Ring.BackgroundTransparency = 1
local PlusH, PlusHEdge = CursorPart("PlusH", false)
local PlusV, PlusVEdge = CursorPart("PlusV", false)
local CursorDot, CursorDotEdge = CursorPart("Dot", true)

--// The classic Windows arrow, drawn pixel by pixel (X = outline, O = fill).
--// The tip (top-left pixel) sits exactly on the pointer position.
local ArrowMap = {
    "X...........",
    "XX..........",
    "XOX.........",
    "XOOX........",
    "XOOOX.......",
    "XOOOOX......",
    "XOOOOOX.....",
    "XOOOOOOX....",
    "XOOOOOOOX...",
    "XOOOOOOOOX..",
    "XOOOOOOOOOX.",
    "XOOOOOXXXXXX",
    "XOOXOOX.....",
    "XOX.XOOX....",
    "XX..XOOX....",
    "X....XOOX...",
    ".....XOOX...",
    "......XOOX..",
    "......XXX...",
}
local ArrowHolder = New("Frame", {
    Name = "Arrow",
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.fromOffset(0, 0),
    Visible = false,
    Parent = CursorRoot,
})
local ArrowScale = New("UIScale", { Scale = 2, Parent = ArrowHolder })
local ArrowFill, ArrowEdge = {}, {}
for RowIndex, Row in ipairs(ArrowMap) do
    local Col = 1
    while Col <= #Row do
        local Char = string.sub(Row, Col, Col)
        local Start = Col
        while Col < #Row and string.sub(Row, Col + 1, Col + 1) == Char do
            Col = Col + 1
        end
        if Char ~= "." then
            local Run = New("Frame", {
                BackgroundColor3 = Char == "X" and Color3.new(0, 0, 0) or Color3.new(1, 1, 1),
                Position = UDim2.fromOffset(Start - 1, RowIndex - 1),
                Size = UDim2.fromOffset(Col - Start + 1, 1),
                Parent = ArrowHolder,
            })
            table.insert(Char == "X" and ArrowEdge or ArrowFill, Run)
        end
        Col = Col + 1
    end
end

function Cursor:GetColor()
    if Cursor.FollowAccent then
        return Scheme.AccentColor
    end
    return Cursor.Color
end

function Cursor:IsActive()
    if not Cursor.Enabled or Library.Unloaded then
        return false
    end
    return Cursor.ShowAlways or (Library.Window ~= nil and Library.Toggled)
end

function Cursor:Update()
    local Color = Cursor:GetColor()
    local Alpha = Cursor.Transparency
    local Style = Cursor.Style
    local Thick = Cursor.Thickness
    local Active = Cursor:IsActive()

    CursorRoot.Visible = Active

    --// take over / give back the real pointer
    if Active then
        if not Cursor._Taken then
            Cursor._Original = UserInputService.MouseIconEnabled
            Cursor._Taken = true
        end
        UserInputService.MouseIconEnabled = false
    elseif Cursor._Taken then
        Cursor._Taken = false
        UserInputService.MouseIconEnabled = Cursor._Original
    end

    --// Windows arrow
    ArrowHolder.Visible = Style == "Windows"
    ArrowScale.Scale = math.max(0.5, Cursor.ArrowSize)
    for _, Run in ipairs(ArrowFill) do
        Run.BackgroundColor3 = Color
        Run.BackgroundTransparency = Alpha
    end
    for _, Run in ipairs(ArrowEdge) do
        Run.Visible = Cursor.Outline
        Run.BackgroundTransparency = Alpha
    end

    local ShowDot = Style == "Dot + Ring" or Style == "Dot"
    local ShowRing = Style == "Dot + Ring" or Style == "Ring"
    local ShowPlus = Style == "Plus"

    CursorDot.Size = UDim2.fromOffset(Cursor.Size, Cursor.Size)
    CursorDot.Visible = ShowDot
    CursorDot.BackgroundColor3 = Color
    CursorDot.BackgroundTransparency = Alpha
    CursorDotEdge.Enabled = Cursor.Outline
    CursorDotEdge.Transparency = Alpha

    for _, RingFrame in ipairs({ Ring, RingBack }) do
        RingFrame.Size = UDim2.fromOffset(Cursor.RingSize, Cursor.RingSize)
        RingFrame.Visible = ShowRing
    end
    RingStroke.Color = Color
    RingStroke.Thickness = Thick
    RingStroke.Transparency = Alpha
    RingBackStroke.Thickness = Thick + 2
    RingBackStroke.Enabled = Cursor.Outline
    RingBackStroke.Transparency = Alpha

    local Arm = Cursor.RingSize
    PlusH.Size = UDim2.fromOffset(Arm, Thick)
    PlusV.Size = UDim2.fromOffset(Thick, Arm)
    for _, Bar in ipairs({ { PlusH, PlusHEdge }, { PlusV, PlusVEdge } }) do
        Bar[1].Visible = ShowPlus
        Bar[1].BackgroundColor3 = Color
        Bar[1].BackgroundTransparency = Alpha
        Bar[2].Enabled = Cursor.Outline
        Bar[2].Transparency = Alpha
    end
end

function Library:SetCursor(Settings)
    if typeof(Settings) == "table" then
        for Key, Value in pairs(Settings) do
            Cursor[Key] = Value
        end
    end
    Cursor:Update()
end

--// follows the real pointer every frame
Library:GiveSignal(RunService.RenderStepped:Connect(function()
    if Cursor:IsActive() then
        local Mouse = UserInputService:GetMouseLocation()
        CursorRoot.Position = UDim2.fromOffset(Mouse.X + Cursor.Offset.X, Mouse.Y + Cursor.Offset.Y)
        if UserInputService.MouseIconEnabled then
            UserInputService.MouseIconEnabled = false -- some games turn it back on
        end
    end
end))

--// little squeeze when clicking
Library:GiveSignal(UserInputService.InputBegan:Connect(function(Input)
    if Input.UserInputType == Enum.UserInputType.MouseButton1 and CursorRoot.Visible then
        Tween(CursorScale, { Scale = 0.78 }, 0.08)
    end
end))
Library:GiveSignal(UserInputService.InputEnded:Connect(function(Input)
    if Input.UserInputType == Enum.UserInputType.MouseButton1 then
        Tween(CursorScale, { Scale = 1 }, 0.14, Enum.EasingStyle.Back)
    end
end))

Library:OnUnload(function()
    Cursor.Enabled = false
    if Cursor._Taken then
        Cursor._Taken = false
        UserInputService.MouseIconEnabled = Cursor._Original
    end
end)

--// settings box (added to the "UI Settings" tab automatically)
function Cursor:BuildMenu(Groupbox)
    Groupbox:AddDropdown("Cursor_Style", {
        Text = "Style",
        Values = { "Windows", "Dot + Ring", "Dot", "Ring", "Plus" },
        Default = Cursor.Style,
        Callback = function(Value)
            if Value then
                Cursor.Style = Value
                Cursor:Update()
            end
        end,
    })
    Groupbox:AddSlider("Cursor_ArrowSize", {
        Text = "Arrow size", Default = Cursor.ArrowSize, Min = 1, Max = 5, Rounding = 0,
        Callback = function(Value)
            Cursor.ArrowSize = Value
            Cursor:Update()
        end,
    })
    Groupbox:AddSlider("Cursor_Size", {
        Text = "Dot size", Default = Cursor.Size, Min = 2, Max = 16, Rounding = 0,
        Callback = function(Value)
            Cursor.Size = Value
            Cursor:Update()
        end,
    })
    Groupbox:AddSlider("Cursor_RingSize", {
        Text = "Ring / plus size", Default = Cursor.RingSize, Min = 10, Max = 60, Rounding = 0,
        Callback = function(Value)
            Cursor.RingSize = Value
            Cursor:Update()
        end,
    })
    Groupbox:AddSlider("Cursor_Thickness", {
        Text = "Thickness", Default = Cursor.Thickness, Min = 1, Max = 6, Rounding = 0,
        Callback = function(Value)
            Cursor.Thickness = Value
            Cursor:Update()
        end,
    })
    Groupbox:AddSlider("Cursor_Opacity", {
        Text = "Opacity", Default = 100, Min = 20, Max = 100, Rounding = 0, Suffix = "%",
        Callback = function(Value)
            Cursor.Transparency = 1 - Value / 100
            Cursor:Update()
        end,
    })
    Groupbox:AddToggle("Cursor_Outline", {
        Text = "Outline",
        Default = Cursor.Outline,
        Callback = function(Value)
            Cursor.Outline = Value
            Cursor:Update()
        end,
    })
    Groupbox:AddToggle("Cursor_FollowAccent", {
        Text = "Use accent color",
        Default = Cursor.FollowAccent,
        Callback = function(Value)
            Cursor.FollowAccent = Value
            Cursor:Update()
        end,
    })
    Groupbox:AddLabel("Custom color"):AddColorPicker("Cursor_Color", {
        Default = Cursor.Color,
        Title = "Cursor color",
        Callback = function(Value)
            Cursor.Color = Value
            local Follow = Library.Toggles.Cursor_FollowAccent
            if Follow and Follow.Value then
                Follow:SetValue(false)
            else
                Cursor:Update()
            end
        end,
    })
    Groupbox:AddToggle("Cursor_ShowAlways", {
        Text = "Also show when menu is closed",
        Default = Cursor.ShowAlways,
        Callback = function(Value)
            Cursor.ShowAlways = Value
            Cursor:Update()
        end,
    })
end

Cursor:Update()

return Library
