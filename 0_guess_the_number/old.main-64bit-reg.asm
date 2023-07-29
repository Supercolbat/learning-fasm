format ELF64 executable 3

;==================== info =======================
; [Overview]
; A simple Guess the Number game written in x86_64 assembly using the Flat Assembler (FASM).
;
; Author: Joey Lent
; License: N/A
;
; [Technical information]
; Tabs are set to 8 spaces.
;
; This program uses the ELF64 format, which changes the calling convention of syscalls from `int 0x80` to `syscall`. The codes for each system call also changes.
;
; In the data section, the use of a period in the `.length` prefix is purely for cosmetic reasons. It can be replaced with an underscore or removed entirely. However, Vim does add highlighting to this syntax.
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
	;   rdi: char __user *buf
	;   rsi: size_t count
	;   rdx: unsigned int flags
	; )
	
	; Generate a random number
	sub     rsp, 24			; I can't explain this.

	mov	rax, SYS_GETRANDOM
	lea	rdi, [rsp + 8]		; I can't explain this.
	mov	rsi, 8
	mov	rdx, 1
	syscall

        mov     rax, [rsp + 8]		; Move the generated number to RAX for the following step 
        add     rsp, 24			; I can't explain this.

	; Constrain the number to a range
	xor	rdx, rdx		; Zero-extend EAX into EDX:EAX
					; I can't explain this.

	push	max			; Divide the number by the maximum value
	int3
	div	rsp			; The modulo gets stored in edx
	int3
					;   Quotient  = RAX
	mov	reg, rdx		;   Remainder = RDX
	add	reg, min		; Shift the range to account for the minimum

	pop	rdx			; Clean up the stack (random unused register)
}

macro Print buf, count {
	; sys_write(
	;   rdi: unsigned int fd
	;   rsi: const char *buf
	;   rdx: size_t count
	; )
	mov	rax, SYS_WRITE
	mov	rdi, STDOUT
	mov 	rsi, buf	; Address of message
	mov 	rdx, count	; Length of the message
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
	;   rdi: unsigned int fd
	;   rsi: char *buf
	;   rdx: size_t count
	; )

	mov	r8, 0	; Accumulated (total) number
	mov	r9, 0	; Error flag (0 is success)

	.read_char:
		mov	rax, SYS_READ
		mov	rdi, STDIN
		push	0		; Add a byte to the stack
		mov 	rsi, rsp	; Address of the top of stack
		mov 	rdx, 1		; Read 1 byte
		syscall

		pop	rax		; Retrieve the read byte

		cmp	rax, 0xA	; Once the line has been read, break
		je	success_jump	; out of the loop

					; (char - '0') <= ('9' - '0')
		sub	rax, '0'	; Turn the ascii char into a number.
					; This can underflow; don't worry about it.
		cmp	edi, '9'-'0'
		ja	.consume_line	; Jump away if the char is greater than 9 (unsigned)

		imul	r8, 10		; Multiply total by 10
		add	r8, rax		; Add the char (now a number) to total

		jmp .read_char

	.consume_line:
		mov	rax, SYS_READ
		mov	rdi, STDIN
		push	0		; Add a byte to the stack
		mov 	rsi, rsp	; Address of the top of stack
		mov 	rdx, 1		; Read 1 byte
		syscall

		pop	rax		; Retrieve the read byte

		cmp	rax, 0xA	; Once the line has been read, break
		je	error_jump	; out of the loop

		jmp .consume_line
}

;================== code =====================
segment readable executable
entry main
;=============================================

main:
	; The secret number
	Rand	rbx, 1, 100

	; Number of guesses
	mov	rbp, 0

	; Show intro text
	Print	banner, banner.length

	.gameloop:
		int3

		; Prompt the user for a number
		Print	prompt, prompt.length

		inc	rbp
		ReadInt	.successful_read, .failed_read ; to r8

		.successful_read:
			cmp	r8, rbx
			jl	.less_than
			jg	.greater_than

			jmp	.win

			.less_than:
				Print higher, higher.length

			.greater_than:
				Print lower, lower.length

			jmp .gameloop

		.failed_read:
			Print invalid, invalid.length
			jmp .gameloop
	
	.win:
		Print success, success.length


	; Exit procedure

        mov     rax, SYS_EXIT	; System call 'exit'
        xor     rbx, rbx	; Exit code: 0 ('xor ebx,ebx' saves time; 'mov ebx, 0' would be slower)
        syscall


;================== data =====================
segment readable writeable
;=============================================

banner           db "Guess a number from 1 to 100.", 0xA
banner.length  = $-banner

prompt           db "> "
prompt.length  = $-prompt

invalid          db "Invalid input :(", 0xA
invalid.length = $-invalid

higher           db "Higher!", 0xA
higher.length  = $-lower

lower            db "Lower!", 0xA
lower.length   = $-lower

success          db "You're are a winner!!", 0xA
success.length = $-success

debug		 db "debug", 0xA
debug.length   = $-debug
