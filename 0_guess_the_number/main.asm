format ELF64 executable 3

;==================== info =======================
; [Overview]
; A simple Guess the Number game written in x86_64 assembly using the Flat Assembler (FASM).
;
; Author: Joey Lent
; License: MIT
;
; [Technical information]
; Tabs are used and are set to 8 spaces.
;
; This program uses the ELF64 format, which changes the calling convention of syscalls from `int 0x80` to `syscall`. The codes for each system call also changes.
;
; In the data section, the use of a period in the `sizeof.` prefix is purely for cosmetic reasons. It can be replaced with an underscore or removed entirely. However, the prefix is used in the Print macro to simplify the macro.
;
; Binary size might be reduced by replacing the Print macro with a function, but for simplicity, I've left them as macros.
;=================================================



;================= macros ====================
; Convenience macros and definitions.
;=============================================

define SYS_READ		0
define SYS_WRITE	1
define SYS_GETRANDOM	318
define SYS_EXIT		60

define STDIN	0
define STDOUT	1

define EXIT_SUCCESS 0

macro Rand reg, min, max {
	; sys_getrandom(
	;   edi: char __user *buf
	;   esi: size_t count
	;   edx: unsigned int flags
	; )
	
	; Generate a random number using the SYS_GETRANDOM syscall
	push	0

	mov	eax, SYS_GETRANDOM
	mov	rdi, rsp		; Use the top of stack as the buffer
	mov	esi, 8			; Generate 8 bytes (bits?)
	mov	edx, 1			; idk
	syscall

	; Constrain the number to a range ((x mod max) + min)
	pop	rax			; Dividend low half
	xor	edx, edx		; Dividend high half = 0
	mov	ecx, max		; Divisor

	div	ecx			; The modulo gets stored in EDX
					;   Quotient  = EAX
	mov	reg, edx		;   Remainder = EDX
	add	reg, min		; Offset the number according to the minimum
					;   e.g. 0-99 to 1-100
}

macro Print buf {
	; sys_write(
	;   edi: unsigned int fd
	;   esi: const char *buf
	;   edx: size_t count
	; )
	mov	eax, SYS_WRITE
	mov	edi, STDOUT
	mov 	esi, buf		; Address of message
	mov 	edx, sizeof.#buf	; Length of the message
	syscall
}

; Reads a number from STDIN using the following procedure
; 1. Read a byte
; 2. Check if it's between 48 and 57.
; 3a. If yes, multiply the total by 10 and add this number.
;     Go to step 1.
; 3b. If not, then stop.
macro ReadInt success_jump, error_jump {
	; sys_read(
	;   edi: unsigned int fd
	;   esi: char *buf
	;   edx: size_t count
	; )

	mov	r8, 0	; Accumulated (total) number
	mov	r9, 0	; Error flag (0 is success)

	.read_char:
		mov	eax, SYS_READ
		mov	edi, STDIN
		push	0		; Add a byte to the stack
		mov 	rsi, rsp	; Address of the top of stack
		mov 	edx, 1		; Read 1 byte
		syscall

		pop	rax		; Retrieve the read byte

		cmp	rax, 0xA	; Once the line has been read, break
		je	success_jump	; out of the loop

					; (char - '0') <= ('9' - '0')
		sub	eax, '0'	; Turn the ascii char into a number.
					; This can underflow; don't worry about it.
		cmp	eax, '9'-'0'
		ja	.consume_line	; Jump away if the char is greater than 9 (unsigned)

		imul	r8, 10		; Multiply total by 10
		add	r8, rax		; Add the char (now a number) to total

		jmp .read_char

	.consume_line:
		mov	eax, SYS_READ
		mov	edi, STDIN
		push	0		; Add a byte to the stack
		mov 	rsi, rsp	; Address of the top of stack
		mov 	edx, 1		; Read 1 byte
		syscall

		pop	rax		; Retrieve the read byte

		cmp	eax, 0xA	; Once the line has been read, break
		je	error_jump	; out of the loop

		jmp .consume_line
}

