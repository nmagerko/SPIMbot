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

.text

main:
	
	li $t0, REQUEST_PUZZLE_INT_MASK
	ori $t0, $t0, 1
	mtc0 $t0, $12		#enable interrupts

	jal initialize_puzzle_pointers

	li $t0 1
	sw $t0 VELOCITY
	

loop:

	jal can_request_puzzle

	beq $v0 $0 check_ready
	jal request_fire

check_ready:
	la $t0, current_puzzle_is_ready
	lb $t0, 0($t0)

	# While the puzzle isn't ready
	beq $t0, $0, loop
	jal solve_puzzle
	jal submit_puzzle

	sw $0 BURN_TILE
	j loop


infinite:
	j infinite
	

#####################
# Main program code	#
#####################

request_water:
	sub $sp, $sp, 4
	sw $ra, 0($sp)

	li $t0, 0  # 0 for water, 1 for seeds, 2 for fire starters
	sw $t0, SET_RESOURCE_TYPE

	jal request_puzzle
	
	lw $ra, 0($sp)
	add $sp, $sp, 4

	jr $ra

request_seeds:
	sub $sp, $sp, 4
	sw $ra, 0($sp)

	li $t0, 1 # 0 for water, 1 for seeds, 2 for fire starters
	sw $t0, SET_RESOURCE_TYPE

	jal request_puzzle
	
	lw $ra, 0($sp)
	add $sp, $sp, 4

	jr $ra

request_fire:
	sub $sp, $sp, 4
	sw $ra, 0($sp)

	li $t0, 2  # 0 for water, 1 for seeds, 2 for fire starters
	sw $t0, SET_RESOURCE_TYPE

	jal request_puzzle
	
	lw $ra, 0($sp)
	add $sp, $sp, 4

	jr $ra

request_puzzle:

	la $t0, num_puzzles
	lb $t1, 0($t0)

	beq $t1, 0, request_puzzle_send_current
	# If there are not zero (one) outstanding puzzles, fill the next puzzle
		la $t2, next_puzzle_pointer
		lw $t2, 0($t2)
		sw $t2, REQUEST_PUZZLE
		j request_puzzle_finish

	# If there are zero outstanding puzzles, fill the current puzzle
	request_puzzle_send_current:
		la $t2, current_puzzle_pointer
		lw $t2, 0($t2)
		sw $t2, REQUEST_PUZZLE
		#fall through to finish

	request_puzzle_finish:
		# Increment num_puzzles (outstanding puzzles)
		addi $t1, 1
		sb $t1, 0($t0)

		jr $ra

initialize_puzzle_pointers:
	# Set the current puzzle_pointer
	la $t0, current_puzzle_pointer
	la $t1, puzzle2_data
	sw $t1, 0($t0)

	# Set the next puzzle_pointer
	la $t0, next_puzzle_pointer
	la $t1, puzzle1_data
	sw $t1, 0($t0)

	jr $ra

swap_puzzles:
	# Get the current puzzle_pointer
	la $t0	current_puzzle_pointer
	lw $t1, 0($t0)

	# Get the next puzzle_pointer
	la $t2	next_puzzle_pointer
	lw $t3, 0($t2)

	#Swap 'em
	sw $t1, 0($t2)
	sw $t3, 0($t0)

	# Get the current puzzle ready bool
	la $t0	current_puzzle_is_ready
	lb $t1, 0($t0)

	# Get the next puzzle ready bool
	la $t2	next_puzzle_is_ready
	lb $t3, 0($t2)

	#Swap 'em
	sb $t1, 0($t2)
	sb $t3, 0($t0)

	jr $ra

submit_puzzle:
	sub $sp, $sp, 4
	sw $ra, 0($sp)

	la $t0, solution_data
	sw $t0, SUBMIT_SOLUTION

	# Decrement num_puzzles
	la $t0, num_puzzles
	lb $t1, 0($t0)
	addi $t1, -1
	sb $t1, 0($t0)

	# Reset ready bool
	la $t0, current_puzzle_is_ready
	sb $0, 0($t0)

	# Clear the solution
	jal clear_solution

	# Move on to next puzzle
	jal swap_puzzles
	
	lw $ra, 0($sp)
	add $sp, $sp, 4

	jr $ra

clear_solution:
	move $t0, $0
	la $t1, solution_data 

	clear_solution_loop:
		beq $t0, 328, clear_solution_finish
		add $t2, $t1, $t0
		sw $0, 0($t2)
		addi $t0, 4
		j clear_solution_loop

	clear_solution_finish:
		jr $ra

