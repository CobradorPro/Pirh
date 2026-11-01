--[[
	╔══════════════════════════════════════════════════════════════════════════╗
	║         ROBLOX — ADVANCED REGENERATION MOVESET (LocalScript)             ║
	║                                                                          ║
	║  Local: StarterPlayer > StarterPlayerScripts                             ║
	║                                                                          ║
	║  Três Habilidades Regenerativas Completas:                               ║
	║   1. JUMP   — Salto com desprendimento físico das pernas, queda deitado, ║
	║               reconstrução anatômica progressiva e levantar natural.     ║
	║   2. NOCLIP — Explosão em fragmentos, poça viscosa, transformação em     ║
	║               gota vermelha controlável com Noclip real (3s) e           ║
	║               reconstrução corporal sequencial (Torso → Estrutura →      ║
	║               Membros → Cabeça → Superfície Externa).                    ║
	║   3. GANCHO — Mira por toque/clique em superfície, lançamento do braço   ║
	║               direito geométrico, feixes de tendões/fibras nervosas com  ║
	║               gotas vermelhas, puxão com aceleração/balanço/desaceleração║
	║               e reconexão biológica ao ombro.                            ║
	║                                                                          ║
	║  Compatível com R6 e R15 | Mobile & PC | BulkMoveTo Renderer             ║
	╚══════════════════════════════════════════════════════════════════════════╝
]]

--------------------------------------------------------------------------------
-- SERVIÇOS
--------------------------------------------------------------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera

-- RemoteEvent opcional para sincronizar CollisionGroup do Noclip com o Servidor
local noclipRemote = ReplicatedStorage:FindFirstChild("RegenMovesetRemote")

--------------------------------------------------------------------------------
-- CONFIGURAÇÃO GLOBAL E PALETA BIOMECÂNICA
--------------------------------------------------------------------------------
local CONFIG = {
	Quality = "Auto", -- "Auto" | "High" | "Low"

	Cooldowns = {
		Jump = 9.0,
		Noclip = 12.0,
		Grapple = 6.5,
	},

	Jump = {
		AnticipationTime = 0.34,
		LaunchVelocityY = 76,
		ForwardBoost = 18,
		DetachTime = 0.24,      -- após sair do chão
		MinAirTime = 0.55,
		ImpactSettleTime = 0.48,
		LegRegenTime = 4.20,
		StandUpTime = 1.25,
	},

	Noclip = {
		ExplodeTime = 0.55,
		PuddleToDropTime = 0.55,
		ControlDuration = 3.00,
		MoveSpeed = 34,
		DropAccel = 14,
		FullRegenTime = 4.60,
	},

	Grapple = {
		MaxDistance = 145,
		MinDistance = 10,
		AimTimeout = 8.0,
		ArmLaunchSpeed = 165,
		PullMaxSpeed = 92,
		PullAccel = 150,
		ArrivalDistance = 6.5,
		RetractTime = 0.42,
	},

	Colors = {
		Energy     = Color3.fromRGB(228, 52, 48),
		EnergyHot  = Color3.fromRGB(255, 168, 138),
		EnergyCore = Color3.fromRGB(255, 92, 82),
		Stump      = Color3.fromRGB(112, 22, 28),
		StumpDeep  = Color3.fromRGB(58, 10, 14),
		Bone       = Color3.fromRGB(234, 226, 212),
		BoneHot    = Color3.fromRGB(255, 210, 188),
		Joint      = Color3.fromRGB(214, 204, 186),
		Ligament   = Color3.fromRGB(224, 184, 176),
		Muscle     = Color3.fromRGB(132, 24, 32),
		MuscleDeep = Color3.fromRGB(86, 14, 20),
		MuscleHot  = Color3.fromRGB(198, 54, 50),
		Membrane   = Color3.fromRGB(154, 42, 48),
		Droplet    = Color3.fromRGB(196, 22, 30),
		DropletHot = Color3.fromRGB(245, 68, 62),
		DropletDeep= Color3.fromRGB(98, 8, 14),
		Tendon     = Color3.fromRGB(168, 28, 36),
		Nerve      = Color3.fromRGB(255, 118, 104),
		Smoke      = Color3.fromRGB(96, 78, 82),
		SmokeDark  = Color3.fromRGB(58, 44, 48),
	},
}

local QUALITY_PRESETS = {
	High = {
		boneSegs = 2,
		muscleBundles = 6,
		ligaments = 4,
		skinSlices = 2,
		shards = 4,
		fragmentPool = 18,
		dropletSatellites = 6,
		puddleRings = 4,
		tendonStrands = 3,
		tendonSegments = 14,
		grappleDroplets = 10,
	},
	Low = {
		boneSegs = 1,
		muscleBundles = 4,
		ligaments = 2,
		skinSlices = 1,
		shards = 2,
		fragmentPool = 10,
		dropletSatellites = 4,
		puddleRings = 3,
		tendonStrands = 2,
		tendonSegments = 9,
		grappleDroplets = 6,
	},
}

local TEX_SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local TEX_SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local C = CONFIG.Colors
local PI = math.pi
local TAU = PI * 2

--------------------------------------------------------------------------------
-- MATEMÁTICA DE ANIMAÇÃO E FUNÇÕES PURAS
--------------------------------------------------------------------------------
local function clamp(x, a, b)
	return x < a and a or (x > b and b or x)
end

local function clamp01(x)
	return x < 0 and 0 or (x > 1 and 1 or x)
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function inv(a, b, x)
	if a == b then
		return x >= b and 1 or 0
	end
	return clamp01((x - a) / (b - a))
end

local function smooth(a, b, x)
	local t = inv(a, b, x)
	return t * t * (3 - 2 * t)
end

local function outCubic(x)
	x = clamp01(x)
	local i = 1 - x
	return 1 - i * i * i
end

local function inCubic(x)
	x = clamp01(x)
	return x * x * x
end

local function inOutSine(x)
	x = clamp01(x)
	return 0.5 - 0.5 * math.cos(PI * x)
end

local function outBack(x, k)
	x = clamp01(x)
	k = k or 1.35
	local i = x - 1
	return 1 + (k + 1) * i * i * i + k * i * i
end

local function spring(x)
	x = clamp01(x)
	if x >= 1 then
		return 1
	end
	return 1 - math.exp(-6.2 * x) * math.cos(10.5 * x)
end

local function bell(x)
	x = clamp01(x)
	return math.sin(PI * x)
end

local function noise(t, seed)
	return math.noise(t, seed, 0.37) * 2
end

local function rand(a, b)
	return a + math.random() * (b - a)
end

local function bezier(p0, p1, p2, t)
	local i = 1 - t
	return p0 * (i * i) + p1 * (2 * i * t) + p2 * (t * t)
end

local function heartPulse(clock)
	local x = (clock * 1.2) % 1
	local a = (x - 0.08) / 0.05
	local b = (x - 0.25) / 0.06
	return math.exp(-a * a) + 0.55 * math.exp(-b * b)
end

local function expAlpha(dt, speed)
	return 1 - math.exp(-dt * speed)
end

local function resolveQuality()
	local q = CONFIG.Quality
	if q == "Auto" then
		q = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) and "Low" or "High"
	end
	return QUALITY_PRESETS[q] or QUALITY_PRESETS.High
end

--------------------------------------------------------------------------------
-- RENDERER DE ALTA PERFORMANCE (BulkMoveTo em lote por frame)
--------------------------------------------------------------------------------
local Renderer = {}
Renderer.__index = Renderer
local MIN_PART_SIZE = 0.015

function Renderer.new(parent)
	return setmetatable({
		parent = parent,
		parts = {},
		cframes = {},
		count = 0,
		pool = {},
	}, Renderer)
end

