;Displaying the current time on the LCD
LCD_data equ P2    ;LCD Data port
LCD_rs   equ P0.0  ;LCD Register Select
LCD_rw   equ P0.1  ;LCD Read/Write
LCD_en   equ P0.2  ;LCD Enable

;Bank 0 -> Main program
;Bank 1 -> function calls
;Bank 2 -> Interrupts

org 00h
ljmp main

org 0bh
ljmp timer_int

org 100h
zeroOut:	
	using 1						;Bank 1 for function calls
		push psw
		mov psw,#08H
	mov r1,50h					;N
	mov r0,51h					;Starting Pointer
	loop_zero:
		mov @r0,#0
		inc r0
		djnz r1, loop_zero
		pop psw
ret

start_timer:
	mov r1,#30
	mov TMOD,#01H
	mov IE,#82H
	clr tf0
	setb tr0					;Starting the timer
ret


main:
	mov sp,#0C7H				;Safe siding the stack pointer
	
	mov 50H,#16					;Initialising the array to zero
	mov 51H,#70H
	acall zeroOut
	
	mov 72H,#':'
	mov 75H,#':'
	
	mov 7Ah,#12H
	mov 7Bh,#59H
	mov 7Ch,#45H
	
	mov P1,#0FH					;First configure switches as input and LED�s as output
	acall lcd_init				;initialise LCD
	acall delay
	acall delay
	acall delay

	acall start_timer			;Starts the timer

loop_main:
	
	mov   a,#80h		 		;Put cursor on first row,6 column
	acall lcd_command	 		;send command to LCD
	acall delay
	mov   dptr,#my_string    	;Load DPTR with sring1 Addr
	acall lcd_sendstring		;call text strings sending routine
	acall delay

								
	mov   a,#0C4H	  		 	;Put cursor on second row,4 column
	acall lcd_command
	acall delay
	mov   r0,#70H
	acall lcd_sendstring_name	
	
	sjmp loop_main				 ;return to loop
	
;======================================
;			LCD subroutines
;======================================
lcd_init:
         mov   LCD_data,#38H  ;Function set: 2 Line, 8-bit, 5x7 dots
         clr   LCD_rs         ;Selected command register
         clr   LCD_rw         ;We are writing in instruction register
         setb  LCD_en         ;Enable H->L
		 acall delay
         clr   LCD_en
	     acall delay

         mov   LCD_data,#0CH  ;Display on, Curson off
         clr   LCD_rs         ;Selected instruction register
         clr   LCD_rw         ;We are writing in instruction register
         setb  LCD_en         ;Enable H->L
		 acall delay
         clr   LCD_en
         
		 acall delay
         mov   LCD_data,#01H  ;Clear LCD
         clr   LCD_rs         ;Selected command register
         clr   LCD_rw         ;We are writing in instruction register
         setb  LCD_en         ;Enable H->L
		 acall delay
         clr   LCD_en
         
		 acall delay

         mov   LCD_data,#06H  ;Entry mode, auto increment with no shift
         clr   LCD_rs         ;Selected command register
         clr   LCD_rw         ;We are writing in instruction register
         setb  LCD_en         ;Enable H->L
		 acall delay
         clr   LCD_en

		 acall delay
         
         ret                  ;Return from routine

;-----------------------command sending routine-------------------------------------
 lcd_command:
         mov   LCD_data,A     ;Move the command to LCD port
         clr   LCD_rs         ;Selected command register
         clr   LCD_rw         ;We are writing in instruction register
         setb  LCD_en         ;Enable H->L
		 acall delay
         clr   LCD_en
		 acall delay
    
         ret  
;-----------------------data sending routine-------------------------------------		     
 lcd_senddata:
         mov   LCD_data,A     ;Move the command to LCD port
         setb  LCD_rs         ;Selected data register
         clr   LCD_rw         ;We are writing
         setb  LCD_en         ;Enable H->L
		 acall delay
         clr   LCD_en
         acall delay
		 acall delay
         ret                  ;Return from busy routine

