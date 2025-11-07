# Compression Analysis

## Test Results for testapp.wasm (1748 bytes)

### Stripping Results

| Mode | Stripped Size | Reduction | Metadata Size |
|------|--------------|-----------|---------------|
| Normal | 1571 bytes | 10.1% | 1865 bytes |
| Aggressive | 1387 bytes | 20.7% | 2451 bytes |

### Compression Results

#### Normal Mode Stripped File (1571 bytes)

| Algorithm | Compressed Size | Compression Ratio | Total with Metadata |
|-----------|----------------|-------------------|---------------------|
| gzip -9 | 935 bytes | 59.5% | 2800 bytes |
| bzip2 -9 | 1011 bytes | 64.4% | 2876 bytes |
| xz -9 | 900 bytes | 57.3% | 2765 bytes |
| zstd -19 | 891 bytes | 56.7% | 2756 bytes |

**Best: zstd -19** at 891 bytes (56.7% of stripped, 51.0% of original)

#### Aggressive Mode Stripped File (1387 bytes)

| Algorithm | Compressed Size | Compression Ratio | Total with Metadata |
|-----------|----------------|-------------------|---------------------|
| gzip -9 | 798 bytes | 57.5% | 3249 bytes |
| bzip2 -9 | 826 bytes | 59.6% | 3277 bytes |
| xz -9 | 772 bytes | 55.7% | 3223 bytes |
| zstd -19 | 755 bytes | 54.4% | 3206 bytes |

**Best: zstd -19** at 755 bytes (54.4% of stripped, 43.2% of original)

### Key Findings

1. **Aggressive mode provides better compression**: The stripped file compresses to 755 bytes vs 891 bytes for normal mode (15% better)

2. **Metadata overhead**: For small files like this test case, metadata size (1865-2451 bytes) exceeds the stripped file size, making the total larger than the original

3. **Best algorithm: zstd**: Consistently provides the best compression ratios at maximum settings

4. **Compression effectiveness**: Both modes achieve ~55% compression of the stripped WASM bytecode

### Recommendations

#### For Small Files (<5KB)
- Use **normal mode** if you need to inspect the WASM with tools
- Consider **no stripping** if total size (stripped + metadata) exceeds original
- Compression alone (without stripping) may be more effective

#### For Medium Files (5KB-100KB)
- Use **aggressive mode** for maximum size reduction
- Combine with **zstd -19** for best results
- Metadata overhead becomes negligible

#### For Large Files (>100KB)
- **Aggressive mode + zstd** provides significant savings
- Metadata size becomes insignificant compared to file size
- Can achieve 50%+ total size reduction

### Compression Command Examples

```bash
# Normal mode with zstd
python3 wasm_stripper.py strip input.wasm -o stripped.wasm -m metadata.json
zstd -19 stripped.wasm

# Aggressive mode with zstd
python3 wasm_stripper.py strip input.wasm -o stripped.wasm -m metadata.json --aggressive
zstd -19 stripped.wasm

# Decompress and reassemble
zstd -d stripped.wasm.zst
python3 wasm_stripper.py reassemble stripped.wasm metadata.json -o output.wasm
```

### Performance Notes

- **zstd -19**: Slowest compression, best ratio, fast decompression
- **xz -9**: Very slow compression, good ratio, slow decompression
- **gzip -9**: Fast compression, moderate ratio, fast decompression
- **bzip2 -9**: Moderate speed, moderate ratio

For production use, **zstd** offers the best balance of compression ratio and decompression speed.