function Renderer:Create(color, material, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Locked = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Material = material or Enum.Material.SmoothPlastic
	p.Color = color or C.Bone
	p.Transparency = 1
	p.Size = Vector3.new(0.05, 0.05, 0.05)
	p.Parent = self.parent
	local el = {
		part = p,
		alpha = 1,
		size = p.Size,
		color = p.Color,
		material = p.Material,
	}
	table.insert(self.pool, el)
	return el
end

function Renderer:Hide(el)
	if not el then
		return
	end
	if el.alpha < 1 then
		el.part.Transparency = 1
		el.alpha = 1
	end
end

function Renderer:Place(part, cf)
	local n = self.count + 1
	self.count = n
	self.parts[n] = part
	self.cframes[n] = cf
end

function Renderer:Draw(el, cf, size, alpha, color, material)
	if not el then
		return
	end
	alpha = clamp01(alpha or 0)
	if alpha >= 0.994 then
		self:Hide(el)
		return
	end
	if math.abs(el.alpha - alpha) > 0.003 then
		el.part.Transparency = alpha
		el.alpha = alpha
	end
	local sx = math.max(size.X, MIN_PART_SIZE)
	local sy = math.max(size.Y, MIN_PART_SIZE)
	local sz = math.max(size.Z, MIN_PART_SIZE)
	local dsx = math.abs(el.size.X - sx)
	local dsy = math.abs(el.size.Y - sy)
	local dsz = math.abs(el.size.Z - sz)
	if dsx + dsy + dsz > 0.002 then
		local newSize = Vector3.new(sx, sy, sz)
		el.part.Size = newSize
		el.size = newSize
	end
	if color then
		local c = el.color
		if math.abs(c.R - color.R) + math.abs(c.G - color.G) + math.abs(c.B - color.B) > 0.005 then
			el.part.Color = color
			el.color = color
		end
	end
	if material and el.material ~= material then
		el.part.Material = material
		el.material = material
	end
	self:Place(el.part, cf)
end

function Renderer:HideAll()
	for _, el in ipairs(self.pool) do
		self:Hide(el)
	end
end

function Renderer:Flush()
	if self.count > 0 then
		Workspace:BulkMoveTo(self.parts, self.cframes, Enum.BulkMoveMode.FireCFrameChanged)
		table.clear(self.parts)
		table.clear(self.cframes)
		self.count = 0
	end
end

function Renderer:Destroy()
	table.clear(self.parts)
	table.clear(self.cframes)
	table.clear(self.pool)
	self.count = 0
end

--------------------------------------------------------------------------------
-- ABSTRAÇÃO DE RIG (R6 E R15), VISIBILIDADE E MOTOR6D POSE CONTROLLER
--------------------------------------------------------------------------------
local RigAdapter = {}

local LIMB_PART_NAMES = {
	R6 = {
		Torso    = { "Torso" },
		Head     = { "Head" },
		RightArm = { "Right Arm" },
		LeftArm  = { "Left Arm" },
		RightLeg = { "Right Leg" },
		LeftLeg  = { "Left Leg" },
	},
	R15 = {
		Torso    = { "UpperTorso", "LowerTorso" },
		Head     = { "Head" },
		RightArm = { "RightUpperArm", "RightLowerArm", "RightHand" },
		LeftArm  = { "LeftUpperArm", "LeftLowerArm", "LeftHand" },
		RightLeg = { "RightUpperLeg", "RightLowerLeg", "RightFoot" },
		LeftLeg  = { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot" },
	},
}

function RigAdapter.YToU(sec, y)
	return sec.u0 + (sec.top - y) / sec.length * (sec.u1 - sec.u0)
end

function RigAdapter.UToY(limb, u)
	local secs = limb.sections
	for i, sec in ipairs(secs) do
		if u <= sec.u1 or i == #secs then
			local f = clamp01((u - sec.u0) / math.max(0.0001, sec.u1 - sec.u0))
			return sec, sec.top - f * sec.length
		end
	end
	return secs[1], secs[1].top
end

local function buildLimbDescriptor(char, isR6, limbName, partNames)
	local parts = {}
	local sections = {}
	for _, name in ipairs(partNames) do
		local p = char:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			table.insert(parts, p)
			if isR6 and (limbName == "RightArm" or limbName == "LeftArm" or limbName == "RightLeg" or limbName == "LeftLeg") then
				-- Divide membros R6 em 2 seções virtuais (superior e inferior) para articulação rica
				local h = p.Size.Y
				table.insert(sections, {
					part = p,
					top = h / 2,
					bottom = 0,
					length = h / 2,
					w = p.Size.X,
					d = p.Size.Z,
					index = #sections + 1,
				})
				table.insert(sections, {
					part = p,
					top = 0,
					bottom = -h / 2,
					length = h / 2,
					w = p.Size.X,
					d = p.Size.Z,
					index = #sections + 1,
				})
			else
				local h = p.Size.Y
				table.insert(sections, {
					part = p,
					top = h / 2,
					bottom = -h / 2,
					length = h,
					w = p.Size.X,
					d = p.Size.Z,
					index = #sections + 1,
				})
			end
		end
	end

	if #sections == 0 then
		return nil
	end

	local totalLen = 0
	for _, sec in ipairs(sections) do
		totalLen += sec.length
	end
	local acc = 0
	for _, sec in ipairs(sections) do
		sec.u0 = acc / totalLen
		acc += sec.length
		sec.u1 = acc / totalLen
		sec.fillTop = sec.top
	end

	local s1 = sections[1]
	local hasStump = (limbName ~= "Torso" and limbName ~= "Head")
	local capY = hasStump and (s1.top - math.min(0.18, s1.length * 0.14)) or s1.top
	local capU = hasStump and RigAdapter.YToU(s1, capY) or 0
	s1.fillTop = capY

	local joints = {}
	table.insert(joints, {
		sec = s1,
		y = capY,
		u = capU,
		kind = "root",
		w = s1.w,
		d = s1.d,
	})
	for i = 1, #sections - 1 do
		local a, b = sections[i], sections[i + 1]
		table.insert(joints, {
			sec = a,
			y = a.bottom,
			u = a.u1,
			kind = (i == 1) and "mid" or "tip",
			w = math.min(a.w, b.w),
			d = math.min(a.d, b.d),
		})
	end

	return {
		name = limbName,
		parts = parts,
		sections = sections,
		joints = joints,
		capY = capY,
		capU = capU,
		hasStump = hasStump,
		totalLength = totalLen,
	}
end

function RigAdapter.Read(char)
	if not char or not char.Parent then
		return nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then
		return nil
	end

	local isR6 = (hum.RigType == Enum.HumanoidRigType.R6)
	local map = isR6 and LIMB_PART_NAMES.R6 or LIMB_PART_NAMES.R15
	local limbs = {}
	for limbName, partNames in pairs(map) do
		limbs[limbName] = buildLimbDescriptor(char, isR6, limbName, partNames)
	end
	if not limbs.Torso or not limbs.RightArm or not limbs.RightLeg or not limbs.LeftLeg then
		return nil
	end

	-- Mapeia Motor6D principais para animação procedural sem destruir a hierarquia
	local motors = {}
	local function findMotor(name, parentPart)
		if parentPart then
			local m = parentPart:FindFirstChild(name)
			if m and m:IsA("Motor6D") then
				return m
			end
		end
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("Motor6D") and d.Name == name then
				return d
			end
		end
		return nil
	end

	if isR6 then
		local torso = char:FindFirstChild("Torso")
		motors.Root          = findMotor("RootJoint", root)
		motors.Neck          = findMotor("Neck", torso)
		motors.RightShoulder = findMotor("Right Shoulder", torso)
		motors.LeftShoulder  = findMotor("Left Shoulder", torso)
		motors.RightHip      = findMotor("Right Hip", torso)
		motors.LeftHip       = findMotor("Left Hip", torso)
	else
		motors.Root          = findMotor("Root", char:FindFirstChild("LowerTorso"))
		motors.Waist         = findMotor("Waist", char:FindFirstChild("UpperTorso"))
		motors.Neck          = findMotor("Neck", char:FindFirstChild("Head"))
		motors.RightShoulder = findMotor("RightShoulder", char:FindFirstChild("RightUpperArm"))
		motors.RightElbow    = findMotor("RightElbow", char:FindFirstChild("RightLowerArm"))
		motors.LeftShoulder  = findMotor("LeftShoulder", char:FindFirstChild("LeftUpperArm"))
		motors.LeftElbow     = findMotor("LeftElbow", char:FindFirstChild("LeftLowerArm"))
		motors.RightHip      = findMotor("RightHip", char:FindFirstChild("RightUpperLeg"))
		motors.RightKnee     = findMotor("RightKnee", char:FindFirstChild("RightLowerLeg"))
		motors.LeftHip       = findMotor("LeftHip", char:FindFirstChild("LeftUpperLeg"))
		motors.LeftKnee      = findMotor("LeftKnee", char:FindFirstChild("LeftLowerLeg"))
	end

	local motorOriginals = {}
	for k, m in pairs(motors) do
		if m then
			motorOriginals[k] = {
				motor = m,
				C0 = m.C0,
				C1 = m.C1,
			}
		end
	end

	-- Captura estado original de todas as BaseParts, Decals e Acessórios do personagem
	local partOriginals = {}
	local limbPartLookup = {}
	for limbName, limb in pairs(limbs) do
		limbPartLookup[limbName] = {}
		for _, p in ipairs(limb.parts) do
			limbPartLookup[limbName][p] = true
		end
	end

	local function registerVisual(inst, limbTag)
		if not partOriginals[inst] then
			partOriginals[inst] = {
				Transparency = inst.Transparency,
				CanCollide = inst:IsA("BasePart") and inst.CanCollide or nil,
				limbs = {},
			}
		end
		if limbTag then
			partOriginals[inst].limbs[limbTag] = true
		end
	end

	for limbName, set in pairs(limbPartLookup) do
		for p in pairs(set) do
			registerVisual(p, limbName)
			for _, d in ipairs(p:GetDescendants()) do
				if d:IsA("Decal") or d:IsA("Texture") then
					registerVisual(d, limbName)
				end
			end
		end
	end

	-- Associa acessórios (chapéus, cabelos, ombreiras, etc.) ao membro ao qual estão soldados
	for _, child in ipairs(char:GetChildren()) do
		if child:IsA("Accoutrement") then
			local handle = child:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				local attachedLimb = "Head"
				for _, j in ipairs(handle:GetChildren()) do
					if j:IsA("JointInstance") or j:IsA("WeldConstraint") then
						local p0, p1 = j.Part0, j.Part1
						for lName, set in pairs(limbPartLookup) do
							if (p0 and set[p0]) or (p1 and set[p1]) then
								attachedLimb = lName
								break
							end
						end
					end
				end
				registerVisual(handle, attachedLimb)
				for _, d in ipairs(handle:GetDescendants()) do
					if d:IsA("Decal") or d:IsA("Texture") or d:IsA("BasePart") then
						registerVisual(d, attachedLimb)
					end
				end
			end
		end
	end

	return {
		character = char,
		humanoid = hum,
		root = root,
		isR6 = isR6,
		limbs = limbs,
		motors = motors,
		motorOriginals = motorOriginals,
		partOriginals = partOriginals,
		origWalkSpeed = hum.WalkSpeed > 0 and hum.WalkSpeed or 16,
		origJumpPower = hum.JumpPower > 0 and hum.JumpPower or 50,
		origJumpHeight = hum.JumpHeight > 0 and hum.JumpHeight or 7.2,
		origAutoRotate = hum.AutoRotate,
	}
end

-- Define a visibilidade de um membro específico (hidden: 0 = visível original, 1 = totalmente oculto)
function RigAdapter.SetLimbHidden(rig, limbName, hidden)
	hidden = clamp01(hidden)
	for inst, data in pairs(rig.partOriginals) do
		if inst.Parent and data.limbs[limbName] then
			local target = data.Transparency + (1 - data.Transparency) * hidden
			if math.abs(inst.Transparency - target) > 0.002 then
				inst.Transparency = target
			end
		end
	end
end

function RigAdapter.SetAllHidden(rig, hidden)
	for limbName in pairs(rig.limbs) do
		RigAdapter.SetLimbHidden(rig, limbName, hidden)
	end
end

-- Aplica offsets de pose procedural sobre os Motor6D preservando C0 original
function RigAdapter.ApplyPose(rig, offsets, alpha)
	alpha = clamp01(alpha or 1)
	for key, data in pairs(rig.motorOriginals) do
		local m = data.motor
		if m and m.Parent then
			local targetOffset = (offsets and offsets[key]) or CFrame.identity
			if rig.isR6 and key == "Root" then
				-- Em R6, RootJoint tem rotação base (-90°, 0, 180°); aplicamos o offset no espaço do mundo da raiz
				m.C0 = m.C0:Lerp(data.C0 * targetOffset, alpha)
			else
				m.C0 = m.C0:Lerp(data.C0 * targetOffset, alpha)
			end
		end
	end
end

-- Converte ângulos anatômicos universais (em radianos) para R6 ou R15 automaticamente
function RigAdapter.MakeUniversalPose(rig, poseSpec)
	local out = {}
	if rig.isR6 then
		-- No R6: RootJoint tem X apontando para a lateral, Y para trás e Z para cima
		if poseSpec.rootPos or poseSpec.rootPitch or poseSpec.rootRoll or poseSpec.rootYaw then
			local pos = poseSpec.rootPos or Vector3.zero
			local pitch = poseSpec.rootPitch or 0
			local roll = poseSpec.rootRoll or 0
			local yaw = poseSpec.rootYaw or 0
			out.Root = CFrame.new(pos.X, -pos.Z, pos.Y) * CFrame.Angles(-pitch, roll, -yaw)
		end
		if poseSpec.neckPitch or poseSpec.neckYaw then
			out.Neck = CFrame.Angles(-(poseSpec.neckPitch or 0), 0, -(poseSpec.neckYaw or 0))
		end
		if poseSpec.rArmPitch or poseSpec.rArmSpread then
			out.RightShoulder = CFrame.Angles(poseSpec.rArmSpread or 0, 0, poseSpec.rArmPitch or 0)
		end
		if poseSpec.lArmPitch or poseSpec.lArmSpread then
			out.LeftShoulder = CFrame.Angles(-(poseSpec.lArmSpread or 0), 0, -(poseSpec.lArmPitch or 0))
		end
		if poseSpec.rLegPitch or poseSpec.rLegSpread then
			out.RightHip = CFrame.Angles(poseSpec.rLegSpread or 0, 0, poseSpec.rLegPitch or 0)
		end
		if poseSpec.lLegPitch or poseSpec.lLegSpread then
			out.LeftHip = CFrame.Angles(-(poseSpec.lLegSpread or 0), 0, -(poseSpec.lLegPitch or 0))
		end
	else
		-- No R15: Eixos padrões (+X = pitch frontal, +Z = abertura lateral, +Y = yaw)
		if poseSpec.rootPos or poseSpec.rootPitch or poseSpec.rootRoll or poseSpec.rootYaw then
			local pos = poseSpec.rootPos or Vector3.zero
			out.Root = CFrame.new(pos) * CFrame.Angles(poseSpec.rootPitch or 0, poseSpec.rootYaw or 0, poseSpec.rootRoll or 0)
		end
		if poseSpec.waistPitch then
			out.Waist = CFrame.Angles(poseSpec.waistPitch, 0, 0)
		end
		if poseSpec.neckPitch or poseSpec.neckYaw then
			out.Neck = CFrame.Angles(poseSpec.neckPitch or 0, poseSpec.neckYaw or 0, 0)
		end
		if poseSpec.rArmPitch or poseSpec.rArmSpread then
			out.RightShoulder = CFrame.Angles(poseSpec.rArmPitch or 0, 0, poseSpec.rArmSpread or 0)
		end
		if poseSpec.rElbow then
			out.RightElbow = CFrame.Angles(poseSpec.rElbow, 0, 0)
		end
		if poseSpec.lArmPitch or poseSpec.lArmSpread then
			out.LeftShoulder = CFrame.Angles(poseSpec.lArmPitch or 0, 0, -(poseSpec.lArmSpread or 0))
		end
		if poseSpec.lElbow then
			out.LeftElbow = CFrame.Angles(poseSpec.lElbow, 0, 0)
		end
		if poseSpec.rLegPitch or poseSpec.rLegSpread then
			out.RightHip = CFrame.Angles(poseSpec.rLegPitch or 0, 0, poseSpec.rLegSpread or 0)
		end
		if poseSpec.rKnee then
			out.RightKnee = CFrame.Angles(poseSpec.rKnee, 0, 0)
		end
		if poseSpec.lLegPitch or poseSpec.lLegSpread then
			out.LeftHip = CFrame.Angles(poseSpec.lLegPitch or 0, 0, -(poseSpec.lLegSpread or 0))
		end
		if poseSpec.lKnee then
			out.LeftKnee = CFrame.Angles(poseSpec.lKnee, 0, 0)
		end
	end
	return out
end

function RigAdapter.RestoreAll(rig)
	if not rig then
		return
	end
	for inst, data in pairs(rig.partOriginals) do
		if inst and inst.Parent then
			inst.Transparency = data.Transparency
			if data.CanCollide ~= nil and inst:IsA("BasePart") then
				inst.CanCollide = data.CanCollide
			end
		end
	end
	for _, data in pairs(rig.motorOriginals) do
		if data.motor and data.motor.Parent then
			data.motor.C0 = data.C0
			data.motor.C1 = data.C1
		end
	end
	if rig.humanoid and rig.humanoid.Parent then
		rig.humanoid.WalkSpeed = rig.origWalkSpeed
		rig.humanoid.JumpPower = rig.origJumpPower
		rig.humanoid.JumpHeight = rig.origJumpHeight
		rig.humanoid.AutoRotate = rig.origAutoRotate
		rig.humanoid.PlatformStand = false
	end
	if rig.root and rig.root.Parent then
		rig.root.Anchored = false
	end
end

--------------------------------------------------------------------------------
-- MOTOR DE RECONSTRUÇÃO CORPORAL MULTICAPA (Generalizado para Qualquer Membro)
--------------------------------------------------------------------------------
local LimbBuilder = {}

local SKIN_FACES = {
	{ n = Vector3.new(0, 0, -1), axis = "z", order = 0 },
	{ n = Vector3.new(1, 0, 0),  axis = "x", order = 1 },
	{ n = Vector3.new(0, 0, 1),  axis = "z", order = 2 },
	{ n = Vector3.new(-1, 0, 0), axis = "x", order = 3 },
}

local MUSCLE_LAYOUT = {
	{ posA = Vector2.new(0.20, 0),    posB = Vector2.new(0.31, 0),    sizeA = Vector2.new(0.18, 0.48), sizeB = Vector2.new(0.31, 0.82), len = 0.96 },
	{ posA = Vector2.new(0, 0.20),    posB = Vector2.new(0, 0.31),    sizeA = Vector2.new(0.48, 0.18), sizeB = Vector2.new(0.82, 0.31), len = 0.98 },
	{ posA = Vector2.new(-0.20, 0),   posB = Vector2.new(-0.31, 0),   sizeA = Vector2.new(0.18, 0.48), sizeB = Vector2.new(0.31, 0.82), len = 0.94 },
	{ posA = Vector2.new(0, -0.20),   posB = Vector2.new(0, -0.31),   sizeA = Vector2.new(0.48, 0.18), sizeB = Vector2.new(0.82, 0.31), len = 0.97 },
	{ posA = Vector2.new(0.22, 0.22), posB = Vector2.new(0.33, 0.33), sizeA = Vector2.new(0.14, 0.14), sizeB = Vector2.new(0.27, 0.27), len = 0.89, corner = true },
	{ posA = Vector2.new(-0.22,-0.22),posB = Vector2.new(-0.33,-0.33),sizeA = Vector2.new(0.14, 0.14), sizeB = Vector2.new(0.27, 0.27), len = 0.89, corner = true },
}

-- Constrói a estrutura de camadas procedurais para um membro específico (`limb`)
function LimbBuilder.Create(renderer, limb, quality)
	local unit = {
		limb = limb,
		renderer = renderer,
		stump = nil,
		bones = {},
		boneTip = renderer:Create(C.EnergyHot, Enum.Material.Neon),
		joints = {},
		muscles = {},
		membranes = {},
		skinPlates = {},
		waveBars = {
			renderer:Create(C.EnergyHot, Enum.Material.Neon),
			renderer:Create(C.EnergyHot, Enum.Material.Neon),
			renderer:Create(C.EnergyHot, Enum.Material.Neon),
			renderer:Create(C.EnergyHot, Enum.Material.Neon),
		},
	}

	local s1 = limb.sections[1]
	-- 1. Coto (Stump)
	if limb.hasStump then
		local st = {
			sec = s1,
			remnant = renderer:Create(s1.part.Color),
			cap = renderer:Create(C.Stump),
			marrow = renderer:Create(C.Bone),
			shards = {},
		}
		for i = 1, quality.shards do
			table.insert(st.shards, {
				el = renderer:Create(i % 2 == 0 and C.Joint or C.StumpDeep),
				pos = Vector3.new(rand(-0.28, 0.28) * s1.w, 0, rand(-0.28, 0.28) * s1.d),
				size = Vector3.new(rand(0.08, 0.14) * s1.w, rand(0.05, 0.09), rand(0.08, 0.14) * s1.d),
				rot = CFrame.Angles(rand(-0.5, 0.5), rand(-1, 1), rand(-0.5, 0.5)),
				seed = rand(0, 100),
				lift = rand(0.16, 0.32),
			})
		end
		unit.stump = st
	end

	-- 2. Segmentos Ósseos (Bone)
	for _, sec in ipairs(limb.sections) do
		local margin = math.min(0.05, sec.length * 0.08)
		local top = (sec.index == 1 and limb.hasStump) and (limb.capY - 0.03) or (sec.top - margin)
		local bottom = sec.bottom + margin
		local span = top - bottom
		if span > 0.05 then
			local n = (span >= 0.65) and quality.boneSegs or 1
			local gap = n > 1 and 0.04 or 0
			local segLen = (span - gap * (n - 1)) / n
			local y = top
			for _ = 1, n do
				local segBot = y - segLen
				table.insert(unit.bones, {
					el = renderer:Create(C.Bone),
					cap = renderer:Create(C.Joint),
					sec = sec,
					top = y,
					len = segLen,
					uTop = RigAdapter.YToU(sec, y),
					uBot = RigAdapter.YToU(sec, segBot),
					bw = sec.w * 0.26,
					bd = sec.d * 0.26,
					seed = rand(0, 100),
				})
				y = segBot - gap
			end
		end
	end

	-- 3. Articulações e Ligamentos (Joints)
	local numJ = #limb.joints
	for jIdx, jt in ipairs(limb.joints) do
		local sec = jt.sec
		local jw, jd = jt.w * 0.45, jt.d * 0.45
		local jh = math.min(0.22, sec.length * 0.22)
		local cy = (jt.kind == "root" and limb.hasStump) and (jt.y - jh * 0.5) or jt.y
		local uNorm = (jIdx - 1) / math.max(1, numJ - 1)
		local entry = {
			sec = sec,
			u = jt.u,
			uNorm = uNorm,
			cy = cy,
			jw = jw,
			jd = jd,
			jh = jh,
			pieces = {},
			ligs = {},
		}
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local final = Vector3.new(sx * jw * 0.25, cy, sz * jd * 0.25)
				local dir = Vector3.new(sx, rand(-0.4, 0.7), sz).Unit
				table.insert(entry.pieces, {
					el = renderer:Create(C.Joint),
					final = final,
					start = final + dir * rand(0.9, 1.35),
					ctrl = final + dir * 0.45 + Vector3.new(-dir.Z, 0.22, dir.X) * rand(0.28, 0.55),
					size = Vector3.new(jw * 0.5 - 0.005, jh, jd * 0.5 - 0.005),
					rot = CFrame.Angles(rand(-1.8, 1.8), rand(-1.8, 1.8), rand(-1.8, 1.8)),
					order = #entry.pieces,
				})
			end
		end
		for k = 1, math.min(quality.ligaments, 4) do
			local f = SKIN_FACES[k]
			local len = jh * 2.4
			local pos, size
			if f.axis == "x" then
				pos = Vector3.new(f.n.X * (jw * 0.5 + 0.018), cy, 0)
				size = Vector3.new(0.032, len, jd * 0.42)
			else
				pos = Vector3.new(0, cy, f.n.Z * (jd * 0.5 + 0.018))
				size = Vector3.new(jw * 0.42, len, 0.032)
			end
			table.insert(entry.ligs, {
				el = renderer:Create(C.Ligament),
				pos = pos,
				size = size,
				order = k - 1,
				seed = rand(0, 100),
			})
		end
		table.insert(unit.joints, entry)
	end

	-- 4. Feixes Musculares (Muscles)
	for _, sec in ipairs(limb.sections) do
		local fillTop = sec.fillTop - 0.02
		local len = fillTop - (sec.bottom + 0.02)
		if len > 0.06 then
			for idx, def in ipairs(MUSCLE_LAYOUT) do
				if idx <= quality.muscleBundles then
					local col = C.Muscle:Lerp(C.MuscleDeep, rand(0, 0.45))
					table.insert(unit.muscles, {
						el = renderer:Create(col),
						sec = sec,
						fillTop = fillTop,
						len = len * def.len,
						posA = def.posA,
						posB = def.posB,
						sizeA = def.sizeA,
						sizeB = def.sizeB,
						color = col,
						uMid = (sec.u0 + sec.u1) * 0.5,
						order = (idx - 1) / quality.muscleBundles,
						twist = ((idx + sec.index) % 2 == 0 and 1 or -1) * 0.52,
						seed = rand(0, 100),
					})
				end
			end
		end
	end

	-- 5. Membrana Translúcida (Membrane)
	for _, sec in ipairs(limb.sections) do
		local len = sec.fillTop - sec.bottom
		if len > 0.04 then
			table.insert(unit.membranes, {
				el = renderer:Create(C.Membrane),
				sec = sec,
				fillTop = sec.fillTop,
				len = len,
				u0 = sec.u0,
				seed = rand(0, 100),
			})
		end
	end

	-- 6. Placas de Pele Externa Geométrica (Skin)
	local pad = 0.008
	local function addPlate(sec, n, restPos, fullSize, gapSize, tangent, u, order)
		local up = Vector3.new(0, rand(0.08, 0.38), 0)
		table.insert(unit.skinPlates, {
			el = renderer:Create(sec.part.Color),
			sec = sec,
			n = n,
			restPos = restPos,
			full = fullSize,
			gap = gapSize,
			uMid = clamp01(u),
			order = order,
			start = restPos + n * rand(0.95, 1.45) + tangent * rand(-0.45, 0.45) + up,
			ctrl = restPos + n * 0.38 + tangent * rand(-0.2, 0.2) + up * 0.35,
			rot = CFrame.Angles(rand(-1.1, 1.1), rand(-1.1, 1.1), rand(-1.1, 1.1)),
			drift = n * rand(0.65, 1.15) + tangent * rand(-0.45, 0.45),
			spin = Vector3.new(rand(-3.2, 3.2), rand(-3.2, 3.2), rand(-3.2, 3.2)),
			seed = rand(0, 100),
		})
	end

	for _, sec in ipairs(limb.sections) do
		local thick = math.min(0.065, math.min(sec.w, sec.d) * 0.2)
		local slices = math.clamp(math.floor(sec.length / 0.42), 1, quality.skinSlices)
		local sliceH = sec.length / slices
		for sIdx = 1, slices do
			local yTop = sec.top - (sIdx - 1) * sliceH
			local yBot = yTop - sliceH
			if sec.index == 1 and sIdx == 1 then
				yTop += pad
			end
			if sec.index == #limb.sections and sIdx == slices then
				yBot -= pad
			end
			local hh = yTop - yBot
			local cy = (yTop + yBot) * 0.5
			for _, f in ipairs(SKIN_FACES) do
				if f.axis == "x" then
					local dd = sec.d + 2 * pad
					addPlate(
						sec, f.n,
						Vector3.new(f.n.X * (sec.w / 2 + pad - thick / 2), cy, 0),
						Vector3.new(thick, hh, dd),
						Vector3.new(thick, hh * 0.88, dd * 0.88),
						Vector3.zAxis, RigAdapter.YToU(sec, cy), f.order
					)
				else
					local wz = sec.w + 2 * pad - 2 * thick
					addPlate(
						sec, f.n,
						Vector3.new(0, cy, f.n.Z * (sec.d / 2 + pad - thick / 2)),
						Vector3.new(wz, hh, thick),
						Vector3.new(wz * 0.88, hh * 0.88, thick),
						Vector3.xAxis, RigAdapter.YToU(sec, cy), f.order
					)
				end
			end
		end
	end

	-- Tampas superior e inferior do membro
	local sLast = limb.sections[#limb.sections]
	local tTop = math.min(0.065, math.min(s1.w, s1.d) * 0.2)
	local capTop = Vector3.new(s1.w + 2 * pad - 2 * tTop, tTop, s1.d + 2 * pad - 2 * tTop)
	addPlate(s1, Vector3.yAxis, Vector3.new(0, s1.top + pad - tTop / 2, 0), capTop, capTop * 0.88, Vector3.xAxis, 0, 0)

	local tBot = math.min(0.065, math.min(sLast.w, sLast.d) * 0.2)
	local capBot = Vector3.new(sLast.w + 2 * pad - 2 * tBot, tBot, sLast.d + 2 * pad - 2 * tBot)
	addPlate(sLast, -Vector3.yAxis, Vector3.new(0, sLast.bottom - pad + tBot / 2, 0), capBot, capBot * 0.88, Vector3.xAxis, 1, 1)

	return unit
end

function LimbBuilder.HideAll(unit)
	local R = unit.renderer
	if unit.stump then
		R:Hide(unit.stump.remnant)
		R:Hide(unit.stump.cap)
		R:Hide(unit.stump.marrow)
		for _, sh in ipairs(unit.stump.shards) do
			R:Hide(sh.el)
		end
	end
	for _, b in ipairs(unit.bones) do
		R:Hide(b.el)
		R:Hide(b.cap)
	end
	R:Hide(unit.boneTip)
	for _, jt in ipairs(unit.joints) do
		for _, pc in ipairs(jt.pieces) do
			R:Hide(pc.el)
		end
		for _, lg in ipairs(jt.ligs) do
			R:Hide(lg.el)
		end
	end
	for _, m in ipairs(unit.muscles) do
		R:Hide(m.el)
	end
	for _, mb in ipairs(unit.membranes) do
		R:Hide(mb.el)
	end
	for _, sp in ipairs(unit.skinPlates) do
		R:Hide(sp.el)
	end
	for _, wb in ipairs(unit.waveBars) do
		R:Hide(wb)
	end
end

-- Renderiza apenas o coto exposto (usado quando um membro foi arrancado e aguarda regeneração)
function LimbBuilder.UpdateStumpOnly(unit, clock, heatBoost)
	LimbBuilder.HideAll(unit)
	local st = unit.stump
	if not st then
		return
	end
	local R = unit.renderer
	local sec = st.sec
	local base = sec.part.CFrame
	local capY = unit.limb.capY
	local beat = heartPulse(clock)
	local heat = clamp01(0.25 + 0.2 * beat + (heatBoost or 0))

	local remH = sec.top - capY
	if remH > 0.01 then
		R:Draw(st.remnant, base * CFrame.new(0, capY + remH / 2, 0), Vector3.new(sec.w + 0.002, remH, sec.d + 0.002), 0, sec.part.Color)
	end
	R:Draw(
		st.cap,
		base * CFrame.new(0, capY - 0.022, 0),
		Vector3.new(sec.w * 0.9, 0.048, sec.d * 0.9),
		0,
		C.StumpDeep:Lerp(C.Stump, 0.65):Lerp(C.Energy, heat * 0.5)
	)
	local mk = 1 + 0.08 * beat
	R:Draw(
		st.marrow,
		base * CFrame.new(0, capY - 0.05, 0),
		Vector3.new(sec.w * 0.26 * mk, 0.04, sec.d * 0.26 * mk),
		0,
		C.Bone:Lerp(C.BoneHot, heat * 0.6)
	)
end

-- Renderiza desintegração progressiva (progress: 0 = intacto, 1 = completamente desintegrado)
function LimbBuilder.UpdateDisintegration(unit, progress, clock, targetWorldPos)
	local R = unit.renderer
	progress = clamp01(progress)
	if unit.stump then
		R:Hide(unit.stump.remnant)
		R:Hide(unit.stump.cap)
		R:Hide(unit.stump.marrow)
		for _, sh in ipairs(unit.stump.shards) do
			R:Hide(sh.el)
		end
	end
	for _, b in ipairs(unit.bones) do
		R:Hide(b.el)
		R:Hide(b.cap)
	end
	R:Hide(unit.boneTip)
	for _, jt in ipairs(unit.joints) do
		for _, pc in ipairs(jt.pieces) do
			R:Hide(pc.el)
		end
		for _, lg in ipairs(jt.ligs) do
			R:Hide(lg.el)
		end
	end
	for _, m in ipairs(unit.muscles) do
		R:Hide(m.el)
	end

	-- Membrana interna encolhendo
	local front = lerp(-0.15, 1.2, inOutSine(progress))
	for _, mb in ipairs(unit.membranes) do
		local sec = mb.sec
		local localP = inv(sec.u0, sec.u1, front)
		if localP >= 0.99 then
			R:Hide(mb.el)
		else
			local remLen = mb.len * (1 - localP)
			local yCenter = sec.bottom + remLen * 0.5
			R:Draw(
				mb.el,
				sec.part.CFrame * CFrame.new(0, yCenter, 0),
				Vector3.new(sec.w * 0.9, remLen, sec.d * 0.9),
				0.15,
				C.MuscleDeep:Lerp(C.Energy, localP)
			)
		end
	end

	-- Placas externas se soltando e fluindo em direção à poça (targetWorldPos)
	for _, sp in ipairs(unit.skinPlates) do
		local e = inv(sp.uMid * 0.55, sp.uMid * 0.55 + 0.45, progress)
		if e >= 0.995 then
			R:Hide(sp.el)
		else
			local d = outCubic(e)
			local baseCF = sp.sec.part.CFrame
			local startWorld = (baseCF * CFrame.new(sp.restPos)).Position
			local worldPos
			if targetWorldPos then
				local midWorld = startWorld + (baseCF:VectorToWorldSpace(sp.drift)) * 1.1 + Vector3.new(0, 0.5, 0)
				worldPos = bezier(startWorld, midWorld, targetWorldPos, d)
			else
				worldPos = (baseCF * CFrame.new(sp.restPos + sp.drift * d - Vector3.new(0, 0.6 * d * d, 0))).Position
			end
			local rot = baseCF.Rotation * CFrame.Angles(sp.spin.X * d, sp.spin.Y * d, sp.spin.Z * d)
			local col = sp.sec.part.Color:Lerp(C.MuscleHot, smooth(0, 0.35, e)):Lerp(C.DropletHot, d * 0.85)
			R:Draw(
				sp.el,
				CFrame.new(worldPos) * rot,
				sp.full * (1 - 0.62 * d),
				smooth(0.55, 1, e),
				col
			)
		end
	end
end

--[[
	Atualiza a reconstrução completa de um membro em função do progresso `p` (0..1)
	ou de janelas customizadas `w` = { bone={a,b}, joints={a,b}, muscle={a,b}, membrane={a,b}, skin={a,b} }.
]]
function LimbBuilder.UpdateReconstruction(unit, p, clock, windows)
	local R = unit.renderer
	p = clamp01(p)
	if p <= 0.001 then
		if unit.limb.hasStump then
			LimbBuilder.UpdateStumpOnly(unit, clock, 0.3)
		else
			LimbBuilder.HideAll(unit)
		end
		return
	end

	local w = windows or {
		stump    = { 0.00, 0.16 },
		bone     = { 0.08, 0.38 },
		joints   = { 0.26, 0.50 },
		muscle   = { 0.38, 0.68 },
		volume   = { 0.52, 0.76 },
		membrane = { 0.64, 0.82 },
		skin     = { 0.72, 0.94 },
		seal     = { 0.88, 1.00 },
	}

	local pStump    = inv(w.stump[1],    w.stump[2],    p)
	local pBone     = inv(w.bone[1],     w.bone[2],     p)
	local pJoints   = inv(w.joints[1],   w.joints[2],   p)
	local pMuscle   = inv(w.muscle[1],   w.muscle[2],   p)
	local pVolume   = inv(w.volume[1],   w.volume[2],   p)
	local pMembrane = inv(w.membrane[1], w.membrane[2], p)
	local pSkin     = inv(w.skin[1],     w.skin[2],     p)
	local pSeal     = inv(w.seal[1],     w.seal[2],     p)

	local seal = inOutSine(pSeal)
	local hideInternals = (seal >= 0.92)
	local beat = heartPulse(clock)

	-- 1. Coto e Estilhaços
	if unit.stump then
		local st = unit.stump
		if hideInternals then
			R:Hide(st.remnant)
			R:Hide(st.cap)
			R:Hide(st.marrow)
			for _, sh in ipairs(st.shards) do
				R:Hide(sh.el)
			end
		else
			local sec = st.sec
			local base = sec.part.CFrame
			local capY = unit.limb.capY
			local heat = clamp01((0.3 + 0.6 * bell(pStump)) * (1 - 0.6 * pBone) + 0.2 * beat)
			local remH = sec.top - capY
			if remH > 0.01 then
				R:Draw(st.remnant, base * CFrame.new(0, capY + remH / 2, 0), Vector3.new(sec.w + 0.002, remH, sec.d + 0.002), 0, sec.part.Color)
			end
			R:Draw(
				st.cap,
				base * CFrame.new(0, capY - 0.022, 0),
				Vector3.new(sec.w * 0.9, 0.048, sec.d * 0.9),
				smooth(0.3, 0.8, pMembrane),
				C.StumpDeep:Lerp(C.Stump, 0.6):Lerp(C.Energy, heat * 0.5)
			)
			local mk = 1 + 0.35 * bell(pStump)
			R:Draw(
				st.marrow,
				base * CFrame.new(0, capY - 0.05, 0),
				Vector3.new(sec.w * 0.26 * mk, 0.04, sec.d * 0.26 * mk),
				smooth(0.2, 0.6, pJoints),
				C.Bone:Lerp(C.BoneHot, heat)
			)
			local lift = smooth(0, 0.7, pStump)
			local absorb = smooth(0, 0.45, pBone)
			for _, sh in ipairs(st.shards) do
				if absorb >= 0.96 then
					R:Hide(sh.el)
				else
					local rest = Vector3.new(sh.pos.X, capY - 0.06, sh.pos.Z)
					local lifted = rest + Vector3.new(0, -sh.lift * lift, 0)
					local pos = lifted:Lerp(Vector3.new(0, capY - 0.12, 0), outCubic(absorb))
					R:Draw(
						sh.el,
						base * CFrame.new(pos) * sh.rot,
						sh.size * (1 - 0.8 * absorb),
						absorb,
						C.Joint:Lerp(C.BoneHot, math.max(absorb, lift * 0.4))
					)
				end
			end
		end
	end

	-- 2. Extrusão Óssea
	if hideInternals or pBone <= 0 then
		for _, sg in ipairs(unit.bones) do
			R:Hide(sg.el)
			R:Hide(sg.cap)
		end
		R:Hide(unit.boneTip)
	else
		local front = lerp(unit.limb.capU, 1, inOutSine(pBone))
		for _, sg in ipairs(unit.bones) do
			local g = inv(sg.uTop, sg.uBot, front)
			if g <= 0 then
				R:Hide(sg.el)
				R:Hide(sg.cap)
			else
				local base = sg.sec.part.CFrame
				local curL = math.max(0.02, sg.len * g)
				local wob = (1 - g) * 0.09
				local ax = noise(clock * 1.8, sg.seed) * wob
				local az = noise(clock * 1.8, sg.seed + 5.7) * wob
				local thick = 0.45 + 0.55 * smooth(0, 0.45, g)
				local cf = base * CFrame.new(0, sg.top, 0) * CFrame.Angles(ax, 0, az) * CFrame.new(0, -curL / 2, 0)
				R:Draw(
					sg.el,
					cf,
					Vector3.new(sg.bw * thick, curL, sg.bd * thick),
					0.35 * (1 - smooth(0, 0.35, g)),
					C.BoneHot:Lerp(C.Bone, smooth(0.2, 1, g))
				)
				local c = inv(0.85, 1, g)
				if c > 0 then
					local k = spring(c)
					R:Draw(
						sg.cap,
						base * CFrame.new(0, sg.top - sg.len + 0.032, 0),
						Vector3.new(sg.bw * 1.42 * k, 0.068, sg.bd * 1.42 * k),
						1 - smooth(0, 0.35, c),
						C.BoneHot:Lerp(C.Joint, c)
					)
				else
					R:Hide(sg.cap)
				end
			end
		end
		if pBone < 1 then
			local sec, y = RigAdapter.UToY(unit.limb, front)
			local pulse = 1 + 0.2 * math.sin(clock * 16)
			R:Draw(
				unit.boneTip,
				sec.part.CFrame * CFrame.new(0, y - 0.02, 0),
				Vector3.new(sec.w * 0.3 * pulse, 0.038, sec.d * 0.3 * pulse),
				0.2,
				C.EnergyHot
			)
		else
			R:Hide(unit.boneTip)
		end
	end

	-- 3. Articulações e Ligamentos
	for _, jt in ipairs(unit.joints) do
		if hideInternals or pJoints <= 0 then
			for _, pc in ipairs(jt.pieces) do
				R:Hide(pc.el)
			end
			for _, lg in ipairs(jt.ligs) do
				R:Hide(lg.el)
			end
		else
			local base = jt.sec.part.CFrame
			local startLocal = jt.uNorm * 0.45
			for _, pc in ipairs(jt.pieces) do
				local g = inv(startLocal + pc.order * 0.05, startLocal + pc.order * 0.05 + 0.35, pJoints)
				if g <= 0 then
					R:Hide(pc.el)
				else
					local a = outCubic(g)
					local pos = bezier(pc.start, pc.ctrl, pc.final, a)
					local rot = pc.rot:Lerp(CFrame.identity, a)
					local col = C.EnergyHot:Lerp(C.Joint, smooth(0.4, 1, g))
					R:Draw(pc.el, base * CFrame.new(pos) * rot, pc.size * (0.4 + 0.6 * a), 1 - smooth(0, 0.3, g), col)
				end
			end
			for _, lg in ipairs(jt.ligs) do
				local g = inv(startLocal + 0.32 + lg.order * 0.06, startLocal + 0.68 + lg.order * 0.06, pJoints)
				if g <= 0 then
					R:Hide(lg.el)
				else
					local k = spring(g)
					R:Draw(
						lg.el,
						base * CFrame.new(lg.pos),
						Vector3.new(lg.size.X, lg.size.Y * k, lg.size.Z),
						1 - smooth(0, 0.25, g),
						C.EnergyHot:Lerp(C.Ligament, smooth(0.2, 1, g))
					)
				end
			end
		end
	end

	-- 4. Feixes Musculares e Onda de Contração
	if hideInternals or pMuscle <= 0 then
		for _, m in ipairs(unit.muscles) do
			R:Hide(m.el)
		end
	else
		local vol = inOutSine(pVolume)
		local envVol = bell(pVolume)
		local waveU = (clock * 0.65) % 1.4 - 0.2
		for _, m in ipairs(unit.muscles) do
			local startM = 0.42 * m.sec.u0 + 0.22 * m.order
			local g = inv(startM, startM + 0.45, pMuscle)
			if g <= 0 then
				R:Hide(m.el)
			else
				local sec = m.sec
				local grow = outCubic(g)
				local radial = lerp(0.35, 1, spring(g))
				local thick = lerp(0.32, 1, spring(inv(0.1, 1, g)))
				local pos2 = m.posA:Lerp(m.posB, vol) * radial
				local size2 = m.sizeA:Lerp(m.sizeB, vol) * thick

				local dz = (m.uMid - waveU) / 0.16
				local bulge = (0.04 * bell(g) + 0.12 * envVol) * math.exp(-dz * dz)
				local sxz = 1 + bulge
				local curL = math.max(0.02, m.len * grow * (1 - bulge * 0.28))
				local twist = (1 - grow) * m.twist

				local cf = sec.part.CFrame
					* CFrame.new(0, m.fillTop - curL / 2, 0)
					* CFrame.Angles(0, twist, 0)
					* CFrame.new(pos2.X * sec.w, 0, pos2.Y * sec.d)

				local col = C.MuscleHot:Lerp(m.color, smooth(0.15, 0.85, g)):Lerp(C.MuscleHot, math.min(1, bulge * 3.5))
				R:Draw(m.el, cf, Vector3.new(size2.X * sec.w * sxz, curL, size2.Y * sec.d * sxz), 1 - smooth(0, 0.3, g), col)
			end
		end
	end

	-- 5. Membrana Translúcida
	if hideInternals or pMembrane <= 0 then
		for _, mb in ipairs(unit.membranes) do
			R:Hide(mb.el)
		end
	else
		for _, mb in ipairs(unit.membranes) do
			local startMb = 0.45 * mb.u0
			local g = inv(startMb, startMb + 0.55, pMembrane)
			if g <= 0 then
				R:Hide(mb.el)
			else
				local sec = mb.sec
				local grow = outCubic(g)
				local xz = lerp(0.78, 1, spring(g))
				local curL = math.max(0.02, mb.len * grow)
				local alpha = lerp(1, 0.42, smooth(0, 0.35, g)) - 0.22 * pSkin
				R:Draw(
					mb.el,
					sec.part.CFrame * CFrame.new(0, mb.fillTop - curL / 2, 0),
					Vector3.new(sec.w * 0.95 * xz, curL, sec.d * 0.95 * xz),
					alpha,
					C.Membrane:Lerp(C.MuscleHot, 0.55 * (1 - smooth(0, 0.7, g)))
				)
			end
		end
	end

	-- 6. Placas de Pele Externa (Skin)
	if pSkin <= 0 then
		for _, sp in ipairs(unit.skinPlates) do
			R:Hide(sp.el)
		end
	else
		local fadeOut = smooth(0.55, 0.98, pSeal)
		local breathe = 0.018 * bell(seal)
		for _, sp in ipairs(unit.skinPlates) do
			local startS = 0.52 * sp.uMid + 0.04 * sp.order
			local g = inv(startS, startS + 0.36, pSkin)
			if g <= 0 then
				R:Hide(sp.el)
			else
				local skinCol = sp.sec.part.Color
				local a = outBack(g, 1.15)
				local pos = bezier(sp.start, sp.ctrl, sp.restPos, a) + sp.n * breathe
				local rot = sp.rot:Lerp(CFrame.identity, outCubic(g))
				local size = sp.gap:Lerp(sp.full, seal) * (0.3 + 0.7 * outCubic(g))
				local cure = smooth(startS + 0.18, math.min(1, startS + 0.55), pSkin)
				local col = C.EnergyHot:Lerp(C.MuscleHot, smooth(0, 0.8, g)):Lerp(skinCol, cure)
				local vis = smooth(0, 0.35, g)
				local alpha = math.max(1 - vis * (0.75 + 0.25 * cure), fadeOut)
				R:Draw(sp.el, sp.sec.part.CFrame * CFrame.new(pos) * rot, size, alpha, col)
			end
		end
	end

	-- Anel de Onda Luminosa percorrendo o membro durante a selagem
	local waveProg = (p * 2.2) % 1
	local waveStrength = bell(pBone) * 0.65 + bell(pMuscle) * 0.55 + bell(pSeal) * 0.9
	if waveStrength > 0.08 and p < 0.98 then
		local wsec, wy = RigAdapter.UToY(unit.limb, waveProg)
		local hx = wsec.w * 0.53
		local hz = wsec.d * 0.53
		local th = 0.028 * (1 + 0.5 * bell(waveProg))
		local alpha = 1 - clamp01(waveStrength) * bell(waveProg) * 0.78
		local col = C.EnergyHot:Lerp(C.Energy, waveProg)
		local base = wsec.part.CFrame
		local bars = unit.waveBars
		R:Draw(bars[1], base * CFrame.new(hx, wy, 0),  Vector3.new(th, th, hz * 2 + th), alpha, col)
		R:Draw(bars[2], base * CFrame.new(-hx, wy, 0), Vector3.new(th, th, hz * 2 + th), alpha, col)
		R:Draw(bars[3], base * CFrame.new(0, wy, hz),  Vector3.new(hx * 2 - th, th, th), alpha, col)
		R:Draw(bars[4], base * CFrame.new(0, wy, -hz), Vector3.new(hx * 2 - th, th, th), alpha, col)
	else
		for _, wb in ipairs(unit.waveBars) do
			R:Hide(wb)
		end
	end
end

--------------------------------------------------------------------------------
-- PARTÍCULAS E PORTADORES DE EFEITOS LOCALIZADOS
--------------------------------------------------------------------------------
local function createNumSeq(points)
	local kps = {}
	for _, pt in ipairs(points) do
		table.insert(kps, NumberSequenceKeypoint.new(pt[1], pt[2]))
	end
	return NumberSequence.new(kps)
end

local function createFXRig(parentFolder)
	local carrier = Instance.new("Part")
	carrier.Name = "FXCarrier"
	carrier.Anchored = true
	carrier.CanCollide = false
	carrier.CanQuery = false
	carrier.CanTouch = false
	carrier.Transparency = 1
	carrier.Size = Vector3.new(0.4, 0.4, 0.4)
	carrier.Parent = parentFolder

	local embers = Instance.new("ParticleEmitter")
	embers.Texture = TEX_SPARK
	embers.Color = ColorSequence.new(C.EnergyHot, C.Energy)
	embers.LightEmission = 0.75
	embers.LightInfluence = 0
	embers.Size = createNumSeq({ { 0, 0.04 }, { 0.35, 0.11 }, { 1, 0 } })
	embers.Transparency = createNumSeq({ { 0, 0.8 }, { 0.15, 0.15 }, { 1, 1 } })
	embers.Lifetime = NumberRange.new(0.45, 1.0)
	embers.Speed = NumberRange.new(1.2, 4.5)
	embers.SpreadAngle = Vector2.new(180, 180)
	embers.Drag = 3.5
	embers.Acceleration = Vector3.new(0, 1.5, 0)
	embers.Rate = 0
	embers.Parent = carrier

	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = TEX_SMOKE
	smoke.Color = ColorSequence.new(C.Smoke, C.SmokeDark)
	smoke.LightInfluence = 0.65
	smoke.Size = createNumSeq({ { 0, 0.35 }, { 1, 1.45 } })
	smoke.Transparency = createNumSeq({ { 0, 1 }, { 0.25, 0.72 }, { 1, 1 } })
	smoke.Lifetime = NumberRange.new(1.1, 2.0)
	smoke.Speed = NumberRange.new(0.4, 1.6)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Acceleration = Vector3.new(0, 0.8, 0)
	smoke.Drag = 1.5
	smoke.Rate = 0
	smoke.Parent = carrier

	local burst = Instance.new("ParticleEmitter")
	burst.Texture = TEX_SPARK
	burst.Color = ColorSequence.new(Color3.new(1, 1, 1), C.Energy)
	burst.LightEmission = 1
	burst.LightInfluence = 0
	burst.Size = createNumSeq({ { 0, 0.12 }, { 1, 0 } })
	burst.Transparency = createNumSeq({ { 0, 0 }, { 1, 1 } })
	burst.Lifetime = NumberRange.new(0.25, 0.55)
	burst.Speed = NumberRange.new(5, 14)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Drag = 6
	burst.Rate = 0
	burst.Parent = carrier

	local light = Instance.new("PointLight")
	light.Color = C.Energy
	light.Brightness = 0
	light.Range = 7
	light.Shadows = false
	light.Parent = carrier

	return {
		carrier = carrier,
		embers = embers,
		smoke = smoke,
		burst = burst,
		light = light,
		 EmitBurst = function(self, worldPos, count)
			self.carrier.CFrame = CFrame.new(worldPos)
			self.burst:Emit(count or 12)
		end,
		SetActivity = function(self, worldPos, intensity)
			intensity = clamp01(intensity)
			self.carrier.CFrame = CFrame.new(worldPos)
			self.embers.Rate = math.floor(intensity * 18)
			self.smoke.Rate = math.floor(intensity * 6)
			self.light.Brightness = intensity * 1.6
			self.light.Range = 5 + intensity * 5
		end,
	}
end

--------------------------------------------------------------------------------
-- UTILITÁRIOS DE RAYCAST E SEGURANÇA DE TERRENO
--------------------------------------------------------------------------------
local function makeCharRayParams(char)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char, Workspace:FindFirstChild("RegenMovesetFX_Local") }
	params.IgnoreWater = true
	return params
end

local function findGroundBelow(char, origin, maxDist)
	local params = makeCharRayParams(char)
	local hit = Workspace:Raycast(origin + Vector3.new(0, 2.2, 0), Vector3.new(0, -(maxDist or 60), 0), params)
	if hit then
		return hit.Position, hit.Normal, hit.Instance
	end
	return nil, Vector3.yAxis, nil
end

--------------------------------------------------------------------------------
-- HABILIDADE 1: JUMP — SALTO COM REGENERAÇÃO DAS PERNAS
--------------------------------------------------------------------------------
local JumpAbility = {}

local function createDetachedLegAssembly(renderer, limb, sideSign)
	local pieces = {}
	for _, sec in ipairs(limb.sections) do
		table.insert(pieces, {
			el = renderer:Create(sec.part.Color, sec.part.Material),
			offset = sec.part.CFrame:ToObjectSpace(limb.sections[1].part.CFrame):Inverse(),
			size = Vector3.new(sec.w, sec.length, sec.d),
			color = sec.part.Color,
		})
	end
	local s1 = limb.sections[1]
	local stumpCap = renderer:Create(C.Stump, Enum.Material.SmoothPlastic)
	local stumpCore = renderer:Create(C.EnergyHot, Enum.Material.Neon)

	local rootCF = s1.part.CFrame
	return {
		cf = rootCF,
		vel = rootCF.RightVector * (sideSign * rand(4.5, 7.5)) - rootCF.LookVector * rand(6, 10) + Vector3.new(0, rand(6, 10), 0),
		angVel = Vector3.new(rand(-7, -3.5), rand(-3, 3) * sideSign, rand(-4, 4)),
		pieces = pieces,
		stumpCap = stumpCap,
		stumpCore = stumpCore,
		capSize = Vector3.new(s1.w * 0.92, 0.06, s1.d * 0.92),
		coreSize = Vector3.new(s1.w * 0.32, 0.07, s1.d * 0.32),
		topY = s1.top,
		halfH = limb.totalLength * 0.5,
		grounded = false,
	}
end

local function updateDetachedLegAssembly(renderer, char, legObj, dt, fadeOut)
	local alpha = clamp01(fadeOut or 0)
	if alpha >= 0.99 then
		for _, pc in ipairs(legObj.pieces) do
			renderer:Hide(pc.el)
		end
		renderer:Hide(legObj.stumpCap)
		renderer:Hide(legObj.stumpCore)
		return
	end

	if not legObj.grounded then
		legObj.vel += Vector3.new(0, -Workspace.Gravity * 0.85 * dt, 0)
		local nextPos = legObj.cf.Position + legObj.vel * dt
		local gPos, gNorm = findGroundBelow(char, nextPos, 3.2)
		if gPos and (nextPos.Y - gPos.Y) <= 0.55 and legObj.vel.Y < 0 then
			nextPos = Vector3.new(nextPos.X, gPos.Y + 0.42, nextPos.Z)
			if math.abs(legObj.vel.Y) > 6 then
				legObj.vel = Vector3.new(legObj.vel.X * 0.48, -legObj.vel.Y * 0.28, legObj.vel.Z * 0.48)
				legObj.angVel *= 0.55
			else
				legObj.grounded = true
				legObj.vel = Vector3.zero
				-- Alinha a perna caída deitada sobre o solo
				local forward = legObj.cf.LookVector
				local flatFwd = (forward - forward:Dot(gNorm) * gNorm)
				if flatFwd.Magnitude < 0.05 then
					flatFwd = Vector3.zAxis
				else
					flatFwd = flatFwd.Unit
				end
				local right = flatFwd:Cross(gNorm).Unit
				legObj.cf = CFrame.fromMatrix(nextPos, right, flatFwd, -gNorm)
			end
		end
		if not legObj.grounded then
			local rx = legObj.angVel.X * dt
			local ry = legObj.angVel.Y * dt
			local rz = legObj.angVel.Z * dt
			legObj.cf = CFrame.new(nextPos) * legObj.cf.Rotation * CFrame.Angles(rx, ry, rz)
		end
	end

	for _, pc in ipairs(legObj.pieces) do
		renderer:Draw(pc.el, legObj.cf * pc.offset, pc.size, alpha, pc.color)
	end
	renderer:Draw(legObj.stumpCap, legObj.cf * CFrame.new(0, legObj.topY + 0.01, 0), legObj.capSize, alpha, C.Stump)
	renderer:Draw(legObj.stumpCore, legObj.cf * CFrame.new(0, legObj.topY + 0.03, 0), legObj.coreSize, math.max(alpha, 0.25), C.EnergyHot)
end

function JumpAbility.Start(session, onStatus, onProgress, onComplete)
	local rig = session.rig
	local R = session.renderer
	local fx = session.fx
	local cfg = CONFIG.Jump

	local rightLegUnit = LimbBuilder.Create(R, rig.limbs.RightLeg, session.quality)
	local leftLegUnit  = LimbBuilder.Create(R, rig.limbs.LeftLeg, session.quality)

	local detachedRight = nil
	local detachedLeft = nil

	local phase = "Anticipation"
	local phaseClock = 0
	local totalClock = 0
	local detachedTriggered = false
	local landingSpot = nil
	local landingYaw = 0

	-- Calcula a direção horizontal inicial do salto
	local moveDir = rig.humanoid.MoveDirection
	if moveDir.Magnitude < 0.1 then
		local lv = rig.root.CFrame.LookVector
		moveDir = Vector3.new(lv.X, 0, lv.Z)
		if moveDir.Magnitude > 0.01 then
			moveDir = moveDir.Unit
		end
	end

	rig.humanoid.WalkSpeed = 4
	rig.humanoid.JumpPower = 0
	rig.humanoid.JumpHeight = 0
	onStatus("PREPARANDO IMPULSO...", 0.05)

	session.stepFn = function(dt)
		totalClock += dt
		phaseClock += dt

		if phase == "Anticipation" then
			local p = clamp01(phaseClock / cfg.AnticipationTime)
			local crouch = inOutSine(p)
			local pose = RigAdapter.MakeUniversalPose(rig, {
				rootPos = Vector3.new(0, -1.05 * crouch, 0),
				rootPitch = -0.38 * crouch,
				rLegPitch = 0.75 * crouch,
				lLegPitch = 0.75 * crouch,
				rKnee = -1.15 * crouch,
				lKnee = -1.15 * crouch,
				rArmPitch = -0.65 * crouch,
				lArmPitch = -0.65 * crouch,
				rArmSpread = 0.22 * crouch,
				lArmSpread = 0.22 * crouch,
				neckPitch = 0.25 * crouch,
			})
			RigAdapter.ApplyPose(rig, pose, expAlpha(dt, 18))
			fx:SetActivity(rig.root.Position - Vector3.new(0, 1.8, 0), p * 0.75)

			if phaseClock >= cfg.AnticipationTime then
				phase = "Ascending"
				phaseClock = 0
				rig.humanoid.WalkSpeed = 0
				rig.humanoid.AutoRotate = false
				-- Impulso físico forte para cima
				rig.root.AssemblyLinearVelocity = moveDir * cfg.ForwardBoost + Vector3.new(0, cfg.LaunchVelocityY, 0)
				fx:EmitBurst(rig.root.Position - Vector3.new(0, 2.2, 0), 18)
				onStatus("SALTO PROPULSIVO!", 0.15)
			end

		elseif phase == "Ascending" then
			-- Antes do desprendimento: estica o corpo no salto
			if not detachedTriggered and phaseClock < cfg.DetachTime then
				local p = clamp01(phaseClock / cfg.DetachTime)
				local stretch = outCubic(p)
				local pose = RigAdapter.MakeUniversalPose(rig, {
					rootPos = Vector3.new(0, 0.25 * stretch, 0),
					rootPitch = 0.16 * stretch,
					rArmPitch = 2.4 * stretch,
					lArmPitch = 2.4 * stretch,
					rArmSpread = 0.3,
					lArmSpread = 0.3,
					rLegPitch = -0.35 * stretch,
					lLegPitch = -0.35 * stretch,
				})
				RigAdapter.ApplyPose(rig, pose, expAlpha(dt, 20))
			end

			-- Desprendimento das duas pernas durante a subida!
			if not detachedTriggered and phaseClock >= cfg.DetachTime then
				detachedTriggered = true
				RigAdapter.SetLimbHidden(rig, "RightLeg", 1)
				RigAdapter.SetLimbHidden(rig, "LeftLeg", 1)
				detachedRight = createDetachedLegAssembly(R, rig.limbs.RightLeg, 1)
				detachedLeft  = createDetachedLegAssembly(R, rig.limbs.LeftLeg, -1)
				fx:EmitBurst(rig.root.Position - Vector3.new(0, 1.1, 0), 24)
				onStatus("PERNAS DESPRENDIDAS — QUEDA EM DESEQUILÍBRIO", 0.28)
			end

			if detachedTriggered then
				local airT = phaseClock - cfg.DetachTime
				-- Rotação de perda de equilíbrio no ar + braços tentando compensar
				local tumblePitch = -clamp01(airT / 0.85) * 1.42 + math.sin(airT * 9) * 0.08
				local tumbleRoll = math.sin(airT * 6.5) * 0.22
				local armFlailR = 1.6 + math.sin(airT * 14) * 0.55
				local armFlailL = 1.6 + math.cos(airT * 14) * 0.55

				local pose = RigAdapter.MakeUniversalPose(rig, {
					rootPos = Vector3.new(0, 0, 0),
					rootPitch = tumblePitch,
					rootRoll = tumbleRoll,
					rArmPitch = armFlailR,
					lArmPitch = armFlailL,
					rArmSpread = 0.55,
					lArmSpread = 0.55,
					neckPitch = 0.35,
				})
				RigAdapter.ApplyPose(rig, pose, expAlpha(dt, 14))

				LimbBuilder.UpdateStumpOnly(rightLegUnit, totalClock, 0.8)
				LimbBuilder.UpdateStumpOnly(leftLegUnit, totalClock, 0.8)
				updateDetachedLegAssembly(R, rig.character, detachedRight, dt, 0)
				updateDetachedLegAssembly(R, rig.character, detachedLeft, dt, 0)
				fx:SetActivity(rig.root.Position - Vector3.new(0, 0.8, 0), 0.85)

				-- Verifica aterrissagem no solo durante a descida
				local velY = rig.root.AssemblyLinearVelocity.Y
				if phaseClock >= cfg.MinAirTime and velY <= 2 then
					local gPos = findGroundBelow(rig.character, rig.root.Position, 5.2)
					if gPos and (rig.root.Position.Y - gPos.Y) <= 4.2 then
						phase = "ImpactProne"
						phaseClock = 0
						local look = rig.root.CFrame.LookVector
						landingYaw = math.atan2(-look.X, -look.Z)
						landingSpot = Vector3.new(rig.root.Position.X, gPos.Y + 2.85, rig.root.Position.Z)
						rig.root.AssemblyLinearVelocity = Vector3.zero
						rig.root.Anchored = true
						fx:EmitBurst(Vector3.new(landingSpot.X, gPos.Y + 0.2, landingSpot.Z), 26)
						onStatus("IMPACTO NO SOLO — ESTABILIZANDO CORPO", 0.36)
					end
				end
			end

		elseif phase == "ImpactProne" then
			-- Transição de impacto deitado no chão (quique amortecido + postura horizontal)
			local p = clamp01(phaseClock / cfg.ImpactSettleTime)
			local bounce = math.exp(-6 * p) * math.sin(p * PI * 2.5) * 0.35
			if landingSpot then
				rig.root.CFrame = CFrame.new(landingSpot + Vector3.new(0, bounce, 0)) * CFrame.Angles(0, landingYaw, 0)
			end
			-- Deitado de bruços/apoio frontal no chão (rootPos.Y = -2.15 baixa o tronco até tocar o solo)
			local pose = RigAdapter.MakeUniversalPose(rig, {
				rootPos = Vector3.new(0, -2.15, 0),
				rootPitch = -1.48 + 0.12 * bounce,
				rootRoll = 0.06 * math.sin(p * PI),
				rArmPitch = 1.15,
				lArmPitch = 1.15,
				rElbow = 0.85,
				lElbow = 0.85,
				rArmSpread = 0.38,
				lArmSpread = 0.38,
				neckPitch = 0.55,
			})
			RigAdapter.ApplyPose(rig, pose, expAlpha(dt, 16))

			LimbBuilder.UpdateStumpOnly(rightLegUnit, totalClock, 0.65)
			LimbBuilder.UpdateStumpOnly(leftLegUnit, totalClock, 0.65)
			if detachedRight then
				updateDetachedLegAssembly(R, rig.character, detachedRight, dt, 0)
			end
			if detachedLeft then
				updateDetachedLegAssembly(R, rig.character, detachedLeft, dt, 0)
			end

			if phaseClock >= cfg.ImpactSettleTime then
				phase = "RegeneratingLegs"
				phaseClock = 0
				onStatus("RECONSTRUINDO PERNAS (ESTRUTURA → MÚSCULO → PELE)", 0.42)
			end

		elseif phase == "RegeneratingLegs" then
			local p = clamp01(phaseClock / cfg.LegRegenTime)
			local breathe = math.sin(totalClock * 3.2) * 0.04

			-- Permanece deitado no chão com leve movimento respiratório e olhar acompanhando a reconstrução
			local pose = RigAdapter.MakeUniversalPose(rig, {
				rootPos = Vector3.new(0, -2.15 + breathe, 0),
				rootPitch = -1.46 + breathe * 0.5,
				rArmPitch = 1.05,
				lArmPitch = 1.05,
				rElbow = 0.9,
				lElbow = 0.9,
				rArmSpread = 0.35,
				lArmSpread = 0.35,
				rLegPitch = 0.05 * math.sin(totalClock * 5),
				lLegPitch = -0.05 * math.sin(totalClock * 5),
				neckPitch = 0.52,
				neckYaw = math.sin(totalClock * 1.4) * 0.25,
			})
			RigAdapter.ApplyPose(rig, pose, expAlpha(dt, 12))

			-- Reconstrói ambas as pernas progressivamente
			LimbBuilder.UpdateReconstruction(rightLegUnit, p, totalClock)
			LimbBuilder.UpdateReconstruction(leftLegUnit, math.max(0, p - 0.03) / 0.97, totalClock + 0.4)

			-- Desvanece as pernas antigas caídas no chão enquanto as novas se completam
			local oldFade = smooth(0.25, 0.85, p)
			if detachedRight then
				updateDetachedLegAssembly(R, rig.character, detachedRight, dt, oldFade)
			end
			if detachedLeft then
				updateDetachedLegAssembly(R, rig.character, detachedLeft, dt, oldFade)
			end

			-- Revela suavemente as pernas reais do avatar na etapa final de selagem (sem pop)
			local reveal = smooth(0.88, 0.99, p)
			if reveal > 0 then
				RigAdapter.SetLimbHidden(rig, "RightLeg", 1 - reveal)
				RigAdapter.SetLimbHidden(rig, "LeftLeg", 1 - reveal)
			end

			-- Foco de partículas acompanha a frente de crescimento das pernas
			local focusSec, focusY = RigAdapter.UToY(rig.limbs.RightLeg, clamp01(p * 1.15))
			local focusWorld = (focusSec.part.CFrame * CFrame.new(0, focusY, 0)).Position
			fx:SetActivity(focusWorld, 0.85 * (1 - smooth(0.9, 1, p)))

			-- Atualiza texto da sub-etapa anatômica
			local subStage = "ESTRUTURA ÓSSEA INTERNA"
			if p >= 0.72 then
				subStage = "CAMADA EXTERNA E SELAGEM"
			elseif p >= 0.40 then
				subStage = "VOLUMES MUSCULARES E CONTRAÇÃO"
			elseif p >= 0.26 then
				subStage = "ARTICULAÇÕES E LIGAMENTOS"
			end
			onStatus("REGENERANDO PERNAS · " .. subStage, 0.42 + p * 0.44)

			if phaseClock >= cfg.LegRegenTime then
				RigAdapter.SetLimbHidden(rig, "RightLeg", 0)
				RigAdapter.SetLimbHidden(rig, "LeftLeg", 0)
				LimbBuilder.HideAll(rightLegUnit)
				LimbBuilder.HideAll(leftLegUnit)
				if detachedRight then
					updateDetachedLegAssembly(R, rig.character, detachedRight, dt, 1)
				end
				if detachedLeft then
					updateDetachedLegAssembly(R, rig.character, detachedLeft, dt, 1)
				end
				fx:EmitBurst(rig.root.Position - Vector3.new(0, 1.8, 0), 16)
				phase = "StandingUp"
				phaseClock = 0
				onStatus("LEVANTANDO...", 0.88)
			end

		elseif phase == "StandingUp" then
			-- Animação orgânica de se levantar do chão em 3 estágios contínuos:
			-- 1) Apoia os braços e levanta o tronco (0..0.45)
			-- 2) Puxa os joelhos/pernas para baixo do quadril (0.35..0.80)
			-- 3) Estende o corpo até ficar de pé com leve mola (0.70..1.00)
			local p = clamp01(phaseClock / cfg.StandUpTime)
			local pushUp = smooth(0.0, 0.5, p)
			local tuckLegs = smooth(0.25, 0.75, p)
			local standExt = spring(inv(0.55, 1.0, p))

			local rootY = lerp(-2.15, -0.85, pushUp)
			rootY = lerp(rootY, 0, standExt)

			local rootPitch = lerp(-1.46, -0.55, pushUp)
			rootPitch = lerp(rootPitch, 0, standExt)

			local legBend = bell(tuckLegs) * 0.95 * (1 - standExt)
			local armPush = (1 - standExt) * lerp(1.05, 0.45, pushUp)

			local pose = RigAdapter.MakeUniversalPose(rig, {
				rootPos = Vector3.new(0, rootY, 0),
				rootPitch = rootPitch,
				rArmPitch = armPush,
				lArmPitch = armPush,
				rArmSpread = 0.25 * (1 - standExt),
				lArmSpread = 0.25 * (1 - standExt),
				rLegPitch = legBend,
				lLegPitch = legBend * 0.7,
				rKnee = -legBend * 1.2,
				lKnee = -legBend * 0.9,
				neckPitch = 0.4 * (1 - standExt),
			})
			RigAdapter.ApplyPose(rig, pose, expAlpha(dt, 16))
			fx:SetActivity(rig.root.Position, 0.25 * (1 - p))
			onProgress(0.88 + 0.12 * p)

			if phaseClock >= cfg.StandUpTime then
				rig.root.Anchored = false
				RigAdapter.RestoreAll(rig)
				fx:SetActivity(rig.root.Position, 0)
				onComplete()
			end
		end
	end
