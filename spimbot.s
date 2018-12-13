.data
# syscall constants
PRINT_STRING = 4
PRINT_CHAR = 11
PRINT_INT = 1

# memory-mapped I/O
VELOCITY = 0xffff0010
ANGLE = 0xffff0014
ANGLE_CONTROL = 0xffff0018

BOT_X = 0xffff0020
BOT_Y = 0xffff0024

TIMER = 0xffff001c

RIGHT_WALL_SENSOR = 0xffff0054
PICK_TREASURE = 0xffff00e0
TREASURE_MAP = 0xffff0058
MAZE_MAP = 0xffff0050

REQUEST_PUZZLE = 0xffff00d0
SUBMIT_SOLUTION = 0xffff00d4

BONK_INT_MASK = 0x1000
BONK_ACK = 0xffff0060

TIMER_INT_MASK = 0x8000
TIMER_ACK = 0xffff006c

REQUEST_PUZZLE_INT_MASK = 0x800
REQUEST_PUZZLE_ACK = 0xffff00d8

GET_KEYS = 0xffff00e4

BREAK_WALL = 0xffff0000

V = 10
UNIT = 10 # converting cell to pixel

QUANTUM = 800
DQUANTUM = 9500 # a double quantum should be the least time for a bot to run 1 pixel
SQUANTUM = 50000

MAZE_ROW = 30
MAZE_COL = 30

INF = 0xfffbeef
UNDEF = -1

# s w n e
CELL_LEFT_MASK = 0xff00
CELL_RIGHT_MASK = 0xff000000
CELL_TOP_MASK = 0xff0000
CELL_BOTTOM_MASK = 0xff

# UNDEFINED = 0xffbeef # == INF

NODE_INFO_SIZE = 28

# route direction
ROUTE_EAST = 0
ROUTE_SOUTH = 1
ROUTE_WEST = 2
ROUTE_NORTH = 3
ROUTE_DUMB = 4

# heuristic params

# actual bound = row/col +- row/col_bound

# min row/col bound

SEARCH_MIN_ROW_BOUND = 5
SEARCH_MIN_COL_BOUND = 5

FULL_SEARCH_MIN_DIST_DIFF = 36

ONE_KEY_DISTANCE = 15
# if a break-wall scheme is ONE_KEY_DISTANCE shorter than a non-break-wall scheme
# break wall

ENABLE_EXPLORE_MODE = 1

SOUTH_WALL = 0
WEST_WALL = 1
NORTH_WALL = 2
EAST_WALL = 3

CORN_KEYS = 1
CHEST_KEYS = 3

TIMING_STARTUP = 800000 # used to prevent some premature wall breaking

CLOSEST_MIN_RETRY = 10 # retry on edge points at least 10 times before using the closest node again

# sudoku data
.data
# sudoku board
.align 4
board0: .space 512

.align 4
board1: .space 512

puzzle_ready: .word 0

# treasure data
.data
.align 4
treasure_length: .word 0
treasure_map: .space 400 # (4 + 4) * 50

.data
.align 4
maze_map: .space 3600 # 30 * 30 * 4

# full_search_min_dist_diff: .word 16

# FULL_SEARCH_INIT_LIMIT = 0
# full_search_limit: .word 0 # if this is non-zero, decrease this value and don't do full search

break_wall: .word UNDEF

.text
main:
    sub $sp, $sp, 4
    sw $ra, 0($sp)

    # super stupid convention 1
    # $t8 = maze_map
    # $t9 = node_info

    la $t8, maze_map
    la $t9, node_info

    # enable interrupt
    li $t0, 0
    or $t0, $t0, TIMER_INT_MASK
    or $t0, $t0, BONK_INT_MASK
    or $t0, $t0, REQUEST_PUZZLE_INT_MASK
    or $t0, $t0, 1
    mtc0 $t0, $12

    # set timer
    lw $t0, TIMER
    add $t0, $t0, 0
    sw $t0, TIMER

    jal init_sudoku

main_solve:
    jal solve_board_0
    jal solve_board_1
    j main_solve

# init the first board
init_sudoku:
    la $t0, puzzle_ready
    sw $0, 0($t0)

    la $t1, board0
    sw $t1, REQUEST_PUZZLE

is_loop:
    lw $t1, 0($t0)
    beq $t1, 0, is_loop

    jr $ra

solve_board_0:
    sub $sp, $sp, 4
    sw $ra, 0($sp)

    la $t0, puzzle_ready
    sw $0, 0($t0)

    la $t0, board1
    sw $t0, REQUEST_PUZZLE # request board 1

    la $a0, board0
    jal sudoku # solve board 0

    sw $v0, SUBMIT_SOLUTION

    la $t0, puzzle_ready
sb0_loop:
    lw $t1, 0($t0)
    beq $t1, 0, sb0_loop

    lw $ra, 0($sp)
    add $sp, $sp, 4
    jr $ra

solve_board_1:
    sub $sp, $sp, 4
    sw $ra, 0($sp)

    la $t0, puzzle_ready
    sw $0, 0($t0)

    la $t0, board0
    sw $t0, REQUEST_PUZZLE # request board 0

    la $a0, board1
    jal sudoku # solve board 1

    sw $v0, SUBMIT_SOLUTION

    la $t0, puzzle_ready
sb1_loop:
    lw $t1, 0($t0)
    beq $t1, 0, sb1_loop

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
    move $k1, $at        # Save $at
.set at
    la $k0, chunkIH
    sw $a0, 0($k0)        # Get some free registers
    sw $v0, 4($k0)        # by storing them to a global variable
    sw $t0, 8($k0)
    sw $t1, 12($k0)
    sw $t2, 16($k0)
    sw $t3, 20($k0)
    sw $ra, 24($k0)

    mfhi $t0
    sw $t0, 28($k0)

    mflo $t0
    sw $t0, 32($k0)

    sw $v1, 36($k0)
    sw $a1, 40($k0)
    sw $a2, 44($k0)
    sw $a3, 48($k0)

    sw $t4, 52($k0)
    sw $t5, 56($k0)
    sw $t6, 60($k0)
    sw $t7, 64($k0)

    sw $s0, 68($k0)
    sw $s1, 72($k0)
    sw $s2, 76($k0)
    sw $s3, 80($k0)
    sw $s4, 84($k0) 
    sw $s5, 88($k0)
    sw $s6, 92($k0)
    sw $s7, 96($k0)

    sw $sp, 100($k0)
    sw $fp, 104($k0)

    # sw $t8, 108($k0)
    # sw $t9, 112($k0)

    mfc0 $k0, $13             # Get Cause register
    srl $a0, $k0, 2
    and $a0, $a0, 0xf        # ExcCode field
    bne $a0, 0, non_intrpt

interrupt_dispatch:            # Interrupt:
    mfc0 $k0, $13        # Get Cause register, again
    beq $k0, 0, done        # handled all outstanding interrupts

    and $a0, $k0, BONK_INT_MASK    # is there a bonk interrupt?
    bne $a0, 0, bonk_interrupt

    and $a0, $k0, TIMER_INT_MASK    # is there a timer interrupt?
    beq $a0, 0, no_timer_interrupt
    la $t0, timer_interrupt
    jr $t0
no_timer_interrupt:

    and $a0, $k0, REQUEST_PUZZLE_INT_MASK
	bne $a0, 0, request_puzzle_interrupt

    li $v0, PRINT_STRING    # Unhandled interrupt types
    la $a0, unhandled_str
    syscall
    j done

bonk_interrupt:
    sw $0, BONK_ACK

    # emergency plan if the
    # bot bumped into a wall
    # this should rarely happen
    li $t0, V
    sub $t0, $0, $t0
    sw $t0, VELOCITY

    # restore position
bonk_not_on_cell:
    la $t0, is_on_cell
    jalr $t0
    beq $v0, 0, bonk_not_on_cell

    # reset timer
    lw $t0, TIMER
    add $t0, $t0, QUANTUM
    sw $t0, TIMER

    j interrupt_dispatch    # see if other interrupts are waiting

request_puzzle_interrupt:
    # solve and submit the solution

    sw $t0, REQUEST_PUZZLE_ACK

    li $t0, 1
    la $t1, puzzle_ready
    sw $t0, 0($t1) # set puzzle_ready flag

	j	interrupt_dispatch

non_intrpt:                # was some non-interrupt
    li $v0, PRINT_STRING
    la $a0, non_intrpt_str
    syscall # print out an error message
    # fall through to done

done:
    la $k0, chunkIH

    lw $t0, 28($k0)
    mthi $t0

    lw $t0, 32($k0)
    mtlo $t0

    lw $a0, 0($k0)        # Restore saved registers
    lw $v0, 4($k0)
	lw $t0, 8($k0)
    lw $t1, 12($k0)
    lw $t2, 16($k0)
    lw $t3, 20($k0)
    lw $ra, 24($k0)

    lw $v1, 36($k0)
    lw $a1, 40($k0)
    lw $a2, 44($k0)
    lw $a3, 48($k0)

    lw $t4, 52($k0)
    lw $t5, 56($k0)
    lw $t6, 60($k0)
    lw $t7, 64($k0)

    lw $s0, 68($k0)
    lw $s1, 72($k0)
    lw $s2, 76($k0)
    lw $s3, 80($k0)
    lw $s4, 84($k0) 
    lw $s5, 88($k0)
    lw $s6, 92($k0)
    lw $s7, 96($k0)

    lw $sp, 100($k0)
    lw $fp, 104($k0)

    # lw $t8, 108($k0)
    # lw $t9, 112($k0)

.set noat
    move $at, $k1        # Restore $at
.set at
    eret

.text

