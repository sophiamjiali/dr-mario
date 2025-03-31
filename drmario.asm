################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Dr Mario.
#
# Student 1: Sophia Li, 1009009314
# Student 2: Alexander Lambermon, 1009710877
#
# We assert that the code submitted here is entirely our own 
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       2
# - Unit height in pixels:      2
# - Display width in pixels:    128
# - Display height in pixels:   128
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################


##############################################################################
# Notes
##############################################################################

# Features Implemented:
#   Hard:
#     1. Animation: remove matches, drop blocks, viruses twinkle
#
#   Easy:
#     1. Gravity: each second that passes automatically moves capsule down
#     2. Pause: displays paused message on screen upon pressing p
#     3. Game Mode: play can select a game mode affecting virus number and speed
#     4. Game Level: triggered upon eliminating all viruses, affects virus number and speed
#     5. Drop Shadow: Displays a shadow to show where the capsule will fall
#     6. Next Capsule: Displays on the right the next capsule to be generated

##############################################################################

    .data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL: .word 0x10008000
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD: .word 0xffff0000

##############################################################################
# Mutable Data
##############################################################################

# store each colour
BLACK: .word 0x000000
DARK_GRAY: .word 0x636363
GRAY: .word 0xc0c0c0
WHITE: .word 0xffffff
RED: .word 0xcc1616
BLUE: .word 0x2f3269
YELLOW: .word 0xffb300
BOTTLE_BLUE: .word 0xadd8e6

LIGHT_RED: .word 0xffcccb
LIGHT_BLUE: .word 0xadd8e6
LIGHT_YELLOW: .word 0xffa500

# create a colour table to choose from when generating a random colour
COLOUR_TABLE: .word 0xcc1616, 0xffb300, 0x2f3269

# game level: determines the difficulty per game iteration
GAME_LEVEL: .word 1

# game mode: determines the multiplier for virus generation and speed
GAME_MODE: .word 1

# colours of the saved capsule halves; the next capsule used in play
SAVED_CAPSULE_FIRST: .word 0x000000
SAVED_CAPSULE_SECOND: .word 0x000000

# sets how fast gravity will move the capsule down barring a movement input
GRAVITY_SPEED: .word 1500

# tracks the current timer that decides if gravity should be induced
GRAVITY_TIMER: .word 0

# tracks when to make the viruses do a beautiful little sparkle sparkle
VIRUS_ANIMATION_TIMER: .word 0

# tracks the global number of viruses still in play
NUM_VIRUS: .word 0

# holds the pause status, 0 if off, 1 if on
PAUSE_STATE: .word 0

# formats how game memory appears in memory, organizational only
SPACER: .space 28        

# allocate space to hold memory representing the playing area
GAME_MEMORY: .space 3840 


##############################################################################
# Code
##############################################################################
	.text
	.globl main
	
.macro set_defaults ()
    # define defaults here
    li $s6, 2       # number of pixels in a block
    li $s7, 3       # minimum consequtive blocks that count as a match - 1
.end_macro

.macro set_defaults ()
    # define defaults here
    li $s6, 2       # number of pixels in a block
    li $s7, 3       # minimum consequtive blocks that count as a match - 1
.end_macro

.macro new_saved_capsule ()
    # generates a new capsule on the side of the bottle; colours for the new capsule in play
    # is fetched from these colours
    
    addi $sp, $sp -12               # allocate space on the stack for three registers
    sw $t0, 8($sp)                  # save $t0 to the stack
    sw $t1, 4($sp)                  # save $t1 to the stack
    sw $t2, 0($sp)                  # save $t2 to the stack
    
    li $t0, 36                      # initialize the x-coordinate for the saved capsule
    li $t1, 20                      # initialize the y-coordinate for the saved capsule
    
    generate_colour ()              # generate a random colour, stored in $v1
    move $t2, $v1                   # extract the colour
    draw_square ($t0, $t1, $t2)     # draw the top-half of the capsule
    
    la $t0, SAVED_CAPSULE_FIRST     # fetch the address of the saved capsule's first half
    sw $t2, 0($t0)                  # save the generated colour
    
    li $t0, 36                      # (re)initialize the x-coordinate for the saved capsule
    addi $t1, $t1, 2                # increment the y-coordinate down by one block
    
    generate_colour ()              # generate a random colour, stored in $v1
    move $t2, $v1                   # extract the colour
    draw_square ($t0, $t1, $t2)     # draw the bottom-half of the capsule
    
    la $t0, SAVED_CAPSULE_SECOND    # fetch the address of the saved capsule's second half
    sw $t2, 0($t0)                  # save the generated colour
    
    lw $t2, 0($sp)                  # restore $t2 from the stack
    lw $t1, 4($sp)                  # restore $t1 from the stack
    lw $t0, 8($sp)                  # restore $t0 from the stack
    addi $sp, $sp, 12               # free space on the stack
.end_macro

.macro new_capsule ()
    # generates a new capsule in the mouth of the bottle, storing its address as (x,y)
    # coordinates in the save registers; fetches its colours from the stored capsule
    
    addi $sp, $sp, -4       # allocate space for one (more) register on the stack
    sw $t0, 0($sp)          # $t0 is used in this macro, save it to the stack to avoid overwriting 
    
    
    lw $s3, SAVED_CAPSULE_FIRST     # set the first half's colour to the first saved colour
    li $s0, 16                      # set the x-coordinate
    li $s1, 16                      # set the y-coordinate
    draw_square ($s0, $s1, $s3)     # draw the top-half of the capsule
    
    lw $s4, SAVED_CAPSULE_SECOND    # set the second half's colour to the second saved colour
    li $t0, 18                      # set the x-coordinate
    draw_square ($t0, $s1, $s4)     # draw the bottom-half of the capsule
    
    li $s2, 2                       # sets 'horizontal = 2' as orientation in $v1
    
    new_saved_capsule ()            # generate a new saved capsule
    
    lw $t0, 0($sp)                  # restore the original $t0 value
    addi $sp, $sp, 4                # free space used by the three registers
.end_macro

.macro move_capsule (%direction)
    # move the current capsule the specified direction
    
    addi $sp, $sp, -8       # allocate space for two (more) registers on the stack
    sw $t0, 4($sp)          # $t0 is used in this macro, save it to the stack to avoid overwriting
    sw $t1, 0($sp)          # $t1 is used in this macro, save it to the stack to avoid overwriting
    
    li $a2, %direction      # load the specified direction
    
    beq $s2, 1, move_vertical_capsule          # move the second half of the vertical capsule
    beq $s2, 2, move_horizontal_capsule        # move the second half of the horizontal capsule
    
    move_vertical_capsule:
        add $t1, $s1, $s6                       # the second half is below of the first half
        move_square ($s0, $t1, %direction)      # move the capsule's second half first to avoid being overwritten
        move_square ($s0, $s1, %direction)      # move first half second, avoids overwriting the second half
        j move_capsule_done                     # return back to main
        
    move_horizontal_capsule:
        beq $a2, 1, move_horizontal_capsule_left    # if moving left, move the capsule's first half first
        
        add $t0, $s0, $s6                       # the second half is to the right of the first half
        move_square ($t0, $s1, %direction)      # move the second half first to avoid being overwritten
        move_square ($s0, $s1, %direction)      # move first half second, avoids overwriting the second half
        j move_capsule_done                     # return back to main
        
    move_horizontal_capsule_left: 
        move_square ($s0, $s1, %direction)      # move the first half first to avoid being overwritten
        add $t0, $s0, $s6                       # the second half is to the right of the first half
        move_square ($t0, $s1, %direction)      # move the second half second, avoids overwriting the first half
        j move_capsule_done                     # return back to main
 
    move_capsule_done:                  
        lw $t1, 0($sp)      # restore the original $t1 value
        lw $t0, 4($sp)      # restore the original $t0 value
        addi $sp, $sp, 8    # free space used by the three registers
.end_macro

.macro move_square (%x, %y, %direction)
    # given (x,y) coordinates, move the square defined around this point the specified direction
    
    move $a0, %x                 # move the x-coordinate into a safe register to avoid overwriting
    move $a1, %y                 # move the y-coordinate into a safe register to avoid overwriting
    li $a2, %direction           # move direction into a safe register to avoid overwriting
    
    addi $sp, $sp, -16           # allocate space for four (more) registers on the stack
    sw $t0, 12($sp)              # $t0 is used in this macro, save it to the stack to avoid overwriting
    sw $t1, 8($sp)               # $t1 is used in this macro, save it to the stack to avoid overwriting
    sw $t3, 4($sp)               # $t3 is used in this macro, save it to the stack to avoid overwriting
    sw $t4, 0($sp)               # $t3 is used in this macro, save it to the stack to avoid overwriting
    
    move $t0, $a0                # load x-coordinate into function argument register
    move $t1, $a1                # load y-coordinate into function argument register
    
    lw $t4, BLACK                # load the colour black
    get_pixel ($t0, $t1)         # fetch the address corresponding to the coordinate
    lw $t3, 0($v0)               # fetch the colour of the coordinate
    
    draw_square ($t0, $t1, $t4)     # colour the original square at (x,y) black
    
    beq $a2, 1, shift_left        # if direction specifies left
    beq $a2, 2, shift_right       # if direction specifies right
    beq $a2, 3, shift_up          # if direction specifies up
    beq $a2, 4, shift_down        # if direction specifies down
    
    shift_left:
        sub $t0, $t0, $s6                   # shift the x-coordinate left by two units
        j move_done                         # completed, jump back
    shift_right:
        add $t0, $t0, $s6                   # shift the x-coordinate right by two units
        j move_done                         # completed, jump back
    shift_up:
        sub $t1, $t1, $s6                   # shift the y-coordinate up by two units
        j move_done                         # completed, jump back
    shift_down:
        add $t1, $t1, $s6                   # shift the y-coordinate down by two units
        j move_done                         # completed, jump back
   
    move_done:
        draw_square ($t0, $t1, $t3)         # draw the square at the new coordinates with the original colour
        
        lw $t4, 0($sp)       # restore the original $t4 value
        lw $t3, 4($sp)       # restore the original $t3 value
        lw $t1, 8($sp)      # restore the original $t1 value
        lw $t0, 12($sp)      # restore the original $t0 value
        addi $sp, $sp, 16    # free space used by the four registers
.end_macro

