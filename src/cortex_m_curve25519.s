	.syntax unified
	.thumb
// Copyright (c) 2021, Akiles Technologies
// Copyright (c) 2017, Emil Lenngren
//
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form, except as embedded into a Nordic
//    Semiconductor ASA or Dialog Semiconductor PLC integrated circuit in a product
//    or a software update for such product, must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
// ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


	.text
	.align 2

// in: *r0 = result, *r1 = scalar, *r2 = basepoint (all pointers may be unaligned)
// cycles: 548 873
	.type curve25519_scalarmult, %function
curve25519_scalarmult:
	.global curve25519_scalarmult
	
	// stack layout: xp zp xq zq x0  bitpos lastbit scalar result_ptr r4-r11,lr
	//               0  32 64 96 128 160    164     168    200        204

	push {r0,r4-r11,lr}
	//frame push {r4-r11,lr}
	//frame address sp,40
	
	mov r10,r2
	bl loadm
	
	and r0,r0,#0xfffffff8
	//and r7,r7,#0x7fffffff not needed since we don't inspect the msb anyway
	orr r7,r7,#0x40000000
	push {r0-r7}
	//frame address sp,72
	movs r8,#0
	push {r2,r8}
	//frame address sp,80
	
	//ldm r1,{r0-r7}
	mov r1,r10
	bl loadm
	
	and r7,r7,#0x7fffffff
	push {r0-r7}
	//frame address sp,112
	
	movs r9,#1
	umull r10,r11,r8,r8
	mov r12,#0
	push {r8,r10,r11,r12}
	//frame address sp,128
	push {r9,r10,r11,r12}
	//frame address sp,144
	
	push {r0-r7}
	//frame address sp,176
	
	umull r6,r7,r8,r8
	push {r6,r7,r8,r10,r11,r12}
	//frame address sp,200
	push {r6,r7,r8,r10,r11,r12}
	//frame address sp,224
	push {r9,r10,r11,r12}
	//frame address sp,240
	
	movs r0,#254
	movs r3,#0
	// 129 cycles so far
0:
	// load scalar bit into r1
	lsrs r1,r0,#5
	adds r2,sp,#168
	ldr r1,[r2,r1,lsl #2]
	and r4,r0,#0x1f
	lsrs r1,r1,r4
	and r1,r1,#1
	
	strd r0,r1,[sp,#160]

	// if bit != lastbit, swap p, q 	
	eors r3,r1,r3
	mov r0,sp
	add r1,sp,#64
	mov r2,#4
	bl cswap

	// 40*4 - 2 = 158 cycles
	
	mov r8,sp
	add r9,sp,#32
	bl fe25519_add
	push {r0-r7}
	//frame address sp,272
	
	bl fe25519_sqr
	push {r0-r7}
	//frame address sp,304
	
	add r8,sp,#64
	add r9,sp,#96
	bl fe25519_sub
	push {r0-r7}
	//frame address sp,336
	
	bl fe25519_sqr
	push {r0-r7}
	//frame address sp,368
	
	mov r1,sp
	add r2,sp,#64
	bl fe25519_mul
	add r8,sp,#128
	stm r8,{r0-r7}
	
	add r8,sp,#64
	mov r9,sp
	bl fe25519_sub
	add r8,sp,#64
	stm r8,{r0-r7}
	
	// 64 + 1*45 + 2*46 + 1*173 + 2*115 = 604 cycles
	
	//multiplies (r0-r7) with 121666, adds *sp and puts the result on the top of the stack (replacing old content)
	ldr lr,=121666
	//mov lr,#56130
	//add lr,lr,#65536
	ldr r12,[sp,#28]
	mov r11,#0
	umaal r12,r11,lr,r7
	lsl r11,r11,#1
	add r11,r11,r12, lsr #31
	movs r7,#19
	mul r11,r11,r7
	bic r7,r12,#0x80000000
	ldm sp!,{r8,r9,r10,r12}
	//frame address sp,352
	umaal r8,r11,lr,r0
	umaal r9,r11,lr,r1
	umaal r10,r11,lr,r2
	umaal r12,r11,lr,r3
	ldm sp!,{r0,r1,r2}
	//frame address sp,340
	umaal r0,r11,lr,r4
	umaal r1,r11,lr,r5
	umaal r2,r11,lr,r6
	add r7,r7,r11
	add sp,sp,#4
	//frame address sp,338
	push {r0,r1,r2,r7}
	//frame address sp,352
	push {r8,r9,r10,r12}
	//frame address sp,368
	// 39 cycles
	
	mov r1,sp
	add r2,sp,#64
	bl fe25519_mul
	add r8,sp,#160
	stm r8,{r0-r7}
	
	add r8,sp,#192
	add r9,sp,#224
	bl fe25519_add
	stm sp,{r0-r7}
	
	mov r1,sp
	add r2,sp,#32
	bl fe25519_mul
	add r8,sp,#32
	stm r8,{r0-r7}
	
	add r8,sp,#192
	add r9,sp,#224
	bl fe25519_sub
	stm sp,{r0-r7}
	
	mov r1,sp
	add r2,sp,#96
	bl fe25519_mul
	stm sp,{r0-r7}
	
	mov r8,sp
	add r9,sp,#32
	bl fe25519_add
	
	bl fe25519_sqr
	
	add r8,sp,#192
	stm r8,{r0-r7}
	
	mov r8,sp
	add r9,sp,#32
	bl fe25519_sub
	
	bl fe25519_sqr
	stm sp,{r0-r7}
	
	mov r1,sp
	add r2,sp,#256
	bl fe25519_mul
	add r8,sp,#224
	stm r8,{r0-r7}
	
	add sp,sp,#128
	//frame address sp,240
	
	ldrd r2,r3,[sp,#160]
	subs r0,r2,#1
	// 97 + 2*45 + 2*46 + 4*173 + 2*115 = 1201 cycles
	bpl 0b
	// in total 2020 cycles per iteration, in total 515 098 cycles for 255 iterations

	// no cswap needed here for curve25519 since the lowest bit is hardcoded to 0

	// now we must invert zp
	add r1,sp,#32
	bl fe25519_inv
	push {r0-r7}
	
	mov r1,sp
	add r2,sp,#32
	bl fe25519_mul
	
	// now final reduce
	bl fe25519_reduce
	ldr r8,[sp,#232]
	bl storem

	add sp,sp,#236
	//frame address sp,36
	
	pop {r4-r11,pc}
	
	// 234 cycles after inversion
	// in total for whole function 548 873 cycles
	
	.size curve25519_scalarmult, .-curve25519_scalarmult



// conditionally swap A and B in constant time.
// in: *r0 = A, *r1 = B, *r2 = len/16, r3 = whether to swap
	.type cswap, %function
cswap:
	.global cswap

	// convert mask from 0/1 to 0/0xFFFF_FFFF
	rsbs r3, r3, #0

1:
	ldm r0,{r4-r7}
	ldm r1,{r8-r11}
	
	eors r4,r4,r8
	and r12,r4,r3
	eors r8,r8,r12
	eors r4,r4,r8
	
	eors r5,r5,r9
	and r12,r5,r3
	eors r9,r9,r12
	eors r5,r5,r9
	
	eors r6,r6,r10
	and r12,r6,r3
	eors r10,r10,r12
	eors r6,r6,r10
	
	eors r7,r7,r11
	and r12,r7,r3
	eors r11,r11,r12
	eors r7,r7,r11
	
	stm r0!,{r4-r7}
	stm r1!,{r8-r11}
	
	subs r2,#1
	bne 1b
	bx lr
	.size cswap, .-cswap
