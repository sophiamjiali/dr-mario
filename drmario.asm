################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Dr Mario.
#
# Student 1: Sophia Li, 1009009314
# Student 2: Adam Lambermon, Student Number (if applicable)
#
# We assert that the code submitted here is entirely our own 
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       2
# - Unit height in pixels:      2
# - Display width in pixels:    64
# - Display height in pixels:   64
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
# store the codes for each colour as data values (see address 0x10010000)
red: .word 0xff0000
green: .word 0x00ff00
blue: .word 0x0000ff
black: .word 0x000000
gray: .word 0x808080

# number of bytes corresponding to the row and step of the display
row: .word 0x00000100
step: .word 0x0000004

# allocate a block to format the bitmap in memory properly
<<<<<<< Updated upstream
<<<<<<< Updated upstream
spacer: .space 4
=======
spacer: .space 16
>>>>>>> Stashed changes
=======
spacer: .space 16
>>>>>>> Stashed changes

# allocate 8 x 16 = 128 words (512 bytes) representing each pixel of the bitmap
bitmap: .space 512

##############################################################################
# Code
##############################################################################
	.text
	.globl main
	
##############################################################################
# Macros
##############################################################################

.macro get_pixel (%x, %y)
    # given (x,y) coordinates, returns the corresponding address in the display
    
    move $a0, %x        # load x-coordinate into the first function argument register
    move $a1, %y        # load y-coordinate into the second function argument register
    
    lw $t0, row         # load the number of bytes to offset to the next row
    lw $t1, step        # load the number of bytes to offset to the next pixel
    
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

##############################################################################
# Main Game Code
##############################################################################

    # Run the game.
main:
    # Initialize the game
    
    # draw the bottle
    jal draw_scene # draw the initial static scene
    
    j game_loop

game_loop:
    # 1a. Check if key has been pressed
    # 1b. Check which key has been pressed
<<<<<<< Updated upstream
    # 2a. Check for collisions
	# 2b. Update locations (capsules)
	# 3. Draw the screen
	# 4. Sleep

    # 5. Go back to Step 1
    j game_loop


=======
    keyboard_input:
        lw $t0, 4($t0)              # load in the second word from the keyboard: actual input value
        beq $t0, 0x71, Q_pressed    # user pressed Q: quit the program
        
    	# 2a. Check for collisions, 2b. Update locations (capsules), # 3. Draw the screen
    	beq $t0, 0x77, W_pressed    # user pressed W: rotate capsule 90 degrees anticlockwise
        beq $t0, 0x61, A_pressed    # user pressed A: move capsule to the left
        beq $t0, 0x73, S_pressed    # user pressed S: move capsule down
        beq $t0, 0x64, D_pressed    # user pressed D: move capsule to the right
        
    finalize_game_loop:
    
        # check for four or more in a row and remove them, updating the display
        # check_matches ()

    	# 4. Sleep
    	li $v0, 32         # load the syscall code for delay
    	li $a0, 15         # specify a delay of 15 ms (60 updates/second)
    	syscall            # invoke the syscall
    
        # 5. Go back to Step 1
        j game_loop

