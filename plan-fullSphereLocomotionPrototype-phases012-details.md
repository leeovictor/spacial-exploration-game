## Full-Sphere Locomotion Prototype: Phases 0-2 Implementation Details

This document supports the main prototype plan by detailing the implementation shape for Phases 0, 1, and 2 only.

Scope of this document:
1. Files that should be created or edited.
2. Data structures that should be introduced.
3. Functions that should exist in each module and what each function is responsible for.

This document is intentionally design-oriented. It is not final code. The goal is to reduce ambiguity before implementation begins.

## Target Outcome For Phases 0-2

By the end of Phase 2, the project should support:
1. One playable spherical planet in a shared Roblox world.
2. A locally resolved gravity source for the player.
3. Stable local-up orientation aligned to the planet.
4. Curved-surface grounded movement using custom probing instead of world-down assumptions.
5. Jumping and landing relative to local up.
6. Debug instrumentation that makes the gravity and movement stack observable.

## Current Relevant Files

Existing files that should be reused or extended:
1. [src/client/init.client.luau](/home/leonardo/Projects/spacial-factory-game/src/client/init.client.luau)
2. [src/server/init.server.luau](/home/leonardo/Projects/spacial-factory-game/src/server/init.server.luau)
3. [src/shared/hooks/useSignal.luau](/home/leonardo/Projects/spacial-factory-game/src/shared/hooks/useSignal.luau)
4. [src/client/components/HUD.luau](/home/leonardo/Projects/spacial-factory-game/src/client/components/HUD.luau)
5. [src/client/UI/App.luau](/home/leonardo/Projects/spacial-factory-game/src/client/UI/App.luau)

## Proposed File Plan

### Files To Create

Shared configuration and math:
1. [src/shared/Prototype/LocomotionConstants.luau](/home/leonardo/Projects/spacial-factory-game/src/shared)
2. [src/shared/Prototype/PlanetDefinitions.luau](/home/leonardo/Projects/spacial-factory-game/src/shared)
3. [src/shared/Prototype/PrototypeTypes.luau](/home/leonardo/Projects/spacial-factory-game/src/shared)
4. [src/shared/Prototype/Math/GravityMath.luau](/home/leonardo/Projects/spacial-factory-game/src/shared)
5. [src/shared/Prototype/Math/SurfaceBasis.luau](/home/leonardo/Projects/spacial-factory-game/src/shared)

Server runtime:
6. [src/server/Prototype/PlanetBuilder.luau](/home/leonardo/Projects/spacial-factory-game/src/server)
7. [src/server/Prototype/PrototypeWorldService.luau](/home/leonardo/Projects/spacial-factory-game/src/server)
8. [src/server/Prototype/SpawnService.luau](/home/leonardo/Projects/spacial-factory-game/src/server)

Client runtime:
9. [src/client/Prototype/GravityResolver.luau](/home/leonardo/Projects/spacial-factory-game/src/client)
10. [src/client/Prototype/OrientationController.luau](/home/leonardo/Projects/spacial-factory-game/src/client)
11. [src/client/Prototype/GroundProbe.luau](/home/leonardo/Projects/spacial-factory-game/src/client)
12. [src/client/Prototype/LocomotionController.luau](/home/leonardo/Projects/spacial-factory-game/src/client)
13. [src/client/Prototype/PrototypeBootstrap.luau](/home/leonardo/Projects/spacial-factory-game/src/client)
14. [src/client/Prototype/DebugState.luau](/home/leonardo/Projects/spacial-factory-game/src/client)
15. [src/client/components/PrototypeDebugPanel.luau](/home/leonardo/Projects/spacial-factory-game/src/client/components)

### Files To Edit

1. [src/server/init.server.luau](/home/leonardo/Projects/spacial-factory-game/src/server/init.server.luau)
Purpose: bootstrap the server-side prototype world and spawn helpers.

2. [src/client/init.client.luau](/home/leonardo/Projects/spacial-factory-game/src/client/init.client.luau)
Purpose: bootstrap the locomotion prototype systems on the local client.

3. [src/client/UI/App.luau](/home/leonardo/Projects/spacial-factory-game/src/client/UI/App.luau)
Purpose: include the prototype debug panel in the UI tree.

4. [src/client/components/HUD.luau](/home/leonardo/Projects/spacial-factory-game/src/client/components/HUD.luau)
Purpose: either replace or temporarily augment the existing HUD with prototype state information.

## Directory Layout Recommendation

Recommended new structure:

```text
src/
  client/
    Prototype/
      DebugState.luau
      GravityResolver.luau
      GroundProbe.luau
      LocomotionController.luau
      OrientationController.luau
      PrototypeBootstrap.luau
    components/
      HUD.luau
      PrototypeDebugPanel.luau
  server/
    Prototype/
      PlanetBuilder.luau
      PrototypeWorldService.luau
      SpawnService.luau
    init.server.luau
  shared/
    Prototype/
      LocomotionConstants.luau
      PlanetDefinitions.luau
      PrototypeTypes.luau
      Math/
        GravityMath.luau
        SurfaceBasis.luau
```

## Phase 0 Implementation Details

### Purpose

Phase 0 should create the shared prototype contract. Nothing in later phases should invent new body scales, state names, or gravity thresholds ad hoc.

### Files In Scope

Create:
1. [src/shared/Prototype/PrototypeTypes.luau](/home/leonardo/Projects/spacial-factory-game/src/shared)
2. [src/shared/Prototype/LocomotionConstants.luau](/home/leonardo/Projects/spacial-factory-game/src/shared)
3. [src/shared/Prototype/PlanetDefinitions.luau](/home/leonardo/Projects/spacial-factory-game/src/shared)
4. [src/shared/Prototype/Math/GravityMath.luau](/home/leonardo/Projects/spacial-factory-game/src/shared)
5. [src/shared/Prototype/Math/SurfaceBasis.luau](/home/leonardo/Projects/spacial-factory-game/src/shared)

No file edits are strictly required in Phase 0 if this is done as shared setup first.

### Data Structures

#### `PlanetId`
```luau
export type PlanetId = "PlanetA" | "PlanetB" | "Moon" | "Star"
```

#### `PlanetDefinition`
```luau
export type PlanetDefinition = {
    id: PlanetId,
    displayName: string,
    center: Vector3,
    radius: number,
    surfaceGravity: number,
    influenceRadius: number,
    atmosphereHeight: number,
    handoffBias: number,
    isPlayable: boolean,
    isVisualOnly: boolean,
    debugColor: Color3,
}
```

#### `LocomotionState`
```luau
export type LocomotionState = "Grounded" | "Airborne" | "Transitioning"
```

#### `GravitySample`
```luau
export type GravitySample = {
    planetId: PlanetId,
    gravityDirection: Vector3,
    upDirection: Vector3,
    distanceToCenter: number,
    altitudeAboveSurface: number,
    isInsideInfluence: boolean,
}
```

#### `GroundProbeResult`
```luau
export type GroundProbeResult = {
    isGrounded: boolean,
    hitPosition: Vector3?,
    hitNormal: Vector3?,
    hitInstance: Instance?,
    distance: number?,
    slopeAngleDegrees: number?,
}
```

#### `PrototypeDebugSnapshot`
```luau
export type PrototypeDebugSnapshot = {
    activePlanetId: PlanetId?,
    locomotionState: LocomotionState,
    gravityDirection: Vector3?,
    upDirection: Vector3?,
    altitudeAboveSurface: number?,
    isGrounded: boolean,
    groundNormal: Vector3?,
    moveSpeed: number,
    slopeAngleDegrees: number?,
}
```

### Functions To Create

#### In `LocomotionConstants.luau`
1. `getMovementConstants()`
Returns the central tuning table for grounded movement, jump force, probe length, orientation smoothing, and debug toggles.

2. `getPrototypeScaleConstants()`
Returns system-wide scale values such as max expected travel distance, coordinate budget, and recommended test thresholds.

#### In `PlanetDefinitions.luau`
1. `getPlanetDefinitions()`
Returns the full map of prototype celestial body definitions.

2. `getPlanetDefinition(planetId)`
Returns one planet definition by id.

3. `getPlayablePlanetDefinitions()`
Returns only planets intended to be traversable during the prototype.

4. `getPrimarySpawnPlanetId()`
Returns the planet used for initial spawn and early traversal testing.

#### In `GravityMath.luau`
1. `computeDistanceToCenter(position, planetDefinition)`
Returns the distance between a world position and a planet center.

2. `computeAltitudeAboveSurface(position, planetDefinition)`
Returns distance to center minus the planet radius.

3. `isInsideInfluence(position, planetDefinition)`
Returns whether the world position is inside the planet influence radius.

4. `computeGravityDirection(position, planetDefinition)`
Returns a normalized vector pointing toward the planet center.

5. `computeUpDirection(position, planetDefinition)`
Returns the inverse of gravity direction.

6. `sampleGravity(position, planetDefinition)`
Returns a `GravitySample` containing all gravity-derived information for one body.

