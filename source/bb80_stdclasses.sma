#pragma dynamic 2048

#include <amxmodx>

#include "include/basebuilder.inc"

#define PLUGIN_VERSION "0.0.1"

public bb_fw_init() {
	bb_core_registerPlugin("Base Builder [Standard Classes]", "Registers standard classes with the class manager", PLUGIN_VERSION);
}

public bb_fw_init_post() {
	bb_class_registerClass(
		.name = "Classic",
		.description = "A well-balanced mix of all zombie traits",
		.model = "bb_classic",
		.handModel = "v_bloodyhands",
		.health = 3000.0,
		.speed = 1.0,
		.gravity = 0.85,
		.cost = 0,
		.levelReq = 0
	);

	bb_class_registerClass(
		.name = "Fast",
		.description = "Sacrifice some health for a speed boost",
		.model = "bb_fast",
		.handModel = "v_bloodyhands",
		.health = 2000.0,
		.speed = 1.25,
		.gravity = 0.9,
		.cost = 0,
		.levelReq = 0
	);
	
	bb_class_registerClass(
		.name = "Jumper",
		.description = "Sacrifice some health for higher jump",
		.model = "bb_jumper",
		.handModel = "v_bloodyhands",
		.health = 2500.0,
		.speed = 1.0,
		.gravity = 0.5,
		.cost = 0,
		.levelReq = 0
	);
	
	bb_class_registerClass(
		.name = "Tanker",
		.description = "When in doubt, let the Tanker lead",
		.model = "bb_tanker",
		.handModel = "v_bloodyhands",
		.health = 5000.0,
		.speed = 0.85,
		.gravity = 1.0,
		.cost = 0,
		.levelReq = 0
	);
}