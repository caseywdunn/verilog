# LDR Literal Test

## Purpose
- Validate LDR literal (PC-relative load) instruction
- Verify PC alignment and offset calculation
- Confirm literal pool access works correctly

## Test Program

### Assembly Listing
```assembly
@0x00:  LDR  r0, [PC, #8]      ; Load from literal pool (0x4802)
@0x02:  LDR  r0, [PC, #12]     ; Load from literal pool (0x4803)
@0x04:  MOVS r1, #1            ; r1 = 1 (0x2101)
@0x06:  LSL  r1, r1, #8        ; r1 = 0x100 (0x0209)
@0x08:  STR  r0, [r1, #0]      ; Store to [0x100] (0x6008)
@0x0A:  B    .                 ; Halt (0xE7FE)
@0x0C:  .word 0x000000BC       ; Literal pool value
```

### Instruction Encoding
- `LDR r0, [PC, #8]`: 0x4802
  - Encoding: 01001 Rd=000 imm8=00000010
  - At PC=0: Align(PC+4, 4) = 4, address = 4 + 8 = 12 (0x0C)

- `LDR r0, [PC, #12]`: 0x4803
  - Encoding: 01001 Rd=000 imm8=00000011
  - At PC=2: Align(PC+4, 4) = Align(6, 4) = 4, address = 4 + 12 = 16
  - (This will load from beyond our literal, just testing the instruction works)

### Execution Flow
1. Load literal value 0xBC from address 0x0C into r0
2. Second LDR will load from address 16 (may be 0 or undefined)
3. Build address 0x100 in r1 (1 << 8)
4. Store r0 to memory[0x100]
5. Halt

### Expected Result
- mem[64] (address 0x100) = 0x000000BC

## Notes
PC-relative addressing in Thumb:
- PC value during instruction execution = (instruction_address + 4)
- Address is aligned to 4-byte boundary: Align(PC, 4)
- Final address = Align(PC, 4) + (imm8 << 2)