end

--------------------------------------------------------------------------------
-- HABILIDADE 2: NOCLIP — TRANSFORMAÇÃO EM GOTA E RECONSTRUÇÃO CORPORAL
--------------------------------------------------------------------------------
local NoclipAbility = {}

local function createDropletModel(renderer, quality)
	local d = {
		puddleDisc = renderer:Create(C.DropletDeep, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder),
		puddleInner = renderer:Create(C.Droplet, Enum.Material.Neon, Enum.PartType.Cylinder),
		rings = {},
		core = renderer:Create(C.DropletHot, Enum.Material.Neon, Enum.PartType.Ball),
		midShell = renderer:Create(C.Droplet, Enum.Material.SmoothPlastic, Enum.PartType.Ball),
		outerMembrane = renderer:Create(C.DropletDeep, Enum.Material.Glass, Enum.PartType.Ball),
		tailCone = renderer:Create(C.Droplet, Enum.Material.SmoothPlastic, Enum.PartType.Ball),
		satellites = {},
		trailDrops = {},
		trailCursor = 1,
	}
	for i = 1, quality.puddleRings do
		table.insert(d.rings, {
			el = renderer:Create(C.EnergyHot, Enum.Material.Neon, Enum.PartType.Cylinder),
			phase = (i - 1) / quality.puddleRings,
		})
	end
	for i = 1, quality.dropletSatellites do
		table.insert(d.satellites, {
			el = renderer:Create(i % 2 == 0 and C.DropletHot or C.Droplet, Enum.Material.SmoothPlastic, Enum.PartType.Ball),
			seed = rand(0, 100),
			angle = (i / quality.dropletSatellites) * TAU,
			radius = rand(0.65, 1.05),
			speed = rand(3.2, 5.4),
		})
	end
	for _ = 1, 10 do
		table.insert(d.trailDrops, {
			el = renderer:Create(C.Droplet, Enum.Material.SmoothPlastic, Enum.PartType.Ball),
			pos = Vector3.zero,
			born = -10,
			size = 0.25,
		})
	end
	return d