timer_interrupt:
    sw $0, TIMER_ACK

    lw $t0, BOT_X
    lw $t1, BOT_Y

    sub $t0, $t0, 5
    sub $t1, $t1, 5

    li $t2, 10

    div $t0, $t2
    mfhi $t0
    bne $t0, 0, timer_not_on_cell

    div $t1, $t2
    mfhi $t1
    bne $t1, 0, timer_not_on_cell

    # jal is_on_cell
    # beq $v0, 0, timer_not_on_cell

    sw $0, VELOCITY

    # check treasure

    # init map
    jal map_init

    # check if there is treasure on the current position
    jal map_has_treasure
    beq $v0, 0, timer_no_treasure

    # stall if no enough key
    lw $t0, GET_KEYS
    blt $t0, $v0, timer_stall_bot

    sw $0, PICK_TREASURE

    # reinit map
    jal map_init

timer_no_treasure:

    # on cell
    jal strategy

    bne $v0, 0, timer_stall_bot # strategy stall

    li $t0, V
    sw $t0, VELOCITY

    lw $t0, TIMER
    add $t0, $t0, DQUANTUM # wait for a double quantum to ensure the bot is not on cell anymore
    sw $t0, TIMER

    la $t0, interrupt_dispatch
    jr $t0

    # j timer_not_on_cell
timer_stall_bot:
    # set another timer
    lw $t0, TIMER
    add $t0, $t0, SQUANTUM # wait for a stall quantum to compensate the extra cycles spent before the bot is stopped
    sw $t0, TIMER

    la $t0, interrupt_dispatch
    jr $t0

timer_not_on_cell:

    # set another timer
    lw $t0, TIMER
    add $t0, $t0, QUANTUM # wait for a partial quantum to compensate the extra cycles spent before the bot is stopped
    sw $t0, TIMER

    la $t0, interrupt_dispatch
    jr $t0

# 10 | (x - 5) && 10 | (y - 5)
is_on_cell:
    lw $t0, BOT_X
    lw $t1, BOT_Y

    sub $t0, $t0, 5
    sub $t1, $t1, 5

    li $t2, 10

    div $t0, $t2
    mfhi $t0
    bne $t0, 0, ioc_negative

    div $t1, $t2
    mfhi $t1
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

# maze searching trategy
# return $v0 if needs stall
strategy:
    sub $sp, $sp, 4
    sw $ra, 0($sp)

    # j strategy_dfs

    jal as_route_pop_step
    bne $v0, UNDEF, strategy_found_step

    # sw $0, BREAK_WALL

    # no step popped
    # check break_wall flag
    # if not == -1, write it to BREAK_WALL

    la $t0, break_wall
    lw $t1, 0($t0)
    li $t2, UNDEF
    beq $t1, $t2, strategy_no_break_wall

    lw $t3, GET_KEYS
    bne $t3, 0, strategy_no_stall

    li $v0, 1
    j strategy_return

strategy_no_stall:

    sw $t1, BREAK_WALL
    sw $t2, 0($t0)

    jal map_init
strategy_no_break_wall:

    jal as_map_init
    jal as_map_search
    # j strategy_dfs

    # try again to see if we found
    # a step or not
    jal as_route_pop_step
    bne $v0, UNDEF, strategy_found_step

    # try again with no bound
    jal as_map_init_no_bound
    jal as_map_search

    jal as_route_pop_step
    beq $v0, UNDEF, strategy_dfs # fall back to dfs -- BAD!!!
    # only 1 case: a chest is regenerated at the same position

strategy_found_step:
    # follow step

    bne $v0, ROUTE_EAST, strategy_not_east
    sw $0, ANGLE
    li $t1, 1
    sw $t1, ANGLE_CONTROL
    j strategy_found_dir
strategy_not_east:

    bne $v0, ROUTE_WEST, strategy_not_west
    li $t0, 180
    sw $t0, ANGLE
    li $t1, 1
    sw $t1, ANGLE_CONTROL
    j strategy_found_dir
strategy_not_west:

    bne $v0, ROUTE_NORTH, strategy_not_north
    li $t0, 270
    sw $t0, ANGLE
    li $t1, 1
    sw $t1, ANGLE_CONTROL
    j strategy_found_dir
strategy_not_north:

    bne $v0, ROUTE_SOUTH, strategy_not_south
    li $t0, 90
    sw $t0, ANGLE
    li $t1, 1
    sw $t1, ANGLE_CONTROL
    j strategy_found_dir
strategy_not_south:

    beq $v0, ROUTE_DUMB, strategy_found_dir # do nothing

strategy_not_dumb: j strategy_not_dumb # exception

strategy_found_dir:
    # li $t1, 1
    # sw $t1, ANGLE_CONTROL

    li $v0, 0

strategy_return:
    lw $ra, 0($sp)
    add $sp, $sp, 4
    jr $ra # return

strategy_dfs: j strategy_dfs

    jal turn_right

strategy_search:
    jal check_bonk
    beq $v0, $0, strategy_search_found

    # turn anticlockwise
    jal turn_left

    j strategy_search
strategy_search_found:

    li $v0, 0
    lw $ra, 0($sp)
    add $sp, $sp, 4

    jr $ra

# map utilities

# for funtions with map_ prefix
# call map_init before them
map_init:
    sub $sp, $sp, 4
    sw $ra, 0($sp)

    sw $t8, MAZE_MAP

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
    add $t0, $t8, $t0

    lw $v0, 0($t0)

    jr $ra

# has treasure in the current position
# return the min key required
map_has_treasure:
    sub $sp, $sp, 4
    sw $ra, 0($sp)

    jal get_pos
    
    lw $ra, 0($sp)
    add $sp, $sp, 4

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
    jr $ra
ht_not_chest:
    li $v0, 1
    jr $ra
ht_if_end:

    add $t0, $t0, 8
    j ht_loop
ht_loop_end:

    li $v0, 0
    jr $ra

# get current position as a single word
# row << 16 | column
get_pos:
    lw $t0, BOT_Y
    lw $t1, BOT_X

    li $t2, UNIT

    div $t0, $t2
    mflo $t0

    div $t1, $t2
    mflo $t1

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

.globl dist_to_target # of an edge point

queue_size: .word 0
queue: .space 3600 # int[900]
node_info: .space 25200
# (struct { int dist; int from; int treasure; int heuris; int closed; int is_reverse; int round_mark; })[900]

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

dist_to_target: .word INF

# SEARCH_NO_TARGET = 0 # has to be 0
# SEARCH_FOUND_WALL = 1 # found a node separated with a chest by a wall

found_break_node: .word 0

# enable searching from the chest
reverse_search: .word 0

round_mark: .word 3131 # an identifier to distinguish different rounds

# search_row_bound: .word 5
# search_col_bound: .word 5

# node_info:
#     .word 0 0
#     .word 1 0
#     .word 2 0
#     .word 3 0

# closest node searched
closest_node: .word INF
closest_dist: .word INF
closest_retry: .word 0

full_search: .word 0

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

    # check if the current point is the target
    mul $t1, $a0, NODE_INFO_SIZE
    add $t1, $t1, $t9
    lw $t1, 4($t1) # prev

    beq $t1, $a0, art_current_target
    j art_loop_sub
art_current_target:
    # push a dumb value
    li $a0, ROUTE_DUMB
    jal as_route_push
    j art_loop_end_1

art_loop_1:
    mul $t1, $a0, NODE_INFO_SIZE
    add $t1, $t1, $t9
    lw $t1, 4($t1) # prev

    beq $t1, $a0, art_loop_end_1
    # not the end

art_loop_sub:

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

# $a0 row
# $a1 col
as_heuristic:
    # li $t0, 30
    # div $a0, $t0
    # mflo $t0 # row
    # mfhi $t1 # col

    la $t2, target_row
    lw $t2, 0($t2)
    sub $a0, $a0, $t2

    la $t2, target_col
    lw $t2, 0($t2)
    sub $a1, $a1, $t2

    mul $a0, $a0, $a0
    mul $a1, $a1, $a1

    add $v0, $a0, $a1
    # mul $v0, $v0, $v0
    
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
# aqdec_exc_1: j aqdec_exc_1

    jr $ra

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
    mul $t1, $a0, NODE_INFO_SIZE
    add $t1, $t1, $t9

    # $t7 = dist
    lw $t7, 0($t1)

    ### new
    lw $t6, 12($t1)
    add $t7, $t7, $t6 # add heuristic
    ### new

    # t0 = current position

    la $a1, queue
    la $a2, node_info

