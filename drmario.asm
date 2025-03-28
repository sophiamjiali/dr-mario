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

# store each colour
BLACK: .word 0x000000
GRAY: .word 0x808080
RED: .word 0xff0000
GREEN: .word 0x00ff00
BLUE: .word 0x0000ff
YELLOW: .word 0xffff00

LIGHT_RED: .word 0xffcccb
LIGHT_BLUE: .word 0xadd8e6
LIGHT_YELLOW: .word 0xffa500

# game difficulty; determines the number of viruses generated, etc.
GAME_DIFFICULTY: .word 1

# create a colour table to choose from when generating a random colour
COLOUR_TABLE: .word 0xff0000, 0x00ff00, 0x0000ff

# formats how game memory appears in memory, organizational only
SPACER: .space 24

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

.macro set_defaults ()
    # define defaults here
    li $s6, 2       # number of pixels in a block
    li $s7, 3       # minimum consequtive blocks that count as a match - 1
.end_macro

.macro new_capsule ()
    # generates a new capsule in the mouth of the bottle, storing 
    # its address as (x,y) coordinates in the save registers
    
    addi $sp, $sp, -4       # allocate space for one (more) register on the stack
    sw $t0, 0($sp)          # $t0 is used in this macro, save it to the stack to avoid overwriting 
    
    generate_colour ()              # generate a random colour, stored in $v1
    move $s3, $v1                   # set the first half's colour
    li $s0, 16                      # set the x-coordinate
    li $s1, 16                      # set the y-coordinate
    draw_square ($s0, $s1, $s3)     # draw the top-half of the capsule
    
    generate_colour ()              # generate a random colour, stored in $v1
    move $s4, $v1                   # set the second half's colour
    li $t0, 18                      # set the x-coordinate
    draw_square ($t0, $s1, $s4)     # draw the bottom-half of the capsule
    
    li $s2, 2                       # sets 'horizontal = 2' as orientation in $v1
    
    lw $t0, 0($sp)       # restore the original $t0 value
    addi $sp, $sp, 4     # free space used by the three registers
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

.macro generate_colour ()
    # generate a random colour out of the given choices: red, green, and blue
    
    addi $sp, $sp, -16      # allocate space for four (more) registers on the stack
    sw $a0, 12($sp)         # $a0 is used in this macro, save it to the stack to avoid overwriting
    sw $a1, 8($sp)          # $a1 is used in this macro, save it to the stack to avoid overwriting
    sw $v0, 4($sp)          # $v0 is used in this macro, save it to the stack to avoid overwriting
    sw $t0, 0($sp)          # $t0 is used in this macro, save it to the stack to avoid overwriting
    
    li $v0, 42          # load syscall code for RANDGEN
    li $a0, 0           # set up RANGEN with generator 0
    li $a1, 3           # set the upper limit for the random number as 2
    syscall             # make the system call, returning to $a0
    
    la $t1, COLOUR_TABLE        # load address of color table
    sll $a0, $a0, 2             # multiply index by four (word size)
    add $t1, $t1, $a0           # offset into table
    lw $v1, 0($t1)              # load color into return register
    
    lw $t0, 0($sp)       # restore the original $t0 value
    lw $v0, 4($sp)       # restore the original $v0 value
    lw $a1, 8($sp)       # restore the original $a1 value
    lw $a0, 12($sp)      # restore the original $a0 value
    addi $sp, $sp, 16    # free space used by the four registers
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
    
    move $a0, %x                        # load x-coordinate into a function argument register
    move $a1, %y                        # load y-coordinate into a function argumnet register
    
    addi $sp, $sp, -8        # allocate space for two (more) register on the stack
    sw $t0, 4($sp)           # $t0 is used in this macro, save it to the stack to avoid overwriting
    sw $t1, 0($sp)           # $t1 is used in this macro, save it to the stack to avoid overwriting
    
    get_memory_pixel ($a0, $a1)         # fetch the address of the pixel in memory
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
        
    remove_info_done:
        sb $zero, 1($v0)                    # set the other half's connection orientation to zero
       
        lw $t1, 0($sp)          # restore the original value of $t1
        lw $t0, 4($sp)          # restore the original value of $t0
        addi $sp, $sp, 8        # free space used by the register
    
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
    
    set_defaults ()                 # set all default values for the game
    jal initialize_game             # initialize the game with static drawings
    new_capsule ()                  # draws a new capsule, info held in $s0-4
    jal new_viruses                 # generate viruses based on the game difficulty
    
    j game_loop