#### In `SurfaceBasis.luau`
1. `getSurfaceBasisFromUp(upDirection, forwardHint)`
Builds a stable tangent basis from local up and an optional forward hint.

2. `projectVectorOntoSurface(vector, upDirection)`
Projects a vector onto the tangent plane defined by local up.

3. `getSlopeAngleDegrees(surfaceNormal, upDirection)`
Computes the angle between the ground normal and local up for debugging and movement rules.

### Phase 0 Deliverable Intent

By the end of Phase 0:
1. Every later module should import shared constants instead of inventing them.
2. All prototype body data should live in one place.
3. All gravity math terminology should already be standardized.

## Phase 1 Implementation Details

### Purpose

Phase 1 should prove that one spherical body can define player up/down consistently and that the avatar can align to it.

### Files In Scope

Create:
1. [src/server/Prototype/PlanetBuilder.luau](/home/leonardo/Projects/spacial-factory-game/src/server)
2. [src/server/Prototype/PrototypeWorldService.luau](/home/leonardo/Projects/spacial-factory-game/src/server)
3. [src/server/Prototype/SpawnService.luau](/home/leonardo/Projects/spacial-factory-game/src/server)
4. [src/client/Prototype/GravityResolver.luau](/home/leonardo/Projects/spacial-factory-game/src/client)
5. [src/client/Prototype/OrientationController.luau](/home/leonardo/Projects/spacial-factory-game/src/client)
6. [src/client/Prototype/DebugState.luau](/home/leonardo/Projects/spacial-factory-game/src/client)
7. [src/client/Prototype/PrototypeBootstrap.luau](/home/leonardo/Projects/spacial-factory-game/src/client)
8. [src/client/components/PrototypeDebugPanel.luau](/home/leonardo/Projects/spacial-factory-game/src/client/components)

Edit:
9. [src/server/init.server.luau](/home/leonardo/Projects/spacial-factory-game/src/server/init.server.luau)
10. [src/client/init.client.luau](/home/leonardo/Projects/spacial-factory-game/src/client/init.client.luau)
11. [src/client/UI/App.luau](/home/leonardo/Projects/spacial-factory-game/src/client/UI/App.luau)

### Data Structures

#### `WorldPlanetRuntime`
```luau
export type WorldPlanetRuntime = {
    definition: PlanetDefinition,
    model: Model,
    surfacePart: BasePart,
    spawnPoints: { BasePart },
}
```

#### `GravityResolverState`
```luau
export type GravityResolverState = {
    activePlanetId: PlanetId?,
    activeSample: GravitySample?,
    lastStablePlanetId: PlanetId?,
}
```

#### `OrientationState`
```luau
export type OrientationState = {
    currentUp: Vector3?,
    targetUp: Vector3?,
    lastAppliedCFrame: CFrame?,
}
```

### Functions To Create

#### In `PlanetBuilder.luau`
1. `buildPlanetModel(planetDefinition)`
Creates a server-side model representing one prototype planet.

2. `buildPlanetSurface(planetDefinition)`
Creates the visible and collidable spherical body or shell for the planet.

3. `buildPlanetSpawnPoints(planetDefinition)`
Creates debug spawn markers around the surface at known test latitudes and orientations.

4. `tagPlanetParts(model, planetId)`
Applies attributes or tags to all relevant parts so they can be identified by client and debug systems.

#### In `PrototypeWorldService.luau`
1. `initializePrototypeWorld()`
Builds the prototype world at server startup.

2. `getPlanetRuntime(planetId)`
Returns the runtime structure for one built planet.

3. `getAllPlanetRuntimes()`
Returns all built planet runtimes.

#### In `SpawnService.luau`
1. `getSpawnCFrame(planetId, spawnName)`
Returns a stable surface-aligned spawn transform for a named test point.

2. `spawnCharacterOnPlanet(character, planetId, spawnName)`
Moves a player character to a specified planet spawn for testing.

3. `registerPlayerSpawns()`
Hooks spawn logic into player lifecycle for the prototype.

#### In `GravityResolver.luau`
1. `new(planetDefinitions)`
Creates a resolver instance for the local client.

2. `resolveActivePlanet(position)`
Returns the active gravity body for a world position.

3. `sampleActiveGravity(position)`
Returns the active `GravitySample` for the local player.

4. `getState()`
Returns the current `GravityResolverState`.

This module should stay simple in Phase 1. It only needs one active planet to work correctly.

#### In `OrientationController.luau`
1. `new(character)`
Creates an orientation controller bound to the local character.

2. `setTargetUpDirection(upDirection)`
Stores the target up direction for alignment.