aqpush_loop_1:
    # swap until heap rule is satisfied
    beq $t0, 0, aqpush_loop_end_1 # already at root

    # get parent index
    sub $t1, $t0, 1
    div $t1, $t1, 2

    # la $t3, queue
    mul $t2, $t1, 4
    add $t2, $t2, $a1

    # read parent and parent distance
    lw $t3, 0($t2) # $t3 = parent value
    mul $t4, $t3, NODE_INFO_SIZE
    add $t4, $t4, $a2
    lw $t6, 0($t4) # dist

    ### new
    lw $t4, 12($t4)
    add $t6, $t6, $t4
    ### new

    bge $t7, $t6, aqpush_loop_end_1
    # we are finished if parent dist is greater or equal to us

    # swap queue[$t1] and queue[$t0]

    sw $a0, 0($t2) # queue[$t1] = $a0

    mul $t4, $t0, 4 # queue[$t0] = parent
    add $t4, $t4, $a1
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
    add $t4, $t4, $t9

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

    sub $sp, $sp, 72
    sw $ra, 0($sp)

    sw $s0, 40($sp)
    sw $s1, 44($sp)

    sw $s2, 48($sp)
    sw $s3, 52($sp)
    sw $s4, 56($sp)
    sw $s5, 60($sp)
    sw $s6, 64($sp)
    sw $s7, 68($sp)

    jal as_queue_init
    jal as_route_init

    la $t0, found_break_node
    sw $0, 0($t0)

    li $t1, INF
    la $t0, closest_node
    sw $t1, 0($t0)

    la $t0, closest_dist
    sw $t1, 0($t0)

    jal get_pos

    # set source.dist = 0
    srl $t1, $v0, 16 # row
    and $t2, $v0, 0xffff # col
    mul $t0, $t1, 30
    add $t7, $t2, $t0 # $t7 is the source node index

    # init dist_to_target to INF
    la $s0, dist_to_target
    li $s1, INF
    sw $s1, 0($s0)

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

    lw $t1, 8($sp)
    lw $t2, 12($sp)

    mul $a0, $a0, 30
    add $a0, $a0, $a1
    mul $a0, $a0, 4
    add $a0, $a0, $t8
    lw $a0, 0($a0)

    beq $a0, 0, ami_target_invisible
    # target visible
    la $t0, explore_mode
    sw $0, 0($t0)

    la $t0, reverse_search
    li $t1, 1
    sw $t1, 0($t0)

    # use bounded search(with distance check) unless
    # not bounded is explicitly set
    la $t0, bounded_search
    lw $t0, 0($t0)
    beq $t0, 0, ami_no_bound

    # j ami_explore_mode_set_end
    j ami_use_bound_weak # don't use bounded search if target is visible

ami_target_invisible:
    # target invisible
    la $t0, explore_mode
    li $t1, ENABLE_EXPLORE_MODE
    sw $t1, 0($t0)

    la $t0, reverse_search
    sw $0, 0($t0)

ami_explore_mode_set_end:

    # init boundary

    la $t3, bounded_search
    lw $t3, 0($t3)
    bne $t3, 0, ami_use_bound

ami_no_bound:
    # set bound to the whole map

    la $t3, full_search # set full search flag
    li $t4, 1
    sw $t4, 0($t3)

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

ami_use_bound_weak:
    lw $t1, 8($sp)
    lw $t2, 12($sp)

    # lw $t3, TIMER
    # ble $t3, MID_GAME, ami_no_full_search

    la $s0, target_row
    lw $s0, 0($s0)
    sub $s0, $s0, $t1
    mul $s0, $s0, $s0

    la $s1, target_col
    lw $s1, 0($s1)
    sub $s1, $s1, $t2
    mul $s1, $s1, $s1
    
    add $s0, $s0, $s1

    blt $s0, FULL_SEARCH_MIN_DIST_DIFF, ami_no_full_search
    # la $s0, explore_mode
    # sw $0, 0($s0) # disable explore mode if doing a full search
    j ami_no_bound
ami_no_full_search:

ami_use_bound:
    la $t1, full_search # set non-full search flag
    lw $0, 0($t1)

    lw $t1, 8($sp)
    lw $t2, 12($sp)

    li $s0, SEARCH_MIN_ROW_BOUND
    li $s1, SEARCH_MIN_COL_BOUND

    # adjust $t1 and $t2 so that the region does not shrink upon
    # reaching edges
    bge $t1, $s0, ami_no_adjust_row_1
    move $t1, $s0
ami_no_adjust_row_1:

    add $t3, $t1, $s0
    blt $t3, 29, ami_no_adjust_row_2
    li $t1, 29
    sub $t1, $t1, $s0
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
    sub $t3, $t1, $s0
    bge $t3, 0, ami_valid_row_lbound
    li $t3, 0
ami_valid_row_lbound:
    la $t4, row_lbound
    sw $t3, 0($t4)
    sw $t3, 32($sp)

    # init row upper bound
    add $t3, $t1, $s0
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

    # cache address
    # la $s2, node_info

    li $s0, UNDEF # new target node index
    li $s1, INF # new target dist squared

    la $t0, reverse_search
    lw $s3, 0($t0) # $s3 is 0 if the original target is invisible
    
    lw $s4, 24($sp)
    lw $s5, 28($sp)
    
    add $s4, $s4, 1
    add $s5, $s5, 1 # add one to the boundary so that we can use beq instead of bgt

    lw $t7, 4($sp) # restore current node index

    la $t0, round_mark
    lw $t6, 0($t0)
    add $t6, $t6, 1
    sw $t6, 0($t0) # inc round_mark
    # $t6 is the round mark

    # li $t0, 0
    lw $t0, 32($sp)

ami_loop_1:
    beq $t0, $s4, ami_loop_end_1 # row

    # li $t1, 0
    lw $t1, 36($sp)

    mul $s6, $t0, 30
    add $s6, $s6, $t1 # $s6 is the current node index

    mul $s7, $s6, 4
    add $s7, $s7, $t8

    mul $s2, $s6, NODE_INFO_SIZE
    add $s2, $s2, $t9 # $s2 is the pointer to node_info struct

ami_loop_2:
    beq $t1, $s5, ami_loop_end_2 # col
    # sw $t1, 8($sp)

    lw $t3, 0($s7)
    beq $t3, 0, ami_if_end_1 # skip if not visible

    # set node_info[$s6] = { INF, INF, treasure, heuristic, false }
    bne $t7, $s6, ami_if_else_2

    sw $0, 0($s2) # store dist = 0 if it's the source
    sw $t7, 4($s2) # prev = self
    
    li $t4, 1
    sw $0, 8($s2) # set treasure to 0 first
    sw $t4, 16($s2) # set closed = true
    sw $0, 20($s2) # set is_reverse to false
    sw $t6, 24($s2) # set round mark

    j ami_if_end_2
ami_if_else_2:

    li $t4, INF
    sw $t4, 0($s2)

    sw $t4, 4($s2)
    sw $0, 8($s2) # set treasure to 0 first
    sw $0, 16($s2) # set not closed
    sw $0, 20($s2) # set is_reverse to false
    sw $t6, 24($s2) # set round mark

ami_if_end_2:

    # inlined as_heuristic
    la $t2, target_row
    lw $t2, 0($t2)

    la $t3, target_col
    lw $t3, 0($t3)

    sub $a0, $t0, $t2
    sub $a1, $t1, $t3

    mul $a0, $a0, $a0
    mul $a1, $a1, $a1

    add $a0, $a0, $a1

    # try to find the node closest to the original target
    bne $s3, 0, ami_no_change_target

    bge $a0, $s1, ami_set_target_end # if distance is greater, don't set
    move $s0, $s6 # node index
    move $s1, $a0 # dist ^ 2
ami_set_target_end:

ami_no_change_target:

    sw $a0, 12($s2) # store heuristic
    # inlined as_heuristic

ami_if_end_1:

    add $s2, $s2, NODE_INFO_SIZE
    add $s6, $s6, 1
    add $s7, $s7, 4
    add $t1, $t1, 1
    j ami_loop_2
ami_loop_end_2:

    # lw $t0, 4($sp)

    add $t0, $t0, 1
    j ami_loop_1
ami_loop_end_1:

    lw $t2, TIMER
    blt $t2, TIMING_STARTUP, ami_no_update_target # don't do anything at startup
    bne $s3, 0, ami_no_update_target
    # update target

    li $t2, 30
    div $s0, $t2
    mflo $t2 # row
    mfhi $t3 # col

    la $t4, target_row
    sw $t2, 0($t4)

    la $t4, target_col
    sw $t3, 0($t4)

    # enable reverse search
    la $t4, reverse_search
    li $t2, 1
    sw $t2, 0($t4)

    la $t4, explore_mode
    sw $0, 0($t4)

ami_no_update_target:

    # push source node
    # lw $a0, 12($sp)
    move $a0, $t7
    jal as_queue_push

    # init treasure
    jal as_init_treasure

ami_return:

    lw $ra, 0($sp)
    lw $s0, 40($sp)
    lw $s1, 44($sp)
    lw $s2, 48($sp)
    lw $s3, 52($sp)
    lw $s4, 56($sp)
    lw $s5, 60($sp)
    lw $s6, 64($sp)
    lw $s7, 68($sp)

    add $sp, $sp, 72
    jr $ra

as_left_node:
    # $a0 current node index
    # return $v0 = UNDEF if not exist
    # return $v1 = 1 if wall, 0 if not exist
    # if $v1 is set, $t0 is set to the left node
    # SIMILAR for right_node/top_node/bottom_node functions below

    li $t1, 30
    div $a0, $t1
    mfhi $t0

    # if divisible by 30 -> no left node
    beq $t0, 0, aln_no_node

    # load map cell
    mul $t1, $a0, 4
    add $t1, $t1, $t8
    lw $t1, 0($t1)
    and $t1, $t1, CELL_LEFT_MASK

    # blocked
    beq $t1, 0, aln_wall

    sub $v0, $a0, 1
    jr $ra

aln_wall:
    li $v1, 1
    li $v0, UNDEF
    sub $t0, $a0, 1
    jr $ra

aln_no_node:
    li $v1, 0
    li $v0, UNDEF
    jr $ra

as_right_node:
    # $a0 current node index
    add $t1, $a0, 1
    li $t2, 30
    div $t1, $t2
    mfhi $t0

    # if ($a0 + 1) divisible by 30 -> no right node
    beq $t0, 0, arn_no_node

    # load map cell
    mul $t1, $a0, 4
    add $t1, $t1, $t8
    lw $t1, 0($t1)
    and $t1, $t1, CELL_RIGHT_MASK

    # blocked
    beq $t1, 0, arn_wall

    add $v0, $a0, 1
    jr $ra

arn_wall:
    li $v1, 1
    li $v0, UNDEF
    add $t0, $a0, 1
    jr $ra

arn_no_node:
    li $v1, 0
    li $v0, UNDEF
    jr $ra