.macro draw_square (%x, %y, %colour)
    # draws a square starting at (x,y) of the given colour
    
    move $a0, %x                    # move the x-coordinate into a safe register to avoid overwriting
    move $a1, %y                    # move the y-coordinate into a safe register to avoid overwriting
    move $a3, %colour               # move the direction into a safe register to avoid overwriting
    
    addi $sp, $sp, -8       # allocate space for two (more) register on the stack
    sw $t0, 4($sp)          # $t0 is used in this macro, save it to the stack to avoid overwriting  
    sw $t1, 0($sp)          # $t1 is used in this macro, save it to the stack to avoid overwriting  
    
    move $t0, $a0           # initialize the x-coordinate
    move $t1, $a1           # initialize the y-coordinate  
    
    draw_pixel ($t0, $t1, $a3)      # draw the first pixel
    addi $t1, $t1, 1                # move the y-coordinate down by one
    draw_pixel ($t0, $t1, $a3)      # draw the second pixel
    addi $t0, $t0, 1                # move the x-coordinate over by one
    draw_pixel ($t0, $t1, $a3)      # draw the third pixel
    subi $t1, $t1, 1                # move the y-coordinate up by one
    draw_pixel ($t0, $t1, $a3)      # draw the fourth pixel
    
    lw $t1, 0($sp)       # restore the original value of $t1
    lw $t0, 4($sp)       # restore the original value of $t0
    addi $sp, $sp, 8     # free space used by the four registers
.end_macro

.macro draw_line (%start_x, %start_y, %end_x, %end_y, %colour, %direction)
    # draws a line from the start to end coordinates in the specified direction 
    # in the specified colour
    
    li $t0, %start_x                # extract the starting x-coordinate
    li $t1, %start_y                # extract the starting y-coordinate
    li $t3, %direction              # extract the direction
    
    beq $t3, 1, draw_vertical        # direction 1 specifies a vertical line
    beq $t3, 2, draw_horizontal      # direction 2 specifies a horizontal line
    
    draw_vertical:
        li $t4, %end_y                          # extract the end y-coordinate
        draw_vertical_loop:
            bgt $t1, $t4, draw_line_done        # exit the loop
            draw_pixel ($t0, $t1, %colour)      # draw the pixel
            addi $t1, $t1, 1                    # increment the y-coordinate by two
            j draw_vertical_loop                # continue the loop
            
    draw_horizontal:
        li $t4, %end_x                          # extract the end x-coordinate
        draw_horizontal_loop:
            bgt $t0, $t4, draw_line_done        # exit the loop
            draw_pixel ($t0, $t1, %colour)      # draw the pixel
            addi $t0, $t0, 1                    # increment the x-coordinate by two
            j draw_horizontal_loop              # continue the loop
            
    draw_line_done:                         # exit the macro 
.end_macro

.macro draw_pixel (%x, %y, %colour)
    # draws a pixel of the given colour at the coordinate specified by (x,y)
    
    get_pixel (%x, %y)    # fetch the bitmap address corresponding to (x,y)
    move $a3, %colour     # move the colour into a function argument register
    sw $a3, 0($v0)        # save the specified colour at the given address
.end_macro

.macro get_pixel (%x, %y)
    # given (x,y) coordinates, returns the corresponding address in the bitmap display
    
    addi $sp, $sp, -8       # allocate space for two (more) registers on the stack
    sw $t0, 4($sp)          # $t0 is used in this macro, save it to the stack to avoid overwriting
    sw $t1, 0($sp)          # $t1 is used in this macro, save it to the stack to avoid overwriting
    
    move $a0, %x            # load x-coordinate into the first function argument register
    move $a1, %y            # load y-coordinate into the second function argument register
    li $t0, 256             # load the number of bytes to offset to the next row
    li $t1, 4               # load the number of bytes to offset to the next pixel
    
    mul $t1, $t1, $a0       # calculate the x-offset of the pixel (relative to the left)
    mul $t0, $t0, $a1       # calculate the y-offset of the pixel (relative to the top)
    add $t0, $t0, $t1       # calculate the overall byte offset
    add $t0, $t0, $gp       # calculate the address relative to the bitmap
    move $v0, $t0           # save the address
    
    lw $t1, 0($sp)          # restore the original $t1 value
    lw $t0, 4($sp)          # restore the original $t0 value
    addi $sp, $sp, 8        # free space used by the two registers
.end_macro

.macro draw_coordinates (%x, %y, %colour)
    # adapter for draw_pixel to take literals
    
    li $a0, %x                              # move the literal x-coordinate into a register
    li $a1, %y                              # move the literal y-coordinate into a register
    draw_pixel ($a0, $a1, %colour)          # draw the pixel
.end_macro

.macro generate_colour ()
    # generate a random colour out of the given choices: red, yellow, and blue
    
    addi $sp, $sp, -16      # allocate space for four (more) registers on the stack
    sw $a0, 12($sp)         # $a0 is used in this macro, save it to the stack to avoid overwriting
    sw $a1, 8($sp)          # $a1 is used in this macro, save it to the stack to avoid overwriting
    sw $v0, 4($sp)          # $v0 is used in this macro, save it to the stack to avoid overwriting
    sw $t0, 0($sp)          # $t0 is used in this macro, save it to the stack to avoid overwriting
    
    li $v0, 42          # load syscall code for RANDGEN
    li $a0, 0           # set up RANGEN with generator 0
    li $a1, 3           # set the upper limit for the random number as 2
    syscall             # make the system call, returning to $a0
    
    la $t0, COLOUR_TABLE        # load address of color table
    sll $a0, $a0, 2             # multiply index by four (word size)
    add $t0, $t0, $a0           # offset into table
    lw $v1, 0($t0)              # load color into return register
    
    lw $t0, 0($sp)       # restore the original $t0 value
    lw $v0, 4($sp)       # restore the original $v0 value
    lw $a1, 8($sp)       # restore the original $a1 value
    lw $a0, 12($sp)      # restore the original $a0 value
    addi $sp, $sp, 16    # free space used by the four registers
.end_macro

.macro compare_colours (%consequtive, %current)
    # evaluates if the current colour is the same (or the lighter variety) of 
    # the consequtive colour; returns 0 for no, 1 for yes
    
    addi $sp, $sp, -4           # allocate space on the stack for one register
    sw $t0, 0($sp)              # save $t0 to the stack
    
    move $a0, %consequtive          # move the current colour into a function argument register
    move $a1, %current           # move the target colour into a function argument register
    
    lw $t0, RED                         # load the colour red
    beq $a0, $t0, compare_red           # if the target colour is red
    lw $t0, BLUE                        # load the colour red
    beq $a0, $t0, compare_blue          # if the target colour is blue
    lw $t0, YELLOW                      # load the colour red
    beq $a0, $t0, compare_yellow        # if the target colour is yellow
    
    j compare_no_match                  # else, by default, no match was found
    
    compare_red:
        beq $a1, $t0, compare_match     # if the current colour is red
        lw $t0, LIGHT_RED               # load the alt colour light red
        beq $a1, $t0, compare_match     # if the current colour is light red
        j compare_no_match              # else, no match
    compare_blue:
        beq $a1, $t0, compare_match     # if the current colour is blue
        lw $t0, LIGHT_BLUE               # load the alt colour light blue
        beq $a1, $t0, compare_match     # if the current colour is light blue
        j compare_no_match              # else, no match
    compare_yellow:
        beq $a1, $t0, compare_match     # if the current colour is yellow
        lw $t0, LIGHT_YELLOW            # load the alt colour light yellow
        beq $a1, $t0, compare_match     # if the current colour is light yellow
        j compare_no_match              # else, no match
    
    compare_no_match:
        li $v0, 0               # load the code into the return variable for no match found
        j compare_done          # finalize the macro
    compare_match:
        li $v0, 1               # load the code into the return variable for match found
        j compare_done          # finalize the macro
        
    compare_done:
        lw $t0, 0($sp)          # restore the original value of $t0
        addi $sp, $sp, 4        # free space on the stack
.end_macro

.macro move_info_down (%x, %y)
    # given (x,y) coordinates of a pixel in the display, move the information associated with it down a block
    
    addi $sp, $sp, -4           # allocate space for one (more) register on the stack
    sw $t0, 0($sp)              # store $t0 to the stack
    
    get_memory_pixel (%x, %y)   # fetch the address of the pixel in memory
    lb $t0, 0($v0)              # fetch the block type code
    sb $t0, 192($v0)            # save the block type code into the pixel below in memory
    lb $t0, 1($v0)              # fetch the connection orientation code
    sb $t0, 193($v0)            # save the connection orientation code into the pixel below in memory

    sb $zero, 0($v0)                # erase the memory stored in the current position
    sb $zero, 1($v0)                # ,,,
    
    lw $t0, 0($sp)              # restore the original $t0 value
    addi $sp, $sp, 4            # free space used by the register
.end_macro

.macro save_info ()
    # saves the information about the current capsule (round just finished) into game memory
    
    addi $sp, $sp, -8           # allocate space for two (more) registers on the stack
    sw $t0, 4($sp)              # $t0 is used in this macro, save it to othe stack to avoid overwriting
    sw $t1, 0($sp)              # $t1 is used in this macro, save it to othe stack to avoid overwriting
    
    get_memory_pixel ($s0, $s1)         # fetch the address of the current pixel in game memory
    li $t1, 1                           # load the block type code for capsules
    sb $t1, 0($v0)                      # save the byte code to the first position in the address
    
    beq $s2, 1, save_info_vertical      # if the capsule is vertical
    beq $s2, 2, save_info_horizontal    # if the capsule is horizontal
    
    save_info_vertical:
        li $t1, 4                       # load the orientation direction code for down
        sb $t1, 1($v0)                  # save the byte code to the second position in the address
        addi $t0, $s1, 2                # fetch the y-coordinate of the second half
        get_memory_pixel ($s0, $t0)     # fetch the address of the next capsule half
        li $t1, 1                       # load the block type code for capsule
        sb $t1, 0($v0)                  # save the byte code to the first position in the address
        li $t1, 3                       # load the orientation direction code for up
        sb $t1, 1($v0)                  # save the byte code to the second position in the address
        j save_info_done                # return to the original calling
        
    save_info_horizontal:
        li $t1, 2                       # load the orientation direction code for right
        sb $t1, 1($v0)                  # save the bye code to the second position in the address
        addi $t0, $s0, 2                # fetch the x-coordinate of the second half
        get_memory_pixel($t0, $s1)      # fetch the address of the nextca capsule half
        li $t1, 1                       # load the block type code for capsule
        sb $t1, 0($v0)                  # save the byte code to the first position in the address
        li $t1, 1                       # load the orientation drection code for left
        sb $t1, 1($v0)                  # save the byte code to the second positio nin the address
        j save_info_done                # return to the original calling
        
    save_info_done:
        lw $t1, 0($sp)       # restore the original $t1 value
        lw $t0, 4($sp)       # restore the original $t0 value
        addi $sp, $sp, 8    # free space used by the two registers    
