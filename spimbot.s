# syscall constants
PRINT_STRING = 4
PRINT_CHAR   = 11
PRINT_INT    = 1

# debug constants
PRINT_INT_ADDR   = 0xffff0080
PRINT_FLOAT_ADDR = 0xffff0084
PRINT_HEX_ADDR   = 0xffff0088

# spimbot constants
VELOCITY       = 0xffff0010
ANGLE          = 0xffff0014
ANGLE_CONTROL  = 0xffff0018
BOT_X          = 0xffff0020
BOT_Y          = 0xffff0024
OTHER_BOT_X    = 0xffff00a0
OTHER_BOT_Y    = 0xffff00a4
TIMER          = 0xffff001c
SCORES_REQUEST = 0xffff1018

TILE_SCAN       = 0xffff0024
SEED_TILE       = 0xffff0054
WATER_TILE      = 0xffff002c
MAX_GROWTH_TILE = 0xffff0030
HARVEST_TILE    = 0xffff0020
BURN_TILE       = 0xffff0058
GET_FIRE_LOC    = 0xffff0028
PUT_OUT_FIRE    = 0xffff0040

GET_NUM_WATER_DROPS   = 0xffff0044
GET_NUM_SEEDS         = 0xffff0048
GET_NUM_FIRE_STARTERS = 0xffff004c
SET_RESOURCE_TYPE     = 0xffff00dc
REQUEST_PUZZLE        = 0xffff00d0
SUBMIT_SOLUTION       = 0xffff00d4

# interrupt constants
BONK_MASK               = 0x1000
BONK_ACK                = 0xffff0060
TIMER_MASK              = 0x8000
TIMER_ACK               = 0xffff006c
ON_FIRE_MASK            = 0x400
ON_FIRE_ACK             = 0xffff0050
MAX_GROWTH_ACK          = 0xffff005c
MAX_GROWTH_INT_MASK     = 0x2000
REQUEST_PUZZLE_ACK      = 0xffff00d8
REQUEST_PUZZLE_INT_MASK = 0x800

.data
# data things go here

.text
request_seeds:

	li $t0, 0  # 0 for water, 1 for seeds, 2 for fire starters
	sw $t0, SET_RESOURCE_TYPE

	la $t0, puzzle_data
	sw $t0, REQUEST_PUZZLE

request_water:

	li $t0, 1  # 0 for water, 1 for seeds, 2 for fire starters
	sw $t0, SET_RESOURCE_TYPE

	la $t0, puzzle_data
	sw $t0, REQUEST_PUZZLE

request_fire:

	li $t0, 2  # 0 for water, 1 for seeds, 2 for fire starters
	sw $t0, SET_RESOURCE_TYPE

	la $t0, puzzle_data
	sw $t0, REQUEST_PUZZLE

main:

	li $t0, ON_FIRE_MASK
	ori $t0, $t0, 1
	mtc0 $t0, $12		#enable fire interrupt
	
	la $t0, tile_data
	sw $t0, TILE_SCAN

	sw $0, VELOCITY

	j main

#fire interrupt

.kdata
	chunkIH: .space 40

.ktext 0x80000180
interrupt_handler:
.set noat
	move $k1, $at
.set at
	la $k0, chunkIH
	sw $t0, 0($k0)
	sw $t1, 4($k0)
	sw $t2, 8($k0)
	sw $t3, 12($k0)
	sw $t4, 16($k0)
	sw $t5, 20($k0)
	sw $t6, 24($k0)
	sw $t7, 28($k0)
	sw $a0, 32($k0)
	sw $a1, 36($k0)

	mfc0 $k0, $13
	srl $a0, $k0, 2
	and $a0, $a0, 0xf
	bne $a0, 0, done

interrupt_dispatch:

	mfc0 $k0, $13
	beq $k0, $0, done

	and $a0, $k0, ON_FIRE_MASK
	bne $a0, $0, fire_interrupt

	j done


fire_interrupt:
	sw $a1, ON_FIRE_ACK

	lw $a1, GET_FIRE_LOC
	srl $t4, $a1, 16	#x_index
	and $t5, $a1, 0xffff 	#y_index

	mul $t4, $t4, 30
	add $t4, $t4, 15		#wanted x
	mul $t5, $t5, 30
	add $t5, $t5, 15		#wanted y
	
	lw $t6, BOT_X
	lw $t7, BOT_Y

	bgt $t4, $t6, fire_goright
	blt $t4, $t6, fire_goleft
	j fire_afterX

fire_goright:
	li $t8, 0
	sw $t8, ANGLE
	li $t8, 1
	sw $t8, ANGLE_CONTROL
	li $t8, 10
	sw $t8, VELOCITY

	lw $t6, BOT_X
	bgt $t4, $t6, fire_goright
	sw $0, VELOCITY
	j fire_afterX

fire_goleft:
	li $t8, 180
	sw $t8, ANGLE
	li $t8, 1
	sw $t8, ANGLE_CONTROL
	li $t8, 10
	sw $t8, VELOCITY

	lw $t6, BOT_X
	blt $t4, $t6, fire_goleft
	sw $0, VELOCITY
	j fire_afterX


fire_afterX:
	bgt $t5, $t7, fire_godown
	blt $t5, $t7, fire_goup
	j water

fire_godown:
	li $t8, 90
	sw $t8, ANGLE
	li $t8, 1
	sw $t8, ANGLE_CONTROL
	li $t8, 10
	sw $t8, VELOCITY

	lw $t7, BOT_Y
	bgt $t5, $t7, fire_godown
	sw $0, VELOCITY
	j water

fire_goup:
	li $t8, 270
	sw $t8, ANGLE
	li $t8, 1
	sw $t8, ANGLE_CONTROL
	li $t8, 10
	sw $t8, VELOCITY

	lw $t7, BOT_Y
	blt $t5, $t7, fire_goup
	sw $0, VELOCITY
	j water

water:
	li $t9, 1
	sw $t9, PUT_OUT_FIRE

	addi $t1, $t1, 1

	j interrupt_dispatch

done:
	la $k0, chunkIH

	lw $t0, 0($k0)
	lw $t1, 4($k0)
	lw $t2, 8($k0)
	lw $t3, 12($k0)
	lw $t4, 16($k0)
	lw $t5, 20($k0)
	lw $t6, 24($k0)
	lw $t7, 28($k0)
	lw $a0, 32($k0)
	lw $a1, 36($k0)

.set noat
	move $at, $k1
.set at
	eret


