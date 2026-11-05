#!/usr/bin/env python3
# DES decryption with verbose debugging.
# Inputs: 64-bit key and 64-bit ciphertext as bit strings ("0"/"1").
# Output: 64-bit plaintext bitstring, plus detailed intermediate prints.

# ------------------------
# DES Tables (same as encryption)
# ------------------------

IP_TABLE = [
    58, 50, 42, 34, 26, 18, 10,  2,
    60, 52, 44, 36, 28, 20, 12,  4,
    62, 54, 46, 38, 30, 22, 14,  6,
    64, 56, 48, 40, 32, 24, 16,  8,
    57, 49, 41, 33, 25, 17,  9,  1,
    59, 51, 43, 35, 27, 19, 11,  3,
    61, 53, 45, 37, 29, 21, 13,  5,
    63, 55, 47, 39, 31, 23, 15,  7
]

FP_TABLE = [
    40,  8, 48, 16, 56, 24, 64, 32,
    39,  7, 47, 15, 55, 23, 63, 31,
    38,  6, 46, 14, 54, 22, 62, 30,
    37,  5, 45, 13, 53, 21, 61, 29,
    36,  4, 44, 12, 52, 20, 60, 28,
    35,  3, 43, 11, 51, 19, 59, 27,
    34,  2, 42, 10, 50, 18, 58, 26,
    33,  1, 41,  9, 49, 17, 57, 25
]

E_TABLE = [
    32,  1,  2,  3,  4,  5,
     4,  5,  6,  7,  8,  9,
     8,  9, 10, 11, 12, 13,
    12, 13, 14, 15, 16, 17,
    16, 17, 18, 19, 20, 21,
    20, 21, 22, 23, 24, 25,
    24, 25, 26, 27, 28, 29,
    28, 29, 30, 31, 32,  1
]

P_TABLE = [
    16,  7, 20, 21,
    29, 12, 28, 17,
     1, 15, 23, 26,
     5, 18, 31, 10,
     2,  8, 24, 14,
    32, 27,  3,  9,
    19, 13, 30,  6,
    22, 11,  4, 25
]

PC1_TABLE = [
    57, 49, 41, 33, 25, 17,  9,
     1, 58, 50, 42, 34, 26, 18,
    10,  2, 59, 51, 43, 35, 27,
    19, 11,  3, 60, 52, 44, 36,
    63, 55, 47, 39, 31, 23, 15,
     7, 62, 54, 46, 38, 30, 22,
    14,  6, 61, 53, 45, 37, 29,
    21, 13,  5, 28, 20, 12,  4
]

PC2_TABLE = [
    14, 17, 11, 24,  1,  5,
     3, 28, 15,  6, 21, 10,
    23, 19, 12,  4, 26,  8,
    16,  7, 27, 20, 13,  2,
    41, 52, 31, 37, 47, 55,
    30, 40, 51, 45, 33, 48,
    44, 49, 39, 56, 34, 53,
    46, 42, 50, 36, 29, 32
]

SHIFTS = [1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1]