.end_macro

.macro get_info (%x, %y)
    # fetches information about the pixel at the (x,y) coordinates; $v0 holds block type (1 is capsule, 2 is virus),
    # $v1 holds connection direction (0 if not connected (or virus), 1-4 represent left right up down)
    
    addi $sp, $sp, -4       # allocate space for one (more) registers on the stack
    sw $t0, 0($sp)          # save $t0 to the stack
    
    move $a0, %x                        # load x-coordinate into a function argument register
    move $a1, %y                        # load y-coordinate into a function argumnet register
    
    get_memory_pixel ($a0, $a1)         # fetch the address of the pixel in game memory
    move $t0, $v0                       # extract the address, $v0 is overwritten later
    lb $v0, 0($t0)                      # extract the first byte, holding block type
    lb $v1, 1($t0)                      # extract the second byte, holding connection direction
    
    lw $t0, 0($sp)          # restore the original $t0 value
    addi $sp, $sp, 4        # free space used by the register
.end_macro

.macro remove_info (%x, %y)
    # removes the information about a pixel at the (x,y) coordinates from the game memory
    
    move $a0, %x                            # load x-coordinate into a function argument register
    move $a1, %y                            # load y-coordinate into a function argumnet register
    
    addi $sp, $sp, -8           # allocate space for two (more) register on the stack
    sw $t0, 4($sp)              # $t0 is used in this macro, save it to the stack to avoid overwriting
    sw $t1, 0($sp)              # $t1 is used in this macro, save it to the stack to avoid overwriting
    
    get_memory_pixel ($a0, $a1)             # fetch the address of the pixel in memory
    
    lb $t0, 0($v0)                          # extract the block type code
    beq $t0, 2, decrement_virus             # if its a virus, decrement the global counter
    
    remove_info_continue:
        sb $zero, 0($v0)                    # erase the block type
        lb $t1, 1($v0)                      # fetch the connection orientation of the block
        sb $zero, 1($v0)                    # erase the connection orientation
        
        beq $t1, 0, remove_info_done        # if not connected to anything, done
        beq $t1, 1, remove_left             # if connected on the left
        beq $t1, 2, remove_right            # if connected on the right
        beq $t1, 3, remove_up               # if connected above
        beq $t1, 4, remove_down             # if connected below
        
        remove_left:
            subi $t0, $a0, 2                    # shift the x-coordinate left by one block
            get_memory_pixel ($t0, $a1)         # fetch the address in memory
            j remove_info_done                  # update the second half's connection orientation
        remove_right:
            addi $t0, $a0, 2                    # shift the x-coordinate right by one block
            get_memory_pixel ($t0, $a1)         # fetch the address in memory
            j remove_info_done                  # update the second half's connection orientation
        remove_up:
            subi $t0, $a1, 2                    # shift the y-coordinate up by one block
            get_memory_pixel ($a0, $t0)         # fetch the address in memory
            j remove_info_done                  # update the second half's connection orientation
        remove_down:
            addi $t0, $a1, 2                    # shift the y-coordinate down by one block
            get_memory_pixel ($a0, $t0)         # fetch the address in memory
            j remove_info_done                  # update the second half's connection orientation
    
    decrement_virus:
        la $t0, NUM_VIRUS               # fetch the address of the global counter for the number of viruses
        lw $t1, 0($t0)                  # fetch the number of viruses still in play
        subi $t1, $t1, 1                # decrement the number of viruses by one
        sw $t1, 0($t0)                  # save the counter incrementation
        j remove_info_continue          # continue to removing the block's info
        
    remove_info_done:
        sb $zero, 1($v0)            # set the other half's connection orientation to zero

        lw $t1, 0($sp)              # restore the original value of $t1
        lw $t0, 4($sp)              # restore the original value of $t0
        addi $sp, $sp, 8            # free space used by the register
    
.end_macro

.macro get_memory_pixel (%x, %y)
    # give (x,y) coordinates on the display, return the corresponding address in game memory
    
    move $a0, %x             # move the x-coordinate into a safe register
    move $a1, %y             # move the y-coordinate into a safe register
    
    addi $sp, $sp, -8           # allocate space for two (more) registers on the stack
    sw $t0, 4($sp)              # $t0 is used in this macro, save it to the stack to avoid overwriting
    sw $t1, 0($sp)              # $t1 is used in this macro, save it to the stack to avoid overwriting
    
    move $t0, $a0               # load x-coordinate into the first function argument register
    move $t1, $a1               # load y-coordinate into the second function argument register
    
    subi $t0, $t0, 6            # subtract the playing area offset from the x-coordinate
    subi $t1, $t1, 18           # subtract the playing area offset from the y-coordinate
    
    mul $t0, $t0, 4            # calculate the x-offset of the pixel (relative to the left)
    mul $t1, $t1, 96           # calculate the y-offset of the pixel (relative to the top)
    
    add $t0, $t0, $t1           # calculate the overall byte offset
 
    la $t1, GAME_MEMORY         # fetch the address of the game memory
    add $t0, $t0, $t1           # calculate the address relative to the game memory address offset
    
    move $v0, $t0               # save the address

    lw $t1, 0($sp)              # restore the original $t1 value
    lw $t0, 4($sp)              # restore the original $t0 value
    addi $sp, $sp, 8           # free space used by the two registers
.end_macro

.macro generate_virus ()
    # generates a new virus at a random location below half the bottle's depth, storing its location
    # in memory; if it generated a position that is already occupied, generate another
    
    li $v0, 42          # load syscall code for RANDGEN
    li $a0, 0           # set a generator
    li $a1, 3           # set the upper limit for the random number as 2
    syscall             # generate a random number for the colour selection
    
    beq $a0, 0, virus_red           # if the colour selected was red
    beq $a0, 1, virus_blue          # if the colour selected was blue
    beq $a0, 2, virus_yellow        # if the colour selected was yellow
    
    virus_red:
        lw $t2, RED                  # load the colour red
        lw $t3, LIGHT_RED            # load the secondary colour for red
        j virus_generate_position    # continue to generate a coordinate
    virus_blue:
        lw $t2, BLUE                 # load the colour blue
        lw $t3, LIGHT_BLUE           # load the secondary colour for red
        j virus_generate_position    # continue to generate a coordinate
    virus_yellow:
        lw $t2, YELLOW               # load the colour yellow
        lw $t3, LIGHT_YELLOW         # load the secondary colour for red
        j virus_generate_position    # continue to generate a coordinate
    
    virus_generate_position:
        li $v0, 42              # load syscall code for RANDGEN
        li $a0, 0               # set a generator
        li $a1, 12              # set the upper limit for the random number as 12 (0 to 11)
        syscall                 # generate a random number for the x-coordinate
        sll $t0, $a0, 1         # multiply by two (shift left by one)
        addi $t0, $t0, 6        # shift the first x-coordinate from [0, 22] to [6, 28]
        
        li $v0, 42              # load syscall code for RANDGEN
        li $a0, 0               # set a generator
        li $a1, 12              # set the upper limit for the random number as 12 (0 to 11)
        syscall                 # generate a random number for the y-coordinate
        sll $t1, $a0, 1         # multiply by two (shift left by one)
        addi $t1, $t1, 34       # shift the first y-coordinate from [0, 22] to [34, 56]
        
        get_memory_pixel ($t0, $t1)                 # fetch the pixel's memory
        lw $v0, 0($v0)                              # fetch the information stored at the memory address
        bne $v0, $zero, virus_generate_position     # if there is a collision, regenerate coordinates

    get_pixel ($t0, $t1)    # fetch the address of the pixel
    sw $t2, 0($v0)          # colour the coordinate the chosen colour
    sw $t3, 4($v0)          # colour the next coordinate the secondary virus colour
    sw $t3, 256($v0)        # colour the coordinate below the secondary virus colour
    sw $t2, 260($v0)        # colour the next coordinate the chosen colour

    get_memory_pixel ($t0, $t1)     # fetch the address of the block in memory
    li $t2, 2                       # load the block type code for virus
    sb $t2, 0($v0)                  # save the block type code as the first byte
    sb $zero, 1($v0)                # save the orientation direction code as zero (not connected)
    
    la $t0, NUM_VIRUS               # fetch the address of the global counter for the number of viruses
    lw $t1, 0($t0)                  # fetch the number of viruses still in play
    addi $t1, $t1, 1                # increment the number of viruses by one
    sw $t1, 0($t0)                  # save the counter incrementation
.end_macro

.macro remove_shadow ()
    # removes a drop shadow from the current capsule location
    
    addi $sp, $sp, -16              # allocate space on the stack for four registers
    sw $t0, 12($sp)                 # save $t0 to the stack
    sw $t1, 8($sp)                  # save $t1 to the stack
    sw $t2, 4($sp)                  # save $t2 to the stack
    sw $t3, 0($sp)                  # save $t3 to the stack
    
    move $t0, $s0                   # fetch the capsule's x-coordinate
    move $t1, $s1                   # fetch the capsule's y-coordinate
    
    beq $s2, 2, drop_horizontal     # if horizontal, increment y-coordinate by one block
    addi $t1, $t1, 2                # else, vertical; increment by two blocks
    
    drop_horizontal:    
        addi $t1, $t1, 2            # increment down by one block
    
    lw $t3, BLACK                   # load the colour black
    
    remove_shadow_for_y:
        beq $t1, 58, check_remove_shadow    # if no collision was found but the bottom, check for removal
        
        get_pixel ($t0, $t1)            # fetch the address of the current pixel
        lw $t2, 0($v0)                  # extract its colour
        
        bne $t2, $t3, check_remove_shadow       # if collision detected, check if a shadow should be drawn
        beq $s2, 1, remove_shadow_vertical             # if vertical, only check one pixel
        
        lw $t2, 8($v0)                          # else, extract the colour under the capsule's second half
        bne $t2, $t3, check_remove_shadow              # if collision detected, check if a shadow should be drawn
        
        remove_shadow_vertical:
            addi $t1, $t1, 2            # increment to the next block down
            j remove_shadow_for_y       # continue the for-loop
            
    check_remove_shadow:
        beq $s2, 2, check_shadow_horizontal         # if the capsule is horizontal
        subi $t3, $t1, 4                            # else, vertical; check two blocks above
        j is_valid_remove                           # check the validity of the removal
        check_shadow_horizontal: subi $t3, $t1, 2   # check one block above
            
        is_valid_remove:
            beq $t3, $s1, remove_shadow_done             # if flush against the block, don't remove
            
    lw $t2, BLACK                       # load the colour black
    
    subi $t1, $t1, 1                    # decrement to the available position's bottom pixel
            
    beq $s2, 1, remove_main_shadow        # if vertical, only draw the main block's shadow
    
    addi $t0, $t0, 3                    # else, horizontal; increment to the second half's right pixel
    draw_pixel ($t0, $t1, $t2)          # draw the fourth pixel
    subi $t0, $t0, 1                    # decrement the x-coordinate by one pixel
    draw_pixel ($t0, $t1, $t2)          # draw the third pixel
    subi $t0, $t0, 2                    # decrement the x-coordinate to the first pixel
    
    remove_main_shadow:
        draw_pixel ($t0, $t1, $t2)      # draw the first pixel
        addi $t0, $t0, 1                # increment the x-coordinate by one pixel
        draw_pixel ($t0, $t1, $t2)      # draw the second pixel
            
    remove_shadow_done:
        lw $t3, 0($sp)          # restore the original $t3 value
        lw $t2, 4($sp)          # restore the original $t2 value
        lw $t1, 8($sp)          # restore the original $t1 value
        lw $t0, 12($sp)         # restore the original $t0 value
        addi $sp, $sp, 16       # free space used by the four registers    
