# WASM Stripper

A Python tool for stripping metadata from WebAssembly (WASM) files and reassembling them. This tool helps reduce WASM file sizes by separating code from metadata, which can be particularly useful for distribution, storage, or obfuscation purposes.

## Features

- **Two Stripping Modes:**
  - **Normal Mode**: Strips Type, Import, and Export sections (~10% size reduction)
  - **Aggressive Mode**: Strips everything except Code section (~20% size reduction)
- **Lossless Reassembly**: Perfectly reconstructs original WASM files
- **JSON Metadata**: Stores stripped sections in human-readable JSON format
- **Section Ordering**: Maintains proper WASM section ordering during reassembly

## Installation

### Requirements

- Python 3.7+
- No external dependencies (uses only Python standard library)

### Optional Tools

- `wasm-objdump` (from WABT) - for WASM file inspection
- Compression tools: `gzip`, `bzip2`, `xz`, `zstd` - for additional size reduction

## Usage

### Strip a WASM File (Normal Mode)

```bash
python3 wasm_stripper.py strip input.wasm -o stripped.wasm -m metadata.json
```

This strips Type, Import, and Export sections while keeping Function, Table, Memory, Global, Element, Code, and Data sections.

### Strip a WASM File (Aggressive Mode)

```bash
python3 wasm_stripper.py strip input.wasm -o stripped.wasm -m metadata.json --aggressive
```

This keeps **only** the Code section, storing all other sections as base64-encoded data in the metadata JSON.

### Reassemble a WASM File

```bash
python3 wasm_stripper.py reassemble stripped.wasm metadata.json -o output.wasm
```

Reconstructs the original WASM file from the stripped version and metadata. Works with both normal and aggressive modes.

## Command Line Options

### Strip Command

```
python3 wasm_stripper.py strip <input> -o <output> -m <metadata> [--aggressive]

Arguments:
  input                 Input WASM file
  -o, --output         Output stripped WASM file
  -m, --metadata       Output metadata JSON file
  -a, --aggressive     Enable aggressive mode (only keep Code section)
```

### Reassemble Command

```
python3 wasm_stripper.py reassemble <stripped> <metadata> -o <output>

Arguments:
  stripped             Stripped WASM file
  metadata             Metadata JSON file
  -o, --output         Output reassembled WASM file
```

## How It Works

### WASM Section Structure

WebAssembly files consist of multiple sections:

1. **Type** (1) - Function signatures
2. **Import** (2) - Imported functions, tables, memories, globals
3. **Function** (3) - Function type indices
4. **Table** (4) - Table definitions
5. **Memory** (5) - Memory definitions
6. **Global** (6) - Global variable definitions
7. **Export** (7) - Exported functions, tables, memories, globals
8. **Start** (8) - Start function index
9. **Element** (9) - Table element initialization
10. **Code** (10) - Function bytecode
11. **Data** (11) - Memory initialization data

### Normal Mode

Strips sections that contain metadata about the module's interface:
- Type section (function signatures)
- Import section (external dependencies)
- Export section (public API)

Keeps sections needed for execution:
- Function, Table, Memory, Global, Element, Code, Data

### Aggressive Mode

Strips everything except the Code section, which contains the actual function bytecode. All other sections are stored as base64-encoded binary data in the metadata JSON.

This mode provides maximum size reduction but results in a WASM file that cannot be validated or inspected without reassembly.

## Size Reduction Examples

Based on testapp.wasm (1748 bytes):

### Stripping Results

| Mode | Stripped Size | Reduction | Metadata Size |
|------|--------------|-----------|---------------|
| Normal | 1571 bytes | 10.1% | 1865 bytes |
| Aggressive | 1387 bytes | 20.7% | 2451 bytes |

### Compression Results

Best compression of stripped files (vs original 1748 bytes):

| Mode | Algorithm | Compressed Size | vs Original |
|------|-----------|----------------|-------------|
| Normal | zstd -19 | 891 bytes | 51.0% |
| Normal | xz -9 | 900 bytes | 51.5% |
| Normal | gzip -9 | 935 bytes | 53.5% |
| Aggressive | zstd -19 | 755 bytes | 43.2% |
| Aggressive | xz -9 | 772 bytes | 44.2% |
| Aggressive | gzip -9 | 798 bytes | 45.7% |

**Key Findings:**
- **Aggressive mode + zstd** achieves the best compression: **755 bytes (43.2% of original)**
- Aggressive mode compresses ~15% better than normal mode
- zstd provides the best compression ratio with fast decompression
- For distribution, ship the compressed stripped WASM + metadata JSON separately

## Testing

Run the comprehensive test suite:

```bash
chmod +x test.sh
./test.sh
```

The test suite:
1. Tests normal mode stripping and reassembly
2. Tests aggressive mode stripping and reassembly
3. Verifies binary identity with `cmp`
4. Validates WASM structure with `wasm-objdump`
5. Tests compression with gzip, bzip2, xz, and zstd
6. Provides detailed size comparison reports

## Use Cases

### 1. Distribution Size Reduction
Strip metadata before distributing WASM files, then reassemble on the client side.

### 2. Code Obfuscation
Aggressive mode removes all function names, imports, and exports, making reverse engineering more difficult.

### 3. Storage Optimization
Store stripped WASM files with compressed metadata for long-term archival.

### 4. Build Pipeline Integration
Integrate into build systems to automatically strip debug information from production builds.

## Limitations

- Custom sections (like the name section) are always discarded
- Stripped WASM files cannot be validated without reassembly
- Aggressive mode files cannot be inspected with standard WASM tools
- Metadata must be distributed alongside the stripped WASM file
- Best results achieved with larger WASM files (>10KB) where metadata overhead is proportionally smaller

## Technical Details

### Metadata Format

The metadata JSON contains:
- WASM version number
- Parsed sections (Type, Import, Export)
- Base64-encoded binary sections (aggressive mode only)

Example metadata structure:

```json
{
  "version": 1,
  "sections": {
    "type": [...],
    "import": [...],
    "export": [...],
    "section_3": {
      "id": 3,
      "data": "base64-encoded-data"
    }
  }
}
```

### Section Ordering

The reassembler ensures sections are written in the correct order as required by the WASM specification. Sections must appear in ascending order by section ID.

## Contributing

Contributions are welcome! Areas for improvement:
- Support for more section types (Start, Data Count)
- Custom section preservation options
- Streaming processing for large files
- Additional compression algorithms
- Performance optimizations

## License

This project is provided as-is for educational and practical use.

## See Also

- [WebAssembly Specification](https://webassembly.github.io/spec/)
- [WABT - WebAssembly Binary Toolkit](https://github.com/WebAssembly/wabt)
- [wasm-opt](https://github.com/WebAssembly/binaryen) - Alternative optimization tool