check_move:
    Q_pressed:
        li $v0, 10          # load the syscall code for quitting the program
       syscall              # invoke the syscall
       
    W_pressed:
        # collision check for a potential 90 degree rotation of the current capsule
        
        lw $t3, black                   # fetch the colour black
        
        beq $s2, 1, W_vertical          # check for a vertical capsule
        beq $s2, 2, W_horizontal        # check for a horizontal capsule
        
        W_vertical:
            addi $t0, $s0, 2            # check the pixel to the right of the first half
            get_pixel ($t0, $s1)        # fetch the address of the pixel
            lw $t2, 0($v0)              # fetch the colour of the pixel
            beq $t3, $t2, move_W        # if no pixel to the right, then no collision
            subi $t0, $s0, 2            # else, check the pixel to the right of the first half
            get_pixel ($t0, $s1)        # fetch the address of the pixel
            lw $t2, 0($v0)              # fetch the colour of the pixel
            bne $t3, $t2, move_done     # if there is a collision, check if the game is over
            move_capsule (1)            # else, move the capsule left
            j move_W                    # then rotate the capsule
            
        W_horizontal:
            addi $t1, $s1, 2            # check the pixel below the first half
            get_pixel ($s0, $t1)        # fetch the address of the pixel
            lw $t2, 0($v0)              # fetch the colour of the pixel
            beq $t3, $t2, move_W        # if no pixel to the right, then no collision
            j move_done                 # else, check if the game is over
    
    A_pressed:
        # collision check for a potential movement left of the current capsule
        
        lw $t2, black                           # fetch the colour black
        
        subi $t0, $s0, 2                        # check the pixel left of the first half
        get_pixel ($t0, $s1)                    # fetch the address of the pixel
        lw $t3, 0($v0)                          # fetch the colour of the pixel
        bne $t3, $t2, move_done                 # if first half collides, return to game loop
    
        beq $s2, 1, A_vertical                  # if vertical, must check pixel left of the second half
        beq $s2, 2, move_A                      # if horizontal, collision check is complete
        
        A_vertical:
            addi $t1, $s1, 2                        # check the pixel left of the second half
            get_pixel ($t0, $t1)                    # fetch the address of the pixel
            lw $t3, 0($v0)                          # fetch the colour of the pixel
            beq $t3, $t2, move_A                    # if no pixel to the left, then no collision
            j move_done                             # else, move is done, check if the game is over
    
    S_pressed:
        # collision check for a potential movement down of the current capsule
        
        lw $t2, black                           # fetch the colour black
        
        beq $s2, 1, S_vertical                  # check for a vertical capsule
        beq $s2, 2, S_horizontal                # check for a horizontal capsule
        
        S_vertical:
            addi $t1, $s1, 4                    # check the pixel below the second half
            get_pixel ($s0, $t1)                # fetch the address of the pixel
            lw $t3, 0($v0)                      # fetch the colour of the pixel
            beq $t3, $t2, move_S                # if no pixel below, then no collision
            j move_done                         # else, move is done, check if the game is over
            
        S_horizontal:
            addi $t1, $s1, 2                    # check the pixel below the first half
            get_pixel ($s0, $t1)                # fetch the address of the pixel
            lw $t3, 0($v0)                      # fetch the colour of the pixel
            bne $t3, $t2, move_done             # if first half collides, return to game loop
            addi $t0, $s0, 2                    # check the pixel below the second half
            get_pixel ($t0, $t1)                # fetch the address of the pixel
            lw $t3, 0($v0)                      # fetch the colour of the pixel
            beq $t3, $t2, move_S                # if no pixel below, then no collision
            j move_done                         # else, move is done, check if the game is over
<<<<<<< Updated upstream
>>>>>>> Stashed changes
=======
>>>>>>> Stashed changes

    D_pressed:
        # collision check for a potential movement right of the current capsule
        
        lw $t2, black                           # fetch the colour black
        
        beq $s2, 1, D_vertical                  # if vertical, must check pixel right of the second half
        beq $s2, 2, D_horizontal                # if horizontal, collision check is complete
            
        D_vertical:
            addi $t0, $s0, 2                        # check the pixel right of the first half
            get_pixel ($t0, $s1)                    # fetch the address of the pixel
            lw $t3, 0($v0)                          # fetch the colour of the pixel
            bne $t3, $t2, move_done                 # if first half collides, return to game loop
            subi $t1, $s1, 2                        # check the pixel right of the second half
            get_pixel ($t0, $t1)                    # fetch the address of the pixel
            lw $t3, 0($v0)                          # fetch the colour of the pixel
            beq $t3, $t2, move_D                    # if no pixel to the left, then no collision
            j move_done                             # else, move is done, check if the game is over
            
        D_horizontal:
            addi $t0, $s0, 4                        # check the pixel right of the second half
            get_pixel ($t0, $s1)                    # fetch the address of the pixel
            lw $t3, 0($v0)                          # fetch the colour of the pixel
            beq $t3, $t2, move_D                    # if first half collides, return to game 
            j move_done                             # else, move is done, check if the game is over
    
    