as_top_node:
    blt $a0, 30, atn_no_node

    # load map cell
    mul $t1, $a0, 4
    add $t1, $t1, $t8
    lw $t1, 0($t1)
    and $t1, $t1, CELL_TOP_MASK

    # blocked
    beq $t1, 0, atn_wall

    sub $v0, $a0, 30
    jr $ra

atn_wall:
    li $v1, 1
    li $v0, UNDEF
    sub $t0, $a0, 30
    jr $ra

atn_no_node:
    li $v1, 0
    li $v0, UNDEF
    jr $ra

as_bottom_node:
    # 29 * 30
    bge $a0, 870, abn_no_node

    # load map cell
    mul $t1, $a0, 4
    add $t1, $t1, $t8
    lw $t1, 0($t1)
    and $t1, $t1, CELL_BOTTOM_MASK

    # blocked
    beq $t1, 0, abn_wall

    add $v0, $a0, 30
    jr $ra

abn_wall:
    li $v1, 1
    li $v0, UNDEF
    add $t0, $a0, 30
    jr $ra

abn_no_node:
    li $v1, 0
    li $v0, UNDEF
    jr $ra

as_map_visit_node:
    # $a0 node index
    # $a1 new distance
    # $a2 from node

    sub $sp, $sp, 16
    sw $ra, 0($sp)

    mul $t1, $a0, 4
    add $t1, $t1, $t8
    lw $t1, 0($t1)

    beq $t1, 0, amvn_non_visible

    # check bounds
    li $t0, 30
    div $a0, $t0
    mflo $t0 # row
    mfhi $t1 # col

    la $t3, row_lbound

    lw $t2, 0($t3)
    blt $t0, $t2, amvn_not_in_bound

    lw $t2, 4($t3)
    bgt $t0, $t2, amvn_not_in_bound

    lw $t2, 8($t3)
    blt $t1, $t2, amvn_not_in_bound

    lw $t2, 12($t3)
    bgt $t1, $t2, amvn_not_in_bound
    # bound checking end

    mul $t1, $a0, NODE_INFO_SIZE
    add $t1, $t1, $t9
    lw $t0, 0($t1) # dist
    lw $t3, 16($t1) # closed

    # beq $t0, UNDEF, amvn_undefined

    lw $t2, 12($t1) # heuristic
    add $t0, $t0, $t2
    add $a3, $a1, $t2
    
    ble $t0, $a3, amvn_no_update
    # update
    sw $a1, 0($t1) # update dist
    sw $a2, 4($t1) # store from node
    
    beq $t3, 0, amvn_no_update
    # nop
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
amvn_non_visible:
amvn_undefined:

    lw $ra, 0($sp)
    add $sp, $sp, 16
    jr $ra

as_map_is_target:
    sub $sp, $sp, 12
    sw $ra, 0($sp)
    sw $a0, 4($sp)

    # $a0 node index
    mul $t1, $a0, NODE_INFO_SIZE
    add $t1, $t1, $t9
    lw $t2, 8($t1) # treasure

    bne $t2, 3, amit_no_treasure

    # if the distance is significantly larger, choose the
    # original path instead
    la $t0, found_break_node
    lw $t0, 0($t0)
    beq $t0, 0, amit_break_node_not_found

    la $t0, route_size
    lw $t0, 0($t0)

    lw $t2, 0($t1) # distance

    sub $t2, $t2, $t0

    # cost of running extra distance is
    # less than the cost of waiting for one key
    blt $t2, ONE_KEY_DISTANCE, amit_change_path
    li $v0, 1 # use the original path
    j amit_use_break_node
amit_change_path:

    # override break wall
    la $t0, break_wall
    li $t1, UNDEF
    sw $t1, 0($t0)

amit_break_node_not_found:

    jal as_route_init

    lw $a0, 4($sp)
    jal as_route_trace

    li $v0, 1

amit_use_break_node:

    lw $ra, 0($sp)
    add $sp, $sp, 12
    jr $ra

amit_no_treasure:

    la $t0, target_row
    lw $t0, 0($t0)
    la $t1, target_col
    lw $t1, 0($t1)

    mul $t2, $t0, 30
    add $t2, $t2, $t1

    bne $t2, $a0, amit_not_target

    jal as_route_init

    lw $a0, 4($sp)
    jal as_route_trace

    lw $ra, 0($sp)
    add $sp, $sp, 12
    li $v0, 1
    jr $ra

amit_not_target:

    # calculate the distance from target to this point
    # and log it if it's closer than the record
    # $t0 target row, $t1 target col

    srl $t2, $a0, 16
    and $t3, $a0, 0xffff

    sub $t2, $t2, $t0
    mul $t2, $t2, $t2
    sub $t3, $t3, $t1
    mul $t3, $t3, $t3
    add $t2, $t2, $t3

    la $t3, closest_dist
    lw $t4, 0($t3)

    bge $t2, $t4, amit_no_closer_node
    # closer node, log it down
    sw $t2, 0($t3)
    la $t2, closest_node
    sw $a0, 0($t2)
amit_no_closer_node:

    la $t0, found_break_node
    lw $t0, 0($t0)
    bne $t0, 0, amit_has_candidate # has a candidate, skip

    # check if there any unexplored region around

    # disabling explore mode
    # j amit_no_bottom

    lw $a0, 4($sp)
    jal as_left_node
    beq $v0, UNDEF, amit_no_left

    mul $v0, $v0, 4
    add $v0, $v0, $t8
    lw $v0, 0($v0)

    bne $v0, 0, amit_left_explored # found a unexplored node
    li $v0, 1
    j amit_found_unexplored
amit_no_left:

    ### detect chest behind a wall
    beq $v1, 0, amit_no_left_chest
    
    mul $t0, $t0, NODE_INFO_SIZE
    add $t0, $t0, $t9
    lw $t0, 8($t0) # treasure

    bne $t0, 3, amit_no_left_chest

    # chest on the left but there is a wall
    la $t0, break_wall
    li $t1, WEST_WALL # left/west wall
    sw $t1, 0($t0)

    jal as_route_init

    lw $a0, 4($sp)
    jal as_route_trace
    li $v0, 0 # keep search to check if there is a better path

    # set candidate
    la $t0, found_break_node
    li $t1, 1
    sw $t1, 0($t0)

    j amit_return

amit_no_left_chest:
    ### detect chest behind a wall
amit_left_explored:

    lw $a0, 4($sp)
    jal as_right_node
    beq $v0, UNDEF, amit_no_right

    mul $v0, $v0, 4
    add $v0, $v0, $t8
    lw $v0, 0($v0)

    bne $v0, 0, amit_right_explored # found a unexplored node
    li $v0, 1
    j amit_found_unexplored
amit_no_right:

    ### detect chest behind a wall
    beq $v1, 0, amit_no_right_chest
    
    mul $t0, $t0, NODE_INFO_SIZE
    add $t0, $t0, $t9
    lw $t0, 8($t0) # treasure

    bne $t0, 3, amit_no_right_chest

    # chest on the right but there is a wall
    la $t0, break_wall
    li $t1, EAST_WALL # right/east wall
    sw $t1, 0($t0)

    jal as_route_init

    lw $a0, 4($sp)
    jal as_route_trace
    li $v0, 0 # keep search to check if there is a better path

    # set candidate
    la $t0, found_break_node
    li $t1, 1
    sw $t1, 0($t0)

    j amit_return

amit_no_right_chest:
    ### detect chest behind a wall
amit_right_explored:

    lw $a0, 4($sp)
    jal as_top_node
    beq $v0, UNDEF, amit_no_top

    mul $v0, $v0, 4
    add $v0, $v0, $t8
    lw $v0, 0($v0)

    bne $v0, 0, amit_top_explored # found a unexplored node
    li $v0, 1
    j amit_found_unexplored
amit_no_top:

    ### detect chest behind a wall
    beq $v1, 0, amit_no_top_chest
    
    mul $t0, $t0, NODE_INFO_SIZE
    add $t0, $t0, $t9
    lw $t0, 8($t0) # treasure

    bne $t0, 3, amit_no_top_chest

    # chest on the top but there is a wall
    la $t0, break_wall
    li $t1, NORTH_WALL # top/north wall
    sw $t1, 0($t0)

    jal as_route_init

    lw $a0, 4($sp)
    jal as_route_trace
    li $v0, 0 # keep search to check if there is a better path

    # set candidate
    la $t0, found_break_node
    li $t1, 1
    sw $t1, 0($t0)

    j amit_return

amit_no_top_chest:
    ### detect chest behind a wall

amit_top_explored:

    lw $a0, 4($sp)
    jal as_bottom_node
    beq $v0, UNDEF, amit_no_bottom

    mul $v0, $v0, 4
    add $v0, $v0, $t8
    lw $v0, 0($v0)

    bne $v0, 0, amit_bottom_explored # found a unexplored node
    li $v0, 1
    j amit_found_unexplored
amit_no_bottom:

    ### detect chest behind a wall
    beq $v1, 0, amit_no_bottom_chest
    
    mul $t0, $t0, NODE_INFO_SIZE
    add $t0, $t0, $t9
    lw $t0, 8($t0) # treasure

    bne $t0, 3, amit_no_bottom_chest

    # chest on the bottom but there is a wall
    la $t0, break_wall
    li $t1, SOUTH_WALL # bottom/south wall
    sw $t1, 0($t0)

    jal as_route_init

    lw $a0, 4($sp)
    jal as_route_trace
    li $v0, 0 # keep search to check if there is a better path

    # set candidate
    la $t0, found_break_node
    li $t1, 1
    sw $t1, 0($t0)

    j amit_return

amit_no_bottom_chest:
    ### detect chest behind a wall

amit_bottom_explored:
amit_has_candidate:

    li $v0, 0
    j amit_return