.end_macro

.macro drop_shadow ()
    # displays a drop shadow for the current capsule location
    
    addi $sp, $sp, -16              # allocate space on the stack for four registers
    sw $t0, 12($sp)                 # save $t0 to the stack
    sw $t1, 8($sp)                  # save $t1 to the stack
    sw $t2, 4($sp)                  # save $t2 to the stack
    sw $t3, 0($sp)                  # save $t3 to the stack
    
    move $t0, $s0                   # fetch the capsule's x-coordinate
    move $t1, $s1                   # fetch the capsule's y-coordinate
    
    beq $s2, 2, drop_horizontal     # if horizontal, increment y-coordinate by one block
    addi $t1, $t1, 2                # else, vertical; increment by two blocks
    
    drop_horizontal:    
        addi $t1, $t1, 2            # increment down by one block
    
    lw $t3, BLACK                   # load the colour black
    
    shadow_for_y:
        beq $t1, 58, check_shadow       # if no collisions, check if a shadow should be drawn
        
        get_pixel ($t0, $t1)            # fetch the address of the current pixel
        lw $t2, 0($v0)                  # extract its colour
        
        bne $t2, $t3, check_shadow      # if collision detected, check if a shadow should be drawn
        beq $s2, 1, shadow_vertical     # if vertical, only check one pixel
        
        lw $t2, 8($v0)                  # else, extract the colour under the capsule's second half
        bne $t2, $t3, check_shadow       # if collision detected, check if a shadow should be drawn
        
        shadow_vertical:
            addi $t1, $t1, 2            # increment to the next block down
            j shadow_for_y              # continue the for-loop
            
    check_shadow:
        beq $s2, 1, check_shadow_vertical           # if the capsule is vertical
        subi $t3, $t1, 2                            # else, horizontal; check the block is directly below the capsule
        j is_valid_draw                             # verify validity
        check_shadow_vertical:  subi $t3, $t1, 4    # check if the block is directly below the capsule
            
        is_valid_draw:
            beq $t3, $s1, drop_shadow_done             # if flush against the block, don't remove
            
    lw $t2, DARK_GRAY                   # load the colour dark gray
    
    subi $t1, $t1, 1                    # decrement to the available position's bottom pixel
    
    beq $s2, 1, draw_main_shadow        # if vertical, only draw the main block's shadow
    
    addi $t0, $t0, 3                    # else, horizontal; increment to the second half's right pixel
    draw_pixel ($t0, $t1, $t2)          # draw the fourth pixel
    subi $t0, $t0, 1                    # decrement the x-coordinate by one pixel
    draw_pixel ($t0, $t1, $t2)          # draw the third pixel
    subi $t0, $t0, 2                    # decrement the x-coordinate to the first pixel
    
    draw_main_shadow:
        draw_pixel ($t0, $t1, $t2)      # draw the first pixel
        addi $t0, $t0, 1                # increment the x-coordinate by one pixel
        draw_pixel ($t0, $t1, $t2)      # draw the second pixel
            
    drop_shadow_done:
        lw $t3, 0($sp)          # restore the original $t3 value
        lw $t2, 4($sp)          # restore the original $t2 value
        lw $t1, 8($sp)          # restore the original $t1 value
        lw $t0, 12($sp)         # restore the original $t0 value
        addi $sp, $sp, 16       # free space used by the four registers    
.end_macro

.macro is_paused ()
    # returns 0 or 1 in $v0 if the game is currently paused
    
    addi $sp, $sp, -8           # allocate space for two registers on the stack
    sw $t0, 4($sp)              # save $t0 to the stack
    sw $t1, 0($sp)              # save $t1 to the stack
    
    la $t0, PAUSE_STATE         # fetch the address of the pause state in memory
    lw $t1, 0($t0)              # extract the pause state
    
    beq $t1, 0, not_paused          # if not paused, return
    
    li $t1, 1                       # else, load the code for paused, one
    move $v0, $t1                   # move the code into the variable return register
    j pause_done                    # exit the macro
    
    not_paused:
        move $v0, $zero             # move the code for not paused into the variable return register
        
    pause_done:
        lw $t1, 0($sp)              # restore the original value of $t0
        lw $t0, 4($sp)              # restore the original value of $t1
        addi $sp, $sp, 8            # deallocate the space on the stack
.end_macro

.macro save_ra ()
    # saves the current return address in $ra to the stack, for when there are nested helper labels
    
    addi $sp, $sp, -4       # allocate space on the stack
    sw $ra, 0($sp)          # store the original $ra of main on the stack
.end_macro

.macro load_ra ()
    # loads the most recently saved return address back into $ra from the stack
    
    lw $ra, 0($sp)          # restore the original address
    addi $sp, $sp, 4        # deallocate the space on the stack
.end_macro


##############################################################################
# Main Game Code
##############################################################################

# Run the game.
main:
    # Initialize the game
    
    jal set_game_mode               # prompts the user to set a game mode
    
    set_defaults ()                 # set all default values for the game
    jal initialize_game             # initialize the game with static drawings
    new_saved_capsule ()            # initializes the first stored capsule
    j start_new_level               # initialize a new level with starting difficulty and mode


game_loop:
    
    # 0.5: Pre-round checks
    jal virus_animation                 # animates the viruses
    
    # 1a. Check if key has been pressed
    lw $t0, ADDR_KBRD                   # load the base address for the keyboard
    lw $t1, 0($t0)                      # load the first word from the keyboard: flag
    beq $t1, 0, check_timer             # if a word was not detected, induce gravity
    remove_shadow ()                    # erase the current drop-shadow
    
    beq $t1, 0, finish_game_loop        # if a word was not detected, skip handling of the input

    # 1b. Check which key has been pressed
    keyboard_input:
        lw $t0, 4($t0)              # load in the second word from the keyboard: actual input value
        beq $t0, 0x71, Q_pressed    # user pressed Q: quit the program
        beq $t0, 0x70, P_pressed    # user pressed P: pause the program
        
        is_paused()                     # evaluates if the game is paused; if yes, display pause icon
        beq $v0, 1, draw_pause_icon     # if paused, continue to display to pause icon
        
    	# 2a. Check for collisions, 2b. Update locations (capsules), # 3. Draw the screen
    	beq $t0, 0x77, W_pressed    # rotate capsule 90 degrees clockwise
        beq $t0, 0x61, A_pressed    # move capsule left
        beq $t0, 0x73, S_pressed    # move capsule down
        beq $t0, 0x64, D_pressed    # move capsule to the right
        
    update_playing_area:
        jal check_rows            # checks for any matching blocks in rows and removes them
        jal check_columns         # checks for any matching blocks in columns and removes them
    
    finish_game_loop:
        jal is_level_completed          # checks to see if the level is completed: all viruses removed
        drop_shadow ()                  # draws the drop-shadow for the current capsule position
    
    	# 4. Sleep
    	li $v0, 32         # load the syscall code for delay
    	li $a0, 15         # specify a delay of 15 ms (60 updates/second)
    	syscall            # invoke the syscall
    
        # 5. Go back to Step 1
        j game_loop
        
        

##############################################################################
# Level Completion
##############################################################################

start_new_level:
    # starts a new level based on current (updated) game level
    
    jal clear_playing_area      # clear the bitmap display and game memory
    jal new_viruses             # generate viruses based on updated game difficulty
    jal set_gravity             # set gravity speed based on updated game difficulty
    jal display_level           # displays the current level on the display
    new_capsule ()              # generate a new capsule based on the current saved capsule
    new_saved_capsule ()        # generate a new saved capsule, the next capsule
    j game_loop                 # begin the game loop
     
     
is_level_completed:
    # evaluates if all viruses were removed; if so, start a new level, increasing
    # the game difficulty to a max of five
    
    lw $t0, NUM_VIRUS               # fetch the current number of viruses
    bne $t0, $zero, ra_hop          # if viruses remain, return to the game loop
    
    la $t0, GAME_LEVEL              # fetch the address of the current game level
    lw $t1, 0($t0)                  # extract the current game difficulty
    beq $t1, 5, start_new_level     # if already max level, don't increment anything
    
    addi $t1, $t1, 1                # else, increment to the next game difficulty
    sw $t1, 0($t0)                  # save the game difficulty to memory
    
    la $t0, GRAVITY_SPEED           # fetch the address of the current game speed
    lw $t1, 0($t0)                  # extract the current game speed
    
    j start_new_level               # start a new level with the updated level
        

clear_playing_area:
    # clears the bitmap display and game memory
    
    save_ra ()                  # nested label jumps, save the original return address
    
    lw $t2, BLACK               # fetch the colour black
    li $t1, 18                  # initialize the starting y-coordinate
    
    clear_for_y:
        beq $t1, 58, clear_done     # if the for-loops are complete, exit the loop
        li $t0, 6                   # initialize the starting x-coordinate
        
        clear_for_x:
            beq $t0, 30, clear_next_y       # if the for-loop completes, iterate to the next y-coordinate   
            
            draw_square ($t0, $t1, $t2)     # draw the current block in the bitmap display black
            remove_info ($t0, $t1)          # remove the current pixel's information in the game memory
            
            addi $t0, $t0, 2    # increment the x-coordinate by two
            j clear_for_x       # continue the for-loop
            
    clear_next_y:
        addi $t1, $t1, 2        # increment the y-coordinate by two
        j clear_for_y           # continue the for-loop
        
    clear_done:
        jal display_level       # redraw the level display
        load_ra ()              # fetch the original return address
        jr $ra                  # return
        
        