game_loop:
    # 1a. Check if key has been pressed
    lw $t0, ADDR_KBRD                   # load the base address for the keyboard
    lw $t1, 0($t0)                      # load the first word from the keyboard: flag
    beq $t1, 0, finish_game_loop        # if a word was not detected, skip handling of the input
    
    # 1b. Check which key has been pressed
    keyboard_input:
        lw $t0, 4($t0)              # load in the second word from the keyboard: actual input value
        beq $t0, 0x71, Q_pressed    # user pressed Q: quit the program
        
    	# 2a. Check for collisions, 2b. Update locations (capsules), # 3. Draw the screen
    	beq $t0, 0x77, W_pressed    # rotate capsule 90 degrees clockwise
        beq $t0, 0x61, A_pressed    # move capsule left
        beq $t0, 0x73, S_pressed    # move capsule down
        beq $t0, 0x64, D_pressed    # move capsule to the right
        
    update_playing_area:
        jal check_rows            # checks for any matching blocks in rows and removes them
        jal check_columns         # checks for any matching blocks in columns and removes them
    
    finish_game_loop:
    
    	# 4. Sleep
    	li $v0, 32         # load the syscall code for delay
    	li $a0, 15         # specify a delay of 15 ms (60 updates/second)
    	syscall            # invoke the syscall
    
        # 5. Go back to Step 1
        j game_loop
        
        
        
        
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
                bne $t3, $t7, rows_diff_colour      # if the current block is a different colour than the current consequtive
                
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
                bne $t3, $t7, columns_diff_colour
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
            lw $t2, 516($v0)                    # fetch the colour of the block below and to the right
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
    li $v0, 10          # load the syscall code for quitting the program
   syscall              # invoke the syscall
   
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
    # generates new viruses according to game difficulty
    
    lw $t9, GAME_DIFFICULTY         # fetch the game difficulty
    mul $t9, $t9, 2                 # multiply the game difficulty by two
    addi $t9, $t9, 2                # base number of viruses is four, offset for difficulty 1
    
    li $t8, 0                       # initialize a counter
    
    new_viruses_loop:
        beq $t8, $t9, ra_hop        # once all viruses are generated, return to the game loop
        generate_virus ()           
        addi $t8, $t8, 1            # increment the counter by one
        j new_viruses_loop          # continue the for-loop
    


##############################################################################
# Static Scene Initialization
##############################################################################

initialize_game:
    # draws the initial static scene
    
    save_ra ()              # there are nested helper labels, save the original return address
    
    # initialize variables to draw the vertical walls of the bottle
    li $t2, 42              # set the number of loops to perform to draw each line
    lw $t3, GRAY            # load the colour gray
    li $t5, 256             # set the increment to move to the next pixel (down)
    
    # draw the left wall
    addi $t0, $gp, 4368     # set the starting coordinate for the left wall's first pass
    jal draw_line          # paint the left wall
    addi $t0, $gp, 4116     # set the starting coordinate for the left wall's second pass
    li $t2, 44              # draw the inner line one pixel longer than the inner
    jal draw_line          # paint the left wall
    
    # draw the right wall
    addi $t0, $gp, 4216     # set the starting coordinate for the right wall's first pass
    jal draw_line          # paint the right wall
    addi $t0, $gp, 4476     # set the starting coordinate for the right wall's second pass
    li $t2, 42              # draw the outer line one pixel shorter than the inner
    jal draw_line          # paint the right wall
    
    # draw the bottom
    li $t2, 24              # set the number of loops to perform to draw the line
    li $t5, 4               # set the increment to move to the next pixel (across)
    
    addi $t0, $gp, 14872    # set the starting coordinate for the bottom
    jal draw_line          # paint the bottom of the bottle
    addi $t0, $gp, 15128    # set the starting coordinate for the bottom
    jal draw_line          # paint the bottom of the bottle
    
    # draw the mouth
    li $t2, 8               # update number of loops to perform: horizontal portion
    li $t5, 4               # set increment value: draw horizontally
    addi $t0, $gp, 4120     # update coordinate
    jal draw_line          # paint the line
    addi $t0, $gp, 4376
    jal draw_line
    addi $t0, $gp, 4184
    jal draw_line
    addi $t0, $gp, 4440
    jal draw_line
    
    li $t2, 4               # update number of loops to perform: first vertical portion 
    li $t5, 256             # set incremental value: draw vertically
    addi $t0, $gp, 3120     # update coordinate
    jal draw_line          # paint the line
    addi $t0, $gp, 3124
    jal draw_line
    addi $t0, $gp, 3160
    jal draw_line
    addi $t0, $gp, 3164
    jal draw_line
    
    addi $t0, $gp, 2092     # draw the second vertical portion
    jal draw_line
    addi $t0, $gp, 2096
    jal draw_line
    addi $t0, $gp, 2140
    jal draw_line
    addi $t0, $gp, 2144
    jal draw_line
    
    load_ra ()              # fetch the original return address
    jr $ra                  # return back to main

    draw_line:
        li $t1, 0           # reset the initial value of i = 0
        j draw              # enters the for-loop
        
        draw:
            beq $t1, $t2, ra_hop    # once for-loop is done, return to label call in draw_bottle
                sw $t3, 0($t0)          # paint the pixel gray
                add $t0, $t0, $t5       # move to the next pixel (row down or pixel to the right)
                addi $t1, $t1, 1        # increment i
            j draw               # continue the for-loop

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
