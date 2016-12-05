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
# Space for puzzle solutions
solution_data: .space 328;
# Space to hold two puzzles
puzzle1_data: .space 4096;
puzzle2_data: .space 4096;
#This will alternate between puzzle1 and puzzle2.
next_puzzle_pointer: .word 0;
current_puzzle_pointer: .word 0;
#How many puzzles are unsolved
num_puzzles: .byte 0x0000;
current_puzzle_is_ready: .byte 0x0000;
next_puzzle_is_ready: .byte 0x0000;

tile_data: .space 1600

move_state:
		.word 	0, 0, 0
seeds:
	.word 10
water:
	.word 100

puzzle_track:
	.word 0, 0
isfire:
	.word 0
fire_place:
	.word 0, 0
isripe:
	.word 0
ripe_place:
	.word 0, 0
final_tile:
	.word 0, 0
# [imported - taylor.s]
three:	
		.float	3.0
five:	
		.float	5.0
PI:		
		.float	3.141592
F180:	
		.float  180.0


.text
main:
	
	li $t0, 1
	ori $t0, $t0, TIMER_MASK
	ori $t0, $t0, MAX_GROWTH_INT_MASK
	ori $t0, $t0, REQUEST_PUZZLE_INT_MASK
	mtc0 $t0, $12		#enable  interrupt

action:
	la $t0, tile_data
	sw $t0, TILE_SCAN

	sub $sp, $sp, 20
	sw $ra, 0($sp)
	sw $v0, 4($sp)
	sw $a0, 8($sp)
	sw $a1, 12($sp)
	sw $a2, 16($sp)

	li $a0, 9
	li $a1, 9
	li $a2, 10

	jal move_package_tile

	lw $ra, 0($sp)
	lw $v0, 4($sp)
	lw $a0, 8($sp)
	lw $a1, 12($sp)
	sw $a2, 16($sp)

	add $sp, $sp, 20

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

	j action	

	j main


########################function harversting_planting
harvesting_planting:

	li $t2, 9
	li $t1, 4		#vertical move number

no_harvest_workloop:
	beq $t1, 0, next_line	# one line ends
	la $t0, final_tile
	lw $t3, 0($t0)
	lw $t4, 4($t0)
	blt $t1, $t3, next_round_harvest
	blt $t2, $t4, next_round_harvest 

	la $t0, tile_data
	sw $t0, TILE_SCAN
	
        sub $sp, $sp, 32	#go to next tile
        sw $ra, 0($sp)
        sw $v0, 4($sp)
        sw $a0, 8($sp)
        sw $a1, 12($sp)
        sw $a2, 16($sp)
	sw $t0, 20($sp)
	sw $t1, 24($sp)
	sw $t2, 28($sp)

	move $a0, $t2
	add $a1, $t1, 5
        li $a2, 10
        jal move_package_tile

        lw $ra, 0($sp)
        lw $v0, 4($sp)
        lw $a0, 8($sp)
        lw $a1, 12($sp)
        lw $a2, 16($sp)
	lw $t0, 20($sp)
	lw $t1, 24($sp)
	lw $t2, 28($sp)
        add $sp, $sp, 32	

	la $t5, is_ripe		#(9,9) ripe! harvest time!
	beq $t5, $0, no_harvest_then
 
	li $t9, 1
	sw $t9, HARVEST_TILE
	

no_harvest_then:
	li $t4, 1	
	sw $t4, SEED_TILE	#seed	
	li $t4, 4
	sw $t4, WATER_TILE	#water

	la $t4, isfire
	beq $t4, $0, no_fire	# there is a fire

	la $t4, fire_place	#go to fire
	
	sub $sp, $sp, 32
        sw $ra, 0($sp)
        sw $v0, 4($sp)
        sw $a0, 8($sp)
        sw $a1, 12($sp)
        sw $a2, 16($sp)
        sw $t0, 20($sp)
        sw $t1, 24($sp)
        sw $t2, 28($sp)

        lw $a0, 0($t4)
        lw $a1, 4($t4)
        li $a2, 10
        jal move_package_pixel

        lw $ra, 0($sp)
        lw $v0, 4($sp)
        lw $a0, 8($sp)
        lw $a1, 12($sp)
        lw $a2, 16($sp)
        lw $t0, 20($sp)
        lw $t1, 24($sp)
        lw $t2, 28($sp)
        add $sp, $sp, 32

	li $t4, 1
	sw $t4, PUT_OUT_FIRE
	la $t4, isfire
	lw $0, 0($t4)	#set the isfire back to 0

no_fire:

	la $t4, isripe
	beq $t4, $0, no_ripe