end

local function hideDropletModel(R, d)
	R:Hide(d.puddleDisc)
	R:Hide(d.puddleInner)
	for _, r in ipairs(d.rings) do
		R:Hide(r.el)
	end
	R:Hide(d.core)
	R:Hide(d.midShell)
	R:Hide(d.outerMembrane)
	R:Hide(d.tailCone)
	for _, s in ipairs(d.satellites) do
		R:Hide(s.el)
	end
	for _, tr in ipairs(d.trailDrops) do
		R:Hide(tr.el)
	end
end

-- Se o jogador terminar os 3s de Noclip dentro de uma parede sólida, encontra a saída livre mais próxima
local function findSafeExitPosition(char, currentPos, fallbackPos)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char, Workspace:FindFirstChild("RegenMovesetFX_Local") }

	local function isClear(pos)
		local hits = Workspace:GetPartBoundsInBox(CFrame.new(pos), Vector3.new(2.2, 4.2, 2.2), params)
		for _, part in ipairs(hits) do
			if part.CanCollide then
				return false
			end
		end
		return true
	end

	if isClear(currentPos) then
		return currentPos
	end

	-- Busca radial em espiral ao redor da posição atual
	for dist = 2, 16, 2 do
		for a = 0, 7 do
			local ang = (a / 8) * TAU
			local candidate = currentPos + Vector3.new(math.cos(ang) * dist, 0, math.sin(ang) * dist)
			if isClear(candidate) then
				return candidate
			end
		end
	end
	return fallbackPos
