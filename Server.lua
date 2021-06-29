local players = game:GetService("Players")
local carModel = game.ServerStorage.Car

local function newForce(chassis, attachment, name)
	local force = Instance.new("VectorForce")
	force.Force = Vector3.new(0, 0, 0)
	force.Attachment0 = attachment
	force.Name = name
	force.Parent = chassis
	return force
end

local function getCar(plyr)
	local car = carModel:Clone()
	local chassis = car.Chassis
	-- weld parts
	for _, p in ipairs(car:GetChildren()) do
		if not (p == chassis) and p:IsA("BasePart") then
			local w = Instance.new("Weld")
			w.Part0 = chassis
			w.Part1 = p
			w.C0 = chassis.CFrame:ToObjectSpace(p.CFrame)
			w.Parent = p
		end
	end
	-- joint wheels
	for _, w in ipairs(car.Wheels:GetChildren()) do
		local j = Instance.new("Motor6D")
		j.Part0 = chassis
		j.Part1 = w
		j.C0 = chassis.CFrame:ToObjectSpace(w.CFrame)
		j.Name = "WheelJoint"
		j.Parent = w
	end
	-- create forces
	newForce(chassis, chassis.SuspensionPointFR, "SuspensionForceFR")
	newForce(chassis, chassis.SuspensionPointBR, "SuspensionForceBR")
	newForce(chassis, chassis.SuspensionPointFL, "SuspensionForceFL")
	newForce(chassis, chassis.SuspensionPointBL, "SuspensionForceBL")
	-- parent, setnetwork ownership, etc
	car.Parent = workspace
	chassis:SetNetworkOwner(plyr)
	return car
end

local cars = {}
local function playerAdded(plyr)
	-- get car for player & save in table
	local car = getCar(plyr)
	cars[plyr] = car
	-- asign w/ object value
	local carRef = Instance.new("ObjectValue")
	carRef.Value = car
	carRef.Name = "Car"
	carRef.Parent = plyr
end

local function playerRemoving(plyr)
	-- delete car and remove from table
	if cars[plyr] then
		cars[plyr]:Destroy()
		cars[plyr] = nil
	end
end

for _, plyr in ipairs(players:GetPlayers()) do
	playerAdded(plyr)
end
players.PlayerAdded:Connect(playerAdded)
players.PlayerRemoving:Connect(playerRemoving)