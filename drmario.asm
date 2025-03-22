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

# Save Register Designations:
# $s0: x-coordinate of first half
# $s1: y-coordinate of second half
# $s2: capsule orientation
# $s3: colour of first half
# $s4: colour of second half
# $s5:  
# $s6: 
# $s7: 

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
    
    addi $sp, $sp, -8       # allocate space for two (more) registers on the stack
    sw $t0, 4($sp)          # $t0 is used in this macro, save it to the stack to avoid overwriting
    sw $t1, 0($sp)          # $t1 is used in this macro, save it to the stack to avoid overwriting
    
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
    
    lw $t1, 0($sp)      # restore the original $t1 value
    lw $t0, 4($sp)      # restore the original $t0 value
    addi $sp, $sp, 8    # free space used by the two registers
.end_macro

.macro draw_pixel (%x, %y, %colour)
    # draws a pixel of the given colour at the coordinate specified by (x,y)
    
    get_pixel (%x, %y)    # fetch the bitmap address corresponding to (x,y)
    sw %colour, 0($v0)    # save the specified colour at the given address
.end_macro

.macro random_colour ()
    # generates a random colour out of red, green, and blue
    
    addi $sp, $sp, -16      # allocate space for four (more) registers on the stack
    sw $t0, 12($sp)         # $t0 is used in this macro, save it to the stack to avoid overwriting
    sw $v0, 8($sp)          # $v0 is used in this macro, save it to the stack to avoid overwriting
    sw $a0, 4($sp)          # $a0 is used in this macro, save it to the stack to avoid overwriting
    sw $a1, 0($sp)          # $a1 is used in this macro, save it to the stack to avoid overwriting
    
    li $v0, 42          # load syscall code for RANDGEN
    li $a0, 0           # set up RANGEN with generator 0
    li $a1, 3           # set the upper limit for the random number as 2
    syscall             # make the system call, returning to $a0
    
    li $t0, 0                       # load zero as the number corresponding to red
    beq $a0, $t0, random_red        # if zero, return red
    li $t0, 1                       # load one as the number corresponding to green
    beq $a0, $t0, random_green      # if one, return green
    li $t0, 2                       # load two as the number corresponding to blue
    beq $a0, $t0, random_blue       # if two, return blue
    
    random_red:             # assign red to $t3
        lw $t0, red
        j random_done
    random_green:           # assign green to $t3
        lw $t0, green
        j random_done
    random_blue:             # assign blue to $t3
        lw $t0, blue
        j random_done

    random_done: 
        move $v1, $t0     # assign the colour to return variable register $v1
        
        lw $a1, 0($sp)       # restore the original $a1 value
        lw $a0, 4($sp)       # restore the original $a0 value
        lw $v0, 8($sp)       # restore the original $v0 value
        lw $t0, 12($sp)      # restore the original $t0 value
        addi $sp, $sp, 16    # free space used by the four registers
.end_macro