amit_found_unexplored:

    # jal get_pos
    # srl $t2, $v0, 16 # row
    # and $t3, $v0, 0xffff # col

    lw $a0, 4($sp)
    li $t0, 30
    div $a0, $t0
    mflo $t0 # edge row
    mfhi $t1 # edge col

    # calculate distance squared of me -> edge
    # sub $t2, $t2, $t0
    # sub $t3, $t3, $t1
    # mul $t2, $t2, $t2
    # mul $t3, $t3, $t3
    # add $t2, $t2, $t3

    # calculate distance squared of edge -> target
    la $t4, target_row
    lw $t4, 0($t4)

    la $t5, target_col
    lw $t5, 0($t5)

    sub $t4, $t4, $t0
    mul $t4, $t4, $t4

    sub $t5, $t5, $t1
    mul $t5, $t5, $t5

    add $t0, $t4, $t5

    # add $t0, $t0, $t2 # dist2(me -> edge) + dist2(edge -> target)

    la $t1, dist_to_target
    lw $t3, 0($t1)

    bge $t0, $t3, amit_no_update
    # don't update if this edge point is too further from target

    sw $t0, 0($t1) # update new dist

    jal as_route_init

    lw $a0, 4($sp)
    jal as_route_trace

amit_no_update:

    la $v0, explore_mode
    lw $v0, 0($v0) # return 1 if explore_mode is enabled

amit_return:
    lw $ra, 0($sp)
    # lw $s0, 8($sp)
    add $sp, $sp, 12
    jr $ra

# $a0 node index
# check if lbound <= row <= ubound && lbound <= col <= ubound
as_in_bound:
    li $t0, 30
    div $a0, $t0
    mflo $t0 # row
    mfhi $t1 # col

    la $a0, row_lbound

    lw $t2, 0($a0)
    blt $t0, $t2, aib_not_in_bound

    lw $t2, 4($a0)
    bgt $t0, $t2, aib_not_in_bound

    lw $t2, 8($a0)
    blt $t1, $t2, aib_not_in_bound

    lw $t2, 12($a0)
    bgt $t1, $t2, aib_not_in_bound

    li $v0, 1
    jr $ra

aib_not_in_bound:
    li $v0, 0
    jr $ra

# a-star
as_map_search:
    # stack

    sub $sp, $sp, 20
    sw $ra, 0($sp)
    
    sw $s0, 4($sp) # use $s0 as the popped node index
    sw $s1, 12($sp) # $s1 used for pointer to node_info
    sw $s2, 16($sp)

    la $s1, node_info
    la $s2, queue_size

ams_loop_1:
    lw $v0, 0($s2)
    beq $v0, 0, ams_loop_end_1

    jal as_queue_pop # pop next node index to $v0
    move $s0, $v0

    # read dist
    mul $t0, $s0, NODE_INFO_SIZE
    add $t0, $t0, $s1
    lw $t0, 0($t0)

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
ams_loop_end_1:

    # if still no candidate & reverse_search is true
    # push the target point and search from target
    # to find border point
    la $t0, found_break_node
    lw $t0, 0($t0)
    bne $t0, 0, ams_no_reverse_search

    la $t1, reverse_search
    lw $t1, 0($t1)
    beq $t1, 0, ams_no_reverse_search

    # push target
    la $t0, target_row
    la $t1, target_col

    lw $t0, 0($t0)
    lw $t1, 0($t1)
    
    mul $t0, $t0, 30
    add $t0, $t0, $t1 # node index

    mul $t1, $t0, NODE_INFO_SIZE
    add $t1, $t1, $t9
    lw $0, 0($t1) # set dist to 0
    li $t2, 1
    lw $t2, 20($t1) # set is_reverse to true

    # jal as_queue_init
    move $a0, $t0
    jal as_queue_push

    # target defined as a node adjacent to a non-reverse, visited node, i.e.
    # is_reverse == 0 && prev != UNDEF

ams_loop_2:
    lw $v0, 0($s2)
    beq $v0, 0, ams_loop_end_2

    jal as_queue_pop # pop next node index to $v0
    move $s0, $v0

    move $a0, $s0
    jal as_map_is_reverse_target
    # return the actual reachable target
    # and set route/break_wall as required
    # otherwise return UNDEF

    bne $v0, UNDEF, ams_found_reverse_target

    mul $t0, $s0, NODE_INFO_SIZE
    add $t0, $t0, $s1
    lw $t0, 0($t0)

    add $t0, $t0, 1 # new distance
    sw $t0, 8($sp) # store new dist

    # visit four nodes surrounding it
    move $a0, $s0
    jal as_left_node

    beq $v0, UNDEF, ams_no_left_r

    ### set is_reverse = true
    mul $a0, $v0, NODE_INFO_SIZE
    add $a0, $a0, $t9
    li $t0, 1
    sw $t0, 20($a0)
    ### set is_reverse = true

    move $a0, $v0
    lw $a1, 8($sp)
    move $a2, $s0 # current node
    jal as_map_visit_node
ams_no_left_r:

    move $a0, $s0
    jal as_right_node

    beq $v0, UNDEF, ams_no_right_r

     ### set is_reverse = true
    mul $a0, $v0, NODE_INFO_SIZE
    add $a0, $a0, $t9
    li $t0, 1
    sw $t0, 20($a0)
    ### set is_reverse = true

    move $a0, $v0
    lw $a1, 8($sp)
    move $a2, $s0 # current node
    jal as_map_visit_node
ams_no_right_r:

    move $a0, $s0
    jal as_top_node

    beq $v0, UNDEF, ams_no_top_r

     ### set is_reverse = true
    mul $a0, $v0, NODE_INFO_SIZE
    add $a0, $a0, $t9
    li $t0, 1
    sw $t0, 20($a0)
    ### set is_reverse = true

    move $a0, $v0
    lw $a1, 8($sp)
    move $a2, $s0 # current node
    jal as_map_visit_node
ams_no_top_r:

    move $a0, $s0
    jal as_bottom_node

    beq $v0, UNDEF, ams_no_bottom_r

     ### set is_reverse = true
    mul $a0, $v0, NODE_INFO_SIZE
    add $a0, $a0, $t9
    li $t0, 1
    sw $t0, 20($a0)
    ### set is_reverse = true

    move $a0, $v0
    lw $a1, 8($sp)
    move $a2, $s0 # current node
    jal as_map_visit_node
ams_no_bottom_r:

    j ams_loop_2
ams_loop_end_2:

    # no target found,
    # check if there is a closer node
    # AND it's currently a full search

    jal get_pos # make sure the target is not the current position
    # otherwise the bot will be traped at the same position

    la $t0, full_search
    lw $t0, 0($t0)

    beq $t0, 0, ams_not_full_search

    la $t0, closest_retry
    lw $t1, 0($t0)

    beq $t1, 0, ams_closest_no_retry
    sub $t1, $t1, 1
    sw $t1, 0($t0) # closest_retry--
    j ams_not_full_search
ams_closest_no_retry:

    la $s0, closest_node
    lw $s0, 0($s0)

    srl $t1, $v0, 16
    and $t2, $v0, 0xffff
    mul $t1, $t1, 30
    add $t1, $t1, $t2

    beq $s0, $t1, ams_not_full_search
    beq $s0, INF, ams_not_full_search

    jal as_route_init
    
    move $a0, $s0 # go to this point instead
    jal as_route_trace

    la $t0, closest_retry
    li $t1, CLOSEST_MIN_RETRY
    sw $t1, 0($t0)

ams_not_full_search:

ams_found_reverse_target:

ams_no_reverse_search:

ams_found_target:

    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 12($sp)
    lw $s2, 16($sp)
    add $sp, $sp, 20
    jr $ra

# is neighbor of a node that is is_reverse == 0 && prev != INF
as_map_is_reverse_target:
    sub $sp, $sp, 16
    sw $ra, 0($sp)

    sw $a0, 4($sp)
    sw $s0, 12($sp)

    la $s0, round_mark
    lw $s0, 0($s0) # load round_mark

    ### left
    jal as_left_node
    bne $v0, UNDEF, amirt_no_left_node
    beq $v1, 0, amirt_no_left_node

    # t0 is the left node index
    mul $t1, $t0, NODE_INFO_SIZE
    add $t1, $t1, $t9
    lw $t2, 20($t1) # is_reverse
    lw $t3, 0($t1) # dist
    lw $t4, 24($t1) # check round_mark

    bne $t2, 0, amirt_no_left_node
    beq $t3, INF, amirt_no_left_node
    bne $t4, $s0, amirt_no_left_node

    # make sure the node is visible
    mul $t1, $t0, 4
    add $t1, $t1, $t8
    lw $t1, 0($t1)
    beq $t1, 0, amirt_no_left_node

    # reachable node in the non-reverse graph
    sw $t0, 8($sp) # store target first

    la $t0, break_wall # set break wall
    li $t1, EAST_WALL # current node is at the east of the left node
    sw $t1, 0($t0)

    jal as_route_init

    lw $a0, 8($sp)
    jal as_route_trace

    lw $v0, 8($sp) # set return value

    j amirt_found
amirt_no_left_node:

    ### right
    lw $a0, 4($sp)
    jal as_right_node
    bne $v0, UNDEF, amirt_no_right_node
    beq $v1, 0, amirt_no_right_node

    # t0 is the right node index
    mul $t1, $t0, NODE_INFO_SIZE
    add $t1, $t1, $t9
    lw $t2, 20($t1) # is_reverse
    lw $t3, 0($t1) # dist
    lw $t4, 24($t1) # check round_mark

    bne $t2, 0, amirt_no_right_node
    beq $t3, INF, amirt_no_right_node
    bne $t4, $s0, amirt_no_right_node

    # make sure the node is visible
    mul $t1, $t0, 4
    add $t1, $t1, $t8
    lw $t1, 0($t1)
    beq $t1, 0, amirt_no_right_node

    # reachable node in the non-reverse graph
    sw $t0, 8($sp) # store target first

    la $t0, break_wall # set break wall
    li $t1, WEST_WALL # current node is at the west of the right node
    sw $t1, 0($t0)

    jal as_route_init

    lw $a0, 8($sp)
    jal as_route_trace

    lw $v0, 8($sp) # set return value

    j amirt_found
