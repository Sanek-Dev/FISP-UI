-- Globals
local _cloneref = cloneref or function(v) return v end
local RunService = _cloneref(game:GetService("RunService"))
local UserInputService = _cloneref(game:GetService("UserInputService"))
local IsStudio = RunService:IsStudio()
local _CoreGui = IsStudio and nil or (gethui and gethui() or _cloneref(game:GetService("CoreGui")))
local CustomAssets = {}

-- Constants
local DEF_WINDOW_ROUNDING = 15
local FOLDER_NAME = "Fisp"
local ASSETS_FOLDER_NAME = FOLDER_NAME.."/Assets"

-- Utils
function IsTable(val)
	return val and typeof(val) == "table"
end

function IsFunction(val)
	return val and typeof(val) == "function"
end

function IsStringNullOrEmpty(val)
	return not val or typeof(val) ~= "string" or string.len(val) < 1
end

function GetPlayerGui()
	local localPlr = game.Players.LocalPlayer
	if not localPlr then
		repeat
			task.wait()
			localPlr = game.Players.LocalPlayer
		until localPlr
	end
	
	return localPlr:WaitForChild("PlayerGui")
end

function IsFilesystemSupported()
	return IsFunction(delfile) and IsFunction(delfolder) and IsFunction(isfile) and IsFunction(isfolder) and IsFunction(makefolder) and IsFunction(readfile) and IsFunction(writefile)
end

function IsWebSupported()
	return IsFunction(request) or IsFunction(game.HttpGet)
end

function AreCustomAssetsSupported()
	return IsFilesystemSupported() and IsWebSupported() and IsFunction(getcustomasset)
end

function CheckForFolder(folderName)
	if not isfolder(folderName) then
		if isfile(folderName) then delfile(folderName) end
		
		makefolder(folderName)
	end
end

-- Credits to ChatGPT
function dumpTable(tbl, indent, visited)
	indent = indent or 0
	visited = visited or {}

	if visited[tbl] then
		return string.rep(" ", indent) .. "\n"
	end
	visited[tbl] = true

	local result = ""
	local prefix = string.rep(" ", indent)

	for key, value in pairs(tbl) do
		local keyStr = tostring(key)
		if keyStr == "__references" then continue end

		local valueStr = ""

		if typeof(value) == "Instance" then
			valueStr = string.format(
				"Instance (%s) \"%s\"",
				value.ClassName,
				value.Name
			)

		elseif type(value) == "table" then
			valueStr = "{\n"
			valueStr ..= dumpTable(value, indent + 4, visited)
			valueStr ..= prefix .. "}"

		else
			valueStr = tostring(value)
		end

		result ..= string.format(
			"%s[%s] = %s\n",
			prefix,
			keyStr,
			valueStr
		)
	end

	return result
end

function RecursiveCopyTable(source, destination, overrideExisting)
	for k,v in pairs(source) do
		if typeof(v) == "table" and destination[k] and typeof(destination[k]) == "table" then
			RecursiveCopyTable(v, destination[k], overrideExisting)
		elseif typeof(v) == "table" and not destination[k] then
			destination[k] = {}
			RecursiveCopyTable(v, destination[k], overrideExisting)
		elseif typeof(v) ~= "table" then
			if destination[k] and not overrideExisting then continue end
			
			if not IsStringNullOrEmpty(v) and v == "__nil" then
				destination[k] = nil
			else
				destination[k] = v
			end
		end
	end
end

