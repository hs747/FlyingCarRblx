local uis = game:GetService("UserInputService")
local carController = require(script.CarController)
local player = game:GetService("Players").LocalPlayer
-- handle input
local input = {{0, 0}, {0, 0}}

local function getInputVec()
	return Vector2.new(input[1][1] - input[1][2], input[2][1] - input[2][2])
end

uis.InputBegan:Connect(function(inputObj, gp)
	if inputObj.UserInputType == Enum.UserInputType.Keyboard then
		if inputObj.KeyCode == Enum.KeyCode.A then
			input[1][1] = 1
		elseif inputObj.KeyCode == Enum.KeyCode.D then
			input[1][2] = 1
		elseif inputObj.KeyCode == Enum.KeyCode.W then
			input[2][1] = 1
		elseif inputObj.KeyCode == Enum.KeyCode.S then
			input[2][2] = 1
		elseif inputObj.KeyCode == Enum.KeyCode.LeftShift then
			carController.setBoost(true)
		end
		carController.setInputVec(getInputVec())
	end
end)

uis.InputEnded:Connect(function(inputObj, gp) 
	if inputObj.UserInputType == Enum.UserInputType.Keyboard then
		if inputObj.KeyCode == Enum.KeyCode.A then
			input[1][1] = 0
		elseif inputObj.KeyCode == Enum.KeyCode.D then
			input[1][2] = 0
		elseif inputObj.KeyCode == Enum.KeyCode.W then
			input[2][1] = 0
		elseif inputObj.KeyCode == Enum.KeyCode.S then
			input[2][2] = 0
		elseif inputObj.KeyCode == Enum.KeyCode.LeftShift then
			carController.setBoost(false)
		end
		carController.setInputVec(getInputVec())
	end
end)

-- get player's car
local carValue = player:WaitForChild("Car")
local car = carValue.Value
carController.startControl(car)
print("initiated")