;-----------------------text strings sending routine-------------------------------------
lcd_sendstring:
         clr   a                  ;clear Accumulator for any previous data
         movc  a,@a+dptr          ;load the first character in accumulator
         jz    exit               ;go to exit if zero
         acall lcd_senddata       ;send first char
         inc   dptr               ;increment data pointer
         sjmp  LCD_sendstring     ;jump back to send the next character
exit:
         ret                      ;End of routine
		 
;-----------------------text strings sending routine-------------------------------------
lcd_sendstring_name:
         mov   a,@r0         	  ;load the first character in accumulator
         jz    exit2              ;go to exit if zero
         acall lcd_senddata       ;send first char
         inc   r0              	  ;increment register
         sjmp  LCD_sendstring_name    ;jump back to send the next character
exit2:
         ret                      ;End of routine

;----------------------delay routine-----------------------------------------------------
delay:	 
	using 1
		push psw
		mov psw,#08H
         mov r0,#1
loop2:	 mov r1,#255
loop1:	 djnz r1, loop1
		 djnz r0,loop2
		 pop psw
		 ret


;=============================
;		Interrupt
;=============================
org 200h
write_nibble: 					;Lower nibble in 53h and write location in r0
		clr c
		subb A,#0ah
		jc digit
			add A,#41h
			mov @r0,A
		sjmp comp
		digit:
			mov A,53h
			add A,#30h
			mov @r0,A
		comp: ret

bin2ascii:
	using 1
		push psw
		mov psw,#08H
	mov r2,50h 						;N
	mov r1,51h 						;Read pointer
	mov r0,52h 						;Write pointer	
	
	binloop:
		mov A,@r1
		anl A,#0F0H 				;higher nibble saved , rest all bits to 0
		swap A
		mov 53h,A
		acall write_nibble 			;53 is reserved for its argument parameter
		inc r0
		
		mov A,#0FH
		anl A,@r1 					;Lower order bits recovered
		mov 53h,A
		acall write_nibble
		inc r0
		inc r1
	djnz r2,binloop
	pop psw
ret

add_a_sec_min:						;r0 has the address of the seconds or minutes byte
									;Returns if any carry through the carry bit
	mov A,@r0
	anl A,#0FH						;Lower nibble
	cjne A,#09H,skip1
	mov A,@r0
	anl A,#0F0H						;Higher Nibble
	cjne A,#50H,skip2
	mov @r0,#00
	setb c
	sjmp return1
	skip2:
		add A,#10H
		mov @r0,A
		clr c
		sjmp return1
	skip1:
		inc @r0
		clr c
	return1:
		ret

add_an_hh:
	mov A,@r0
	cjne A,#09H,skip_9				;Check for 09H
		mov @r0,#10H
		sjmp term
	skip_9:
		cjne A,#12H,skip_12
		mov @r0,#01H
		sjmp term
	skip_12:
		inc @r0
		term:
	ret

update_time:						;70H,71H -> hh   73H,74H -> mm   76H,77H -> ss
									;7AH,7BH,7CH -> one combined bytes stored
									
	mov r0,#7CH						;Add a second
	acall add_a_sec_min
	jnc bin_ascii
	mov r0,#7BH						;Add a minute
	acall add_a_sec_min
	jnc bin_ascii
	mov r0,#7AH						;Add an hour
	acall add_an_hh
	
	bin_ascii:
		mov 50H,#1
		mov 51H,#7CH
		mov 52H,#76H
		acall bin2ascii
		
		mov 50H,#1
		mov 51H,#7BH
		mov 52H,#73H
		acall bin2ascii
		
		mov 50H,#1
		mov 51H,#7AH
		mov 52H,#70H
		acall bin2ascii
	ret

timer_int:
	djnz r1,skip_update
	acall update_time
	mov r1,#30
	skip_update:
		reti

org 300h
	my_string:
		DB '      Time        ',00H
	
end