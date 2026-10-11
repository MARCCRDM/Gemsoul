-- Pooled elemental border layers. Geometry is clipped to the card and
-- kept at its edges; no image upload or per-frame instance allocation.
local FX = {}
local colors = require(game:GetService("ReplicatedStorage").Shared.GemConfig).ElementColors

local function shape(parent)
 local part = Instance.new("Frame")
 part.BorderSizePixel = 0
 part.AnchorPoint = Vector2.new(0.5, 0.5)
 part.Active = false
 part.Parent = parent
 return part
end
local function round(part, amount)
 local corner = Instance.new("UICorner")
 corner.CornerRadius = UDim.new(amount, 0)
 corner.Parent = part
 return corner
end
local function line(part, a, b, width)
 local delta = b - a
 part.Position = UDim2.fromOffset((a.X + b.X)/2, (a.Y + b.Y)/2)
 part.Size = UDim2.fromOffset(delta.Magnitude, width)
 part.Rotation = math.deg(math.atan2(delta.Y, delta.X))
end

function FX.create(card: GuiObject, _gemWell: GuiObject)
 local layer = shape(card)
 layer.Name = "ElementalBorderLayer"
 layer.Position = UDim2.fromScale(0.5, 0.5)
 layer.Size = UDim2.fromScale(1, 1)
 layer.BackgroundTransparency = 1
 layer.ClipsDescendants = true
 layer.ZIndex = 2
 layer.Visible = false
 round(layer, 0.08)
 local washes = {}
 for index = 1, 4 do
  local wash = shape(layer)
  local horizontal = index <= 2
  wash.Size = if horizontal then UDim2.new(1,0,0,17) else UDim2.new(0,17,1,0)
  wash.Position = if horizontal then UDim2.fromScale(0.5, if index == 1 then 0 else 1) else UDim2.fromScale(if index == 3 then 0 else 1,0.5)
  local gradient = Instance.new("UIGradient")
  gradient.Rotation = if horizontal then 90 else 0
  gradient.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(0.5,0), NumberSequenceKeypoint.new(1,1)})
  gradient.Parent = wash
  washes[index] = wash
 end
 local shapes = {}
 for index = 1, 18 do
  local body = shape(layer)
  local corner = round(body, 0)
  local gradient = Instance.new("UIGradient")
  gradient.Rotation = 90
  gradient.Parent = body
  local core = shape(layer)
  local coreCorner = round(core, 0)
  shapes[index] = { Body=body, Core=core, Corner=corner, CoreCorner=coreCorner, Gradient=gradient }
 end
 return { Layer=layer, Washes=washes, Shapes=shapes }
end

function FX.update(effect, element, time)
 local color = colors[element]
 effect.Layer.Visible = color ~= nil
 if not color then return end
 -- Use local offsets: ancestor UIScale handles screen/mobile sizing.
 local card = effect.Layer.Parent
 local width, height = card.Size.X.Offset, card.Size.Y.Offset
 if width <= 0 or height <= 0 then return end
 local thermal = element == "Fire"
 local frost = element == "Frost"
 local ion = element == "Shock"
 local accent = if thermal then Color3.fromRGB(255,116,32) elseif frost then Color3.fromRGB(108,218,255) else color
 for _, wash in effect.Washes do
  wash.BackgroundColor3 = accent
  wash.BackgroundTransparency = 0.48 + math.sin(time * 1.7) * 0.06
 end
 for index, piece in effect.Shapes do
  local body, core = piece.Body, piece.Core
  local wave = 0.5 + 0.5 * math.sin(time * 2.4 + index * 1.93)
  local bottom = index % 2 == 0
  local x = ((index - 1) / 18 + 0.025) * width
  body.BackgroundColor3 = accent
  core.BackgroundColor3 = accent:Lerp(Color3.new(1,1,1),0.65)
  piece.Gradient.Transparency = NumberSequence.new(0)
  piece.Corner.CornerRadius = UDim.new(0,0)
  piece.CoreCorner.CornerRadius = UDim.new(0,0)
  core.Visible = true
  if thermal then
   -- Overlapping flame tongues, warm cores, tapered/fading tips.
   local size = 9 + wave * 15
   body.Position = UDim2.fromOffset(x + math.sin(time*2+index)*3, if bottom then height+6 else -6)
   body.Size = UDim2.fromOffset(7 + wave*5,size)
   body.Rotation = math.sin(time*3+index)*18
   piece.Corner.CornerRadius = UDim.new(0.5,0)
   piece.Gradient.Transparency = if bottom then NumberSequence.new(1,0.05) else NumberSequence.new(0.05,1)
   body.BackgroundTransparency = 0.23
   core.Size = UDim2.fromOffset(3+wave*3,size*0.48)
   core.Position = body.Position
   core.Rotation = body.Rotation
   piece.CoreCorner.CornerRadius = UDim.new(0.5,0)
   core.BackgroundColor3 = Color3.fromRGB(255,218,102)
   core.BackgroundTransparency = 0.28
  elseif ion then
   -- Two continuous zigzag arcs with branches at the border.
   local segment = math.floor((index-1)/2)
   local tick = math.floor(time*7)
   local function point(n)
    local jitter = 2 + (math.sin(n*17.1+tick*0.8)*0.5+0.5)*6
    return Vector2.new(n*width/9, if bottom then height-jitter else jitter)
   end
   local a,b = point(segment), point(segment+1)
   line(body,a,b,2)
   if index % 3 == 0 then
    local middle = (a+b)*0.5
    line(core,middle,middle+Vector2.new(7,if bottom then -4 else 4),1)
   else
    line(core,a,b,0.8)
   end
   body.BackgroundTransparency = 0.3 + wave*0.25
   core.BackgroundTransparency = 0.2 + wave*0.25
  elseif frost then
   -- Faceted crystal teeth grow inward from an icy rim.
   local size = 7 + (index%4)*3
   body.Size = UDim2.fromOffset(size,size)
   body.Position = UDim2.fromOffset(x, if bottom then height-1 else 1)
   body.Rotation = 45
   body.BackgroundTransparency = 0.45
   piece.Gradient.Transparency = NumberSequence.new(0.65,0.05)
   core.Size = UDim2.fromOffset(1,size*1.7)
   core.Position = body.Position
   core.Rotation = 45
   core.BackgroundTransparency = 0.35 + wave*0.4
  else
   -- Slow, overlapping corrosive vapor with small bright bubble cores.
   local size = 17 + wave*18
   piece.Corner.CornerRadius = UDim.new(1,0)
   body.Size = UDim2.fromOffset(size*1.6,size)
   body.Position = UDim2.fromOffset(x+math.sin(time*0.8+index)*6, if bottom then height+3 else -3)
   body.Rotation = 0
   body.BackgroundTransparency = 0.82
   core.Size = UDim2.fromOffset(3,3)
   core.Position = UDim2.fromOffset(x, if bottom then height-wave*8 else wave*8)
   core.Rotation = 0
   piece.CoreCorner.CornerRadius = UDim.new(1,0)
   core.BackgroundTransparency = 0.5 + wave*0.3
  end
 end
end
return FX
