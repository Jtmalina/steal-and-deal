extends RefCounted
class_name GameData

# ============================================================
#  STEAL AND DEAL  --  static game data
#  Everything here is data-driven so new cars / parts / tools
#  can be added without touching gameplay code.
# ============================================================

# ---------- TEARDOWN ----------
# Parts come off the car in 3D with the mouse. A part is an ordered list of
# STAGES; every prop in a stage must be dealt with before the next unlocks.
#   type:  "BOLT"  turn the mouse anticlockwise -- lefty loosey
#          "CLAMP" same, but a battery terminal
#          "PLUG"  drag the connector straight out, steadily, or it snaps
#          "CUT"   drag back and forth across the cut, watch the blade heat
#          "PULL"  drag the freed part off the car
#          "PUMP"  drag the jack handle down and up
#          "SCAN"  hold a key reader against the lock and keep the hand still
#   at:    exact spots on the car, in the vehicle local space. These are the
#          real fastener positions -- hinge bolts on the hinges, lug nuts on
#          the hub, mount bolts down in the engine bay.
#   dir:   which way the fastener backs out / the part comes off.
#   cam:   where the camera watches the job from.
const PARTS := {
	"hood": {
		"name": "Hood", "base_value": 55, "mass": 25, "size": 2,
		"needs": "", "lifted": false, "after": [],
		"stages": [
			{"type": "BOLT", "label": "Four hinge bolts, both hinges, back edge",
			 "at": [Vector3(-0.66, 1.07, -1.28), Vector3(-0.44, 1.07, -1.28),
					Vector3(0.44, 1.07, -1.28), Vector3(0.66, 1.07, -1.28)],
			 "dir": Vector3(0, 1, 0), "cam": Vector3(0, 2.35, -3)},
			{"type": "PULL", "label": "Lift the hood clear",
			 "at": [Vector3(0, 1.06, -1.675)],
			 "dir": Vector3(0, 1, 0), "cam": Vector3(0, 2.8, -3.6)},
		],
		"alt": {
			"tool": "sawzall", "quality": 0.65, "button": "[Cut the hinges]",
			"stages": [
				{"type": "CUT", "label": "Saw through both hinges", "slow_without": "sawzall",
				 "at": [Vector3(-0.55, 1.07, -1.28), Vector3(0.55, 1.07, -1.28)],
				 "dir": Vector3(0, 1, 0), "cam": Vector3(0, 2.35, -3)},
				{"type": "PULL", "label": "Drag it off",
				 "at": [Vector3(0, 1.06, -1.675)],
				 "dir": Vector3(0, 1, 0), "cam": Vector3(0, 2.8, -3.6)},
			],
		},
	},
	"trunk": {
		"name": "Trunk Lid", "base_value": 50, "mass": 22, "size": 2,
		"needs": "", "lifted": false, "after": [],
		"stages": [
			{"type": "PLUG", "label": "Unplug the lamp harness",
			 "at": [Vector3(0, 1.12, 2.05)],
			 "dir": Vector3(0, 1, 0), "cam": Vector3(0, 2.2, 3.4)},
			{"type": "BOLT", "label": "Hinge bolts, front edge of the lid",
			 "at": [Vector3(-0.62, 1.13, 0.95), Vector3(-0.4, 1.13, 0.95),
					Vector3(0.4, 1.13, 0.95), Vector3(0.62, 1.13, 0.95)],
			 "dir": Vector3(0, 1, 0), "cam": Vector3(0, 2.45, 2.6)},
			{"type": "PULL", "label": "Lift the lid off",
			 "at": [Vector3(0, 1.12, 1.5)],
			 "dir": Vector3(0, 1, 0), "cam": Vector3(0, 2.8, 3.6)},
		],
	},
	"battery": {
		"name": "Battery", "base_value": 45, "mass": 18, "size": 1,
		"needs": "", "lifted": false, "after": ["hood"],
		"stages": [
			{"type": "CLAMP", "label": "NEGATIVE terminal first -- the black one", "color": "black",
			 "at": [Vector3(-0.75, 0.99, -1.36)],
			 "dir": Vector3(0, 1, 0), "cam": Vector3(-1.5, 1.9, -2.5)},
			{"type": "CLAMP", "label": "Now the positive terminal", "color": "red",
			 "at": [Vector3(-0.57, 0.99, -1.36)],
			 "dir": Vector3(0, 1, 0), "cam": Vector3(-1.5, 1.9, -2.5)},
			{"type": "BOLT", "label": "Undo the hold-down clamp",
			 "at": [Vector3(-0.66, 0.97, -1.24), Vector3(-0.66, 0.97, -1.48)],
			 "dir": Vector3(0, 1, 0), "cam": Vector3(-1.5, 1.9, -2.5)},
			{"type": "PULL", "label": "Lift the battery out",
			 "at": [Vector3(-0.66, 0.95, -1.36)],
			 "dir": Vector3(0, 1, 0), "cam": Vector3(-1.7, 2, -2.6)},
		],
	},
	"engine": {
		"name": "Engine", "base_value": 300, "mass": 180, "size": 4,
		"needs": "", "lifted": false, "after": ["hood", "battery"],
		"stages": [
			{"type": "PLUG", "label": "Unplug the harness, fuel and coolant lines",
			 "at": [Vector3(0.5, 1, -1.35), Vector3(0.2, 1, -2.05),
					Vector3(-0.2, 1, -2.05)],
			 "dir": Vector3(0, 1, 0), "cam": Vector3(0.1, 2.4, -3.2)},
			{"type": "BOLT", "label": "Six mount bolts, spread round the block",
			 "at": [Vector3(-0.62, 0.9, -1.32), Vector3(0.62, 0.9, -1.32),
					Vector3(-0.62, 0.9, -1.72), Vector3(0.62, 0.9, -1.72),
					Vector3(-0.35, 0.9, -2.08), Vector3(0.35, 0.9, -2.08)],
			 "dir": Vector3(0, 1, 0), "cam": Vector3(0.1, 2.5, -3.3)},
			{"type": "PULL", "label": "Haul it up and out", "heavy": true, "slow_without": "hoist",
			 "at": [Vector3(0.02, 0.9, -1.7)],
			 "dir": Vector3(0, 1, 0), "cam": Vector3(0.1, 2.7, -3.5)},
		],
	},
	"mirror_r": {
		"name": "Right Wing Mirror", "base_value": 20, "mass": 3, "size": 1,
		"needs": "", "lifted": false, "after": [],
		"stages": [
			{"type": "BOLT", "label": "Two screws behind the mirror base",
			 "at": [Vector3(1.03, 1.40, -1.0), Vector3(1.03, 1.32, -1.0)],
			 "dir": Vector3(1, 0, 0), "cam": Vector3(2.6, 1.5, -1.2)},
			{"type": "PULL", "label": "Lift the mirror off the door",
			 "at": [Vector3(1.06, 1.36, -1.0)],
			 "dir": Vector3(1, 0, 0), "cam": Vector3(2.8, 1.5, -1.2)},
		],
	},
	"mirror_l": {
		"name": "Left Wing Mirror", "base_value": 20, "mass": 3, "size": 1,
		"needs": "", "lifted": false, "after": [],
		"stages": [
			{"type": "BOLT", "label": "Two screws behind the mirror base",
			 "at": [Vector3(-1.03, 1.40, -1.0), Vector3(-1.03, 1.32, -1.0)],
			 "dir": Vector3(-1, 0, 0), "cam": Vector3(-2.6, 1.5, -1.2)},
			{"type": "PULL", "label": "Lift the mirror off the door",
			 "at": [Vector3(-1.06, 1.36, -1.0)],
			 "dir": Vector3(-1, 0, 0), "cam": Vector3(-2.8, 1.5, -1.2)},
		],
	},
	# The door is hauled open before any of this starts, so the shot stands in
	# the doorway it just made -- out at the flank, level with the aperture and
	# looking forward at the hinge pillar -- instead of out in front of the car
	# squinting past the wing.
	"door_r": {
		"name": "Right Door", "base_value": 45, "mass": 45, "size": 2,
		"needs": "", "lifted": false, "after": ["mirror_r"],
		"stages": [
			{"type": "PLUG", "label": "Unplug the harness boot on the hinge pillar",
			 "at": [Vector3(0.78, 1.02, -1.06)],
			 "dir": Vector3(0, 0, 1), "cam": Vector3(2.55, 1.45, 0.45)},
			{"type": "BOLT", "label": "Two bolts per hinge, front edge of the door",
			 "at": [Vector3(0.78, 1.31, -1.06), Vector3(0.78, 1.17, -1.06),
					Vector3(0.78, 0.85, -1.06), Vector3(0.78, 0.71, -1.06)],
			 "dir": Vector3(0, 0, 1), "cam": Vector3(2.45, 1.35, 0.30),
			 "props": [{"hinge": true}, {}, {"hinge": true}, {}]},
			{"type": "PULL", "label": "Lift the door off its hinges",
			 "at": [Vector3(1.02, 0.98, -0.25)],
			 "dir": Vector3(1, 0, 0), "cam": Vector3(3.1, 1.45, 0.35)},
		],
		"alt": {
			"tool": "sawzall", "quality": 0.6, "button": "[Cut the hinges]",
			"stages": [
				{"type": "CUT", "label": "Just saw the hinges off. It is fine.", "slow_without": "sawzall",
				 "at": [Vector3(0.78, 1.24, -1.06), Vector3(0.78, 0.78, -1.06)],
				 "dir": Vector3(0, 0, 1), "cam": Vector3(2.45, 1.35, 0.30)},
				{"type": "PULL", "label": "Catch it before it lands on your foot",
				 "at": [Vector3(1.02, 0.98, -0.25)],
				 "dir": Vector3(1, 0, 0), "cam": Vector3(3.1, 1.45, 0.35)},
			],
		},
	},
	"door_l": {
		"name": "Left Door", "base_value": 45, "mass": 45, "size": 2,
		"needs": "", "lifted": false, "after": ["mirror_l"],
		"stages": [
			{"type": "PLUG", "label": "Unplug the harness boot on the hinge pillar",
			 "at": [Vector3(-0.78, 1.02, -1.06)],
			 "dir": Vector3(0, 0, 1), "cam": Vector3(-2.55, 1.45, 0.45)},
			{"type": "BOLT", "label": "Two bolts per hinge, front edge of the door",
			 "at": [Vector3(-0.78, 1.31, -1.06), Vector3(-0.78, 1.17, -1.06),
					Vector3(-0.78, 0.85, -1.06), Vector3(-0.78, 0.71, -1.06)],
			 "dir": Vector3(0, 0, 1), "cam": Vector3(-2.45, 1.35, 0.30),
			 "props": [{"hinge": true}, {}, {"hinge": true}, {}]},
			{"type": "PULL", "label": "Lift the door off its hinges",
			 "at": [Vector3(-1.02, 0.98, -0.25)],
			 "dir": Vector3(-1, 0, 0), "cam": Vector3(-3.1, 1.45, 0.35)},
		],
		"alt": {
			"tool": "sawzall", "quality": 0.6, "button": "[Cut the hinges]",
			"stages": [
				{"type": "CUT", "label": "Just saw the hinges off. It is fine.", "slow_without": "sawzall",
				 "at": [Vector3(-0.78, 1.24, -1.06), Vector3(-0.78, 0.78, -1.06)],
				 "dir": Vector3(0, 0, 1), "cam": Vector3(-2.45, 1.35, 0.30)},
				{"type": "PULL", "label": "Catch it before it lands on your foot",
				 "at": [Vector3(-1.02, 0.98, -0.25)],
				 "dir": Vector3(-1, 0, 0), "cam": Vector3(-3.1, 1.45, 0.35)},
			],
		},
	},
	"seat_r": {
		"name": "Right Seat", "base_value": 35, "mass": 30, "size": 2,
		"needs": "", "lifted": false, "after": ["door_r"],
		"stages": [
			{"type": "PLUG", "label": "Unplug the occupancy sensor under the cushion",
			 "at": [Vector3(0.42, 1.06, 0.22)],
			 "dir": Vector3(0, 1, 0), "cam": Vector3(2.6, 1.9, -0.2)},
			{"type": "BOLT", "label": "Four bolts, two rails",
			 "at": [Vector3(0.24, 1.06, -0.24), Vector3(0.6, 1.06, -0.24),
					Vector3(0.24, 1.06, 0.24), Vector3(0.6, 1.06, 0.24)],
			 "dir": Vector3(0, 1, 0), "cam": Vector3(2.5, 2, -0.1)},
			{"type": "PULL", "label": "Drag it out through the door hole",
			 "at": [Vector3(0.42, 1.25, 0)],
			 "dir": Vector3(1, 0, 0), "cam": Vector3(3.2, 1.7, -0.2)},
		],
	},
	"seat_l": {
		"name": "Left Seat", "base_value": 35, "mass": 30, "size": 2,
		"needs": "", "lifted": false, "after": ["door_l"],
		"stages": [
			{"type": "PLUG", "label": "Unplug the occupancy sensor under the cushion",
			 "at": [Vector3(-0.42, 1.06, 0.22)],
			 "dir": Vector3(0, 1, 0), "cam": Vector3(-2.6, 1.9, -0.2)},
			{"type": "BOLT", "label": "Four bolts, two rails",
			 "at": [Vector3(-0.24, 1.06, -0.24), Vector3(-0.6, 1.06, -0.24),
					Vector3(-0.24, 1.06, 0.24), Vector3(-0.6, 1.06, 0.24)],
			 "dir": Vector3(0, 1, 0), "cam": Vector3(-2.5, 2, -0.1)},
			{"type": "PULL", "label": "Drag it out through the door hole",
			 "at": [Vector3(-0.42, 1.25, 0)],
			 "dir": Vector3(-1, 0, 0), "cam": Vector3(-3.2, 1.7, -0.2)},
		],
	},
	"electronics": {
		"name": "Electronics", "base_value": 130, "mass": 15, "size": 1,
		"needs": "bench", "lifted": false, "after": ["battery", "door_r"],
		"stages": [
			{"type": "PULL", "label": "Pop the dash trim off its clips", "mesh": "dash_trim",
			 "at": [Vector3(0.45, 1.3, -0.95)],
			 "dir": Vector3(0, 1, 0), "cam": Vector3(2.4, 1.9, -1.1)},
			{"type": "PLUG", "label": "Release the ECU connector locks",
			 "at": [Vector3(0.3, 1.24, -0.86), Vector3(0.6, 1.24, -0.86)],
			 "dir": Vector3(0, 1, 0), "cam": Vector3(2.3, 1.85, -1)},
			{"type": "BOLT", "label": "ECU bracket bolts",
			 "at": [Vector3(0.32, 1.26, -1.06), Vector3(0.58, 1.26, -1.06)],
			 "dir": Vector3(0, 1, 0), "cam": Vector3(2.2, 1.8, -1.1)},
			{"type": "PULL", "label": "Slide the ECU out",
			 "at": [Vector3(0.45, 1.22, -0.98)],
			 "dir": Vector3(1, 0, 0), "cam": Vector3(2.6, 1.7, -1)},
		],
	},
	"wheel_fr": {
		"name": "Front Right Wheel", "base_value": 25, "mass": 20, "size": 1,
		"needs": "jack", "lifted": true, "after": [],
		"stages": [
			{"type": "BOLT", "pattern": "circle", "radius": 0.19, "count": 5, "label": "Crack the lug nuts off",
			 "origin": Vector3(1.22, 0.42, -1.45), "dir": Vector3(1, 0, 0), "cam": Vector3(2.9, 0.95, -1.5)},
			{"type": "PULL", "label": "Heave the wheel off the hub",
			 "at": [Vector3(1.05, 0.42, -1.45)],
			 "dir": Vector3(1, 0, 0), "cam": Vector3(3.2, 0.95, -1.5)},
		],
	},
	"wheel_fl": {
		"name": "Front Left Wheel", "base_value": 25, "mass": 20, "size": 1,
		"needs": "jack", "lifted": true, "after": [],
		"stages": [
			{"type": "BOLT", "pattern": "circle", "radius": 0.19, "count": 5, "label": "Crack the lug nuts off",
			 "origin": Vector3(-1.22, 0.42, -1.45), "dir": Vector3(-1, 0, 0), "cam": Vector3(-2.9, 0.95, -1.5)},
			{"type": "PULL", "label": "Heave the wheel off the hub",
			 "at": [Vector3(-1.05, 0.42, -1.45)],
			 "dir": Vector3(-1, 0, 0), "cam": Vector3(-3.2, 0.95, -1.5)},
		],
	},
	"wheel_rr": {
		"name": "Rear Right Wheel", "base_value": 25, "mass": 20, "size": 1,
		"needs": "jack", "lifted": true, "after": [],
		"stages": [
			{"type": "BOLT", "pattern": "circle", "radius": 0.19, "count": 5, "label": "Crack the lug nuts off",
			 "origin": Vector3(1.22, 0.42, 1.45), "dir": Vector3(1, 0, 0), "cam": Vector3(2.9, 0.95, 1.4)},
			{"type": "PULL", "label": "Heave the wheel off the hub",
			 "at": [Vector3(1.05, 0.42, 1.45)],
			 "dir": Vector3(1, 0, 0), "cam": Vector3(3.2, 0.95, 1.4)},
		],
	},
	"wheel_rl": {
		"name": "Rear Left Wheel", "base_value": 25, "mass": 20, "size": 1,
		"needs": "jack", "lifted": true, "after": [],
		"stages": [
			{"type": "BOLT", "pattern": "circle", "radius": 0.19, "count": 5, "label": "Crack the lug nuts off",
			 "origin": Vector3(-1.22, 0.42, 1.45), "dir": Vector3(-1, 0, 0), "cam": Vector3(-2.9, 0.95, 1.4)},
			{"type": "PULL", "label": "Heave the wheel off the hub",
			 "at": [Vector3(-1.05, 0.42, 1.45)],
			 "dir": Vector3(-1, 0, 0), "cam": Vector3(-3.2, 0.95, 1.4)},
		],
	},
	"catalytic": {
		"name": "Catalytic Converter", "base_value": 260, "mass": 12, "size": 1,
		"needs": "lift", "lifted": true, "after": [],
		"stages": [
			{"type": "BOLT", "label": "Heat shield bolts",
			 "at": [Vector3(0.25, 0.16, 0.02), Vector3(0.25, 0.16, 0.3),
					Vector3(0.25, 0.16, 0.58)],
			 "dir": Vector3(0, -1, 0), "cam": Vector3(2.4, 0.05, 0.3)},
			{"type": "CUT", "label": "Cut the pipe either side of the cat", "slow_without": "sawzall",
			 "at": [Vector3(0.25, 0.2, -0.1), Vector3(0.25, 0.2, 0.72)],
			 "dir": Vector3(0, -1, 0), "cam": Vector3(2.4, 0.1, 0.3)},
			{"type": "PULL", "label": "Drop the cat out",
			 "at": [Vector3(0.25, 0.24, 0.3)],
			 "dir": Vector3(0, -1, 0), "cam": Vector3(2.6, 0, 0.3)},
		],
	},
	"transmission": {
		"name": "Transmission", "base_value": 200, "mass": 70, "size": 3,
		"needs": "jack", "lifted": true, "after": [],
		"stages": [
			{"type": "PLUG", "label": "Driveshaft flange and shift linkage",
			 "at": [Vector3(-0.05, 0.24, -0.42)],
			 "dir": Vector3(0, -1, 0), "cam": Vector3(2.3, 0.1, -0.7)},
			{"type": "BOLT", "pattern": "circle", "radius": 0.28, "count": 7, "label": "Bellhousing bolts, all the way round",
			 "origin": Vector3(0.05, 0.3, -0.95), "dir": Vector3(0, 0, -1), "cam": Vector3(1.6, 0.35, -2.3)},
			{"type": "PULL", "label": "Lower it onto your chest", "heavy": true, "slow_without": "hoist",
			 "at": [Vector3(0.05, 0.28, -0.7)],
			 "dir": Vector3(0, -1, 0), "cam": Vector3(2.4, 0, -0.7)},
		],
	},
}

