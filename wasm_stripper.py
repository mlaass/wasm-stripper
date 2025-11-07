#!/usr/bin/env python3
"""
WebAssembly Stripper/Reassembler
Strips metadata from WASM files and saves it to JSON, or reassembles from stripped WASM + JSON
"""

import sys
import json
import struct
import argparse
from pathlib import Path
from typing import List, Dict, Tuple, Any

# WASM constants
WASM_MAGIC = 0x6D736100  # '\0asm'
WASM_VERSION = 1

# Section IDs
SECTION_CUSTOM = 0
SECTION_TYPE = 1
SECTION_IMPORT = 2
SECTION_FUNCTION = 3
SECTION_TABLE = 4
SECTION_MEMORY = 5
SECTION_GLOBAL = 6
SECTION_EXPORT = 7
SECTION_START = 8
SECTION_ELEMENT = 9
SECTION_CODE = 10
SECTION_DATA = 11
SECTION_DATA_COUNT = 12


class WASMReader:
    def __init__(self, data: bytes):
        self.data = data
        self.pos = 0

    def read_bytes(self, n: int) -> bytes:
        result = self.data[self.pos : self.pos + n]
        self.pos += n
        return result

    def read_u8(self) -> int:
        return self.read_bytes(1)[0]

    def read_u32(self) -> int:
        return struct.unpack("<I", self.read_bytes(4))[0]

    def read_varuint(self) -> int:
        result = 0
        shift = 0
        while True:
            byte = self.read_u8()
            result |= (byte & 0x7F) << shift
            if (byte & 0x80) == 0:
                break
            shift += 7
        return result

    def read_varint(self) -> int:
        result = 0
        shift = 0
        byte = 0
        while True:
            byte = self.read_u8()
            result |= (byte & 0x7F) << shift
            shift += 7
            if (byte & 0x80) == 0:
                break

        if shift < 64 and (byte & 0x40):
            result |= -(1 << shift)
        return result

    def read_name(self) -> str:
        length = self.read_varuint()
        return self.read_bytes(length).decode("utf-8")

    def at_end(self) -> bool:
        return self.pos >= len(self.data)


class WASMWriter:
    def __init__(self):
        self.data = bytearray()

    def write_bytes(self, data: bytes):
        self.data.extend(data)

    def write_u8(self, value: int):
        self.data.append(value & 0xFF)

    def write_u32(self, value: int):
        self.data.extend(struct.pack("<I", value))

    def write_varuint(self, value: int):
        while True:
            byte = value & 0x7F
            value >>= 7
            if value != 0:
                byte |= 0x80
            self.write_u8(byte)
            if value == 0:
                break

    def write_varint(self, value: int):
        more = True
        while more:
            byte = value & 0x7F
            value >>= 7
            if (value == 0 and (byte & 0x40) == 0) or (value == -1 and (byte & 0x40) != 0):
                more = False
            else:
                byte |= 0x80
            self.write_u8(byte)

    def write_name(self, name: str):
        encoded = name.encode("utf-8")
        self.write_varuint(len(encoded))
        self.write_bytes(encoded)

    def get_bytes(self) -> bytes:
        return bytes(self.data)


def parse_type_section(reader: WASMReader) -> List[Dict]:
    """Parse type section (function signatures)"""
    count = reader.read_varuint()
    types = []

    for _ in range(count):
        form = reader.read_u8()  # Should be 0x60 for func
        param_count = reader.read_varuint()
        params = [reader.read_varint() for _ in range(param_count)]
        return_count = reader.read_varuint()
        returns = [reader.read_varint() for _ in range(return_count)]

        types.append({"form": form, "params": params, "returns": returns})

    return types


def parse_import_section(reader: WASMReader) -> List[Dict]:
    """Parse import section"""
    count = reader.read_varuint()
    imports = []

    for _ in range(count):
        module = reader.read_name()
        field = reader.read_name()
        kind = reader.read_u8()

        import_entry = {"module": module, "field": field, "kind": kind}

        if kind == 0:  # Function
            import_entry["type_idx"] = reader.read_varuint()
        elif kind == 1:  # Table
            elem_type = reader.read_varint()
            limits_flags = reader.read_varuint()
            limits_initial = reader.read_varuint()
            limits_max = reader.read_varuint() if limits_flags & 1 else None
            import_entry["table"] = {"elem_type": elem_type, "limits": {"initial": limits_initial, "max": limits_max}}
        elif kind == 2:  # Memory
            limits_flags = reader.read_varuint()
            limits_initial = reader.read_varuint()
            limits_max = reader.read_varuint() if limits_flags & 1 else None
            import_entry["memory"] = {"limits": {"initial": limits_initial, "max": limits_max}}
        elif kind == 3:  # Global
            content_type = reader.read_varint()
            mutability = reader.read_varuint()
            import_entry["global"] = {"content_type": content_type, "mutability": mutability}

        imports.append(import_entry)

    return imports


