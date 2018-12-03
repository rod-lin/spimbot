.data
# syscall constants
PRINT_STRING            = 4
PRINT_CHAR              = 11
PRINT_INT               = 1

# memory-mapped I/O
VELOCITY                = 0xffff0010
ANGLE                   = 0xffff0014
ANGLE_CONTROL           = 0xffff0018

BOT_X                   = 0xffff0020
BOT_Y                   = 0xffff0024

TIMER                   = 0xffff001c

RIGHT_WALL_SENSOR 		= 0xffff0054
PICK_TREASURE           = 0xffff00e0
TREASURE_MAP            = 0xffff0058
MAZE_MAP                = 0xffff0050

REQUEST_PUZZLE          = 0xffff00d0
SUBMIT_SOLUTION         = 0xffff00d4

BONK_INT_MASK           = 0x1000
BONK_ACK                = 0xffff0060

TIMER_INT_MASK          = 0x8000
TIMER_ACK               = 0xffff006c

REQUEST_PUZZLE_INT_MASK = 0x800
REQUEST_PUZZLE_ACK      = 0xffff00d8

GET_KEYS                = 0xffff00e4

V = 10
UNIT = 10 # converting cell to pixel

QUANTUM = 1000

MAZE_ROW = 30
MAZE_COL = 30

INF = 0xffbeef
UNDEF = -1

# s w n e
CELL_LEFT_MASK = 0xff00
CELL_RIGHT_MASK = 0xff000000
CELL_TOP_MASK = 0xff0000
CELL_BOTTOM_MASK = 0xff

# UNDEFINED = 0xffbeef # == INF

NODE_INFO_SIZE = 20

# route direction
ROUTE_EAST = 0
ROUTE_SOUTH = 1
ROUTE_WEST = 2
ROUTE_NORTH = 3

# heuristic params

# actual bound = row/col +- row/col_bound

# min row/col bound
SEARCH_MIN_ROW_BOUND = 5
SEARCH_MIN_COL_BOUND = 5

# sudoku data
.data
# sudoku board
.align 4
board: .space 512

puzzle_ready: .word 0

# treasure data
.data
.align 4
treasure_length: .word 0
treasure_map: .space 400 # (4 + 4) * 50

.data
.align 4
maze_map: .space 3600 # 30 * 30 * 4

.text
main:
    sub $sp, $sp, 4
    sw $ra, 0($sp)

    # enable interrupt
    li $t0, 0
    or $t0, $t0, TIMER_INT_MASK
    or $t0, $t0, BONK_INT_MASK
    or $t0, $t0, REQUEST_PUZZLE_INT_MASK
    or $t0, $t0, 1
    mtc0 $t0, $12
    
    # jal run_until_not_on_cell

    # set timer
    lw $t0, TIMER
    add $t0, $t0, QUANTUM
    sw $t0, TIMER

main_solve:
    jal solve_sync
    j main_solve

# this function will solve and collect keys in sync
solve_sync:
    sub $sp, $sp, 4
    sw $ra, 0($sp)

    la $t0, puzzle_ready
    sw $0, 0($t0)

    la $t1, board
    sw $t1, REQUEST_PUZZLE

ss_loop:
    lw $t1, 0($t0)
    beq $t1, 0, ss_loop

    la $a0, board
    jal sudoku

    # li        $v0, PRINT_INT
    # move        $a0, $t0
    # syscall

    # li        $v0, PRINT_CHAR
    # li        $a0, '\n'
    # syscall

    sw $v0, SUBMIT_SOLUTION

    lw $ra, 0($sp)
    add $sp, $sp, 4
    jr $ra

.kdata
chunkIH:    .space 128
non_intrpt_str:    .asciiz "Non-interrupt exception\n"
unhandled_str:    .asciiz "Unhandled interrupt type\n"

.ktext 0x80000180
interrupt_handler:

.set noat
    move      $k1, $at        # Save $at
.set at
    la        $k0, chunkIH
    sw        $a0, 0($k0)        # Get some free registers
    sw        $v0, 4($k0)        # by storing them to a global variable
    sw        $t0, 8($k0)
    sw        $t1, 12($k0)
    sw        $t2, 16($k0)
    sw        $t3, 20($k0)
    sw        $ra, 24($k0)

    mfhi $t0
    sw $t0, 28($k0)

    mflo $t0
    sw $t0, 32($k0)

    sw      $v1, 36($k0)
    sw      $a1, 40($k0)
    sw      $a2, 44($k0)
    sw      $a3, 48($k0)

    sw      $t4, 52($k0)
    sw      $t5, 56($k0)
    sw      $t6, 60($k0)
    sw      $t7, 64($k0)

    sw      $s0, 68($k0)
    sw      $s1, 72($k0)
    sw      $s2, 76($k0)
    sw      $s3, 80($k0)
    sw      $s4, 84($k0) 
    sw      $s5, 88($k0)
    sw      $s6, 92($k0)
    sw      $s7, 96($k0)

    sw      $sp, 100($k0)
    sw      $fp, 104($k0)

    sw      $t8, 108($k0)
    sw      $t9, 112($k0)

    mfc0      $k0, $13             # Get Cause register
    srl       $a0, $k0, 2
    and       $a0, $a0, 0xf        # ExcCode field
    bne       $a0, 0, non_intrpt

interrupt_dispatch:            # Interrupt:
    mfc0      $k0, $13        # Get Cause register, again
    beq       $k0, 0, done        # handled all outstanding interrupts

    and       $a0, $k0, BONK_INT_MASK    # is there a bonk interrupt?
    bne       $a0, 0, bonk_interrupt

    and       $a0, $k0, TIMER_INT_MASK    # is there a timer interrupt?
    bne       $a0, 0, timer_interrupt

    and 	  $a0, $k0, REQUEST_PUZZLE_INT_MASK
	bne 	  $a0, 0, request_puzzle_interrupt

    li        $v0, PRINT_STRING    # Unhandled interrupt types
    la        $a0, unhandled_str
    syscall
    j    done

bonk_interrupt:
    sw $0, BONK_ACK
    j       interrupt_dispatch    # see if other interrupts are waiting

timer_interrupt:
    sw $0, TIMER_ACK

    la $t0, is_on_cell
    jalr $t0
    beq $v0, 0, timer_not_on_cell

    la $t0, stop
    jalr $t0

    # check treasure

    # init map
    la $t0, map_init
    jalr $t0

    # check if there is treasure on the current position
    la $t0, map_has_treasure
    jalr $t0
    beq $v0, 0, timer_no_treasure

    # stall if no enough key
    lw $t0, GET_KEYS
    blt $t0, $v0, timer_stall_bot

    sw $0, PICK_TREASURE

    # reinit map
    la $t0, map_init
    jalr $t0

timer_no_treasure:

    # on cell
    la $t0, strategy
    jalr $t0

    la $t0, start
    jalr $t0

    la $t0, run_until_not_on_cell
    jalr $t0

    j timer_not_on_cell
timer_stall_bot:

timer_not_on_cell:

    # set another timer
    lw $t0, TIMER
    add $t0, $t0, QUANTUM
    sw $t0, TIMER

    j        interrupt_dispatch    # see if other interrupts are waiting

request_puzzle_interrupt:
    # solve and submit the solution

    sw $t0, REQUEST_PUZZLE_ACK

    li $t0, 1
    la $t1, puzzle_ready
    sw $t0, 0($t1) # set puzzle_ready flag

	j	interrupt_dispatch

non_intrpt:                # was some non-interrupt
    li        $v0, PRINT_STRING
    la        $a0, non_intrpt_str
    syscall                # print out an error message
    # fall through to done

done:
    la      $k0, chunkIH

    lw $t0, 28($k0)
    mthi $t0

    lw $t0, 32($k0)
    mtlo $t0

    lw      $a0, 0($k0)        # Restore saved registers
    lw      $v0, 4($k0)
	lw      $t0, 8($k0)
    lw      $t1, 12($k0)
    lw      $t2, 16($k0)
    lw      $t3, 20($k0)
    lw      $ra, 24($k0)

    lw      $v1, 36($k0)
    lw      $a1, 40($k0)
    lw      $a2, 44($k0)
    lw      $a3, 48($k0)

    lw      $t4, 52($k0)
    lw      $t5, 56($k0)
    lw      $t6, 60($k0)
    lw      $t7, 64($k0)

    lw      $s0, 68($k0)
    lw      $s1, 72($k0)
    lw      $s2, 76($k0)
    lw      $s3, 80($k0)
    lw      $s4, 84($k0) 
    lw      $s5, 88($k0)
    lw      $s6, 92($k0)
    lw      $s7, 96($k0)

    lw      $sp, 100($k0)
    lw      $fp, 104($k0)

    lw      $t8, 108($k0)
    lw      $t9, 112($k0)

