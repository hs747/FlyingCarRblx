local runService = game:GetService("RunService")
local camera = workspace.CurrentCamera

-- le config
local carConfig = {-- _C means coefficient (multiplied by the mass of the car)
	-- suspension
	SUSPENSION_HEIGHT = 2.25;
	SUSPENSION_STRENGTH_C = 1.25;
	SUSPENSION_DAMPENING_C = 3;
	-- driving linear movement
	POWER_BOOST_C = 100;
	--POWER_FORWARD_C = 100;
	DRAG_SIDE_C = 10;
	DRAG_FORWARD_C = 1;
	-- driving angular movement
	POWER_ANGULAR_C = 40;
	DRAG_ANGULAR_C = 10;
	-- visual
	WHEEL_STEER_ANGLE = 25;
	--
	DRAG_AIR_C = 1;
	-- flying
	---GYRO_FORCE_C = --Vector3.new(0, 0, 0)
}
--
local ZERO_VECTOR = Vector3.new(0, 0, 0)

-- controller variables
local inputVec = Vector2.new()
local boost = false

local car
local chassis
local mass = 0

local moveForce
local turnTorque
local boostForce
local airGyro

local wheels
local suspensionPoints
local suspensionForces

-- suspension variables
local suspensionCastParams = RaycastParams.new()
suspensionCastParams.FilterType = Enum.RaycastFilterType.Blacklist
local ders, a, b

-- functionality
local carController = {}

local function castForGround(point)
	local origin = point.WorldPosition
	local direction = -chassis.CFrame.UpVector * carConfig.SUSPENSION_HEIGHT
	local result = workspace:Raycast(origin, direction, suspensionCastParams)
	if result then
		return result.Position, (origin - result.Position).Magnitude, result.Normal
	end
end

local function updateWheels(lengths, steer, td)
	for i, wheel in ipairs(wheels) do
		local motor = wheel.WheelJoint
		local length = lengths[i]
		local position = motor.C1.Position
		local goal = Vector3.new(0, length - wheel.Size.Y/2, 0)
		--position:Lerp(goal, 0.3)
		motor.C1 = (motor.C1 - motor.C1.Position) + position:Lerp(goal, 0.3)
	end
	-- steering rotation
	local angle = CFrame.Angles(0, -steer * math.rad(carConfig.WHEEL_STEER_ANGLE), 0)
	local r, l = wheels[1], wheels[3]
	r.WheelJoint.C1 = (r.WheelJoint.C1 - r.WheelJoint.C1.Position):Lerp(angle, 0.2) + r.WheelJoint.C1.Position
	l.WheelJoint.C1 = (l.WheelJoint.C1 - l.WheelJoint.C1.Position):Lerp(angle, 0.2) + l.WheelJoint.C1.Position
end

local LIFT_C = 15 -- air density * wing area (something im just gonna tweak the shit out of)
local DRAG_C = 1
local AIR_MAX_FORCE = 1000000--Vector3.new(1000000, 1000000, 1000000)
local AIR_MAX_TORQUE = Vector3.new(100000, 100000, 100000)
local AIR_TURN_C = 100
local AIR_TURN_DRAG_C = 100
local AIR_TURN_R = math.pi/4

local function updateFlight(td, lv, lav) -- referred to math from other airfoil systems (slietnick)
	-- update steering
	airGyro.MaxTorque = AIR_MAX_TORQUE
	-- the following is disturbing (i was out of time)
	local look = airGyro.CFrame
	local x, y , z = airGyro.CFrame:ToEulerAnglesYXZ()
	airGyro.CFrame = CFrame.fromEulerAnglesYXZ(math.clamp(x + inputVec.Y * AIR_TURN_R * td, math.rad(-70), math.rad(70)), y + inputVec.X * AIR_TURN_R * td, inputVec.X * math.rad(30))--chassis.CFrame:VectorToObjectSpace(Vector3.new(0, inputVec.X * AIR_TURN_R, 0)) + Vector3.new(inputVec.Y * AIR_TURN_R, 0, 0)
	-- apply lift and drag
	local a = -math.atan2(lv.y, -lv.z)
	--print(math.deg(a))
	a = math.clamp(a, -math.rad(5), math.rad(80))
	local lc = lv.z < 0 and math.max(0, math.sin(a + math.rad(5)) * 2.75)  or 0
	local speedSquared = lv:Dot(lv) --[[lv.X * lv.X + lv.Y * lv.Y + lv.Z * lv.Z]]
	--print(speedSquared, lc)
	local lift = Vector3.new(0, lv.Z * lv.Z * lc * LIFT_C, 0)
	local drag = lv.Unit * Vector3.new(2, 2, 0.2) * speedSquared * DRAG_C--* carConfig.DRAG_AIR_C
	local force = lift - drag
	force = math.min(force.Magnitude, AIR_MAX_FORCE) * force.unit
	moveForce.Force = force
end

