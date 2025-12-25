# Thumb-1 Architecture Reference

This document provides a reference for the Thumb-1 instruction set architecture, including encoding formats and implementation status.

## CPU Architecture Overview

### Execution model

The core is multi-cycle (not pipelined). Instructions execute over a small
finite-state machine:

  1. FETCH    Issue memory read for instruction at PC
  2. WAITI    Wait for synchronous memory read (1-cycle latency)
  3. DECODE   Decode opcode and latch operands/immediates
  4. EXEC     Perform ALU operation or compute address/branch target
  5. MEM      Issue data memory operation (LDR/STR only)
  6. WAITM    Wait for synchronous memory read on loads
  7. FETCH    Next instruction

The PC advances by 2 bytes per instruction (Thumb semantics).

Wait states (WAITI, WAITM) handle the 1-cycle read latency of synchronous
block RAM, matching real FPGA memory timing.

### Registers and flags

- Registers R0–R15 stored internally
- R15 mirrors PC for debug visibility
- Flags: N, Z, C, V
  - Updated by ADD, SUB, CMP, shifts, and logical ops as implemented

## Machine Code Format

Thumb-1 instructions are **16 bits wide** (halfwords), providing a compact encoding:
- Instructions are aligned to 2-byte boundaries
- PC increments by 2 for each instruction
- Instructions stored in memory as 16-bit halfwords within 32-bit words
- Little-endian byte order: lower halfword executes first

Common encoding features across all instructions:
- Bits [15:0] contain the full instruction
- High bits typically encode instruction type/opcode
- Low bits typically encode operands (registers, immediates)
- Most instructions update condition flags (N, Z, C, V)
- Register operands use 3 bits (R0-R7 for low registers)

## 1. Shift and Rotate Instructions

Encoding format: `000 OP[1:0] imm5[4:0] Rm[2:0] Rd[2:0]`
- Bits [15:13] = 000 (shift/rotate group)
- Bits [12:11] = operation type
- Bits [10:6] = 5-bit immediate shift amount
- Bits [5:3] = source register Rm
- Bits [2:0] = destination register Rd

**Implemented:**
- ✅ **LSL Rd, Rm, #imm5** - Logical shift left
  - Encoding: `000 00 imm5 Rm Rd`
  - Flags: N, Z, C (if imm5≠0)

- ✅ **LSR Rd, Rm, #imm5** - Logical shift right
  - Encoding: `000 01 imm5 Rm Rd`
  - Flags: N, Z, C (if imm5≠0)

**Not Implemented:**
- ❌ **ASR Rd, Rm, #imm5** - Arithmetic shift right
  - Encoding: `000 10 imm5 Rm Rd`
  - Flags: N, Z, C (if imm5≠0)

## 2. Add/Subtract (Register and Immediate)

Encoding format: `00011 I Op Rn/imm3[2:0] Rm/Rs[2:0] Rd[2:0]`
- Bits [15:11] = 00011 (add/sub group)
- Bit [10] = I (0=register, 1=immediate)
- Bit [9] = Op (0=ADD, 1=SUB)
- Bits [8:6] = Rn (if I=0) or imm3 (if I=1)
- Bits [5:3] = Rm/Rs source register
- Bits [2:0] = Rd destination register

**Not Implemented:**
- ❌ **ADD Rd, Rs, Rn** - Add register to register
  - Encoding: `00011 0 0 Rn Rs Rd`
  - Flags: N, Z, C, V

- ❌ **SUB Rd, Rs, Rn** - Subtract register from register
  - Encoding: `00011 0 1 Rn Rs Rd`
  - Flags: N, Z, C, V

- ❌ **ADD Rd, Rs, #imm3** - Add 3-bit immediate
  - Encoding: `00011 1 0 imm3 Rs Rd`
  - Flags: N, Z, C, V

- ❌ **SUB Rd, Rs, #imm3** - Subtract 3-bit immediate
  - Encoding: `00011 1 1 imm3 Rs Rd`
  - Flags: N, Z, C, V

## 3. Add/Subtract/Compare/Move (8-bit Immediate)

