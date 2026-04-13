--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocomotionConstants = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Prototype"):WaitForChild("LocomotionConstants")
) :: any
local LocomotionState =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Prototype"):WaitForChild("LocomotionState")) :: any

type TrackMap = {
	[string]: AnimationTrack,
}

local ANIMATION_TRANSITION_TIME = 0.15

local function ensureAnimator(humanoid: Humanoid): Animator
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator ~= nil then
		return animator
	end

	local newAnimator = Instance.new("Animator")
	newAnimator.Parent = humanoid
	return newAnimator
end

local function getFirstAnimationId(container: Instance?): string?
	if container == nil then
		return nil
	end

	for _, child in container:GetChildren() do
		if child:IsA("Animation") and child.AnimationId ~= "" then
			return child.AnimationId
		end
	end

	return nil
end

local function loadTrack(
	animator: Animator,
	animationId: string?,
	looped: boolean,
	priority: Enum.AnimationPriority
): AnimationTrack?
	if animationId == nil or animationId == "" then
		return nil
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = animationId

	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	animation:Destroy()

	if not ok or not track then
		return nil
	end

	track.Looped = looped
	track.Priority = priority

	return track
end

local function buildTracks(animator: Animator, animateScript: Instance?): TrackMap
	local tracks: TrackMap = {}

	local idleTrack = loadTrack(
		animator,
		getFirstAnimationId(animateScript and animateScript:FindFirstChild("idle")),
		true,
		Enum.AnimationPriority.Idle
	)
	if idleTrack ~= nil then
		tracks[LocomotionState.Idle] = idleTrack
	end

	local walkTrack = loadTrack(
		animator,
		getFirstAnimationId(animateScript and animateScript:FindFirstChild("walk")),
		true,
		Enum.AnimationPriority.Movement
	)
	if walkTrack ~= nil then
		tracks[LocomotionState.Walk] = walkTrack
	end

	local jumpTrack = loadTrack(
		animator,
		getFirstAnimationId(animateScript and animateScript:FindFirstChild("jump")),
		false,
		Enum.AnimationPriority.Action
	)
	if jumpTrack ~= nil then
		tracks[LocomotionState.Jump] = jumpTrack
	end

	local fallTrack = loadTrack(
		animator,
		getFirstAnimationId(animateScript and animateScript:FindFirstChild("fall")),
		true,
		Enum.AnimationPriority.Action
	)
	if fallTrack ~= nil then
		tracks[LocomotionState.Fall] = fallTrack
	end

	return tracks
end

local CharacterAnimationController = {}

function CharacterAnimationController.attach(character: Model): (() -> ())?
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	local rootPart = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if humanoid == nil or rootPart == nil then
		return nil
	end

	local animator = ensureAnimator(humanoid)
	local animateScript = character:FindFirstChild("Animate")
	local previousAnimateDisabled: boolean? = nil

	if animateScript ~= nil and animateScript:IsA("LocalScript") then
		previousAnimateDisabled = animateScript.Disabled
		animateScript.Disabled = true
	end

	local tracks = buildTracks(animator, animateScript)
	local activeState = LocomotionState.Idle
	local activeTrack: AnimationTrack? = nil

	local function setActiveTrack(stateName: string)
		if activeState == stateName and activeTrack ~= nil then
			return
		end

		local nextTrack = tracks[stateName] or tracks[LocomotionState.Idle]
		if activeTrack == nextTrack then
			activeState = stateName
			return
		end

		if activeTrack ~= nil then
			activeTrack:Stop(ANIMATION_TRANSITION_TIME)
		end

		activeState = stateName
		activeTrack = nextTrack

		if activeTrack ~= nil then
			activeTrack:Play(ANIMATION_TRANSITION_TIME)
		end
	end

	local function updateAnimationState()
		local nextState = character:GetAttribute(LocomotionState.attributeName)
		if type(nextState) ~= "string" then
			nextState = LocomotionState.Idle
		end

		setActiveTrack(nextState :: string)
		if activeTrack ~= nil and nextState == LocomotionState.Walk then
			local speedScale =
				math.clamp(rootPart.AssemblyLinearVelocity.Magnitude / LocomotionConstants.walkSpeed, 0.85, 1.35)
			activeTrack:AdjustSpeed(speedScale)
		elseif activeTrack ~= nil then
			activeTrack:AdjustSpeed(1)
		end
	end

	updateAnimationState()

	local stateConn = character:GetAttributeChangedSignal(LocomotionState.attributeName):Connect(updateAnimationState)
	local heartbeatConn = RunService.Heartbeat:Connect(function()
		if activeState == LocomotionState.Walk and activeTrack ~= nil then
			local speedScale =
				math.clamp(rootPart.AssemblyLinearVelocity.Magnitude / LocomotionConstants.walkSpeed, 0.85, 1.35)
			activeTrack:AdjustSpeed(speedScale)
		end
		if activeState == LocomotionState.Jump and activeTrack ~= nil and not activeTrack.IsPlaying then
			setActiveTrack(LocomotionState.Fall)
		end
	end)

	local cleaned = false
	local function cleanup()
		if cleaned then
			return
		end
		cleaned = true

		stateConn:Disconnect()
		heartbeatConn:Disconnect()

		for _, track in tracks do
			track:Stop(0)
			track:Destroy()
		end

		if animateScript ~= nil and animateScript:IsA("LocalScript") and previousAnimateDisabled ~= nil then
			animateScript.Disabled = previousAnimateDisabled
		end
	end

	humanoid.Died:Once(cleanup)

	return cleanup
end

return CharacterAnimationController