.macro draw_square (%x, %y, %colour)
    # draws a square starting at (x,y) of the given colour
    
    move $a0, %x                 # move the x-coordinate into a safe register to avoid overwriting
    move $a1, %y                 # move the y-coordinate into a safe register to avoid overwriting
    move $a2, %colour         # move the direction into a safe register to avoid overwriting
    
    addi $sp, $sp, -12      # allocate space for three (more) registers on the stack
    sw $t0, 8($sp)          # $t0 is used in this macro, save it to the stack to avoid overwriting
    sw $t1, 4($sp)          # $t1 is used in this macro, save it to the stack to avoid overwriting
    sw $t2, 0($sp)          # $t2 is used in this macro, save it to the stack to avoid overwriting
    
    move $t0, $a0        # load x-coordinate into function argument register
    move $t1, $a1        # load y-coordinate into function argument register
    move $t2, $a2        # load colour into function argument register
    
    draw_pixel ($t0, $t1, $t2)      # draw the first pixel
    addi $t0, $t0, 1                # move the x-coordinate over by one
    draw_pixel ($t0, $t1, $t2)      # draw the second pixel
    addi $t1, $t1, 1                # move the y-coordinate up by one (down on the bitmap)
    draw_pixel ($t0, $t1, $t2)      # draw the third pixel
    addi $t0, $t0, -1               # move the x-coordinate back by one (left on the bitmap)
    draw_pixel ($t0, $t1, $t2)      # draw the fourth pixel
    
    lw $t2, 0($sp)       # restore the original $t2 value
    lw $t1, 4($sp)       # restore the original $t1 value
    lw $t0, 8($sp)       # restore the original $t0 value
    addi $sp, $sp, 12    # free space used by the three registers
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
    
    move $a0, %x                 # move the x-coordinate into a safe register to avoid overwriting
    move $a1, %y                 # move the y-coordinate into a safe register to avoid overwriting
    move $a2, %direction         # move the direction into a safe register to avoid overwriting
    
    addi $sp, $sp, -16      # allocate space for four (more) registers on the stack
    sw $t0, 16($sp)         # $t0 is used in this macro, save it to the stack to avoid overwriting
    sw $t1, 12($sp)         # $t1 is used in this macro, save it to the stack to avoid overwriting
    sw $t2, 8($sp)          # $t2 is used in this macro, save it to the stack to avoid overwriting
    sw $t3, 4($sp)          # $t3 is used in this macro, save it to the stack to avoid overwriting
    
    move $t0, $a0            # load x-coordinate into function argument register
    move $t1, $a1            # load y-coordinate into function argument register
    move $t2, $a2    # load the direction into a temporary register to avoid being overwritten
    
    lw $t3, black                   # load the colour black
    draw_square ($t0, $t1, $t3)     # colour the original square at (x,y) black
    
    get_pixel ($a0, $a1)        # fetch the address corresponding to the coordinate
    lw $t3, 0($v0)              # fetch the colour of the coordinate
    
    beq $t2, 1, move_square_left        # if direction specifies left
    beq $t2, 2, move_square_right       # if direction specifies right
    beq $t2, 3, move_square_up          # if direction specifies up
    beq $t2, 4, move_square_down        # if direction specifies down
    
    move_square_left:
        subi $t0, $t0, 2                    # shift the x-coordinate left by two units
        j move_square_done                  # completed, jump back
    move_square_right:
        addi $t0, $t0, 2                    # shift the x-coordinate right by two units
        j move_square_done                  # completed, jump back
    move_square_up:
        subi $t1, $t1, 2                    # shift the y-coordinate up by two units
        j move_square_done                  # completed, jump back
    move_square_down:
        addi $a1, $a1, 2                    # shift the y-coordinate down by two units
        j move_square_done                  # completed, jump back
   
    move_square_done:
        draw_square ($t0, $t1, $t3)         # draw the square at the new coordinates with the original colour
        
        lw $t3, 0($sp)       # restore the original $t3 value
        lw $t2, 4($sp)       # restore the original $t2 value
        lw $t1, 8($sp)       # restore the original $t1 value
        lw $t0, 12($sp)      # restore the original $t0 value
        addi $sp, $sp, 16    # free space used by the four registers
.end_macro

.macro move_capsule (%direction)
    # move the current capsule the specified direction
    
    li $a0, %direction      # move the direction into a safe register to avoid overwriting
    
    addi $sp, $sp, -12      # allocate space for three (more) registers on the stack
    sw $t0, 8($sp)          # $t0 is used in this macro, save it to the stack to avoid overwriting
    sw $t1, 4($sp)          # $t1 is used in this macro, save it to the stack to avoid overwriting
    sw $t2, 0($sp)          # $t2 is used in this macro, save it to the stack to avoid overwriting
    
    move $t2, $a0                  # load the direction into a temporary register to avoid being overwritten
    
    beq $s2, 1, move_vertical_capsule          # move the second half of the vertical capsule
    beq $s2, 2, move_horizontal_capsule        # move the second half of the horizontal capsule
    
    move_vertical_capsule:
        addi $t1, $s1, 2                        # the second half is below of the first half
        move_square ($s0, $t1, $t2)             # move the capsule's second half first to avoid being overwritten
        move_square ($s0, $s1, $t2)             # move first half second, avoids overwriting the second half
        j move_capsule_done                     # return back to main
        
    move_horizontal_capsule:
        beq $t2, 1, move_horizontal_capsule_left    # if moving left, move the capsule's first half first
        
        addi $t0, $s0, 4                        # the second half is to the right of the first half
        move_square ($t0, $s1, $t2)             # move the second half first to avoid being overwritten
        move_square ($s0, $s1, $t2)             # move first half second, avoids overwriting the second half
        j move_capsule_done                     # return back to main
        
    move_horizontal_capsule_left: 
        move_square ($s0, $s1, $t2)             # move the first half first to avoid being overwritten
        addi $t0, $s0, 4                        # the second half is to the right of the first half
        move_square ($t0, $s1, $t2)             # move the second half second, avoids overwriting the first half
        j move_capsule_done                     # return back to main
 
    move_capsule_done:                  
        lw $t2, 0($sp)      # restore the original $t2 value
        lw $t1, 4($sp)      # restore the original $t1 value
        lw $t0, 8($sp)      # restore the original $t0 value
        addi $sp, $sp, 12    # free space used by the three registers
        
