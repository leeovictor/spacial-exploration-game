## Plan: Full-Sphere Locomotion Prototype

Validate whether the project can support literal spherical planets in one shared Roblox world by building a locomotion-first vertical slice. The prototype should prove custom gravity, curved-surface walking, scriptable camera, flight transition, two-planet gravity handoff, and one surface-aligned placement interaction before any factory systems are attempted.

**Phases**

### Phase 0: Prototype Envelope

**Goal**
Lock the physical scale, visual scope, and technical constraints so later phases are testing one stable target instead of a moving spec.

**Implementation steps**

1. Define the prototype bodies in shared config: Planet A, Planet B, Moon, Star.
2. Set compressed radii and distances that keep the entire micro-system well inside stable coordinate space.
3. Decide the first-pass gravity model per body: surface gravity, influence radius, atmosphere band, flight handoff band.
4. Decide which bodies are gameplay-relevant versus visual-only.
5. Decide the first-pass player states: grounded, airborne, flight, transitioning.
6. Record hard stop conditions for the prototype: if controller stability or camera readability fail, do not move to factory systems.

**Execution notes**

- This phase blocks all other phases.
- Do not spend time on art polish here.
- Keep the solar system stylized and compressed.

**Deliverables**

- Shared constant table for prototype celestial bodies.
- Written scale sheet with agreed radii and distances.
- Written locomotion state list and transition rules.

**Verification**

1. Review the scale sheet against Roblox part size and origin constraints.
2. Confirm the farthest active gameplay body remains comfortably inside the intended coordinate budget.
3. Confirm Planet A and Planet B can both be visible in one shared world at the chosen scale.

### Phase 1: Single-Planet Gravity Lock

**Goal**
Prove a character can exist on one spherical planet with a stable custom up vector and gravity source.

**Implementation steps**

1. Add a shared planet definition module for Planet A center, radius, gravity strength, influence radius, and metadata.
2. Build a first server-side planet model or shell in Workspace for Planet A.
3. Add a client locomotion bootstrap that resolves the current gravity source for the local player.
4. Compute gravity direction as the normalized vector from player position toward the active planet center.
5. Derive local up as the inverse of gravity direction.
6. Apply character orientation so the avatar aligns to local up instead of world Y.
7. Add a debug overlay showing active body id, gravity direction, local up, and distance to planet center.
8. Add debug spawn points around the sphere to force testing at different latitudes and orientations.

**Execution notes**

- Keep this phase single-planet only.
- Do not attempt walking polish yet; just prove stable attachment and orientation.
- Character respawn handling must restore the gravity body cleanly.

**Deliverables**

- Planet definition data.
- Planet A geometry in Workspace.
- Gravity-source selection for one body.
- Orientation alignment layer.
- Debug overlay and spawn commands.

**Verification**

1. Spawn at equator, high latitude, opposite hemisphere, and near steep contour changes.
2. Respawn repeatedly at those locations.
3. Confirm the avatar never flips unpredictably, loses local up, or drifts into world-down behavior.
4. Confirm debug readouts stay coherent during respawn and teleport.

### Phase 2: Grounded Walking On Curvature

**Goal**
Prove the player can walk, stop, and jump around the curved surface instead of only being pulled toward it.

**Implementation steps**

1. Add a ground probing system that casts along the local gravity direction rather than world-down.
2. Compute ground normal and grounded state from the probe result.
3. Build tangent-plane movement so player input moves along the planet surface.
4. Add grounded acceleration, deceleration, friction, and slope rules.
5. Add jump impulse aligned to local up.
6. Add grounded-to-airborne transition rules and landing recovery.
7. Expand the debug overlay with grounded state, ground normal, move speed, and slope angle.
8. Add a full-loop traversal test route around Planet A.

**Execution notes**

- This phase should not depend on stock world-down floor logic.
- Prioritize predictability over realism.
- If slope behavior is unstable, reduce complexity and retune before continuing.

**Deliverables**

- Local gravity-aware ground probe.
- Tangent-plane movement controller.
- Jump and landing logic.
- Expanded movement diagnostics.

**Verification**

1. Walk a full loop around Planet A without controller failure.
2. Stop on slopes and verify the avatar does not slide or vibrate unintentionally.
3. Jump and land on different parts of the sphere, including areas that are upside-down relative to world Y.
4. Hold movement input while crossing the visual horizon and confirm direction remains intuitive.

### Phase 3: Camera Stability Layer

**Goal**
Prove the player can read the world comfortably while moving on a sphere.

**Implementation steps**