## The stages you run to get a car up on stands.
const JACK_STAGES := [
	{"type": "PUMP", "rig": "jack", "label": "Pump the jack handle", "slow_without": "lift",
	 "at": [Vector3(1.25, 0.3, 0.85)], "dir": Vector3(1, 0, 0), "cam": Vector3(3.0, 1.1, 1.3)},
	{"type": "PULL", "rig": "jack", "mesh": "stands", "label": "Slide the stands underneath",
	 "at": [Vector3(1.1, 0.12, 0.85)], "dir": Vector3(1, 0, 0), "cam": Vector3(3.0, 0.9, 1.3)},
]

# Bare-metal price per kg when you crush the shell instead of parting it out.
const SCRAP_RATE := 0.14
# Shell weight before any parts are counted.
const SHELL_MASS := 720.0

# ---------- THEFT TOOLS ----------
# Architecture note: every vehicle lists requirement OPTIONS.
# A requirement option is [tool_id, level]. Owning ANY option unlocks the car.
# Only "jimmy" and "lockpick" are implemented for the prototype; the rest are
# declared so they can be dropped in later with zero refactoring.
const THEFT_TOOLS := {
	"jimmy":      {"name": "Jimmy",            "max_level": 3, "zone_bonus": 0.00},
	"lockpick":   {"name": "Lock Pick",        "max_level": 3, "zone_bonus": 0.05},
	"scanner":    {"name": "Key Scanner",      "max_level": 2, "zone_bonus": 0.10},
	"reader":     {"name": "Key Reader",       "max_level": 2, "zone_bonus": 0.12},
	"duplicator": {"name": "Key Duplicator",   "max_level": 2, "zone_bonus": 0.15},
	"bypass":     {"name": "Electronic Bypass","max_level": 2, "zone_bonus": 0.18},
	"ecu":        {"name": "Advanced ECU Kit", "max_level": 1, "zone_bonus": 0.22},
}

