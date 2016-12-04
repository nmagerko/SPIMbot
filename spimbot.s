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
# the current movement state structure
# contents are [valid, x, y]
move_state:
		.word 	0, 0, 0

# the following are data members used by 
# the provided taylor.s functions
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
	li 		$t0, 0x8000                                   # timer interrupt enable bit
	or 		$t0, $t0, 1                                   # global interrupt enable
	mtc0 	$t0, $12                                      # set interrupt mask

	li  	$a0, 3
	li  	$a1, 7
	li  	$a2, 3
	jal 	move_to

infinite:	
	j	infinite

# -----------------------------------------------------------------------
# computes the arctangent of y / x
#
# $a0 - x
# $a1 - y
# returns the arctangent
# -----------------------------------------------------------------------
sb_arctan:
	li	$v0, 0		# angle = 0;

	abs	$t0, $a0	# get absolute values
	abs	$t1, $a1
	ble	$t1, $t0, no_TURN_90	  

	## if (abs(y) > abs(x)) { rotate 90 degrees }
	move	$t0, $a1	# int temp = y;
	neg	$a1, $a0	# y = -x;      
	move	$a0, $t0	# x = temp;    
	li	$v0, 90		# angle = 90;  

no_TURN_90:
	bgez	$a0, pos_x 	# skip if (x >= 0)

	## if (x < 0) 
	add	$v0, $v0, 180	# angle += 180;

pos_x:
	mtc1	$a0, $f0
	mtc1	$a1, $f1
	cvt.s.w $f0, $f0	# convert from ints to floats
	cvt.s.w $f1, $f1
	
	div.s	$f0, $f1, $f0	# float v = (float) y / (float) x;

	mul.s	$f1, $f0, $f0	# v^^2
	mul.s	$f2, $f1, $f0	# v^^3
	l.s	$f3, three	# load 5.0
	div.s 	$f3, $f2, $f3	# v^^3/3
	sub.s	$f6, $f0, $f3	# v - v^^3/3

	mul.s	$f4, $f1, $f2	# v^^5
	l.s	$f5, five	# load 3.0
	div.s 	$f5, $f4, $f5	# v^^5/5
	add.s	$f6, $f6, $f5	# value = v - v^^3/3 + v^^5/5

	l.s	$f8, PI		# load PI
	div.s	$f6, $f6, $f8	# value / PI
	l.s	$f7, F180	# load 180.0
	mul.s	$f6, $f6, $f7	# 180.0 * value / PI

	cvt.w.s $f6, $f6	# convert "delta" back to integer
	mfc1	$t0, $f6
	add	$v0, $v0, $t0	# angle += delta

	jr 	$ra

# ------------------------
# computes sqrt(x^2 + y^2)
#
# $a0 - x
# $a1 - y
# returns the distance
# ------------------------
euclidean_dist:
	mul	$a0, $a0, $a0	# x^2
	mul	$a1, $a1, $a1	# y^2
	add	$v0, $a0, $a1	# x^2 + y^2
	mtc1	$v0, $f0
	cvt.s.w	$f0, $f0	# float(x^2 + y^2)
	sqrt.s	$f0, $f0	# sqrt(x^2 + y^2)
	cvt.w.s	$f0, $f0	# int(sqrt(...))
	mfc1	$v0, $f0
	jr	$ra

# ----------------------------------------------
# orients the bot towards the desired tile, and
# sets it in motion. a timer interrupt is set to
# fire when the bot reaches its position
#
# $a0 - the x position 
# $a1 - they y position
# $a2 - the velocity
# ----------------------------------------------
move_to:
	sub 	$sp, $sp, 16
	sw 		$ra, 0($sp)
	sw      $s0, 4($sp)
	sw      $s1, 8($sp)
	sw      $s2, 12($sp)

	# compute the world coords
	mul		$s0, $a0, 30
	add 	$s0, $s0, 15

	mul		$s1, $a1, 30
	add 	$s1, $s1, 15

	# compute the difference in the world coords
	lw      $t0, BOT_X
	sub 	$s0, $s0, $t0

	lw 		$t1, BOT_Y
	sub 	$s1, $s1, $t1

	# save velocity for later
	move 	$s2, $a2

	# set the angle to point towards the tile
	move    $a0, $s0
	move    $a1, $s1
	jal		sb_arctan

	sw      $v0, ANGLE

	# set the angle control to absolute
	li		$t1, 1
	sw		$t1, ANGLE_CONTROL

	# set up the interrupt
	la 		$t0, move_state # TODO store the data right...
	sw      $t1, 0($t0)
	sw      $s0, 4($t0)
	sw		$s1, 8($t0)

	move 	$a0, $s0
	move 	$a1, $s1
	jal 	euclidean_dist

	divu 	$v0, $s2                                  # divide the distance by the velocity
	mflo 	$t0                                       # quotient
	mfhi	$t1
	mul 	$t0, $t0, 10000
	mul		$t1, $t1, 1000
	add     $t0, $t0, $t1

	lw		$t1, TIMER                                # read current time
	add 	$t1, $t1, $t0                             # add proper offset to current time
	sw		$t1, TIMER                                # request timer interrupt

	# set speed
	sw 		$s2, VELOCITY

	lw 		$ra, 0($sp)
	lw      $s0, 4($sp)
	lw      $s1, 8($sp)
	lw      $s2, 12($sp)
	add 	$sp, $sp, 16

	jr 		$ra

.kdata
	chunkIH:	.space 8	# space for two registers
	non_intrpt_str:	.asciiz "Non-interrupt exception\n"
	unhandled_str:	.asciiz "Unhandled interrupt type\n"
	timer_str: .asciiz "Handling timer interrupt\n"


	.ktext 0x80000180
	interrupt_handler:
	.set noat
		move	$k1, $at		                      # save $at                               
	.set at
		la	$k0, chunkIH                              # free registers
		sw	$a0, 0($k0)               
		sw	$a1, 4($k0) 

		mfc0	$k0, $13                              # get cause register                    
		srl	$a0, $k0, 2                
		and	$a0, $a0, 0xf		                      # exccode field                        
		bne	$a0, 0, non_intrpt         

	interrupt_dispatch:                           
		mfc0	$k0, $13		# Get Cause register, again                 
		beq	$k0, 0, done		# handled all outstanding interrupts      

		and	$a0, $k0, TIMER_MASK	# is there a timer interrupt?
		bne	$a0, 0, timer_interrupt

		# add dispatch for other interrupt types here.

		li	$v0, PRINT_STRING	# Unhandled interrupt types
		la	$a0, unhandled_str
		syscall 
		j	done

	timer_interrupt:
		sw	$a1, TIMER_ACK		# acknowledge interrupt

		sw 	$0, VELOCITY

	timer_interrupt_done:
		j	interrupt_dispatch	# see if other interrupts are waiting

	non_intrpt:				# was some non-interrupt
		li	$v0, PRINT_STRING
		la	$a0, non_intrpt_str
		syscall				# print out an error message
		# fall through to done

	done:
		la	$k0, chunkIH
		lw	$a0, 0($k0)		# Restore saved registers
		lw	$a1, 4($k0)
	.set noat
		move	$at, $k1		# Restore $at
	.set at 
		eret