end

function NoclipAbility.Start(session, onStatus, onProgress, onComplete)
	local rig = session.rig
	local R = session.renderer
	local fx = session.fx
	local cfg = CONFIG.Noclip

	-- Cria reconstrutores para todas as 6 partes do corpo
	local limbOrder = { "Torso", "RightArm", "LeftArm", "RightLeg", "LeftLeg", "Head" }
	local bodyUnits = {}
	for _, name in ipairs(limbOrder) do
		if rig.limbs[name] then
			bodyUnits[name] = LimbBuilder.Create(R, rig.limbs[name], session.quality)
		end
	end

	local dropModel = createDropletModel(R, session.quality)

	local phase = "ExplodeDisintegrate"
	local phaseClock = 0
	local totalClock = 0

	local safeOriginPos = rig.root.Position
	local groundPos = findGroundBelow(rig.character, rig.root.Position, 20) or (rig.root.Position - Vector3.new(0, 3, 0))
	local dropPos = Vector3.new(rig.root.Position.X, groundPos.Y + 0.75, rig.root.Position.Z)
	local dropVel = Vector3.zero
	local lastTrailClock = 0
	local hiddenTriggered = false
	local noclipConn = nil

	local function setNoclipActive(enabled)
		if noclipRemote then
			noclipRemote:FireServer("SetNoclip", enabled)
		end
		if enabled then
			if not noclipConn then
				noclipConn = RunService.Stepped:Connect(function()
					if not rig.character or not rig.character.Parent then
						return
					end
					for _, d in ipairs(rig.character:GetDescendants()) do
						if d:IsA("BasePart") then
							d.CanCollide = false
						end
					end
				end)
				table.insert(session.extraConns, noclipConn)
			end
		else
			if noclipConn then
				noclipConn:Disconnect()
				noclipConn = nil
			end
			for inst, data in pairs(rig.partOriginals) do
				if inst and inst.Parent and data.CanCollide ~= nil and inst:IsA("BasePart") then
					inst.CanCollide = data.CanCollide
				end
			end
		end
	end

	rig.humanoid.WalkSpeed = 0
	rig.humanoid.JumpPower = 0
	rig.humanoid.JumpHeight = 0
	rig.humanoid.AutoRotate = false
	rig.root.Anchored = true

	fx:EmitBurst(rig.root.Position, 30)
	onStatus("DESINTEGRAÇÃO CELULAR...", 0.05)

	session.stepFn = function(dt)
		totalClock += dt
		phaseClock += dt

		if phase == "ExplodeDisintegrate" then
			local p = clamp01(phaseClock / cfg.ExplodeTime)
			if not hiddenTriggered and p >= 0.08 then
				hiddenTriggered = true
				RigAdapter.SetAllHidden(rig, 1)
			end

			local gPos = findGroundBelow(rig.character, rig.root.Position, 20)
			if gPos then
				groundPos = gPos
			end
			local puddleTarget = Vector3.new(rig.root.Position.X, groundPos.Y + 0.15, rig.root.Position.Z)

			for _, name in ipairs(limbOrder) do
				local u = bodyUnits[name]
				if u then
					LimbBuilder.UpdateDisintegration(u, p, totalClock, puddleTarget)
				end
			end

			-- A poça começa a se formar no chão à medida que os fragmentos caem
			local puddleGrow = smooth(0.25, 1.0, p)
			if puddleGrow > 0 then
				local rad = lerp(0.4, 4.4, outCubic(puddleGrow))
				local cylCF = CFrame.new(puddleTarget) * CFrame.Angles(0, 0, PI / 2)
				R:Draw(dropModel.puddleDisc, cylCF, Vector3.new(0.08, rad, rad), 0.15, C.DropletDeep)
				R:Draw(dropModel.puddleInner, cylCF * CFrame.new(0.02, 0, 0), Vector3.new(0.09, rad * 0.72, rad * 0.72), 0.25, C.Droplet)
			end

			fx:SetActivity(rig.root.Position:Lerp(puddleTarget, p), 0.95)
			onProgress(p * 0.12)

			if phaseClock >= cfg.ExplodeTime then
				for _, u in pairs(bodyUnits) do
					LimbBuilder.HideAll(u)
				end
				phase = "PuddleToDroplet"
				phaseClock = 0
				dropPos = Vector3.new(rig.root.Position.X, groundPos.Y + 0.72, rig.root.Position.Z)
				onStatus("CONDENSANDO GOTA VISCOSA...", 0.14)
			end

		elseif phase == "PuddleToDroplet" then
			local p = clamp01(phaseClock / cfg.PuddleToDropTime)
			local puddleCenter = Vector3.new(dropPos.X, groundPos.Y + 0.08, dropPos.Z)
			local cylCF = CFrame.new(puddleCenter) * CFrame.Angles(0, 0, PI / 2)

			-- A poça se concentra (encolhe radialmente) enquanto a gota emerge no centro
			local shrink = 1 - inOutSine(p)
			local rad = math.max(0.1, 4.4 * shrink)
			R:Draw(dropModel.puddleDisc, cylCF, Vector3.new(0.08, rad, rad), 1 - shrink * 0.85, C.DropletDeep)
			R:Draw(dropModel.puddleInner, cylCF * CFrame.new(0.02, 0, 0), Vector3.new(0.09, rad * 0.7, rad * 0.7), 1 - shrink * 0.8, C.Droplet)

			for _, ring in ipairs(dropModel.rings) do
				local rp = (totalClock * 1.8 + ring.phase) % 1
				local rSize = rad * (0.3 + 0.9 * rp)
				R:Draw(ring.el, cylCF * CFrame.new(0.03, 0, 0), Vector3.new(0.05, rSize, rSize), 0.3 + 0.7 * rp, C.EnergyHot)
			end

			-- Gota se erguendo com overshoot elástico (spring)
			local rise = spring(inv(0.18, 1.0, p))
			local curDropPos = puddleCenter + Vector3.new(0, 0.65 * rise, 0)
			local baseRadius = 1.15 * rise
			local stretchY = 1 + 0.35 * bell(p)
			local squashXZ = 1 / math.sqrt(stretchY)

			R:Draw(dropModel.core, CFrame.new(curDropPos), Vector3.new(baseRadius * 0.55 * squashXZ, baseRadius * 0.55 * stretchY, baseRadius * 0.55 * squashXZ), 0.1, C.DropletHot)
			R:Draw(dropModel.midShell, CFrame.new(curDropPos), Vector3.new(baseRadius * 0.88 * squashXZ, baseRadius * 0.88 * stretchY, baseRadius * 0.88 * squashXZ), 0.22, C.Droplet)
			R:Draw(dropModel.outerMembrane, CFrame.new(curDropPos), Vector3.new(baseRadius * 1.06 * squashXZ, baseRadius * 1.06 * stretchY, baseRadius * 1.06 * squashXZ), 0.55, C.DropletDeep)

			fx:SetActivity(curDropPos, 0.75)
			onProgress(0.12 + p * 0.10)

			if phaseClock >= cfg.PuddleToDropTime then
				R:Hide(dropModel.puddleDisc)
				R:Hide(dropModel.puddleInner)
				for _, ring in ipairs(dropModel.rings) do
					R:Hide(ring.el)
				end
				phase = "DropletControl"
				phaseClock = 0
				setNoclipActive(true)
				fx:EmitBurst(curDropPos, 15)
			end

		elseif phase == "DropletControl" then
			local rem = math.max(0, cfg.ControlDuration - phaseClock)
			onStatus(string.format("MODO GOTA (NOCLIP ATIVO) — %.1fs", rem), 0.22 + (phaseClock / cfg.ControlDuration) * 0.36)

			-- Lê direção de movimento (compatível com Mobile Thumbstick e WASD no PC)
			local inputDir = rig.humanoid.MoveDirection
			local targetVel = Vector3.new(inputDir.X, 0, inputDir.Z) * cfg.MoveSpeed
			dropVel = dropVel:Lerp(targetVel, expAlpha(dt, cfg.DropAccel))

			dropPos += dropVel * dt

			-- Mantém a gota deslizando sobre a altura do piso sem cair no void quando atravessa paredes
			local floorRayParams = makeCharRayParams(rig.character)
			local floorHit = Workspace:Raycast(Vector3.new(dropPos.X, dropPos.Y + 1.8, dropPos.Z), Vector3.new(0, -12, 0), floorRayParams)
			if floorHit and (floorHit.Position.Y <= dropPos.Y + 0.5) then
				dropPos = Vector3.new(dropPos.X, lerp(dropPos.Y, floorHit.Position.Y + 0.72, expAlpha(dt, 14)), dropPos.Z)
			end

			-- Move o HumanoidRootPart junto com a gota (mantendo câmera e posição real sincronizadas)
			local speed = dropVel.Magnitude
			local moveUnit = speed > 0.5 and dropVel.Unit or rig.root.CFrame.LookVector
			local flatLook = Vector3.new(moveUnit.X, 0, moveUnit.Z)
			if flatLook.Magnitude < 0.01 then
				flatLook = Vector3.zAxis
			else
				flatLook = flatLook.Unit
			end
			rig.root.CFrame = CFrame.lookAt(dropPos + Vector3.new(0, 2.2, 0), dropPos + Vector3.new(0, 2.2, 0) + flatLook)

			-- Física e Deformação Viscosa da Gota (Squash & Stretch + Ondulações Capilares)
			local speedRatio = clamp01(speed / cfg.MoveSpeed)
			local ripple1 = math.sin(totalClock * 14) * 0.07
			local ripple2 = noise(totalClock * 5.5, 1.9) * 0.08
			local lenStretch = 1 + 0.52 * speedRatio + ripple1
			local widthSquash = (1 / math.sqrt(lenStretch)) + ripple2 * 0.5
			local heightSquash = (1 - 0.18 * speedRatio) - ripple1 * 0.6

			local dropCF = CFrame.lookAt(dropPos, dropPos + flatLook)
			local baseD = 1.22

			R:Draw(
				dropModel.core,
				dropCF * CFrame.new(0, 0, -0.08 * speedRatio),
				Vector3.new(baseD * 0.56 * widthSquash, baseD * 0.56 * heightSquash, baseD * 0.56 * lenStretch),
				0.08,
				C.DropletHot:Lerp(C.EnergyHot, 0.35 + 0.35 * math.sin(totalClock * 10))
			)
			R:Draw(
				dropModel.midShell,
				dropCF,
				Vector3.new(baseD * 0.90 * widthSquash, baseD * 0.90 * heightSquash, baseD * 0.90 * lenStretch),
				0.20,
				C.Droplet
			)
			R:Draw(
				dropModel.outerMembrane,
				dropCF * CFrame.Angles(0, 0, math.sin(totalClock * 8) * 0.15),
				Vector3.new(baseD * 1.10 * widthSquash, baseD * 1.10 * heightSquash, baseD * 1.10 * lenStretch),
				0.52,
				C.DropletDeep
			)
			-- Cauda viscosa alongada atrás da gota quando em movimento
			if speedRatio > 0.06 then
				local tailDist = (0.45 + 0.55 * speedRatio)
				local tailSize = baseD * (0.55 * speedRatio)
				R:Draw(
					dropModel.tailCone,
					dropCF * CFrame.new(0, -0.08, tailDist),
					Vector3.new(tailSize * 0.75, tailSize * 0.65, tailSize * 1.45),
					0.25,
					C.Droplet
				)
			else
				R:Hide(dropModel.tailCone)
			end

			-- Micro-gotas satélites orbitando e ondulando ao redor da gota principal
			for _, sat in ipairs(dropModel.satellites) do
				local ang = sat.angle + totalClock * sat.speed
				local r = sat.radius * (0.75 + 0.25 * math.sin(totalClock * 6 + sat.seed))
				local ox = math.cos(ang) * r
				local oz = math.sin(ang) * r + 0.35 * speedRatio
				local oy = math.sin(totalClock * 9 + sat.seed) * 0.22
				local sz = 0.22 + 0.08 * math.sin(totalClock * 11 + sat.seed)
				R:Draw(sat.el, dropCF * CFrame.new(ox, oy, oz), Vector3.new(sz, sz * 0.85, sz * 1.15), 0.18, nil)
			end

			-- Rastro viscoso de pequenas gotas no chão
			if totalClock - lastTrailClock >= 0.07 and speedRatio > 0.1 then
				lastTrailClock = totalClock
				local td = dropModel.trailDrops[dropModel.trailCursor]
				dropModel.trailCursor = (dropModel.trailCursor % #dropModel.trailDrops) + 1
				td.pos = dropPos - Vector3.new(0, 0.52, 0) + Vector3.new(rand(-0.25, 0.25), 0, rand(-0.25, 0.25))
				td.born = totalClock
				td.size = rand(0.28, 0.52)
			end

			for _, td in ipairs(dropModel.trailDrops) do
				local age = totalClock - td.born
				if age >= 0 and age < 0.75 then
					local k = 1 - (age / 0.75)
					R:Draw(td.el, CFrame.new(td.pos), Vector3.new(td.size * k, 0.08, td.size * k), 1 - k * 0.8, C.Droplet)
				else
					R:Hide(td.el)
				end
			end

			-- Anel de ondulação rente ao piso
			local cylCF = CFrame.new(dropPos - Vector3.new(0, 0.58, 0)) * CFrame.Angles(0, 0, PI / 2)
			for _, ring in ipairs(dropModel.rings) do
				local rp = (totalClock * 2.2 + ring.phase) % 1
				local rSize = 0.8 + 1.8 * rp
				R:Draw(ring.el, cylCF, Vector3.new(0.04, rSize, rSize), 0.35 + 0.65 * rp, C.DropletHot)
			end

			fx:SetActivity(dropPos, 0.6 + 0.35 * speedRatio)

			if phaseClock >= cfg.ControlDuration then
				hideDropletModel(R, dropModel)
				-- Posiciona o personagem em local livre de colisão e inicia a reconstrução sequencial
				local safeRootPos = findSafeExitPosition(rig.character, dropPos + Vector3.new(0, 2.35, 0), safeOriginPos)
				rig.root.CFrame = CFrame.lookAt(safeRootPos, safeRootPos + flatLook)
				setNoclipActive(false)
				fx:EmitBurst(safeRootPos, 28)
				phase = "FullBodyRebuild"
				phaseClock = 0
			end

		elseif phase == "FullBodyRebuild" then
			--[[
				RECONSTRUÇÃO CORPORAL SEQUENCIAL DO NOCLIP:
				1. Primeiro o Torso (0.00 -> 0.36)
				2. Depois a estrutura interna dos membros (0.18 -> 0.54)
				3. Em seguida braços e pernas — volumes musculares (0.38 -> 0.74)
				4. Depois a Cabeça (0.56 -> 0.86)
				5. Por último, a superfície externa e os detalhes de todo o corpo (0.72 -> 1.00)
			]]
			local p = clamp01(phaseClock / cfg.FullRegenTime)

			-- Gota residual na base subindo para formar o Torso nos primeiros instantes
			if p < 0.24 then
				local colP = p / 0.24
				local basePos = rig.root.Position - Vector3.new(0, 2.2 * (1 - colP), 0)
				local sz = 1.35 * (1 - colP * 0.7)
				R:Draw(dropModel.core, CFrame.new(basePos), Vector3.new(sz, sz * (1 + colP * 2.2), sz), colP, C.DropletHot)
			else
				R:Hide(dropModel.core)
			end

			-- Postura corporal emergindo da flutuação de reconstrução até a postura natural
			local settle = smooth(0.75, 1.0, p)
			local floatBob = (1 - settle) * (0.28 + 0.1 * math.sin(totalClock * 4.5))
			local armOpen = (1 - settle) * 0.42
			local pose = RigAdapter.MakeUniversalPose(rig, {
				rootPos = Vector3.new(0, floatBob, 0),
				rootPitch = (1 - settle) * 0.14,
				rArmSpread = armOpen,
				lArmSpread = armOpen,
				rArmPitch = (1 - settle) * 0.25,
				lArmPitch = (1 - settle) * 0.25,
				rLegSpread = (1 - settle) * 0.15,
				lLegSpread = (1 - settle) * 0.15,
				neckPitch = (1 - settle) * (-0.22),
			})
			RigAdapter.ApplyPose(rig, pose, expAlpha(dt, 14))

			-- Janelas específicas respeitando a ordem exata pedida:
			-- 1) Torso
			if bodyUnits.Torso then
				LimbBuilder.UpdateReconstruction(bodyUnits.Torso, p, totalClock, {
					stump    = { 0.00, 0.10 },
					bone     = { 0.02, 0.22 },
					joints   = { 0.12, 0.28 },
					muscle   = { 0.18, 0.36 },
					volume   = { 0.26, 0.44 },
					membrane = { 0.62, 0.78 },
					skin     = { 0.70, 0.90 },
					seal     = { 0.86, 0.98 },
				})
			end

			-- 2 & 3) Braços e Pernas (Estrutura óssea/articular primeiro -> Volumes musculares -> Pele externa por último)
			local limbWin = {
				stump    = { 0.16, 0.26 },
				bone     = { 0.18, 0.44 }, -- 2. Estrutura dos membros
				joints   = { 0.30, 0.52 },
				muscle   = { 0.40, 0.66 }, -- 3. Volumes de braços e pernas
				volume   = { 0.52, 0.74 },
				membrane = { 0.66, 0.82 },
				skin     = { 0.74, 0.94 }, -- 5. Superfície externa
				seal     = { 0.88, 0.99 },
			}
			for _, lName in ipairs({ "RightArm", "LeftArm", "RightLeg", "LeftLeg" }) do
				if bodyUnits[lName] then
					LimbBuilder.UpdateReconstruction(bodyUnits[lName], p, totalClock, limbWin)
				end
			end

			-- 4) Cabeça (após braços e pernas)
			if bodyUnits.Head then
				LimbBuilder.UpdateReconstruction(bodyUnits.Head, p, totalClock, {
					stump    = { 0.54, 0.62 },
					bone     = { 0.56, 0.70 },
					joints   = { 0.62, 0.74 },
					muscle   = { 0.66, 0.78 },
					volume   = { 0.70, 0.82 },
					membrane = { 0.74, 0.86 },
					skin     = { 0.78, 0.95 },
					seal     = { 0.90, 0.99 },
				})
			end

			-- Revela gradualmente as partes reais à medida que cada selagem conclui
			local revealTorso = smooth(0.86, 0.97, p)
			local revealLimbs = smooth(0.88, 0.98, p)
			local revealHead  = smooth(0.90, 0.99, p)
			RigAdapter.SetLimbHidden(rig, "Torso",    1 - revealTorso)
			RigAdapter.SetLimbHidden(rig, "RightArm", 1 - revealLimbs)
			RigAdapter.SetLimbHidden(rig, "LeftArm",  1 - revealLimbs)
			RigAdapter.SetLimbHidden(rig, "RightLeg", 1 - revealLimbs)
			RigAdapter.SetLimbHidden(rig, "LeftLeg",  1 - revealLimbs)
			RigAdapter.SetLimbHidden(rig, "Head",     1 - revealHead)

			-- Status dinâmico claro na interface
			local stageLabel = "1/5 · RECONSTRUINDO TORSO"
			if p >= 0.74 then
				stageLabel = "5/5 · SUPERFÍCIE EXTERNA E DETALHES"
			elseif p >= 0.56 then
				stageLabel = "4/5 · RECONSTRUINDO CABEÇA"
			elseif p >= 0.40 then
				stageLabel = "3/5 · FORMANDO BRAÇOS E PERNAS"
			elseif p >= 0.18 then
				stageLabel = "2/5 · ESTRUTURA INTERNA DOS MEMBROS"
			end
			onStatus("REGENERAÇÃO NOCLIP · " .. stageLabel, 0.58 + p * 0.42)
			fx:SetActivity(rig.root.Position, 0.9 * (1 - smooth(0.88, 1.0, p)))

			if phaseClock >= cfg.FullRegenTime then
				for _, u in pairs(bodyUnits) do
					LimbBuilder.HideAll(u)
				end
				hideDropletModel(R, dropModel)
				rig.root.Anchored = false
				RigAdapter.RestoreAll(rig)
				fx:EmitBurst(rig.root.Position, 20)
				fx:SetActivity(rig.root.Position, 0)
				onComplete()
			end
		end
	end
