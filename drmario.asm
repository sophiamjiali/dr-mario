################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Dr Mario.
#
# Student 1: Sophia Li, 1009009314
# Student 2: Name, Student Number (if applicable)
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

# stored starting at address 0x10010000

# store the codes for each colour as data values (see address 0x10010000)
red: .word 0xff0000
green: .word 0x00ff00
blue: .word 0x0000ff
black: .word 0x000000
gray: .word 0x808080

# the (x,y) coordinates of the playing area on the bitmap
GAME_DSPL_X: .word 0x00000006
GAME_DSPL_Y: .word 0x00000012

# number of bytes corresponding to the row and step of the playing area
game_row: .word 0x00000064
game_step: .word 0x00000100

# allocate a block to format the bitmap in memory properly
spacer: .space 8

# allocate 24 x 40 = 960 words (3840 bytes) representing each pixel of the playing area
GAME_MEMORY_ADDR: .word 0x10009220       # address of the state of the game stored in memory
GAME_MEMORY: .space 3840                 # starts at address 0x10010040








##############################################################################
# Notes
##############################################################################

# - finish get_info to map pixel on bitmap to game memory
# - finalize what each byte holds (orientation, type, ...)
# - figure out how to do the rotation, see original game
# - implement movement (finish milestone 2)

##############################################################################







##############################################################################
# Code
##############################################################################
	.text
	.globl main
	
##############################################################################
# Macros
##############################################################################

.macro get_pixel (%x, %y)
    # given (x,y) coordinates, returns the corresponding address in the bitmap display
    
    move $a0, %x        # load x-coordinate into the first function argument register
    move $a1, %y        # load y-coordinate into the second function argument register
    
    li $t0, 256         # load the number of bytes to offset to the next row
    li $t1, 4           # load the number of bytes to offset to the next pixel
    
    mult $t0, $a1       # calculate the y-offset of the pixel (relative to the top)
    mflo $t0            # extract the result from 'lo' register
    mult $t1, $a0       # calculate the x-offset of the pixel (relative to the left)
    mflo $t1             # extract the result from 'lo' register
    
    add $t0, $t0, $t1   # calculate the overall byte offset
    add $t0, $t0, $gp   # calculate the address relative to the bitmap
    
    move $v0, $t0       # save the address in the return variable
.end_macro

.macro draw_pixel (%colour, %x, %y)
    # draws a pixel of the given colour at the coordinate specified by (x,y)
    
    move $a0, %x        # load x-coordinate into function argument register
    move $a1, %y        # load y-coordinate into function argument register
    move $a2, %colour   # load colour into function argument register
    
    get_pixel (%x, %y)    # fetch the bitmap address corresponding to (x,y)
    
    sw $a2, 0($v0)  # save the specified colour at the given address
.end_macro

.macro random_colour ()
    # generates a random colour out of red, green, and blue
    
    li $v0, 42          # load syscall code for RANDGEN
    li $a0, 0           # set up RANGEN with generator 0
    li $a1, 3           # set the upper limit for the random number as 2
    syscall             # make the system call, returning to $a0
    
    li $t2, 0                       # load zero as the number corresponding to red
    beq $a0, $t2, random_red        # if zero, return red
    li $t2, 1                       # load one as the number corresponding to green
    beq $a0, $t2, random_green      # if one, return green
    li $t2, 2                       # load two as the number corresponding to blue
    beq $a0, $t2, random_blue       # if two, return blue
    
    random_red:             # assign red to $t3
        lw $t3, red
        j random_done
    random_green:           # assign green to $t3
        lw $t3, green
        j random_done
    random_blue:             # assign blue to $t3
        lw $t3, blue
        j random_done

    random_done: move $v1, $t3     # assign the colour to return variable register $v1
.end_macro

.macro draw_square (%colour, %x, %y)
    # draws a square starting at (x,y) of the given colour
    
    move $a0, %x        # load x-coordinate into function argument register
    move $a1, %y        # load y-coordinate into function argument register
    move $a2, %colour   # load colour into function argument register
    
    draw_pixel ($a2, $a0, $a1)      # draw the first pixel
    addi $a0, $a0, 1                # move the x-coordinate over by one
    draw_pixel ($a2, $a0, $a1)      # draw the second pixel
    addi $a1, $a1, 1                # move the y-coordinate up by one (down on the bitmap)
    draw_pixel ($a2, $a0, $a1)      # draw the third pixel
    addi $a0, $a0, -1               # move the x-coordinate back by one (left on the bitmap)
    draw_pixel ($a2, $a0, $a1)      # draw the fourth pixel