#	la $t4, start_to_ripe
#	li $t5, 1
#	lw $t5, 0($t4)

	la $t4, final_tile		# save the final spot
	sw $t1, 0($t4)
	sw $t2, 4($t4)

        sub $sp, $sp, 32        #try to move back incase there is a fire
        sw $ra, 0($sp)
        sw $v0, 4($sp)
        sw $a0, 8($sp)
        sw $a1, 12($sp)
        sw $a2, 16($sp)
        sw $t0, 20($sp)
        sw $t1, 24($sp)
        sw $t2, 28($sp)

        li $a0, 9
        li $a1, 9
        li $a2, 10
        jal move_package_tile

        lw $ra, 0($sp)
        lw $v0, 4($sp)
        lw $a0, 8($sp)
        lw $a1, 12($sp)
        lw $a2, 16($sp)
        lw $t0, 20($sp)
        lw $t1, 24($sp)
        lw $t2, 28($sp)
        add $sp, $sp, 32


        j no_harvest_workloop

no_ripe:
#	mul $t4, $t1, $t2
#	div $t4, 2
#	mfhi $t4

        sub $sp, $sp, 32        #try to move back incase there is a fire
        sw $ra, 0($sp)
        sw $v0, 4($sp)
        sw $a0, 8($sp)
        sw $a1, 12($sp)
        sw $a2, 16($sp)
        sw $t0, 20($sp)
        sw $t1, 24($sp)
        sw $t2, 28($sp)

        move $a0, $t2
        add $a1, $t1, 5
        li $a2, 10
        jal move_package_tile

        lw $ra, 0($sp)
        lw $v0, 4($sp)
        lw $a0, 8($sp)
        lw $a1, 12($sp)
        lw $a2, 16($sp)
        lw $t0, 20($sp)
        lw $t1, 24($sp)
        lw $t2, 28($sp)
        add $sp, $sp, 32

	sub $t1, $t1, 1
	j no_harvest_workloop
		
next_line:
	sub $t2, $t2, 1
	li $t1, 4

	j no_harvest_workloop

next_round_harvest:
	li $t1, 9
	li $t2, 9

	j no_harvest_workloop		

end:
	jr $ra


#######################function move_package_pixel
move_package_pixel:
        sub $sp, $sp, 20
        sw $ra, 0($sp)
        sw $v0, 4($sp)
        sw $a0, 8($sp)
        sw $a1, 12($sp)
        sw $a2, 16($sp)

        jal move_to_pixel

        lw $ra, 0($sp)
        lw $v0, 4($sp)
        lw $a0, 8($sp)
        lw $a1, 12($sp)
        sw $a2, 16($sp)

        add $sp, $sp, 20

while1:
        la $t0, move_state
        lw $t0, 0($t0)
        beq, $t0, $0, end_move_package_pixel

        sub $sp, $sp, 8
        sw $ra, 0($sp)
        sw $v0, 4($sp)
        jal can_request_puzzle			#can request
        move $t0, $v0
        lw $ra, 0($sp)
        lw $v0, 4($sp)
        add $sp, $sp, 8

        beq $t0, $0, no_request

        la $t1, seed
        lw $t1, 0($t1)
        la $t2, water
        lw $t2, 0($t2)

        sub $sp, $sp, 8
        sw $ra, 0($sp)
        sw $v0, 4($sp)
	bge $t2, $t1, requestseed
        blt $t2, $t1, requestwater
requestseed:
        jal request_seed			#request
        lw $ra, 0($sp)
        lw $v0, 4($sp)
	add $sp, $sp, 8

	la $t0, puzzle_track			#update puzzle track
	lw $t1, 0($t0)
	beq $t1, $0, update1
	bne $t1, $0, update2
update1:
	li $t1, 1
	sw $t1, 0($t0)
	j done_request

update2:
	li $t1, 1
	sw $t1, 4($t0)
	j done_request

requestwater:
        jal request_water
        lw $ra, 0($sp)
        lw $v0, 4($sp)
	add $sp, $sp, 8

	la $t0, puzzle_track			#update puzzle track
	lw $t1, 0($t0)
	beq $t1, $0, update1
	bne $t1, $0, update2
update1:
	li $t1, 2
	sw $t1, 0($t0)
	j done_request

update2:
	li $t1, 2
	sw $t1, 4($t0)
	j done_request

done_request:
no_request:
	sub $sp, $sp, 8
        sw $ra, 0($sp)
        sw $v0, 4($sp)
        jal can_solve_puzzle                  #can solve puzzle
        move $t0, $v0
        lw $ra, 0($sp)
        lw $v0, 4($sp)
        add $sp, $sp, 8

	beq $t0, $0, no_solve

        sub $sp, $sp, 8
        sw $ra, 0($sp)
        sw $v0, 4($sp)
        jal solve_puzzle                  	#solve puzzle
        lw $ra, 0($sp)
        lw $v0, 4($sp)
        add $sp, $sp, 8

        sub $sp, $sp, 8
        sw $ra, 0($sp)
        sw $v0, 4($sp)
        jal submit_puzzle                        #submit puzzle
        lw $ra, 0($sp)
        lw $v0, 4($sp)
        add $sp, $sp, 8

	la $t0, puzzle_track			#add send/water, and track the puzzle
	lw $t1, 0($t0)
	beq $t1, 1, addseed
	beq $t1, 2, addwater
	