-- Assets management
function LoadAsset(assetFilename, source)
	if not AreCustomAssetsSupported() then
		warn("Custom assets are not supported by your executor")
		return nil
	end
	
	if IsStringNullOrEmpty(assetFilename) or IsStringNullOrEmpty(source) then
		error("Invalid arguments!")
	end
	
	CheckForFolder(FOLDER_NAME)
	CheckForFolder(ASSETS_FOLDER_NAME)
	
	local assetPath = ASSETS_FOLDER_NAME.."/"..assetFilename
	local data = nil
	if not isfile(assetPath) then
		if isfolder(assetPath) then delfolder(assetPath) end
		
		data = nil
		if request then
			local success, response = pcall(request, {
				["Url"] = source,
				["Method"] = "GET"
			})
			
			if not success then
				warn("[FISP-request] Failed: "..response)
				return nil
			end
			
			if not response then
				warn("[FISP-request] No response")
				return nil
			end
			
			if not response.Success then
				if response.StatusCode and response.StatusMessage then
					warn("[FISP-request] Request failed with status code "..tostring(response.StatusCode)..": "..response.StatusMessage)
				elseif response.StatusCode then
					warn("[FISP-request] Request failed with status code "..tostring(response.StatusCode))
				else
					warn("[FISP-request] Request failed")
				end
				
				return nil
			end
			
			if not response.Body then
				warn("[FISP-request] No response body")
				return nil
			end
			
			data = response.Body
		else
			data = game:HttpGet(source)
		end
		
		if IsStringNullOrEmpty(data) then
			warn("[FISP-LoadAsset] Failed to get asset data")
			return nil
		end
		
		local success, status = pcall(writefile, assetPath, data)
		if not success then
			warn("Failed to write asset data: "..status)
			return nil
		end
		
		return getcustomasset(assetPath)
	end
	
	local success = false
	success, data = pcall(readfile, assetPath)
	if not success then
		warn("Failed to read asset data: "..data)
		return nil
	end
	
	if IsStringNullOrEmpty(data) then
		delfile(assetPath)
		
		warn("[FISP-LoadAsset] Empty data, trying to reload asset")
		return LoadAsset(assetFilename, source)
	end
	
	return getcustomasset(assetPath)
end

-- UI Utils
function AddCorner(frame, radius)
	if not frame then warn("AddFrame called with no frame!"); return nil end
	
	local corner = Instance.new("UICorner")
	corner.Parent = frame
	corner.CornerRadius = radius
	
	return corner
end

function LimitTextSize(frame, minSize, maxSize)
	frame.TextScaled = true
	
	local sizeConstraint = Instance.new("UITextSizeConstraint")
	sizeConstraint.Parent = frame
	sizeConstraint.MinTextSize = minSize
	sizeConstraint.MaxTextSize = maxSize
	
	return sizeConstraint
end

function PaintElementColor(frame, paramsTable)
	if IsTable(paramsTable.Gradient) and paramsTable.Gradient.ColorSequence then
		frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		
		if frame:IsA("TextLabel") or frame:IsA("TextBox") or frame:IsA("TextButton") then
			frame.TextColor3 = Color3.fromRGB(255, 255, 255)
		elseif frame:IsA("ImageLabel") or frame:IsA("ImageButton") then
			frame.ImageColor3 = Color3.fromRGB(255, 255, 255)
		end
		
		local gradient = Instance.new("UIGradient")
		gradient.Parent = frame
		gradient.Color = paramsTable.Gradient.ColorSequence
		gradient.Rotation = paramsTable.Gradient.Rotation or 0
		gradient.Enabled = true
		if paramsTable.Gradient.TransparencySequence then gradient.Transparency = paramsTable.Gradient.TransparencySequence end
		if paramsTable.Gradient.Offset then gradient.Offset = paramsTable.Gradient.Offset end
	elseif paramsTable.Color then
		frame.BackgroundColor3 = paramsTable.Color
	end
	
	if (frame:IsA("TextLabel") or frame:IsA("TextBox") or frame:IsA("TextButton")) and paramsTable.TextColor3 then
		frame.TextColor3 = paramsTable.TextColor3
	end
	
	if (frame:IsA("ImageLabel") or frame:IsA("ImageButton")) and paramsTable.ImageColor3 then
		frame.ImageColor3 = paramsTable.ImageColor3
	end
	
	if frame:IsA("ScrollingFrame") then
		if paramsTable.ScrollBarImageColor then
			frame.ScrollBarImageColor3 = paramsTable.ScrollBarImageColor
		end
		
		if paramsTable.ScrollBarImageTransparency then
			frame.ScrollBarImageTransparency = paramsTable.ScrollBarImageTransparency
		end
		
		if paramsTable.ScrollBarThickness then
			frame.ScrollBarThickness = paramsTable.ScrollBarThickness
		end
	end
	
	if paramsTable.BackgroundTransparency then
		frame.BackgroundTransparency = paramsTable.BackgroundTransparency
	end
end

function AddImageButton(frame, paramsTable)
	if not IsTable(paramsTable) then error("paramsTable required") end
	
	local button = Instance.new("ImageButton")
	button.Parent = frame
	button.Name = paramsTable.Name or "ImageButton"
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	if paramsTable.Position then button.Position = paramsTable.Position end
	if paramsTable.Size then button.Size = paramsTable.Size end
	
	return button
end