3. `step(deltaTime, gravitySample)`
Applies orientation updates each frame so the avatar aligns to local up.

4. `reset()`
Clears controller state after respawn or character replacement.

#### In `DebugState.luau`
1. `new()`
Creates a mutable debug state store.

2. `setSnapshot(snapshot)`
Writes the latest debug snapshot.

3. `getSnapshot()`
Returns the latest snapshot for UI or logging.

4. `subscribe(listener)`
Allows debug UI to react to snapshot changes.

#### In `PrototypeBootstrap.luau`
1. `start()`
Bootstraps all Phase 1 client systems when the local character is ready.

2. `bindCharacter(character)`
Creates resolver, orientation controller, and debug bindings for the active character.

3. `unbindCharacter()`
Cleans up previous bindings on respawn.

4. `step(deltaTime)`
Runs the Phase 1 per-frame loop for gravity resolution, orientation updates, and debug snapshot refresh.

#### In `PrototypeDebugPanel.luau`
1. `PrototypeDebugPanel(props)`
React component that displays active planet id, altitude, gravity vector, and local up.

### Phase 1 Bootstrap Changes

#### `src/server/init.server.luau`
Should do the following:
1. Require `PrototypeWorldService`.
2. Require `SpawnService`.
3. Initialize the world once at server start.
4. Register player spawn behavior.

#### `src/client/init.client.luau`
Should do the following:
1. Require `PrototypeBootstrap`.
2. Start the prototype runtime after the current UI mount or alongside it.

#### `src/client/UI/App.luau`
Should do the following:
1. Render `PrototypeDebugPanel` in addition to the current HUD, or replace the current HUD during prototype mode.

### Phase 1 Deliverable Intent

By the end of Phase 1:
1. The player should spawn on Planet A.
2. Gravity should resolve against Planet A.
3. The avatar should align to local up.
4. The debug panel should confirm what the system thinks is happening.

## Phase 2 Implementation Details

### Purpose

Phase 2 should turn gravity alignment into playable curved-surface locomotion.

### Files In Scope

Create:
1. [src/client/Prototype/GroundProbe.luau](/home/leonardo/Projects/spacial-factory-game/src/client)
2. [src/client/Prototype/LocomotionController.luau](/home/leonardo/Projects/spacial-factory-game/src/client)

Edit:
3. [src/client/Prototype/PrototypeBootstrap.luau](/home/leonardo/Projects/spacial-factory-game/src/client)
4. [src/client/Prototype/DebugState.luau](/home/leonardo/Projects/spacial-factory-game/src/client)
5. [src/client/components/PrototypeDebugPanel.luau](/home/leonardo/Projects/spacial-factory-game/src/client/components)
6. [src/shared/Prototype/LocomotionConstants.luau](/home/leonardo/Projects/spacial-factory-game/src/shared)
7. [src/shared/Prototype/PrototypeTypes.luau](/home/leonardo/Projects/spacial-factory-game/src/shared)

### Data Structures

#### `GroundProbeConfig`
```luau
export type GroundProbeConfig = {
    probeLength: number,
    characterClearance: number,
    collisionFilter: RaycastParams,
}
```

#### `LocomotionInput`
```luau
export type LocomotionInput = {
    moveVector: Vector3,
    wantsJump: boolean,
}
```

#### `LocomotionFrameContext`
```luau
export type LocomotionFrameContext = {
    deltaTime: number,
    gravitySample: GravitySample,
    groundProbe: GroundProbeResult,
    input: LocomotionInput,
}
```

#### `LocomotionRuntimeState`
```luau
export type LocomotionRuntimeState = {
    locomotionState: LocomotionState,
    desiredMoveDirection: Vector3,
    surfaceMoveDirection: Vector3,
    currentSpeed: number,
    jumpCooldownRemaining: number,
}
```

### Functions To Create

#### In `GroundProbe.luau`
1. `new(character, config)`
Creates a probe helper bound to the current character.

2. `probe(gravitySample)`
Casts from the character root along gravity direction and returns a `GroundProbeResult`.

3. `buildRaycastParams(character)`
Creates collision filters that ignore the local character and any excluded debug objects.

4. `isValidGroundHit(result, gravitySample)`
Returns whether the probe hit should count as ground for Phase 2 movement.

5. `reset()`
Clears cached state across respawn.

#### In `LocomotionController.luau`
1. `new(character, constants)`
Creates the movement controller for the current character.

2. `readInput()`
Reads current player movement intent and jump intent.

3. `computeSurfaceMoveDirection(input, gravitySample, facingReference)`
Converts input into a tangent-plane move vector aligned to the planet surface.