.set noat
    move    $at, $k1        # Restore $at
.set at
    eret

.text

# 10 | (x - 5) && 10 | (y - 5)
is_on_cell:
    lw $t0, BOT_X
    lw $t1, BOT_Y

    sub $t0, $t0, 5
    sub $t1, $t1, 5

    li $t2, 10

    div $t0, $t2
    mfhi $t0

    div $t1, $t2
    mfhi $t1

    bne $t0, 0, ioc_negative
    bne $t1, 0, ioc_negative

    li $v0, 1
    jr $ra

ioc_negative:
    li $v0, 0
    jr $ra

turn_east:
    li $t0, 0
    sw $t0, ANGLE
    li $t1, 1
    sw $t1, ANGLE_CONTROL
    jr $ra

turn_south:
    li $t0, 90
    sw $t0, ANGLE
    li $t1, 1
    sw $t1, ANGLE_CONTROL
    jr $ra

turn_west:
    li $t0, 180
    sw $t0, ANGLE
    li $t1, 1
    sw $t1, ANGLE_CONTROL
    jr $ra

turn_north:
    li $t0, 270
    sw $t0, ANGLE
    li $t1, 1
    sw $t1, ANGLE_CONTROL
    jr $ra

turn_right:
    li $t0, 90
    sw $t0, ANGLE
    sw $0, ANGLE_CONTROL
    jr $ra

turn_left:
    li $t0, -90
    sw $t0, ANGLE
    sw $0, ANGLE_CONTROL
    jr $ra

check_bonk:
    sub $sp, $sp, 8
    sw $ra, 0($sp)

    jal turn_left
    lw $v0, RIGHT_WALL_SENSOR
    sw $v0, 4($sp)
    jal turn_right

    lw $ra, 0($sp)
    lw $v0, 4($sp)
    add $sp, $sp, 8
    jr $ra

stop:
    sw $0, VELOCITY
    jr $ra

start:
    li $t0, V
    sw $t0, VELOCITY
    jr $ra

run_until_not_on_cell:
    sub $sp, $sp, 4
    sw $ra, 0($sp)

    jal start
    
runoc_wait:
    jal is_on_cell
    beq $v0, 1, runoc_wait

    lw $ra, 0($sp)
    add $sp, $sp, 4
    jr $ra

# run one cell from the current direction
run_cell:
    sub $sp, $sp, 12
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)

    # read current x, y
    lw $s0, BOT_X
    lw $s1, BOT_Y

    lw $t0, ANGLE

    bne $t0, 0, run_not_east
    add $s0, $s0, UNIT
    j run_x
run_not_east:

    bne $t0, 90, run_not_south
    add $s1, $s1, UNIT
    j run_y
run_not_south:

    bne $t0, 180, run_not_west
    sub $s0, $s0, UNIT
    j run_x
run_not_west:

    bne $t0, 270, run_not_north
    sub $s1, $s1, UNIT
    j run_y
run_not_north:

    bne $t0, 360, run_not_east_2
    add $s0, $s0, UNIT
    j run_x
run_not_east_2:

    move $a0, $t0
    li $v0, 1
    syscall

    # error
    run_error: j run_error

run_x:
run_wait_x:
    jal start
    lw $t0, BOT_X
    bne $t0, $s0, run_wait_x
    j run_align_end

run_y:
run_wait_y:
    jal start
    lw $t0, BOT_Y
    bne $t0, $s1, run_wait_y

run_align_end:
    jal stop

    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    add $sp, $sp, 12
    jr $ra

print_pos:
    sub $sp, $sp, 4
    sw $ra, 0($sp)

    lw $a0, BOT_X
    li $v0, PRINT_INT
    syscall

    li $a0, ' '
    li $v0, PRINT_CHAR
    syscall

    lw $a0, BOT_Y
    li $v0, PRINT_INT
    syscall

    li $a0, ' '
    li $v0, PRINT_CHAR
    syscall

    lw $a0, RIGHT_WALL_SENSOR
    li $v0, PRINT_INT
    syscall

    li $a0, ' '
    li $v0, PRINT_CHAR
    syscall

    jal check_bonk
    move $a0, $v0
    li $v0, PRINT_INT
    syscall

    li $a0, '\n'
    li $v0, PRINT_CHAR
    syscall

    lw $ra, 0($sp)
    add $sp, $sp, 4
    jr $ra

# maze searching trategy
strategy:
    sub $sp, $sp, 4
    sw $ra, 0($sp)

    # j strategy_dfs

    jal as_route_pop_step
    bne $v0, UNDEF, strategy_found_step

#    lw $t0, TIMER
    
#    blt $t0, START_SEARCH_TIME, strategy_dfs

#     blt $t0, 10000000, strategy_explore_mode
#     la $t1, explore_mode
#     sw $0, 0($t1) # turn off explore mode
# strategy_explore_mode:

#     blt $t0, 1000000, strategy_test_range_2
#     bgt $t0, 4000000, strategy_test_range_2
#     j strategy_dfs
# strategy_test_range_2:

#     blt $t0, 5000000, strategy_test_range_3
#     bgt $t0, 8000000, strategy_test_range_3
#     j strategy_dfs
# strategy_test_range_3:

#     blt $t0, 9000000, strategy_test_range_4
#     bgt $t0, 10000000, strategy_test_range_4
#     j strategy_dfs
# strategy_test_range_4:

# strategy_no_dfs:

    jal as_map_init
    jal as_map_search
    # j strategy_dfs

    # try again to see if we found
    # a step or not
    jal as_route_pop_step
    bne $v0, UNDEF, strategy_found_step

    nop

    # try again with no bound
    jal as_map_init_no_bound
    jal as_map_search

    jal as_route_pop_step
    beq $v0, UNDEF, strategy_dfs # fall back to dfs -- BAD!!!
    # only 1 case: a chest is regenerated at the same position

strategy_found_step:
    # follow step

    bne $v0, ROUTE_EAST, strategy_not_east
    la $t0, turn_east
    j strategy_found_dir
strategy_not_east:

    bne $v0, ROUTE_WEST, strategy_not_west
    la $t0, turn_west
    j strategy_found_dir
strategy_not_west:

    bne $v0, ROUTE_NORTH, strategy_not_north
    la $t0, turn_north
    j strategy_found_dir
strategy_not_north:

    bne $v0, ROUTE_SOUTH, strategy_not_south
    la $t0, turn_south
    j strategy_found_dir
strategy_not_south: j strategy_not_south # exception

strategy_found_dir:
    jalr $t0

    lw $ra, 0($sp)
    add $sp, $sp, 4
    jr $ra
    # return

strategy_dfs: # j strategy_dfs

    jal turn_right

strategy_search:
    jal check_bonk
    beq $v0, $0, strategy_search_found

    # turn anticlockwise
    jal turn_left

    j strategy_search
strategy_search_found:

    lw $ra, 0($sp)
    add $sp, $sp, 4

    jr $ra

# map utilities

# for funtions with map_ prefix
# call map_init before them
map_init:
    sub $sp, $sp, 4
    sw $ra, 0($sp)

    la $t0, maze_map
    sw $t0, MAZE_MAP

    la $t0, treasure_length
    sw $t0, TREASURE_MAP

    lw $ra, 0($sp)
    add $sp, $sp, 4
    jr $ra

# a0 position
# return 0 if the cell is not reachable
map_get_cell:
    srl $t0, $a0, 16     # row
    and $t1, $a0, 0xffff # column

    mul $t0, $t0, MAZE_COL
    add $t0, $t0, $t1
    mul $t0, $t0, 4
    la $t1, maze_map
    add $t0, $t1, $t0

    lw $v0, 0($t0)

    jr $ra

map_has_treasure_at:
    sub $sp, $sp, 4
    sw $ra, 0($sp)

    move $v0, $a0
    j map_has_treasure_at_sub

# has treasure in the current position
# return the min key required
map_has_treasure:
    sub $sp, $sp, 4
    sw $ra, 0($sp)

    jal get_pos