def parse_export_section(reader: WASMReader) -> List[Dict]:
    """Parse export section"""
    count = reader.read_varuint()
    exports = []

    for _ in range(count):
        field = reader.read_name()
        kind = reader.read_u8()
        index = reader.read_varuint()

        exports.append({"field": field, "kind": kind, "index": index})

    return exports


def write_type_section(writer: WASMWriter, types: List[Dict]):
    """Write type section"""
    writer.write_varuint(len(types))
    for t in types:
        writer.write_u8(t["form"])
        writer.write_varuint(len(t["params"]))
        for p in t["params"]:
            writer.write_varint(p)
        writer.write_varuint(len(t["returns"]))
        for r in t["returns"]:
            writer.write_varint(r)


def write_import_section(writer: WASMWriter, imports: List[Dict]):
    """Write import section"""
    writer.write_varuint(len(imports))
    for imp in imports:
        writer.write_name(imp["module"])
        writer.write_name(imp["field"])
        writer.write_u8(imp["kind"])

        if imp["kind"] == 0:  # Function
            writer.write_varuint(imp["type_idx"])
        elif imp["kind"] == 1:  # Table
            table = imp["table"]
            writer.write_varint(table["elem_type"])
            writer.write_varuint(1 if table["limits"]["max"] is not None else 0)
            writer.write_varuint(table["limits"]["initial"])
            if table["limits"]["max"] is not None:
                writer.write_varuint(table["limits"]["max"])
        elif imp["kind"] == 2:  # Memory
            mem = imp["memory"]
            writer.write_varuint(1 if mem["limits"]["max"] is not None else 0)
            writer.write_varuint(mem["limits"]["initial"])
            if mem["limits"]["max"] is not None:
                writer.write_varuint(mem["limits"]["max"])
        elif imp["kind"] == 3:  # Global
            glob = imp["global"]
            writer.write_varint(glob["content_type"])
            writer.write_varuint(glob["mutability"])


def write_export_section(writer: WASMWriter, exports: List[Dict]):
    """Write export section"""
    writer.write_varuint(len(exports))
    for exp in exports:
        writer.write_name(exp["field"])
        writer.write_u8(exp["kind"])
        writer.write_varuint(exp["index"])


def strip_wasm(input_path: Path, output_wasm: Path, output_json: Path):
    """Strip metadata from WASM file and save to JSON"""
    print(f"Stripping {input_path}...")

    with open(input_path, "rb") as f:
        data = f.read()

    reader = WASMReader(data)

    # Read header
    magic = reader.read_u32()
    version = reader.read_u32()

    if magic != WASM_MAGIC:
        raise ValueError("Not a valid WASM file")

    print(f"WASM version: {version}")

    metadata = {"version": version, "sections": {}}

    stripped_sections = []

    # Parse sections
    while not reader.at_end():
        section_id = reader.read_u8()
        section_size = reader.read_varuint()
        section_start = reader.pos
        section_data = reader.read_bytes(section_size)

        section_reader = WASMReader(section_data)

        if section_id == SECTION_TYPE:
            print("  Found TYPE section")
            types = parse_type_section(section_reader)
            metadata["sections"]["type"] = types
            # Don't include in stripped version

        elif section_id == SECTION_IMPORT:
            print("  Found IMPORT section")
            imports = parse_import_section(section_reader)
            metadata["sections"]["import"] = imports
            # Don't include in stripped version

        elif section_id == SECTION_EXPORT:
            print("  Found EXPORT section")
            exports = parse_export_section(section_reader)
            metadata["sections"]["export"] = exports
            # Don't include in stripped version

        elif section_id == SECTION_CUSTOM:
            print("  Found CUSTOM section (skipping)")
            # Skip custom sections (like name section)

        else:
            # Keep all other sections (function, code, memory, etc.)
            print(f"  Found section {section_id} (keeping)")
            stripped_sections.append({"id": section_id, "data": section_data})

    # Write stripped WASM
    writer = WASMWriter()
    writer.write_u32(WASM_MAGIC)
    writer.write_u32(version)

    for section in stripped_sections:
        writer.write_u8(section["id"])
        writer.write_varuint(len(section["data"]))
        writer.write_bytes(section["data"])

    with open(output_wasm, "wb") as f:
        f.write(writer.get_bytes())

    # Write metadata JSON
    with open(output_json, "w") as f:
        json.dump(metadata, f, indent=2)

    original_size = len(data)
    stripped_size = len(writer.get_bytes())
    print(f"\nOriginal size: {original_size} bytes")
    print(f"Stripped size: {stripped_size} bytes")
    print(
        f"Saved: {original_size - stripped_size} bytes ({100 * (original_size - stripped_size) / original_size:.1f}%)"
    )
    print(f"\nWrote stripped WASM to: {output_wasm}")
    print(f"Wrote metadata to: {output_json}")


