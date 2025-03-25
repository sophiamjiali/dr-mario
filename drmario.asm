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
black: .word 0x000000
gray: .word 0x808080
red: .word 0xff0000
green: .word 0x00ff00
blue: .word 0x0000ff

# create a colour table to choose from when generating a random colour
colour_table: .word 0xff0000, 0x00ff00, 0x0000ff

# formats how game memory appears in memory, organizational only
spacer: .space 24

# store the playing area in memory, playing field of 24 x 40
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
    
    li $a0, %direction      # move the direction into a safe register to avoid overwriting
    
    addi $sp, $sp, -12      # allocate space for three (more) registers on the stack
    sw $t0, 8($sp)          # $t0 is used in this macro, save it to the stack to avoid overwriting
    sw $t1, 4($sp)          # $t1 is used in this macro, save it to the stack to avoid overwriting
    sw $t2, 0($sp)          # $t2 is used in this macro, save it to the stack to avoid overwriting
    
    move $t2, $a0                  # load the direction into a temporary register to avoid being overwritten
    
    beq $s2, 1, move_vertical_capsule          # move the second half of the vertical capsule
    beq $s2, 2, move_horizontal_capsule        # move the second half of the horizontal capsule
    
    move_vertical_capsule:
        add $t1, $s1, $s6                       # the second half is below of the first half
        move_square ($s0, $t1, $t2)             # move the capsule's second half first to avoid being overwritten
        move_square ($s0, $s1, $t2)             # move first half second, avoids overwriting the second half
        j move_capsule_done                     # return back to main
        
    move_horizontal_capsule:
        beq $t2, 1, move_horizontal_capsule_left    # if moving left, move the capsule's first half first
        
        add $t0, $s0, $s6                       # the second half is to the right of the first half
        move_square ($t0, $s1, $t2)             # move the second half first to avoid being overwritten
        move_square ($s0, $s1, $t2)             # move first half second, avoids overwriting the second half
        j move_capsule_done                     # return back to main
        
    move_horizontal_capsule_left: 
        move_square ($s0, $s1, $t2)             # move the first half first to avoid being overwritten
        add $t0, $s0, $s6                       # the second half is to the right of the first half
        move_square ($t0, $s1, $t2)             # move the second half second, avoids overwriting the first half
        j move_capsule_done                     # return back to main
 
    move_capsule_done:                  
        lw $t2, 0($sp)      # restore the original $t2 value
        lw $t1, 4($sp)      # restore the original $t1 value
        lw $t0, 8($sp)      # restore the original $t0 value
        addi $sp, $sp, 12    # free space used by the three registers
.end_macro
    
.macro move_square (%x, %y, %direction)
    # given (x,y) coordinates, move the square defined around this point the specified direction
    
    move $a0, %x                 # move the x-coordinate into a safe register to avoid overwriting
    move $a1, %y                 # move the y-coordinate into a safe register to avoid overwriting
    move $a2, %direction         # move the direction into a safe register to avoid overwriting
    
    addi $sp, $sp, -20           # allocate space for five (more) registers on the stack
    sw $t0, 16($sp)              # $t0 is used in this macro, save it to the stack to avoid overwriting
    sw $t1, 12($sp)               # $t1 is used in this macro, save it to the stack to avoid overwriting
    sw $t2, 8($sp)               # $t2 is used in this macro, save it to the stack to avoid overwriting
    sw $t3, 4($sp)               # $t3 is used in this macro, save it to the stack to avoid overwriting
    sw $t4, 0($sp)               # $t3 is used in this macro, save it to the stack to avoid overwriting
    
    move $t0, $a0                # load x-coordinate into function argument register
    move $t1, $a1                # load y-coordinate into function argument register
    move $t2, $a2                # load the direction into a temporary register to avoid being overwritten
    
    lw $t4, black                # load the colour black
    get_pixel ($t0, $t1)         # fetch the address corresponding to the coordinate
    lw $t3, 0($v0)               # fetch the colour of the coordinate
    
    draw_square ($t0, $t1, $t4)     # colour the original square at (x,y) black
    
    beq $t2, 1, shift_left        # if direction specifies left
    beq $t2, 2, shift_right       # if direction specifies right
    beq $t2, 3, shift_up          # if direction specifies up
    beq $t2, 4, shift_down        # if direction specifies down
    
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
        
        lw $t3, 0($sp)       # restore the original $t4 value
        lw $t3, 4($sp)       # restore the original $t3 value
        lw $t2, 8($sp)       # restore the original $t2 value
        lw $t1, 12($sp)      # restore the original $t1 value
        lw $t0, 16($sp)      # restore the original $t0 value
        addi $sp, $sp, 20    # free space used by the four registers