S_BOXES = [
    # S1
    [
        [14,4,13,1,2,15,11,8,3,10,6,12,5,9,0,7],
        [0,15,7,4,14,2,13,1,10,6,12,11,9,5,3,8],
        [4,1,14,8,13,6,2,11,15,12,9,7,3,10,5,0],
        [15,12,8,2,4,9,1,7,5,11,3,14,10,0,6,13]
    ],
    # S2
    [
        [15,1,8,14,6,11,3,4,9,7,2,13,12,0,5,10],
        [3,13,4,7,15,2,8,14,12,0,1,10,6,9,11,5],
        [0,14,7,11,10,4,13,1,5,8,12,6,9,3,2,15],
        [13,8,10,1,3,15,4,2,11,6,7,12,0,5,14,9]
    ],
    # S3
    [
        [10,0,9,14,6,3,15,5,1,13,12,7,11,4,2,8],
        [13,7,0,9,3,4,6,10,2,8,5,14,12,11,15,1],
        [13,6,4,9,8,15,3,0,11,1,2,12,5,10,14,7],
        [1,10,13,0,6,9,8,7,4,15,14,3,11,5,2,12]
    ],
    # S4
    [
        [7,13,14,3,0,6,9,10,1,2,8,5,11,12,4,15],
        [13,8,11,5,6,15,0,3,4,7,2,12,1,10,14,9],
        [10,6,9,0,12,11,7,13,15,1,3,14,5,2,8,4],
        [3,15,0,6,10,1,13,8,9,4,5,11,12,7,2,14]
    ],
    # S5
    [
        [2,12,4,1,7,10,11,6,8,5,3,15,13,0,14,9],
        [14,11,2,12,4,7,13,1,5,0,15,10,3,9,8,6],
        [4,2,1,11,10,13,7,8,15,9,12,5,6,3,0,14],
        [11,8,12,7,1,14,2,13,6,15,0,9,10,4,5,3]
    ],
    # S6
    [
        [12,1,10,15,9,2,6,8,0,13,3,4,14,7,5,11],
        [10,15,4,2,7,12,9,5,6,1,13,14,0,11,3,8],
        [9,14,15,5,2,8,12,3,7,0,4,10,1,13,11,6],
        [4,3,2,12,9,5,15,10,11,14,1,7,6,0,8,13]
    ],
    # S7
    [
        [4,11,2,14,15,0,8,13,3,12,9,7,5,10,6,1],
        [13,0,11,7,4,9,1,10,14,3,5,12,2,15,8,6],
        [1,4,11,13,12,3,7,14,10,15,6,8,0,5,9,2],
        [6,11,13,8,1,4,10,7,9,5,0,15,14,2,3,12]
    ],
    # S8
    [
        [13,2,8,4,6,15,11,1,10,9,3,14,5,0,12,7],
        [1,15,13,8,10,3,7,4,12,5,6,11,0,14,9,2],
        [7,11,4,1,9,12,14,2,0,6,10,13,15,3,5,8],
        [2,1,14,7,4,10,8,13,15,12,9,0,3,5,6,11]
    ]
]

# ------------------------
# Helper functions
# ------------------------

def permute(bits: str, table) -> str:
    """Apply permutation table (1-based indices) to bit-string."""
    return ''.join(bits[i-1] for i in table)

def left_shift(bits: str, n: int) -> str:
    """Circular left shift by n bits."""
    n = n % len(bits)
    return bits[n:] + bits[:n]

def xor_bits(a: str, b: str) -> str:
    """Bitwise XOR of two equal-length bit-strings."""
    return ''.join('1' if x != y else '0' for x, y in zip(a, b))

def bits_to_hex(bits: str) -> str:
    """Convert bit-string to hex (no 0x prefix)."""
    return format(int(bits, 2), f'0{len(bits)//4}X')

def sbox_substitution(bits48: str) -> str:
    """Apply 8 S-boxes to 48-bit string, return 32-bit string."""
    out = ''
    for i in range(8):
        block = bits48[6*i:6*(i+1)]
        row = int(block[0] + block[5], 2)
        col = int(block[1:5], 2)
        val = S_BOXES[i][row][col]
        out += format(val, '04b')
    return out

# ------------------------
# Core DES steps (same key schedule as encryption)
# ------------------------

def generate_subkeys_verbose(key64: str):
    """Generate 16 48-bit round keys from 64-bit key. Print intermediates."""
    print("=== KEY SCHEDULE ===")
    print(f"Original key (64b): {key64} (hex: {bits_to_hex(key64)})")

    # PC-1: 64 -> 56 bits
    key56 = permute(key64, PC1_TABLE)
    print(f"After PC1 (56b):  {key56}")
    print(f"PC1 hex:          {bits_to_hex(key56)}")

    C = key56[:28]
    D = key56[28:]

    subkeys = []
    for r in range(16):
        C = left_shift(C, SHIFTS[r])
        D = left_shift(D, SHIFTS[r])
        cd_combined = C + D
        Ki = permute(cd_combined, PC2_TABLE)
        subkeys.append(Ki)

        print(f"\n-- Round {r+1} key schedule --")
        print(f"C{r+1} (28b): {C}")
        print(f"D{r+1} (28b): {D}")
        print(f"K{r+1} (48b): {Ki}")
        print(f"K{r+1} hex :  {bits_to_hex(Ki)}")

    print("=== END KEY SCHEDULE ===\n")
    return subkeys

def f_function_core(R: str, subkey: str):
    """Core f-function: no prints, returns all intermediates."""
    expanded = permute(R, E_TABLE)
    xored    = xor_bits(expanded, subkey)
    s_out    = sbox_substitution(xored)
    p_out    = permute(s_out, P_TABLE)
    return expanded, xored, s_out, p_out