amirt_no_right_node:

    ### top
    lw $a0, 4($sp)
    jal as_top_node
    bne $v0, UNDEF, amirt_no_top_node
    beq $v1, 0, amirt_no_top_node

    # t0 is the top node index
    mul $t1, $t0, NODE_INFO_SIZE
    add $t1, $t1, $t9
    lw $t2, 20($t1) # is_reverse
    lw $t3, 0($t1) # dist
    lw $t4, 24($t1) # check round_mark

    bne $t2, 0, amirt_no_top_node
    beq $t3, INF, amirt_no_top_node
    bne $t4, $s0, amirt_no_top_node

    # make sure the node is visible
    mul $t1, $t0, 4
    add $t1, $t1, $t8
    lw $t1, 0($t1)
    beq $t1, 0, amirt_no_top_node

    # reachable node in the non-reverse graph
    sw $t0, 8($sp) # store target first

    la $t0, break_wall # set break wall
    li $t1, SOUTH_WALL # current node is at the south of the top node
    sw $t1, 0($t0)

    jal as_route_init

    lw $a0, 8($sp)
    jal as_route_trace

    lw $v0, 8($sp) # set return value

    j amirt_found
amirt_no_top_node:

    ### bottom
    lw $a0, 4($sp)
    jal as_bottom_node
    bne $v0, UNDEF, amirt_no_bottom_node
    beq $v1, 0, amirt_no_bottom_node

    # t0 is the bottom node index
    mul $t1, $t0, NODE_INFO_SIZE
    add $t1, $t1, $t9
    lw $t2, 20($t1) # is_reverse
    lw $t3, 0($t1) # dist
    lw $t4, 24($t1) # check round_mark

    bne $t2, 0, amirt_no_bottom_node
    beq $t3, INF, amirt_no_bottom_node
    bne $t4, $s0, amirt_no_bottom_node

    # make sure the node is visible
    mul $t1, $t0, 4
    add $t1, $t1, $t8
    lw $t1, 0($t1)
    beq $t1, 0, amirt_no_bottom_node

    # reachable node in the non-reverse graph
    sw $t0, 8($sp) # store target first

    la $t0, break_wall # set break wall
    li $t1, NORTH_WALL # current node is at the north of the bottom node
    sw $t1, 0($t0)

    jal as_route_init

    lw $a0, 8($sp)
    jal as_route_trace

    lw $v0, 8($sp) # set return value

    j amirt_found
amirt_no_bottom_node:

    j amirt_not_found

amirt_found:
    # $v0 already set
    lw $ra, 0($sp)
    lw $s0, 12($sp)
    add $sp, $sp, 16
    jr $ra

amirt_not_found:
    li $v0, UNDEF
    lw $ra, 0($sp)
    lw $s0, 12($sp)
    add $sp, $sp, 16
    jr $ra

################ solve ################

.text

# 136
sudoku:
    sub $sp, $sp, 8
    sw $ra, 0($sp)
    sw $s0, 4($sp)

sudoku_solve:
    jal elim_rule_1 # assuming $a0 doesn't change
    move $s0, $v0

    jal elim_rule_2 # assuming $a0 doesn't change
    or $s0, $s0, $v0

    jal elim_rule_2 # assuming $a0 doesn't change
    or $s0, $s0, $v0

    jal elim_rule_2 # assuming $a0 doesn't change
    or $s0, $s0, $v0

    jal elim_rule_2 # assuming $a0 doesn't change
    or $s0, $s0, $v0

    bne $s0, 0, sudoku_solve

    move $v0, $a0

    lw $ra, 0($sp)
    lw $s0, 4($sp)
    add $sp, $sp, 8
    jr $ra

ALL_VALUES = 65535
GRID_SQUARED = 16
GRIDSIZE = 4

# changed = $s0
# i = $s1
# j = $s2
# &board[i][j] = $t0
# value = $t1
# $a1, $a2, reserved for opt

#### rule 1
# k = $s3
# ii = $s3
# jj = $s4
# k = $s5
# l = $s6

#### rule 2
# k = $s3
# jsum = $s4
# isum  = $s5
# ii = $s3
# jj = $s4
# sum = $s5
# k = $s6
# l = $s7

# ~value = $t6

# $t7 = GRID_SQUARED

# 186
# 198
elim_rule_1:
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

    # for (int i = 0 ; i < GRID_SQUARED ; ++ i) {

    li $s0, 0
    li $s1, 0

    move $t0, $a0

    li $t7, GRID_SQUARED

elim_r1_loop_1:
    beq $s1, $t7, elim_r1_loop_end_1

    li $s2, 0
elim_r1_loop_2:
    beq $s2, $t7, elim_r1_loop_end_2

    lhu $t1, 0($t0)
    not $t6, $t1
    
    beq $t1, 0, elim_r1_not_single_bit
    sub $t2, $t1, 1
    and $t2, $t1, $t2
    bne $t2, 0, elim_r1_not_single_bit
    
    # has signle bit set
    # rule 1

    # for (int k = 0; k < GRID_SQUARED; ++k) {
    mul $a1, $s1, 32
    add $a1, $a1, $a0 # board + i * 30

    mul $a2, $s2, 2
    add $a2, $a2, $a0 # board + j * 2

    ### crazy unrolling

    ##############################
    li $s3, 0

    beq $s3, $s2, elim_r1_if_end_1_1
    lhu $t2, 0($a1)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_2_1

    and $t2, $t2, $t6 # & ~value
    sh $t2, 0($a1)
    or $s0, $s0, 1

elim_r1_if_end_2_1:
elim_r1_if_end_1_1:

    beq $s3, $s1, elim_r1_if_end_3_1
    lhu $t2, 0($a2)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_4_1

    and $t2, $t2, $t6 # & ~value
    sh $t2, 0($a2)
    or $s0, $s0, 1

elim_r1_if_end_4_1:
elim_r1_if_end_3_1:

    ##############################
    li $s3, 1

    beq $s3, $s2, elim_r1_if_end_1_2
    lhu $t2, 2($a1)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_2_2

    and $t2, $t2, $t6 # & ~value
    sh $t2, 2($a1)
    or $s0, $s0, 1

elim_r1_if_end_2_2:
elim_r1_if_end_1_2:

    beq $s3, $s1, elim_r1_if_end_3_2
    lhu $t2, 32($a2)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_4_2

    and $t2, $t2, $t6 # & ~value
    sh $t2, 32($a2)
    or $s0, $s0, 1

elim_r1_if_end_4_2:
elim_r1_if_end_3_2:

    ##############################
    li $s3, 2

    beq $s3, $s2, elim_r1_if_end_1_3
    lhu $t2, 4($a1)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_2_3

    and $t2, $t2, $t6 # & ~value
    sh $t2, 4($a1)
    or $s0, $s0, 1

elim_r1_if_end_2_3:
elim_r1_if_end_1_3:

    beq $s3, $s1, elim_r1_if_end_3_3
    lhu $t2, 64($a2)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_4_3

    and $t2, $t2, $t6 # & ~value
    sh $t2, 64($a2)
    or $s0, $s0, 1

elim_r1_if_end_4_3:
elim_r1_if_end_3_3:

    ##############################
    li $s3, 3

    beq $s3, $s2, elim_r1_if_end_1_4
    lhu $t2, 6($a1)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_2_4

    and $t2, $t2, $t6 # & ~value
    sh $t2, 6($a1)
    or $s0, $s0, 1

elim_r1_if_end_2_4:
elim_r1_if_end_1_4:

    beq $s3, $s1, elim_r1_if_end_3_4
    lhu $t2, 96($a2)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_4_4

    and $t2, $t2, $t6 # & ~value
    sh $t2, 96($a2)
    or $s0, $s0, 1

elim_r1_if_end_4_4:
elim_r1_if_end_3_4:

    ##############################
    li $s3, 4

    beq $s3, $s2, elim_r1_if_end_1_5
    lhu $t2, 8($a1)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_2_5

    and $t2, $t2, $t6 # & ~value
    sh $t2, 8($a1)
    or $s0, $s0, 1

elim_r1_if_end_2_5:
elim_r1_if_end_1_5:

    beq $s3, $s1, elim_r1_if_end_3_5
    lhu $t2, 128($a2)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_4_5

    and $t2, $t2, $t6 # & ~value
    sh $t2, 128($a2)
    or $s0, $s0, 1

elim_r1_if_end_4_5:
elim_r1_if_end_3_5:

    ##############################
    li $s3, 5

    beq $s3, $s2, elim_r1_if_end_1_6
    lhu $t2, 10($a1)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_2_6

    and $t2, $t2, $t6 # & ~value
    sh $t2, 10($a1)
    or $s0, $s0, 1

elim_r1_if_end_2_6:
elim_r1_if_end_1_6:

    beq $s3, $s1, elim_r1_if_end_3_6
    lhu $t2, 160($a2)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_4_6

    and $t2, $t2, $t6 # & ~value
    sh $t2, 160($a2)
    or $s0, $s0, 1

