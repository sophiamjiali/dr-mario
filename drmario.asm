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

# allocate a block to format the bitmap in memory properly
spacer: .space 4

# allocate 8 x 16 = 128 words (512 bytes) representing each pixel of the bitmap
bitmap: .space 512

##############################################################################
# Code
##############################################################################
	.text
	.globl main

    # Run the game.
main:
    # Initialize the game
    
    # draw the bottle
    jal draw_bottle # jump to label draw_bottle, link next instruction's address to $ra
    
    j game_loop

game_loop:
    # 1a. Check if key has been pressed
    # 1b. Check which key has been pressed
    # 2a. Check for collisions
	# 2b. Update locations (capsules)
	# 3. Draw the screen
	# 4. Sleep

    # 5. Go back to Step 1
    j game_loop


##############################################################################
# Global Helpers
##############################################################################

# allows 'beq' to jump to a register (usually $ra)
jump_to_ra: jr $ra

##############################################################################

draw_bottle:
    # draws each wall of the bottle using the helper label 'paint_line'
    
    # there are nested helper labels, save the original return address to main on the stack
    addi $sp, $sp, -4       # allocate space on the stack
    sw $ra, 0($sp)          # store the original $ra of main on the stack
    
    # initialize variables to draw the vertical walls of the bottle
    li $t2, 42              # set the number oxf loops to perform to draw each line
    lw $t3, gray            # load the colour gray
    lw $t4, ADDR_DSPL       # load the start coordinate of the display
    li $t5, 256             # set the increment to move to the next pixel (down)
    
    # draw the left wall
    addi $t0, $t4, 4368     # set the starting coordinate for the left wall's first pass
    li $t1, 0               # set the initial value of i = 0
    jal paint_line          # paint the left wall
    addi $t0, $t4, 4116     # set the starting coordinate for the left wall's second pass
    li $t1, 0               # set the initial value of i = 0
    li $t2, 44              # draw the inner line one pixel longer than the inner
    jal paint_line          # paint the left wall
    
    # draw the right wall
    addi $t0, $t4, 4216     # set the starting coordinate for the right wall's first pass
    li $t1, 0               # reset the initial value of i = 0
    jal paint_line          # paint the right wall
    addi $t0, $t4, 4476     # set the starting coordinate for the right wall's second pass
    li $t1, 0               # reset the initial value of i = 0
    li $t2, 42              # draw the outer line one pixel shorter than the inner
    jal paint_line          # paint the right wall
    
    # draw the bottom
    li $t2, 24              # set the number of loops to perform to draw the line
    li $t5, 4               # set the increment to move to the next pixel (across)
    
    addi $t0, $t4, 14872    # set the starting coordinate for the bottom
    li $t1, 0               # reset the initial value of i = 0
    jal paint_line          # paint the bottom of the bottle
    addi $t0, $t4, 15128    # set the starting coordinate for the bottom
    li $t1, 0               # reset the initial value of i = 0
    jal paint_line          # paint the bottom of the bottle
    
    # draw the mouth
    li $t2, 8               # update number of loops to perform
    li $t5, 4               # set increment value (draw horizontally
    addi $t0, $t4, 4120     # update coordinate
    li $t1, 0               # reset i
    jal paint_line          # paint the line
    addi $t0, $t4, 4376
    li $t1, 0
    jal paint_line
    addi $t0, $t4, 4184
    li $t1, 0
    jal paint_line
    addi $t0, $t4, 4440
    li $t1, 0
    jal paint_line
    
    li $t2, 4
    li $t5, 256
    addi $t0, $t4, 3120
    li $t1, 0
    jal paint_line
    addi $t0, $t4, 3124
    li $t1, 0
    jal paint_line
    addi $t0, $t4, 3160
    li $t1, 0
    jal paint_line
    addi $t0, $t4, 3164
    li $t1, 0
    jal paint_line
    
    addi $t0, $t4, 2092
    li $t1, 0
    jal paint_line
    addi $t0, $t4, 2096
    li $t1, 0
    jal paint_line
    addi $t0, $t4, 2140
    li $t1, 0
    jal paint_line
    addi $t0, $t4, 2144
    li $t1, 0
    jal paint_line
    
    # restore the original return address to main from the stack and return
    lw $ra, 0($sp)          # restore the original address
    addi $sp, $sp, 4        # deallocate the space on the stack
    jr $ra                  # return back to main


    # helper label that a line for a given number of pixels gray
    paint_line:
        
        beq $t1, $t2, jump_to_ra    # once for-loop is done, return to label call in draw_bottle
            sw $t3, 0($t0)          # paint the pixel gray
            add $t0, $t0, $t5       # move to the next pixel (row down or pixel to the right)
            addi $t1, $t1, 1        # increment i
        j paint_line                # continue the for-loop

        jr $ra # return back to main at the next instruction

##############################################################################