# ---------- VEHICLES ----------
# zone: base width (0-1) of the success zone in the break-in minigame.
const VEHICLES := [
	{
		"id": "rustbucket", "name": "Rusty Junker", "tier": 1,
		"value": 900, "part_mult": 0.8, "zone": 0.30, "heat": 1,
		"top_speed": 17.0, "accel": 8.5, "color": Color(0.45, 0.32, 0.22),
		"requires": [["jimmy", 1]],
		# a real model instead of boxes. It is 5.17m long and points +X, so it
		# gets turned a quarter turn and scaled into the 4.4m footprint the
		# teardown positions are all written against.
		"model": "res://assets/Cars/BasicLowPolyCar/scene.gltf",
		"model_scale": 1.35, "model_yaw": PI * 0.5,
		"body_size": Vector3(2.8, 1.9, 6.9), "body_y": 0.95,
		"model_map": {
			"hood": ["Illinois90_Hood"],
			"trunk": ["Illinois90_Trunkdoor", "Illinois90_Trunkdoor_inner",
					  "Illinois90_Trunkdoor_Badges", "Illinois90_Trunkdoor_Numberplates"],
			"wheel_fr": ["Illinois90_WheelStock_FR"], "wheel_fl": ["Illinois90_WheelStock_FL"],
			"wheel_rr": ["Illinois90_WheelStock_RR"], "wheel_rl": ["Illinois90_WheelStock_RL"],
			# the side windows are their own meshes -- a door comes off with its
			# glass in it, not leaving a pane hanging in mid air
			"door_r": ["Illinois90_Glass_Passenger"],
			"door_l": ["Illinois90_glass_Driver"],
		},
		# It has its own interior and its own engine bay, so nothing is
		# generated for it. Only the parts it can actually separate are
		# listed: the rest are welded into the body and underbody meshes and
		# need those meshes splitting before they can come off.
		# The model welds its doors into the body, its seats into the interior
		# and its engine into the underbody. Cut them back out by region so the
		# teardown can take them off; the numbers are metres in the car's own
		# space. A door is in all three meshes -- outer skin in the body, trim
		# card in the interior, frame and mirror in the underbody -- and every
		# one of them has to come away or you are left looking at the guts of a
		# door that is supposedly in your hands. Front edge sits just behind the
		# front arch, back edge just ahead of the quarter glass, top at the
		# window seal (the glass itself is a mesh of its own, mapped above).
		# The front door runs from the A pillar back to the B pillar -- the rear
		# door glass starts at z 0.48, so the seam is just ahead of that, and
		# the front one stops short of the wing or taking the door off opens up
		# the engine bay with it. The
		# mirror is cut first and separately: it bolts to the door in real life
		# and it is worth a few dollars on its own.
		"model_split": [
			{"node": "Illinois90_Body", "regions": {
				"door_r": AABB(Vector3(0.90, 0.48, -1.28), Vector3(0.70, 0.98, 1.72)),
				"door_l": AABB(Vector3(-1.60, 0.48, -1.28), Vector3(0.70, 0.98, 1.72)),
			}},
			{"node": "Illinois90_Interior", "regions": {
				"door_r": AABB(Vector3(0.90, 0.48, -1.28), Vector3(0.70, 0.98, 1.72)),
				"door_l": AABB(Vector3(-1.60, 0.48, -1.28), Vector3(0.70, 0.98, 1.72)),
				"seat_r": AABB(Vector3(0.047, 0.528, -0.80), Vector3(0.845, 0.998, 1.28)),
				"seat_l": AABB(Vector3(-0.892, 0.528, -0.80), Vector3(0.845, 0.998, 1.28)),
			}},
			{"node": "Illinois90_Bottom", "regions": {
				"mirror_r": AABB(Vector3(1.255, 1.26, -0.95), Vector3(0.35, 0.24, 0.40)),
				"mirror_l": AABB(Vector3(-1.605, 1.26, -0.95), Vector3(0.35, 0.24, 0.40)),
				"door_r": AABB(Vector3(0.90, 0.48, -1.28), Vector3(0.70, 0.98, 1.72)),
				"door_l": AABB(Vector3(-1.60, 0.48, -1.28), Vector3(0.70, 0.98, 1.72)),
				"engine": AABB(Vector3(-0.940, 0.352, -2.993), Vector3(1.878, 0.822, 1.702)),
			}},
		],
		# Where the teardown props land on this body. Every position in PARTS is
		# written against a box car -- 4.4m long, 2.0m wide -- and this one is
		# 6.9m long with its wheels, doors and engine bay somewhere else, so each
		# job gets a scale and an offset that carries the box-car spot onto the
		# real panel. x is mirrored about the centre line, so one entry covers
		# both flanks. "car" is the fallback and is what the camera always uses.
		"rig": {
			"car":     {"scale": Vector3(1.22, 1.15, 1.45),  "offset": Vector3(0, 0, -0.10)},
			"door":    {"scale": Vector3(1.22, 1.083, 1.0),  "offset": Vector3(0.04, -0.119, -0.16)},
			"jimmy":   {"scale": Vector3(1.22, 1.179, 1.0),  "offset": Vector3(0.04, 0, -0.28)},
			"wheel":   {"scale": Vector3(1.0, 1.036, 1.331), "offset": Vector3(0.08, 0, -0.13)},
			"hood":    {"scale": Vector3(1.36, 1.0, 1.0),    "offset": Vector3(0, 0.25, -0.12)},
			"trunk":   {"scale": Vector3(1.37, 1.0, 0.591),  "offset": Vector3(0, 0.22, 1.789)},
			"seat":    {"scale": Vector3(1.25, 0.547, 1.25), "offset": Vector3.ZERO},
			"mirror":  {"scale": Vector3(1.22, 1.0, 1.0),    "offset": Vector3(0.04, -0.04, 0.27)},
			"engine":  {"scale": Vector3(1.29, 1.0, 1.316),  "offset": Vector3(0, 0.05, 0)},
			"hotwire": {"scale": Vector3.ONE,                "offset": Vector3(0, -0.21, -0.08)},
			"jack":    {"scale": Vector3(1.15, 1.0, 1.35),   "offset": Vector3.ZERO},
		},
		"parts": ["wheel_fr", "wheel_fl", "wheel_rr", "wheel_rl", "hood", "trunk",
				  "mirror_r", "mirror_l", "door_r", "door_l", "seat_r", "seat_l", "engine"],
	},
	{
		"id": "beater", "name": "Beige Beater", "tier": 1,
		"value": 1100, "part_mult": 0.9, "zone": 0.26, "heat": 1,
		"top_speed": 19.0, "accel": 9.5, "color": Color(0.78, 0.73, 0.55),
		"requires": [["jimmy", 1]],
		"parts": ["engine", "transmission", "wheel_fr", "wheel_fl", "wheel_rr", "wheel_rl", "battery", "catalytic", "door_r", "door_l", "hood", "trunk"],
	},
	{
		"id": "sedan", "name": "Family Sedan", "tier": 2,
		"value": 2200, "part_mult": 1.35, "zone": 0.19, "heat": 2,
		"top_speed": 25.0, "accel": 12.5, "color": Color(0.25, 0.45, 0.7),
		"requires": [["jimmy", 2], ["lockpick", 1]],
		"parts": ["engine", "transmission", "wheel_fr", "wheel_fl", "wheel_rr", "wheel_rl", "battery", "catalytic", "door_r", "door_l", "hood", "trunk", "seat_r", "seat_l", "electronics"],
	},
	{
		"id": "van", "name": "Suspicious Van", "tier": 2,
		"value": 2600, "part_mult": 1.5, "zone": 0.21, "heat": 2,
		"top_speed": 22.0, "accel": 10.5, "color": Color(0.85, 0.85, 0.82),
		"requires": [["jimmy", 2], ["lockpick", 1]],
		# Taller and wider than everything else, and no boot lid -- the back of a
		# van is doors, not a deck, so there is no trunk to take off it.
		"model": "res://assets/Cars/SketchyVan/scene.gltf",
		"model_scale": 1.35, "model_yaw": PI * 0.5,
		"body_size": Vector3(3.19, 2.61, 6.62), "body_y": 1.30,
		"model_map": {
			"hood": ["Shvan92_Hood"],
			"wheel_fr": ["Shvan92_WheelStock_FR"],
			"wheel_fl": ["Shvan92_WheelStock_FL"],
			"wheel_rr": ["Shvan92_WheelStock_RL2"],
			"wheel_rl": ["Shvan92_WheelStock_RL"],
			"door_r": ["Shvan92_Glass_Passanger"],
			"door_l": ["Shvan92_Glass_Driver"],
		},
		"model_split": [
			{"node": "Shvan92_Body_Shvan92", "regions": {
				"door_r": AABB(Vector3(1.007, 0.652, -1.590), Vector3(0.776, 1.189, 1.888)),
				"door_l": AABB(Vector3(-1.783, 0.652, -1.590), Vector3(0.776, 1.189, 1.888)),
			}},
			{"node": "Shvan92_Interior", "regions": {
				"door_r": AABB(Vector3(1.007, 0.652, -1.590), Vector3(0.776, 1.189, 1.888)),
				"door_l": AABB(Vector3(-1.783, 0.652, -1.590), Vector3(0.776, 1.189, 1.888)),
				"seat_r": AABB(Vector3(0.10, 0.95, -2.45), Vector3(1.05, 1.05, 1.45)),
				"seat_l": AABB(Vector3(-1.15, 0.95, -2.45), Vector3(1.05, 1.05, 1.45)),
			}},
			{"node": "Shvan92_Bottom", "regions": {
				"mirror_r": AABB(Vector3(1.433, 1.841, -1.227), Vector3(0.350, 0.240, 0.439)),
				"mirror_l": AABB(Vector3(-1.783, 1.841, -1.227), Vector3(0.350, 0.240, 0.439)),
				"door_r": AABB(Vector3(1.007, 0.652, -1.590), Vector3(0.776, 1.189, 1.888)),
				"door_l": AABB(Vector3(-1.783, 0.652, -1.590), Vector3(0.776, 1.189, 1.888)),
				"engine": AABB(Vector3(-1.058, 0.478, -2.738), Vector3(2.116, 1.114, 1.148)),
			}},
		],
		"rig": {
			"car": {"scale": Vector3(1.375, 1.559, 1.375), "offset": Vector3(0.000, 0.000, -0.095)},
			"door": {"scale": Vector3(1.375, 1.468, 0.949), "offset": Vector3(0.045, -0.161, -0.152)},
			"jimmy": {"scale": Vector3(1.375, 1.598, 0.949), "offset": Vector3(0.045, 0.000, -0.266)},
			"wheel": {"scale": Vector3(1.000, 1.125, 1.459), "offset": Vector3(0.115, 0.000, -0.319)},
			"hood": {"scale": Vector3(1.533, 1.356, 0.949), "offset": Vector3(0.000, 0.339, -0.114)},
			"trunk": {"scale": Vector3(1.544, 1.356, 0.561), "offset": Vector3(0.000, 0.298, 1.697)},
			"seat": {"scale": Vector3(1.409, 0.741, 1.186), "offset": Vector3(0.000, 0.000, 0.000)},
			"mirror": {"scale": Vector3(1.375, 1.356, 0.949), "offset": Vector3(0.045, -0.054, 0.256)},
			"engine": {"scale": Vector3(1.454, 1.356, 1.248), "offset": Vector3(0.000, 0.068, 0.000)},
			"hotwire": {"scale": Vector3(1.127, 1.356, 0.949), "offset": Vector3(0.000, -0.285, -0.076)},
			"jack": {"scale": Vector3(1.296, 1.356, 1.280), "offset": Vector3(0.000, 0.000, 0.000)},
		},
		"parts": ["wheel_fr", "wheel_fl", "wheel_rr", "wheel_rl", "hood", "mirror_r", "mirror_l", "door_r", "door_l", "seat_r", "seat_l", "engine"],
	},
	{
		"id": "sports", "name": "Midlife Sports Car", "tier": 3,
		"value": 5200, "part_mult": 2.4, "zone": 0.12, "heat": 3,
		"top_speed": 35.0, "accel": 18.0, "color": Color(0.85, 0.15, 0.12),
		"requires": [["lockpick", 3], ["scanner", 1]],
		# The mid-life crisis car, as an actual model. Same family as the junker,
		# so the same trick: turn it a quarter, scale it into the shared footprint,
		# and cut the welded doors, seats, mirrors and engine back out by region.
		"model": "res://assets/Cars/MidLifeCar/scene.gltf",
		"model_scale": 1.35, "model_yaw": PI * 0.5,
		"body_size": Vector3(2.82, 1.80, 6.61), "body_y": 0.90,
		"model_map": {
			"hood": ["Phoenix445_Hood"],
			"trunk": ["Phoenix445_Trunkdoor"],
			"wheel_fr": ["Phoenix445_WheelStock_FR"],
			"wheel_fl": ["Phoenix445_WheelStock_FL"],
			"wheel_rr": ["Phoenix445_WheelStock_RR"],
			"wheel_rl": ["Phoenix445_WheelStock_RL"],
			"door_r": ["Phoenix445_Glass_Passenger"],
			"door_l": ["Phoenix445_Glass_Driver"],
		},
		"model_split": [
			{"node": "Phoenix445_Body_Phoenix445", "regions": {
				"door_r": AABB(Vector3(0.911, 0.449, -1.261), Vector3(0.690, 0.754, 1.650)),
				"door_l": AABB(Vector3(-1.601, 0.449, -1.261), Vector3(0.690, 0.754, 1.650)),
			}},
			{"node": "Phoenix445_Interior", "regions": {
				"door_r": AABB(Vector3(0.911, 0.449, -1.261), Vector3(0.690, 0.754, 1.650)),
				"door_l": AABB(Vector3(-1.601, 0.449, -1.261), Vector3(0.690, 0.754, 1.650)),
				"seat_r": AABB(Vector3(0.047, 0.492, -0.801), Vector3(0.842, 0.933, 1.228)),
				"seat_l": AABB(Vector3(-0.889, 0.492, -0.801), Vector3(0.842, 0.933, 1.228)),
			}},
			{"node": "Phoenix445_Bottom", "regions": {
				"mirror_r": AABB(Vector3(1.251, 1.204, -0.945), Vector3(0.350, 0.240, 0.384)),
				"mirror_l": AABB(Vector3(-1.601, 1.204, -0.945), Vector3(0.350, 0.240, 0.384)),
				"door_r": AABB(Vector3(0.911, 0.449, -1.261), Vector3(0.690, 0.754, 1.650)),
				"door_l": AABB(Vector3(-1.601, 0.449, -1.261), Vector3(0.690, 0.754, 1.650)),
				"engine": AABB(Vector3(-0.937, 0.329, -2.668), Vector3(1.873, 0.767, 1.384)),
			}},
		],
		"rig": {
			"car": {"scale": Vector3(1.218, 1.073, 1.375), "offset": Vector3(0.000, 0.000, -0.095)},
			"door": {"scale": Vector3(1.218, 1.011, 0.948), "offset": Vector3(0.040, -0.111, -0.152)},
			"jimmy": {"scale": Vector3(1.218, 1.100, 0.948), "offset": Vector3(0.040, 0.000, -0.265)},
			"wheel": {"scale": Vector3(1.000, 1.035, 1.276), "offset": Vector3(0.156, 0.000, -0.173)},
			"hood": {"scale": Vector3(1.357, 0.933, 0.948), "offset": Vector3(0.000, 0.233, -0.114)},
			"trunk": {"scale": Vector3(1.367, 0.933, 0.560), "offset": Vector3(0.000, 0.205, 1.696)},
			"seat": {"scale": Vector3(1.248, 0.511, 1.185), "offset": Vector3(0.000, 0.000, 0.000)},
			"mirror": {"scale": Vector3(1.218, 0.933, 0.948), "offset": Vector3(0.040, -0.037, 0.256)},
			"engine": {"scale": Vector3(1.288, 0.933, 1.248), "offset": Vector3(0.000, 0.047, 0.000)},
			"hotwire": {"scale": Vector3(0.998, 0.933, 0.948), "offset": Vector3(0.000, -0.196, -0.076)},
			"jack": {"scale": Vector3(1.148, 0.933, 1.280), "offset": Vector3(0.000, 0.000, 0.000)},
		},
		"parts": ["wheel_fr", "wheel_fl", "wheel_rr", "wheel_rl", "hood", "trunk", "mirror_r", "mirror_l", "door_r", "door_l", "seat_r", "seat_l", "engine"],
	},
	{
		"id": "coupe", "name": "Bavarian Coupe", "tier": 3,
		"value": 6100, "part_mult": 2.6, "zone": 0.11, "heat": 3,
		"top_speed": 38.0, "accel": 20.0, "color": Color(0.16, 0.18, 0.24),
		"requires": [["lockpick", 3], ["scanner", 1]],
		# The other tier-3 car. Lower and narrower than the mid-life saloon, and
		# a hatch rather than a boot lid, so there is no trunk on it either.
		"model": "res://assets/Cars/SportyCar/scene.gltf",
		"model_scale": 1.35, "model_yaw": PI * 0.5,
		"body_size": Vector3(2.56, 1.86, 6.19), "body_y": 0.93,
		"model_map": {
			"hood": ["KIRI95_HOOD"],
			"wheel_fr": ["KIRI95_WheelSport_FR"],
			"wheel_fl": ["KIRI95_WheelSport_FL"],
			"wheel_rr": ["KIRI95_WheelSport_RR"],
			"wheel_rl": ["KIRI95_WheelSport_RL"],
			"door_r": ["KIRI95_Glass_Passenger"],
			"door_l": ["KIRI95_Glass_Driver"],
		},
		"model_split": [
			{"node": "KIRI95_BODY_KIRI95", "regions": {
				"door_r": AABB(Vector3(0.725, 0.465, -1.025), Vector3(0.743, 0.837, 1.562)),
				"door_l": AABB(Vector3(-1.468, 0.465, -1.025), Vector3(0.743, 0.837, 1.562)),
			}},
			{"node": "KIRI95_INTERIOR", "regions": {
				"door_r": AABB(Vector3(0.725, 0.465, -1.025), Vector3(0.743, 0.837, 1.562)),
				"door_l": AABB(Vector3(-1.468, 0.465, -1.025), Vector3(0.743, 0.837, 1.562)),
				"seat_r": AABB(Vector3(0.042, 0.510, -0.589), Vector3(0.763, 0.966, 1.163)),
				"seat_l": AABB(Vector3(-0.805, 0.510, -0.589), Vector3(0.763, 0.966, 1.163)),
			}},
			{"node": "KIRI95_BOTTOM", "regions": {
				"mirror_r": AABB(Vector3(1.118, 1.302, -0.725), Vector3(0.350, 0.240, 0.363)),
				"mirror_l": AABB(Vector3(-1.468, 1.302, -0.725), Vector3(0.350, 0.240, 0.363)),
				"door_r": AABB(Vector3(0.725, 0.465, -1.025), Vector3(0.743, 0.837, 1.562)),
				"door_l": AABB(Vector3(-1.468, 0.465, -1.025), Vector3(0.743, 0.837, 1.562)),
				"engine": AABB(Vector3(-0.848, 0.341, -2.449), Vector3(1.697, 0.795, 1.391)),
			}},
		],
		"rig": {
			"car": {"scale": Vector3(1.103, 1.112, 1.286), "offset": Vector3(0.000, 0.000, -0.089)},
			"door": {"scale": Vector3(1.103, 1.047, 0.887), "offset": Vector3(0.036, -0.115, -0.142)},
			"jimmy": {"scale": Vector3(1.103, 1.140, 0.887), "offset": Vector3(0.036, 0.000, -0.248)},
			"wheel": {"scale": Vector3(1.000, 1.009, 1.208), "offset": Vector3(0.068, 0.000, -0.006)},
			"hood": {"scale": Vector3(1.229, 0.967, 0.887), "offset": Vector3(0.000, 0.242, -0.106)},
			"trunk": {"scale": Vector3(1.238, 0.967, 0.524), "offset": Vector3(0.000, 0.213, 1.587)},
			"seat": {"scale": Vector3(1.130, 0.529, 1.109), "offset": Vector3(0.000, 0.000, 0.000)},
			"mirror": {"scale": Vector3(1.103, 0.967, 0.887), "offset": Vector3(0.036, -0.039, 0.240)},
			"engine": {"scale": Vector3(1.166, 0.967, 1.167), "offset": Vector3(0.000, 0.048, 0.000)},
			"hotwire": {"scale": Vector3(0.904, 0.967, 0.887), "offset": Vector3(0.000, -0.203, -0.071)},
			"jack": {"scale": Vector3(1.040, 0.967, 1.198), "offset": Vector3(0.000, 0.000, 0.000)},
		},
		"parts": ["wheel_fr", "wheel_fl", "wheel_rr", "wheel_rl", "hood", "mirror_r", "mirror_l", "door_r", "door_l", "seat_r", "seat_l", "engine"],
	},
	{
		"id": "luxury", "name": "Chrome Land Yacht", "tier": 4,
		"value": 9000, "part_mult": 3.4, "zone": 0.09, "heat": 3,
		"top_speed": 32.0, "accel": 16.0, "color": Color(0.1, 0.1, 0.12),
		"requires": [["scanner", 2], ["duplicator", 1]],
		"parts": ["engine", "transmission", "wheel_fr", "wheel_fl", "wheel_rr", "wheel_rl", "battery", "catalytic", "door_r", "door_l", "hood", "trunk", "seat_r", "seat_l", "electronics"],
	},
]