elim_r1_if_end_4_6:
elim_r1_if_end_3_6:

    ##############################
    li $s3, 6

    beq $s3, $s2, elim_r1_if_end_1_7
    lhu $t2, 12($a1)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_2_7

    and $t2, $t2, $t6 # & ~value
    sh $t2, 12($a1)
    or $s0, $s0, 1

elim_r1_if_end_2_7:
elim_r1_if_end_1_7:

    beq $s3, $s1, elim_r1_if_end_3_7
    lhu $t2, 192($a2)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_4_7

    and $t2, $t2, $t6 # & ~value
    sh $t2, 192($a2)
    or $s0, $s0, 1

elim_r1_if_end_4_7:
elim_r1_if_end_3_7:

    ##############################
    li $s3, 7

    beq $s3, $s2, elim_r1_if_end_1_8
    lhu $t2, 14($a1)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_2_8

    and $t2, $t2, $t6 # & ~value
    sh $t2, 14($a1)
    or $s0, $s0, 1

elim_r1_if_end_2_8:
elim_r1_if_end_1_8:

    beq $s3, $s1, elim_r1_if_end_3_8
    lhu $t2, 224($a2)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_4_8

    and $t2, $t2, $t6 # & ~value
    sh $t2, 224($a2)
    or $s0, $s0, 1

elim_r1_if_end_4_8:
elim_r1_if_end_3_8:

    ##############################
    li $s3, 8

    beq $s3, $s2, elim_r1_if_end_1_9
    lhu $t2, 16($a1)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_2_9

    and $t2, $t2, $t6 # & ~value
    sh $t2, 16($a1)
    or $s0, $s0, 1

elim_r1_if_end_2_9:
elim_r1_if_end_1_9:

    beq $s3, $s1, elim_r1_if_end_3_9
    lhu $t2, 256($a2)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_4_9

    and $t2, $t2, $t6 # & ~value
    sh $t2, 256($a2)
    or $s0, $s0, 1

elim_r1_if_end_4_9:
elim_r1_if_end_3_9:

    ##############################
    li $s3, 9

    beq $s3, $s2, elim_r1_if_end_1_10
    lhu $t2, 18($a1)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_2_10

    and $t2, $t2, $t6 # & ~value
    sh $t2, 18($a1)
    or $s0, $s0, 1

elim_r1_if_end_2_10:
elim_r1_if_end_1_10:

    beq $s3, $s1, elim_r1_if_end_3_10
    lhu $t2, 288($a2)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_4_10

    and $t2, $t2, $t6 # & ~value
    sh $t2, 288($a2)
    or $s0, $s0, 1

elim_r1_if_end_4_10:
elim_r1_if_end_3_10:

    ##############################
    li $s3, 10

    beq $s3, $s2, elim_r1_if_end_1_11
    lhu $t2, 20($a1)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_2_11

    and $t2, $t2, $t6 # & ~value
    sh $t2, 20($a1)
    or $s0, $s0, 1

elim_r1_if_end_2_11:
elim_r1_if_end_1_11:

    beq $s3, $s1, elim_r1_if_end_3_11
    lhu $t2, 320($a2)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_4_11

    and $t2, $t2, $t6 # & ~value
    sh $t2, 320($a2)
    or $s0, $s0, 1

elim_r1_if_end_4_11:
elim_r1_if_end_3_11:

    ##############################
    li $s3, 11

    beq $s3, $s2, elim_r1_if_end_1_12
    lhu $t2, 22($a1)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_2_12

    and $t2, $t2, $t6 # & ~value
    sh $t2, 22($a1)
    or $s0, $s0, 1

elim_r1_if_end_2_12:
elim_r1_if_end_1_12:

    beq $s3, $s1, elim_r1_if_end_3_12
    lhu $t2, 352($a2)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_4_12

    and $t2, $t2, $t6 # & ~value
    sh $t2, 352($a2)
    or $s0, $s0, 1

elim_r1_if_end_4_12:
elim_r1_if_end_3_12:

    ##############################
    li $s3, 12

    beq $s3, $s2, elim_r1_if_end_1_13
    lhu $t2, 24($a1)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_2_13

    and $t2, $t2, $t6 # & ~value
    sh $t2, 24($a1)
    or $s0, $s0, 1

elim_r1_if_end_2_13:
elim_r1_if_end_1_13:

    beq $s3, $s1, elim_r1_if_end_3_13
    lhu $t2, 384($a2)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_4_13

    and $t2, $t2, $t6 # & ~value
    sh $t2, 384($a2)
    or $s0, $s0, 1

elim_r1_if_end_4_13:
elim_r1_if_end_3_13:

    ##############################
    li $s3, 13

    beq $s3, $s2, elim_r1_if_end_1_14
    lhu $t2, 26($a1)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_2_14

    and $t2, $t2, $t6 # & ~value
    sh $t2, 26($a1)
    or $s0, $s0, 1

elim_r1_if_end_2_14:
elim_r1_if_end_1_14:

    beq $s3, $s1, elim_r1_if_end_3_14
    lhu $t2, 416($a2)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_4_14

    and $t2, $t2, $t6 # & ~value
    sh $t2, 416($a2)
    or $s0, $s0, 1

elim_r1_if_end_4_14:
elim_r1_if_end_3_14:

    ##############################
    li $s3, 14

    beq $s3, $s2, elim_r1_if_end_1_15
    lhu $t2, 28($a1)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_2_15

    and $t2, $t2, $t6 # & ~value
    sh $t2, 28($a1)
    or $s0, $s0, 1

elim_r1_if_end_2_15:
elim_r1_if_end_1_15:

    beq $s3, $s1, elim_r1_if_end_3_15
    lhu $t2, 448($a2)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_4_15

    and $t2, $t2, $t6 # & ~value
    sh $t2, 448($a2)
    or $s0, $s0, 1

elim_r1_if_end_4_15:
elim_r1_if_end_3_15:

    ##############################
    li $s3, 15

    beq $s3, $s2, elim_r1_if_end_1_16
    lhu $t2, 30($a1)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_2_16

    and $t2, $t2, $t6 # & ~value
    sh $t2, 30($a1)
    or $s0, $s0, 1

elim_r1_if_end_2_16:
elim_r1_if_end_1_16:

    beq $s3, $s1, elim_r1_if_end_3_16
    lhu $t2, 480($a2)

    and $t3, $t2, $t1
    beq $t3, 0, elim_r1_if_end_4_16

    and $t2, $t2, $t6 # & ~value
    sh $t2, 480($a2)
    or $s0, $s0, 1

elim_r1_if_end_4_16:
elim_r1_if_end_3_16:

    ### crazy unrolling
    
elim_r1_not_single_bit:

elim_r1_loop_continue_2:
    add $t0, $t0, 2
    add $s2, $s2, 1
    j elim_r1_loop_2
elim_r1_loop_end_2:

    add $s1, $s1, 1
    j elim_r1_loop_1
elim_r1_loop_end_1:

    move $v0, $s0 # set return value

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
    jr $ra

elim_rule_2:
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

    # for (int i = 0 ; i < GRID_SQUARED ; ++ i) {

    li $s0, 0
    li $s1, 0

    move $t0, $a0

    li $t7, GRID_SQUARED

elim_r2_loop_1:
    beq $s1, $t7, elim_r2_loop_end_1

    li $s2, 0
elim_r2_loop_2:
    beq $s2, $t7, elim_r2_loop_end_2

    lhu $t1, 0($t0)
    
    beq $t1, 0, elim_r2_not_single_bit
    sub $t2, $t1, 1
    and $t2, $t1, $t2
    bne $t2, 0, elim_r2_not_single_bit
    j elim_r2_loop_continue_2
elim_r2_not_single_bit:

    # not single bit set
    # rule 2

    # int jsum = 0, isum = 0;
    li $s4, 0 # jsum
    li $s5, 0 # isum

    mul $a1, $s1, 32
    add $a1, $a1, $a0 # board + i * 32

    mul $a2, $s2, 2
    add $a2, $a2, $a0 # board + j * 2

    # for (int k = 0; k < GRID_SQUARED; ++k) {
    ### crazy unrolling 2

    ##############################
    li $s3, 0

    beq $s3, $s2, elim_r2_if_end_7_1
    lhu $t2, 0($a1)
    or $s4, $s4, $t2
elim_r2_if_end_7_1:

    beq $s3, $s1, elim_r2_if_end_8_1
    lhu $t2, 0($a2)
    or $s5, $s5, $t2
elim_r2_if_end_8_1:
    ##############################
    li $s3, 1

    beq $s3, $s2, elim_r2_if_end_7_2
    lhu $t2, 2($a1)
    or $s4, $s4, $t2
elim_r2_if_end_7_2:

    beq $s3, $s1, elim_r2_if_end_8_2
    lhu $t2, 32($a2)
    or $s5, $s5, $t2
elim_r2_if_end_8_2:
    ##############################
    li $s3, 2

    beq $s3, $s2, elim_r2_if_end_7_3
    lhu $t2, 4($a1)
    or $s4, $s4, $t2
elim_r2_if_end_7_3:

    beq $s3, $s1, elim_r2_if_end_8_3
    lhu $t2, 64($a2)
    or $s5, $s5, $t2
elim_r2_if_end_8_3:
    ##############################
    li $s3, 3

    beq $s3, $s2, elim_r2_if_end_7_4
    lhu $t2, 6($a1)
    or $s4, $s4, $t2
elim_r2_if_end_7_4:

    beq $s3, $s1, elim_r2_if_end_8_4
    lhu $t2, 96($a2)
    or $s5, $s5, $t2
elim_r2_if_end_8_4:
    ##############################
    li $s3, 4

    beq $s3, $s2, elim_r2_if_end_7_5
    lhu $t2, 8($a1)
    or $s4, $s4, $t2