can_solve_puzzle:
	la $t0, current_puzzle_is_ready
	lb $v0, 0($t0)
	jr $ra

can_request_puzzle:
	la $t0, num_puzzles
	lb $t0, 0($t0)
	# Set $v0 equal to bool expression (num_puzzles < 2)
	slt $v0, $t0, 2
	jr $ra

solve_puzzle:
	sub $sp, $sp, 4
	sw $ra, 0($sp)

	#load solution address
	la $a0 solution_data
	#load current puzzle address
	la $t0 current_puzzle_pointer
	lw $a1 0($t0)

	jal recursive_backtracking
	
	lw $ra, 0($sp)
	add $sp, $sp, 4

	jr $ra

##########################
# BEGIN HELPER FUNCTIONS #
##########################

# convert_highest_bit_to_int function
convert_highest_bit_to_int:
    move  $v0, $0             # result = 0

chbti_loop:
    beq   $a0, $0, chbti_end
    add   $v0, $v0, 1         # result ++
    sra   $a0, $a0, 1         # domain >>= 1
    j     chbti_loop

chbti_end:
    jr    $ra

# is_single_value_domain function
is_single_value_domain:
    beq    $a0, $0, isvd_zero     # return 0 if domain == 0
    sub    $t0, $a0, 1	          # (domain - 1)
    and    $t0, $t0, $a0          # (domain & (domain - 1))
    bne    $t0, $0, isvd_zero     # return 0 if (domain & (domain - 1)) != 0
    li     $v0, 1
    jr	   $ra

isvd_zero:
    li	   $v0, 0
    jr	   $ra

# get_domain_for_addition function
get_domain_for_addition:
    sub    $sp, $sp, 20
    sw     $ra, 0($sp)
    sw     $s0, 4($sp)
    sw     $s1, 8($sp)
    sw     $s2, 12($sp)
    sw     $s3, 16($sp)
    move   $s0, $a0                     # s0 = target
    move   $s1, $a1                     # s1 = num_cell
    move   $s2, $a2                     # s2 = domain

    move   $a0, $a2
    jal    convert_highest_bit_to_int
    move   $s3, $v0                     # s3 = upper_bound

    sub    $a0, $0, $s2	                # -domain
    and    $a0, $a0, $s2                # domain & (-domain)
    jal    convert_highest_bit_to_int   # v0 = lower_bound

    sub    $t0, $s1, 1                  # num_cell - 1
    mul    $t0, $t0, $v0                # (num_cell - 1) * lower_bound
    sub    $t0, $s0, $t0                # t0 = high_bits

    bge	   $t0, $0, gdfa_continue
    # Set high bits to zero if it's less than zero
    move   $t0, $0    

    gdfa_continue:
    bge    $t0, $s3, gdfa_skip1

    li     $t1, 1
    sll    $t0, $t1, $t0                # 1 << high_bits
    sub    $t0, $t0, 1                  # (1 << high_bits) - 1
    and    $s2, $s2, $t0                # domain & ((1 << high_bits) - 1)

gdfa_skip1:
    sub    $t0, $s1, 1                  # num_cell - 1
    mul    $t0, $t0, $s3                # (num_cell - 1) * upper_bound
    sub    $t0, $s0, $t0                # t0 = low_bits
    ble    $t0, $0, gdfa_skip2

    sub    $t0, $t0, 1                  # low_bits - 1
    sra    $s2, $s2, $t0                # domain >> (low_bits - 1)
    sll    $s2, $s2, $t0                # domain >> (low_bits - 1) << (low_bits - 1)

gdfa_skip2:
    move   $v0, $s2                     # return domain
    lw     $ra, 0($sp)
    lw     $s0, 4($sp)
    lw     $s1, 8($sp)
    lw     $s2, 12($sp)
    lw     $s3, 16($sp)
    add    $sp, $sp, 20
    jr     $ra


# get_domain_for_subtraction function
get_domain_for_subtraction:
    li     $t0, 1
    li     $t1, 2
    mul    $t1, $t1, $a0            # target * 2
    sll    $t1, $t0, $t1            # 1 << (target * 2)
    or     $t0, $t0, $t1            # t0 = base_mask
    li     $t1, 0                   # t1 = mask