map_has_treasure_at_sub:

    la $t1, treasure_length
    lw $t1, 0($t1)
    mul $t1, $t1, 8

    la $t0, treasure_map
    add $t1, $t1, $t0 # end = treasure_map + length * 8

ht_loop:
    bge $t0, $t1, ht_loop_end

    lw $t2, 0($t0)

    # same position
    bne $v0, $t2, ht_if_end

    lw $v0, 4($t0) # points

    bne $v0, 5, ht_not_chest

    li $v0, 3 # need 3 keys
    j ht_ret
ht_not_chest:

    li $v0, 1
    j ht_ret

ht_if_end:
    add $t0, $t0, 8
    j ht_loop
ht_loop_end:

    li $v0, 0
ht_ret:

    lw $ra, 0($sp)
    add $sp, $sp, 4
    jr $ra

# get current position as a single word
# row << 16 | column
get_pos:
    lw $t0, BOT_Y
    lw $t1, BOT_X

    div $t0, $t0, UNIT
    div $t1, $t1, UNIT

    sll $t0, $t0, 16
    or $t0, $t0, $t1

    move $v0, $t0
    
    jr $ra

# a star

.data

.globl queue_size
.globl queue
.globl node_info
.globl route_size
.globl route_cur
.globl route
.globl target_row
.globl target_col

.globl explore_mode

.globl max_row
.globl max_col

.globl row_lbound
.globl row_ubound

.globl col_lbound
.globl col_ubound

.globl target_row
.globl target_col

.globl bounded_search

queue_size: .word 0
queue: .space 3600 # int[900]
node_info: .space 18000
# (struct { int dist; int from; int treasure; int heuris; int closed })[900]

route_size: .word 0
route_cur: .word 0 # current step, stop when cur == size
route: .space 3600

explore_mode: .word 1 # whether to treat the first found edge as target

max_row: .word 0 # max row reached
max_col: .word 0 # max col reached

row_lbound: .word 0
row_ubound: .word 30 # lbound <= row <= ubound

col_lbound: .word 0
col_ubound: .word 30 # lbound <= col <= ubound

target_row: .word 30
target_col: .word 30

bounded_search: .word 1 # if enable bounded search

# search_row_bound: .word 5
# search_col_bound: .word 5

# node_info:
#     .word 0 0
#     .word 1 0
#     .word 2 0
#     .word 3 0

.text

as_route_exist:
    la $v0, route_size
    lw $v0, 0($v0)
    sgt $v0, $v0, $0
    jr $ra

# return the next step
# return UNDEF if no more step is available
as_route_pop_step:
    la $a0, route_size
    la $a1, route

    lw $t0, 0($a0) # size
    lw $t1, 4($a0) # cur

    beq $t0, $t1, arps_no_more_step

    sub $t0, $t0, $t1
    sub $t0, $t0, 1 # actual step index = size - cur - 1
    add $t1, $t1, 1
    sw $t1, 4($a0) # cur++

    mul $t0, $t0, 4
    add $t0, $t0, $a1
    lw $v0, 0($t0) # read direction

    jr $ra

arps_no_more_step:
    li $v0, UNDEF
    jr $ra

as_route_init:
    la $t0, route_size
    sw $0, 0($t0)

    la $t0, route_cur
    sw $0, 0($t0)

    jr $ra

# $a0 from
# $a1 to
# get the direction from 'from' to 'to'
as_route_dir:
    sub $t0, $a0, $a1
    bne $t0, 1, ard_not_left

    # left
    li $v0, ROUTE_WEST
    jr $ra

ard_not_left:
    
    bne $t0, 30, ard_not_top

    # top
    li $v0, ROUTE_NORTH
    jr $ra

ard_not_top:

    sub $t0, $a1, $a0
    bne $t0, 1, ard_not_right

    # right
    li $v0, ROUTE_EAST
    jr $ra

ard_not_right:

    bne $t0, 30, ard_not_bottom

    # bottom

    li $v0, ROUTE_SOUTH
    jr $ra

ard_not_bottom: j ard_not_bottom # exception

# $a0 direction
as_route_push:
    la $t0, route_size
    lw $t1, 0($t0)
    add $t2, $t1, 1
    sw $t2, 0($t0) # size++

    la $t0, route
    mul $t1, $t1, 4
    add $t1, $t1, $t0
    sw $a0, 0($t1)

    jr $ra

# $a0 node index of target
as_route_trace:
    sub $sp, $sp, 8
    sw $ra, 0($sp)

    # while (1)
    #     route_push
    #     read prev
    #     if prev != cur
    #         cur = prev
    #     else
    #         break

art_loop_1:
    la $t0, node_info
    mul $t1, $a0, NODE_INFO_SIZE
    add $t1, $t1, $t0
    lw $t1, 4($t1) # prev

    beq $t1, $a0, art_loop_end_1
    # not the end

    ### debug
    # move $t2, $a0
    # li $v0, PRINT_INT
    # syscall

    # li $v0, PRINT_CHAR
    # li $a0, ' '
    # syscall
    # move $a0, $t2
    ### debug

    sw $t1, 4($sp)
    move $a1, $a0
    move $a0, $t1
    
    jal as_route_dir

    move $a0, $v0
    jal as_route_push

    # restore cur = prev
    lw $a0, 4($sp)

    j art_loop_1
art_loop_end_1:

    lw $ra, 0($sp)
    add $sp, $sp, 8
    jr $ra

# $a0 node index
# distance to 15, 15
as_heuristic:
    li $t0, 30
    div $a0, $t0
    mflo $t0 # row
    mfhi $t1 # col

    la $t2, target_row
    lw $t2, 0($t2)
    sub $t0, $t0, $t2

    la $t2, target_col
    lw $t2, 0($t2)
    sub $t1, $t1, $t2

    mul $t0, $t0, $t0
    mul $t1, $t1, $t1

    add $v0, $t0, $t1
    
    # li $v0, 0

    jr $ra

as_queue_init:
    la $t0, queue_size
    sw $0, 0($t0)
    jr $ra

as_queue_size:
    la $v0, queue_size
    lw $v0, 0($v0)
    jr $ra

as_queue_dec_value:
    # $a0 node index to find
    # dist of $a0 node must have been decreased
    
    la $t0, queue_size
    lw $t1, 0($t0)

    la $t2, queue

    li $t0, 0

aqdec_loop_1:
    bge $t0, $t1, aqdec_loop_end_1

    mul $t3, $t0, 4
    add $t3, $t3, $t2
    lw $t3, 0($t3)

    bne $t3, $a0, aqdec_if_end_1

    # invoke as_queue_dec_value_sub
    # $t0 is ready as it is
    # move $a0, $a1 # set value
    j as_queue_dec_value_sub

aqdec_if_end_1:

    add $t0, $t0, 1
    j aqdec_loop_1
aqdec_loop_end_1:

    # not found, exception
aqdec_exc_1: j aqdec_exc_1

    # j as_queue_push

# $a0 node index
# zero indexed
# children: 2i + 1, 2i + 2
# parent: (i - 1) / 2
as_queue_push:
    la $t0, queue_size
    lw $t1, 0($t0)

    add $t1, $t1, 1
    sw $t1, 0($t0)
    sub $t0, $t1, 1

as_queue_dec_value_sub:
    # index at $t0
    # value at $a0

    la $t2, queue
    mul $t1, $t0, 4
    add $t1, $t1, $t2

    # queue[queue_size] = $a0
    sw $a0, 0($t1)

    # read node_info[$a0].dist
    la $t2, node_info
    mul $t1, $a0, NODE_INFO_SIZE
    add $t1, $t1, $t2

    # $t7 = dist
    lw $t7, 0($t1)

    ### new
    lw $t6, 12($t1)
    add $t7, $t7, $t6 # add heuristic
    ### new

    # t0 = current position

