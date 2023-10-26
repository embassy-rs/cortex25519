// Copyright (c) 2023, Akiles Technologies
// 
// Available under 2-clause BSD license.
//
// Note the exceptions for Semiconductor ASA or Dialog Semiconductor
// PLC integrated circuits in other files in this work apply ONLY to
// these files, not to this one, and therefore not to the whole work.

	.syntax unified
	.thumb
	.text
	.align 2


// INPUT: *r0 = result, *r1 = a, *r2 = b
	.type ed25519_add, %function
ed25519_add:
	.global ed25519_add
	push {r0, r4-r11,lr}
	sub sp, sp, #256

	mov r10, r2

	// copy a from input
	mov r8, r1
	mov r9, sp
	bl copy128

	// copy b from input
	mov r8, r10
	add r9, sp, #128
	bl copy128

	bl ed25519_add_impl

	// copy r to output
	add r8, sp, #128    // res
	ldr r9, [sp, #256]  // output
	bl copy128

	add sp, sp, #260
	pop {r4-r11,pc}

	.size ed25519_add, .-ed25519_add



// INPUT: sp, sp+128
// OUTPUT: sp+128
// CLOBBERS: all registers
	.type ed25519_add_impl, %function
ed25519_add_impl:
	.global ed25519_add_impl

	push {lr}
	sub sp, sp, #96

	// A = y1-x1
	add r8, sp, #132 // y1
	add r9, sp, #100 // x1
	bl fe25519_sub
	add r8, sp, #0 // a
	stm r8, {r0-r7}

	// B = Y2-X2
	add r8, sp, #260 // y2
	add r9, sp, #228 // x2
	bl fe25519_sub
	add r8, sp, #32 // b
	stm r8, {r0-r7}

	// A = A*B
	add r1, sp, #0 // a
	add r2, sp, #32 // b
	bl fe25519_mul
	add r8, sp, #0 // a
	stm r8, {r0-r7}


	// B = Y1+X1
	add r8, sp, #132 // y1
	add r9, sp, #100 // x1
	bl fe25519_add
	add r8, sp, #32 // b
	stm r8, {r0-r7}

	// C = Y2+X2
	add r8, sp, #260 // y2
	add r9, sp, #228 // x2
	bl fe25519_add
	add r8, sp, #64 // c
	stm r8, {r0-r7}

	// X2 = B*C
	add r1, sp, #32 // b
	add r2, sp, #64 // c
	bl fe25519_mul
	add r8, sp, #228 // x2
	stm r8, {r0-r7}


	// Y2 = k*T2
    ldr r1, =ED25519_D2
	add r2, sp, #324 // t2
	bl fe25519_mul
	add r8, sp, #260 // y2
	stm r8, {r0-r7}

	// Y2 = T1*Y2
	add r1, sp, #260 // y2
	add r2, sp, #196 // t1
	bl fe25519_mul
	add r8, sp, #260 // y2
	stm r8, {r0-r7}

	// T2 = 2*Z2
	add r8, sp, #292 // z2
	add r9, sp, #292 // z2
	bl fe25519_add
	add r8, sp, #324 // t2
	stm r8, {r0-r7}

    // T2 = Z1*T2
	add r1, sp, #164 // z1
	add r2, sp, #324 // t2
	bl fe25519_mul
	add r8, sp, #324 // t2
	stm r8, {r0-r7}


    // B = T2-Y2
	add r8, sp, #324 // t2
	add r9, sp, #260 // y2
	bl fe25519_sub
	add r8, sp, #32 // b
	stm r8, {r0-r7}

    // C = T2+Y2
	add r8, sp, #324 // t2
	add r9, sp, #260 // y2
	bl fe25519_add
	add r8, sp, #64 // c
	stm r8, {r0-r7}

    // T2 = X2-A
	add r8, sp, #228 // x2
	add r9, sp, #0 // a
	bl fe25519_sub
	add r8, sp, #324 // t2
	stm r8, {r0-r7}

    // A = X2+A
	add r8, sp, #228 // x2
	add r9, sp, #0 // a
	bl fe25519_add
	add r8, sp, #0 // a
	stm r8, {r0-r7}


    // X2 = T2*B
	add r1, sp, #324 // t2
	add r2, sp, #32 // b
	bl fe25519_mul
	add r8, sp, #228 // x2
	stm r8, {r0-r7}

    // Y2 = C*A
	add r1, sp, #64 // c
	add r2, sp, #0 // a
	bl fe25519_mul
	add r8, sp, #260 // y2
	stm r8, {r0-r7}

    // Z2 = B*C
	add r1, sp, #32 // b
	add r2, sp, #64 // c
	bl fe25519_mul
	add r8, sp, #292 // z2
	stm r8, {r0-r7}

    // T2 = T2*A
	add r1, sp, #324 // t2
	add r2, sp, #0 // a
	bl fe25519_mul
	add r8, sp, #324 // t2
	stm r8, {r0-r7}

	add sp, sp, #96
	pop {pc}

	.size ed25519_add_impl, .-ed25519_add_impl


// in: *r0 = result, *r1 = scalar, *r2 = point
	.type ed25519_scalarmult, %function
ed25519_scalarmult:
	.global ed25519_scalarmult
	push {r0, r1, r4-r11,lr}
	sub sp, sp, #260
	// stack: p(x, y, z, t), r(x, y, z, t)

	// copy p from input
	mov r8, r2
	mov r9, sp
	bl copy128

	// initialize r=0
	mov r0, #0
	mov r1, #0
	mov r2, #0
	mov r3, #0
	mov r4, #0
	mov r5, #0
	mov r6, #0
	mov r7, #0
	add r8, sp, #128
	stm r8!, {r0-r7}
	mov r0, #1
	stm r8!, {r0-r7}
	stm r8!, {r0-r7}
	mov r0, #0
	stm r8!, {r0-r7}

	//////////////////////////////////////////////

	mov r0, #0 
	str r0, [sp, #256] // loop counter

0:
	ldr r0, [sp, #256] // loop counter
	lsr r1, r0, #3
	ldr r2, [sp, #264] // scalar
	ldrb r2, [r2, r1] // load byte i/8 from scalar

	// Do the add if bit i%8 is set
	and r0, r0, #7
	mov r1, #1
	lsl r1, r1, r0
	tst r2, r1
	beq 1f
	bl ed25519_add_impl
1:

	ldr r0, [sp, #256] // loop counter
	add r0, r0, #1
	cmp r0, #256
	beq 2f
	str r0, [sp, #256] // loop counter

	//////////////////////////////////////////////
	// BEGIN POINT DOUBLE
	
	sub sp, sp, #96
	// We use 3 temporaries: a, b, c
	// stack: a, b, c, x, y, z, t

	add r8, sp, #96 // x
	add r9, sp, #128 // y
	bl fe25519_add
	bl fe25519_sqr
	add r8, sp, #192 // t
	stm r8, {r0-r7}

	add r8, sp, #128 // y
	ldm r8, {r0-r7}
	bl fe25519_sqr
	add r8, sp, #32 // b
	stm r8, {r0-r7}

	add r8, sp, #96 // x
	ldm r8, {r0-r7}
	bl fe25519_sqr
	add r9, sp, #0 // a
	stm r9, {r0-r7}

	add r8, sp, #192 // t
	//add r9, sp, #0 // a
	bl fe25519_sub
	add r8, sp, #192 // t
	stm r8, {r0-r7}

	//add r8, sp, #192 // t
	add r9, sp, #32 // b
	bl fe25519_sub
	add r8, sp, #192 // t
	stm r8, {r0-r7}

	add r8, sp, #32 // b
	add r9, sp, #0 // a
	bl fe25519_sub
	add r8, sp, #64 // c
	stm r8, {r0-r7}

	add r8, sp, #32 // b
	add r9, sp, #0 // a
	bl fe25519_add
	bl fe25519_neg
	add r8, sp, #0 // a
	stm r8, {r0-r7}

	add r8, sp, #160 // z
	ldm r8, {r0-r7}
	bl fe25519_sqr
	add r8, sp, #32 // b
	stm r8, {r0-r7}

	//add r8, sp, #32 // b
	mov r9, r8 // b
	bl fe25519_add
	add r9, sp, #32 // b
	stm r9, {r0-r7}

	add r8, sp, #64 // c
	//add r9, sp, #32 // b
	bl fe25519_sub
	add r8, sp, #32 // b
	stm r8, {r0-r7}

	add r1, sp, #192 // t
	add r2, sp, #32 // b
	bl fe25519_mul
	add r8, sp, #96 // x
	stm r8, {r0-r7}

	add r1, sp, #64 // c
	add r2, sp, #0 // a
	bl fe25519_mul
	add r8, sp, #128 // y
	stm r8, {r0-r7}

	add r1, sp, #32 // b
	add r2, sp, #64 // c
	bl fe25519_mul
	add r8, sp, #160 // z
	stm r8, {r0-r7}

	add r1, sp, #0 // a
	add r2, sp, #192 // t
	bl fe25519_mul
	add r8, sp, #192 // t
	stm r8, {r0-r7}

	////////////////////
	//add r8, sp, #0 // a
	//add r8, sp, #32 // b
	//add r8, sp, #64 // c
	//add r8, sp, #96 // x
	//add r8, sp, #128 // y
	//add r8, sp, #160 // z
	//add r8, sp, #192 // t

	add sp, sp, #96

	// END POINT DOUBLE
	
	b 0b 
2:

	// copy r to output
	add r8, sp, #128    // r
	ldr r9, [sp, #260]  // output
	bl copy128

	// success!
	mov r0, #1
	add sp, sp, #268
	pop {r4-r11,pc}

fail2:
	mov r0, #0
	add sp, sp, #268
	pop {r4-r11,pc}
	.size ed25519_scalarmult, .-ed25519_scalarmult


// in: *r8 = dst, *r9 = src
	.type copy128, %function
copy128:
	.global copy128
	ldm r8!, {r0-r7}
	stm r9!, {r0-r7}
	ldm r8!, {r0-r7}
	stm r9!, {r0-r7}
	ldm r8!, {r0-r7}
	stm r9!, {r0-r7}
	ldm r8!, {r0-r7}
	stm r9!, {r0-r7}
	bx lr
	.size copy128, .-copy128

// in: *r0 = result, *r1 = point
	.type ed25519_compress, %function
ed25519_compress:
	.global ed25519_compress

	push {r0, r1, r4-r11, lr}
	sub sp, sp, #36

	// Calc z ^ -1
	ldr r1, [sp, #40] // point
	add r1, r1, #64 // z
	bl fe25519_inv
	stm sp, {r0-r7} // z^-1
	
	// Calc x
	ldr r1, [sp, #40] // point.x
	mov r2, sp        // z^-1
	bl fe25519_mul
	bl fe25519_reduce

	// Calc x's parity
	lsl r0, r0, #31
	str r0, [sp, #32]

	// Calc y
	ldr r1, [sp, #40] // point
	add r1, r1, #32   // y
	mov r2, sp        // z^-1
	bl fe25519_mul
	bl fe25519_reduce

	// Set parity bit
	ldr r8, [sp, #32]  // parity
	orr r7, r7, r8

	// Write it out
	ldr r8, [sp, #36]  // output
	bl storem

	add sp, sp, #44
	pop {r4-r11, pc}

	.size ed25519_compress, .-ed25519_compress


// in: *r0 = output (may be unaligned)
// in: *r1 = input (aligned)
// out: r0 = success
	.type ed25519_decompress, %function
ed25519_decompress:
	.global ed25519_decompress
	push {r0, r4-r11, lr}

	bl loadm
	lsr r8, r7, 31 // Topmost y bit is the parity bit
	push {r8}
	bic r7, #0x80000000 // remove it
	ldr r8, [sp, #4]
	add r8, r8, #32
	stm r8, {r0-r7}  // Store Y

	bl fe25519_sqr
	push {r0-r7}
	// stack: y^2

	mov r8, sp
    ldr r9, =FE25519_ONE
	bl fe25519_sub
	bl fe25519_reduce
	push {r0-r7}
	// u = y^2 - 1
	// stack: u y^2

	add r1, sp, #32
    ldr r2, =ED25519_D
	bl fe25519_mul
	add r8, sp, #32
	stm r8, {r0-r7}
	// stack: u d*y^2

	add r8, sp, #32
    ldr r9, =FE25519_ONE
	bl fe25519_add
	add r8, sp, #32
	stm r8, {r0-r7}
	// u = d*y2 + 1
	// stack: u v
	
	bl fe25519_sqr
	push {r0-r7}
	// stack: v2 u v

	mov r1, sp
	add r2, sp, #64
	bl fe25519_mul
	stm sp, {r0-r7}
	// stack: v3 u v

	bl fe25519_sqr
	push {r0-r7}
	// stack: v6 v3 u v

	mov r1, sp
	add r2, sp, #96
	bl fe25519_mul
	stm sp, {r0-r7}
	// stack: v7 v3 u v

	mov r1, sp
	add r2, sp, #64
	bl fe25519_mul
	stm sp, {r0-r7}
	// stack: uv7 v3 u v

	mov r1, sp
	bl fe25519_pow2523
	stm sp, {r0-r7}
	// stack: uv7^((P-5)//8) v3 u v

	mov r1, sp
	add r2, sp, #64
	bl fe25519_mul
	stm sp, {r0-r7}
	// stack: u*uv7^((P-5)//8) v3 u v

	mov r1, sp
	add r2, sp, #32
	bl fe25519_mul
	add r8, sp, #32
	stm r8, {r0-r7}
	// x = u*v3*uv7^((P-5)//8)
	// stack: _ x u v

	bl fe25519_sqr
	stm sp, {r0-r7}
	// stack: x2 x u v

	mov r1, sp
	add r2, sp, #96
	bl fe25519_mul
	bl fe25519_reduce
	stm sp, {r0-r7}
	// stack: vx2 x u v

	add r8, sp, #64
	bl fe25519_eq
	beq found

	ldm sp, {r0-r7}
	bl fe25519_neg
	bl fe25519_reduce
	add r8, sp, #64
	bl fe25519_eq
	bne fail

	add r1, sp, #32
	ldr r2, =FE25519_SQRTM1
	bl fe25519_mul
	b found2
	
found:
	add r8, sp, #32
	ldm r8, {r0-r7}

found2:
	add sp, sp, #128
	pop {r8} // parity bit
	and r9, r0, #1
	cmp r9, r8
	beq done
	bl fe25519_neg
done:
	ldr r8, [sp]
	stm r8, {r0-r7}  // Store X
	
	mov r1, r8
	add r2, r1, #32
	bl fe25519_mul
	ldr r8, [sp]
	add r8, r8, #96
	stm r8, {r0-r7}  // Store T=X*Y

	mov r0, #1
	mov r1, #0
	mov r2, #0
	mov r3, #0
	mov r4, #0
	mov r5, #0
	mov r6, #0
	mov r7, #0
	ldr r8, [sp]
	add r8, r8, #64
	stm r8, {r0-r7}  // Store Z=1

	mov r0, #1
	add sp, sp, #4
	pop {r4-r11, pc}
	
fail:
	mov r0, #0
	add sp, sp, #136
	pop {r4-r11, pc}

	.size ed25519_decompress, .-ed25519_decompress


// in: *r0 = point
	.type ed25519_neg, %function
ed25519_neg:
	.global ed25519_neg

	push {r4-r11, lr}

	mov r10, r0

	// negate x
	ldm r10, {r0-r7}
	bl fe25519_neg
	stm r10, {r0-r7}

	// negate t
	add r10, r10, #96
	ldm r10, {r0-r7}
	bl fe25519_neg
	stm r10, {r0-r7}

	pop {r4-r11, pc}

	.size ed25519_neg, .-ed25519_neg


.align 4
ED25519_D:      .byte 0xa3, 0x78, 0x59, 0x13, 0xca, 0x4d, 0xeb, 0x75, 0xab, 0xd8, 0x41, 0x41, 0x4d, 0x0a, 0x70, 0x00, 0x98, 0xe8, 0x79, 0x77, 0x79, 0x40, 0xc7, 0x8c, 0x73, 0xfe, 0x6f, 0x2b, 0xee, 0x6c, 0x03, 0x52
ED25519_D2:     .byte 0x59, 0xf1, 0xb2, 0x26, 0x94, 0x9b, 0xd6, 0xeb, 0x56, 0xb1, 0x83, 0x82, 0x9a, 0x14, 0xe0, 0x00, 0x30, 0xd1, 0xf3, 0xee, 0xf2, 0x80, 0x8e, 0x19, 0xe7, 0xfc, 0xdf, 0x56, 0xdc, 0xd9, 0x06, 0x24
FE25519_SQRTM1: .byte 0xb0, 0xa0, 0x0e, 0x4a, 0x27, 0x1b, 0xee, 0xc4, 0x78, 0xe4, 0x2f, 0xad, 0x06, 0x18, 0x43, 0x2f, 0xa7, 0xd7, 0xfb, 0x3d, 0x99, 0x00, 0x4d, 0x2b, 0x0b, 0xdf, 0xc1, 0x4f, 0x80, 0x24, 0x83, 0x2b
FE25519_ONE:    .byte 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
FE25519_TWO:    .byte 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