gdfs_loop:
    beq    $a2, $0, gdfs_loop_end
    and    $t2, $a2, 1              # other_domain & 1
    beq    $t2, $0, gdfs_if_end

    sra    $t2, $t0, $a0            # base_mask >> target
    or     $t1, $t1, $t2            # mask |= (base_mask >> target)

gdfs_if_end:
    sll    $t0, $t0, 1              # base_mask <<= 1
    sra    $a2, $a2, 1              # other_domain >>= 1
    j      gdfs_loop

gdfs_loop_end:
    and    $v0, $a1, $t1            # domain & mask
    jr	   $ra

# get_domain_for_cell function
get_domain_for_cell:
    # save registers
    sub $sp, $sp, 36
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    sw $s3, 16($sp)
    sw $s4, 20($sp)
    sw $s5, 24($sp)
    sw $s6, 28($sp)
    sw $s7, 32($sp)

    li $t0, 0 # valid_domain
    lw $t1, 4($a1) # puzzle->grid (t1 free)
    sll $t2, $a0, 3 # position*8 (actual offset) (t2 free)
    add $t3, $t1, $t2 # &puzzle->grid[position]
    lw  $t4, 4($t3) # &puzzle->grid[position].cage
    lw  $t5, 0($t4) # puzzle->grid[posiition].cage->operation

    lw $t2, 4($t4) # puzzle->grid[position].cage->target

    move $s0, $t2   # remain_target = $s0  *!*!
    lw $s1, 8($t4) # remain_cell = $s1 = puzzle->grid[position].cage->num_cell
    lw $s2, 0($t3) # domain_union = $s2 = puzzle->grid[position].domain
    move $s3, $t4 # puzzle->grid[position].cage
    li $s4, 0   # i = 0
    move $s5, $t1 # $s5 = puzzle->grid
    move $s6, $a0 # $s6 = position
    # move $s7, $s2 # $s7 = puzzle->grid[position].domain

    bne $t5, 0, gdfc_check_else_if

    li $t1, 1
    sub $t2, $t2, $t1 # (puzzle->grid[position].cage->target-1)
    sll $v0, $t1, $t2 # valid_domain = 0x1 << (prev line comment)
    j gdfc_end # somewhere!!!!!!!!

gdfc_check_else_if:
    bne $t5, '+', gdfc_check_else

gdfc_else_if_loop:
    lw $t5, 8($s3) # puzzle->grid[position].cage->num_cell
    bge $s4, $t5, gdfc_for_end # branch if i >= puzzle->grid[position].cage->num_cell
    sll $t1, $s4, 2 # i*4
    lw $t6, 12($s3) # puzzle->grid[position].cage->positions
    add $t1, $t6, $t1 # &puzzle->grid[position].cage->positions[i]
    lw $t1, 0($t1) # pos = puzzle->grid[position].cage->positions[i]
    add $s4, $s4, 1 # i++

    sll $t2, $t1, 3 # pos * 8
    add $s7, $s5, $t2 # &puzzle->grid[pos]
    lw  $s7, 0($s7) # puzzle->grid[pos].domain

    beq $t1, $s6 gdfc_else_if_else # branch if pos == position



    move $a0, $s7 # $a0 = puzzle->grid[pos].domain
    jal is_single_value_domain
    bne $v0, 1 gdfc_else_if_else # branch if !is_single_value_domain()
    move $a0, $s7
    jal convert_highest_bit_to_int
    sub $s0, $s0, $v0 # remain_target -= convert_highest_bit_to_int
    addi $s1, $s1, -1 # remain_cell -= 1
    j gdfc_else_if_loop
gdfc_else_if_else:
    or $s2, $s2, $s7 # domain_union |= puzzle->grid[pos].domain
    j gdfc_else_if_loop

gdfc_for_end:
    move $a0, $s0
    move $a1, $s1
    move $a2, $s2
    jal get_domain_for_addition # $v0 = valid_domain = get_domain_for_addition()
    j gdfc_end