end

--------------------------------------------------------------------------------
-- HABILIDADE 3: GANCHO DE MÃO — GRAPPLE REGENERATIVO
--------------------------------------------------------------------------------
local GrappleAbility = {}

local function createGrappleVisuals(renderer, rightArmLimb, quality)
	local g = {
		flyingPieces = {},
		tendonStrands = {},
		nerveCore = {},
		droplets = {},
		reticleRing = renderer:Create(C.EnergyHot, Enum.Material.Neon, Enum.PartType.Cylinder),
		reticleDot  = renderer:Create(C.DropletHot, Enum.Material.Neon, Enum.PartType.Ball),
	}

	-- Réplica geométrica fiel do braço direito do jogador (respeitando R6 ou R15)
	local s1 = rightArmLimb.sections[1]
	for _, sec in ipairs(rightArmLimb.sections) do
		table.insert(g.flyingPieces, {
			el = renderer:Create(sec.part.Color, sec.part.Material),
			relCF = s1.part.CFrame:ToObjectSpace(sec.part.CFrame),
			size = Vector3.new(sec.w, sec.length, sec.d),
			color = sec.part.Color,
		})
	end
	g.cuffBio = renderer:Create(C.MuscleHot, Enum.Material.SmoothPlastic)
	g.cuffSize = Vector3.new(s1.w * 0.94, 0.12, s1.d * 0.94)

	-- Feixes de tendões e fibras nervosas entre o ombro e o braço lançado
	local numSegs = quality.tendonSegments
	for s = 1, quality.tendonStrands do
		local strand = {
			segs = {},
			phase = (s / quality.tendonStrands) * TAU,
			isNerve = (s == 1),
		}
		for _ = 1, numSegs do
			local col = strand.isNerve and C.Nerve or C.Tendon
			local mat = strand.isNerve and Enum.Material.Neon or Enum.Material.SmoothPlastic
			table.insert(strand.segs, renderer:Create(col, mat))
		end
		table.insert(g.tendonStrands, strand)
	end

	-- Gotas vermelhas estilizadas que surgem durante o lançamento e percorrem os tendões
	for i = 1, quality.grappleDroplets do
		table.insert(g.droplets, {
			el = renderer:Create(i % 2 == 0 and C.DropletHot or C.Droplet, Enum.Material.SmoothPlastic, Enum.PartType.Ball),
			u = (i - 1) / quality.grappleDroplets,
			speed = rand(0.9, 1.7),
			radial = rand(0.08, 0.26),
			angle = rand(0, TAU),
			size = rand(0.14, 0.26),
		})
	end

	return g
end

local function hideGrappleVisuals(R, g)
	for _, fp in ipairs(g.flyingPieces) do
		R:Hide(fp.el)
	end
	R:Hide(g.cuffBio)
	for _, st in ipairs(g.tendonStrands) do
		for _, seg in ipairs(st.segs) do
			R:Hide(seg)
		end
	end
	for _, dr in ipairs(g.droplets) do
		R:Hide(dr.el)
	end
	R:Hide(g.reticleRing)
	R:Hide(g.reticleDot)
end

-- Faz raycast a partir da posição da tela (Mouse ou Toque Mobile)
local function raycastFromScreenPoint(char, screenPos, maxDist)
	local cam = Workspace.CurrentCamera
	if not cam then
		return nil
	end
	local unitRay = cam:ViewportPointToRay(screenPos.X, screenPos.Y)
	local params = makeCharRayParams(char)
	local hit = Workspace:Raycast(unitRay.Origin, unitRay.Direction * maxDist, params)
	if hit then
		return hit.Position, hit.Normal, hit.Instance
	end
	return nil
end

