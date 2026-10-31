class_name OfficeGoals
extends RefCounted
## Spots the milestones Dale's story asks for that the Loot Machine link
## doesn't count: beating a Pong boss, beating the cube world record scramble,
## and proving a theorem at the Proof Desk. The office feeds it what each game
## shows every frame; each call returns how many to add to the shared stat
## (pong_bosses, cube_records, proof_wins). Pure rules, no scenes.

## Phone Pong: every 4th stage is a boss.
const PONG_BOSS_EVERY := 4
## Cube Desk: level 9 is the 2.51 s world record scramble.
const CUBE_RECORD_LEVEL := 9

var _pong_stage := 0
var _cube_solves := -1
var _proof_blind_id := 0


## Pong's current stage; a boss is beaten when the stage moves past a
## multiple of 4. Cheated runs (its hidden test menu) don't count.
func pong(stage: int, cheated: bool) -> int:
	var beaten := 0
	if _pong_stage > 0 and stage > _pong_stage and not cheated:
		for s in range(_pong_stage, stage):
			if s % PONG_BOSS_EVERY == 0:
				beaten += 1
	_pong_stage = stage
	return beaten


## Cube Desk's solve count and the level of the last solve.
func cube(solves: int, last_level: int) -> int:
	var first := _cube_solves < 0
	var more := solves > _cube_solves
	_cube_solves = solves
	return 1 if not first and more and last_level >= CUBE_RECORD_LEVEL else 0


## Proof Hand's current blind (a new object each round) and whether it's won.
## Each round counts once.
func proof(blind: Object, won: bool) -> int:
	if blind == null or not won:
		return 0
	var id := blind.get_instance_id()
	if id == _proof_blind_id:
		return 0
	_proof_blind_id = id
	return 1