gdfc_check_else:
    lw $t3, 12($s3) # puzzle->grid[position].cage->positions
    lw $t0, 0($t3) # puzzle->grid[position].cage->positions[0]
    lw $t1, 4($t3) # puzzle->grid[position].cage->positions[1]
    xor $t0, $t0, $t1
    xor $t0, $t0, $s6 # other_pos = $t0 = $t0 ^ position
    lw $a0, 4($s3) # puzzle->grid[position].cage->target

    sll $t2, $s6, 3 # position * 8
    add $a1, $s5, $t2 # &puzzle->grid[position]
    lw  $a1, 0($a1) # puzzle->grid[position].domain
    # move $a1, $s7

    sll $t1, $t0, 3 # other_pos*8 (actual offset)
    add $t3, $s5, $t1 # &puzzle->grid[other_pos]
    lw $a2, 0($t3)  # puzzle->grid[other_pos].domian

    jal get_domain_for_subtraction # $v0 = valid_domain = get_domain_for_subtraction()
    # j gdfc_end
gdfc_end:
# restore registers

    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    lw $s4, 20($sp)
    lw $s5, 24($sp)
    lw $s6, 28($sp)
    lw $s7, 32($sp)
    add $sp, $sp, 36
    jr $ra


# clone function
clone:

    lw  $t0, 0($a0)
    sw  $t0, 0($a1)

    mul $t0, $t0, $t0
    mul $t0, $t0, 2 # two words in one grid

    lw  $t1, 4($a0) # &puzzle(ori).grid
    lw  $t2, 4($a1) # &puzzle(clone).grid

    li  $t3, 0 # i = 0;
clone_for_loop:
    bge  $t3, $t0, clone_for_loop_end
    sll $t4, $t3, 2 # i * 4
    add $t5, $t1, $t4 # puzzle(ori).grid ith word
    lw   $t6, 0($t5)

    add $t5, $t2, $t4 # puzzle(clone).grid ith word
    sw   $t6, 0($t5)

    addi $t3, $t3, 1 # i++

    j    clone_for_loop
clone_for_loop_end:

    jr  $ra

#forward_checking function
forward_checking:
  sub   $sp, $sp, 24
  sw    $ra, 0($sp)
  sw    $a0, 4($sp)
  sw    $a1, 8($sp)
  sw    $s0, 12($sp)
  sw    $s1, 16($sp)
  sw    $s2, 20($sp)
  lw    $t0, 0($a1)     # size
  li    $t1, 0          # col = 0
fc_for_col:
  bge   $t1, $t0, fc_end_for_col  # col < size
  div   $a0, $t0
  mfhi  $t2             # position % size
  mflo  $t3             # position / size
  beq   $t1, $t2, fc_for_col_continue    # if (col != position % size)
  mul   $t4, $t3, $t0
  add   $t4, $t4, $t1   # position / size * size + col
  mul   $t4, $t4, 8
  lw    $t5, 4($a1) # puzzle->grid
  add   $t4, $t4, $t5   # &puzzle->grid[position / size * size + col].domain
  mul   $t2, $a0, 8   # position * 8
  add   $t2, $t5, $t2 # puzzle->grid[position]
  lw    $t2, 0($t2) # puzzle -> grid[position].domain
  not   $t2, $t2        # ~puzzle->grid[position].domain
  lw    $t3, 0($t4) #
  and   $t3, $t3, $t2
  sw    $t3, 0($t4)
  beq   $t3, $0, fc_return_zero # if (!puzzle->grid[position / size * size + col].domain)
fc_for_col_continue:
  add   $t1, $t1, 1     # col++
  j     fc_for_col
fc_end_for_col:
  li    $t1, 0          # row = 0
fc_for_row:
  bge   $t1, $t0, fc_end_for_row  # row < size
  div   $a0, $t0
  mflo  $t2             # position / size
  mfhi  $t3             # position % size
  beq   $t1, $t2, fc_for_row_continue
  lw    $t2, 4($a1)     # puzzle->grid
  mul   $t4, $t1, $t0
  add   $t4, $t4, $t3
  mul   $t4, $t4, 8
  add   $t4, $t2, $t4   # &puzzle->grid[row * size + position % size]
  lw    $t6, 0($t4)
  mul   $t5, $a0, 8
  add   $t5, $t2, $t5
  lw    $t5, 0($t5)     # puzzle->grid[position].domain
  not   $t5, $t5
  and   $t5, $t6, $t5
  sw    $t5, 0($t4)
  beq   $t5, $0, fc_return_zero
fc_for_row_continue:
  add   $t1, $t1, 1     # row++
  j     fc_for_row
fc_end_for_row:

  li    $s0, 0          # i = 0