# ---------- BREAKING IN ----------
# Both of these run through the same hands-on rig as the teardown.
#
# The jimmy is a lever: you hold the handle above the window seal and the tip
# swings the other way down inside the door. Find the lock rod, lift, repeat.
const JIMMY_STAGES := [
	{"type": "JIMMY", "rig": "jimmy", "label": "Work the jimmy down the door and feel for the lock rod",
	 "at": [Vector3(-1.07, 0.95, 0.16)], "dir": Vector3(-1, 0, 0), "cam": Vector3(-3.3, 1.35, -0.05)},
]

# ---------- TAKING ONE OFF SOMEBODY ----------
# A car with a driver in it is not a lock problem, it is a people problem.
# Haul the door open against them holding it shut, then drag them out -- both
# against the clock, because they are trying to pull away the whole time.
const CARJACK_STAGES := [
	# "swing" means the thing you drag is the car's own door on its own hinge,
	# not a stand-in in front of it that gets swapped for an animation after
	{"type": "PULL", "rig": "carjack", "swing": "door_l", "heavy": true, "limit": 5.0,
	 "label": "Get hold of the door and haul it open -- they are holding it shut",
	 "at": [Vector3(-1.06, 1.02, -0.1)], "dir": Vector3(-1, 0, 0),
	 "cam": Vector3(-3.2, 1.5, -0.6)},
	# the shot for this one stands at the rear door and looks forward through
	# the open front one, which is where you would actually be: one hand on the
	# roof, leaning in past the B pillar to get hold of them
	{"type": "PULL", "rig": "carjack", "mesh": "driver", "heavy": true, "limit": 5.0,
	 "label": "Now get them out of it",
	 "at": [Vector3(-0.45, 1.05, -0.1)], "dir": Vector3(-1, 0, 0),
	 "cam": Vector3(-1.85, 1.45, 1.15), "fov": 72.0},
]