.end_macro

.macro get_coordinates (%address)
    # given an address in the bitmap, get the corresponding (x,y) coordinates
    
    move $a0, %address      # load the address into a function argument register
    
    sub $t0, $a0, $gp       # fetch the offset of the address from the display's base address
    srl $t0, $t0, 2         # divide the index by four to fetch the pixel index (shift right by 2)
    li $t1, 256             # load the width of the display
    div $t0, $t1            # divide the index by the width of the display
    mfhi $v0                # set the x coordinate to the remainder
    mflo $v1                # set the y coordinate to the quotient
.end_macro

.macro move_square (%x, %y, %direction)
    # assuming no collisions, moves the square starting at (x,y) the given direction
    
    move $a0, %x        # load x-coordinate into function argument register
    move $a1, %y        # load y-coordinate into function argument register
    move $a2, %direction   # load the direction into function argument register
    
    get_pixel ($a0, $a1)        # fetch the address corresponding to the coordinate
    lw $t0, 0($v0)              # fetch the colour of the coordinate
    lw $t1, black               # load the colour black
    
    draw_square ($t1, $a0, $a1)     # colour the original square at (x,y) black
    
    beq $a2, 1, move_square_left        # if direction specifies left
    beq $a2, 2, move_square_right       # if direction specifies right
    beq $a2, 3, move_square_up          # if direction specifies up
    beq $a2, 4, move_square_down        # if direction specifies down
    
    move_square_left:
        subi $a0, $a0, 2                    # shift the x-coordinate left by two units
        draw_square ($t0, $a0, $a1)         # draw the square at the new coordinates with the original colour
        j move_square_done                  # completed, jump back
    move_square_right:
        addi $a0, $a0, 2                    # shift the x-coordinate right by two units
        draw_square ($t0, $a0, $a1)         # draw the square at the new coordinates with the original colour
        j move_square_done                  # completed, jump back
    move_square_up:
        subi $a1, $a1, 2                    # shift the y-coordinate up by two units
        draw_square ($t0, $a0, $a1)         # draw the square at the new coordinates with the original colour
        j move_square_done                  # completed, jump back
    move_square_down:
        addi $a1, $a1, 2                    # shift the y-coordinate down by two units
        draw_square ($t0, $a0, $a1)         # draw the square at the new coordinates with the original colour
        j move_square_done                  # completed, jump back
   
    move_square_done:                       # return label for structured jumping, macros don't need jr $ra
.end_macro

.macro move_capsule (%address, %orientation, %direction)
    # given the address of the first half and its orientation, move it the specified direction

    move $a0, %address                  # load address of the capsule's first half into function argument register
    move $a1, %orientation              # load capsule's orientation into function argument register
    li $a2, %direction                  # load the direction into function argument register
    
    get_coordinates ($a0)               # fetch the coordinates of the capsule's first half
    move $t0, $v0                       # extract the x-coordinate
    move $t1, $v1                       # extract the y-coordinate
    
    beq $a1, 1, move_vertical_capsule          # move the second half of the vertical capsule
    beq $a1, 2, move_horizontal_capsule        # move the second half of the horizontal capsule
    
    move_vertical_capsule:
        addi $v1, $v1, 2                        # the second half is below of the first half
        move_square ($t0, $t1, $a2)             # move the capsule's second half first to avoid being overwritten
        get_coordinates ($a0)                   # fetch the coordinates of the first half again
        move $t0, $v0                           # extract the x-coordinate
        move $t1, $v1                           # extract the y-coordinate
        move_square ($t0, $t1, $a2)             # move first half second, avoids overwriting the second half
        j move_capsule_done                     # return back to main
        
    move_horizontal_capsule:
        beq $a2, 1, move_horizontal_capsule_left    # if moving left, move the capsule's first half first
        
        addi $v0, $v0, 4                        # the second half is to the right of the first half
        move_square ($v0, $v1, $a2)             # move the second half first to avoid being overwritten
        get_coordinates ($a0)                   # fetch the coordinates of the first half again
        move $t0, $v0                           # extract the x-coordinate
        move $t1, $v1                           # extract the y-coordinate
        move_square ($v0, $v1, $a2)             # move first half second, avoids overwriting the second half
        j move_capsule_done                     # return back to main
        
    move_horizontal_capsule_left: 
        move_square ($v0, $v1, $a2)             # move the first half first to avoid being overwritten
        addi $v0, $v0, 4                        # the second half is to the right of the first half
        move_square ($v0, $v1, $a2)             # move the second half second, avoids overwriting the first half
        j move_capsule_done                     # return back to main
 
    move_capsule_done:                  # return label for structured jumping, macros don't need jr $ra