4. `step(deltaTime, gravitySample, groundProbeResult)`
Runs the Phase 2 movement update for the current frame.

5. `stepGrounded(context)`
Applies grounded acceleration, deceleration, friction, and tangent movement.

6. `stepAirborne(context)`
Applies airborne movement behavior for the early prototype before flight exists.

7. `tryJump(context)`
Applies jump impulse aligned to local up if grounded and off cooldown.

8. `applyMoveVelocity(moveDirection, speed)`
Writes the intended tangential motion to the character root or movement mechanism.

9. `applyJumpImpulse(upDirection)`
Applies local-up jump force.

10. `updateState(context)`
Transitions between `Grounded` and `Airborne`.

11. `getRuntimeState()`
Returns the current `LocomotionRuntimeState` for debug display.

12. `reset()`
Clears movement state during respawn.

#### In `PrototypeBootstrap.luau`
Additional responsibilities in Phase 2:
1. Create a `GroundProbe` instance after character bind.
2. Create a `LocomotionController` instance after character bind.
3. In the per-frame step, sample gravity, run the ground probe, step locomotion, then refresh debug state.
4. Ensure cleanup happens in the right order on respawn.

#### In `PrototypeDebugPanel.luau`
Additional displayed values:
1. grounded state
2. ground normal
3. slope angle
4. current movement speed
5. locomotion state

### Movement Design Rules For Phase 2

These rules should be kept explicit during implementation:
1. Movement input should be projected onto the tangent plane defined by local up.
2. Grounded motion should never apply force toward or away from the planet center except for jump and ground correction.
3. Jumping should use local up, not world Y.
4. Grounded state should come from probe results, not from default Humanoid floor assumptions.
5. The debug overlay should always expose whether the controller believes the player is grounded.

### Proposed Integration Order Inside Phase 2

1. Add ground probing and make the results visible in debug UI.
2. Add locomotion state transitions without movement first.
3. Add tangent-plane move vector calculation.
4. Add grounded acceleration and deceleration.
5. Add jumping.
6. Add slope handling and retuning.
7. Run the full-loop traversal test on Planet A.

This order matters because it makes failures easier to localize.

## File Responsibilities Summary

### Shared
1. `PrototypeTypes.luau`
Owns shared types used by server and client prototype modules.

2. `LocomotionConstants.luau`
Owns tuning constants and limits for Phases 0-2.

3. `PlanetDefinitions.luau`
Owns the source of truth for celestial body layout.

4. `GravityMath.luau`
Owns pure gravity calculations.

5. `SurfaceBasis.luau`
Owns tangent-plane and local frame math.

### Server
1. `PlanetBuilder.luau`
Owns creation of prototype planet geometry and spawn points.

2. `PrototypeWorldService.luau`
Owns server startup world assembly.

3. `SpawnService.luau`
Owns player placement on the spherical test world.

### Client
1. `GravityResolver.luau`
Owns active gravity body resolution for the local player.

2. `OrientationController.luau`
Owns avatar alignment to local up.

3. `GroundProbe.luau`
Owns local-up-aware ground detection.

4. `LocomotionController.luau`
Owns curved-surface movement and jumping.

5. `PrototypeBootstrap.luau`
Owns wiring all client prototype systems together.

6. `DebugState.luau`
Owns current prototype diagnostics.

7. `PrototypeDebugPanel.luau`
Owns rendering prototype debug data to the screen.

## Recommended First Build Order

1. Create shared types and constants.
2. Create planet definitions and shared gravity math.
3. Create server planet builder and world bootstrap.
4. Create client gravity resolver.
5. Create orientation controller and spawn testing.
6. Add debug panel and debug state.
7. Add ground probe.
8. Add locomotion controller.
9. Expand debug state and run traversal tests.

## Explicit Non-Goals For Phases 0-2

Do not add these yet:
1. flight controller
2. second planet gravity handoff logic
3. camera replacement
4. placement probe
5. multiplayer correction systems
6. resource or building gameplay

Those belong to later phases and should not complicate the Phase 0-2 implementation surface.

## Success Criteria For This Detailed Scope

The design described here is sufficient only if it supports these checkpoints:
1. The repo has a single shared source of truth for planet definitions and locomotion constants.
2. The server can build Planet A and spawn a player on it.
3. The client can resolve local gravity and align the avatar to the planet.
4. The client can detect ground using local gravity direction.
5. The player can walk and jump along the curved surface with visible debug state.

If any of those remain structurally undefined during implementation, the document should be revised before coding proceeds.
