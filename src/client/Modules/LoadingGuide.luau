-- Loading-screen artwork composed exclusively from the game's own asset renderers.
-- No automatic onboarding. Call preview() in Studio to review; mount() is ready
-- for a loading controller to drive with real progress and destroy on completion.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local GemArt = require(script.Parent.GemArt)
local GearArt = require(script.Parent.GearArt)
local SurgeIcons = require(script.Parent.SurgeIcons)
local Guide = {}
local gold = Color3.fromRGB(255, 206, 91)
local white = Color3.fromRGB(232, 240, 247)
local dim = Color3.fromRGB(151, 173, 190)
Guide.Topics = {
	{"MINING", "Your next upgrade is in the rock.", "Click, tap, or press E for each swing. Break rocks to discover gems."},
	{"GEMS", "One gem. Two ways to build.", "Enchant equipment or equip a Surge. Each gem occupies one place at a time."},
	{"ENCHANTING", "Give your gear an edge.", "Select an equipment slot, choose a gem, and check the resulting effect."},
	{"SURGES", "Put power on your hotbar.", "Equip Surges in Q, E, or R. On mobile, tap their ability buttons."},
	{"CHARGE", "Strike. Build Charge. Unleash.", "Start at zero Charge. Land attacks to build it, then spend it on Surges."},
}
local function make(class, props, parent)
	local object = Instance.new(class)
	for k, v in props do object[k] = v end
	object.Parent = parent
	return object
end
local function label(parent, value, x, y, w, h, size, color)
	return make("TextLabel", {BackgroundTransparency=1, Position=UDim2.fromOffset(x,y), Size=UDim2.fromOffset(w,h),
		Text=value, TextColor3=color or white, TextSize=size, Font=Enum.Font.GothamMedium,
		TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left}, parent)
end
local function tile(parent, x, caption)
	local f = make("Frame", {BackgroundColor3=Color3.fromRGB(15,29,40), BorderSizePixel=0,
		Position=UDim2.fromOffset(x,135),Size=UDim2.fromOffset(300,290)},parent)
	make("UICorner", {CornerRadius=UDim.new(0,14)},f)
	make("UIStroke", {Color=Color3.fromRGB(43,66,78),Thickness=1},f)
	label(f,caption,20,243,260,30,18,gold)
	return make("Frame", {BackgroundTransparency=1,Position=UDim2.fromOffset(20,10),Size=UDim2.fromOffset(260,225)},f)
end
local function gem(parent, element)
	GemArt.viewport(parent,{Id="LoadingGuide"..element,Element=element,Tier="Common",Size=7,Clarity=7,Cut=6},true)
end
local function icon(parent, id)
	local target=make("TextLabel",{BackgroundTransparency=1,Text="",AnchorPoint=Vector2.new(.5,.5),
		Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(160,160)},parent)
	SurgeIcons.apply(target,id,gold)
end
local function gear(parent, slot)
	local view=make("ViewportFrame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),
		Ambient=Color3.fromRGB(190,190,200),LightColor=Color3.new(1,1,1),LightDirection=Vector3.new(-1,-1,-1)},parent)
	if not GearArt.draw(view,slot,"",true) then
		label(parent,"Equipment preview becomes available after your miner spawns.",15,65,230,90,16,dim)
	end