function SafeCallHandler(handler, ...)
	local success, ret = pcall(handler, ...)
	if not success then
		if ret then
			warn("UI Handler error: "..ret)
		else
			warn("UI Handler error")
		end
	end
end

-- IContentDisplay
local IContentDisplay = {}
IContentDisplay.__index = IContentDisplay

function IContentDisplay.new(wnd, contentFrame)
	if not wnd then error("No Window arg") end
	if not contentFrame then error("No contentFrame") end
	
	local contentDisplay = {}
	contentDisplay.ContentFrame = contentFrame
	contentDisplay.Window = wnd
	
	return setmetatable(contentDisplay, IContentDisplay)
end

-- TabsContentDisplay
local TabsContentDisplay = {}
TabsContentDisplay.__index = TabsContentDisplay

function TabsContentDisplay.new(wnd, contentFrame)
	local Self = {}
	Self.Base = IContentDisplay.new(wnd, contentFrame)
	
	local tabsFrame = Instance.new("ScrollingFrame")
	tabsFrame.Parent = contentFrame
	tabsFrame.Name = "TabsFrame"
	tabsFrame.Position = UDim2.fromScale(0, 0)
	tabsFrame.BorderSizePixel = 0
	tabsFrame.Size = UDim2.fromScale(0.25, 1)
	tabsFrame.CanvasPosition = Vector2.new(0, 0)
	tabsFrame.CanvasSize = UDim2.fromScale(0, 1)
	tabsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	tabsFrame.ScrollingEnabled = true
	tabsFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	tabsFrame.Visible = true
	
	local separator = Instance.new("Frame")
	separator.Parent = contentFrame
	separator.Name = "Separator"
	separator.Position = UDim2.fromScale(0.25, 0)
	separator.Size = UDim2.fromScale(0.005, 1)
	separator.BorderSizePixel = 0
	separator.Visible = true
	
	if IsTable(wnd.ThemeParams.TabsContentDisplay) then
		local params = wnd.ThemeParams.TabsContentDisplay
		if IsTable(params.TabsFrame) then
			PaintElementColor(tabsFrame, params.TabsFrame)
		end
		
		if IsTable(params.Separator) then
			PaintElementColor(separator, params.Separator)
		end
	end
	
	Self.TabsFrame = tabsFrame
	
	return setmetatable(Self, TabsContentDisplay)
end

-- Window
local Window = {}
Window.__index = Window

