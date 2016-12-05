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
.align 2
tile_data: .space 1600
puzzle: .space 4096
solutions: .space 328

original_place:
	.word 0, 0, 0		#x,y,enemyexist

should_stop:
	.word 0
can_request:
	.word 0



.text
main:
	
	la $t0, original_place
	lw $t1, BOT_X
	lw $t2, BOT_Y
	sw $t1, 0($t0)
	sw $t2, 4($t0)
	
	li $t0, ON_FIRE_MASK
	ori $t0, $t0, 1
	ori $t0, $t0, TIMER_MASK
	ori $t0, $t0, MAX_GROWTH_INT_MASK
	ori $t0, $t0, REQUEST_PUZZLE_INT_MASK
	mtc0 $t0, $12		#enable fire interrupt

action:
	la $t0, tile_data
	sw $t0, TILE_SCAN

	sub $sp, $sp, 16
	sw $ra, 0($sp)
	sw $v0, 4($sp)
	sw $a0, 8($sp)
	sw $a1, 12($sp)

	li $a0, 10
	li $a1, 10
	jal move

	lw $ra, 0($sp)
	lw $v0, 4($sp)
	lw $a0, 8($sp)
	lw $a1, 12($sp)

	add $sp, $sp, 16

while1:	
	beq, $t0, $0, stop_moving_and_plant

	sub $sp, $sp, 8
	sw $ra, 0($sp)
	sw $v0, 4($sp)

	jal request_seed

	lw $ra, 0($sp)
	lw $v0, 4($sp)

	jal request_water

	lw $ra, 0($sp)
	lw $v0, 4($sp)

	add $sp, $sp, 8

	j while1

stop_moving_and_plant:

        sub $sp, $sp, 16
        sw $ra, 0($sp)
        sw $v0, 4($sp)
        sw $a0, 8($sp)
        sw $a1, 12($sp)

        li $a0, 10
        li $a1, 10
        jal harvesting_planting

        lw $ra, 0($sp)
        lw $v0, 4($sp)
        lw $a0, 8($sp)
        lw $a1, 12($sp)

        add $sp, $sp, 16

        sub $sp, $sp, 8
        sw $ra, 0($sp)
        sw $v0, 4($sp)
        
        jal check_enemy_exist

        move $t0, $v0

        lw $ra, 0($sp)
        lw $v0, 4($sp)

        add $sp, $sp, 8

	beq $t0, $0, sabo		#check enemy exist

	j action	
sabo:
	
	sub $sp, $sp, 16
	sw $ra, 0($sp)
	sw $v0, 4($sp)
	sw $a0, 8($sp)
	sw $a1, 12($sp)

	li $a0, ????????
	li $a1, ????????
	jal move

	lw $ra, 0($sp)
	lw $v0, 4($sp)
	lw $a0, 8($sp)
	lw $a1, 12($sp)

	add $sp, $sp, 16

while2:	
	beq, $t0, $0, stop_moving_and_fire

	sub $sp, $sp, 8
	sw $ra, 0($sp)
	sw $v0, 4($sp)

	jal request_fire

	lw $ra, 0($sp)
	lw $v0, 4($sp)

	add $sp, $sp, 8

	j while2

stop_moving_and_fire:

        sub $sp, $sp, 16
        sw $ra, 0($sp)
        sw $v0, 4($sp)
        sw $a0, 8($sp)
        sw $a1, 12($sp)

        li $a0, 10
        li $a1, 10
        jal set_fire

        lw $ra, 0($sp)
        lw $v0, 4($sp)
        lw $a0, 8($sp)
        lw $a1, 12($sp)

        add $sp, $sp, 16

	j action

	j main




###### function check_enemy_exist
check_enemy_exist:

	la $t0, original_place
	
	lw $t1, 8(t0)
	beq $t1, $0, check
	li $v0, 1		#always know there is an enemy
	jr $ra
	
check:	
	lw $t0, 0($t0)
	lw $t1, 4($t0)
	
	lw $t2, OTHER_BOT_X
	lw $t3, OTHER_BOT_Y

	beq $t0, $t2, next
	li $v0, 1
	sw $v0, 8($t0)
	jr $ra

next:
	beq $t3, $t1, not_exist
	li $v0, 1
	sw $v0, 8($t0)
	jr $ra

not_exist:

	li $v0, 0
	jr $ra

####### function set fire
set_fire:
	jr $ra


####### function harvest&plant
harvesting_planting:
		
	