fc_for_i:
  lw    $t2, 4($a1)
  mul   $t3, $a0, 8
  add   $t2, $t2, $t3
  lw    $t2, 4($t2)     # &puzzle->grid[position].cage
  lw    $t3, 8($t2)     # puzzle->grid[position].cage->num_cell
  bge   $s0, $t3, fc_return_one
  lw    $t3, 12($t2)    # puzzle->grid[position].cage->positions
  mul   $s1, $s0, 4
  add   $t3, $t3, $s1
  lw    $t3, 0($t3)     # pos
  lw    $s1, 4($a1)
  mul   $s2, $t3, 8
  add   $s2, $s1, $s2   # &puzzle->grid[pos].domain
  lw    $s1, 0($s2)
  move  $a0, $t3
  jal get_domain_for_cell
  lw    $a0, 4($sp)
  lw    $a1, 8($sp)
  and   $s1, $s1, $v0
  sw    $s1, 0($s2)     # puzzle->grid[pos].domain &= get_domain_for_cell(pos, puzzle)
  beq   $s1, $0, fc_return_zero
fc_for_i_continue:
  add   $s0, $s0, 1     # i++
  j     fc_for_i
fc_return_one:
  li    $v0, 1
  j     fc_return
fc_return_zero:
  li    $v0, 0
fc_return:
  lw    $ra, 0($sp)
  lw    $a0, 4($sp)
  lw    $a1, 8($sp)
  lw    $s0, 12($sp)
  lw    $s1, 16($sp)
  lw    $s2, 20($sp)
  add   $sp, $sp, 24
  jr    $ra

# get_unassigned_position function
get_unassigned_position:
  li    $v0, 0            # unassigned_pos = 0
  lw    $t0, 0($a1)       # puzzle->size
  mul  $t0, $t0, $t0     # puzzle->size * puzzle->size
  add   $t1, $a0, 4       # &solution->assignment[0]
get_unassigned_position_for_begin:
  bge   $v0, $t0, get_unassigned_position_return  # if (unassigned_pos < puzzle->size * puzzle->size)
  mul  $t2, $v0, 4
  add   $t2, $t1, $t2     # &solution->assignment[unassigned_pos]
  lw    $t2, 0($t2)       # solution->assignment[unassigned_pos]
  beq   $t2, 0, get_unassigned_position_return  # if (solution->assignment[unassigned_pos] == 0)
  add   $v0, $v0, 1       # unassigned_pos++
  j   get_unassigned_position_for_begin
get_unassigned_position_return:
  jr    $ra

# recursive_backtracking function
recursive_backtracking:
sub   $sp, $sp, 680
sw    $ra, 0($sp)
sw    $a0, 4($sp)     # solution
sw    $a1, 8($sp)     # puzzle
sw    $s0, 12($sp)    # position
sw    $s1, 16($sp)    # val
sw    $s2, 20($sp)    # 0x1 << (val - 1)
                      # sizeof(Puzzle) = 8
                      # sizeof(Cell [81]) = 648

jal   is_complete
bne   $v0, $0, recursive_backtracking_return_one
lw    $a0, 4($sp)     # solution
lw    $a1, 8($sp)     # puzzle
jal   get_unassigned_position
move  $s0, $v0        # position
li    $s1, 1          # val = 1
recursive_backtracking_for_loop:
lw    $a0, 4($sp)     # solution
lw    $a1, 8($sp)     # puzzle
lw    $t0, 0($a1)     # puzzle->size
add   $t1, $t0, 1     # puzzle->size + 1
bge   $s1, $t1, recursive_backtracking_return_zero  # val < puzzle->size + 1
lw    $t1, 4($a1)     # puzzle->grid
mul   $t4, $s0, 8     # sizeof(Cell) = 8
add   $t1, $t1, $t4   # &puzzle->grid[position]
lw    $t1, 0($t1)     # puzzle->grid[position].domain
sub   $t4, $s1, 1     # val - 1
li    $t5, 1
sll   $s2, $t5, $t4   # 0x1 << (val - 1)
and   $t1, $t1, $s2   # puzzle->grid[position].domain & (0x1 << (val - 1))
beq   $t1, $0, recursive_backtracking_for_loop_continue # if (domain & (0x1 << (val - 1)))
mul   $t0, $s0, 4     # position * 4
add   $t0, $t0, $a0
add   $t0, $t0, 4     # &solution->assignment[position]
sw    $s1, 0($t0)     # solution->assignment[position] = val
lw    $t0, 0($a0)     # solution->size
add   $t0, $t0, 1
sw    $t0, 0($a0)     # solution->size++
add   $t0, $sp, 32    # &grid_copy
sw    $t0, 28($sp)    # puzzle_copy.grid = grid_copy !!!
move  $a0, $a1        # &puzzle
add   $a1, $sp, 24    # &puzzle_copy
jal   clone           # clone(puzzle, &puzzle_copy)
mul   $t0, $s0, 8     # !!! grid size 8
lw    $t1, 28($sp)