.end_macro

.macro draw_square (%x, %y, %colour)
    # draws a square starting at (x,y) of the given colour
    
    move $a0, %x                    # move the x-coordinate into a safe register to avoid overwriting
    move $a1, %y                    # move the y-coordinate into a safe register to avoid overwriting
    move $a2, %colour               # move the direction into a safe register to avoid overwriting
    
    addi $sp, $sp, -8       # allocate space for two (more) register on the stack
    sw $t0, 4($sp)          # $t0 is used in this macro, save it to the stack to avoid overwriting  
    sw $t1, 0($sp)          # $t1 is used in this macro, save it to the stack to avoid overwriting  
    
    move $t0, $a0           # initialize the x-coordinate
    move $t1, $a1           # initialize the y-coordinate  
    
    draw_pixel ($t0, $t1, $a2)      # draw the first pixel
    addi $t1, $t1, 1                # move the y-coordinate down by one
    draw_pixel ($t0, $t1, $a2)      # draw the second pixel
    addi $t0, $t0, 1                # move the x-coordinate over by one
    draw_pixel ($t0, $t1, $a2)      # draw the third pixel
    subi $t1, $t1, 1                # move the y-coordinate up by one
    draw_pixel ($t0, $t1, $a2)      # draw the fourth pixel
    
    lw $t1, 0($sp)       # restore the original value of $t1
    lw $t0, 4($sp)       # restore the original value of $t0
    addi $sp, $sp, 8     # free space used by the four registers
.end_macro

.macro draw_pixel (%x, %y, %colour)
    # draws a pixel of the given colour at the coordinate specified by (x,y)
    
    get_pixel (%x, %y)    # fetch the bitmap address corresponding to (x,y)
    move $a2, %colour     # move the colour into a function argument register
    sw $a2, 0($v0)        # save the specified colour at the given address
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
    
    la $t1, colour_table        # load address of color table
    sll $a0, $a0, 2             # multiply index by four (word size)
    add $t1, $t1, $a0           # offset into table
    lw $v1, 0($t1)              # load color into return register
    
    lw $t0, 0($sp)       # restore the original $t0 value
    lw $v0, 4($sp)       # restore the original $v0 value
    lw $a1, 8($sp)       # restore the original $a1 value
    lw $a0, 12($sp)      # restore the original $a0 value
    addi $sp, $sp, 16    # free space used by the four registers
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
        li $t2, 3                       # load the orientation direction code for up
        sb $t2, 1($v0)                  # save the byte code to the second position in the address
        j save_info_done                # return to the original calling
        
    save_info_horizontal:
        li $t1, 2                       # load the orientation direction code for right
        sb $t1, 1($v0)                  # save the bye code to the second position in the address
        addi $t0, $s0, 2                # fetch the x-coordinate of the second half
        get_memory_pixel($t0, $s1)             # fetch the address of the nextca capsule half
        li $t1, 1                       # load the block type code for capsule
        sb $t1, 0($v0)                  # save the byte code to the first position in the address
        li $t2, 1                       # load the orientation drection code for left
        sb $t2, 1($v0)                  # save the byte code to the second positio nin the address
        j save_info_done                # return to the original calling
        
    save_info_done:
        lw $t1, 0($sp)       # restore the original $t1 value
        lw $t0, 4($sp)       # restore the original $t0 value
        addi $sp, $sp, 8    # free space used by the two registers    