##############################################################################
# Gravity
##############################################################################

set_gravity:
    # sets the gravity speed based on game difficulty and level
    
    la $t0, GRAVITY_SPEED           # fetch the address of the gravity speed
    li $t1, 2050                    # initialize the starting value to 2000 msss
    
    lw $t2, GAME_MODE               # fetch the current game mode
    mul $t2, $t2, 500               # game mode changes the base speed by a multiplier of 500
    
    lw $t3, GAME_LEVEL              # fetch the current game level
    mul $t3, $t3, 75                # game level changes the speed by a multiplier of 75
    add $t2, $t2, $t3               # add both multipliers together
    sub $t1, $t1, $t2               # subtract the starting speed by the multipliers
    
    sw $t1, 0($t0)                  # save the speed to memory
    jr $ra                          # return to the original calling address

check_timer:
    # checks the global clock to see if gravity should be induced
    
    is_paused()                     # evaluates if the game is paused; if yes, display pause icon
    beq $v0, 1, finish_game_loop    # if paused, do not induce gravity

    la $t0, GRAVITY_TIMER           # fetch the address of the gravity timer
    lw $t1, 0($t0)                  # extract its value
    addi $t1, $t1, 15               # increment by 15 ms
    sw $t1, 0($t0)                  # increment the gravity timer
    
    lw $t2, GRAVITY_SPEED               # fetch the current gravity speed
    blt $t1, $t2, finish_game_loop      # if not enough time has passed, continue to game loop
    
    li $t2, 0                           # else, enough time has passed to induce gravity, load zero
    sw $t2, 0($t0)                      # reset the gravity timer
    j S_pressed                         # simulate auto-drop
    
    
##############################################################################
# Virus Animation
##############################################################################
virus_animation:
    # every second, viruses will be animated to twinkle
    
    la $t0, VIRUS_ANIMATION_TIMER       # fetch the address of the virus animation timer
    lw $t1, 0($t0)                      # extract its value
    addi $t1, $t1, 15                   # increment its value by 15 ms
    sw $t1, 0($t0)                      # save the value into memory
    
    li $t2, 750                        # load 1000 ms
    blt $t1, $t2, ra_hop                # if not enough time has passed, return
    li $t2, 0                           # else, enough time has passed to twinkle
    sw $t2, 0($t0)                      # reset the animation timer
    
    li $t8, 30                          # initialize max x-coordinate + 2
    li $t9, 58                          # initialize max y-coordinate + 2
    
    li $t1, 18                          # initialize the starting y-coordinate
    
    virus_for_y:
        beq $t1, $t9, ra_hop            # all pixels checked, return to game loop
        li $t0, 6                       # initialize the starting x-coordinate
        
        virus_for_x:
            beq $t0, $t8, virus_next_y
            
            get_memory_pixel ($t0, $t1)         # fetch the address of the pixel in memory
            lb $t2, 0($v0)                      # fetch the block type code from memory
            
            beq $t2, 2, animate_virus           # if a virus was found, animate it
    
        virus_next_x:
            addi $t0, $t0, 2            # iterate to the next x-coordinate
            j virus_for_x               # continue the x for-loop
    virus_next_y:
        addi $t1, $t1, 2                # iterate to the next y-coordinate
        j virus_for_y                   # continue the y for-loop
        
    animate_virus:
        move $t2, $t0                   # initialize a temporary x-coordinate
        move $t3, $t1                   # initialize a temporary y-coordinate
        
        get_pixel ($t2, $t3)            # fetch the address of the current pixel
        lw $t4, 0($v0)                  # extract the colour of the first pixel
        addi $t2, $t2, 1                # increment to the next pixel
        get_pixel ($t2, $t3)            # fetch the address of the next pixel
        lw $t5, 0($v0)                  # extract the colour of the next pixel
        
        sw $t4, 0($v0)                  # colour the top right the original colour
        sw $t5, -4($v0)                 # colour the top left the alt colour
        sw $t5, 256($v0)                # colour the bottom right the alt colour
        sw $t4, 252($v0)                # colour the bottom left the original colour
        
        j virus_next_x                  # continue the x for-loop
        
##############################################################################
# Match Checking
##############################################################################

reset_consequtive:
    li $t6, 1           # set the current consequtive number of blocks to one
    move $t8, $t0       # set the x-coordinate to the current position
    move $t9, $t1       # set the y-coordinate to the current position
    jr $ra              # return to the for-loops  
    
check_rows:
    # checks for any matching blocks in each row and removes them
    
    # $t0: x-coordinate
    # $t1: y-coordinate
    # $t2: black
    # $t3: current colour
    # $t4: max x
    # $t5: max y
    # $t6: num consequtive
    # $t7: current consequtive colour
    # $t8: start of colour x-coordinate
    # $t9: start of colour y-coordinate
    # $s7: min num of blocks per row - 1
    
    save_ra ()          # there are nested jumps, save the original return address
    
    lw $t2, BLACK       # load the colour black
    li $t4, 32          # load the maximum x-coordinate + 4 (to not clip off last pixel)
    li $t5, 58          # load the maximum y-coordinate
    
    rows_loops:
        li $t1, 18          # initialize y-coordinate to the playing area offset
        
        rows_for_y:
            beq $t1, $t5, rows_end_loops     # if for-loop is done, row match checking is completed
        
            li $t0, 6                       # initialize x-coordinate to the playing area offset
            jal reset_consequtive           # reset consequtive coordinates to the current position
            move $t7, $t2                   # set the current consequtive colour to black by default
        
            rows_for_x:
                beq $t0, $t4, rows_next_y       # if for-loop is done, iterate to next y-coordinate in for-loop
                
                get_pixel ($t0, $t1)            # fetch the address of the current pixel (represents the block)
                lw $t3, 0($v0)                  # extract its colour
                
                beq $t3, $t2, rows_found_black      # if its black, skip to next iteration of the for loop
                
                compare_colours ($t7, $t3)          # compare the current pixels colour to the current consequtive
                beq $v0, 0, rows_diff_colour        # if the current colour is different
                
                addi $t6, $t6, 1                # else, same colour, increment the number of consequtive blocks
                j rows_next_x                   # continue to the next iteration of the for-loop
            
                rows_diff_colour:
                    bgt $t6, $s7, rows_remove_match     # if a valid matching is found, remove it
                    jal reset_consequtive               # else, reset consequtive information to the current pixel
                    move $t7, $t3                       # set the consequtive colour to the current pixel
                    j rows_next_x                       # continue to the next iteration of the for-loop
                    
                rows_found_black:
                    bgt $t6, $s7, rows_remove_match     # if a valid matching is found, remove it
                    jal reset_consequtive               # reset consequtive information to the current pixel
                    move $t7, $t2                       # set the current consequtive colour to black
                    j rows_next_x                       # continue to the next iteration of the for-loop
                    
            rows_next_x:
                addi $t0, $t0, 2                # increment the x-coordinate
                j rows_for_x                    # return to the for-loop
            
        rows_next_y:
            addi $t1, $t1, 2                    # increment the y-coordinate
            j rows_for_y                        # return to the for-loop
    
        rows_remove_match:
            rows_match_loop:
                beq $t8, $t0, rows_end_match_loop   # once all of the match is removed, move on
                draw_square ($t8, $t9, $t2)         # remove the block at the current coordinates
                remove_info ($t8, $t9)              # remove the block's information stored in the game memory
                addi $t8, $t8, 2                    # increment to the next block
                jal animation_delay                 # sleep for one second to create an animation delay
                j rows_match_loop
                
            rows_end_match_loop: 
                addi $sp, $sp, 4            # original address isn't needed, deallocate its space on the stack
                j collapse_playing_area     # collapses any blocks after removing the matching and recheck everything
            
    rows_end_loops:
        load_ra ()          # restore the original return address
        jr $ra              # return to the original call
            

check_columns:
    # checks for any matching blocks in each column and removes them
    # exact same logic as rows, comments omitted and code compressed
    
    save_ra ()
   
    lw $t2, BLACK
    li $t4, 30          
    li $t5, 60  
    
    columns_loops:
        li $t0, 6
        columns_for_x:
            beq $t0, $t4, columns_end_loops
            li $t1, 18
            jal reset_consequtive
            move $t7, $t2
            columns_for_y:
                beq $t1, $t5, columns_next_x
                
                get_pixel ($t0, $t1)
                lw $t3, 0($v0)
                
                beq $t3, $t2, columns_found_black
                
                compare_colours ($t7, $t3)
                beq $v0, 0, columns_diff_colour
                
                addi $t6, $t6, 1
                j columns_next_y
                
                columns_diff_colour:
                    bgt $t6, $s7, columns_remove_match
                    jal reset_consequtive
                    move $t7, $t3
                    j columns_next_y
                    
                columns_found_black:
                    bgt $t6, $s7, columns_remove_match
                    jal reset_consequtive
                    move $t7, $t2
                    j columns_next_y
                    
                columns_next_y:
                    addi $t1, $t1, 2
                    j columns_for_y
                    
            columns_next_x:
                addi $t0, $t0, 2
                j columns_for_x
                
        columns_remove_match:
            columns_match_loop:
                beq $t9, $t1, columns_end_match_loop
                draw_square ($t8, $t9, $t2)
                remove_info ($t8, $t9)
                addi $t9, $t9, 2
                jal animation_delay                 # sleep for one second to create an animation delay
                j columns_match_loop
            columns_end_match_loop: 
                addi $sp, $sp, 4
                j collapse_playing_area
    columns_end_loops:
        load_ra ()
        jr $ra
        
    
    
##############################################################################
# Collapse Blocks 
##############################################################################