end
local function rock(parent)
	local source
	for _, candidate in CollectionService:GetTagged("OutpostNode") do
		if candidate:IsA("Model") and candidate:GetAttribute("NodeId") then source=candidate;break end
	end
	if not source then label(parent,"Mining rock preview becomes available in the Outpost.",15,65,230,90,16,dim);return end
	local view=make("ViewportFrame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Ambient=Color3.fromRGB(180,180,195),LightColor=Color3.new(1,1,1)},parent)
	local model=make("Model",{},view)
	for _, part in source:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency<1 then
			local clone=part:Clone()
			for _, child in clone:GetChildren() do if child:IsA("LuaSourceContainer") or child:IsA("ProximityPrompt") then child:Destroy() end end
			clone.Anchored=true;clone.Parent=model
		end
	end
	if #model:GetChildren()==0 then return end
	local cf,size=model:GetBoundingBox()
	local cam=make("Camera",{FieldOfView=35},view)
	cam.CFrame=CFrame.lookAt(cf.Position+Vector3.new(.6,.4,1).Unit*size.Magnitude*1.6,cf.Position)
	view.CurrentCamera=cam
end
function Guide.mount(parent, firstTopic, preview)
	local gui=make("ScreenGui",{Name="LoadingGuide",IgnoreGuiInset=true,ResetOnSpawn=false,DisplayOrder=200},parent)
	local background=make("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(7,14,21),BorderSizePixel=0},gui)
	make("UIGradient",{Rotation=25,Color=ColorSequence.new(Color3.fromRGB(19,42,53),Color3.fromRGB(6,10,18))},background)
	local canvas=make("Frame",{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(1120,630)},background)
	local scale=make("UIScale",{},canvas)
	local function resize() scale.Scale=math.min(background.AbsoluteSize.X/1120,background.AbsoluteSize.Y/630) end
	local connection=background:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize);resize()
	local stage=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1)},canvas)
	local track=make("Frame",{BackgroundColor3=Color3.fromRGB(42,56,67),BorderSizePixel=0,Position=UDim2.fromOffset(50,605),Size=UDim2.fromOffset(1020,3)},canvas)
	local fill=make("Frame",{BackgroundColor3=gold,BorderSizePixel=0,Size=UDim2.fromScale(0,1)},track)
	local current=firstTopic or 1
	local function show(index)
		current=math.clamp(index,1,#Guide.Topics);stage:ClearAllChildren()
		local topic=Guide.Topics[current]
		label(stage,string.format("FIELD GUIDE  /  %02d     %s",current,topic[1]),50,46,900,26,16,gold)
		label(stage,topic[2],50,458,1020,62,34)
		label(stage,topic[3],50,528,990,50,21,dim)
		if current==1 then
			rock(tile(stage,50,"01  MINE"));gem(tile(stage,410,"02  DISCOVER"),"Fire");gear(tile(stage,770,"03  BUILD YOUR MINER"),"Helmet")
		elseif current==2 then
			gear(tile(stage,50,"ENCHANT EQUIPMENT"),"Armor");gem(tile(stage,410,"CHOOSE HOW TO USE IT"),"Fire");icon(tile(stage,770,"EQUIP AN ACTIVE SURGE"),"EmberLance")
		elseif current==3 then
			gear(tile(stage,50,"01  SELECT EQUIPMENT"),"Helmet");gem(tile(stage,410,"02  CHOOSE A GEM"),"Frost")
			local result=tile(stage,770,"03  READ THE PERK")
			label(result,"CHECK YOUR GEAR",16,38,230,42,22,gold)
			label(result,"Read the equipment's effect after enchanting to see what changed.",16,100,230,100,21,white)
		elseif current==4 then
			for i,entry in {{"Q","EmberLance","Fire"},{"E","CryoShield","Frost"},{"R","IonSpark","Shock"}} do
				local holder=tile(stage,50+(i-1)*360,entry[1].."  /  EXAMPLE SURGE")
				icon(holder,entry[2])
				local small=make("Frame",{BackgroundTransparency=1,Position=UDim2.fromOffset(188,158),Size=UDim2.fromOffset(70,65)},holder);gem(small,entry[3])
			end
		else
			gear(tile(stage,50,"01  LAND ATTACKS"),"Weapon")
			local holder=tile(stage,410,"02  BUILD CHARGE")
			label(holder,"CHARGE",18,45,220,34,24,gold)
			for i=1,8 do make("Frame",{BackgroundColor3=if i<=5 then gold else Color3.fromRGB(43,62,73),BorderSizePixel=0,Position=UDim2.fromOffset(18+(i-1)*28,105),Size=UDim2.fromOffset(22,48)},holder) end
			label(holder,"Attacks fill the meter",18,170,230,28,16,dim)
			icon(tile(stage,770,"03  SPEND IT ON A SURGE"),"IonSpark")
		end
	end
	if preview then
		for i,topic in Guide.Topics do
			local button=make("TextButton",{BackgroundTransparency=1,Text=topic[1],TextColor3=dim,TextSize=12,Font=Enum.Font.GothamMedium,Position=UDim2.fromOffset(50+(i-1)*160,88),Size=UDim2.fromOffset(150,30)},canvas)
			button.Activated:Connect(function() show(i) end)
		end
		local close=make("TextButton",{BackgroundTransparency=1,Text="CLOSE",TextColor3=gold,TextSize=14,Position=UDim2.fromOffset(965,45),Size=UDim2.fromOffset(105,30)},canvas)
		close.Activated:Connect(function() gui:Destroy() end)
	end
	gui.Destroying:Connect(function() connection:Disconnect() end)
	show(current)
	return {Show=show,SetProgress=function(value) fill.Size=UDim2.fromScale(math.clamp(value,0,1),1) end,Destroy=function() gui:Destroy() end}
end
function Guide.preview()
	local player=Players.LocalPlayer
	local gui=player:WaitForChild("PlayerGui")
	local old=gui:FindFirstChild("LoadingGuide");if old then old:Destroy() end
	return Guide.mount(gui,1,true)
end
return Guide