1. Switch the local player camera to Scriptable mode.
2. Build a camera state model with yaw around local up and pitch around camera-local right.
3. Compute desired camera offset relative to the avatar using the curved-surface basis.
4. Update Camera.CFrame and Camera.Focus every frame.
5. Add smoothing to camera position and orientation changes.
6. Add collision handling with raycasts or shape checks to prevent camera clipping into terrain or planet geometry.
7. Add debug controls for camera distance and optional zoom lock.
8. Add camera diagnostics: distance, pitch, collision status, and current local up.

**Execution notes**

- Keep roll controlled; do not let the camera constantly inherit character roll.
- Camera readability is a stop/go gate for the whole prototype.
- Mouse and gamepad should both be considered if practical during testing.

**Deliverables**

- Scriptable curved-world third-person camera.
- Camera collision logic.
- Camera diagnostics and tuning constants.

**Verification**

1. Run around the planet quickly while rotating the camera continuously.
2. Jump near horizon lines and steep silhouettes.
3. Test close camera, far camera, and rapid direction changes.
4. Confirm the camera remains readable and does not oscillate, roll unpleasantly, or lose the character.

**Go/No-Go Review A**

1. If Phase 2 and Phase 3 are both stable, continue.
2. If grounded movement works but the camera remains disorienting after focused tuning, stop and reconsider the literal full-sphere direction.
3. If both movement and camera are unstable, do not proceed to flight or multi-planet work.

### Phase 4: Transition To Flight

**Goal**
Prove the player can leave the surface and enter a controllable space/air movement mode.

**Implementation steps**

1. Define a flight activation rule: altitude threshold, jump assist, or explicit toggle for testing.
2. Add a flight controller separate from grounded movement.
3. Reduce or replace grounded locomotion forces when outside the surface band.
4. Define steering, acceleration, deceleration, and turn behavior for flight.
5. Add re-entry detection as the player approaches a planet surface.
6. Add a landing recovery path that cleanly returns the player to grounded mode.
7. Add debug controls to force flight on/off during test sessions.
8. Add diagnostics for altitude, active movement mode, flight speed, and re-entry status.

**Execution notes**

- Keep flight arcade-simple for the prototype.
- Do not chase realistic orbital mechanics.
- The important result is a stable transition, not a realistic spacecraft simulation.

**Deliverables**

- Flight controller.
- Surface-to-flight and flight-to-surface transition rules.
- Flight diagnostics and debug toggles.

**Verification**

1. Leave the planet at low and high speeds.
2. Circle Planet A in free space.
3. Re-enter from multiple approach angles.
4. Confirm the player can land without losing orientation or entering invalid states.

### Phase 5: Two-Planet Gravity Handoff

**Goal**
Prove multiple gravity wells can coexist in one shared world and the player can travel from one planet to another.

**Implementation steps**

1. Add Planet B definitions with independent radius, gravity, and influence radius.
2. Add Planet B geometry and collision shell to the world.
3. Extend gravity-source selection to evaluate multiple bodies in range.
4. Add hysteresis or lock rules so the active gravity body does not flicker near boundaries.
5. Define neutral or low-influence travel space between planets.
6. Add landing targets or clear safe approach regions on Planet B.
7. Add simple moon and star visuals only after two-body switching is stable.
8. Expand debug diagnostics with nearest-body distances, active-body lock timer, and handoff state.

**Execution notes**

- Planet B should be added only after Planet A traversal is already stable.
- Body switching should be discrete and readable, not constantly blended.
- The moon and star remain visual-only in this phase.

**Deliverables**

- Two-planet shared-world setup.
- Multi-body gravity-source resolver.
- Handoff hysteresis rules.
- Planet B landing area.

**Verification**

1. Launch from Planet A and land on Planet B from multiple vectors.
2. Hover near the midpoint or handoff boundary and verify the active source does not flicker.
3. Land on Planet B and perform the same basic walking checks as on Planet A.
4. Confirm the active gravity body shown in debug state always matches player expectation.

**Go/No-Go Review B**

1. If interplanet travel and handoff are stable, continue.
2. If body handoff remains unreliable after targeted iteration, stop before investing in placement or multiplayer.
3. If landing on Planet B is substantially less stable than Planet A, treat the multi-body model as unproven.

### Phase 6: Surface-Aligned Placement Probe

**Goal**
Prove future factory systems can at least place objects coherently on curved surfaces.

**Implementation steps**

1. Add a placement probe that raycasts from the camera or cursor toward the planet surface.
2. Compute the surface normal at the hit point.
3. Build a local tangent basis at the hit point for object orientation.
4. Add a ghost placement preview aligned to the surface normal.
5. Add rotation around local up so the preview can be adjusted consistently on curved terrain.
6. Add a simple confirm action to place a test prop.
7. Add debug readouts for hit normal, tangent basis, rotation angle, and placement validity.
8. Add a few sample placement surfaces on both planets, including slopes.

**Execution notes**