function GrappleAbility.Start(session, immediateRayPoint, onStatus, onProgress, onComplete, onCancelAim)
	local rig = session.rig
	local R = session.renderer
	local fx = session.fx
	local cfg = CONFIG.Grapple

	local rightArmLimb = rig.limbs.RightArm
	local armReconstructor = LimbBuilder.Create(R, rightArmLimb, session.quality)
	local gVis = createGrappleVisuals(R, rightArmLimb, session.quality)

	local phase = "Aiming"
	local phaseClock = 0
	local totalClock = 0

	local targetAnchorPos = nil
	local targetNormal = Vector3.yAxis
	local shoulderWorldPos = rig.root.Position
	local handWorldPos = rig.root.Position
	local launchStartPos = rig.root.Position
	local launchDuration = 0.25
	local currentPullSpeed = 12
	local swingPhase = 0

	local function getShoulderWorld()
		local s1 = rightArmLimb.sections[1]
		return (s1.part.CFrame * CFrame.new(0, rightArmLimb.capY, 0)).Position
	end

	local function renderTendonsAndArm(shoulderPos, armPos, armDir, tension, slack, dropletIntensity)
		-- 1. Desenha o Braço Direito Geométrico na posição atual da trajetória
		-- No Roblox, o eixo -Y do braço aponta do ombro para a mão; alinhamos -Y com `armDir`
		local upVec = -armDir.Unit
		local rightVec = upVec:Cross(Vector3.yAxis)
		if rightVec.Magnitude < 0.05 then
			rightVec = upVec:Cross(Vector3.xAxis)
		end
		rightVec = rightVec.Unit
		local backVec = rightVec:Cross(upVec).Unit
		local armRootCF = CFrame.fromMatrix(armPos, rightVec, upVec, backVec)

		for _, fp in ipairs(gVis.flyingPieces) do
			R:Draw(fp.el, armRootCF * fp.relCF, fp.size, 0, fp.color)
		end
		R:Draw(gVis.cuffBio, armRootCF * CFrame.new(0, rightArmLimb.capY, 0), gVis.cuffSize, 0.1, C.MuscleHot)

		-- 2. Desenha os Feixes de Tendões e Fibras Nervosas entre ombro e braço
		local span = armPos - shoulderPos
		local dist = span.Magnitude
		if dist < 0.2 then
			for _, st in ipairs(gVis.tendonStrands) do
				for _, seg in ipairs(st.segs) do
					R:Hide(seg)
				end
			end
			return
		end

		local dir = span / dist
		local ortho1 = dir:Cross(Vector3.yAxis)
		if ortho1.Magnitude < 0.05 then
			ortho1 = dir:Cross(Vector3.xAxis)
		end
		ortho1 = ortho1.Unit
		local ortho2 = dir:Cross(ortho1).Unit

		for _, st in ipairs(gVis.tendonStrands) do
			local numSegs = #st.segs
			local prevPt = shoulderPos
			for i = 1, numSegs do
				local u = i / numSegs
				local env = math.sin(u * PI) -- 0 nas extremidades, 1 no meio
				-- Catenária gravitacional quando frouxo + espiral biológica + vibração de tensão
				local sag = Vector3.new(0, -slack * 1.8 * env, 0)
				local helixAngle = u * TAU * 2.5 + st.phase + totalClock * (st.isNerve and 9 or -5)
				local radius = (st.isNerve and 0.06 or 0.15) * env * (1 - 0.35 * tension)
				local vib = math.sin(totalClock * 42 + u * 18 + st.phase) * 0.04 * tension * env
				local spiralOffset = (ortho1 * math.cos(helixAngle) + ortho2 * math.sin(helixAngle)) * (radius + vib)

				local curPt = shoulderPos + span * u + sag + spiralOffset
				local segVec = curPt - prevPt
				local segLen = segVec.Magnitude
				if segLen > 0.01 then
					local mid = (prevPt + curPt) * 0.5
					local segCF = CFrame.lookAt(mid, curPt) * CFrame.Angles(PI / 2, 0, 0)
					local thick = st.isNerve and (0.075 + 0.03 * math.sin(totalClock * 16 + u * 8)) or (0.11 - 0.03 * tension)
					local col = st.isNerve and C.Nerve:Lerp(C.EnergyHot, 0.5 * math.sin(totalClock * 14 + u * 6) + 0.5)
						or C.Tendon:Lerp(C.MuscleHot, tension * 0.6)
					R:Draw(st.segs[i], segCF, Vector3.new(thick, segLen + 0.03, thick), st.isNerve and 0.12 or 0.04, col)
				else
					R:Hide(st.segs[i])
				end
				prevPt = curPt
			end
		end

		-- 3. Gotas vermelhas estilizadas durante o lançamento e tração
		for _, dr in ipairs(gVis.droplets) do
			if dropletIntensity <= 0.02 then
				R:Hide(dr.el)
			else
				local u = (dr.u + totalClock * dr.speed) % 1
				local env = math.sin(u * PI)
				local ang = dr.angle + totalClock * 4
				local offset = (ortho1 * math.cos(ang) + ortho2 * math.sin(ang)) * (dr.radial * env)
					- Vector3.new(0, 0.25 * (1 - tension) * env, 0)
				local dPos = shoulderPos + span * u + offset
				local dCF = CFrame.lookAt(dPos, dPos + dir)
				local sz = dr.size * (0.6 + 0.4 * env) * dropletIntensity
				R:Draw(dr.el, dCF, Vector3.new(sz * 0.8, sz * 0.8, sz * 1.45), 1 - dropletIntensity * 0.88, nil)
			end
		end
	end

	local function triggerLaunch(hitPos, hitNorm)
		local dist = (hitPos - rig.root.Position).Magnitude
		if dist > cfg.MaxDistance or dist < cfg.MinDistance then
			return false
		end
		targetAnchorPos = hitPos
		targetNormal = hitNorm or Vector3.yAxis
		R:Hide(gVis.reticleRing)
		R:Hide(gVis.reticleDot)

		RigAdapter.SetLimbHidden(rig, "RightArm", 1)
		launchStartPos = getShoulderWorld()
		handWorldPos = launchStartPos
		launchDuration = math.clamp(dist / cfg.ArmLaunchSpeed, 0.14, 0.42)
		phase = "LaunchingArm"
		phaseClock = 0
		rig.humanoid.AutoRotate = false
		fx:EmitBurst(launchStartPos, 16)
		onStatus("BRAÇO LANÇADO!", 0.22)
		return true
	end

	-- Se já foi invocado com um ponto válido (ex: tecla de atalho no PC apontando para superfície), dispara direto
	if immediateRayPoint then
		local hPos, hNorm = raycastFromScreenPoint(rig.character, immediateRayPoint, cfg.MaxDistance)
		if hPos then
			triggerLaunch(hPos, hNorm)
		end
	end

	if phase == "Aiming" then
		onStatus("TOQUE OU CLIQUE EM UMA SUPERFÍCIE PARA LANÇAR O GANCHO", 0.08)
		local inputConn
		inputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed or phase ~= "Aiming" then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				local hPos, hNorm = raycastFromScreenPoint(rig.character, input.Position, cfg.MaxDistance)
				if hPos and triggerLaunch(hPos, hNorm) then
					inputConn:Disconnect()
				end
			end
		end)
		table.insert(session.extraConns, inputConn)
	end

	session.stepFn = function(dt)
		totalClock += dt
		phaseClock += dt

		if phase == "Aiming" then
			-- Mostra mira biológica na superfície sob o cursor do mouse (PC)
			local mousePos = UserInputService:GetMouseLocation()
			local hPos, hNorm = raycastFromScreenPoint(rig.character, mousePos, cfg.MaxDistance)
			if hPos then
				local dist = (hPos - rig.root.Position).Magnitude
				local valid = (dist >= cfg.MinDistance and dist <= cfg.MaxDistance)
				local col = valid and C.EnergyHot or Color3.fromRGB(140, 140, 140)
				local ringCF = CFrame.lookAt(hPos + hNorm * 0.05, hPos + hNorm * 1.05) * CFrame.Angles(0, PI / 2, 0)
				local pulse = 1.2 + 0.25 * math.sin(totalClock * 10)
				R:Draw(gVis.reticleRing, ringCF, Vector3.new(0.06, pulse, pulse), 0.25, col)
				R:Draw(gVis.reticleDot, CFrame.new(hPos + hNorm * 0.08), Vector3.new(0.35, 0.35, 0.35), 0.1, col)
			else
				R:Hide(gVis.reticleRing)
				R:Hide(gVis.reticleDot)
			end

			if phaseClock >= cfg.AimTimeout then
				hideGrappleVisuals(R, gVis)
				onCancelAim()
			end

		elseif phase == "LaunchingArm" then
			local p = clamp01(phaseClock / launchDuration)
			shoulderWorldPos = getShoulderWorld()
			local launchEase = outCubic(p)
			handWorldPos = shoulderWorldPos:Lerp(targetAnchorPos, launchEase)

			-- Orienta o personagem para o ponto de ancoragem com recuo de lançamento no tronco
			local flatTarget = Vector3.new(targetAnchorPos.X, rig.root.Position.Y, targetAnchorPos.Z)
			if (flatTarget - rig.root.Position).Magnitude > 0.5 then
				rig.root.CFrame = rig.root.CFrame:Lerp(CFrame.lookAt(rig.root.Position, flatTarget), expAlpha(dt, 18))
			end

			local pose = RigAdapter.MakeUniversalPose(rig, {
				rootPitch = 0.22 * bell(p),
				rootYaw = -0.35 * (1 - p) + 0.25 * p,
				lArmPitch = -0.6,
				lArmSpread = 0.35,
			})
			RigAdapter.ApplyPose(rig, pose, expAlpha(dt, 20))

			LimbBuilder.UpdateStumpOnly(armReconstructor, totalClock, 0.9)
			renderTendonsAndArm(
				shoulderWorldPos,
				handWorldPos,
				(targetAnchorPos - shoulderWorldPos),
				0.35 + 0.65 * p,
				1 - p,
				1.0
			)
			fx:SetActivity(handWorldPos, 0.95)
			onProgress(0.15 + p * 0.20)

			if phaseClock >= launchDuration then
				phase = "Pulling"
				phaseClock = 0
				currentPullSpeed = 16
				fx:EmitBurst(targetAnchorPos, 22)
				onStatus("TRAÇÃO BIOMECÂNICA EM CURSO!", 0.38)
			end

		elseif phase == "Pulling" then
			shoulderWorldPos = getShoulderWorld()
			handWorldPos = targetAnchorPos
			local toAnchor = targetAnchorPos - rig.root.Position
			local dist = toAnchor.Magnitude

			if dist <= cfg.ArrivalDistance or phaseClock >= 2.6 then
				phase = "RetractingArm"
				phaseClock = 0
				-- Impulso residual suave de chegada (vault)
				rig.root.AssemblyLinearVelocity = rig.root.AssemblyLinearVelocity * 0.32 + Vector3.new(0, 14, 0)
				onStatus("RECONECTANDO BRAÇO AO OMBRO...", 0.80)
			else
				local dir = toAnchor.Unit
				-- Aceleração progressiva + Desaceleração suave ao se aproximar do destino
				currentPullSpeed = math.min(cfg.PullMaxSpeed, currentPullSpeed + cfg.PullAccel * dt)
				local decelFactor = clamp(dist / 24, 0.32, 1.0)
				local speed = currentPullSpeed * decelFactor

				-- Balanço pendular orgânico (gravidade + oscilação lateral durante o voo)
				swingPhase += dt * 7.5
				local rightVec = dir:Cross(Vector3.yAxis)
				if rightVec.Magnitude < 0.05 then
					rightVec = Vector3.xAxis
				else
					rightVec = rightVec.Unit
				end
				local pendulumArc = Vector3.new(0, -math.sin(clamp01(phaseClock / 0.55) * PI) * 10 + 7, 0)
				local lateralSwing = rightVec * (math.sin(swingPhase) * 6.5 * decelFactor)

				local velocity = dir * speed + pendulumArc + lateralSwing
				rig.root.AssemblyLinearVelocity = velocity

				-- Orienta o corpo inclinando na direção do cabo com balanço secundário nas pernas
				local lookPos = rig.root.Position + Vector3.new(dir.X, dir.Y * 0.35, dir.Z)
				rig.root.CFrame = rig.root.CFrame:Lerp(CFrame.lookAt(rig.root.Position, lookPos), expAlpha(dt, 14))

				local swingAngle = math.sin(swingPhase) * 0.22 * decelFactor
				local pitchAngle = clamp(dir.Y * 0.55, -0.5, 0.65)
				local pose = RigAdapter.MakeUniversalPose(rig, {
					rootPitch = pitchAngle,
					rootRoll = -swingAngle,
					rootYaw = 0.25,
					lArmPitch = -0.75 + swingAngle,
					lArmSpread = 0.45,
					rLegPitch = -0.45 - swingAngle * 0.8,
					lLegPitch = -0.30 + swingAngle * 0.8,
					rKnee = -0.5,
					lKnee = -0.35,
				})
				RigAdapter.ApplyPose(rig, pose, expAlpha(dt, 15))

				LimbBuilder.UpdateStumpOnly(armReconstructor, totalClock, 0.95)
				renderTendonsAndArm(
					shoulderWorldPos,
					handWorldPos - dir * 0.7,
					dir,
					1.0,
					0.08 * (1 - decelFactor),
					0.85
				)
				fx:SetActivity(shoulderWorldPos, 0.8)
				onProgress(0.38 + (1 - clamp01(dist / cfg.MaxDistance)) * 0.40)
			end

		elseif phase == "RetractingArm" then
			local p = clamp01(phaseClock / cfg.RetractTime)
			shoulderWorldPos = getShoulderWorld()
			local retractEase = inOutSine(p)
			local curArmPos = targetAnchorPos:Lerp(shoulderWorldPos, retractEase)
			local dir = (targetAnchorPos - shoulderWorldPos)
			if dir.Magnitude < 0.05 then
				dir = rig.root.CFrame.LookVector
			end

			if p < 0.65 then
				LimbBuilder.UpdateStumpOnly(armReconstructor, totalClock, 0.8)
				renderTendonsAndArm(
					shoulderWorldPos,
					curArmPos,
					dir,
					1 - p,
					0.15 * (1 - p),
					1 - p
				)
			else
				hideGrappleVisuals(R, gVis)
				-- Selagem rápida do ombro (placas de pele e flash de reconexão)
				local sealP = inv(0.65, 1.0, p)
				LimbBuilder.UpdateReconstruction(armReconstructor, lerp(0.74, 1.0, sealP), totalClock)
				RigAdapter.SetLimbHidden(rig, "RightArm", 1 - sealP)
			end

			-- Postura retornando suavemente ao equilíbrio
			RigAdapter.ApplyPose(rig, {}, expAlpha(dt, 16))
			onProgress(0.80 + p * 0.20)

			if phaseClock >= cfg.RetractTime then
				hideGrappleVisuals(R, gVis)
				LimbBuilder.HideAll(armReconstructor)
				RigAdapter.RestoreAll(rig)
				fx:EmitBurst(shoulderWorldPos, 16)
				fx:SetActivity(shoulderWorldPos, 0)
				onComplete()
			end
		end
	end
end

--------------------------------------------------------------------------------
-- INTERFACE MOBILE E PC (3 Botões com Ícones, Animação, Recarga e Bloqueio)
--------------------------------------------------------------------------------
local HUD = {}

local ABILITY_META = {
	{
		id = "Jump",
		title = "JUMP",
		sub = "Salto Regenerativo",
		keyLabel = "Q / 1",
		keys = { Enum.KeyCode.Q, Enum.KeyCode.One },
		accent = Color3.fromRGB(238, 72, 68),
	},
	{
		id = "Noclip",
		title = "NOCLIP",
		sub = "Forma de Gota (3s)",
		keyLabel = "E / 2",
		keys = { Enum.KeyCode.E, Enum.KeyCode.Two },
		accent = Color3.fromRGB(214, 34, 56),
	},
	{
		id = "Grapple",
		title = "GANCHO",
		sub = "Grapple Biológico",
		keyLabel = "F / 3",
		keys = { Enum.KeyCode.F, Enum.KeyCode.Three },
		accent = Color3.fromRGB(255, 108, 76),
	},
}

local function uiTween(inst, t, props, style)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function addCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

-- Desenha ícones vetoriais estilizados exclusivos para cada botão usando Frames
local function buildCustomIcon(parent, abilityId)
	local iconHolder = Instance.new("Frame")
	iconHolder.Size = UDim2.fromOffset(38, 38)
	iconHolder.Position = UDim2.new(0, 12, 0.5, 0)
	iconHolder.AnchorPoint = Vector2.new(0, 0.5)
	iconHolder.BackgroundColor3 = Color3.fromRGB(34, 24, 30)
	iconHolder.BorderSizePixel = 0
	iconHolder.ZIndex = 4
	iconHolder.Parent = parent
	addCorner(iconHolder, 12)

	if abilityId == "Jump" then
		-- Ícone de Salto + Pernas desprendidas
		local arrowTop = Instance.new("Frame")
		arrowTop.Size = UDim2.fromOffset(10, 10)
		arrowTop.Position = UDim2.new(0.5, 0, 0, 8)
		arrowTop.AnchorPoint = Vector2.new(0.5, 0)
		arrowTop.Rotation = 45
		arrowTop.BackgroundColor3 = Color3.new(1, 1, 1)
		arrowTop.BorderSizePixel = 0
		arrowTop.ZIndex = 5
		arrowTop.Parent = iconHolder

		local legL = Instance.new("Frame")
		legL.Size = UDim2.fromOffset(5, 13)
		legL.Position = UDim2.new(0.5, -5, 0, 19)
		legL.AnchorPoint = Vector2.new(0.5, 0)
		legL.Rotation = 12
		legL.BackgroundColor3 = C.EnergyHot
		legL.BorderSizePixel = 0
		legL.ZIndex = 5
		legL.Parent = iconHolder
		addCorner(legL, 2)

		local legR = Instance.new("Frame")
		legR.Size = UDim2.fromOffset(5, 13)
		legR.Position = UDim2.new(0.5, 5, 0, 19)
		legR.AnchorPoint = Vector2.new(0.5, 0)
		legR.Rotation = -12
		legR.BackgroundColor3 = C.EnergyHot
		legR.BorderSizePixel = 0
		legR.ZIndex = 5
		legR.Parent = iconHolder
		addCorner(legR, 2)

	elseif abilityId == "Noclip" then
		-- Ícone de Gota Vermelha com ondas
		local dropBall = Instance.new("Frame")
		dropBall.Size = UDim2.fromOffset(16, 16)
		dropBall.Position = UDim2.new(0.5, 0, 0, 15)
		dropBall.AnchorPoint = Vector2.new(0.5, 0.5)
		dropBall.BackgroundColor3 = C.EnergyHot
		dropBall.BorderSizePixel = 0
		dropBall.ZIndex = 6
		dropBall.Parent = iconHolder
		addCorner(dropBall, 8)

		local dropTip = Instance.new("Frame")
		dropTip.Size = UDim2.fromOffset(11, 11)
		dropTip.Position = UDim2.new(0.5, 0, 0, 10)
		dropTip.AnchorPoint = Vector2.new(0.5, 0.5)
		dropTip.Rotation = 45
		dropTip.BackgroundColor3 = C.EnergyHot
		dropTip.BorderSizePixel = 0
		dropTip.ZIndex = 5
		dropTip.Parent = iconHolder

		local puddleLine = Instance.new("Frame")
		puddleLine.Size = UDim2.fromOffset(24, 4)
		puddleLine.Position = UDim2.new(0.5, 0, 1, -7)
		puddleLine.AnchorPoint = Vector2.new(0.5, 0.5)
		puddleLine.BackgroundColor3 = C.Energy
		puddleLine.BorderSizePixel = 0
		puddleLine.ZIndex = 5
		puddleLine.Parent = iconHolder
		addCorner(puddleLine, 2)

	elseif abilityId == "Grapple" then
		-- Ícone de Fibra de Tendão + Braço ancorado
		local tendonLine = Instance.new("Frame")
		tendonLine.Size = UDim2.fromOffset(20, 3)
		tendonLine.Position = UDim2.new(0.5, -2, 0.5, 3)
		tendonLine.AnchorPoint = Vector2.new(0.5, 0.5)
		tendonLine.Rotation = -42
		tendonLine.BackgroundColor3 = C.Energy
		tendonLine.BorderSizePixel = 0
		tendonLine.ZIndex = 5
		tendonLine.Parent = iconHolder

		local handBlock = Instance.new("Frame")
		handBlock.Size = UDim2.fromOffset(10, 10)
		handBlock.Position = UDim2.new(1, -10, 0, 10)
		handBlock.AnchorPoint = Vector2.new(0.5, 0.5)
		handBlock.Rotation = -42
		handBlock.BackgroundColor3 = Color3.new(1, 1, 1)
		handBlock.BorderSizePixel = 0
		handBlock.ZIndex = 6
		handBlock.Parent = iconHolder
		addCorner(handBlock, 2)
	end

	return iconHolder