macro PrintInt reg {
	; sys_write(
	;   edi: unsigned int fd
	;   esi: const char *buf
	;   edx: size_t count
	; )
	; note: this syscall uses the r11 register
	;       i initially used that register, but switched to r9, which isn't used

	mov	r9d, reg	; number
	mov	r10, 10		; maximum divisor

	; find the highest power of 10
	.mod_loop:
	cmp	r9, r10
	jb	.print_loop	; once num < max_divisor, we can start printing
	imul	r10, 10		; otherwise, increase the modulo by 1 base
	jmp	.mod_loop
	
	.print_loop:
	mov	rax, r10	; r10 needs to be 1 base less than the number
	xor	edx, edx	; so we divide it by 10
	mov	ecx, 10		;
	div	ecx		;
	mov	r10, rax	;
	.print_loop_in:
	mov	rax, r9	; dividend low half
	xor	edx, edx	; dividend high half = 0
	;   use r10 as the divisor
	
	div	r10		; eax = eax / r10 (highest digit)
				; edx = eax % r10 (everything else)

	mov	r9, rdx	; move the remainder to R11 so it can be divided later

	; print the byte
	add	eax, '0'	; asciify the number
	push	rax		; you can only push 64-bit registers in long mode

	mov	eax, SYS_WRITE  ; write the number to STDOUT
	mov	edi, STDOUT
	lea	rsi, [rsp]      ;   set the read buffer to the address of the top of stack
	mov	edx, 1		;   write 1 byte
	syscall

	pop	rax		; register can be ignored; only to clean up stack

	; set up next iteration
	mov	rax, r10	; move r10 to rax for division
	xor	edx, edx
	mov	ecx, 10
	div	ecx		; divide r10 by 10
	mov	r10, rax	; move the result back to r10

	test	r10, r10	; check if r10 is 0
	jne	.print_loop_in	; if not, then loop again
}

;================== code =====================
segment readable executable
entry main
;=============================================

main:
	; The secret number
	Rand	ebx, 1, 100

	; Number of guesses
	mov	ebp, 0

	; Show intro text
	Print	banner
	Print	intro

	.gameloop:
		; Prompt the user for a number
		Print	prompt

		ReadInt	.successful_read, .failed_read ; to r8

		jmp	.gameloop	; sanity check

		.successful_read:
			inc	ebp		; Increment counter only on success

			cmp	r8, rbx		; Compare the guess to the secret
			jl	.less_than
			jg	.greater_than

			jmp	.win

			.less_than:
				Print	higher
				jmp	.gameloop

			.greater_than:
				Print	lower
				jmp	.gameloop


		.failed_read:
			Print	invalid
			jmp	.gameloop
	
	.win:
		cmp		ebp, 1
		jne		.success
		je		.megasuccess

		.success:
			Print		success
			PrintInt	ebp
			Print		tries
			jmp		.exit
		.megasuccess:
			Print		megasuccess
			jmp		.exit

	.exit:

	; Exit procedure
        mov     eax, SYS_EXIT
	mov	ebx, EXIT_SUCCESS	; 'xor ebx, ebx' would be faster
        syscall


;================== data =====================
segment readable writeable
;=============================================

banner           db "  __ _  __ _ _ __ ___   ___ _ __",  0xA,\
		    " / _` |/ _` | '_ ` _ \ / _ \ '__|", 0xA,\
		    "| (_| | (_| | | | | | |  __/ |",    0xA,\
		    " \__, |\__,_|_| |_| |_|\___|_|",    0xA,\
		    " |___/uess a mostly entropic random", 0xA, 0xA
sizeof.banner  = $-banner

intro            db "Guess a number from 1 to 100.", 0xA
sizeof.intro   = $-intro

prompt           db "> "
sizeof.prompt  = $-prompt

invalid          db "Invalid input :(", 0xA
sizeof.invalid = $-invalid

higher           db "Higher!", 0xA
sizeof.higher  = $-higher

lower            db "Lower!", 0xA
sizeof.lower   = $-lower

success          db "You're are a winner!!", 0xA, "It took you "
sizeof.success = $-success

tries            db " tries (:", 0xA
sizeof.tries   = $-tries

megasuccess      db "You're are a mega winner!!", 0xA, "It took you 1 try :O", 0xA
sizeof.megasuccess = $-megasuccess