function CreateWindowTopBar(frame, paramsTable)
	if IsStringNullOrEmpty(paramsTable.TopBar.TitleType) then error("No paramsTable.TopBar.TitleType found") end
	
	local topBarR = Instance.new("Frame")
	topBarR.Parent = frame
	topBarR.Name = "TopBarRounding"
	topBarR.Position = UDim2.fromScale(0, 0)
	topBarR.BorderSizePixel = 0
	topBarR.Size = UDim2.fromScale(1, 0.1)
	AddCorner(topBarR, paramsTable.Rounding or UDim.new(0, DEF_WINDOW_ROUNDING))
	
	local topBarBottom = Instance.new("Frame")
	topBarBottom.Parent = frame
	topBarBottom.Name = "TopBarBottom"
	topBarBottom.Position = UDim2.fromScale(0, 0.05)
	topBarBottom.BorderSizePixel = 0
	topBarBottom.Size = UDim2.fromScale(1, 0.05)
	
	local topBar = Instance.new("Frame")
	topBar.Parent = frame
	topBar.Name = "TopBar"
	topBar.Position = UDim2.fromScale(0, 0)
	topBar.BorderSizePixel = 0
	topBar.Size = UDim2.fromScale(1, 0.1)
	topBar.BackgroundTransparency = 1
	
	PaintElementColor(topBarR, paramsTable.TopBar)
	PaintElementColor(topBarBottom, paramsTable.TopBar)
	
	local title = nil
	if paramsTable.TopBar.TitleType == "Text" then
		title = Instance.new("TextLabel")
		title.Parent = topBar
		title.Position = UDim2.fromScale(0.2, 0)
		title.BorderSizePixel = 0
		title.BackgroundTransparency = 1
		title.Size = UDim2.fromScale(0.5, 1)
		title.Name = "Title"
		title.TextWrapped = true
		title.TextStrokeTransparency = 1
		title.Text = paramsTable.TopBar.Title or "No Title"
		LimitTextSize(title, 1, 50)

		if paramsTable.TopBar.RichTitle then
			title.RichText = true
		end

		if paramsTable.TopBar.TitleFont then
			title.FontFace = paramsTable.TopBar.TitleFont
		end
	elseif paramsTable.TopBar.TitleType == "Image" and not IsStringNullOrEmpty(paramsTable.TopBar.TitleImage) then
		title = Instance.new("ImageLabel")
		title.Parent = topBar
		title.Position = UDim2.fromScale(0.2, 0)
		title.BorderSizePixel = 0
		title.BackgroundTransparency = 1
		title.Size = UDim2.fromScale(0.5, 1)
		title.Name = "Title"
		title.Visible = true
		title.ImageColor3 = Color3.fromRGB(255, 255, 255)
		title.Image = paramsTable.TopBar.TitleImage
	end
	
	if title and IsTable(paramsTable.TopBar.TitleColor) then
		PaintElementColor(title, paramsTable.TopBar.TitleColor)
	end
	
	if IsTable(paramsTable.TopBar.SubTitle) and not IsStringNullOrEmpty(paramsTable.TopBar.SubTitle.Type) then
		local subTitle = nil
		if paramsTable.TopBar.SubTitle.Type == "Text" and not IsStringNullOrEmpty(paramsTable.TopBar.SubTitle.Text) then
			subTitle = Instance.new("TextLabel")
			subTitle.Parent = topBar
			subTitle.Name = "SubTitle"
			subTitle.Position = UDim2.fromScale(0, 0)
			subTitle.Size = UDim2.fromScale(0.2, 1)
			subTitle.BackgroundTransparency = 1
			subTitle.BorderSizePixel = 0
			subTitle.TextStrokeTransparency = 1
			subTitle.TextWrapped = true
			subTitle.Visible = true
			subTitle.Text = paramsTable.TopBar.SubTitle.Text or "Empty"
			LimitTextSize(subTitle, 1, 20)

			if paramsTable.TopBar.SubTitle.RichText then
				subTitle.RichText = true
			end

			if paramsTable.TopBar.SubTitle.TextFont then
				subTitle.FontFace = paramsTable.TopBar.SubTitle.TextFont
			end
		elseif paramsTable.TopBar.SubTitle.Type == "Image" and not IsStringNullOrEmpty(paramsTable.TopBar.SubTitle.Image) then
			subTitle = Instance.new("ImageLabel")
			subTitle.Parent = topBar
			subTitle.Name = "SubTitle"
			subTitle.Position = UDim2.fromScale(0, 0)
			subTitle.Size = UDim2.fromScale(0.2, 1)
			subTitle.BackgroundTransparency = 1
			subTitle.BorderSizePixel = 0
			subTitle.Visible = true
			subTitle.ImageColor3 = Color3.fromRGB(255, 255, 255)
			subTitle.Image = paramsTable.TopBar.SubTitle.Image
		end
		
		if subTitle then
			PaintElementColor(subTitle, paramsTable.TopBar.SubTitle)
		end
	end
	
	local elementsFrame = Instance.new("Frame")
	elementsFrame.Parent = topBar
	elementsFrame.Name = "Elements"
	elementsFrame.BorderSizePixel = 0
	elementsFrame.Position = UDim2.fromScale(0.7, 0.1)
	elementsFrame.Size = UDim2.fromScale(0.28, 0.8)
	elementsFrame.BackgroundTransparency = 1
	
	local elementsLayout = Instance.new("UIListLayout")
	elementsLayout.Parent = elementsFrame
	elementsLayout.FillDirection = Enum.FillDirection.Horizontal
	elementsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	elementsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	elementsLayout.HorizontalFlex = Enum.UIFlexAlignment.None
	elementsLayout.Padding = UDim.new(0.05, 0)
	
	return topBar, elementsFrame
end