- Only one simple prop is needed.
- This phase is about geometric correctness, not build UX polish.
- If surface alignment feels arbitrary, later factory placement will be much harder.

**Deliverables**

- Placement probe.
- Surface-aligned ghost preview.
- Confirmed test prop placement.
- Placement diagnostics.

**Verification**

1. Place the test object on equator, higher latitudes, and steep slopes.
2. Rotate the ghost around local up and confirm the final orientation is consistent.
3. Repeat on Planet B.
4. Confirm the object never embeds incorrectly or points in obviously invalid directions.

### Phase 7: Multiplayer Sanity Check

**Goal**
Prove the locomotion stack is not single-player-only and remains visually coherent with multiple players.

**Implementation steps**

1. Define which locomotion state is authoritative locally versus validated by the server.
2. Add basic server handling for spawn, respawn, and replication-safe initialization on curved planets.
3. Ensure remote avatars replicate orientation consistent with their local up/gravity source.
4. Validate that grounded, flight, and landing states remain coherent for observers.
5. Add test hooks for placing two players on the same planet and on different planets.
6. Add debug display or logging for local and observed remote gravity-source state.
7. Document any replication anomalies or correction strategies discovered.
8. Keep server corrections minimal during the first sanity pass; the goal is to expose issues, not solve all of them.

**Execution notes**

- This phase should happen only after single-player traversal is proven.
- Expect to discover edge cases in remote orientation and state replication.
- Do not overbuild anti-cheat or heavy reconciliation in this prototype.

**Deliverables**

- Basic multiplayer initialization and observation support.
- Remote avatar orientation replication.
- Multiplayer debug scenarios.

**Verification**

1. Test two players on Planet A.
2. Test one player on Planet A and one on Planet B.
3. Test one player in flight while another observes from a planet surface.
4. Confirm remote avatars remain upright relative to their active planet and do not appear world-down to observers.

**Cross-Cutting Work**

1. Maintain a debug overlay throughout all phases.
2. Keep prototype constants centralized so tuning does not sprawl.
3. Prefer simple test geometry and deliberate spawn points over handcrafted content.
4. Log failure cases immediately after each test session.
5. Treat camera readability and gravity-source stability as hard gates.

**Suggested Workspace Targets**

- Existing file to extend for server bootstrap: /home/leonardo/Projects/spacial-factory-game/src/server/init.server.luau
- Existing file to extend for client bootstrap: /home/leonardo/Projects/spacial-factory-game/src/client/init.client.luau
- Existing shared root for prototype modules: /home/leonardo/Projects/spacial-factory-game/src/shared
- Existing client root for camera and locomotion client modules: /home/leonardo/Projects/spacial-factory-game/src/client
- Existing shared hooks/components area if debug UI is later rendered through React: /home/leonardo/Projects/spacial-factory-game/src/shared/hooks and /home/leonardo/Projects/spacial-factory-game/src/client/components

**Recommended Module Breakdown**

1. Shared data/config modules
   - PlanetDefinitions
   - LocomotionConstants
   - PlacementConstants
2. Client runtime modules
   - GravityResolver
   - GroundProbe
   - LocomotionController
   - FlightController
   - PlanetCameraController
   - PlacementProbe
   - DebugOverlayController
3. Server runtime modules
   - PlanetRuntimeService
   - PlayerSpawnService
   - PrototypeValidationService

**Prototype Success Criteria**

1. A player can complete a full loop around Planet A on foot.
2. Jumping and landing work around the sphere.
3. The camera remains readable during curved traversal.
4. The player can enter flight, travel, and land on Planet B.
5. Gravity-source handoff between planets is stable.
6. A surface-aligned test object can be placed on both planets.
7. Two players can observe each other without obvious orientation breakage.

**Prototype Failure Criteria**

1. Orientation jitter remains common after focused tuning.
2. Camera discomfort or disorientation remains frequent.
3. Planet handoff continues to flicker or misselect bodies.
4. Placement alignment is too inconsistent for future factory systems.
5. Remote players appear visibly incorrect or unstable in common scenarios.

**Out of Scope**

1. Real factory production systems.
2. Interplanetary cargo automation.
3. Advanced art polish.
4. Full resource loop.
5. Combat or hazards.
6. Realistic orbital mechanics.

**Verification Milestones**

1. Review A after Phase 3: single-planet locomotion and camera.
2. Review B after Phase 5: interplanet travel and handoff.
3. Final review after Phase 7: placement feasibility and multiplayer sanity.

**Decision Rule**
If Review A fails, stop the literal full-sphere path. If Review A passes but Review B fails, reconsider whether literal shared-world planets are worth the extra complexity. Only if Review B passes should the project begin adapting building, mining, and later automation systems to the curved-world model.
