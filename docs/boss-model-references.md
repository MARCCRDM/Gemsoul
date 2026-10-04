# Boss model references

The dungeon skins are original Roblox-part reconstructions guided by the visible models below. They are not imported copies of those meshes. Existing R15 Motor6Ds and RivalPose still drive combat; invisible driver parts retain the existing hit detection. Native shapes are welded, massless and non-colliding.

| Character | Model reference | Rebuilt identifying features |
| --- | --- | --- |
| Tung Tung Tung Sahur | [davidjohnrandom on Sketchfab](https://sketchfab.com/3d-models/tung-tung-tung-sahur-0728d32428fd4b0d984359c5afc418a9) | Continuous cylindrical timber body, wood grain, expressive eyes and nose, slim limbs, fingers, bare toes, long bat. |
| Tralalero Tralala | [Eks.Art on Sketchfab](https://sketchfab.com/3d-models/tralalero-tralala-091fffbf2972484f9c35c8a2ec8916f3) | Horizontal shark, pale belly, open jaw, teeth, gills, dorsal fin, forked tail, three blue sneakers with soles and laces. |
| Brr Brr Patapim | [KAG3D on Sketchfab](https://sketchfab.com/3d-models/brr-brr-patapim-8fbb2c0103474c5fb10686b762e98de5) | Moss hood and trunk, long pendulous nose, root limbs, oversized bare feet and toes. |
| Bombardiro Crocodilo | [Aizen on Sketchfab](https://sketchfab.com/3d-models/bombardiro-crocodilo-db92444b3c064933a6f8ae31b0c27810) | Horizontal crocodile-fuselage, long open jaws, staggered teeth, cockpit, broad wings, propellers, yellow leading edges and aircraft tail. |

Element colors are restrained accents on the bat, dorsal edge, spores and engines. Bosses use the same creatures at 1.8x scale. The crocodile visually hovers on the existing ground-navigation controller; this is not a new flight AI. Its propellers are currently static geometry. The shark's third foot follows the pelvis, while its other feet use the existing walking joints.

## Preview and verification

Run `tools/render_boss_previews.py` with numpy and Pillow installed. It executes the actual Luau skin builders, exports their geometry and renders the four previews in `docs/boss-previews/`. Transparent driver parts are excluded. These are neutral-pose geometry renders with simplified lighting, not Roblox Studio screenshots.

Studio playtesting is still required for moving silhouettes, terrain clearance, camera proximity and multiplayer readability. Imported production meshes and custom creature-specific animation clips would be a separate asset pass.

## Tung Tung combat animation pass

- The bat now uses the same -120-degree fist mount as the Warrior weapons, so its barrel follows the existing slash and overhead-heavy poses instead of hanging backward from the fist.
- `CombatPoseProfile = SahurBat` selects a bat guard and right-arm block recoil in the shared RivalPose module. All seven existing action timelines and ordinary hit reactions remain shared.
- Existing server-played R15 idle/walk/run tracks and the dungeon actor pose loop are retained. The continuous timber body follows Waist; the face intentionally stays with the log rather than bending independently at Neck.
- `tools/render_sahur_poses.py` renders the actual Motor6D hierarchy and skin attachment transforms at ready, heavy wind-up, heavy impact and guard. The sheet omits live locomotion tracks and temporal smoothing; it is a geometry diagnostic, not proof of Roblox runtime playback.
- Combat regression suite passes, including Sahur action parity at seven timestamps per action, bat guard, block recoil and body flinch. Rojo build succeeds. Studio multiplayer playback and animation asset loading are not verified in this environment.