function Window.AddTopBarButton(Self, paramsTable)
	if not IsTable(paramsTable) then error("paramsTable cannot be nil") end
	if not Self.TopBar.ElementsFrame then error("TopBar ElementsFrame not found") end
	if IsStringNullOrEmpty(paramsTable.Type) then error("Invalid top bar button Type param") end
	
	local btn = nil
	if paramsTable.Type == "ImageButton" then
		btn = AddImageButton(Self.TopBar.ElementsFrame, {
			["Name"] = paramsTable.Name or "TopBarImageButton",
			["Size"] = UDim2.fromScale(0.2, 1)
		})
		btn.BackgroundTransparency = 1
		btn.ImageColor3 = paramsTable.ImageColor or Color3.fromRGB(255, 255, 255)
		
		if not IsStringNullOrEmpty(paramsTable.Image) then btn.Image = paramsTable.Image end
		if not IsStringNullOrEmpty(paramsTable.HoverImage) then btn.HoverImage = paramsTable.HoverImage end
		if not IsStringNullOrEmpty(paramsTable.PressedImage) then btn.PressedImage = paramsTable.PressedImage end
		if paramsTable.ImageTransparency then
			btn.ImageTransparency = paramsTable.ImageTransparency
		else
			btn.ImageTransparency = 0
		end
		if paramsTable.ScaleType then btn.ScaleType = paramsTable.ScaleType end
	else
		error("Text TopBar buttons are not supported yet")
	end
	
	if IsFunction(paramsTable.OnClick) then
		local clickConn = btn.MouseButton1Click:Connect(function()
			SafeCallHandler(paramsTable.OnClick, btn, Self)
		end)
		table.insert(Self.Connections, clickConn)
	end
	
	if IsFunction(paramsTable.OnHover) then
		local enterConn = btn.MouseEnter:Connect(function()
			SafeCallHandler(paramsTable.OnHover, btn, Self)
		end)
		table.insert(Self.Connections, enterConn)
	end
	
	if IsFunction(paramsTable.OnUnhover) then
		local leaveConn = btn.MouseLeave:Connect(function()
			SafeCallHandler(paramsTable.OnUnhover, btn, Self)
		end)
		table.insert(Self.Connections, leaveConn)
	end
	
	return btn
end

function Window.SetFooter(Self, paramsTable)
	if not IsTable(paramsTable) then error("paramsTable cannot be nil") end
	
	if Self.Footer then
	else
		local footerR = Instance.new("Frame")
		footerR.Parent = Self.Frame
		footerR.Name = "FooterRounding"
		footerR.BorderSizePixel = 0
		footerR.Size = UDim2.fromScale(1, 0.1)
		footerR.Position = UDim2.fromScale(0, 0.9)
		local wndCorner = Self.Frame:FindFirstChildOfClass("UICorner")
		wndCorner:Clone().Parent = footerR
		
		local footerB = Instance.new("Frame")
		footerB.Parent = Self.Frame
		footerB.BorderSizePixel = 0
		footerB.Name = "FooterBottom"
		footerB.Size = UDim2.fromScale(1, 0.05)
		footerB.Position = UDim2.fromScale(0, 0.9)
		
		PaintElementColor(footerR, Self.ThemeParams.TopBar)
		PaintElementColor(footerB, Self.ThemeParams.TopBar)
		
		local footer = Instance.new("Frame")
		footer.Parent = Self.Frame
		footer.BorderSizePixel = 0
		footer.Name = "Footer"
		footer.Position = UDim2.fromScale(0, 0.9)
		footer.Size = UDim2.fromScale(1, 0.1)
		footer.Visible = true
		footer.BackgroundTransparency = 1
		
		if Self.ContentFrame then
			Self.ContentFrame.Size = UDim2.fromScale(1, 0.8)
		end
		
		Self.Footer = footer
	end
	
	table.clear(paramsTable)
	paramsTable = nil
end

function Window.GetFooterFrame(Self)
	return Self.Footer
end

function Window.GetContentFrame(Self)
	local frame = nil
	if not Self.ContentFrame then
		frame = Instance.new("Frame")
		frame.Parent = Self.Frame
		frame.Name = "Content"
		frame.BorderSizePixel = 0
		frame.Position = UDim2.fromScale(0, 0.1)
		frame.Size = UDim2.fromScale(1, 0.9)
		frame.Visible = true
		frame.BackgroundTransparency = 1
		
		Self.ContentFrame = frame
	else
		frame = Self.ContentFrame
	end
	
	if Self.Footer then
		frame.Size = UDim2.fromScale(1, 0.8)
	end
	
	return frame
end

function Window.SetBodyContentDisplayAsTabs(Self)
	if Self.BodyContentDisplay then error("body content frame already has content display attached") end
	
	local contentDisplay = TabsContentDisplay.new(Self, Self:GetContentFrame())
	Self.BodyContentDisplay = contentDisplay
	
	return contentDisplay
end