collapse_playing_area:
# after blocks are removed, collapse any blocks down the playing area

    # $t0: current x-coordinate
    # $t1: current y-coordinate
    # $t2: curr colour
    # $t3: black
    # $t4: max x-coordinate
    # $t5: max y-coordinate
    # $t6: block info
    # $t7: temporary multipurpose

    lw $t3, BLACK                       # load the colour black
    li $t4, 30                          # initialize the maximum x-coordinate
    li $t5, 26                          # initialize the maximum y-coordinate
    
    collapse_loops:
    li $t1, 54                      # initialize the starting y-coordinate to the playing area offset
    
    collapse_for_y:
        blt $t1, $t5, collapse_end_loops        # if for-loop is done, collapsing the playing area is complete
        li $t0, 6                               # initialize the starting x-coordinate to the playing area offset
        
        collapse_for_x:
            bgt $t0, $t4, collapse_next_y       # if for-loop is done, iterate to next row
            
            get_pixel ($t0, $t1)                # fetch the address of the current pixel
            lw $t2, 0($v0)                      # fetch the colour of the current pixel
            beq $t2, $t3, collapse_next_x       # if the block is black, skip to next iteration of the for-loop
            
            lw $t2, 512($v0)                    # block is not black; fetch the address of the block below it
            beq $t2, $t3, collapse_block        # if black, collapse the block down
            j collapse_next_x                   # else, supported; move on to next block
        
        collapse_next_x:
            addi $t0, $t0, 2        # increment to the next x-coordinate
            j collapse_for_x        # continue the for-loop
            
    collapse_next_y:
        subi $t1, $t1, 2            # increment to the next y-coordinate
        j collapse_for_y            # continue the for-loop
        
    collapse_block:
        get_info ($t0, $t1)                 # fetch the accessory information about the current block 
        move $t6, $v0                       # fetch the block type
        beq $t6, 2, collapse_next_x         # if a virus, skip to the next iteration of the for-loop
        
        move $t6, $v1                       # else, a capsule; fetch its orientation
        
        beq $t6, 0, collapse_direct         # if capsule half is not connected to another half
        beq $t6, 2, collapse_right          # if the current block is connected to 
        beq $t6, 3, collapse_up             # if the current block is connect
        
        j collapse_next_x                   # else, skip the block
        
        collapse_direct:
            move_square ($t0, $t1, 4)           # move the current block down
            move_info_down ($t0, $t1)           # move the game memory information for the current block down
            jal animation_delay                 # sleep for one second to create an animation delay
            j collapse_loops                    # finished moving the main block down, restart the full looping process
            
        collapse_right:
            get_pixel ($t0, $t1)                # fetch the address of the current pixel
            lw $t2, 520($v0)                    # fetch the colour of the block below and to the right
            bne $t2, $t3, collapse_next_x       # second capsule half is supported, return to next for-loop iteration
            
            move_square ($t0, $t1, 4)           # else, move the current block down
            move_info_down ($t0, $t1)           # move the game memory information for the current block down
            addi $t0, $t0, 2                    # move the x-coordinate to the next capsule half
            j collapse_direct                   # move the next half down and move on
    
        collapse_up:
            move_square ($t0, $t1, 4)       # move the current block down
            move_info_down ($t0, $t1)       # move the game memory information for the current block down
            subi $t1, $t1, 2                # move the y-coordinate up to the next capsule half
            j collapse_direct               # move the next half down and move on
        
    collapse_end_loops:
        j update_playing_area                        # restart the collapsing process
        
        
        
##############################################################################
# Collision Checking
##############################################################################


Q_pressed:
    # quits the game
    
    li $v0, 10          # load the syscall code for quitting the program
    syscall              # invoke the syscall
   
P_pressed:
    # pauses or unpauses the game based on the current paused state
    
    la $t0, PAUSE_STATE                 # fetch the address of the pause state
    lw $t1, 0($t0)                      # extract its value
    beq $t1, 0, toggle_pause_on         # if off, turn it on
    
    j toggle_pause_off                  # else, its on; turn it off
    
    toggle_pause_on:
        li $t1, 1                           # load one, value for toggled on
        sw $t1, 0($t0)                      # turn the toggle off
        jal draw_pause_icon                 # overlay the pause icon
        j finish_game_loop                  # return to the game loop, pause
        
    toggle_pause_off:
        sw $zero, 0($t0)                    # turn the toggle state off
        jal erase_pause_icon                # remove the pause icon
        j finish_game_loop                  # return to the game loop, unpause
        
   
W_pressed:
    # collision check for a potential 90 degree rotation of the current capsule
    
    lw $t3, BLACK                   # fetch the colour black
    
    beq $s2, 1, W_vertical          # check for a vertical capsule
    beq $s2, 2, W_horizontal        # check for a horizontal capsule
    
    W_vertical:
        add $t0, $s0, $s6            # check the pixel to the right of the first half
        get_pixel ($t0, $s1)        # fetch the address of the pixel
        lw $t2, 0($v0)              # fetch the colour of the pixel
        beq $t3, $t2, move_W        # if no pixel to the right, then no collision
        sub $t0, $s0, $s6            # else, check the pixel to the right of the first half
        get_pixel ($t0, $s1)        # fetch the address of the pixel
        lw $t2, 0($v0)              # fetch the colour of the pixel
        bne $t3, $t2, move_done     # if there is a collision, check if the game is over
        move_capsule (1)            # else, move the capsule left
        subi $s0, $s0, 2            # update the current capsule's position records
        j move_W                    # then rotate the capsule
        
    W_horizontal:
        add $t1, $s1, $s6            # check the pixel below the first half
        get_pixel ($s0, $t1)        # fetch the address of the pixel
        lw $t2, 0($v0)              # fetch the colour of the pixel
        beq $t3, $t2, move_W        # if no pixel to the right, then no collision
        j move_done                 # else, check if the game is over

A_pressed:
    # collision check for a potential movement left of the current capsule
    
    lw $t2, BLACK                           # fetch the colour black
    
    sub $t0, $s0, $s6                        # check the pixel left of the first half
    get_pixel ($t0, $s1)                    # fetch the address of the pixel
    lw $t3, 0($v0)                          # fetch the colour of the pixel
    bne $t3, $t2, move_done                 # if first half collides, return to game loop

    beq $s2, 1, A_vertical                  # if vertical, must check pixel left of the second half
    beq $s2, 2, move_A                      # if horizontal, collision check is complete
    
    A_vertical:
        add $t1, $s1, $s6                       # check the pixel left of the second half
        get_pixel ($t0, $t1)                    # fetch the address of the pixel
        lw $t3, 0($v0)                          # fetch the colour of the pixel
        beq $t3, $t2, move_A                    # if no pixel to the left, then no collision
        j move_done                             # else, move is done, check if the game is over

S_pressed:
    # collision check for a potential movement down of the current capsule
    
    lw $t2, BLACK                           # fetch the colour black
    
    beq $s2, 1, S_vertical                  # check for a vertical capsule
    beq $s2, 2, S_horizontal                # check for a horizontal capsule
    
    S_vertical:
        addi $t1, $s1, 4                    # check the pixel below the second half
        get_pixel ($s0, $t1)                # fetch the address of the pixel
        lw $t3, 0($v0)                      # fetch the colour of the pixel
        beq $t3, $t2, move_S                # if no pixel below, then no collision
        j move_done                         # else, move is done, check if the game is over
        
    S_horizontal:
        add $t1, $s1, $s6                    # check the pixel below the first half
        get_pixel ($s0, $t1)                # fetch the address of the pixel
        lw $t3, 0($v0)                      # fetch the colour of the pixel
        bne $t3, $t2, move_done             # if first half collides, return to game loop
        add $t0, $s0, $s6                    # check the pixel below the second half
        get_pixel ($t0, $t1)                # fetch the address of the pixel
        lw $t3, 0($v0)                      # fetch the colour of the pixel
        beq $t3, $t2, move_S                # if no pixel below, then no collision
        j move_done                         # else, move is done, check if the game is over

D_pressed:
    # collision check for a potential movement right of the current capsule
    
    lw $t2, BLACK                           # fetch the colour black
    
    beq $s2, 1, D_vertical                  # if vertical, must check pixel right of the second half
    beq $s2, 2, D_horizontal                # if horizontal, collision check is complete
        
    D_vertical:
        add $t0, $s0, $s6                       # check the pixel right of the first half
        get_pixel ($t0, $s1)                    # fetch the address of the pixel
        lw $t3, 0($v0)                          # fetch the colour of the pixel
        bne $t3, $t2, move_done                 # if first half collides, return to game loop
        add $t1, $s1, $s6                       # check the pixel right of the second half
        get_pixel ($t0, $t1)                    # fetch the address of the pixel
        lw $t3, 0($v0)                          # fetch the colour of the pixel
        beq $t3, $t2, move_D                    # if no pixel to the left, then no collision
        j move_done                             # else, move is done, check if the game is over
        
    D_horizontal:
        addi $t0, $s0, 4                        # check the pixel right of the second half
        get_pixel ($t0, $s1)                    # fetch the address of the pixel
        lw $t3, 0($v0)                          # fetch the colour of the pixel
        beq $t3, $t2, move_D                    # no collision, move right
        j move_done                             # else, move is done, check if the game is over
    
    
    
##############################################################################
# Capsule Movement
##############################################################################

move_W:
    # assuming no collision will occur, rotate the capsule 90 degrees clockwise
    
    beq $s2, 1, rotate_vertical             # if the capsule is vertical, rotate to horizontal
    beq $s2, 2, rotate_horizontal           # if the capsule is horizontal, rotate to vertical
    
    rotate_horizontal:
        move_square ($s0, $s1, 4)           # move the first half of the capsule down
        add $t0, $s0, $s6                   # the second half is to the right of the original position
        move_square ($t0, $s1, 1)           # move the second half of teh capsule left
        li $s2, 1                           # set the capsule's orientation to vertical
        j w_pressed_done
    
    rotate_vertical:
        get_pixel ($s0, $s1)                # fetch the address of the first half
        lw $t3, 0($v0)                      # extract the colour of the original half
        
        add $t1, $s1, $s6                   # the second half of the capsule is below the first half
        move_square ($s0, $t1, 3)           # move the capsule's second half up over the first half
        move_square ($s0, $s1, 2)           # move the capsule's second half up
        
        draw_square ($s0, $s1, $t3)         # draw the original first half
        li $s2, 2                           # set the capsule's orientation to horizontal
        j w_pressed_done                    # return back to main
        
    w_pressed_done: j finish_game_loop      # return back to the game loop

move_A:
    # assuming no collision will occur, move the capsule to the left
    move_capsule (1)            # move the capsule left
    sub $s0, $s0, $s6            # update the x-coordinate
    j finish_game_loop        # return back to the game loop

move_S:
    # assuming no collisions will occur, move the capsule down
    move_capsule (4)            # move the capsule down
    add $s1, $s1, $s6           # update the y-coordinate
    j finish_game_loop          # return back to the game loop
    
move_D:
    # assuming no collision will occur, move the capsule to the right
    move_capsule (2)            # move the capsue right
    add $s0, $s0, $s6           # update the x-coordinate
    j finish_game_loop          # return back to the game loop


##############################################################################
# Game and Round Status
##############################################################################