move_capsule:
    move_W:
        # assuming no collision will occur, rotate the capsule 90 degrees clockwise
        
        beq $s2, 1, rotate_vertical             # if the capsule is vertical, rotate to horizontal
        beq $s2, 2, rotate_horizontal           # if the capsule is horizontal, rotate to vertical
        
        rotate_horizontal:
            li $t2, 4                           # set the direction to move to down
            move_square ($s0, $s1, $t2)         # move the first half of the capsule down
            addi $t0, $s0, 2                    # the second half is to the right of the original position
            li $t2, 1                           # set the direction to move to left
            move_square ($t0, $s1, $t2)         # move the second half of teh capsule left
            li $s2, 1                           # set the capsule's orientation to vertical
            j w_pressed_done
        
        rotate_vertical:
            addi $t1, $s1, 2                    # the second half of the capsule is below the first half
            li $t2, 2                           # set the direction to move to right
            move_square ($s0, $t1, $t2)         # move the capsule's second half right
            addi $t0, $s0, 2                    # the second half is now to the right of its original position
            li $t2, 3                           # set the direction to move to up
            move_square ($t0, $t1, $t2)         # move the capsule's second half up
            li $s2, 2                           # set the capsule's orientation to horizontal
            j w_pressed_done                    # return back to main
            
        w_pressed_done: j finalize_game_loop    # return back to the game loop
    
    move_A:
        # assuming no collision will occur, move the capsule to the left
        move_capsule (1)            # move the capsule left
        subi $s0, $s0, 2            # update the x-coordinate
        j finalize_game_loop        # return back to the game loop
    
    move_S:
        # assuming no collisions will occur, move the capsule down
        move_capsule (4)            # move the capsule down
        addi $s1, $s1, 2            # update the y-coordinate
        j finalize_game_loop        # return back to the game loop
    
    move_D:
        # assuming no collision will occur, move the capsule to the right
        move_capsule (2)            # move the capsue right
        addi $s0, $s0, 2            # update the x-coordinate
        j finalize_game_loop        # return back to the game loop
    
    
move_done:
    # called upon a move finding a collision, check if game is over, else generate new capsule
    # and return to the game loop
    
    li $t0, 16              # load the starting x-coordinate of the capsule
    li $t1, 16              # load the starting y-coordinate of the capsule
    
    bne $t0, $s0, start_new_round       # if the x-coordinate doesn't match, 
    bne $t1, $s1, start_new_round       # if the y-coordinate doesn't match
    
    j Q_pressed             # capsule collided at the start position, quit the game
    
    start_new_round:
        new_capsule ()              # else, generate a new capsule and start a new round
        j finalize_game_loop        # return to the game loop

draw_scene:
    # draws the initial static scene
    
    # there are nested helper labels, save the original return address to main on the stack
    addi $sp, $sp, -4       # allocate space on the stack
    sw $ra, 0($sp)          # store the original $ra of main on the stack
    
    # initialize variables to draw the vertical walls of the bottle
    li $t2, 42              # set the number oxf loops to perform to draw each line
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
    li $t0, 17                      # set the x-coordinate
    li $t1, 12                      # set the y-coordinate
    draw_square ($v1, $t0, $t1)     # draw the top-half of the mouth's capsule
    random_colour ()                # generate a random colour, stored in $v1
    li $t0, 17                      # set the x-coordinate
    li $t1, 14                      # set the y-coordinate
    draw_square ($v1, $t0, $t1)     # draw the bottom-half of the mouth's capsule
    
    random_colour ()                # generate a random colour, stored in $v1
    li $t0, 40                      # set the x-coordinate
    li $t1, 20                      # set the y-coordinate
    draw_square ($v1, $t0, $t1)     # draw the top-half of the mouth's capsule
    random_colour ()                # generate a random colour, stored in $v1
    li $t0, 40                      # set the x-coordinate
    li $t1, 22                      # set the y-coordinate
    draw_square ($v1, $t0, $t1)     # draw the bottom-half of the mouth's capsule

    # restore the original return address to main from the stack and return
    lw $ra, 0($sp)          # restore the original address
    addi $sp, $sp, 4        # deallocate the space on the stack
    jr $ra                  # return back to main
    
    jr $ra # return back to main at the next instruction

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