# Anything past a junker has an immobiliser in it, and hauling the driver out
# does you no good if the car will not start once they are gone. The key tool
# comes out first, at the lock, before a hand is laid on anybody. Tier 1 has
# nothing worth beating.
const CARJACK_KEYS := {
	2: [["scanner", 1], ["duplicator", 1]],
	3: [["scanner", 2], ["duplicator", 1]],
	4: [["duplicator", 2]],
}

## Held on the driver's lock until the fob inside answers it.
const CARJACK_SCAN := {
	"type": "SCAN", "rig": "carjack", "limit": 12.0,
	"label": "Read the fob through the door before you touch the driver",
	"at": [Vector3(-1.06, 1.02, -0.45)], "dir": Vector3(-1, 0, 0),
	"cam": Vector3(-2.5, 1.35, -0.95), "fov": 62.0,
}

## The stages for taking one off its driver. Nicer cars get the scanner step
## bolted on the front of it.
static func carjack_stages(vehicle: Dictionary) -> Array:
	var out := []
	if not CARJACK_KEYS.get(int(vehicle.get("tier", 1)), []).is_empty():
		out.append(CARJACK_SCAN)
	out.append_array(CARJACK_STAGES)
	return out

# Wire colours, and which three actually matter. The rest will put you on your
# back if you grab them.
const WIRE_COLOURS := {
	"battery": Color(0.85, 0.15, 0.12),
	"ignition": Color(0.55, 0.35, 0.15),
	"starter": Color(0.85, 0.75, 0.15),
}