local function update(td)
	-- update suspension
	local grounded = true
	local inAir = true
	local lengths = {}
	for i, p in ipairs(suspensionPoints) do
		local vectorForce = suspensionForces[i]
		local point, length, normal = castForGround(p)
		lengths[i] = length or carConfig.SUSPENSION_HEIGHT
		if point then
			inAir = false
			-- get force for spring
			ders[i] = ders[i] or {0, 0}
			local x = carConfig.SUSPENSION_HEIGHT - length
			local f = a*x + b*(x-ders[i][1]) + b/2 * (x-ders[i][2])
			ders[i][2] = ders[i][1]
			ders[i][1] = x

			vectorForce.Force = Vector3.new(0, f, 0)
		else
			--grounded = false
			vectorForce.Force = ZERO_VECTOR
		end
	end
	
	-- update driving movement
	local localVelocity = chassis.CFrame:VectorToObjectSpace(chassis.AssemblyLinearVelocity)
	local localAngVelocity = chassis.CFrame:VectorToObjectSpace(chassis.AssemblyAngularVelocity)
	
	
	if not inAir then
		-- linear forces
		--local power = carConfig.POWER_FORWARD_C * mass
		local brake = (not boost and 5 or 0)
		local force = Vector3.new(0, 0, 0) * mass
		local drag = localVelocity * Vector3.new(carConfig.DRAG_SIDE_C, 0, carConfig.DRAG_FORWARD_C + brake) * mass 
		moveForce.Force = force - drag
		
		
		-- angular forces
		airGyro.CFrame = chassis.CFrame
		airGyro.MaxTorque = ZERO_VECTOR
		local aForce = ZERO_VECTOR
		if math.abs(localVelocity.Z) > 0.1 then
			aForce = inputVec.Y < 0 and Vector3.new(0, -inputVec.X, 0) or Vector3.new(0, inputVec.X, 0)
			aForce = aForce * carConfig.POWER_ANGULAR_C * mass
		end
		local aDrag = grounded and Vector3.new(0, localAngVelocity.Y, 0) * carConfig.DRAG_ANGULAR_C * mass or ZERO_VECTOR
		if inputVec.X == 0 then
			aDrag = aDrag + Vector3.new(0, localAngVelocity.Y, 0) * carConfig.POWER_ANGULAR_C * mass * 4
		end
		turnTorque.Torque = aForce - aDrag
	else
		updateFlight(td, localVelocity, localAngVelocity)
		--local drag = localVelocity * carConfig.DRAG_AIR_C
		--moveForce.Force = ZERO_VECTOR - drag
		--moveForce.Force = ZERO_VECTOR
		turnTorque.Torque = ZERO_VECTOR
	end
	if boost then
		boostForce.Force = Vector3.new(0, 0, -carConfig.POWER_BOOST_C * mass)
	else
		boostForce.Force = ZERO_VECTOR
	end
	-- update visual wheels
	updateWheels(lengths, inputVec.X)
end

function carController.setFlightSteerInput()
	
end

function carController.setInputVec(v)
	inputVec = v
end

function carController.setBoost(b)
	boost = b
	if boost then
		car.Thruster1.ParticleAttachment.Emitter.Enabled = true
		car.Thruster2.ParticleAttachment.Emitter.Enabled = true
	else
		car.Thruster1.ParticleAttachment.Emitter.Enabled = false
		car.Thruster2.ParticleAttachment.Emitter.Enabled = false
	end
end

function carController.startControl(c)
	-- update controller variables
	car = c
	chassis = car:WaitForChild("Chassis")
	mass = chassis.AssemblyMass
	
	moveForce = chassis:WaitForChild("MoveForce")
	boostForce = chassis:WaitForChild("BoostForce")
	turnTorque = chassis:WaitForChild("TurnTorque")
	airGyro = chassis:WaitForChild("TurnAir")
	
	suspensionCastParams.FilterDescendantsInstances = {car}
	ders = {}
	a = carConfig.SUSPENSION_STRENGTH_C * (mass * workspace.Gravity)/4
	b = carConfig.SUSPENSION_DAMPENING_C * a
	
	-- get wheels
	local wm = car:WaitForChild("Wheels")
	wheels = {}
	wheels[1] = wm:WaitForChild("FR")
	wheels[2] = wm:WaitForChild("BR")
	wheels[3] = wm:WaitForChild("FL")
	wheels[4] = wm:WaitForChild("BL")
	
	-- get suspension points & forces
	suspensionPoints = {}
	suspensionPoints[1] = chassis:WaitForChild("SuspensionPointFR")
	suspensionPoints[2] = chassis:WaitForChild("SuspensionPointBR")
	suspensionPoints[3] = chassis:WaitForChild("SuspensionPointFL")
	suspensionPoints[4] = chassis:WaitForChild("SuspensionPointBL")
	
	suspensionForces = {}
	suspensionForces[1] = chassis:WaitForChild("SuspensionForceFR")
	suspensionForces[2] = chassis:WaitForChild("SuspensionForceBR")
	suspensionForces[3] = chassis:WaitForChild("SuspensionForceFL")
	suspensionForces[4] = chassis:WaitForChild("SuspensionForceBL")
	
	-- set camera
	camera.CameraSubject = chassis
	camera.CameraType = Enum.CameraType.Custom
	
	carController.setBoost(false)
	
	-- connect updater
	runService.Heartbeat:Connect(update)
end

function carController.endControl()
end

return carController