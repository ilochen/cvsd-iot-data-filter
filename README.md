# Streaming IoT data filter

NTU CVSD project 4 implements four functions on an 8-bit input stream. Alternating 128-bit input registers let one block feed the DES operation while the next block arrives. `iot_out` carries the result when `valid` is asserted.

| fn_sel | Function | Output |
|---|---|---|
| 001 | DES encryption | 64-bit input key concatenated with the encrypted 64-bit block |
| 010 | DES decryption | 64-bit input key concatenated with the decrypted 64-bit block |
| 011 | Polynomial checksum | Three-bit remainder with polynomial 1101 (x³ + x² + 1) |
| 100 | Byte sort | Sixteen bytes ordered largest first when the output word is printed MSB first |

The DES module uses the DES permutations, key rotations and Feistel round function. Encryption and decryption traverse the subkeys in opposite directions. The checksum processes one input byte at a time, and insertion sort maintains a 16-element register sequence.

## Run

With Verilator 5, a C++ compiler and Make, run `make test`. The testbench streams all 64 supplied 128-bit vectors least-significant byte first, observes the busy/valid protocol, and compares all 64 output words in each of the four modes. It checks 256 results in total. A timeout or mismatch fails the run.

## Files

The private repository also contains the reviewed mapped connectivity in `synthesis/IOTDF_syn.v`. See [source provenance](docs/provenance.md) for the artifact inventory.

- `rtl/IOTDF.v` contains the original top module, DES, comparator and checksum logic.
- `model/des_encrypt.py` and `model/des_decrypt.py` are the original verbose DES round-reference utilities from the course workspace. Each exports a function accepting two 64-character binary strings and prints intermediate results.
- `tests/filter_tb.sv` is a portable check against the supplied `tests/pattern1_data/` input and answer files.

The original report lists a 12 ns target clock. This repository verifies RTL functionality and does not require a proprietary cell library.
