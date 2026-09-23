extends Node
##
## Level data for Lanternbound.
##
## Levels are plain ASCII maps, one character per 32x32 tile, so they are easy
## to hand-edit. Legend:
##
##   #  solid rock / stone
##   ~  hidden platform  (only solid + visible inside lantern light)
##   H  ladder / vine    (hold Up / Down to climb)
##   ^  spikes           (environmental hazard)
##   *  memory fragment  (collectible)
##   o  lantern oil      (restores lantern energy)
##   C  checkpoint       (saves progress, refills health + energy)
##   E  shadow enemy     (burned away by lantern light)
##   /  mirror           (reflects the focused light beam, "/" angle)
##   \  mirror           (the mirrored angle - write it as "\\" in GDScript)
##   R  light rune       (receiver: opens every door while lit by the beam)
##   D  sealed door      (opens when all runes in the level are lit)
##   P  player spawn
##   X  level exit
##

const LEVELS := [
	{
		"name": "I. The Abandoned Village",
		"subtitle": "Keep the flame. The dark remembers you.",
		"ambient": Color(0.26, 0.29, 0.42),
		"unlock": -1,
		"hint": "F toggles the lantern. Some paths only exist in the light.",
		"map": [
			"                                                            ",
			"                                                            ",
			"                                                            ",
			"           *                                                ",
			"         #####                                              ",
			"                                                            ",
			"                        *                                   ",
			"     ####             ######                                ",
			"                                                            ",
			"                                  *                         ",
			"   ####          #####          ####       ####             ",
			"                                                            ",
			" P      C      ^^   o    *      ~~~~~     E              X  ",
			"###############################     #######################",
			"###############################     #######################",
			"###############################     #######################",
		],
	},
	{
		"name": "II. The Dark Forest",
		"subtitle": "Older things than shadow sleep beneath the roots.",
		"ambient": Color(0.20, 0.26, 0.36),
		"unlock": 1,  # Game.Lantern.SPIRIT
		"hint": "TAB swaps lanterns. The Spirit Lantern reaches further into the dark.",
		"map": [
			"                                                              ",
			"            *                                                 ",
			"         ########                                             ",
			"        H                                                     ",
			"        H               *                                     ",
			"        H            #######                                  ",
			"   #####H########                                             ",
			"        H          ####                    ~~~~~~             ",
			"        H                 *                o                  ",
			"        H                                ######               ",
			"        H         ########                            ####    ",
			"  P     H       E         ^^  C  E      *                 X   ",
			"##################      ####################      ############",
			"##################      ####################      ############",
		],
	},
	{
		"name": "III. The Sunken Temple",
		"subtitle": "Light bends here. So does the truth.",
		"ambient": Color(0.17, 0.20, 0.34),
		"unlock": 2,  # Game.Lantern.FIRE
		"hint": "Hold R to focus a beam. Mirrors bend it - wake the rune to open the way.",
		"map": [
			"                                                        ",
			"                                                        ",
			"                                                        ",
			"                          ######                        ",
			"                                                        ",
			"                                  /        R            ",
			"                                                        ",
			"              #####                                     ",
			"                                                        ",
			"                      o *                               ",
			"                     ######                   D         ",
			"                                              D         ",
			"      *     ^^  C   E       E     /           D    X    ",
			"########################################################",
			"########################################################",
			"########################################################",
		],
	},
]