aqpush_loop_1:
    # swap until heap rule is satisfied
    beq $t0, 0, aqpush_loop_end_1 # already at root

    # get parent index
    sub $t1, $t0, 1
    div $t1, $t1, 2

    la $t3, queue
    mul $t2, $t1, 4
    add $t2, $t2, $t3

    # read parent and parent distance
    lw $t3, 0($t2) # $t3 = parent value
    la $t5, node_info
    mul $t4, $t3, NODE_INFO_SIZE
    add $t4, $t4, $t5
    lw $t6, 0($t4) # dist

    ### new
    lw $t4, 12($t4)
    add $t6, $t6, $t4
    ### new

    bge $t7, $t6, aqpush_loop_end_1
    # we are finished if parent dist is greater or equal to us

    # swap queue[$t1] and queue[$t0]

    sw $a0, 0($t2) # queue[$t1] = $a0

    la $t5, queue
    mul $t4, $t0, 4 # queue[$t0] = parent
    add $t4, $t4, $t5
    sw $t3, 0($t4)

    # set current index($t0)

    move $t0, $t1

    j aqpush_loop_1

aqpush_loop_end_1:

    jr $ra

as_queue_pop:
    la $a0, queue
    la $a2, node_info
    lw $v0, 0($a0) # return the root

    # swap the tail to the top
    la $a1, queue_size
    lw $t0, 0($a1) # size
    sub $t0, $t0, 1
    move $a3, $t0 # make a copy of size to $a3
    sw $t0, 0($a1) # decrease queue_size
    mul $t0, $t0, 4
    add $t0, $t0, $a0
    lw $t0, 0($t0) # read queue[queue_size - 1]
    sw $t0, 0($a0) # queue[0] = queue[queue_size - 1]
    move $t7, $t0

    mul $t7, $t7, NODE_INFO_SIZE
    add $t7, $t7, $a2
    lw $t6, 0($t7) # get dist

    ### new
    lw $t7, 12($t7)
    add $t7, $t7, $t6
    ### new

    li $t0, 0 # $t0 current position

aqpop_loop_1:
    mul $t4, $t0, 4
    add $t4, $t4, $a0

    # load two children
    mul $t1, $t0, 2
    add $t1, $t1, 1 # 2i + 1

    mul $t1, $t1, 4
    add $t1, $t1, $a0

    lw $t2, 0($t1) # left child
    lw $t3, 4($t1) # right child

    # $t5 = left child value
    mul $v1, $t2, NODE_INFO_SIZE
    add $v1, $v1, $a2
    lw $t5, 0($v1)

    ### new
    lw $v1, 12($v1)
    add $t5, $t5, $v1
    ### new

    # $t6 = right child value
    mul $v1, $t3, NODE_INFO_SIZE
    add $v1, $v1, $a2
    lw $t6, 0($v1)

    ### new
    lw $v1, 12($v1)
    add $t6, $t6, $v1
    ### new

    # if $t7 > $t5
    #     if $t7 > $t6
    #         if $t5 < $t6
    #             swap with left child
    #         else
    #             swap with right child
    #     else
    #         swap with left child
    # else if $t7 > $t6
    #     swap with right child
    # else
    #     end

    # check bound
    sub $v1, $t1, $a0
    div $v1, $v1, 4
    bge $v1, $a3, aqpop_loop_end_1

    ble $t7, $t5, aqpop_else_if_1

    # check bound
    add $v1, $v1, 1
    bge $v1, $a3, aqpop_else_2
    ble $t7, $t6, aqpop_else_2

    bge $t5, $t6, aqpop_else_3

    # swap with left child
    lw $v1, 0($t4)
    sw $t2, 0($t4)
    sw $v1, 0($t1)

    # update current position = 2i + 1
    mul $t0, $t0, 2
    add $t0, $t0, 1

    j aqpop_if_end_3
aqpop_else_3:

    # swap with right child
    lw $v1, 0($t4)
    sw $t3, 0($t4)
    sw $v1, 4($t1)

    # update current position = 2i + 2
    mul $t0, $t0, 2
    add $t0, $t0, 2

aqpop_if_end_3:

    j aqpop_if_end_2
aqpop_else_2:

    # swap with left child
    lw $v1, 0($t4)
    sw $t2, 0($t4)
    sw $v1, 0($t1)

    # update current position = 2i + 1
    mul $t0, $t0, 2
    add $t0, $t0, 1

aqpop_if_end_2:

    j aqpop_if_end_1
aqpop_else_if_1:

    # check bound
    add $v1, $v1, 1
    bge $v1, $a3, aqpop_loop_end_1
    ble $t7, $t6, aqpop_loop_end_1

    # swap with right child
    lw $v1, 0($t4)
    sw $t3, 0($t4)
    sw $v1, 4($t1)

    # update current position = 2i + 2
    mul $t0, $t0, 2
    add $t0, $t0, 2

aqpop_if_end_1:

    j aqpop_loop_1

aqpop_loop_end_1:

    jr $ra

# given $a0 node index
# find the closest/best treasure
as_init_target:
    li $t0, 30
    div $a0, $t0
    mflo $t0 # row
    mfhi $t1 # col

    # $t2 = i
    # $t3 = nearest treasure index
    # $t4 = cost = distance ^ 2 / point
    # $t5 = treasure map
    # $t7 = treasure length

    li $t2, 0
    li $t3, 0
    li $t4, INF
    la $t5, treasure_map
    la $t7, treasure_length
    lw $t7, 0($t7)

ait_loop_1:
    bge $t2, $t7, ait_loop_end_1

    mul $t6, $t2, 8
    add $t6, $t6, $t5

    lhu $a0, 2($t6) # row
    lhu $a1, 0($t6) # col

    lw $a2, 4($t6) # points

    beq $a2, 1, ait_higher_cost # skip normal corns

    sub $a0, $a0, $t0
    sub $a1, $a1, $t1
    mul $a0, $a0, $a0
    mul $a1, $a1, $a1

    add $a0, $a0, $a1 # dx^2 + dy^2
    div $a0, $a0, $a2 # / point
    # div $a0, $a0, $a2 # / point

    bge $a0, $t4, ait_higher_cost
    # lower cost
    move $t3, $t2
    move $t4, $a0
ait_higher_cost:

    add $t2, $t2, 1
    j ait_loop_1
ait_loop_end_1:

    # found index $t3
    mul $t6, $t3, 8
    add $t6, $t6, $t5
    lhu $a0, 2($t6) # row
    lhu $a1, 0($t6) # col

    # store target row/col
    la $a2, target_row
    sw $a0, 0($a2)

    la $a2, target_col
    sw $a1, 0($a2)

    jr $ra

# traverse through the treasure
# list and init map
as_init_treasure:
    # $t0 = i
    # $t1 = treasure length
    # $t2 = treasure map
    # $t6 = node_info

    la $t1, treasure_length
    lw $t1, 0($t1)

    la $t2, treasure_map

    la $t6, node_info

    li $t0, 0

aitr_loop_1:
    bge $t0, $t1, aitr_loop_end_1

    mul $t3, $t0, 8
    add $t3, $t3, $t2

    lhu $t4, 2($t3) # row
    lhu $t5, 0($t3) # col
    lw $t7, 4($t3) # points

    mul $t4, $t4, 30
    add $t4, $t4, $t5

    mul $t4, $t4, NODE_INFO_SIZE
    add $t4, $t4, $t6

    bne $t7, 5, aitr_not_chest
    li $t5, 3
    sw $t5, 8($t4) # chest needs 3 keys
    j aitr_update_end
aitr_not_chest:
    li $t5, 1
    sw $t5, 8($t4) # corn needs 1 key
aitr_update_end:

    add $t0, $t0, 1
    j aitr_loop_1
aitr_loop_end_1:

    jr $ra

as_map_init_no_bound:
    sub $sp, $sp, 4
    sw $ra, 0($sp)

    la $t0, bounded_search
    sw $0, 0($t0)

    jal as_map_init

    la $t0, bounded_search
    li $t1, 1
    sw $t1, 0($t0)

    lw $ra, 0($sp)
    add $sp, $sp, 4
    jr $ra

# read from maze_map and initialize node_info
as_map_init:
    # i = $t0
    # j = $t1

    sub $sp, $sp, 48
    sw $ra, 0($sp)

    sw $s0, 40($sp)
    sw $s1, 44($sp)

    jal as_queue_init
    jal as_route_init

    jal get_pos

    # set source.dist = 0
    srl $t1, $v0, 16 # row
    and $t2, $v0, 0xffff # col
    mul $t0, $t1, 30
    add $t7, $t2, $t0 # $t7 is the source node index

    # save reg
    sw $t7, 4($sp)
    sw $t1, 8($sp)
    sw $t2, 12($sp)

    move $a0, $t7
    jal as_init_target

    # turn on explore mode
    la $a0, target_row
    lw $a0, 0($a0)
    la $a1, target_col
    lw $a1, 0($a1)

    mul $a0, $a0, 30
    add $a0, $a0, $a1
    mul $a0, $a0, 4
    la $a2, maze_map
    add $a0, $a0, $a2
    lw $a0, 0($a0)

    la $t0, explore_mode
    li $t1, 0
    bne $a0, 0, ami_no_explore_mode # turn on explore mode if the target is not visible
    li $t1, 1