Encoding format: `001 OP[1:0] Rd[2:0] imm8[7:0]`
- Bits [15:13] = 001 (immediate operations)
- Bits [12:11] = operation type
- Bits [10:8] = destination register Rd
- Bits [7:0] = 8-bit immediate value

**Implemented:**
- ✅ **MOVS Rd, #imm8** - Move immediate to register
  - Encoding: `001 00 Rd imm8`
  - Flags: N, Z

- ✅ **CMP Rd, #imm8** - Compare register with immediate
  - Encoding: `001 01 Rd imm8`
  - Flags: N, Z, C, V

- ✅ **ADDS Rd, #imm8** - Add immediate to register
  - Encoding: `001 10 Rd imm8`
  - Flags: N, Z, C, V

- ✅ **SUBS Rd, #imm8** - Subtract immediate from register
  - Encoding: `001 11 Rd imm8`
  - Flags: N, Z, C, V

## 4. ALU Operations (Register)

Encoding format: `010000 OP[3:0] Rs[2:0] Rd[2:0]`
- Bits [15:10] = 010000 (ALU operations)
- Bits [9:6] = operation type
- Bits [5:3] = source register Rs
- Bits [2:0] = destination register Rd

**Implemented:**
- ✅ **AND Rd, Rs** - Bitwise AND
  - Encoding: `010000 0000 Rs Rd`
  - Flags: N, Z

- ✅ **EOR Rd, Rs** - Bitwise exclusive OR
  - Encoding: `010000 0001 Rs Rd`
  - Flags: N, Z

- ✅ **ORR Rd, Rs** - Bitwise OR
  - Encoding: `010000 1100 Rs Rd`
  - Flags: N, Z

- ✅ **CMP Rd, Rs** - Compare registers
  - Encoding: `010000 1010 Rs Rd`
  - Flags: N, Z, C, V

**Not Implemented:**
- ❌ **LSL Rd, Rs** - Logical shift left by register
  - Encoding: `010000 0010 Rs Rd`
  - Flags: N, Z, C

- ❌ **LSR Rd, Rs** - Logical shift right by register
  - Encoding: `010000 0011 Rs Rd`
  - Flags: N, Z, C

- ❌ **ASR Rd, Rs** - Arithmetic shift right by register
  - Encoding: `010000 0100 Rs Rd`
  - Flags: N, Z, C

- ❌ **ADC Rd, Rs** - Add with carry
  - Encoding: `010000 0101 Rs Rd`
  - Flags: N, Z, C, V

- ❌ **SBC Rd, Rs** - Subtract with carry
  - Encoding: `010000 0110 Rs Rd`
  - Flags: N, Z, C, V

- ❌ **ROR Rd, Rs** - Rotate right by register
  - Encoding: `010000 0111 Rs Rd`
  - Flags: N, Z, C

- ❌ **TST Rd, Rs** - Test bits (AND without storing)
  - Encoding: `010000 1000 Rs Rd`
  - Flags: N, Z

- ❌ **NEG Rd, Rs** - Negate (0 - Rs)
  - Encoding: `010000 1001 Rs Rd`
  - Flags: N, Z, C, V

- ❌ **CMN Rd, Rs** - Compare negative (ADD without storing)
  - Encoding: `010000 1011 Rs Rd`
  - Flags: N, Z, C, V

- ❌ **MUL Rd, Rs** - Multiply
  - Encoding: `010000 1101 Rs Rd`
  - Flags: N, Z

- ❌ **BIC Rd, Rs** - Bit clear (AND NOT)
  - Encoding: `010000 1110 Rs Rd`
  - Flags: N, Z

- ❌ **MVN Rd, Rs** - Bitwise NOT
  - Encoding: `010000 1111 Rs Rd`
  - Flags: N, Z

## 5. Special Data Processing

Encoding format: `010001 OP[1:0] H1 H2 Rs/Hs[2:0] Rd/Hd[2:0]`
- Bits [15:10] = 010001 (special data operations)
- Bits [9:8] = operation type
- Bit [7] = H1 (high register flag for Rd)
- Bit [6] = H2 (high register flag for Rs)
- Bits [5:3] = source register
- Bits [2:0] = destination register

