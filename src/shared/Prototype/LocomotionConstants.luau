--!strict

local LocomotionConstants = {
	walkSpeed = 16,
	maxAccelerationForce = 50000,
	jumpHeight = 7.2,
	groundProbeLength = 6,
	groundedDistanceBuffer = 0,
	flySpeed = 40,
	flyVerticalSpeed = 28,
	flyMaxHeight = 30,
	flyProbeLength = 28,
	flyToggleDoubleTapWindow = 0.3,
	flyHeightEpsilon = 0.25,
	cruiseSpeed = 110,
	cruiseVerticalSpeed = 40,
	cruiseMinSpeed = 0,
	cruiseMaxSpeed = 1000,
	cruiseAcceleration = 28,
	cruiseBoostAcceleration = 72,
	cruiseDeceleration = 40,
	cruiseMaxForce = 120000,
	cruiseVelocityCorrectionGain = 3.5,
	cruiseLandingConfirmTime = 0.15,
	cruiseGroundProbeLength = 14,
	cruiseGroundProbeStartHeight = 2.5,
	cruiseGroundProbeRadiusScale = 1.8,
	cruiseLandingVerticalSpeedThreshold = 4,
}

return LocomotionConstants