addseed:					#add seed
	la $t3, seed
	lw $t4, 0($t3)
	add $t4, $t4, 3
	sw $t4, 0($t3)
	j done_adding

addwater:					#add water
	la $t3, water
	lw $t4, 0 ($t3)
	add $t4, $t4, 10
	sw $t4, 0($t3)

done_adding:					#track the puzzle, update the first, ignore second
	lw $t2, 4($t0)
	sw $t2, 0($t0)


no_solve:
        j while1
	

end_move_package_pixel:
	jr $ra



#######################function move_package_tile
move_package_tile:
        sub $sp, $sp, 20
        sw $ra, 0($sp)
        sw $v0, 4($sp)
        sw $a0, 8($sp)
        sw $a1, 12($sp)
        sw $a2, 16($sp)

        jal move_to_tile

        lw $ra, 0($sp)
        lw $v0, 4($sp)
        lw $a0, 8($sp)
        lw $a1, 12($sp)
        sw $a2, 16($sp)

        add $sp, $sp, 20

while1:
        la $t0, move_state
        lw $t0, 0($t0)
        beq, $t0, $0, end_move_package_tile

        sub $sp, $sp, 8
        sw $ra, 0($sp)
        sw $v0, 4($sp)
        jal can_request_puzzle			#can request
        move $t0, $v0
        lw $ra, 0($sp)
        lw $v0, 4($sp)
        add $sp, $sp, 8

        beq $t0, $0, no_request

        la $t1, seed
        lw $t1, 0($t1)
        la $t2, water
        lw $t2, 0($t2)

        sub $sp, $sp, 8
        sw $ra, 0($sp)
        sw $v0, 4($sp)
	bge $t2, $t1, requestseed
        blt $t2, $t1, requestwater
requestseed:
        jal request_seed			#request
        lw $ra, 0($sp)
        lw $v0, 4($sp)
	add $sp, $sp, 8

	la $t0, puzzle_track			#update puzzle track
	lw $t1, 0($t0)
	beq $t1, $0, update1
	bne $t1, $0, update2
update1:
	li $t1, 1
	sw $t1, 0($t0)
	j done_request

update2:
	li $t1, 1
	sw $t1, 4($t0)
	j done_request

requestwater:
        jal request_water
        lw $ra, 0($sp)
        lw $v0, 4($sp)
	add $sp, $sp, 8

	la $t0, puzzle_track			#update puzzle track
	lw $t1, 0($t0)
	beq $t1, $0, update1
	bne $t1, $0, update2
update1:
	li $t1, 2
	sw $t1, 0($t0)
	j done_request

update2:
	li $t1, 2
	sw $t1, 4($t0)
	j done_request

done_request:
no_request:
	sub $sp, $sp, 8
        sw $ra, 0($sp)
        sw $v0, 4($sp)
        jal can_solve_puzzle                  #can solve puzzle
        move $t0, $v0
        lw $ra, 0($sp)
        lw $v0, 4($sp)
        add $sp, $sp, 8

	beq $t0, $0, no_solve

        sub $sp, $sp, 8
        sw $ra, 0($sp)
        sw $v0, 4($sp)
        jal solve_puzzle                  	#solve puzzle
        lw $ra, 0($sp)
        lw $v0, 4($sp)
        add $sp, $sp, 8

        sub $sp, $sp, 8
        sw $ra, 0($sp)
        sw $v0, 4($sp)
        jal submit_puzzle                        #submit puzzle
        lw $ra, 0($sp)
        lw $v0, 4($sp)
        add $sp, $sp, 8

	la $t0, puzzle_track			#add send/water, and track the puzzle
	lw $t1, 0($t0)
	beq $t1, 1, addseed
	beq $t1, 2, addwater
	
addseed:					#add seed
	la $t3, seed
	lw $t4, 0($t3)
	add $t4, $t4, 3
	sw $t4, 0($t3)
	j done_adding

addwater:					#add water
	la $t3, water
	lw $t4, 0 ($t3)
	add $t4, $t4, 10
	sw $t4, 0($t3)

done_adding:					#track the puzzle, update the first, ignore second
	lw $t2, 4($t0)
	sw $t2, 0($t0)


no_solve:
        j while1
	

end_move_package_tile:
	jr $ra