ami_no_explore_mode:
    sw $t1, 0($t0)

    lw $t7, 4($sp)
    lw $t1, 8($sp)
    lw $t2, 12($sp)

    # init boundary

    la $t3, bounded_search
    lw $t3, 0($t3)
    bne $t3, 0, ami_use_bound

    # set bound to the whole map

    la $t3, row_lbound
    sw $0, 0($t3)
    sw $0, 32($sp)

    la $t3, row_ubound
    li $t4, 29
    sw $t4, 0($t3)
    sw $t4, 24($sp)

    la $t3, col_lbound
    sw $0, 0($t3)
    sw $0, 36($sp)

    la $t3, col_ubound
    li $t4, 29
    sw $t4, 0($t3)
    sw $t4, 28($sp)

    j ami_bound_init_end

    # search_row_bound = max(SEARCH_MIN_ROW_BOUND, abs(row - target_row))
    # search_col_bound = max(SEARCH_MIN_COL_BOUND, abs(col - target_col))

ami_use_bound:

#     la $s0, target_row
#     lw $s0, 0($s0)
#     sub $s0, $s0, $t1
#     bge $s0, 0, ami_delta_row_positive
#     mul $s0, $s0, -1
# ami_delta_row_positive:
#     bgt $s0, SEARCH_MIN_ROW_BOUND, ami_valid_row_bound
#     li $s0, SEARCH_MIN_ROW_BOUND
# ami_valid_row_bound:

#     la $s1, target_col
#     lw $s1, 0($s1)
#     sub $s1, $s1, $t1
#     bge $s1, 0, ami_delta_col_positive
#     mul $s1, $s1, -1
# ami_delta_col_positive:
#     bgt $s1, SEARCH_MIN_COL_BOUND, ami_valid_col_bound
#     li $s1, SEARCH_MIN_COL_BOUND
# ami_valid_col_bound:

    li $s0, SEARCH_MIN_ROW_BOUND
    li $s1, SEARCH_MIN_COL_BOUND

    # la $s0, search_row_bound
    # lw $s0, 0($s0)

    # la $s1, search_col_bound
    # lw $s1, 0($s1)

    # adjust $t1 and $t2 so that the region does not shrink upon
    # reaching edges
    bge $t1, $s1, ami_no_adjust_row_1
    move $t1, $s1
ami_no_adjust_row_1:

    add $t3, $t1, $s1
    blt $t3, 29, ami_no_adjust_row_2
    li $t1, 29
    sub $t1, $t1, $s1
ami_no_adjust_row_2:

    bge $t2, $s1, ami_no_adjust_col_1
    move $t2, $s1
ami_no_adjust_col_1:

    add $t3, $t2, $s1
    blt $t3, 29, ami_no_adjust_col_2
    li $t2, 29
    sub $t2, $t2, $s1
ami_no_adjust_col_2:

    # init row lower bound
    sub $t3, $t1, $s1
    bge $t3, 0, ami_valid_row_lbound
    li $t3, 0
ami_valid_row_lbound:
    la $t4, row_lbound
    sw $t3, 0($t4)
    sw $t3, 32($sp)

    # init row upper bound
    add $t3, $t1, $s1
    ble $t3, 29, ami_valid_row_ubound
    li $t3, 29
ami_valid_row_ubound:
    la $t4, row_ubound
    sw $t3, 0($t4)
    sw $t3, 24($sp)

    # init col lower bound
    sub $t3, $t2, $s1
    bge $t3, 0, ami_valid_col_lbound
    li $t3, 0
ami_valid_col_lbound:
    la $t4, col_lbound
    sw $t3, 0($t4)
    sw $t3, 36($sp)

    # init col upper bound
    add $t3, $t2, $s1
    ble $t3, 29, ami_valid_col_ubound
    li $t3, 29
ami_valid_col_ubound:
    la $t4, col_ubound
    sw $t3, 0($t4)
    sw $t3, 28($sp)

ami_bound_init_end:

    # li $t0, 0
    lw $t0, 32($sp)

ami_loop_1:
    lw $t1, 24($sp)
    bgt $t0, $t1, ami_loop_end_1 # row

    # li $t1, 0
    lw $t1, 36($sp)

ami_loop_2:
    lw $t2, 28($sp)

    bgt $t1, $t2, ami_loop_end_2 # col

    # $t2 is the index
    mul $t2, $t0, 30
    add $t2, $t2, $t1

    la $a0, maze_map
    mul $t3, $t2, 4
    add $t3, $t3, $a0
    lw $t3, 0($t3)

    beq $t3, 0, ami_else_1
    # cell visible

    la $a0, node_info
    mul $t3, $t2, NODE_INFO_SIZE
    add $t3, $t3, $a0

    # set node_info[$t2] = { INF, UNDEF, treasure, heuristic, false }
    
    bne $t7, $t2, ami_if_else_2

    sw $0, 0($t3) # store dist = 0 if it's the source
    sw $t7, 4($t3)
    
    li $t4, 1
    sw $t4, 16($t3) # set closed
    sw $0, 8($t3) # set treasure to 0 first

    j ami_if_end_2
ami_if_else_2:

    li $t4, INF
    sw $t4, 0($t3)

    li $t4, UNDEF
    sw $t4, 4($t3)
    sw $0, 16($t3) # set not closed
    sw $0, 8($t3) # set treasure to 0 first

ami_if_end_2:
    
    # save tmp
    sw $t0, 4($sp)
    sw $t1, 8($sp)
    sw $t7, 12($sp)
    sw $t3, 16($sp)
    sw $t2, 20($sp)

    bne $t7, $t2, ami_no_push_node
    # push if it's the source node
    
    lw $a0, 20($sp)
    jal as_queue_push
ami_no_push_node:

    lw $a0, 20($sp)
    jal as_heuristic
    lw $t3, 16($sp)
    sw $v0, 12($t3) # store heuristic

    # sll $a0, $t0, 16
    # or $a0, $a0, $t1
    # jal map_has_treasure_at

    # lw $t3, 16($sp)
    # sw $v0, 8($t3) # store treasure amount
    # sw $0, 8($t3) # set to 0 first

    # bne $v0, 0, ami_no_treasure
    # has treasure! turn off explore mode
    # la $v0, explore_mode
    # sw $0, 0($v0)
# ami_no_treasure:

    # restore tmp
    lw $t0, 4($sp)
    lw $t1, 8($sp)
    lw $t7, 12($sp)

    j ami_if_end_1
ami_else_1:

    la $a0, node_info
    mul $t3, $t2, NODE_INFO_SIZE
    add $t3, $t3, $a0

    # set node_info[$t2] = { UNDEF, UNDEF, 0, 0 }
    li $t4, UNDEF
    sw $t4, 0($t3)
    sw $t4, 4($t3)
    sw $0, 8($t3)
    sw $0, 12($t3)
    sw $0, 16($t3)

ami_if_end_1:

    add $t1, $t1, 1
    j ami_loop_2
ami_loop_end_2:

    add $t0, $t0, 1
    j ami_loop_1
ami_loop_end_1:

    # init treasure
    jal as_init_treasure

    lw $ra, 0($sp)
    lw $s0, 40($sp)
    lw $s1, 44($sp)
    add $sp, $sp, 48
    jr $ra

as_left_node:
    # $a0 current node index
    li $t0, 30
    div $a0, $t0
    mfhi $t0

    # if divisible by 30 -> no left node
    beq $t0, 0, aln_no_node

    # load map cell
    la $t0, maze_map
    mul $t1, $a0, 4
    add $t1, $t1, $t0
    lw $t1, 0($t1)
    and $t1, $t1, CELL_LEFT_MASK

    # blocked
    beq $t1, 0, aln_no_node

    sub $v0, $a0, 1
    jr $ra

aln_no_node:
    li $v0, UNDEF
    jr $ra