.end_macro

.macro get_info (%x, %y)
    # fetches information about the pixel at the (x,y) coordinates; $v0 holds block type (1 is capsule, 2 is virus),
    # $v1 holds connection direction (0 if not connected (or virus), 1-4 represent left right up down)
    
    move $a0, %x                        # load x-coordinate into a function argument register
    move $a1, %y                        # load y-coordinate into a function argumnet register
    
    get_memory_pixel ($a0, $a1)         # fetch the address of the pixel in game memory
    move $t0, 0($v0)                    # extract the address, $v0 is overwritten later
    lb $v0, 0($t0)                      # extract the first byte, holding block type
    lb $v1, 1($t0)                      # extract the second byte, holding connection direction
.end_macro

.macro remove_info (%x, %y)
    # removes the information about a pixel at the (x,y) coordinates from the game memory
    
    get_memory_pixel (%x, %y)   # fetch the address of the pixel in memory
    sb $zero, 0($v0)            # save zero to each byte
    sb $zero, 1($v0)            # ,,,
    
.end_macro

.macro get_memory_pixel (%x, %y)
    # give (x,y) coordinates on the display, return the corresponding address in game memory
    
    addi $sp, $sp, -8       # allocate space for two (more) registers on the stack
    sw $t0, 4($sp)          # $t0 is used in this macro, save it to the stack to avoid overwriting
    sw $t1, 0($sp)          # $t1 is used in this macro, save it to the stack to avoid overwriting
    
    move $a0, %x            # load x-coordinate into the first function argument register
    move $a1, %y            # load y-coordinate into the second function argument register
    li $t0, 96              # load the number of bytes to offset to the next row
    li $t1, 4               # load the number of bytes to offset to the next pixel
    
    subi $a0, $a0, 6        # subtract the playing area offset from the x-coordinate
    subi $a1, $a1, 18       # subtract the playing area offset from the y-coordinate
    
    mul $t1, $t1, $a0       # calculate the x-offset of the pixel (relative to the left)
    mul $t0, $t0, $a1       # calculate the y-offset of the pixel (relative to the top)
    add $t0, $t0, $t1       # calculate the overall byte offset
    
    la $t1, GAME_MEMORY     # fetch the address of the game memory
    
    add $t0, $t0, $t1       # calculate the address relative to the game memory address offset
    move $v0, $t0           # save the address
    
    lw $t1, 0($sp)          # restore the original $t1 value
    lw $t0, 4($sp)          # restore the original $t0 value
    addi $sp, $sp, 8        # free space used by the two registers
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
        # jal check_columns         # checks for any matching blocks in columns and removes them
    
    finish_game_loop:
    
        
    	# 4. Sleep
    	li $v0, 32         # load the syscall code for delay
    	li $a0, 15         # specify a delay of 15 ms (60 updates/second)
    	syscall            # invoke the syscall
    
        # 5. Go back to Step 1
        j game_loop
        
        
        
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
    
    lw $t2, black       # load the colour black
    li $t4, 32          # load the maximum x-coordinate + 4 (to not clip off last pixel)
    li $t5, 58          # load the maximum y-coordinate + 2
    
    rows_loops:
        li $t1, 18          # initialize y-coordinate to the playing area offset
        
        rows_for_y:
            bgt $t1, $t5, rows_end_loops     # if for-loop is done, row match checking is completed
        
            move $t7, $t2                   # set the current consequtive colour to black by default
            li $t0, 6                       # initialize x-coordinate to the playing area offset
            jal reset_consequtive           # reset consequtive coordinates to the current position
        
            rows_for_x:
                bgt $t0, $t4, rows_next_y       # if for-loop is done, iterate to next y-coordinate in for-loop
                
                get_pixel ($t0, $t1)            # fetch the address of the current pixel (represents the block)
                lw $t3, 0($v0)                  # extract its colour
                
                beq $t3, $t2, rows_next_x       # if its black, skip to next iteration of the for loop
                bne $t3, $t7, rows_diff_colour  # if the current block is a different colour than the current consequtive
                
                addi $t6, $t6, 1                # else, same colour, increment the number of consequtive blocks
                j rows_next_x                   # continue to the next iteration of the for-loop
            
                rows_diff_colour:
                    bgt $t6, $s7, rows_remove_match     # if a valid matching is found, remove it
                    jal reset_consequtive               # else, reset consequtive information to the current pixel
                    move $t7, $t3                       # set the consequtive colour to the current pixel
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
                draw_square ($t8, $t1, $t2)         # remove the block at the current coordinates
                remove_info ($t8, $t1)              # remove the block's information stored in the game memory
                addi $t8, $t8, 2                    # increment to the next block
                j rows_match_loop
                
            rows_end_match_loop:
            
                # call label that handles updating the rest of the playing area for falling blocks
                
                j rows_loops        # restart both for-loops
            
        reset_consequtive:
            li $t6, 1           # set the current consequtive number of blocks to one
            move $t8, $t0       # set the x-coordinate to the current position
            move $t9, $t1       # set the y-coordinate to the current position
            jr $ra              # return to the for-loops
            
    rows_end_loops:
        load_ra ()          # restore the original return address
        jr $ra              # return to the original call
            
            
            