function Window.new(paramsTable)
	if not IsTable(paramsTable) then error("paramsTable cannot be nil") end
	if not IsTable(paramsTable.TopBar) then error("paramsTable.TopBar cannot be nil") end
	
	local frame = Instance.new("Frame")
	frame.Parent = paramsTable.Parent
	frame.Name = paramsTable.Name or "Window"
	
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = paramsTable.StartPosition or UDim2.fromScale(0.5, 0.5)
	if paramsTable.StartPositionOffset then 
		frame.Position = UDim2.new(frame.Position.X.Scale + paramsTable.StartPositionOffset.X.Scale, frame.Position.X.Offset + paramsTable.StartPositionOffset.X.Offset, frame.Position.Y.Scale + paramsTable.StartPositionOffset.Y.Scale, frame.Position.Y.Offset + paramsTable.StartPositionOffset.Y.Offset)
	end
	frame.Size = paramsTable.Size or UDim2.fromScale(0.5, 0.7)
	frame.BorderSizePixel = 0
	
	if paramsTable.ZIndex then
		frame.ZIndex = paramsTable.ZIndex
	end
	
	if not paramsTable.DontUseAspectRatioConstraint then
		local aspectRatioConstraint = Instance.new("UIAspectRatioConstraint")
		aspectRatioConstraint.Parent = frame
		aspectRatioConstraint.AspectRatio = paramsTable.AspectRatio or 1.7
		aspectRatioConstraint.AspectType = Enum.AspectType.FitWithinMaxSize
		aspectRatioConstraint.DominantAxis = Enum.DominantAxis.Width
	end
	
	PaintElementColor(frame, paramsTable)
	AddCorner(frame, paramsTable.Rounding or UDim.new(0, DEF_WINDOW_ROUNDING))
	
	local topBar, topBarElements = CreateWindowTopBar(frame, paramsTable)
	
	local wnd = {}
	wnd.Frame = frame
	wnd.TopBar = {
		["Frame"] = topBar,
		["ElementsFrame"] = topBarElements
	}
	wnd.Connections = {}
	wnd.ThemeParams = paramsTable
	wnd.BodyContentDisplay = nil
	wnd = setmetatable(wnd, Window)
	
	local topCloseBtn = wnd:AddTopBarButton({
		["Type"] = "ImageButton",
		["Name"] = "CloseButton",
		["Image"] = CustomAssets.TopBarCloseButton,
		["OnClick"] = function(btn, wnd)
			wnd.Frame.Visible = false
		end
	})
	topCloseBtn.HoverImage = CustomAssets.TopBarCloseButtonHover
	
	-- Drag system
	local Dragging = false
	local DragInput = nil
	local DragStart = nil
	local StartPos = nil

	local UpdateFunc = function(input)
		local delta = input.Position - DragStart
		frame.Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + delta.X, StartPos.Y.Scale, StartPos.Y.Offset + delta.Y)
	end

	local dragInputBeganConn = frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			Dragging = true
			DragStart = input.Position
			StartPos = frame.Position
			
			local changedConn = nil
			changedConn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					changedConn:Disconnect()
					changedConn = nil
					Dragging = false
				end
			end)
		end
	end)
	table.insert(wnd.Connections, dragInputBeganConn)
	
	local dragInputChangedConn = frame.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			DragInput = input
		end
	end)
	table.insert(wnd.Connections, dragInputChangedConn)
	
	local uisInputChangedConn = UserInputService.InputChanged:Connect(function(input)
		if input == DragInput and Dragging then
			UpdateFunc(input)
		end
	end)
	table.insert(wnd.Connections, uisInputChangedConn)
	-- Drag system end
	
	return wnd
end

function Window.Destroy(Self)
	for i,v in ipairs(Self.Connections) do
		if v.Connected then
			v:Disconnect()
		end
		
		Self.Connections[i] = nil
	end
	
	if Self.Frame then
		Self.Frame:Destroy()
	end
end