as_right_node:
    # $a0 current node index
    li $t0, 30
    add $t1, $a0, 1
    div $t1, $t0
    mfhi $t0

    # if ($a0 + 1) divisible by 30 -> no right node
    beq $t0, 0, arn_no_node

    # load map cell
    la $t0, maze_map
    mul $t1, $a0, 4
    add $t1, $t1, $t0
    lw $t1, 0($t1)
    and $t1, $t1, CELL_RIGHT_MASK

    # blocked
    beq $t1, 0, arn_no_node

    add $v0, $a0, 1
    jr $ra

arn_no_node:
    li $v0, UNDEF
    jr $ra

as_top_node:
    blt $a0, 30, atn_no_node

    # load map cell
    la $t0, maze_map
    mul $t1, $a0, 4
    add $t1, $t1, $t0
    lw $t1, 0($t1)
    and $t1, $t1, CELL_TOP_MASK

    # blocked
    beq $t1, 0, atn_no_node

    sub $v0, $a0, 30
    jr $ra

atn_no_node:
    li $v0, UNDEF
    jr $ra

as_bottom_node:
    # 29 * 30
    bge $a0, 870, abn_no_node

    # load map cell
    la $t0, maze_map
    mul $t1, $a0, 4
    add $t1, $t1, $t0
    lw $t1, 0($t1)
    and $t1, $t1, CELL_BOTTOM_MASK

    # blocked
    beq $t1, 0, abn_no_node

    add $v0, $a0, 30
    jr $ra

abn_no_node:
    li $v0, UNDEF
    jr $ra

as_map_visit_node:
    # $a0 node index
    # $a1 new distance
    # $a2 from node

    sub $sp, $sp, 16
    sw $ra, 0($sp)

    sw $a0, 4($sp)
    sw $a1, 8($sp)
    sw $a2, 12($sp)

    jal as_in_bound
    beq $v0, 0, amvn_not_in_bound

    lw $a0, 4($sp)
    lw $a1, 8($sp)
    lw $a2, 12($sp)

    la $t0, node_info
    mul $t1, $a0, NODE_INFO_SIZE
    add $t1, $t1, $t0
    lw $t0, 0($t1) # dist
    lw $t3, 16($t1) # closed

    # la $t0, maze_map
    # mul $t1, $a0, 4
    # add $t1, $t1, $t0

    beq $t0, UNDEF, amvn_undefined

    lw $t2, 12($t1) # heuristic
    add $t0, $t0, $t2
    add $a3, $a1, $t2

    # beq $t0, UNDEF, amvn_no_update # not visible
    
    ble $t0, $a3, amvn_no_update
    # update
    sw $a1, 0($t1) # update dist
    sw $a2, 4($t1) # store from node
    
    beq $t3, 0, amvn_no_update
    # already in the closed set
    jal as_queue_dec_value # move up in the queue
    j amvn_no_push
amvn_no_update:
    
    # check if the node is in the closed set
    bne $t3, 0, amvn_no_push
    li $t4, 1
    sw $t4, 16($t1)

    # not closed, push node
    jal as_queue_push
amvn_no_push:

amvn_not_in_bound:
amvn_undefined:

    lw $ra, 0($sp)
    add $sp, $sp, 16
    jr $ra

as_map_is_target:
    sub $sp, $sp, 12
    sw $ra, 0($sp)
    sw $a0, 4($sp)

    # $a0 node index
    la $t0, node_info
    mul $t1, $a0, NODE_INFO_SIZE
    add $t1, $t1, $t0
    lw $t1, 8($t1) # treasure

    beq $t1, 0, amit_no_treasure

    jal as_route_init

    lw $a0, 4($sp)
    jal as_route_trace

    lw $ra, 0($sp)
    add $sp, $sp, 12
    li $v0, 1
    jr $ra

amit_no_treasure:
    # check if there any unexplored region around

    # disabling explore mode
    # j amit_no_bottom

    sw $s0, 8($sp)
    la $s0, maze_map

    jal as_route_exist
    beq $v0, 1, amit_no_update # don't update route if there exists one

    lw $a0, 4($sp)
    jal as_left_node
    beq $v0, UNDEF, amit_no_left

    mul $v0, $v0, 4
    add $v0, $v0, $s0
    lw $v0, 0($v0)

    bne $v0, 0, amit_no_left # found a unexplored node
    li $v0, 1
    j amit_found_unexplored
amit_no_left:

    lw $a0, 4($sp)
    jal as_right_node
    beq $v0, UNDEF, amit_no_right

    mul $v0, $v0, 4
    add $v0, $v0, $s0
    lw $v0, 0($v0)

    bne $v0, 0, amit_no_right # found a unexplored node
    li $v0, 1
    j amit_found_unexplored
amit_no_right:

    lw $a0, 4($sp)
    jal as_top_node
    beq $v0, UNDEF, amit_no_top

    mul $v0, $v0, 4
    add $v0, $v0, $s0
    lw $v0, 0($v0)

    bne $v0, 0, amit_no_top # found a unexplored node
    li $v0, 1
    j amit_found_unexplored
amit_no_top:

    lw $a0, 4($sp)
    jal as_bottom_node
    beq $v0, UNDEF, amit_no_bottom

    mul $v0, $v0, 4
    add $v0, $v0, $s0
    lw $v0, 0($v0)

    bne $v0, 0, amit_no_bottom # found a unexplored node
    li $v0, 1
    j amit_found_unexplored
amit_no_bottom:

    li $v0, 0
    j amit_return

amit_found_unexplored:
    
    lw $a0, 4($sp)
    jal as_route_trace

amit_no_update:

    la $v0, explore_mode
    lw $v0, 0($v0)

amit_return:
    lw $ra, 0($sp)
    lw $s0, 8($sp)
    add $sp, $sp, 12
    jr $ra

TOO_FAR = INF

# $a0 node index
# check if lbound <= row <= ubound && lbound <= col <= ubound
as_in_bound:
    li $t0, 30
    div $a0, $t0
    mflo $t0 # row
    mfhi $t1 # col

    la $a0, row_lbound
    lw $a0, 0($a0)
    blt $t0, $a0, aib_not_in_bound

    la $a0, row_ubound
    lw $a0, 0($a0)
    bgt $t0, $a0, aib_not_in_bound

    la $a0, col_lbound
    lw $a0, 0($a0)
    blt $t1, $a0, aib_not_in_bound

    la $a0, col_ubound
    lw $a0, 0($a0)
    bgt $t1, $a0, aib_not_in_bound

    li $v0, 1
    jr $ra

aib_not_in_bound:
    li $v0, 0
    jr $ra

# a-star
as_map_search:
    # stack

    sub $sp, $sp, 16
    sw $ra, 0($sp)
    
    sw $s0, 4($sp) # use $s0 as the popped node index
    sw $s1, 12($sp) # $s1 used for pointer to node_info

    la $s1, node_info

ams_loop_1:
    jal as_queue_size
    beq $v0, 0, ams_loop_end_1

    jal as_queue_pop # pop next node index to $v0
    move $s0, $v0

    # read dist
    mul $t0, $s0, NODE_INFO_SIZE
    add $t0, $t0, $s1
    lw $t0, 0($t0)

    # bge $t0, INF, ams_unreachable # all other nodes are unreachable
    # bge $t0, TOO_FAR, ams_unreachable

    add $t0, $t0, 1 # new distance
    sw $t0, 8($sp) # store new dist

    # check if it's a target
    move $a0, $s0
    jal as_map_is_target
    bne $v0, 0, ams_found_target

    move $a0, $s0
    jal as_left_node

    beq $v0, UNDEF, ams_no_left
    move $a0, $v0
    lw $a1, 8($sp)
    move $a2, $s0 # current node
    jal as_map_visit_node
ams_no_left:

    move $a0, $s0
    jal as_right_node

    beq $v0, UNDEF, ams_no_right
    move $a0, $v0
    lw $a1, 8($sp)
    move $a2, $s0 # current node
    jal as_map_visit_node
ams_no_right:

    move $a0, $s0
    jal as_top_node

    beq $v0, UNDEF, ams_no_top
    move $a0, $v0
    lw $a1, 8($sp)
    move $a2, $s0 # current node
    jal as_map_visit_node
ams_no_top:

    move $a0, $s0
    jal as_bottom_node

    beq $v0, UNDEF, ams_no_bottom
    move $a0, $v0
    lw $a1, 8($sp)
    move $a2, $s0 # current node
    jal as_map_visit_node
ams_no_bottom:

    j ams_loop_1