.end_macro

.macro new_capsule ()
    # generates a new capsule in the mouth of the bottle, storing 
    # its address on the bitmap in $v0 and its orientation (default 
    # down) in $v1
    
    random_colour ()                # generate a random colour, stored in $v1
    li $t0, 17                      # set the x-coordinate
    li $t1, 12                      # set the y-coordinate
    draw_square ($v1, $t0, $t1)     # draw the top-half of the capsule
    
    get_pixel($t0, $t1)             # stores address of capsule in $v0
    
    random_colour ()                # generate a random colour, stored in $v1
    li $t0, 17                      # set the x-coordinate
    li $t1, 14                      # set the y-coordinate
    draw_square ($v1, $t0, $t1)     # draw the bottom-half of the capsule
    
    li $v1, 1                       # sets 'down = 1' as orientation in $v1
.end_macro

.macro get_info (%x, %y)
    # returns the address in game memory corresponding to the pixel at 
    # coordinate (x,y) on the bitmap; holds extra information
    
    move $a0, %x                # load x-coordinate into function argument register
    move $a1, %y                # load y-coordinate into function argument register
    
    lw $t0, GAME_DSPL_X         # load x-offset of bitmap to playing area
    lw $t1, GAME_DSPL_Y         # load y-offset of bitmap to playing area
    
    sub $v0, $a0, $t0           # subtract the x-offset from the x-coordinate
    sub $v1, $a1, $t1           # subtract the y-offset from the y-coordinate
    
    # ...

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
    
    jal draw_scene                  # draw the initial static scene
    new_capsule ()                  # draws a new capsule 
    move $t8, $v0                   # load the capsule's address in the display to $t8
    move $t9, $v1                   # load the capsule's orientation to $t9
    
    j game_loop

game_loop:
    # 1a. Check if key has been pressed
    lw $t0, ADDR_KBRD               # load the base address for the keyboard
    lw $t1, 0($t0)                  # load the first word from the keyboard: flag
    beq $t1, 0, game_loop_done      # if a word was not detected, skip handling of the input
    
    # 1b. Check which key has been pressed
    keyboard_input:
        lw $t2, 4($t0)              # load in the second word from the keyboard: actual input value
        beq $t2, 0x71, Q_pressed    # user pressed Q: quit the program
    
        # 2a. Check for collisions
            # ... if moves on, assumes no collision was found
        
    	# 2b. Update locations (capsules), # 3. Draw the screen
    	beq $t2, 0x77, W_pressed    # user pressed W: rotate capsule 90 degrees clockwise
        beq $t2, 0x61, A_pressed    # user pressed A: move capsule to the left
        beq $t2, 0x73, S_pressed    # user pressed S: move capsule down
        beq $t2, 0x64, D_pressed    # user pressed D: move capsule to the right
        
    game_loop_done:
    	# 4. Sleep
    	li $v0, 32         # load the syscall code for delay
    	li $a0, 15         # specify a delay of 15 ms (60 updates/second)
    	syscall            # invoke the syscall
    
        # 5. Go back to Step 1
        j game_loop
    
W_pressed:
    # assuming no collision will occur, rotate the capsule 90 degrees clockwise
    
    get_coordinates ($t8)                   # fetch the coordinates corresponding to the address of the capsule
    
    beq $t9, 1, rotate_horizontally         # if the capsule is vertical, rotate to horizontal
    beq $t9, 2, rotate_vertically           # if the capsule is horizontal, rotate to vertical
    
    rotate_vertically:
        addi $v0, $v0, 2                    # the second half of the capsule is to the right of the first half
        li $t0, 4                           # set the direction to move to down
        move_square ($v0, $v1, $t0)         # move the capsule's second half down
        addi $v1, $v1, 2                    # the second half is now below its original position
        li $t0, 1                           # set the direction to move to left
        move_square($v0, $v1, $t0)          # move the capsule's second half left
        li $t9, 1                           # set the capsule's orientation to vertical
        j w_pressed_done
    
    rotate_horizontally:
        # move right then up
        addi $v1, $v1, 2                    # the second half of the capsule is below the first half
        li $t0, 2                           # set the direction to move to right
        move_square ($v0, $v1, $t0)         # move the capsule's second half right
        addi $v0, $v0, 2                    # the second half is now to the right of its original position
        li $t0, 3                           # set the direction to move to up
        move_square ($v0, $v1, $t0)         # move the capsule's second half up
        li $t9, 2                           # set the capsule's orientation to horizontal
        j w_pressed_done                    # return back to main
        
    w_pressed_done: jr $ra                  # return to the original address upon completion

