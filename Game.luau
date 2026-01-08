local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local AssetService = game:GetService("AssetService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")

type ball = {
	Position : Vector2,
	Velocity : Vector2,
	Radius : number,
	
	Elasticity : number,
	Color : Color3
}

local CANVAS_SIZE = Vector2.new(1024, 1024)
local BACKGROUND_COLOR = Color3.new(0.0784314, 0.0784314, 0.0784314)

local PHYSICS_SUBSTEPS = 50

local GRAVITY = 900
local FRICTION = 0.9
local FLOOR_HEIGHT = CANVAS_SIZE.Y

local player = Players.LocalPlayer

local canvas = AssetService:CreateEditableImage({Size = CANVAS_SIZE})

local balls : {ball} = {}


local _canvasUI = script.CanvasUI
local _display = _canvasUI.Display

_canvasUI.Parent = player.PlayerGui
_display.UIAspectRatioConstraint.AspectRatio = CANVAS_SIZE.X / CANVAS_SIZE.Y
_display.ImageContent = Content.fromObject(canvas)

local function getMouseOnCanvas()
	local mousePos = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
	local displayPos = _display.AbsolutePosition
	local displaySize = _display.AbsoluteSize
	
	-- Convert mouse position to local coordinates (0 to 1 range)
	local localX = (mousePos.X - displayPos.X) / displaySize.X
	local localY = (mousePos.Y - displayPos.Y) / displaySize.Y
	
	-- Convert to canvas coordinates
	local canvasX = localX * CANVAS_SIZE.X
	local canvasY = localY * CANVAS_SIZE.Y
	
	if localX >= 0 and localX <= 1 and localY >= 0 and localY <= 1 then
		return Vector2.new(canvasX, canvasY)
	end
	
	return nil 
end

local function getBallAtPoint(point : Vector2)
	for _, ball in balls do
		local dist = (point - ball.Position).Magnitude
		if dist <= ball.Radius then
			return ball
		end
	end
	
	return nil
end

local function update(dt : number) --game state
	
end

local function physics(dt : number) --moving balls
	for i, ball in balls do
		local xVel = ball.Velocity.X
		local yVel = ball.Velocity.Y
		
		yVel += GRAVITY * dt 
		
		local x = ball.Position.X + xVel * dt  
		local y = ball.Position.Y + yVel * dt 
		
		if x < ball.Radius/2 or x > CANVAS_SIZE.X + ball.Radius/2 then
			xVel *= -ball.Elasticity
		end
		
		if (yVel > 0) and (y > FLOOR_HEIGHT - ball.Radius) then
			y = FLOOR_HEIGHT - ball.Radius
			yVel *= -ball.Elasticity
			xVel *= FRICTION
		end
		
		ball.Position = Vector2.new(x, y)
		ball.Velocity = Vector2.new(xVel, yVel)
	end
	
	-- Ball-to-ball collision (separate loop after positions are updated)
	for i, ball in balls do
		for i2 = i + 1, #balls do
			local ball2 = balls[i2]
			local delta = ball2.Position - ball.Position
			local dist = delta.Magnitude
			local minDist = ball.Radius + ball2.Radius
			
			if dist < minDist and dist > 0 then
				-- Collision normal (unit vector pointing from ball1 to ball2)
				local normal = delta.Unit
				
				local overlap = minDist - dist
				local separation = normal * (overlap / 2)
				ball.Position -= separation
				ball2.Position += separation
				
				local relativeVel = ball2.Velocity - ball.Velocity
				local velAlongNormal = relativeVel.X * normal.X + relativeVel.Y * normal.Y

				if velAlongNormal < 0 then
					local restitution = (ball.Elasticity + ball2.Elasticity) / 2
					local impulse = -(1 + restitution) * velAlongNormal
					impulse /= (1/ball.Radius + 1/ball2.Radius) -- Using radius as mass
					
					local impulseVec = normal * impulse
					ball.Velocity -= impulseVec / ball.Radius
					ball2.Velocity += impulseVec / ball2.Radius
				end
			end
		end
	end
end

local function render(dt : number) -- rendering balls
	for _, ball in balls do
		local drawPos = Vector2.new(
			math.clamp(
				ball.Position.X,
				0 - ball.Radius,
				CANVAS_SIZE.X + ball.Radius
			),
			math.clamp(
				ball.Position.Y,
				0 - ball.Radius,
				CANVAS_SIZE.Y + ball.Radius
			)
		)		
		
		canvas:DrawCircle(
			drawPos,
			ball.Radius,
			ball.Color,
			0,
			Enum.ImageCombineType.AlphaBlend
		)
	end
end

local function placeBall(inputName, inputState : Enum.UserInputState, inputObject : InputObject)
	while inputObject.UserInputState == Enum.UserInputState.Begin do
		local pos = getMouseOnCanvas()
		if pos then
			local ball : ball = {
				Position = pos,
				Velocity = Vector2.new(math.random(-30, 30), math.random(0, 50)),
				Radius = math.random(5, 20),
				
				Elasticity = 0.9,
				
				Color = Color3.new(math.random(),math.random(), math.random()),
			}
			
			table.insert(balls, ball)
		end
		
		task.wait(0.1)
	end
end
ContextActionService:BindAction("Place", placeBall, false, Enum.UserInputType.MouseButton1)


local function growBall(inputName, inputState : Enum.UserInputState, inputObject : InputObject)
	while inputObject.UserInputState == Enum.UserInputState.Begin do
		local ball = getBallAtPoint(getMouseOnCanvas())
		if ball then
			ball.Radius += 1
		end
		task.wait()
	end
end
ContextActionService:BindAction("Grow", growBall, false, Enum.KeyCode.E)

local function shrinkBall(inputName, inputState : Enum.UserInputState, inputObject : InputObject)
	while inputObject.UserInputState == Enum.UserInputState.Begin do
		local ball = getBallAtPoint(getMouseOnCanvas())
		if ball then
			ball.Radius -= 1
		end
		task.wait()
	end
end
ContextActionService:BindAction("Shrink", shrinkBall, false, Enum.KeyCode.Q)

RunService.RenderStepped:Connect(function(deltaTime: number) 
	canvas:DrawRectangle( --clear screen
		Vector2.zero,
		Vector2.new(CANVAS_SIZE.X, CANVAS_SIZE.Y),
		BACKGROUND_COLOR,
		0,
		Enum.ImageCombineType.Overwrite
	)
	
	update()
	
	local subDt = deltaTime / PHYSICS_SUBSTEPS
	for i = 1, PHYSICS_SUBSTEPS do
		physics(subDt)
	end
	
	render()
end)