add   $t1, $t1, $t0   # &puzzle_copy.grid[position]
sw    $s2, 0($t1)     # puzzle_copy.grid[position].domain = 0x1 << (val - 1);
move  $a0, $s0
add   $a1, $sp, 24
jal   forward_checking  # forward_checking(position, &puzzle_copy)
beq   $v0, $0, recursive_backtracking_skip

lw    $a0, 4($sp)     # solution
add   $a1, $sp, 24    # &puzzle_copy
jal   recursive_backtracking
beq   $v0, $0, recursive_backtracking_skip
j     recursive_backtracking_return_one # if (recursive_backtracking(solution, &puzzle_copy))
recursive_backtracking_skip:
lw    $a0, 4($sp)     # solution
mul   $t0, $s0, 4
add   $t1, $a0, 4
add   $t1, $t1, $t0
sw    $0, 0($t1)      # solution->assignment[position] = 0
lw    $t0, 0($a0)
sub   $t0, $t0, 1
sw    $t0, 0($a0)     # solution->size -= 1
recursive_backtracking_for_loop_continue:
add   $s1, $s1, 1     # val++
j     recursive_backtracking_for_loop
recursive_backtracking_return_zero:
li    $v0, 0
j     recursive_backtracking_return
recursive_backtracking_return_one:
li    $v0, 1
recursive_backtracking_return:
lw    $ra, 0($sp)
lw    $a0, 4($sp)
lw    $a1, 8($sp)
lw    $s0, 12($sp)
lw    $s1, 16($sp)
lw    $s2, 20($sp)
add   $sp, $sp, 680
jr    $ra

# is_complete function
is_complete:
  lw    $t0, 0($a0)       # solution->size
  lw    $t1, 0($a1)       # puzzle->size
  mul   $t1, $t1, $t1     # puzzle->size * puzzle->size
  move	$v0, $0
  seq   $v0, $t0, $t1
  j     $ra



#####################
# Interrupt code    #
#####################

.kdata
	chunkIH: .space 24
	non_intrpt_str:	.asciiz "Non-interrupt exception\n"
	unhandled_str:	.asciiz "Unhandled interrupt type\n"

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
	sw $a0, 16($k0)
	sw $a1, 20($k0)

	mfc0 $k0, $13
	srl $a0, $k0, 2
	and $a0, $a0, 0xf
	bne $a0, 0, non_intrpt

interrupt_dispatch:
	mfc0 $k0, $13 										# Get Cause register, again
	beq $k0, $0, done									# handled all outstanding interrupts

	# Interrupt dispatches

	and $a0, $k0, REQUEST_PUZZLE_INT_MASK				#is there a puzzle interrupt?
	bne $a0, $0, puzzle_interrupt

	# Unhandled interrupt types

	li	$v0, PRINT_STRING
	la	$a0, unhandled_str
	syscall
	j	done

puzzle_interrupt:
	sw $a1, REQUEST_PUZZLE_ACK							# acknowledge interrupt
	la $t0, current_puzzle_is_ready
	lb $t1, 0($t0)
	li $t2, 1
	# Branch if the current puzzle is already ready (being solved)
	beq $t1, 1, puzzle_interrupt_next_puzzle_is_ready
		# Set the current puzzle as ready
		sb $t2, 0($t0)
		j puzzle_interrupt_finish

	puzzle_interrupt_next_puzzle_is_ready:
		# Set the next puzzle as ready
		la $t0, next_puzzle_is_ready
		sb $t2, 0($t0)
		#fall through to finish

	puzzle_interrupt_finish:
		j interrupt_dispatch

non_intrpt:
	li	$v0, PRINT_STRING
	la	$a0, non_intrpt_str
	syscall				# print out an error message
	# fall through to done

done:
	la $k0, chunkIH
	# Restore variables
	lw $t0, 0($k0)
	lw $t1, 4($k0)
	lw $t2, 8($k0)
	lw $t3, 12($k0)
	lw $a0, 16($k0)
	lw $a1, 20($k0)

.set noat
	move $at, $k1
.set at
	eret