-- Library
local Library = {}
Library.__index = Library
Library.ThemesData = {
	["LightDark"] = {
		["WindowParams"] = {
			["Gradient"] = {
				["ColorSequence"] = ColorSequence.new(Color3.fromRGB(30, 30, 30), Color3.fromRGB(12, 12, 12)),
				["Rotation"] = 50
			},
			-- ["BackgroundTransparency"] = 0.2,
			["TopBar"] = {
				["TitleType"] = "Text",
				["Color"] = Color3.fromRGB(227, 227, 227),
				["TitleColor"] = {
					["Gradient"] = {
						["ColorSequence"] = ColorSequence.new(Color3.fromRGB(15, 25, 83), Color3.fromRGB(99, 99, 99)),
						["Rotation"] = 0
					}
				},
				["TitleFont"] = Font.fromName("RobotoMono", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
				["SubTitle"] = {
					["Type"] = "Text",
					["Color"] = Color3.fromRGB(0, 0, 0),
					["TextFont"] = Font.fromName("RobotoMono", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
				}
			},
			["TabsContentDisplay"] = {
				["TabsFrame"] = {
					["Color"] = Color3.fromRGB(39, 39, 39),
					["ScrollBarThickness"] = 4,
					["ScrollBarImageColor"] = Color3.fromRGB(94, 94, 94)
				},
				["Separator"] = {
					["Color"] = Color3.fromRGB(227, 227, 227)
				}
			}
		},
		["Assets"] = {
			["TopBarCloseButton"] = {
				["Studio"] = "rbxassetid://122180942562671",
				["Exec"] = {
					["FileName"] = "TopBarCloseButton.png",
					["Source"] = "https://raw.githubusercontent.com/Sanek-Dev/FISP-UI/refs/heads/main/Assets/UICloseButton.png"
				}
			},
			["TopBarCloseButtonHover"] = {
				["Studio"] = "rbxassetid://89158478106717",
				["Exec"] = {
					["FileName"] = "TopBarCloseButtonHover.png",
					["Source"] = "https://raw.githubusercontent.com/Sanek-Dev/FISP-UI/main/Assets/UICloseButtonHover.png"
				}
			}
		}
	},
	["LightDarkTransparent"] = {
		["BasedOn"] = "LightDark",
		["WindowParams"] = {
			["BackgroundTransparency"] = 0.15,
			["TabsContentDisplay"] = {
				["TabsFrame"] = {
					["BackgroundTransparency"] = 1
				}
			}
		}
	}
}

function Library.ReloadAssets(Self)
	if not AreCustomAssetsSupported() and not IsStudio then
		warn("ReloadAssets: Your executor doesn\'t support custom assets")
		return
	end
	if not Self._ThemesData[Self.Theme] then error("Invalid theme (no data)") end
	
	if IsTable(Self._ThemesData[Self.Theme].Assets) then
		for assetName, assetData in pairs(Self._ThemesData[Self.Theme].Assets) do
			if IsStudio and not IsStringNullOrEmpty(assetData.Studio) then
				CustomAssets[assetName] = assetData.Studio
			elseif not IsStudio and IsTable(assetData.Exec) and not IsStringNullOrEmpty(assetData.Exec.FileName) and not IsStringNullOrEmpty(assetData.Exec.Source) then
				CustomAssets[assetName] = LoadAsset(assetData.Exec.FileName, assetData.Exec.Source)
			end
		end
	end
end

function Library.LoadAssets(Self)
	if Self.AssetsLoaded then return end
	Self:ReloadAssets()
	Self.AssetsLoaded = true
end

function Library.AddTheme(Self, themeName, themeTable)
	if IsStringNullOrEmpty(themeName) then error("Invalid theme name") end
	if not IsTable(themeTable) then error("Invalid themeTable") end
	if not IsTable(themeTable.WindowParams) then error("themeTable has no WindowParams") end
	if Self._ThemesData[themeName] then error("Theme with name\""..themeName.."\" already exists") end
	
	if not IsStringNullOrEmpty(themeTable.BasedOn) then
		local baseTable = Self._ThemesData[themeTable.BasedOn]
		if not baseTable then error("BasedOn theme table not found") end
		
		if IsTable(baseTable.Assets) and not IsTable(themeTable.Assets) then
			themeTable.Assets = {}
			RecursiveCopyTable(baseTable.Assets, themeTable.Assets)
		end
		
		RecursiveCopyTable(baseTable.WindowParams, themeTable.WindowParams)
	end
	
	Self._ThemesData[themeName] = themeTable
end

function Library.RemoveTheme(Self, themeName)
	if IsStringNullOrEmpty(themeName) then error("Invalid theme name") end
	if not Self._ThemesData[themeName] then error("Theme with name\""..themeName.."\" doesn\'t exist") end
	
	Self._ThemesData[themeName] = nil
end

function Library.GetAllThemes(Self)
	local result = {}
	for k,v in pairs(Self._ThemesData) do
		table.insert(result, k)
	end
	
	return result
end

function Library.new(paramsTable)
	if not IsTable(paramsTable) then error("Invalid paramsTable") end
	if IsStringNullOrEmpty(paramsTable.Theme) then error("Invalid Theme param") end
	
	local lib = {}
	lib.Theme = paramsTable.Theme
	lib._ThemesData = {}
	lib.Windows = {}
	lib.LastWindowAutoPosOffset = UDim2.fromScale(0, 0)
	lib.LastWindowZIndex = 1
	lib = setmetatable(lib, Library)
	
	local queuedThemes = {}
	for k,v in pairs(Library.ThemesData) do
		if not IsStringNullOrEmpty(v.BasedOn) then
			queuedThemes[k] = v
			continue
		end
		
		lib:AddTheme(k, v)
	end
	
	for k,v in pairs(queuedThemes) do
		lib:AddTheme(k, v)
	end
	table.clear(queuedThemes)
	queuedThemes = nil
	
	lib:LoadAssets()
	
	local UiContainer = IsStudio and GetPlayerGui() or _CoreGui
	local ScreenGui = UiContainer:FindFirstChild("FISP_UI")
	if not ScreenGui then
		ScreenGui = Instance.new("ScreenGui")
		ScreenGui.Parent = UiContainer
		ScreenGui.Name = "FISP_UI"
		ScreenGui.ClipToDeviceSafeArea = true
		ScreenGui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.FullscreenExtension
		ScreenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
		ScreenGui.DisplayOrder = 999
		ScreenGui.IgnoreGuiInset = true
		ScreenGui.ResetOnSpawn = false
		ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		ScreenGui.Enabled = true
	end
	lib.GUI = ScreenGui
	
	return lib
end

function Library.CreateWindowWithParams(Self, paramsTable)
	return Window.new(paramsTable)
end

function Library.CreateWindow(Self, title, subTitle, additionalParams)
	if IsStringNullOrEmpty(title) then error("Missing title argument") end
	
	if not IsTable(Self._ThemesData[Self.Theme]) then error("Invalid theme (no data)") end
	local params = {}
	RecursiveCopyTable(Self._ThemesData[Self.Theme], params)
	params = params.WindowParams
	if not IsTable(params) then error("Theme data has no WindowParams") end
	
	params.TopBar.Title = title
	if not IsStringNullOrEmpty(subTitle) then
		params.TopBar.SubTitle.Text = subTitle
	end
	params.Parent = Self.GUI
	
	if not additionalParams then additionalParams = {} end
	if (not additionalParams.StartPosition and not additionalParams.StartPositionOffset) and #Self.Windows > 0 then
		local newOffset = UDim2.fromScale(Self.LastWindowAutoPosOffset.X.Scale + 0.01, Self.LastWindowAutoPosOffset.Y.Scale + 0.01)
		additionalParams.StartPositionOffset = newOffset
		Self.LastWindowAutoPosOffset = newOffset
	end
	
	if not additionalParams.ZIndex then
		additionalParams.ZIndex = Self.LastWindowZIndex
		Self.LastWindowZIndex += 1
	end
	
	if IsTable(additionalParams) then
		RecursiveCopyTable(additionalParams, params, true)
		
		table.clear(additionalParams)
		additionalParams = nil
	end
	
	local wnd = Window.new(params)
	table.insert(Self.Windows, wnd)
	
	return wnd
end

function Library.CreateWindowWithImageTopBar(Self, titleImage, subTitleImage, additionalParams)
	if IsStringNullOrEmpty(titleImage) then error("Invalid title image argument!") end
	
	if not additionalParams then additionalParams = {} end
	if not IsTable(additionalParams.TopBar) then additionalParams.TopBar = {} end
	if not additionalParams.TopBar.TitleColor then additionalParams.TopBar.TitleColor = "__nil" end
	additionalParams.TopBar.TitleType = "Image"
	additionalParams.TopBar.TitleImage = titleImage
	
	if not IsStringNullOrEmpty(subTitleImage) then
		if not additionalParams.TopBar.SubTitle then additionalParams.TopBar.SubTitle = {} end
		
		additionalParams.TopBar.SubTitle.Type = "Image"
		if not additionalParams.TopBar.SubTitle.Color then additionalParams.TopBar.SubTitle.Color = "__nil" end
		additionalParams.TopBar.SubTitle.Image = subTitleImage
	end
	
	return Library.CreateWindow(Self, "Blank", "Blank", additionalParams)
end

return Library