check_columns:
        
        
        
        
        
        

    
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
        
        lw $t2, black                           # fetch the colour black
        
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
        
        lw $t2, black                           # fetch the colour black
        
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
    
    
valid_move:
    move_W:
        # assuming no collision will occur, rotate the capsule 90 degrees clockwise
        
        beq $s2, 1, rotate_vertical             # if the capsule is vertical, rotate to horizontal
        beq $s2, 2, rotate_horizontal           # if the capsule is horizontal, rotate to vertical
        
        rotate_horizontal:
            li $t2, 4                           # set the direction to move to down
            move_square ($s0, $s1, $t2)         # move the first half of the capsule down
            add $t0, $s0, $s6                    # the second half is to the right of the original position
            li $t2, 1                           # set the direction to move to left
            move_square ($t0, $s1, $t2)         # move the second half of teh capsule left
            li $s2, 1                           # set the capsule's orientation to vertical
            j w_pressed_done
        
        rotate_vertical:
            get_pixel ($s0, $s1)                # fetch the address of the first half
            lw $t3, 0($v0)                      # extract the colour of the original half
            
            add $t1, $s1, $s6                   # the second half of the capsule is below the first half
            li $t2, 3                           # set the direction to move to up
            move_square ($s0, $t1, $t2)         # move the capsule's second half up over the first half
            li $t2, 2                           # set the direction to move to right
            move_square ($s0, $s1, $t2)         # move the capsule's second half up
            
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
    
    
move_done:
    # called upon a move finding a collision, check if game is over, else generate new capsule
    # and return to the game loop
    
    lw $t2, black                           # fetch the colour black
        
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




initialize_game:
    # draws the initial static scene
    
    save_ra ()              # there are nested helper labels, save the original return address
    
    # initialize variables to draw the vertical walls of the bottle
    li $t2, 42              # set the number of loops to perform to draw each line
    lw $t3, gray            # load the colour gray
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

    # helper label that paints a line for a given number of pixels long
    draw_line:
        li $t1, 0           # reset the initial value of i = 0
        j draw       # enters the for-loop
        
        draw:
            beq $t1, $t2, ra_hop    # once for-loop is done, return to label call in draw_bottle
                sw $t3, 0($t0)          # paint the pixel gray
                add $t0, $t0, $t5       # move to the next pixel (row down or pixel to the right)
                addi $t1, $t1, 1        # increment i
            j draw               # continue the for-loop







ra_hop: jr $ra