**Not Implemented:**
- ❌ **ADD Rd, Rs** - Add (high registers)
  - Encoding: `010001 00 H1 H2 Rs Rd`
  - Flags: none (unless Rd=R15)

- ❌ **CMP Rd, Rs** - Compare (high registers)
  - Encoding: `010001 01 H1 H2 Rs Rd`
  - Flags: N, Z, C, V

- ❌ **MOV Rd, Rs** - Move (high registers)
  - Encoding: `010001 10 H1 H2 Rs Rd`
  - Flags: none (unless Rd=R15)

- ❌ **BX Rs** - Branch and exchange
  - Encoding: `010001 11 0 H2 Rs 000`
  - Switches to ARM mode if bit[0] of Rs = 0

## 6. Load from Literal Pool (PC-relative)

Encoding format: `01001 Rd[2:0] imm8[7:0]`
- Bits [15:11] = 01001 (PC-relative load)
- Bits [10:8] = destination register Rd
- Bits [7:0] = 8-bit immediate offset (word-aligned)
- Address = Align(PC+4, 4) + (imm8 << 2)

**Implemented:**
- ✅ **LDR Rd, [PC, #imm8*4]** - Load from literal pool
  - Encoding: `01001 Rd imm8`
  - Loads 32-bit word from PC-relative address

## 7. Load/Store Register Offset

Encoding format: `0101 OP[2:0] Ro[2:0] Rb[2:0] Rd[2:0]`
- Bits [15:12] = 0101 (register offset group)
- Bits [11:9] = operation type
- Bits [8:6] = offset register Ro
- Bits [5:3] = base register Rb
- Bits [2:0] = data register Rd

**Not Implemented:**
- ❌ **STR Rd, [Rb, Ro]** - Store word
  - Encoding: `0101 000 Ro Rb Rd`

- ❌ **STRH Rd, [Rb, Ro]** - Store halfword
  - Encoding: `0101 001 Ro Rb Rd`

- ❌ **STRB Rd, [Rb, Ro]** - Store byte
  - Encoding: `0101 010 Ro Rb Rd`

- ❌ **LDRSB Rd, [Rb, Ro]** - Load sign-extended byte
  - Encoding: `0101 011 Ro Rb Rd`

- ❌ **LDR Rd, [Rb, Ro]** - Load word
  - Encoding: `0101 100 Ro Rb Rd`

- ❌ **LDRH Rd, [Rb, Ro]** - Load halfword
  - Encoding: `0101 101 Ro Rb Rd`

- ❌ **LDRB Rd, [Rb, Ro]** - Load byte
  - Encoding: `0101 110 Ro Rb Rd`

- ❌ **LDRSH Rd, [Rb, Ro]** - Load sign-extended halfword
  - Encoding: `0101 111 Ro Rb Rd`

## 8. Load/Store Immediate Offset

Encoding format: `011 B L imm5[4:0] Rb[2:0] Rd[2:0]`
- Bits [15:13] = 011 (immediate offset group)
- Bit [12] = B (0=word, 1=byte)
- Bit [11] = L (0=store, 1=load)
- Bits [10:6] = 5-bit immediate offset
- Bits [5:3] = base register Rb
- Bits [2:0] = data register Rd
- Word offset: address = Rb + (imm5 << 2)
- Byte offset: address = Rb + imm5

**Implemented:**
- ✅ **STR Rd, [Rb, #imm5*4]** - Store word
  - Encoding: `011 0 0 imm5 Rb Rd`

- ✅ **LDR Rd, [Rb, #imm5*4]** - Load word
  - Encoding: `011 0 1 imm5 Rb Rd`

**Not Implemented:**
- ❌ **STRB Rd, [Rb, #imm5]** - Store byte
  - Encoding: `011 1 0 imm5 Rb Rd`

- ❌ **LDRB Rd, [Rb, #imm5]** - Load byte
  - Encoding: `011 1 1 imm5 Rb Rd`

## 9. Load/Store Halfword (Immediate Offset)

Encoding format: `1000 L imm5[4:0] Rb[2:0] Rd[2:0]`
- Bits [15:12] = 1000 (halfword immediate offset)
- Bit [11] = L (0=store, 1=load)
- Bits [10:6] = 5-bit immediate offset (halfword-aligned)
- Bits [5:3] = base register Rb
- Bits [2:0] = data register Rd
- Address = Rb + (imm5 << 1)

**Not Implemented:**
- ❌ **STRH Rd, [Rb, #imm5*2]** - Store halfword
  - Encoding: `1000 0 imm5 Rb Rd`

- ❌ **LDRH Rd, [Rb, #imm5*2]** - Load halfword
  - Encoding: `1000 1 imm5 Rb Rd`

## 10. Load/Store SP-Relative

Encoding format: `1001 L Rd[2:0] imm8[7:0]`
- Bits [15:12] = 1001 (SP-relative)
- Bit [11] = L (0=store, 1=load)
- Bits [10:8] = data register Rd
- Bits [7:0] = 8-bit immediate offset (word-aligned)
- Address = SP + (imm8 << 2)

**Not Implemented:**
- ❌ **STR Rd, [SP, #imm8*4]** - Store to stack
  - Encoding: `1001 0 Rd imm8`

- ❌ **LDR Rd, [SP, #imm8*4]** - Load from stack
  - Encoding: `1001 1 Rd imm8`

## 11. Load Address

Encoding format: `1010 SP Rd[2:0] imm8[7:0]`
- Bits [15:12] = 1010 (load address)
- Bit [11] = SP (0=PC, 1=SP)
- Bits [10:8] = destination register Rd
- Bits [7:0] = 8-bit immediate offset (word-aligned)

**Not Implemented:**
- ❌ **ADD Rd, PC, #imm8*4** - Add PC and immediate
  - Encoding: `1010 0 Rd imm8`
  - Rd = Align(PC+4, 4) + (imm8 << 2)

- ❌ **ADD Rd, SP, #imm8*4** - Add SP and immediate
  - Encoding: `1010 1 Rd imm8`
  - Rd = SP + (imm8 << 2)

## 12. Miscellaneous Instructions

Encoding format: `1011 0000 OP imm7[6:0]`
- Bits [15:12] = 1011 (miscellaneous group)
- Bits [11:8] = 0000
- Bit [7] = OP (0=ADD, 1=SUB)
- Bits [6:0] = 7-bit immediate (word-aligned)

**Not Implemented:**
- ❌ **ADD SP, #imm7*4** - Add immediate to SP
  - Encoding: `1011 0000 0 imm7`
  - SP = SP + (imm7 << 2)

- ❌ **SUB SP, #imm7*4** - Subtract immediate from SP
  - Encoding: `1011 0000 1 imm7`
  - SP = SP - (imm7 << 2)

## 13. Push/Pop Registers

Encoding format: `1011 L 10 R reglist[7:0]`
- Bits [15:12] = 1011 (push/pop group)
- Bit [11] = L (0=push, 1=pop)
- Bits [10:9] = 10
- Bit [8] = R (PC/LR bit)
- Bits [7:0] = register list bitmap

**Not Implemented:**
- ❌ **PUSH {reglist}** - Push registers onto stack
  - Encoding: `1011 0 10 0 reglist`
  - Stores registers in ascending order

- ❌ **PUSH {reglist, LR}** - Push registers and LR
  - Encoding: `1011 0 10 1 reglist`

- ❌ **POP {reglist}** - Pop registers from stack
  - Encoding: `1011 1 10 0 reglist`
  - Loads registers in ascending order

- ❌ **POP {reglist, PC}** - Pop registers and PC (return)
  - Encoding: `1011 1 10 1 reglist`

## 14. Multiple Load/Store

Encoding format: `1100 L Rb[2:0] reglist[7:0]`
- Bits [15:12] = 1100 (multiple load/store)
- Bit [11] = L (0=store, 1=load)
- Bits [10:8] = base register Rb
- Bits [7:0] = register list bitmap

**Not Implemented:**
- ❌ **STMIA Rb!, {reglist}** - Store multiple, increment after
  - Encoding: `1100 0 Rb reglist`

- ❌ **LDMIA Rb!, {reglist}** - Load multiple, increment after
  - Encoding: `1100 1 Rb reglist`

## 15. Conditional Branches

Encoding format: `1101 cond[3:0] simm8[7:0]`
- Bits [15:12] = 1101 (conditional branch)
- Bits [11:8] = condition code
- Bits [7:0] = signed 8-bit offset
- Target = PC + 4 + (simm8 << 1)

**Implemented:**
- ✅ **BEQ label** - Branch if equal (Z=1)
  - Encoding: `1101 0000 simm8`
  - Condition: 0000 (EQ)

- ✅ **BNE label** - Branch if not equal (Z=0)
  - Encoding: `1101 0001 simm8`
  - Condition: 0001 (NE)

- ✅ **BMI label** - Branch if minus (N=1)
  - Encoding: `1101 0100 simm8`
  - Condition: 0100 (MI)

- ✅ **BPL label** - Branch if plus (N=0)
  - Encoding: `1101 0101 simm8`
  - Condition: 0101 (PL)

**Not Implemented:**
- ❌ **BCS/BHS label** - Branch if carry set / unsigned higher or same (C=1)
  - Encoding: `1101 0010 simm8`
  - Condition: 0010 (CS/HS)

- ❌ **BCC/BLO label** - Branch if carry clear / unsigned lower (C=0)
  - Encoding: `1101 0011 simm8`
  - Condition: 0011 (CC/LO)

- ❌ **BVS label** - Branch if overflow set (V=1)
  - Encoding: `1101 0110 simm8`
  - Condition: 0110 (VS)

- ❌ **BVC label** - Branch if overflow clear (V=0)
  - Encoding: `1101 0111 simm8`
  - Condition: 0111 (VC)

- ❌ **BHI label** - Branch if unsigned higher (C=1 and Z=0)
  - Encoding: `1101 1000 simm8`
  - Condition: 1000 (HI)

- ❌ **BLS label** - Branch if unsigned lower or same (C=0 or Z=1)
  - Encoding: `1101 1001 simm8`
  - Condition: 1001 (LS)

- ❌ **BGE label** - Branch if signed greater or equal (N=V)
  - Encoding: `1101 1010 simm8`
  - Condition: 1010 (GE)

- ❌ **BLT label** - Branch if signed less than (N≠V)
  - Encoding: `1101 1011 simm8`
  - Condition: 1011 (LT)

- ❌ **BGT label** - Branch if signed greater than (Z=0 and N=V)
  - Encoding: `1101 1100 simm8`
  - Condition: 1100 (GT)

- ❌ **BLE label** - Branch if signed less or equal (Z=1 or N≠V)
  - Encoding: `1101 1101 simm8`
  - Condition: 1101 (LE)

## 16. Software Interrupt

Encoding format: `1101 1111 imm8[7:0]`
- Bits [15:12] = 1101
- Bits [11:8] = 1111 (SWI condition code)
- Bits [7:0] = 8-bit immediate value

**Not Implemented:**
- ❌ **SWI #imm8** - Software interrupt
  - Encoding: `1101 1111 imm8`
  - Triggers software interrupt with immediate value

## 17. Unconditional Branch

Encoding format: `11100 simm11[10:0]`
- Bits [15:11] = 11100 (unconditional branch)
- Bits [10:0] = signed 11-bit offset
- Target = PC + 4 + (simm11 << 1)
- Range: ±2KB

**Implemented:**
- ✅ **B label** - Unconditional branch
  - Encoding: `11100 simm11`

## 18. Long Branch with Link

Two-instruction sequence for extended range branches:
- First instruction: `11110 offset_high[10:0]`
- Second instruction: `11111 offset_low[10:0]`
- Combined 22-bit offset for ±4MB range

**Not Implemented:**
- ❌ **BL label** - Branch with link (function call)
  - First: `11110 offset_high`
  - Second: `11111 offset_low`
  - LR = PC + 4, PC = PC + (offset << 1)