# The column is on the driver's side, which is the left one, so all of this
# happens over there -- not reaching across the car from the passenger seat.
const HOTWIRE_STAGES := [
	{"type": "PULL", "rig": "hotwire", "mesh": "dash_trim", "label": "Rip the shroud off the steering column",
	 "at": [Vector3(-0.5, 1.34, -0.92)], "dir": Vector3(0, 1, 0), "cam": Vector3(-0.45, 1.56, 0.1), "fov": 78.0},

	{"type": "WIRE", "rig": "hotwire", "label": "Red is battery, brown is ignition, yellow is starter. Grab those three and scrape them back.",
	 "at": [Vector3(-0.12, 1.26, -0.62), Vector3(-0.25, 1.26, -0.62), Vector3(-0.38, 1.26, -0.62),
			Vector3(-0.51, 1.26, -0.62), Vector3(-0.64, 1.26, -0.62), Vector3(-0.77, 1.26, -0.62)],
	 "dir": Vector3(0, 0, -1), "cam": Vector3(-0.45, 1.52, 0.08), "fov": 78.0,
	 "props": [
		{"colour": Color(0.2, 0.5, 0.85), "name": "blue", "decoy": true},
		{"colour": Color(0.85, 0.15, 0.12), "name": "battery"},
		{"colour": Color(0.15, 0.6, 0.25), "name": "green", "decoy": true},
		{"colour": Color(0.55, 0.35, 0.15), "name": "ignition"},
		{"colour": Color(0.75, 0.75, 0.78), "name": "grey", "decoy": true},
		{"colour": Color(0.85, 0.75, 0.15), "name": "starter"},
	 ]},

	{"type": "JOIN", "rig": "hotwire", "label": "Twist the bared ignition wire onto the battery wire",
	 "at": [Vector3(-0.51, 1.26, -0.62), Vector3(-0.25, 1.26, -0.62)],
	 "dir": Vector3(0, 0, -1), "cam": Vector3(-0.45, 1.5, 0.06), "fov": 78.0,
	 "props": [
		{"colour": Color(0.85, 0.15, 0.12), "name": "battery", "scenery": true, "bare": true},
		{"colour": Color(0.55, 0.35, 0.15), "name": "ignition", "bare": true,
		 "target": Vector3(-0.51, 1.26, -0.62)},
	 ]},

	{"type": "JOIN", "rig": "hotwire", "label": "Live now. Flash the starter across the pair to turn it over.",
	 "at": [Vector3(-0.51, 1.26, -0.62), Vector3(-0.77, 1.26, -0.62)],
	 "dir": Vector3(0, 0, -1), "cam": Vector3(-0.45, 1.5, 0.06), "fov": 78.0,
	 "props": [
		{"colour": Color(0.85, 0.15, 0.12), "colour2": Color(0.55, 0.35, 0.15),
		 "name": "the pair", "scenery": true, "bare": true, "joined": true},
		{"colour": Color(0.85, 0.75, 0.15), "name": "starter", "bare": true, "spark": true,
		 "target": Vector3(-0.51, 1.26, -0.62)},
	 ]},
]

# ---------- WHAT YOU CARRY ----------
# Things you hold in your hands, one at a time, out of a belt with very few
# loops on it. Two slots to start with: a jimmy and a tire iron fill it, so
# the pistol costs you something to carry until you buy a belt.
const ITEMS := {
	"jimmy": {
		"name": "Jimmy", "kind": "theft", "colour": Color(0.78, 0.8, 0.85),
		"blurb": "Gets you into cars. Cannot get you out of trouble.",
	},
	"tire_iron": {
		"name": "Tire Iron", "kind": "melee", "colour": Color(0.45, 0.45, 0.5),
		"damage": 35, "rate": 0.62, "range": 2.7, "turns": 2.5,
		"blurb": "Quiet, close, and legal to own. Mostly. Also the only thing that fits a wheel nut.",
	},
	"socket_wrench": {
		"name": "Socket Wrench", "kind": "tool", "colour": Color(0.62, 0.64, 0.7),
		"turns": 2.5,
		"blurb": "Everything on a car is bolted to something. This is what undoes it.",
	},
	"flashlight": {
		"name": "Flashlight", "kind": "torch", "colour": Color(0.85, 0.82, 0.35),
		"blurb": "Lights up what you are doing. So does everybody else's.",
	},
	"impact_drill": {
		"name": "Impact Driver", "kind": "tool", "colour": Color(0.9, 0.55, 0.15),
		"turns": 1.0,
		"blurb": "Rattles a fastener out in a fraction of the turns. Fits wheel nuts too. Deafening.",
	},
	"pistol": {
		"name": "Pistol", "kind": "gun", "weapon": "pistol", "colour": Color(0.3, 0.3, 0.34),
		"blurb": "Loud. Everything after this gets harder.",
	},
	"snub": {
		"name": "Snub Revolver", "kind": "gun", "weapon": "snub", "colour": Color(0.42, 0.4, 0.38),
		"blurb": "Five shots, and it hits like a brick. Aim it before you pull.",
	},
	"suppressed": {
		"name": "Suppressed Pistol", "kind": "gun", "weapon": "suppressed", "colour": Color(0.22, 0.23, 0.26),
		"blurb": "Nobody a street away hears this. Worth every penny of it.",
	},
	"shotgun": {
		"name": "Sawn-Off", "kind": "gun", "weapon": "shotgun", "colour": Color(0.35, 0.25, 0.16),
		"blurb": "Two barrels, no manners, no range at all.",
	},
	"smg": {
		"name": "Cheap SMG", "kind": "gun", "weapon": "smg", "colour": Color(0.26, 0.27, 0.3),
		"blurb": "Thirty rounds in three seconds and a street full of witnesses.",
	},
	"rifle": {
		"name": "Hunting Rifle", "kind": "gun", "weapon": "rifle", "colour": Color(0.31, 0.22, 0.14),
		"blurb": "For the shot you take from somewhere else entirely.",
	},
	"crowbar": {
		"name": "Crowbar", "kind": "melee", "colour": Color(0.5, 0.24, 0.16),
		"damage": 48, "rate": 0.75, "range": 2.9, "turns": 3.0,
		"blurb": "Heavier than the tire iron and worse at wheel nuts.",
	},
	"bat": {
		"name": "Louisville Slugger", "kind": "melee", "colour": Color(0.62, 0.45, 0.24),
		"damage": 42, "rate": 0.68, "range": 3.2,
		"blurb": "Legal to carry, right up until it is not.",
	},
	"sander": {
		"name": "Angle Sander", "kind": "tool", "colour": Color(0.85, 0.65, 0.1),
		"blurb": "Takes the number off a panel. A part with no number is a part with no history.",
	},
	"spray_gun": {
		"name": "Spray Gun", "kind": "tool", "colour": Color(0.2, 0.65, 0.85),
		"blurb": "A car the wrong colour is a different car, as far as anyone looking is concerned.",
	},
}

# What has to be on your belt to work a fastener. Wheel nuts take a tire iron,
# everything else takes a wrench, and the impact driver does either -- faster.
# A stage can name its own tool with a "tool" key if it wants something else.
const LUG_TOOLS := ["tire_iron", "impact_drill"]
const BOLT_TOOLS := ["socket_wrench", "impact_drill"]

## Which belt items will work `stage` on `part_id`. Empty means bare hands.
static func tools_for_stage(stage: Dictionary, part_id: String) -> Array:
	if stage.has("tool"):
		return [String(stage.tool)]
	match String(stage.get("type", "")):
		"BOLT", "CLAMP":
			return LUG_TOOLS if part_id.begins_with("wheel") else BOLT_TOOLS
	return []

## What actually ends up in your hand for a stage, whether or not the belt is
## what supplies it. The stages whose prop IS the tool -- the jimmy at the
## window, the reader on the lock, the jack under the sill -- name themselves;
## everything else holds whatever the fastener wants.
static func hold_for_stage(stage: Dictionary, part_id: String) -> String:
	if stage.has("hold"):
		return String(stage.hold)
	match String(stage.get("type", "")):
		"JIMMY": return "jimmy"
		"SCAN":  return "scanner"
		"PUMP":  return "jack"
		"CUT":   return "sawzall"
	var want := tools_for_stage(stage, part_id)
	return String(want[0]) if not want.is_empty() else ""

## The stages where the prop you are given IS the tool, so there is nothing to
## see at the work until you have carried it over there.
const PROP_IS_TOOL := ["JIMMY", "SCAN", "PUMP"]