A_pressed:
    # assuming no collision will occur, move the capsule to the left
    move_capsule ($t8, $t9, 1)      # move the capsule left
    jr $ra                          # return to main

S_pressed:
    # assuming no collisions will occur, move the capsule down
    move_capsule ($t8, $t9, 4)      # move the capsule down
    jr $ra                          # return to main

D_pressed:
    # assuming no collision will occur, move the capsule to the right
    move_capsule ($t8, $t9, 2)      # move the capsue right
    jr $ra                          # return to main

Q_pressed:
    li $v0, 10          # load the syscall code for quitting the program
   syscall              # invoke the syscall
    


draw_scene:
    # draws the initial static scene
    
    save_ra ()              # there are nested helper labels, save the original return address
    
    # initialize variables to draw the vertical walls of the bottle
    li $t2, 42              # set the number of loops to perform to draw each line
    lw $t3, gray            # load the colour gray
    li $t5, 256             # set the increment to move to the next pixel (down)
    
    # draw the left wall
    addi $t0, $gp, 4368     # set the starting coordinate for the left wall's first pass
    jal paint_line          # paint the left wall
    addi $t0, $gp, 4116     # set the starting coordinate for the left wall's second pass
    li $t2, 44              # draw the inner line one pixel longer than the inner
    jal paint_line          # paint the left wall
    
    # draw the right wall
    addi $t0, $gp, 4216     # set the starting coordinate for the right wall's first pass
    jal paint_line          # paint the right wall
    addi $t0, $gp, 4476     # set the starting coordinate for the right wall's second pass
    li $t2, 42              # draw the outer line one pixel shorter than the inner
    jal paint_line          # paint the right wall
    
    # draw the bottom
    li $t2, 24              # set the number of loops to perform to draw the line
    li $t5, 4               # set the increment to move to the next pixel (across)
    
    addi $t0, $gp, 14872    # set the starting coordinate for the bottom
    jal paint_line          # paint the bottom of the bottle
    addi $t0, $gp, 15128    # set the starting coordinate for the bottom
    jal paint_line          # paint the bottom of the bottle
    
    # draw the mouth
    li $t2, 8               # update number of loops to perform: horizontal portion
    li $t5, 4               # set increment value: draw horizontally
    addi $t0, $gp, 4120     # update coordinate
    jal paint_line          # paint the line
    addi $t0, $gp, 4376
    jal paint_line
    addi $t0, $gp, 4184
    jal paint_line
    addi $t0, $gp, 4440
    jal paint_line
    
    li $t2, 4               # update number of loops to perform: first vertical portion 
    li $t5, 256             # set incremental value: draw vertically
    addi $t0, $gp, 3120     # update coordinate
    jal paint_line          # paint the line
    addi $t0, $gp, 3124
    jal paint_line
    addi $t0, $gp, 3160
    jal paint_line
    addi $t0, $gp, 3164
    jal paint_line
    
    addi $t0, $gp, 2092     # draw the second vertical portion
    jal paint_line
    addi $t0, $gp, 2096
    jal paint_line
    addi $t0, $gp, 2140
    jal paint_line
    addi $t0, $gp, 2144
    jal paint_line
    
    # draw the initial two coloured capsules
    random_colour ()                # generate a random colour, stored in $v1
    li $t0, 40                      # set the x-coordinate
    li $t1, 20                      # set the y-coordinate
    draw_square ($v1, $t0, $t1)     # draw the top-half of the mouth's capsule
    random_colour ()                # generate a random colour, stored in $v1
    li $t0, 40                      # set the x-coordinate
    li $t1, 22                      # set the y-coordinate
    draw_square ($v1, $t0, $t1)     # draw the bottom-half of the mouth's capsule
    
    load_ra ()              # fetch the original return address
    jr $ra                  # return back to main

    # helper label that paints a line for a given number of pixels long
    paint_line:
    
        li $t1, 0           # reset the initial value of i = 0
        j inner_paint       # enters the for-loop
        
        inner_paint:
            beq $t1, $t2, jump_to_ra    # once for-loop is done, return to label call in draw_bottle
                sw $t3, 0($t0)          # paint the pixel gray
                add $t0, $t0, $t5       # move to the next pixel (row down or pixel to the right)
                addi $t1, $t1, 1        # increment i
            j inner_paint               # continue the for-loop

##############################################################################
# Global Helpers
##############################################################################

# allows 'beq' to jump to a register (usually $ra)
jump_to_ra: jr $ra