ams_found_target: # trace target to generate route
    # sw $a0, 4($sp)
    # jal as_route_trace

ams_unreachable:
ams_loop_end_1:

    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 12($sp)
    add $sp, $sp, 16
    jr $ra

################ solve ################

.text

file_solve_s:

    sudoku:
        sub $sp, $sp, 12
        sw $ra, 0($sp)
        sw $a0, 4($sp)
        
    sudoku_loop:
        lw $a0, 4($sp)
        jal rule1

        beq $t0, 0, sudoku_end

        sw $v0, 8($sp)
        lw $a0, 4($sp)
        jal rule2

        lw $t0, 8($sp)
        or $t0, $t0, $v0

        bne $t0, 0, sudoku_loop
    sudoku_end:

        lw $ra, 0($sp)
        lw $v0, 4($sp)
        add $sp, $sp, 12

        jr $ra

    # 48
    # 60
    # 66
    # 70
    rule1:
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

        li $s4, 0

    # for (int i = 0; i < GRID_SQUARED; ++i) {
    ###########################
        li $s0, 0
    rule1_loop_1:
        bge $s0, 16, rule1_loop_end_1
    ###########################

    # for (int j = 0; j < GRID_SQUARED; ++j) {
    ###########################
        li $s1, 0
    rule1_loop_2:
        bge $s1, 16, rule1_loop_end_2
    ###########################

    # unsigned value = board[i][j];
    ###########################
        mul $t8, $s0, 16
        add $t8, $t8, $s1
        mul $t8, $t8, 2
        add $t8, $t8, $a0

        lhu $s3, 0($t8)
    ###########################

    # if (has_single_bit_set(value)) {
    ###########################
        sw $a0, 4($sp)
        move $a0, $s3
        jal has_single_bit_set

        lw $a0, 4($sp)

        beq $v0, $0, rule1_if_end_1
    ###########################

    ################ opt start

        mul $a1, $s0, 32
        add $a1, $a1, $a0

        mul $a2, $s1, 2
        add $a2, $a2, $a0

    # for (int k = 0; k < GRID_SQUARED; ++k) {
    ###########################
        li $s2, 0
    rule1_loop_3:
        bge $s2, 16, rule1_loop_end_3
    ###########################

    # // eliminate from row
    # if (k != j) {
    #     if (board[i][k] & value) {
    # 	      board[i][k] &= ~value;
    # 	      changed = true;
    #     }
    # }
    ###########################
        beq $s2, $s1, rule1_if_end_2

        # mul $t8, $s0, 16
        # add $t8, $t8, $s2
        # mul $t8, $t8, 2
        # add $t8, $t8, $a0

        lhu $t7, 0($a1)
        and $a3, $t7, $s3

        beq $a3, $0, rule1_if_end_3
        not $t6, $s3
        and $t7, $t7, $t6
        sh $t7, 0($a1)

        li $s4, 1
    rule1_if_end_3:

    rule1_if_end_2:
    ###########################

    # if (k != i) {
    #     if (board[k][j] & value) {
    # 	      board[k][j] &= ~value;
    # 	      changed = true;
    #     }
    # }
    ###########################
        beq $s2, $s0, rule1_if_end_4

        lhu $t7, 0($a2)
        and $a3, $t7, $s3

        beq $a3, $0, rule1_if_end_5
        not $t6, $s3
        and $t7, $t7, $t6
        sh $t7, 0($a2)

        li $s4, 1
    rule1_if_end_5:

    rule1_if_end_4:
    ###########################

        add $a1, $a1, 2
        add $a2, $a2, 32
        add $s2, $s2, 1
        j rule1_loop_3
    rule1_loop_end_3:

    #### opt end

        sw $a0, 4($sp)

    # int ii = get_square_begin(i);
        # move $a0, $s0
        # jal get_square_begin
        # move $s5, $v0
        and $s5, $s0, 0xfffffffc

    # int jj = get_square_begin(j);
        # move $a0, $s1
        # jal get_square_begin
        # move $s6, $v0

        and $s6, $s1, 0xfffffffc

        lw $a0, 4($sp)

    ### opt 2 start

    # for (int k = ii; k < ii + GRIDSIZE; ++k) {
    ###########################
        move $s2, $s5
    rule1_loop_4:
        add $t0, $s5, 4
        bge $s2, $t0, rule1_loop_end_4
    ###########################

        mul $a1, $s2, 16
        add $a1, $a1, $s6
        mul $a1, $a1, 2
        add $a1, $a1, $a0

    # for (int l = jj; l < jj + GRIDSIZE; ++ l) {
    ###########################
        move $s7, $s6
    rule1_loop_5:
        add $t0, $s6, 4
        bge $s7, $t0, rule1_loop_end_5
    ###########################

    # if ((k == i) && (l == j)) {
    #     continue;
    # }
    ###########################
        bne $s2, $s0, rule1_if_end_6
        bne $s7, $s1, rule1_if_end_6
        j rule1_loop_cont_5
    rule1_if_end_6:
    ###########################

    # if (board[k][l] & value) {
    #     board[k][l] &= ~value;
    #     changed = true;
    # }
    ###########################
        # mul $t8, $s2, 16
        # add $t8, $t8, $s7
        # mul $t8, $t8, 2
        # add $t8, $t8, $a0

        lhu $t7, 0($a1)
        and $a2, $t7, $s3

        beq $a2, $0, rule1_if_end_7
        not $t6, $s3
        and $t7, $t7, $t6
        sh $t7, 0($a1)

        li $s4, 1
    rule1_if_end_7:
    ###########################

    rule1_loop_cont_5:
        add $a1, $a1, 2
        add $s7, $s7, 1
        j rule1_loop_5
    rule1_loop_end_5:

        add $s2, $s2, 1
        j rule1_loop_4
    rule1_loop_end_4:

    ### opt 2 end

    rule1_if_end_1:

        add $s1, $s1, 1
        j rule1_loop_2
    rule1_loop_end_2:

        add $s0, $s0, 1
        j rule1_loop_1
    rule1_loop_end_1:

        move $v0, $s4

        lw $s0, 4($sp)
        lw $s1, 8($sp)
        lw $s2, 12($sp)
        lw $s3, 16($sp)
        lw $s4, 20($sp)
        lw $s5, 24($sp)
        lw $s6, 28($sp)
        lw $s7, 32($sp)

        lw $ra, 0($sp)
        add $sp, $sp, 36
        jr	$ra

    GRIDSIZE = 4
    GRID_SQUARED = 16
    ALL_VALUES = 65535

    rule2:
        # $a0 board
        # $s0 changed
        # $s1 i
        # $s2 j
        # $s3 k
        # $s4 jsum
        # $s5 isum

        # reuse
        # $s3 sum
        # $s4 ii
        # $s5 jj
        # $s6 k
        # $s7 l

        sub $sp, $sp, 40
        sw $ra, 0($sp)
        sw $a0, 4($sp)

        sw $s0, 8($sp)
        sw $s1, 12($sp)
        sw $s2, 16($sp)
        sw $s3, 20($sp)
        sw $s4, 24($sp)
        sw $s5, 28($sp)
        sw $s6, 32($sp)
        sw $s7, 36($sp)

    # bool
    # rule2(unsigned short board[GRID_SQUARED][GRID_SQUARED]) {
    #   bool changed = false;
        li $s0, 0

    #   for (int i = 0 ; i < GRID_SQUARED ; ++ i) {

        li $s1, 0
    r2_loop_1:
        bge $s1, GRID_SQUARED, r2_loop_end_1

    #     for (int j = 0 ; j < GRID_SQUARED ; ++ j) {

        li $s2, 0
    r2_loop_2:
        bge $s2, GRID_SQUARED, r2_loop_end_2

    #       unsigned value = board[i][j];
        mul $t0, $s1, GRID_SQUARED
        add $t0, $t0, $s2
        mul $t0, $t0, 2
        lw $a0, 4($sp)
        add $t0, $t0, $a0
        lhu $a0, 0($t0)

    #       if (has_single_bit_set(value)) {
        jal has_single_bit_set
    #         continue;
        bne $v0, 0, r2_loop_continue_2
    #       }

    #       int jsum = 0, isum = 0;
        li $s4, 0
        li $s5, 0

    ### opt 3 start
    
    #       for (int k = 0 ; k < GRID_SQUARED ; ++ k) {

        lw $a0, 4($sp)
        mul $a1, $s1, 32
        add $a1, $a1, $a0

        mul $a2, $s2, 2
        add $a2, $a2, $a0

        li $s3, 0
    r2_loop_3:
        bge $s3, GRID_SQUARED, r2_loop_end_3

    #         if (k != j) {
        beq $s3, $s2, r2_if_end_1

    #           jsum |= board[i][k];        // summarize row
        # mul $t0, $s1, GRID_SQUARED
        # add $t0, $t0, $s3
        # mul $t0, $t0, 2
        # lw $a0, 4($sp)
        # add $t0, $t0, $a0
        lhu $t0, 0($a1)
        or $s4, $s4, $t0

    #         }
    r2_if_end_1:

    #         if (k != i) {
        beq $s3, $s1, r2_if_end_2

    #           isum |= board[k][j];         // summarize column
        # mul $t0, $s3, GRID_SQUARED
        # add $t0, $t0, $s2
        # mul $t0, $t0, 2
        # lw $a0, 4($sp)
        # add $t0, $t0, $a0
        lhu $t0, 0($a2)
        or $s5, $s5, $t0

    #         }
    r2_if_end_2:

    #       }

        add $a1, $a1, 2
        add $a2, $a2, 32
        add $s3, $s3, 1
        j r2_loop_3
    r2_loop_end_3:

    ### opt 3 end

    #       if (ALL_VALUES != jsum) {
        beq $s4, ALL_VALUES, r2_if_else_3

    #         board[i][j] = ALL_VALUES & ~jsum;
        mul $t0, $s1, GRID_SQUARED
        add $t0, $t0, $s2
        mul $t0, $t0, 2
        lw $a0, 4($sp)
        add $t0, $t0, $a0
        not $t1, $s4 # ~jsum
        and $t1, $t1, ALL_VALUES
        sh $t1, 0($t0)

    #         changed = true;
        li $s0, 1
        
    #         continue;
        j r2_loop_continue_2

    #       } else if (ALL_VALUES != isum) {
    r2_if_else_3:
        beq $s5, ALL_VALUES, r2_if_end_3

    #         board[i][j] = ALL_VALUES & ~isum;
        mul $t0, $s1, GRID_SQUARED
        add $t0, $t0, $s2
        mul $t0, $t0, 2
        lw $a0, 4($sp)
        add $t0, $t0, $a0
        not $t1, $s5 # ~isum
        and $t1, $t1, ALL_VALUES
        sh $t1, 0($t0)

    #         changed = true;
        li $s0, 1

    #         continue;
        j r2_loop_continue_2

    #       }
    r2_if_end_3:

    #       // eliminate from square
    #       int ii = get_square_begin(i);
        # move $a0, $s1
        # jal get_square_begin
        # move $s4, $v0

        and $s4, $s1, 0xfffffffc

    #       int jj = get_square_begin(j);
        # move $a0, $s2
        # jal get_square_begin
        # move $s5, $v0

        and $s5, $s2, 0xfffffffc

    #       unsigned sum = 0;
        li $s3, 0

    #       for (int k = ii ; k < ii + GRIDSIZE ; ++ k) {
        li $s6, 0
    r2_loop_4:
        add $t0, $s4, GRIDSIZE
        bge $s6, $t0, r2_loop_end_4

    #         for (int l = jj ; l < jj + GRIDSIZE ; ++ l) {

        li $s7, 0
    r2_loop_5:
        add $t0, $s5, GRIDSIZE
        bge $s7, $t0, r2_loop_end_5

    #           if ((k == i) && (l == j)) {
        bne $s6, $s1, r2_if_end_4
        bne $s7, $s2, r2_if_end_4

    #             continue;
        j r2_loop_continue_5

    #           }
    r2_if_end_4:

    #           sum |= board[k][l];
        mul $t0, $s6, GRID_SQUARED
        add $t0, $t0, $s7
        mul $t0, $t0, 2
        lw $a0, 4($sp)
        add $t0, $t0, $a0
        lhu $t0, 0($t0)
        or $s3, $s3, $t0 # sum |= board[k][l]

    r2_loop_continue_5:
    #         }
        add $s7, $s7, 1
        j r2_loop_5
    r2_loop_end_5:

    #       }
        add $s6, $s6, 1
        j r2_loop_4
    r2_loop_end_4:

    #       if (ALL_VALUES != sum) {
        beq $s3, ALL_VALUES, r2_if_end_5

    #         board[i][j] = ALL_VALUES & ~sum;
        mul $t0, $s1, GRID_SQUARED
        add $t0, $t0, $s2
        mul $t0, $t0, 2
        lw $a0, 4($sp)
        add $t0, $t0, $a0
        not $t1, $s3 # ~sum
        and $t1, $t1, ALL_VALUES
        sh $t1, 0($t0)

    #         changed = true;
        li $s0, 1

    #       }
    r2_if_end_5:

    #     }

    r2_loop_continue_2:
        add $s2, $s2, 1
        j r2_loop_2
    r2_loop_end_2:

    #   }

        add $s1, $s1, 1
        j r2_loop_1
    r2_loop_end_1:

    #   return changed;
        move $v0, $s0

        lw $s0, 8($sp)
        lw $s1, 12($sp)
        lw $s2, 16($sp)
        lw $s3, 20($sp)
        lw $s4, 24($sp)
        lw $s5, 28($sp)
        lw $s6, 32($sp)
        lw $s7, 36($sp)

        lw $ra, 0($sp)
        add $sp, $sp, 40
        jr $ra

    # }

    # get_square_begin:
    #     div	$v0, $a0, 4
    #     mul	$v0, $v0, 4
    #     jr	$ra

    has_single_bit_set:
        beq	$a0, 0, hsbs_ret_zero	# return 0 if value == 0
        sub	$a1, $a0, 1
        and	$a1, $a0, $a1
        bne	$a1, 0, hsbs_ret_zero	# return 0 if (value & (value - 1)) == 0
        li	$v0, 1
        jr	$ra
    hsbs_ret_zero:
        li	$v0, 0
        jr	$ra

    get_lowest_set_bit:
        li	$v0, 0			# i
        li	$t1, 1

    glsb_loop:
        sll	$t2, $t1, $v0		# (1 << i)
        and	$t2, $t2, $a0		# (value & (1 << i))
        bne	$t2, $0, glsb_done
        add	$v0, $v0, 1
        blt	$v0, 16, glsb_loop	# repeat if (i < 16)

        li	$v0, 0			# return 0
    glsb_done:
        jr	$ra

    print_board:
        sub	$sp, $sp, 20
        sw	$ra, 0($sp)		# save $ra and free up 4 $s registers for
        sw	$s0, 4($sp)		# i
        sw	$s1, 8($sp)		# j
        sw	$s2, 12($sp)		# the function argument
        sw	$s3, 16($sp)		# the computed pointer (which is used for 2 calls)
        move	$s2, $a0

        li	$s0, 0			# i
    pb_loop1:
        li	$s1, 0			# j
    pb_loop2:
        mul	$t0, $s0, 16		# i*16
        add	$t0, $t0, $s1		# (i*16)+j
        sll	$t0, $t0, 1		# ((i*16)+j)*2
        add	$s3, $s2, $t0
        lhu	$a0, 0($s3)
        jal	has_single_bit_set		
        beq	$v0, 0, pb_star		# if it has more than one bit set, jump
        lhu	$a0, 0($s3)
        jal	get_lowest_set_bit	# 
        add	$v0, $v0, 1		# $v0 = num
        la	$t0, symbollist
        add	$a0, $v0, $t0		# &symbollist[num]
        lb	$a0, 0($a0)		#  symbollist[num]
        li	$v0, 11
        syscall
        j	pb_cont

    pb_star:		
        li	$v0, 11			# print a "*"
        li	$a0, '*'
        syscall

    pb_cont:	
        add	$s1, $s1, 1		# j++
        blt	$s1, 16, pb_loop2

        li	$v0, 11			# at the end of a line, print a newline char.
        li	$a0, '\n'
        syscall	
        
        add	$s0, $s0, 1		# i++
        blt	$s0, 16, pb_loop1

        lw	$ra, 0($sp)		# restore registers and return
        lw	$s0, 4($sp)
        lw	$s1, 8($sp)
        lw	$s2, 12($sp)
        lw	$s3, 16($sp)
        add	$sp, $sp, 20
        jr	$ra