## Names for things that are not belt items but still end up in your hand.
const HOLD_NAMES := {
	"scanner": "Key Scanner", "jack": "Jack", "sawzall": "Reciprocating Saw",
	"hacksaw": "Hacksaw",
}

static func hold_name(id: String) -> String:
	if ITEMS.has(id):
		return String(ITEMS[id].name)
	return String(HOLD_NAMES.get(id, id.capitalize()))

## Reading the above back out for a prompt: "a Socket Wrench or an Impact Driver".
static func tool_names(ids: Array) -> String:
	var names := []
	for id in ids:
		names.append(String(ITEMS.get(id, {}).get("name", id)))
	return " or ".join(names)

## Belt in the shop -> how many loops you end up with.
const BELTS := {"": 2, "belt": 4, "belt_large": 6}

# ---------- WEAPONS ----------
# Nobody here is a marksman. The pistol is loud, inaccurate past twenty yards,
# and turns a quiet night into a very short career.
const WEAPONS := {
	"pistol": {
		"name": "Battered Pistol", "damage": 25, "range": 60.0,
		"rate": 0.34, "spread": 0.012, "clip": 12, "reload": 1.4,
	},
	"police_pistol": {
		"name": "Service Pistol", "damage": 9, "range": 45.0,
		"rate": 1.05, "spread": 0.075, "clip": 99, "reload": 0.0,
	},
	# Everything below is bought, and every one of them is a trade: quiet for
	# stopping power, or rate of fire for the noise it makes.
	"snub": {
		"name": "Snub Revolver", "damage": 34, "range": 34.0,
		"rate": 0.62, "spread": 0.030, "clip": 5, "reload": 2.2, "heat": 2,
	},
	"suppressed": {
		"name": "Suppressed Pistol", "damage": 22, "range": 55.0,
		"rate": 0.36, "spread": 0.014, "clip": 10, "reload": 1.5, "heat": 0,
		"quiet": true,
	},
	"shotgun": {
		"name": "Sawn-Off", "damage": 17, "range": 16.0,
		"rate": 0.95, "spread": 0.085, "clip": 2, "reload": 2.6, "heat": 3,
		"pellets": 6,
	},
	"smg": {
		"name": "Cheap SMG", "damage": 13, "range": 42.0,
		"rate": 0.09, "spread": 0.055, "clip": 30, "reload": 2.0, "heat": 3,
	},
	"rifle": {
		"name": "Hunting Rifle", "damage": 62, "range": 120.0,
		"rate": 1.35, "spread": 0.004, "clip": 5, "reload": 2.4, "heat": 3,
	},
}

## They will not draw on you below this. One star is a chase, two is a problem.
const SHOOTING_STARS := 2

# ---------- HAULAGE ----------
# Parts only turn into money once they are physically in the back of
# something and that something is parked at a buyer.
const TRUCKS := [
	# The first two are real models. "bed_at" is where the load stacks in the
	# back of each -- a pickup's tray sits behind the cab and low, a box body's
	# floor is further back and higher up.
	{"level": 1, "name": "Rusty Pickup", "capacity": 20, "bed_len": 2.6,
	 "top_speed": 19.0, "accel": 9.5, "color": Color(0.35, 0.45, 0.55),
	 "model": "res://assets/Cars/PickupTruck/scene.gltf",
	 "model_scale": 1.35, "model_yaw": PI * 0.5,
	 "body_size": Vector3(2.89, 2.61, 6.66), "body_y": 1.30,
	 "bed_at": Vector3(0, 1.30, 1.45), "bed_span": Vector3(1.7, 0.0, 2.3),
	 "wheels": {"wheel_fr": "krmlgtbdy85_WheelStock_FR", "wheel_fl": "krmlgtbdy85_WheelStock_FL",
				"wheel_rr": "krmlgtbdy85_WheelStock_RR", "wheel_rl": "krmlgtbdy85_WheelStock_RL"},
	 "desc": "Most of one car, if you leave the engine behind."},
	{"level": 2, "name": "Box Truck", "capacity": 48, "bed_len": 4.4,
	 "top_speed": 17.0, "accel": 8.0, "color": Color(0.85, 0.82, 0.75),
	 "model": "res://assets/Cars/BoxVan/scene.gltf",
	 "model_scale": 1.35, "model_yaw": PI * 0.5,
	 "body_size": Vector3(3.55, 3.86, 8.13), "body_y": 1.90,
	 "bed_at": Vector3(0, 1.35, 1.30), "bed_span": Vector3(1.9, 0.0, 3.4),
	 "wheels": {"wheel_fr": "LCT300095_WheelStock_FR", "wheel_fl": "LCT300095_WheelStock_FL",
				"wheel_rr": "LCT300095_WheelStock_RR", "wheel_rl": "LCT300095_WheelStock_RL"},
	 "desc": "Two cars a trip. Handles like a wardrobe."},
	{"level": 3, "name": "Semi and Trailer", "capacity": 110, "bed_len": 7.0,
	 "top_speed": 16.0, "accel": 7.0, "color": Color(0.6, 0.15, 0.15),
	 "desc": "Clear the whole shop in one run."},
]

# ---------- HEAT ON THE CAR ----------
# A car you took is hot whether or not YOU are. It is on a list, and the list
# does not forget for a fortnight of game time. What clears it is laundering:
# a respray changes what anybody is looking for, and swapping the numbered
# panels changes what a plate check finds. Either one helps. Both together are
# what actually makes it somebody else's car.
const CAR_HEAT_DAYS := 14.0
## Fraction of the heat each job takes off.
const HEAT_RESPRAY := 0.45
const HEAT_PANELS := 0.45
## Both done: the last of it goes with them.
const HEAT_BOTH_BONUS := 0.10
## Panels that carry a number a check can be run against.
const HEAT_PANELS_NEEDED := 2

## How hot a car is when you have just taken it off somebody, by tier.
static func heat_for_theft(tier: int) -> float:
	return clampf(0.35 + 0.18 * float(tier - 1), 0.35, 1.0)

# Cars come off the line in more than one colour, so a street full of the same
# four models does not read as a street full of four cars.
const PAINTS := [
	Color(0.72, 0.10, 0.10), Color(0.10, 0.22, 0.52), Color(0.13, 0.35, 0.20),
	Color(0.82, 0.74, 0.22), Color(0.88, 0.88, 0.90), Color(0.10, 0.10, 0.12),
	Color(0.45, 0.46, 0.50), Color(0.66, 0.36, 0.10), Color(0.30, 0.55, 0.62),
	Color(0.52, 0.20, 0.42), Color(0.85, 0.55, 0.15), Color(0.24, 0.28, 0.24),
]

static func random_paint(rng: RandomNumberGenerator = null) -> Color:
	if rng == null:
		return PAINTS[randi() % PAINTS.size()]
	return PAINTS[rng.randi() % PAINTS.size()]

# Panels that leave the factory with the car's number stamped on them. Grinding
# it off is illegal, obvious, and roughly doubles what a fence will pay.
const VIN_PARTS := ["door_r", "door_l", "hood", "trunk", "engine", "transmission"]
## What a fence pays extra for a part nobody can trace.
const VIN_BONUS := 0.85

# ---------- THE ARMS DEALER ----------
# A separate list from the shop upgrades on purpose: this is somebody's stock,
# not your own workbench, and it is meant to move. Right now he works out of the
# corner of the garage; the plan is a van that turns up somewhere different
# depending on the day and the hour.
const ARMS := [
	{"id": "snub",       "name": "Snub Revolver",     "price": 900,  "item": "snub",
	 "desc": "Five shots and a lot of noise. Stops anybody it hits."},
	{"id": "bat",        "name": "Louisville Slugger","price": 140,  "item": "bat",
	 "desc": "Quiet, legal, and nobody calls it in."},
	{"id": "crowbar",    "name": "Crowbar",           "price": 260,  "item": "crowbar",
	 "desc": "Heavier than the tire iron. Will not do wheel nuts."},
	{"id": "suppressed", "name": "Suppressed Pistol", "price": 4200, "item": "suppressed",
	 "desc": "The only gun here that does not raise the street."},
	{"id": "shotgun",    "name": "Sawn-Off",          "price": 2600, "item": "shotgun",
	 "desc": "Two barrels. Useless past a car's length."},
	{"id": "smg",        "name": "Cheap SMG",         "price": 7500, "item": "smg",
	 "desc": "Thirty rounds. Jams if you look at it wrong."},
	{"id": "rifle",      "name": "Hunting Rifle",     "price": 11000,"item": "rifle",
	 "desc": "For the shot you take from a roof three streets away."},
]

## Highest car tier the hitch will drag. The basic hitch only takes junkers.
const TOW_TIERS := {"hitch": 1, "hitch2": 2}

# Who buys what. `mults` is per part id, `default` covers the rest.
const BUYERS := [
	{"id": "scrap", "name": "Gordo Scrap Yard", "price": 0,
	 "desc": "Buys anything by weight. Pays like it, too.",
	 "mults": {"default": 1.0}},
	{"id": "mechanic", "name": "Ferret the Mechanic", "price": 2500,
	 "desc": "Wants drivetrain. Sniffy about trim.",
	 "mults": {"default": 0.9, "engine": 1.5, "transmission": 1.5, "catalytic": 1.3,
			   "wheel_fr": 1.3, "wheel_fl": 1.3, "wheel_rr": 1.3, "wheel_rl": 1.3}},
	{"id": "shady", "name": "Deniz, Discreet Electronics", "price": 3500,
	 "desc": "Pays stupid money for anything with a chip in it.",
	 "mults": {"default": 0.85, "electronics": 1.9, "battery": 1.4}},
	{"id": "specialty", "name": "The Collector", "price": 9000,
	 "desc": "Takes the lot, at a price that makes the drive worth it.",
	 "mults": {"default": 1.35}},
]