elim_r2_if_end_7_5:

    beq $s3, $s1, elim_r2_if_end_8_5
    lhu $t2, 128($a2)
    or $s5, $s5, $t2
elim_r2_if_end_8_5:
    ##############################
    li $s3, 5

    beq $s3, $s2, elim_r2_if_end_7_6
    lhu $t2, 10($a1)
    or $s4, $s4, $t2
elim_r2_if_end_7_6:

    beq $s3, $s1, elim_r2_if_end_8_6
    lhu $t2, 160($a2)
    or $s5, $s5, $t2
elim_r2_if_end_8_6:
    ##############################
    li $s3, 6

    beq $s3, $s2, elim_r2_if_end_7_7
    lhu $t2, 12($a1)
    or $s4, $s4, $t2
elim_r2_if_end_7_7:

    beq $s3, $s1, elim_r2_if_end_8_7
    lhu $t2, 192($a2)
    or $s5, $s5, $t2
elim_r2_if_end_8_7:
    ##############################
    li $s3, 7

    beq $s3, $s2, elim_r2_if_end_7_8
    lhu $t2, 14($a1)
    or $s4, $s4, $t2
elim_r2_if_end_7_8:

    beq $s3, $s1, elim_r2_if_end_8_8
    lhu $t2, 224($a2)
    or $s5, $s5, $t2
elim_r2_if_end_8_8:
    ##############################
    li $s3, 8

    beq $s3, $s2, elim_r2_if_end_7_9
    lhu $t2, 16($a1)
    or $s4, $s4, $t2
elim_r2_if_end_7_9:

    beq $s3, $s1, elim_r2_if_end_8_9
    lhu $t2, 256($a2)
    or $s5, $s5, $t2
elim_r2_if_end_8_9:
    ##############################
    li $s3, 9

    beq $s3, $s2, elim_r2_if_end_7_10
    lhu $t2, 18($a1)
    or $s4, $s4, $t2
elim_r2_if_end_7_10:

    beq $s3, $s1, elim_r2_if_end_8_10
    lhu $t2, 288($a2)
    or $s5, $s5, $t2
elim_r2_if_end_8_10:
    ##############################
    li $s3, 10

    beq $s3, $s2, elim_r2_if_end_7_11
    lhu $t2, 20($a1)
    or $s4, $s4, $t2
elim_r2_if_end_7_11:

    beq $s3, $s1, elim_r2_if_end_8_11
    lhu $t2, 320($a2)
    or $s5, $s5, $t2
elim_r2_if_end_8_11:
    ##############################
    li $s3, 11

    beq $s3, $s2, elim_r2_if_end_7_12
    lhu $t2, 22($a1)
    or $s4, $s4, $t2
elim_r2_if_end_7_12:

    beq $s3, $s1, elim_r2_if_end_8_12
    lhu $t2, 352($a2)
    or $s5, $s5, $t2
elim_r2_if_end_8_12:
    ##############################
    li $s3, 12

    beq $s3, $s2, elim_r2_if_end_7_13
    lhu $t2, 24($a1)
    or $s4, $s4, $t2
elim_r2_if_end_7_13:

    beq $s3, $s1, elim_r2_if_end_8_13
    lhu $t2, 384($a2)
    or $s5, $s5, $t2
elim_r2_if_end_8_13:
    ##############################
    li $s3, 13

    beq $s3, $s2, elim_r2_if_end_7_14
    lhu $t2, 26($a1)
    or $s4, $s4, $t2
elim_r2_if_end_7_14:

    beq $s3, $s1, elim_r2_if_end_8_14
    lhu $t2, 416($a2)
    or $s5, $s5, $t2
elim_r2_if_end_8_14:
    ##############################
    li $s3, 14

    beq $s3, $s2, elim_r2_if_end_7_15
    lhu $t2, 28($a1)
    or $s4, $s4, $t2
elim_r2_if_end_7_15:

    beq $s3, $s1, elim_r2_if_end_8_15
    lhu $t2, 448($a2)
    or $s5, $s5, $t2
elim_r2_if_end_8_15:
    ##############################
    li $s3, 15

    beq $s3, $s2, elim_r2_if_end_7_16
    lhu $t2, 30($a1)
    or $s4, $s4, $t2
elim_r2_if_end_7_16:

    beq $s3, $s1, elim_r2_if_end_8_16
    lhu $t2, 480($a2)
    or $s5, $s5, $t2
elim_r2_if_end_8_16:
    ### crazy unrolling 2

    li $s7, ALL_VALUES

    beq $s4, $s7, elim_r2_if_else_9

    not $s4, $s4
    and $s4, $s4, $s7
    sh $s4, 0($t0)
    or $s0, $s0, 1

    j elim_r2_loop_continue_2 # continue

elim_r2_if_else_9:
    beq $s5, $s7, elim_r2_if_end_9

    not $s5, $s5
    and $s5, $s5, $s7
    sh $s5, 0($t0)
    or $s0, $s0, 1

    j elim_r2_loop_continue_2 # continue

elim_r2_if_end_9:

    and $s3, $s1, 0xfffc
    and $s4, $s2, 0xfffc
    li $s5, 0

    # add $t3, $s3, GRIDSIZE
    # add $t4, $s4, GRIDSIZE

    mul $a1, $s3, 32
    add $a1, $a1, $a0
    mul $t2, $s4, 2
    add $a1, $a1, $t2

    sll $s6, $s1, 8
    or $s6, $s6, $s2

    sll $s7, $s3, 8
    or $s7, $s7, $s4

    ### crazy unrolling 3

    ################################
    beq $s7, $s6, elim_r2_loop_end_8_0_0

    lhu $t2, 0($a1)
    or $s5, $s5, $t2

elim_r2_loop_end_8_0_0:
    add $s7, $s7, 1
    ################################
    beq $s7, $s6, elim_r2_loop_end_8_0_1

    lhu $t2, 2($a1)
    or $s5, $s5, $t2

elim_r2_loop_end_8_0_1:
    add $s7, $s7, 1
    ################################
    beq $s7, $s6, elim_r2_loop_end_8_0_2

    lhu $t2, 4($a1)
    or $s5, $s5, $t2

elim_r2_loop_end_8_0_2:
    add $s7, $s7, 1
    ################################
    beq $s7, $s6, elim_r2_loop_end_8_0_3

    lhu $t2, 6($a1)
    or $s5, $s5, $t2

elim_r2_loop_end_8_0_3:
    add $s7, $s7, 253
    ################################
    beq $s7, $s6, elim_r2_loop_end_8_1_0

    lhu $t2, 32($a1)
    or $s5, $s5, $t2

elim_r2_loop_end_8_1_0:
    add $s7, $s7, 1
    ################################
    beq $s7, $s6, elim_r2_loop_end_8_1_1

    lhu $t2, 34($a1)
    or $s5, $s5, $t2

elim_r2_loop_end_8_1_1:
    add $s7, $s7, 1
    ################################
    beq $s7, $s6, elim_r2_loop_end_8_1_2

    lhu $t2, 36($a1)
    or $s5, $s5, $t2

elim_r2_loop_end_8_1_2:
    add $s7, $s7, 1
    ################################
    beq $s7, $s6, elim_r2_loop_end_8_1_3

    lhu $t2, 38($a1)
    or $s5, $s5, $t2

elim_r2_loop_end_8_1_3:
    add $s7, $s7, 253
    ################################
    beq $s7, $s6, elim_r2_loop_end_8_2_0

    lhu $t2, 64($a1)
    or $s5, $s5, $t2

elim_r2_loop_end_8_2_0:
    add $s7, $s7, 1
    ################################
    beq $s7, $s6, elim_r2_loop_end_8_2_1

    lhu $t2, 66($a1)
    or $s5, $s5, $t2

elim_r2_loop_end_8_2_1:
    add $s7, $s7, 1
    ################################
    beq $s7, $s6, elim_r2_loop_end_8_2_2

    lhu $t2, 68($a1)
    or $s5, $s5, $t2

elim_r2_loop_end_8_2_2:
    add $s7, $s7, 1
    ################################
    beq $s7, $s6, elim_r2_loop_end_8_2_3

    lhu $t2, 70($a1)
    or $s5, $s5, $t2

elim_r2_loop_end_8_2_3:
    add $s7, $s7, 253
    ################################
    beq $s7, $s6, elim_r2_loop_end_8_3_0

    lhu $t2, 96($a1)
    or $s5, $s5, $t2

elim_r2_loop_end_8_3_0:
    add $s7, $s7, 1
    ################################
    beq $s7, $s6, elim_r2_loop_end_8_3_1

    lhu $t2, 98($a1)
    or $s5, $s5, $t2

elim_r2_loop_end_8_3_1:
    add $s7, $s7, 1
    ################################
    beq $s7, $s6, elim_r2_loop_end_8_3_2

    lhu $t2, 100($a1)
    or $s5, $s5, $t2

elim_r2_loop_end_8_3_2:
    add $s7, $s7, 1
    ################################
    beq $s7, $s6, elim_r2_loop_end_8_3_3

    lhu $t2, 102($a1)
    or $s5, $s5, $t2

elim_r2_loop_end_8_3_3:
    add $s7, $s7, 253

    ### crazy unrolling 3

    beq $s5, ALL_VALUES, elim_r2_if_end_11
    not $s5, $s5
    and $s5, $s5, ALL_VALUES
    sh $s5, 0($t0)
    or $s0, $s0, 1
elim_r2_if_end_11:

elim_r2_loop_continue_2:
    add $t0, $t0, 2
    add $s2, $s2, 1
    j elim_r2_loop_2
elim_r2_loop_end_2:

    add $s1, $s1, 1
    j elim_r2_loop_1
elim_r2_loop_end_1:

    move $v0, $s0 # set return value

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
    jr $ra