def reassemble_wasm(stripped_wasm: Path, metadata_json: Path, output_wasm: Path):
    """Reassemble WASM from stripped version and metadata JSON"""
    print(f"Reassembling from {stripped_wasm} and {metadata_json}...")

    with open(stripped_wasm, "rb") as f:
        stripped_data = f.read()

    with open(metadata_json, "r") as f:
        metadata = json.load(f)

    reader = WASMReader(stripped_data)

    # Read header
    magic = reader.read_u32()
    version = reader.read_u32()

    if magic != WASM_MAGIC:
        raise ValueError("Not a valid WASM file")

    # Start building reassembled WASM
    writer = WASMWriter()
    writer.write_u32(WASM_MAGIC)
    writer.write_u32(version)

    # Write TYPE section if present
    if "type" in metadata["sections"]:
        print("  Restoring TYPE section")
        section_writer = WASMWriter()
        write_type_section(section_writer, metadata["sections"]["type"])

        writer.write_u8(SECTION_TYPE)
        writer.write_varuint(len(section_writer.get_bytes()))
        writer.write_bytes(section_writer.get_bytes())

    # Write IMPORT section if present
    if "import" in metadata["sections"]:
        print("  Restoring IMPORT section")
        section_writer = WASMWriter()
        write_import_section(section_writer, metadata["sections"]["import"])

        writer.write_u8(SECTION_IMPORT)
        writer.write_varuint(len(section_writer.get_bytes()))
        writer.write_bytes(section_writer.get_bytes())

    # Copy sections from stripped WASM in correct order
    # WASM sections must be ordered: Type(1), Import(2), Function(3), Table(4), Memory(5), Global(6), Export(7), Start(8), Element(9), Code(10), Data(11)
    # We need to insert Export(7) at the right position
    
    # First, read all sections from stripped WASM
    remaining_sections = []
    while not reader.at_end():
        section_id = reader.read_u8()
        section_size = reader.read_varuint()
        section_data = reader.read_bytes(section_size)
        remaining_sections.append({"id": section_id, "size": section_size, "data": section_data})
    
    # Write sections in correct order
    for section in remaining_sections:
        section_id = section["id"]
        
        # Before writing Export section (7), insert our restored Export section if we haven't yet
        if section_id >= SECTION_EXPORT and "export" in metadata["sections"]:
            print("  Restoring EXPORT section")
            section_writer = WASMWriter()
            write_export_section(section_writer, metadata["sections"]["export"])
            
            writer.write_u8(SECTION_EXPORT)
            writer.write_varuint(len(section_writer.get_bytes()))
            writer.write_bytes(section_writer.get_bytes())
            
            # Remove export from metadata so we don't write it again
            del metadata["sections"]["export"]
        
        # Copy the section from stripped WASM
        print(f"  Copying section {section_id}")
        writer.write_u8(section_id)
        writer.write_varuint(section["size"])
        writer.write_bytes(section["data"])

    with open(output_wasm, "wb") as f:
        f.write(writer.get_bytes())

    print(f"\nReassembled WASM written to: {output_wasm}")
    print(f"Size: {len(writer.get_bytes())} bytes")


def main():
    parser = argparse.ArgumentParser(
        description="Strip metadata from WASM files or reassemble them",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Strip metadata from a WASM file
  %(prog)s strip input.wasm -o output.wasm -m metadata.json

  # Reassemble WASM from stripped version and metadata
  %(prog)s reassemble stripped.wasm metadata.json -o output.wasm
        """,
    )

    subparsers = parser.add_subparsers(dest="command", help="Command to execute")

    # Strip command
    strip_parser = subparsers.add_parser("strip", help="Strip metadata from WASM file")
    strip_parser.add_argument("input", type=Path, help="Input WASM file")
    strip_parser.add_argument("-o", "--output", type=Path, required=True, help="Output stripped WASM file")
    strip_parser.add_argument("-m", "--metadata", type=Path, required=True, help="Output metadata JSON file")

    # Reassemble command
    reassemble_parser = subparsers.add_parser("reassemble", help="Reassemble WASM from stripped version and metadata")
    reassemble_parser.add_argument("stripped", type=Path, help="Stripped WASM file")
    reassemble_parser.add_argument("metadata", type=Path, help="Metadata JSON file")
    reassemble_parser.add_argument("-o", "--output", type=Path, required=True, help="Output reassembled WASM file")

    args = parser.parse_args()

    if args.command == "strip":
        strip_wasm(args.input, args.output, args.metadata)
    elif args.command == "reassemble":
        reassemble_wasm(args.stripped, args.metadata, args.output)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