.end_macro

.macro new_capsule ()
    # generates a new capsule in the mouth of the bottle, storing 
    # its address as (x,y) coordinates in the save registers
    
    addi $sp, $sp, -4       # allocate space for one (more) register on the stack
    sw $t0, 0($sp)          # $t0 is used in this macro, save it to the stack to avoid overwriting 
    
    random_colour ()                # generate a random colour, stored in $v1
    move $s3, $v0                   # set the first half's colour
    li $s0, 17                      # set the x-coordinate
    li $s1, 12                      # set the y-coordinate
    draw_square ($s0, $s1, $s3)     # draw the top-half of the capsule
    
    random_colour ()                # generate a random colour, stored in $v1
    move $s4, $v0                   # set the second half's colour
    li $t0, 14                      # set the y-coordinate
    draw_square ($s0, $t0, $s4)     # draw the bottom-half of the capsule
    
    li $s2, 1                       # sets 'down = 1' as orientation in $v1
    
    lw $t0, 0($sp)       # restore the original $t0 value
    addi $sp, $sp, 4     # free space used by the three registers
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
    new_capsule ()                  # draws a new capsule, info held in $s0-4
    
    j game_loop

game_loop:
    # 1a. Check if key has been pressed
    lw $t0, ADDR_KBRD               # load the base address for the keyboard
    lw $t1, 0($t0)                  # load the first word from the keyboard: flag
    beq $t1, 0, game_loop_done      # if a word was not detected, skip handling of the input
    
    # 1b. Check which key has been pressed
    keyboard_input:
        lw $t0, 4($t0)              # load in the second word from the keyboard: actual input value
        beq $t0, 0x71, Q_pressed    # user pressed Q: quit the program
    
        # 2a. Check for collisions
            # ... if moves on, assumes no collision was found
        
    	# 2b. Update locations (capsules), # 3. Draw the screen
    	beq $t0, 0x77, W_pressed    # user pressed W: rotate capsule 90 degrees clockwise
        beq $t0, 0x61, A_pressed    # user pressed A: move capsule to the left
        beq $t0, 0x73, S_pressed    # user pressed S: move capsule down
        beq $t0, 0x64, D_pressed    # user pressed D: move capsule to the right
        
    game_loop_done:
    	# 4. Sleep
    	li $v0, 32         # load the syscall code for delay
    	li $a0, 15         # specify a delay of 15 ms (60 updates/second)
    	syscall            # invoke the syscall
    
        # 5. Go back to Step 1
        j game_loop
    
W_pressed:
    # assuming no collision will occur, rotate the capsule 90 degrees clockwise
    
    beq $s2, 1, rotate_horizontally         # if the capsule is vertical, rotate to horizontal
    beq $s2, 2, rotate_vertically           # if the capsule is horizontal, rotate to vertical
    
    rotate_vertically:
        addi $t0, $s0, 2                    # the second half of the capsule is to the right of the first half
        li $t2, 4                           # set the direction to move to down
        move_square ($t0, $s1, $t2)         # move the capsule's second half down
        addi $t1, $s1, 2                    # the second half is now below its original position
        li $t2, 1                           # set the direction to move to left
        move_square($t0, $t1, $t2)          # move the capsule's second half left
        li $s2, 1                           # set the capsule's orientation to vertical
        j w_pressed_done
    
    rotate_horizontally:
        # move right then up
        addi $t1, $s1, 2                    # the second half of the capsule is below the first half
        li $t2, 2                           # set the direction to move to right
        move_square ($s0, $t1, $t2)         # move the capsule's second half right
        addi $t0, $s0, 2                    # the second half is now to the right of its original position
        li $t2, 3                           # set the direction to move to up
        move_square ($t0, $t1, $t2)         # move the capsule's second half up
        li $s2, 2                           # set the capsule's orientation to horizontal
        j w_pressed_done                    # return back to main
        
    w_pressed_done: jr $ra                  # return to the original address upon completion

A_pressed:
    # assuming no collision will occur, move the capsule to the left
    move_capsule (1)      # move the capsule left
    jr $ra                          # return to main

S_pressed:
    # assuming no collisions will occur, move the capsule down
    move_capsule (4)      # move the capsule down
    jr $ra                          # return to main

D_pressed:
    # assuming no collision will occur, move the capsule to the right
    move_capsule (2)      # move the capsue right
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