def f_function_verbose_dec(R: str, subkey: str, round_idx: int, key_idx: int):
    """Feistel f-function for decryption with debug prints."""
    print(f"  f() input R{round_idx-1} (32b): {bits_to_hex(R)}")
    expanded, xored, s_out, p_out = f_function_core(R, subkey)
    print(f"  After E (48b):         {bits_to_hex(expanded)}")
    print(f"  Using K{key_idx} (48b): {bits_to_hex(subkey)}")
    print(f"  After XOR with K{key_idx}: {bits_to_hex(xored)}")
    print(f"  After S-boxes (32b):   {bits_to_hex(s_out)}")
    print(f"  After P (32b):         {bits_to_hex(p_out)}")
    return p_out

# ------------------------
# DES decryption
# ------------------------

def des_decrypt_verbose(key_bits: str, ciphertext_bits: str) -> str:
    """DES decryption with verbose intermediate logging."""
    assert len(key_bits) == 64 and set(key_bits) <= {'0','1'}
    assert len(ciphertext_bits) == 64 and set(ciphertext_bits) <= {'0','1'}

    print("=== DES DECRYPTION DEBUG ===")
    print(f"Ciphertext (64b): {ciphertext_bits} (hex: {bits_to_hex(ciphertext_bits)})")

    # 1. Key schedule (same as encryption)
    subkeys = generate_subkeys_verbose(key_bits)
    # For decryption, we use subkeys in reverse order
    dec_subkeys = list(reversed(subkeys))

    # 2. Initial Permutation on ciphertext
    ip = permute(ciphertext_bits, IP_TABLE)
    L = ip[:32]
    R = ip[32:]
    print("=== INITIAL PERMUTATION (IP) ===")
    print(f"IP output (64b): {bits_to_hex(ip)}")
    print(f"L0 (32b):        {bits_to_hex(L)}")
    print(f"R0 (32b):        {bits_to_hex(R)}\n")

    # 3. 16 Feistel rounds with K16..K1
    for r in range(1, 17):
        # logical round r uses subkey K_(17-r)
        key_idx = 17 - r
        subkey  = dec_subkeys[r-1]

        print(f"=== ROUND {r} (using K{key_idx}) ===")
        print(f"L{r-1} (32b): {bits_to_hex(L)}")
        print(f"R{r-1} (32b): {bits_to_hex(R)}")

        f_out = f_function_verbose_dec(R, subkey, r, key_idx)
        newL = R
        newR = xor_bits(L, f_out)

        print(f"  New L{r} (32b): {bits_to_hex(newL)}")
        print(f"  New R{r} (32b): {bits_to_hex(newR)}\n")

        L, R = newL, newR

    # 4. Final swap (R16, L16) and Final Permutation
    preoutput = R + L
    print("=== PRE-OUTPUT (swap L16,R16) ===")
    print(f"R16||L16 (64b): {bits_to_hex(preoutput)}")
    plain_bits = permute(preoutput, FP_TABLE)
    print("=== FINAL PERMUTATION (FP) ===")
    print(f"Plaintext (64b): {plain_bits}")
    print(f"Plaintext hex  : {bits_to_hex(plain_bits)}")
    print("=== END DES DECRYPTION DEBUG ===")

    return plain_bits

# ------------------------
# Simple CLI / test harness
# ------------------------

if __name__ == "__main__":
    print("Enter 64-bit key and ciphertext as bit strings (e.g. 0110...).")
    key_bits = input("Key (64 bits)         : ").strip()
    ciphertext_bits = input("Ciphertext (64 bits)   : ").strip()

    if len(key_bits) != 64 or set(key_bits) - {'0','1'}:
        raise ValueError("Key must be a 64-bit string of 0/1.")
    if len(ciphertext_bits) != 64 or set(ciphertext_bits) - {'0','1'}:
        raise ValueError("Ciphertext must be a 64-bit string of 0/1.")

    des_decrypt_verbose(key_bits, ciphertext_bits)

    # Example usage with hex (uncomment if you want a self-test):
    # key_hex = 0x133457799BBCDFF1
    # ct_hex  = 0x85E813540F0AB405  # ciphertext from the standard test
    # key_bits = format(key_hex, '064b')
    # ct_bits  = format(ct_hex,  '064b')
    # des_decrypt_verbose(key_bits, ct_bits)