static func truck_by_level(level: int) -> Dictionary:
	for t in TRUCKS:
		if int(t.level) == level:
			return t
	return TRUCKS[0]

## The truck drives through the same Vehicle code as everything else.
static func truck_data(level: int) -> Dictionary:
	var t := truck_by_level(level)
	var d := {
		"id": "truck", "name": t.name, "tier": 0, "value": 0, "part_mult": 1.0,
		"zone": 0.2, "heat": 0, "top_speed": t.top_speed, "accel": t.accel,
		# it has a lock like anything else, which matters the day the city takes it
		"color": t.color, "requires": [["jimmy", 1]], "parts": [],
	}
	# a truck with a model of its own drives it in the same way the cars do
	for key in ["model", "model_scale", "model_yaw", "body_size", "body_y"]:
		if t.has(key):
			d[key] = t[key]
	return d

static func buyer_by_id(id: String) -> Dictionary:
	for b in BUYERS:
		if b.id == id:
			return b
	return BUYERS[0]

static func buyer_mult(buyer_id: String, part_id: String) -> float:
	var m: Dictionary = buyer_by_id(buyer_id).mults
	return float(m.get(part_id, m.get("default", 1.0)))

# ---------- SHOP ----------
# kind: "theft_tool" (grants/levels a theft tool)
#       "shop_tool"  (garage equipment: speed / access)
#       "garage"     (shop tier upgrade)
const UPGRADES := [
	{"id": "jimmy2",   "name": "Reinforced Jimmy",    "price": 750,  "kind": "theft_tool", "tool": "jimmy",    "level": 2,
	 "desc": "Jimmy Lv2. Wider success zone, opens sedans."},
	{"id": "jimmy3",   "name": "Artisanal Jimmy",     "price": 1600, "kind": "theft_tool", "tool": "jimmy",    "level": 3,
	 "desc": "Jimmy Lv3. Even wider zone."},
	{"id": "lockpick", "name": "Lock Pick Set",       "price": 1400, "kind": "theft_tool", "tool": "lockpick", "level": 1,
	 "desc": "Opens tier-2 cars without leveling the jimmy."},
	{"id": "lockpick3","name": "Master Pick Set",     "price": 4200, "kind": "theft_tool", "tool": "lockpick", "level": 3,
	 "desc": "Lockpick Lv3. Required for sports cars."},
	{"id": "scanner",  "name": "Key Scanner",         "price": 7000, "kind": "theft_tool", "tool": "scanner",  "level": 1,
	 "desc": "Grabs the fob signal. Sports cars, no sweat."},
	{"id": "scanner2", "name": "Long-Range Scanner",  "price": 12000,"kind": "theft_tool", "tool": "scanner",  "level": 2,
	 "desc": "Scanner Lv2. Reads a fob through the door of anything up to a sports car."},
	{"id": "cloner",   "name": "Key Cloner",          "price": 9000, "kind": "theft_tool", "tool": "duplicator","level": 1,
	 "desc": "Writes the fob it just read onto a blank. Beats the immobiliser on anything a scanner can reach."},
	{"id": "cloner2",  "name": "Fleet Key Cloner",    "price": 18000,"kind": "theft_tool", "tool": "duplicator","level": 2,
	 "desc": "Cloner Lv2. The only thing that will take a Chrome Land Yacht off its driver."},

	{"id": "jack",     "name": "Hydraulic Jack",      "price": 900,  "kind": "shop_tool",  "tool": "jack",
	 "desc": "Lets you jack a car up. Wheels and the transmission need it off the ground."},
	{"id": "sawzall",  "name": "Reciprocating Saw",   "price": 600,  "kind": "shop_tool",  "tool": "sawzall",
	 "desc": "Cuts exhaust pipe and rusted flanges. Also cuts hinges, if you are in a hurry."},
	{"id": "toolset",  "name": "Professional Tool Set","price": 1000,"kind": "shop_tool",  "tool": "toolset",
	 "desc": "Bigger success window on every fastener. Stop using a rock."},
	{"id": "impact",   "name": "Impact Driver",       "price": 3000, "kind": "shop_tool",  "tool": "impact_drill",
	 "desc": "Goes on your belt. Does wheel nuts and bolts alike, in a fraction of the turns."},
	{"id": "sander",   "name": "Angle Sander",       "price": 1800, "kind": "shop_tool",  "tool": "sander",
	 "desc": "Goes on your belt. Grinds the number off a panel before you sell it -- a part nobody can trace is worth a great deal more."},
	{"id": "spray_gun","name": "Spray Gun",          "price": 3400, "kind": "shop_tool",  "tool": "spray_gun",
	 "desc": "Respray a car on the ramp. A different colour is a different car to anybody looking for the old one."},
	{"id": "flashlight", "name": "Flashlight",      "price": 220,  "kind": "shop_tool",  "tool": "flashlight",
	 "desc": "Goes on your belt. You can see what you are doing after dark -- and so can they."},
	{"id": "spare_wrench", "name": "Spare Socket Wrench", "price": 120, "kind": "shop_tool", "tool": "socket_wrench",
	 "desc": "In case you left the first one under a car somewhere."},
	{"id": "hoist",    "name": "Engine Hoist",        "price": 2500, "kind": "shop_tool",  "tool": "hoist",
	 "desc": "Crank the engine and box out instead of hauling on a chain."},
	{"id": "lift",     "name": "Vehicle Lift",        "price": 4000, "kind": "shop_tool",  "tool": "lift",
	 "desc": "Unlocks underbody work (catalytic converter) and lifts cars on its own."},
	{"id": "bench",    "name": "Industrial Workbench","price": 2000, "kind": "shop_tool",  "tool": "bench",
	 "desc": "Unlocks ELECTRONICS harvesting."},

	{"id": "belt",     "name": "Tool Belt",           "price": 900,  "kind": "shop_tool",  "tool": "belt",
	 "desc": "Two more loops on the belt: four things on you at once instead of two."},
	{"id": "belt_large","name": "Rigger Belt",        "price": 2600, "kind": "shop_tool",  "tool": "belt_large",
	 "desc": "Six loops. Carry the lot and stop choosing."},

	{"id": "pistol",   "name": "Battered Pistol",     "price": 600,  "kind": "shop_tool",  "tool": "pistol",
	 "desc": "Twelve rounds of very bad decision making. [LMB] fires, [R] reloads."},

	{"id": "hitch",    "name": "Tow Hitch",           "price": 800,  "kind": "shop_tool",  "tool": "hitch",
	 "desc": "Drag a whole junker to the yard instead of stripping it."},
	{"id": "hitch2",   "name": "Heavy Tow Rig",       "price": 3200, "kind": "shop_tool",  "tool": "hitch2",
	 "desc": "Tow tier-2 cars as well."},

	{"id": "truck2",   "name": "Box Truck",           "price": 6000, "kind": "truck",      "level": 2,
	 "desc": "48 units of cargo, up from 20. Two cars a trip."},
	{"id": "truck3",   "name": "Semi and Trailer",    "price": 18000,"kind": "truck",      "level": 3,
	 "desc": "110 units. Clear the whole shop in one run."},

	{"id": "buyer_mechanic",  "name": "Contact: Ferret the Mechanic", "price": 2500, "kind": "buyer", "buyer": "mechanic",
	 "desc": "Unlocks a buyer who pays 50% over the odds for engines and boxes."},
	{"id": "buyer_shady",     "name": "Contact: Deniz",               "price": 3500, "kind": "buyer", "buyer": "shady",
	 "desc": "Unlocks a buyer paying 90% over for electronics."},
	{"id": "buyer_specialty", "name": "Contact: The Collector",       "price": 9000, "kind": "buyer", "buyer": "specialty",
	 "desc": "Unlocks a buyer paying 35% over the odds on everything."},

	{"id": "garage2",  "name": "Garage Tier 2",       "price": 2500, "kind": "garage",     "level": 2,
	 "desc": "Small Chop Shop. 2 bays, lights that work, +10% part prices."},
	{"id": "garage3",  "name": "Garage Tier 3",       "price": 9000, "kind": "garage",     "level": 3,
	 "desc": "Professional Operation. 3 bays, +25% part prices."},
]

# ---------- HELPERS ----------
static func vehicle_by_id(id: String) -> Dictionary:
	for v in VEHICLES:
		if v.id == id:
			return v
	return {}

static func upgrade_by_id(id: String) -> Dictionary:
	for u in UPGRADES:
		if u.id == id:
			return u
	return {}

static func part_value(part_id: String, mult: float, condition: float) -> int:
	var base: float = float(PARTS[part_id].base_value) * mult
	return int(round(base * lerpf(0.55, 1.15, condition)))

static func stages_summary(part_id: String) -> String:
	var bits := []
	for st in PARTS[part_id].stages:
		bits.append(String(st.label))
	return " > ".join(bits)