move_done:
    # called upon a move finding a collision, check if game is over, else generate new capsule
    # and return to the game loop (starting a new round)
    
    lw $t2, BLACK                           # fetch the colour black
        
    beq $s2, 1, round_vertical                  # check for a vertical capsule
    beq $s2, 2, round_horizontal                # check for a horizontal capsule
    
    round_vertical:
        addi $t1, $s1, 4                        # check the pixel below the second half
        get_pixel ($s0, $t1)                    # fetch the address of the pixel
        lw $t3, 0($v0)                          # fetch the colour of the pixel
        beq $t3, $t2, finish_game_loop          # if no pixel below, then no collision
        j is_game_over                          # else, move is done, check if the game is over
        
    round_horizontal:
        add $t1, $s1, $s6                        # check the pixel below the first half
        get_pixel ($s0, $t1)                    # fetch the address of the pixel
        lw $t3, 0($v0)                          # fetch the colour of the pixel
        bne $t3, $t2, is_game_over              # if first half collides, check if the game is over
        add $t0, $s0, $s6                        # check the pixel below the second half
        get_pixel ($t0, $t1)                    # fetch the address of the pixel
        lw $t3, 0($v0)                          # fetch the colour of the pixel
        beq $t3, $t2, finish_game_loop          # if no pixel below, then no collision
        j is_game_over                          # else, move is done, check if the game is over
    
    is_game_over:
        li $t0, 16              # load the starting x-coordinate of the capsule
        li $t1, 16              # load the starting y-coordinate of the capsule
        
        bne $t0, $s0, start_new_round       # if the x-coordinate doesn't match 
        bne $t1, $s1, start_new_round       # if the y-coordinate doesn't match
    
        j Q_pressed             # capsule collided at the start position, quit the game

start_new_round:
    save_info ()                # save the information about the current capsule to game memory
    new_capsule ()              # generate a new capsule and start a new round
    j update_playing_area       # check to see if any matches were made


##############################################################################
# Virus Generation
##############################################################################

new_viruses:
    # generates new viruses according to game difficulty and game mode
    
    lw $t8, GAME_LEVEL              # fetch the game level
    lw $t9, GAME_MODE               # fetch the game mode
    
    mul $t9, $t9, 2                 # multiply the game difficulty by two
    add $t9, $t9, $t8               # add the game difficulty
    
    addi $t9, $t9, 1                # base number of viruses is four, offset for difficulty and mode 1
    
    li $t8, 0                       # initialize a counter
    
    new_viruses_loop:
        beq $t8, $t9, ra_hop        # once all viruses are generated, return to the game loop
        generate_virus ()           # call a macro that generates the viruses
        addi $t8, $t8, 1            # increment the counter by one
        j new_viruses_loop          # continue the for-loop
    


##############################################################################
# Static Scene Initialization
##############################################################################

initialize_game:
    # draws the initial static scene
    
    save_ra ()              # there are nested helper labels, save the original return address
    
    # draw the box around the saved capsule
    lw $t2, BOTTLE_BLUE
    draw_line (34, 18, 39, 18, $t2, 2)
    draw_line (34, 18, 34, 25, $t2, 1)
    draw_line (39, 18, 39, 25, $t2, 1)
    draw_line (34, 25, 39, 25, $t2, 2)
    
    lw $t2, BOTTLE_BLUE
    draw_line (4, 17, 4, 58, $t2, 1)    # left outer wall
    lw $t2, WHITE
    draw_line (5, 17, 5, 58, $t2, 1)    # left inner wall
    
    lw $t2, BOTTLE_BLUE
    draw_line (31, 17, 31, 58, $t2, 1)  # right outer wall
    lw $t2, WHITE
    draw_line (30, 17, 30, 58, $t2, 1)  # right inner wall
    
    lw $t2, BOTTLE_BLUE
    draw_line (5, 16, 12, 16, $t2, 2)   # top horizontal left outer wall
    lw $t2, WHITE
    draw_line (5, 17, 13, 17, $t2, 2)   # top horizontal left inner wall
    
    lw $t2, BOTTLE_BLUE
    draw_line (23, 16, 30, 16, $t2, 2)  # top horizontal right outer wall
    lw $t2, WHITE
    draw_line (22, 17, 29, 17, $t2, 2)  # top horizontal right inner wall
    
    lw $t2, BOTTLE_BLUE
    draw_line (5, 59, 30, 59, $t2, 2)   # bottom outer wall
    lw $t2, WHITE
    draw_line (6, 58, 29, 58, $t2, 2)  # bottom inner wall
    
    lw $t2, BOTTLE_BLUE
    draw_line (12, 12, 12, 15, $t2, 1)       # left lower mouth outer wall
    lw $t2, WHITE
    draw_line (13, 12, 13, 16, $t2, 1)       # left lower mouth inner wall
    
    lw $t2, BOTTLE_BLUE
    draw_line (22, 12, 22, 16, $t2, 1)       # right lower mouth outer wall
    lw $t2, WHITE
    draw_line (21, 12, 21, 17, $t2, 1)       # right lower mouth inner wall
    
    lw $t2, BOTTLE_BLUE
    draw_line (11, 9, 12, 11, $t2, 1)        # left upper mouth outer wall
    lw $t2, WHITE
    draw_line (12, 9, 12, 11, $t2, 1)        # left upper mouth inner wall
    
    lw $t2, BOTTLE_BLUE
    draw_line (23, 9, 23, 11, $t2, 1)        # right upper mouth outer wall
    lw $t2, WHITE
    draw_line (22, 9, 22, 11, $t2, 1)        # right upper mouth inner wall
    
    load_ra ()              # fetch the original return address
    jr $ra                  # return back to main
            
##############################################################################
# Game Mode Selection
##############################################################################

set_game_mode:
    # prompts the user to select a gamemode
    
    save_ra ()          # save the original return address
    
    lw $t2, WHITE       # load the colour white
    jal draw_select     # draw 'game mode' as the title
    jal draw_medium     # draw the medium mode
    jal draw_hard       # draw the hard mode
    
    lw $t2, RED         # load the colour red
    jal draw_easy       # draw the easy mode
    li $t9, 1           # load 1 (easy) as the currently selected mode
    
game_mode_loop:

    lw $t0, ADDR_KBRD                   # load the base address for the keyboard
    lw $t1, 0($t0)                      # load the first word from the keyboard: flag
    beq $t1, 0, game_mode_loop          # if nothing was detected, repeat the loop
    
    lw $t0, 4($t0)                      # load in the second word from the keyboard: actual input value
    beq $t0, 0x61, select_down          # user pressed S: move down a selection
    beq $t0, 0x77, select_up            # user pressed S: move down a selection
    beq $t0, 0x20, select_mode          # user pressed S: move down a selection
    
    select_down:
        lw $t2, WHITE                   # load the colour white
        
        beq $t9, 3, game_mode_loop      # if already the lowest selection, return
        beq $t9, 1, move_down_medium    # if easy, move down to medium
        beq $t9, 2, move_down_hard      # if medium, move down to hard
        
        move_down_medium:
            jal draw_easy               # draw easy mode over as white
            lw $t2, RED                 # load the colour red
            jal draw_medium             # draw medium mode over as red
            li $t9, 2                   # set the currently selected mode to medium
            j game_mode_loop            # return to the loop until a mode is selected
            
        move_down_hard:
            jal draw_medium             # draw medium mode over as white
            lw $t2, RED                 # load the colour red
            jal draw_hard               # draw hard mode over as red
            li $t9, 3                   # set the currently selected mode to hard
            j game_mode_loop            # return to the loop until a mode is selected
            
    select_up:
        lw $t2, WHITE                   # load the colour white
        
        beq $t9, 1, game_mode_loop      # if already the highest selection, return
        beq $t9, 2, move_up_easy        # if medium, move up to easy
        beq $t9, 3, move_up_medium      # if hard, move up to easy
        
        move_up_easy:
            jal draw_medium             # draw medium mode over as white
            lw $t2, RED                 # load the colour red
            jal draw_easy               # draw easy mode over as red
            li $t9, 1                   # set the currently selected mode to easy
            j game_mode_loop            # return to the loop until a mode is selected
        move_up_medium:
            jal draw_hard               # draw hard mode over as white
            lw $t2, RED                 # load the colour red
            jal draw_medium             # draw medium mode over as white
            li $t9, 2                   # set the currently selected mode to medium
            j game_mode_loop            # return to the loop until a mode is selected
    select_mode:
        la $t0, GAME_MODE               # fetch the address of game mode in memory
        sw $t9, 0($t0)                  # save the selected game mode to memory
        jal reset_display               # clears the display to black
        load_ra ()                      # fetch the original return address
        jr $ra                          # return to game initialization