end

function HUD.Create(onTriggerAbility)
	local old = playerGui:FindFirstChild("RegenMovesetHUD")
	if old then
		old:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "RegenMovesetHUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 8
	gui.Parent = playerGui
	HUD.gui = gui

	-- Container principal (canto inferior central/direito ergonômico para Mobile e PC)
	local rootFrame = Instance.new("Frame")
	rootFrame.Name = "MovesetContainer"
	rootFrame.AnchorPoint = Vector2.new(0.5, 1)
	rootFrame.Position = UDim2.new(0.5, 0, 1, -18)
	rootFrame.Size = UDim2.fromOffset(540, 112)
	rootFrame.BackgroundTransparency = 1
	rootFrame.Parent = gui

	local uiScale = Instance.new("UIScale")
	uiScale.Parent = rootFrame
	local function updateScale()
		local vs = gui.AbsoluteSize
		if vs.X > 0 and vs.Y > 0 then
			uiScale.Scale = clamp(math.min(vs.X / 760, vs.Y / 480), 0.68, 1.1)
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScale)
	updateScale()

	-- Barra de Status e Progresso da Habilidade Ativa (acima dos 3 botões)
	local statusBanner = Instance.new("CanvasGroup")
	statusBanner.Name = "StatusBanner"
	statusBanner.Size = UDim2.new(1, 0, 0, 32)
	statusBanner.Position = UDim2.fromOffset(0, 0)
	statusBanner.BackgroundColor3 = Color3.fromRGB(18, 15, 22)
	statusBanner.GroupTransparency = 1
	statusBanner.Visible = false
	statusBanner.Parent = rootFrame
	addCorner(statusBanner, 10)

	local bannerStroke = Instance.new("UIStroke")
	bannerStroke.Color = C.Energy
	bannerStroke.Thickness = 1.2
	bannerStroke.Transparency = 0.25
	bannerStroke.Parent = statusBanner

	local statusText = Instance.new("TextLabel")
	statusText.Size = UDim2.new(1, -24, 0, 18)
	statusText.Position = UDim2.fromOffset(12, 3)
	statusText.BackgroundTransparency = 1
	statusText.Font = Enum.Font.GothamBold
	statusText.TextSize = 12
	statusText.TextColor3 = Color3.new(1, 1, 1)
	statusText.TextXAlignment = Enum.TextXAlignment.Left
	statusText.Text = ""
	statusText.Parent = statusBanner

	local progBg = Instance.new("Frame")
	progBg.Size = UDim2.new(1, -24, 0, 5)
	progBg.Position = UDim2.fromOffset(12, 23)
	progBg.BackgroundColor3 = Color3.fromRGB(45, 36, 48)
	progBg.BorderSizePixel = 0
	progBg.Parent = statusBanner
	addCorner(progBg, 3)

	local progFill = Instance.new("Frame")
	progFill.Size = UDim2.fromScale(0, 1)
	progFill.BackgroundColor3 = C.EnergyHot
	progFill.BorderSizePixel = 0
	progFill.Parent = progBg
	addCorner(progFill, 3)

	HUD.statusBanner = statusBanner
	HUD.statusText = statusText
	HUD.progFill = progFill

	-- Linha com os 3 Botões (JUMP, NOCLIP, GANCHO)
	local buttonsRow = Instance.new("Frame")
	buttonsRow.Size = UDim2.new(1, 0, 0, 72)
	buttonsRow.Position = UDim2.fromOffset(0, 40)
	buttonsRow.BackgroundTransparency = 1
	buttonsRow.Parent = rootFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Horizontal
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	listLayout.Padding = UDim.new(0, 12)
	listLayout.Parent = buttonsRow

	HUD.buttons = {}

	for idx, meta in ipairs(ABILITY_META) do
		local card = Instance.new("Frame")
		card.Name = meta.id .. "Button"
		card.LayoutOrder = idx
		card.Size = UDim2.fromOffset(170, 68)
		card.BackgroundColor3 = Color3.fromRGB(22, 18, 26)
		card.BorderSizePixel = 0
		card.Parent = buttonsRow
		addCorner(card, 16)

		local cardScale = Instance.new("UIScale")
		cardScale.Parent = card

		local stroke = Instance.new("UIStroke")
		stroke.Color = meta.accent
		stroke.Thickness = 1.6
		stroke.Transparency = 0.2
		stroke.Parent = card

		local iconFrame = buildCustomIcon(card, meta.id)

		local titleLbl = Instance.new("TextLabel")
		titleLbl.Position = UDim2.fromOffset(58, 12)
		titleLbl.Size = UDim2.new(1, -66, 0, 20)
		titleLbl.BackgroundTransparency = 1
		titleLbl.Font = Enum.Font.GothamBlack
		titleLbl.TextSize = 15
		titleLbl.TextColor3 = Color3.new(1, 1, 1)
		titleLbl.TextXAlignment = Enum.TextXAlignment.Left
		titleLbl.Text = meta.title
		titleLbl.ZIndex = 4
		titleLbl.Parent = card

		local subLbl = Instance.new("TextLabel")
		subLbl.Position = UDim2.fromOffset(58, 32)
		subLbl.Size = UDim2.new(1, -66, 0, 14)
		subLbl.BackgroundTransparency = 1
		subLbl.Font = Enum.Font.GothamMedium
		subLbl.TextSize = 10
		subLbl.TextColor3 = Color3.fromRGB(178, 170, 186)
		subLbl.TextXAlignment = Enum.TextXAlignment.Left
		subLbl.Text = meta.sub
		subLbl.ZIndex = 4
		subLbl.Parent = card

		local keyBadge = Instance.new("TextLabel")
		keyBadge.AnchorPoint = Vector2.new(1, 0)
		keyBadge.Position = UDim2.new(1, -8, 0, 6)
		keyBadge.Size = UDim2.fromOffset(34, 14)
		keyBadge.BackgroundColor3 = Color3.fromRGB(38, 32, 46)
		keyBadge.Font = Enum.Font.GothamBold
		keyBadge.TextSize = 9
		keyBadge.TextColor3 = Color3.fromRGB(210, 205, 220)
		keyBadge.Text = meta.keyLabel
		keyBadge.ZIndex = 5
		keyBadge.Parent = card
		addCorner(keyBadge, 5)

		-- Barra de Cooldown + Overlay de Recarga / Bloqueio
		local cdOverlay = Instance.new("Frame")
		cdOverlay.Size = UDim2.fromScale(0, 1)
		cdOverlay.BackgroundColor3 = Color3.fromRGB(10, 8, 14)
		cdOverlay.BackgroundTransparency = 0.32
		cdOverlay.BorderSizePixel = 0
		cdOverlay.ZIndex = 6
		cdOverlay.Visible = false
		cdOverlay.Parent = card
		addCorner(cdOverlay, 16)

		local cdLabel = Instance.new("TextLabel")
		cdLabel.Size = UDim2.fromScale(1, 1)
		cdLabel.BackgroundTransparency = 1
		cdLabel.Font = Enum.Font.GothamBlack
		cdLabel.TextSize = 18
		cdLabel.TextColor3 = C.EnergyHot
		cdLabel.Text = ""
		cdLabel.ZIndex = 7
		cdLabel.Visible = false
		cdLabel.Parent = card

		local hitBtn = Instance.new("TextButton")
		hitBtn.Size = UDim2.fromScale(1, 1)
		hitBtn.BackgroundTransparency = 1
		hitBtn.Text = ""
		hitBtn.AutoButtonColor = false
		hitBtn.ZIndex = 10
		hitBtn.Parent = card

		hitBtn.InputBegan:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
				uiTween(cardScale, 0.08, { Scale = 0.93 })
			end
		end)
		local function onRelease()
			uiTween(cardScale, 0.28, { Scale = 1.0 }, Enum.EasingStyle.Back)
		end
		hitBtn.InputEnded:Connect(onRelease)
		hitBtn.MouseLeave:Connect(onRelease)
		hitBtn.Activated:Connect(function()
			onTriggerAbility(meta.id, false)
		end)

		HUD.buttons[meta.id] = {
			meta = meta,
			card = card,
			cardScale = cardScale,
			stroke = stroke,
			iconFrame = iconFrame,
			subLbl = subLbl,
			cdOverlay = cdOverlay,
			cdLabel = cdLabel,
		}
	end
end

function HUD.ShowStatus(textStr, progressFrac)
	if not HUD.statusBanner then
		return
	end
	if not HUD.statusBanner.Visible then
		HUD.statusBanner.Visible = true
		uiTween(HUD.statusBanner, 0.2, { GroupTransparency = 0 })
	end
	if textStr then
		HUD.statusText.Text = textStr
	end
	if progressFrac then
		HUD.progFill.Size = UDim2.fromScale(clamp01(progressFrac), 1)
	end
end

function HUD.HideStatus()
	if not HUD.statusBanner then
		return
	end
	uiTween(HUD.statusBanner, 0.25, { GroupTransparency = 1 })
	task.delay(0.26, function()
		if HUD.statusBanner and HUD.statusBanner.GroupTransparency >= 0.95 then
			HUD.statusBanner.Visible = false
		end
	end)
end

function HUD.RejectPulse(abilityId)
	local b = HUD.buttons and HUD.buttons[abilityId]
	if not b then
		return
	end
	task.spawn(function()
		uiTween(b.stroke, 0.08, { Color = Color3.fromRGB(255, 40, 40), Thickness = 2.6 })
		task.wait(0.18)
		uiTween(b.stroke, 0.2, { Color = b.meta.accent, Thickness = 1.6 })
	end)
end

function HUD.UpdateStates(activeAbilityId, cooldowns, now)
	if not HUD.buttons then
		return
	end
	for id, b in pairs(HUD.buttons) do
		local cdEnd = cooldowns[id] or 0
		local rem = math.max(0, cdEnd - now)
		local totalCd = CONFIG.Cooldowns[id] or 1
		local isExecutingThis = (activeAbilityId == id)
		local isLockedByOther = (activeAbilityId ~= nil and activeAbilityId ~= id)

		if isExecutingThis then
			b.cdOverlay.Visible = false
			b.cdLabel.Visible = false
			b.stroke.Color = Color3.new(1, 1, 1)
			b.stroke.Thickness = 2.4
			b.iconFrame.BackgroundColor3 = b.meta.accent
			b.subLbl.Text = "EM EXECUÇÃO..."
			b.subLbl.TextColor3 = C.EnergyHot
		elseif rem > 0 then
			local frac = clamp01(rem / totalCd)
			b.cdOverlay.Visible = true
			b.cdOverlay.Size = UDim2.fromScale(frac, 1)
			b.cdLabel.Visible = true
			b.cdLabel.Text = string.format("%.1fs", rem)
			b.stroke.Color = Color3.fromRGB(90, 82, 100)
			b.stroke.Thickness = 1.2
			b.iconFrame.BackgroundColor3 = Color3.fromRGB(28, 22, 30)
			b.subLbl.Text = "RECARREGANDO"
			b.subLbl.TextColor3 = Color3.fromRGB(130, 124, 140)
		elseif isLockedByOther then
			b.cdOverlay.Visible = true
			b.cdOverlay.Size = UDim2.fromScale(1, 1)
			b.cdLabel.Visible = false
			b.stroke.Color = Color3.fromRGB(75, 70, 84)
			b.stroke.Thickness = 1.0
			b.subLbl.Text = "BLOQUEADO"
			b.subLbl.TextColor3 = Color3.fromRGB(120, 115, 130)
		else
			b.cdOverlay.Visible = false
			b.cdLabel.Visible = false
			b.stroke.Color = b.meta.accent
			b.stroke.Thickness = 1.6
			b.iconFrame.BackgroundColor3 = Color3.fromRGB(34, 24, 30)
			b.subLbl.Text = b.meta.sub
			b.subLbl.TextColor3 = Color3.fromRGB(178, 170, 186)
		end
	end
end

--------------------------------------------------------------------------------
-- DIRETOR DE SESSÃO, CONTROLE DE CONCORRÊNCIA E CICLO DE VIDA (RESPAWN)
--------------------------------------------------------------------------------
local character = nil
local activeSession = nil
local activeAbilityId = nil
local cooldownEnds = { Jump = 0, Noclip = 0, Grapple = 0 }
local charConnections = {}

local function cleanupActiveSession(restoreAvatar)
	local s = activeSession
	activeSession = nil
	activeAbilityId = nil
	HUD.HideStatus()
	if not s then
		return
	end
	s.alive = false
	if s.renderConn then
		s.renderConn:Disconnect()
		s.renderConn = nil
	end
	for _, c in ipairs(s.extraConns) do
		c:Disconnect()
	end
	table.clear(s.extraConns)
	if noclipRemote then
		noclipRemote:FireServer("SetNoclip", false)
	end
	if restoreAvatar and s.rig then
		RigAdapter.RestoreAll(s.rig)
	end
	if s.renderer then
		s.renderer:Destroy()
	end
	if s.folder then
		s.folder:Destroy()
	end
end

local function triggerAbility(abilityId, fromHotkey)
	local now = os.clock()

	-- Se o jogador clicar novamente no botão GANCHO enquanto está apenas mirando, cancela a mira
	if activeAbilityId == "Grapple" and abilityId == "Grapple" and activeSession and activeSession.canCancelAim then
		cleanupActiveSession(true)
		return
	end

	-- Impede habilidades simultâneas ou em recarga
	if activeAbilityId ~= nil or (cooldownEnds[abilityId] and now < cooldownEnds[abilityId]) then
		HUD.RejectPulse(abilityId)
		return
	end

	local rig = RigAdapter.Read(character)
	if not rig then
		HUD.RejectPulse(abilityId)
		return
	end

	rig.humanoid:UnequipTools()

	local fxFolder = Instance.new("Folder")
	fxFolder.Name = "RegenMovesetFX_Local"
	fxFolder.Parent = Workspace

	local session = {
		alive = true,
		abilityId = abilityId,
		rig = rig,
		folder = fxFolder,
		renderer = Renderer.new(fxFolder),
		quality = resolveQuality(),
		fx = createFXRig(fxFolder),
		extraConns = {},
		stepFn = nil,
		canCancelAim = (abilityId == "Grapple"),
	}

	activeSession = session
	activeAbilityId = abilityId

	local function onStatus(msg, prog)
		if activeSession == session then
			if prog and prog > 0.12 then
				session.canCancelAim = false
			end
			HUD.ShowStatus(msg, prog)
		end
	end

	local function onProgress(prog)
		if activeSession == session then
			HUD.ShowStatus(nil, prog)
		end
	end

	local function onComplete()
		if activeSession ~= session then
			return
		end
		cooldownEnds[abilityId] = os.clock() + (CONFIG.Cooldowns[abilityId] or 8)
		cleanupActiveSession(true)
	end

	local function onCancelAim()
		if activeSession ~= session then
			return
		end
		cleanupActiveSession(true)
	end

	if abilityId == "Jump" then
		JumpAbility.Start(session, onStatus, onProgress, onComplete)
	elseif abilityId == "Noclip" then
		NoclipAbility.Start(session, onStatus, onProgress, onComplete)
	elseif abilityId == "Grapple" then
		local immediatePoint = fromHotkey and UserInputService:GetMouseLocation() or nil
		GrappleAbility.Start(session, immediatePoint, onStatus, onProgress, onComplete, onCancelAim)
	end

	session.renderConn = RunService.RenderStepped:Connect(function(dt)
		if not session.alive then
			return
		end
		if not rig.character or not rig.character.Parent or rig.humanoid.Health <= 0 then
			cleanupActiveSession(true)
			return
		end
		dt = math.min(dt, 0.1)
		if session.stepFn then
			session.stepFn(dt)
		end
		if session.alive and session.renderer then
			session.renderer:Flush()
		end
	end)
end

--------------------------------------------------------------------------------
-- INICIALIZAÇÃO, ATALHOS DE TECLADO E SUPORTE A RESPAWN
--------------------------------------------------------------------------------
local function onCharacterAdded(newChar)
	cleanupActiveSession(false)
	for _, c in ipairs(charConnections) do
		c:Disconnect()
	end
	table.clear(charConnections)

	character = newChar
	local hum = newChar:WaitForChild("Humanoid", 10)
	if not hum or character ~= newChar then
		return
	end

	table.insert(charConnections, hum.Died:Connect(function()
		cleanupActiveSession(true)
	end))
end

local function initialize()
	math.randomseed(math.floor(os.clock() * 1000))
	HUD.Create(triggerAbility)

	-- Loop leve de atualização visual dos timers de recarga na UI
	RunService.Heartbeat:Connect(function()
		HUD.UpdateStates(activeAbilityId, cooldownEnds, os.clock())
	end)

	-- Teclas de atalho para PC (Q/1 = Jump, E/2 = Noclip, F/3 = Gancho)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		for _, meta in ipairs(ABILITY_META) do
			for _, key in ipairs(meta.keys) do
				if input.KeyCode == key then
					triggerAbility(meta.id, true)
					return
				end
			end
		end
	end)

	player.CharacterAdded:Connect(onCharacterAdded)
	player.CharacterRemoving:Connect(function(oldChar)
		if oldChar == character then
			cleanupActiveSession(false)
			character = nil
		end
	end)

	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
end

initialize()