draw_selection_screen:
    # draws the gamemode selection screen
    
    draw_select:
        # draws the title
        
        draw_line (3, 3, 3, 9, $t2, 1)  # G
        draw_line (4, 3, 7, 3, $t2, 2)
        draw_coordinates (7, 4, $t2)
        draw_line (3, 9, 7, 9, $t2, 2)
        draw_line (7, 6, 7, 8, $t2, 1)
        draw_line (5, 6, 6, 6, $t2, 2)
        
        draw_line (10, 3, 10, 9, $t2, 1)    # A
        draw_line (11, 3, 14, 3, $t2, 2)
        draw_line (14, 3, 14, 9, $t2, 1)
        draw_line (11, 6, 13, 6, $t2, 2)
        
        draw_line (17, 3, 17, 9, $t2, 1)    # M
        draw_line (21, 3, 21, 9, $t2, 1)
        draw_coordinates (18, 4, $t2)
        draw_coordinates (19, 5, $t2)
        draw_coordinates (20, 4, $t2)
        
        draw_line (24, 3, 24, 9, $t2, 1)    # E
        draw_line (25, 3, 28, 3, $t2, 2)
        draw_line (25, 6, 28, 6, $t2, 2)
        draw_line (25, 9, 28, 9, $t2, 2)
        
        
        draw_line (35, 3, 35, 9, $t2, 1)    # M
        draw_line (39, 3, 39, 9, $t2, 1)
        draw_coordinates (36, 4, $t2)
        draw_coordinates (37, 5, $t2)
        draw_coordinates (38, 4, $t2)
        
        draw_line (43, 3, 45, 3, $t2, 2)    # O
        draw_line (43, 9, 45, 9, $t2, 2)
        draw_line (42, 4, 42, 8, $t2, 1)
        draw_line (46, 4, 46, 8, $t2, 1)
        
        draw_line (49, 3, 52, 3, $t2, 2)    # D
        draw_line (53, 4, 53, 8, $t2, 1)
        draw_line (49, 9, 52, 9, $t2, 2)
        draw_line (49, 3, 49, 9, $t2, 1)

        draw_line (56, 3, 56, 9, $t2, 1)    # E
        draw_line (56, 3, 60, 3, $t2, 2)
        draw_line (56, 6, 60, 6, $t2, 2)
        draw_line (56, 9, 60, 9, $t2, 2)
    
        jr $ra      # return to set_game_mode
        
    draw_easy:
        draw_line (10, 16, 10, 21, $t2, 1)    # E
        draw_line (10, 16, 14, 16, $t2, 2)
        draw_line (10, 19, 14, 19, $t2, 2)
        draw_line (10, 22, 14, 22, $t2, 2)
        
        draw_line (17, 16, 17, 22, $t2, 1)    # A
        draw_line (17, 16, 21, 16, $t2, 2)
        draw_line (21, 16, 21, 22, $t2, 1)
        draw_line (17, 19, 21, 19, $t2, 2)
        
        draw_line (24, 16, 28, 16, $t2, 2)  # S
        draw_line (24, 16, 24, 19, $t2, 1)
        draw_line (24, 19, 28, 19, $t2, 2)
        draw_line (28, 19, 28, 21, $t2, 1)
        draw_line (24, 22, 28, 22, $t2, 2)
        
        draw_line (31, 16, 31, 18, $t2, 1)  # Y
        draw_line (35, 16, 35, 18, $t2, 1)
        draw_coordinates (32, 19, $t2)
        draw_coordinates (34, 19, $t2)
        draw_line (33, 20, 33, 22, $t2, 1)
        
        jr $ra      # return to set_game_mode
        
    draw_medium:
        draw_line (10, 28, 10, 34, $t2, 1)    # M
        draw_line (14, 28, 14, 34, $t2, 1)
        draw_coordinates (11, 29, $t2)
        draw_coordinates (12, 30, $t2)
        draw_coordinates (13, 29, $t2)
        
        draw_line (17, 28, 17, 34, $t2, 1)    # E
        draw_line (17, 28, 21, 28, $t2, 2)
        draw_line (17, 31, 21, 31, $t2, 2)
        draw_line (17, 34, 21, 34, $t2, 2)
        
        draw_line (24, 28, 27, 28, $t2, 2)    # D
        draw_line (28, 29, 28, 33, $t2, 1)
        draw_line (24, 34, 27, 34, $t2, 2)
        draw_line (24, 28, 24, 34, $t2, 1)
        
        draw_line (31, 28, 35, 28, $t2, 2)  # I
        draw_line (33, 28, 33, 34, $t2, 1)
        draw_line (31, 34, 35, 34, $t2, 2)
        
        draw_line (38, 28, 38, 33, $t2, 1)  # U
        draw_line (39, 34, 41, 34, $t2, 2)
        draw_line (42, 28, 42, 33, $t2, 1)
        
        draw_line (45, 28, 45, 34, $t2, 1)    # M
        draw_line (49, 28, 49, 34, $t2, 1)
        draw_coordinates (46, 29, $t2)
        draw_coordinates (47, 30, $t2)
        draw_coordinates (48, 29, $t2)
        
        jr $ra      # return to set_game_mode
        
    draw_hard:
        draw_line (10, 40, 10, 46, $t2, 1)  # H
        draw_line (14, 40, 14, 46, $t2, 1)
        draw_line (10, 43, 14, 43, $t2, 2)
        
        draw_line (17, 40, 17, 46, $t2, 1)    # A
        draw_line (17, 40, 21, 40, $t2, 2)
        draw_line (21, 40, 21, 46, $t2, 1)
        draw_line (17, 43, 21, 43, $t2, 2)
        
        draw_line (24, 40, 24, 46, $t2, 1)  # R
        draw_line (24, 40, 28, 40, $t2, 2)
        draw_line (28, 40, 28, 43, $t2, 1)
        draw_line (24, 43, 28, 43, $t2, 2)
        draw_coordinates (26, 44, $t2)
        draw_coordinates (27, 45, $t2)
        draw_coordinates (28, 46, $t2)
        
        draw_line (31, 40, 34, 40, $t2, 2)    # D
        draw_line (31, 40, 31, 46, $t2, 1)
        draw_line (31, 46, 34, 46, $t2, 2)
        draw_line (35, 41, 35, 45, $t2, 1)
    
        jr $ra      # return to set_game_mode
        
reset_display:
    # colours the entire display black
    
    save_ra ()
    lw $t2, BLACK 
    li $t1, 0
    reset_for_y:
        beq $t1, 64, reset_done
        li $t0, 0
        reset_for_x:
            beq $t0, 64, reset_next_y
            draw_pixel ($t0, $t1, $t2)
            addi $t0, $t0, 1
            j reset_for_x
    reset_next_y:
        addi $t1, $t1, 1
        j reset_for_y
    reset_done: 
        load_ra ()
        jr $ra 
        
##############################################################################
# Level Display 
##############################################################################

display_level:
    # draws the level display at the top of the screen
    
    save_ra ()      # save the return register to the stack
    lw $t2, WHITE   # load the colour white
    
    draw_line (35, 3, 35, 7, $t2, 1)    # L
    draw_line (35, 7, 37, 7, $t2, 2)
    
    draw_line (39, 3, 41, 3, $t2, 2)    # E
    draw_line (39, 3, 39, 7, $t2, 1)
    draw_line (39, 5, 41, 5, $t2, 2)
    draw_line (39, 7, 41, 7, $t2, 2)
    
    draw_line (43, 3, 43, 6, $t2, 1)    # V
    draw_coordinates (44, 7, $t2)
    draw_line (45, 3, 45, 6, $t2, 1)
    
    draw_line (47, 3, 49, 3, $t2, 2)    # E
    draw_line (47, 3, 47, 7, $t2, 1)
    draw_line (47, 5, 49, 5, $t2, 2)
    draw_line (47, 7, 49, 7, $t2, 2)
    
    draw_line (51, 3, 51, 7, $t2, 1)    # L
    draw_line (51, 7, 53, 7, $t2, 2)
    
    lw $t2, BLACK                           # fetch the colour black
    draw_line (58, 3, 60, 3, $t2, 2)        # colour over the original level
    draw_line (58, 4, 60, 4, $t2, 2)
    draw_line (58, 5, 60, 5, $t2, 2)
    draw_line (58, 6, 60, 6, $t2, 2)
    draw_line (58, 7, 60, 7, $t2, 2)
    lw $t2, WHITE                           # restore the colour white
    
    lw $t0, GAME_LEVEL              # fetch the current level
    
    beq $t0, 1, draw_level_one      # display level one
    beq $t0, 2, draw_level_two      # display level one
    beq $t0, 3, draw_level_three    # display level one
    beq $t0, 4, draw_level_four     # display level one
    beq $t0, 5, draw_level_five     # display level one
    
    draw_level_one:
        draw_line (59, 3, 59, 7, $t2, 1)
        draw_coordinates (58, 4, $t2)
        draw_line (58, 7, 60, 7, $t2, 2)
        load_ra ()          # restore the original return address
        jr $ra              # return to the original position
    draw_level_two:
        draw_line (58, 3, 60, 3, $t2, 2)
        draw_coordinates (60, 4, $t2)
        draw_line (58, 5, 60, 5, $t2, 2)
        draw_coordinates (58, 6, $t2)
        draw_line (58, 7, 60, 7, $t2, 2)
        load_ra ()          # restore the original return address
        jr $ra              # return to the original position
    draw_level_three:
        draw_line (60, 3, 60, 7, $t2, 1)
        draw_line (58, 3, 60, 3, $t2, 2)
        draw_line (58, 5, 60, 5, $t2, 2)
        draw_line (58, 7, 60, 7, $t2, 2)
        load_ra ()          # restore the original return address
        jr $ra              # return to the original position
    draw_level_four:
        draw_line (60, 3, 60, 7, $t2, 1)
        draw_line (58, 3, 58, 5, $t2, 1)
        draw_coordinates (59, 5, $t2)
        load_ra ()          # restore the original return address
        jr $ra              # return to the original position
    draw_level_five:
        draw_line (58, 3, 60, 3, $t2, 2)
        draw_coordinates (58, 4, $t2)
        draw_line (58, 5, 60, 5, $t2, 2)
        draw_coordinates (60, 6, $t2)
        draw_line (58, 7, 60, 7, $t2, 2)
        draw_line (58, 3, 60, 3, $t2, 2)
        load_ra ()          # restore the original return address
        jr $ra              # return to the original position

##############################################################################
# Pause Screen
##############################################################################

draw_pause_icon:
    li $t0, 54        # x
    li $t1, 54        # y
    lw $t2, GRAY

    li $t3, 0
draw_box_rows:
    li $t4, 0
draw_box_cols:
    add $t5, $t0, $t4
    add $t6, $t1, $t3
    draw_pixel ($t5, $t6, $t2)
    addi $t4, $t4, 1
    li $t7, 10
    blt $t4, $t7, draw_box_cols
    addi $t3, $t3, 1
    blt $t3, $t7, draw_box_rows

    # Inner pause bars (vertical black lines)
    lw $t2, BLACK

    li $t3, 0
pause_bar_left:
    addi $t5, $t0, 2    # ⬅️ x = box x + 2 (centered horizontally)
    addi $t6, $t1, 2    # ⬅️ y = box y + 2 (start lower to center vertically)
    add $t6, $t6, $t3   # ⬅️ y = y + offset
    draw_pixel ($t5, $t6, $t2)
    addi $t3, $t3, 1
    li $t7, 6           # ⬅️ bar height = 6
    blt $t3, $t7, pause_bar_left

    li $t3, 0
pause_bar_right:
    addi $t5, $t0, 6    # ⬅️ x = box x + 6 (second bar)
    addi $t6, $t1, 2    # ⬅️ y = box y + 2
    add $t6, $t6, $t3   # ⬅️ y = y + offset
    draw_pixel ($t5, $t6, $t2)
    addi $t3, $t3, 1
    blt $t3, $t7, pause_bar_right

    jr $ra
    
erase_pause_icon:
    li $t0, 54        # x
    li $t1, 54        # y
    lw $t2, BLACK

    li $t3, 0
erase_box_rows:
    li $t4, 0
erase_box_cols:
    add $t5, $t0, $t4
    add $t6, $t1, $t3
    draw_pixel ($t5, $t6, $t2)
    addi $t4, $t4, 1
    li $t7, 10
    blt $t4, $t7, erase_box_cols
    addi $t3, $t3, 1
    blt $t3, $t7, erase_box_rows

    jr $ra

##############################################################################
# Global Helpers
##############################################################################

# allows 'beq' to jump to a return address with 'jal'
ra_hop: jr $ra

animation_delay:
    # sleeps for one second to visually show an animation delay
    
    li $v0, 32          # load the syscall code for delay
    li $a0, 70          # specify a delay of 70 ms
    syscall             # invoke the system call
    jr $ra              # return to where the helper was called
    
