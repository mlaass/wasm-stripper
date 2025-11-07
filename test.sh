#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}WASM Stripper Test Suite${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Check if testapp.wasm exists
if [ ! -f "testapp.wasm" ]; then
    echo -e "${RED}Error: testapp.wasm not found${NC}"
    exit 1
fi

ORIGINAL_SIZE=$(stat -c%s testapp.wasm)
echo -e "${BLUE}Original file size: ${ORIGINAL_SIZE} bytes${NC}"
echo

# Clean up previous test files
echo -e "${YELLOW}Cleaning up previous test files...${NC}"
rm -f test-*.wasm test-*.json

# Test 1: Normal mode
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Test 1: Normal Mode${NC}"
echo -e "${BLUE}========================================${NC}"
python3 wasm_stripper.py strip testapp.wasm -o test-normal-stripped.wasm -m test-normal-metadata.json

NORMAL_STRIPPED_SIZE=$(stat -c%s test-normal-stripped.wasm)
NORMAL_METADATA_SIZE=$(stat -c%s test-normal-metadata.json)
NORMAL_SAVINGS=$((ORIGINAL_SIZE - NORMAL_STRIPPED_SIZE))
NORMAL_PERCENT=$(awk "BEGIN {printf \"%.1f\", ($NORMAL_SAVINGS / $ORIGINAL_SIZE) * 100}")

echo -e "\n${YELLOW}Normal mode results:${NC}"
echo -e "  Stripped WASM:  ${NORMAL_STRIPPED_SIZE} bytes"
echo -e "  Metadata JSON:  ${NORMAL_METADATA_SIZE} bytes"
echo -e "  Savings:        ${NORMAL_SAVINGS} bytes (${NORMAL_PERCENT}%)"

# Test 2: Aggressive mode
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Test 2: Aggressive Mode${NC}"
echo -e "${BLUE}========================================${NC}"
python3 wasm_stripper.py strip testapp.wasm -o test-aggressive-stripped.wasm -m test-aggressive-metadata.json --aggressive

AGGRESSIVE_STRIPPED_SIZE=$(stat -c%s test-aggressive-stripped.wasm)
AGGRESSIVE_METADATA_SIZE=$(stat -c%s test-aggressive-metadata.json)
AGGRESSIVE_SAVINGS=$((ORIGINAL_SIZE - AGGRESSIVE_STRIPPED_SIZE))
AGGRESSIVE_PERCENT=$(awk "BEGIN {printf \"%.1f\", ($AGGRESSIVE_SAVINGS / $ORIGINAL_SIZE) * 100}")

echo -e "\n${YELLOW}Aggressive mode results:${NC}"
echo -e "  Stripped WASM:  ${AGGRESSIVE_STRIPPED_SIZE} bytes"
echo -e "  Metadata JSON:  ${AGGRESSIVE_METADATA_SIZE} bytes"
echo -e "  Savings:        ${AGGRESSIVE_SAVINGS} bytes (${AGGRESSIVE_PERCENT}%)"

# Test 3: Compression tests
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Test 3: Compression Analysis${NC}"
echo -e "${BLUE}========================================${NC}"

echo -e "\n${YELLOW}Compressing normal mode stripped file:${NC}"
# gzip
gzip -9 -k -f test-normal-stripped.wasm
NORMAL_GZIP_SIZE=$(stat -c%s test-normal-stripped.wasm.gz)
NORMAL_GZIP_RATIO=$(awk "BEGIN {printf \"%.1f\", ($NORMAL_GZIP_SIZE / $NORMAL_STRIPPED_SIZE) * 100}")
echo -e "  gzip -9:        ${NORMAL_GZIP_SIZE} bytes (${NORMAL_GZIP_RATIO}% of stripped)"

# bzip2
bzip2 -9 -k -f test-normal-stripped.wasm
NORMAL_BZIP2_SIZE=$(stat -c%s test-normal-stripped.wasm.bz2)
NORMAL_BZIP2_RATIO=$(awk "BEGIN {printf \"%.1f\", ($NORMAL_BZIP2_SIZE / $NORMAL_STRIPPED_SIZE) * 100}")
echo -e "  bzip2 -9:       ${NORMAL_BZIP2_SIZE} bytes (${NORMAL_BZIP2_RATIO}% of stripped)"

# xz
xz -9 -k -f test-normal-stripped.wasm
NORMAL_XZ_SIZE=$(stat -c%s test-normal-stripped.wasm.xz)
NORMAL_XZ_RATIO=$(awk "BEGIN {printf \"%.1f\", ($NORMAL_XZ_SIZE / $NORMAL_STRIPPED_SIZE) * 100}")
echo -e "  xz -9:          ${NORMAL_XZ_SIZE} bytes (${NORMAL_XZ_RATIO}% of stripped)"

# zstd
if command -v zstd &> /dev/null; then
    zstd -19 -f -q test-normal-stripped.wasm -o test-normal-stripped.wasm.zst
    NORMAL_ZSTD_SIZE=$(stat -c%s test-normal-stripped.wasm.zst)
    NORMAL_ZSTD_RATIO=$(awk "BEGIN {printf \"%.1f\", ($NORMAL_ZSTD_SIZE / $NORMAL_STRIPPED_SIZE) * 100}")
    echo -e "  zstd -19:       ${NORMAL_ZSTD_SIZE} bytes (${NORMAL_ZSTD_RATIO}% of stripped)"
fi

echo -e "\n${YELLOW}Compressing aggressive mode stripped file:${NC}"
# gzip
gzip -9 -k -f test-aggressive-stripped.wasm
AGGRESSIVE_GZIP_SIZE=$(stat -c%s test-aggressive-stripped.wasm.gz)
AGGRESSIVE_GZIP_RATIO=$(awk "BEGIN {printf \"%.1f\", ($AGGRESSIVE_GZIP_SIZE / $AGGRESSIVE_STRIPPED_SIZE) * 100}")
echo -e "  gzip -9:        ${AGGRESSIVE_GZIP_SIZE} bytes (${AGGRESSIVE_GZIP_RATIO}% of stripped)"

# bzip2
bzip2 -9 -k -f test-aggressive-stripped.wasm
AGGRESSIVE_BZIP2_SIZE=$(stat -c%s test-aggressive-stripped.wasm.bz2)
AGGRESSIVE_BZIP2_RATIO=$(awk "BEGIN {printf \"%.1f\", ($AGGRESSIVE_BZIP2_SIZE / $AGGRESSIVE_STRIPPED_SIZE) * 100}")
echo -e "  bzip2 -9:       ${AGGRESSIVE_BZIP2_SIZE} bytes (${AGGRESSIVE_BZIP2_RATIO}% of stripped)"

# xz
xz -9 -k -f test-aggressive-stripped.wasm
AGGRESSIVE_XZ_SIZE=$(stat -c%s test-aggressive-stripped.wasm.xz)
AGGRESSIVE_XZ_RATIO=$(awk "BEGIN {printf \"%.1f\", ($AGGRESSIVE_XZ_SIZE / $AGGRESSIVE_STRIPPED_SIZE) * 100}")
echo -e "  xz -9:          ${AGGRESSIVE_XZ_SIZE} bytes (${AGGRESSIVE_XZ_RATIO}% of stripped)"

# zstd
if command -v zstd &> /dev/null; then
    zstd -19 -f -q test-aggressive-stripped.wasm -o test-aggressive-stripped.wasm.zst
    AGGRESSIVE_ZSTD_SIZE=$(stat -c%s test-aggressive-stripped.wasm.zst)
    AGGRESSIVE_ZSTD_RATIO=$(awk "BEGIN {printf \"%.1f\", ($AGGRESSIVE_ZSTD_SIZE / $AGGRESSIVE_STRIPPED_SIZE) * 100}")
    echo -e "  zstd -19:       ${AGGRESSIVE_ZSTD_SIZE} bytes (${AGGRESSIVE_ZSTD_RATIO}% of stripped)"
fi

# Test 4: Reassemble normal mode
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Test 4: Reassemble Normal Mode${NC}"
echo -e "${BLUE}========================================${NC}"
python3 wasm_stripper.py reassemble test-normal-stripped.wasm test-normal-metadata.json -o test-normal-reassembled.wasm

echo -e "\n${YELLOW}Verifying normal mode reassembly...${NC}"
if cmp -s testapp.wasm test-normal-reassembled.wasm; then
    echo -e "${GREEN}✓ Normal mode: Reassembled file is identical to original${NC}"
else
    echo -e "${RED}✗ Normal mode: Reassembled file differs from original${NC}"
    exit 1
fi

# Verify with wasm-objdump
if command -v wasm-objdump &> /dev/null; then
    if wasm-objdump -x test-normal-reassembled.wasm > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Normal mode: Reassembled WASM is valid${NC}"
    else
        echo -e "${RED}✗ Normal mode: Reassembled WASM is invalid${NC}"
        exit 1
    fi
fi

# Test 5: Reassemble aggressive mode
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Test 5: Reassemble Aggressive Mode${NC}"
echo -e "${BLUE}========================================${NC}"
python3 wasm_stripper.py reassemble test-aggressive-stripped.wasm test-aggressive-metadata.json -o test-aggressive-reassembled.wasm

echo -e "\n${YELLOW}Verifying aggressive mode reassembly...${NC}"
if cmp -s testapp.wasm test-aggressive-reassembled.wasm; then
    echo -e "${GREEN}✓ Aggressive mode: Reassembled file is identical to original${NC}"
else
    echo -e "${RED}✗ Aggressive mode: Reassembled file differs from original${NC}"
    exit 1
fi

# Verify with wasm-objdump
if command -v wasm-objdump &> /dev/null; then
    if wasm-objdump -x test-aggressive-reassembled.wasm > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Aggressive mode: Reassembled WASM is valid${NC}"
    else
        echo -e "${RED}✗ Aggressive mode: Reassembled WASM is invalid${NC}"
        exit 1
    fi
fi

# Summary
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "\n${GREEN}All tests passed!${NC}\n"

echo -e "${YELLOW}Size Comparison:${NC}"
echo -e "  Original:                    ${ORIGINAL_SIZE} bytes"
echo -e "  Normal stripped:             ${NORMAL_STRIPPED_SIZE} bytes (${NORMAL_PERCENT}% reduction)"
echo -e "  Aggressive stripped:         ${AGGRESSIVE_STRIPPED_SIZE} bytes (${AGGRESSIVE_PERCENT}% reduction)"
echo

echo -e "${YELLOW}Best Compression (of stripped files):${NC}"

# Find best compression for normal mode
BEST_NORMAL_COMPRESSED=$NORMAL_GZIP_SIZE
BEST_NORMAL_NAME="gzip"
if [ $NORMAL_BZIP2_SIZE -lt $BEST_NORMAL_COMPRESSED ]; then
    BEST_NORMAL_COMPRESSED=$NORMAL_BZIP2_SIZE
    BEST_NORMAL_NAME="bzip2"
fi
if [ $NORMAL_XZ_SIZE -lt $BEST_NORMAL_COMPRESSED ]; then
    BEST_NORMAL_COMPRESSED=$NORMAL_XZ_SIZE
    BEST_NORMAL_NAME="xz"
fi
if command -v zstd &> /dev/null && [ $NORMAL_ZSTD_SIZE -lt $BEST_NORMAL_COMPRESSED ]; then
    BEST_NORMAL_COMPRESSED=$NORMAL_ZSTD_SIZE
    BEST_NORMAL_NAME="zstd"
fi
BEST_NORMAL_RATIO=$(awk "BEGIN {printf \"%.1f\", ($BEST_NORMAL_COMPRESSED / $NORMAL_STRIPPED_SIZE) * 100}")
BEST_NORMAL_VS_ORIGINAL=$(awk "BEGIN {printf \"%.1f\", ($BEST_NORMAL_COMPRESSED / $ORIGINAL_SIZE) * 100}")

# Find best compression for aggressive mode
BEST_AGGRESSIVE_COMPRESSED=$AGGRESSIVE_GZIP_SIZE
BEST_AGGRESSIVE_NAME="gzip"
if [ $AGGRESSIVE_BZIP2_SIZE -lt $BEST_AGGRESSIVE_COMPRESSED ]; then
    BEST_AGGRESSIVE_COMPRESSED=$AGGRESSIVE_BZIP2_SIZE
    BEST_AGGRESSIVE_NAME="bzip2"
fi
if [ $AGGRESSIVE_XZ_SIZE -lt $BEST_AGGRESSIVE_COMPRESSED ]; then
    BEST_AGGRESSIVE_COMPRESSED=$AGGRESSIVE_XZ_SIZE
    BEST_AGGRESSIVE_NAME="xz"
fi
if command -v zstd &> /dev/null && [ $AGGRESSIVE_ZSTD_SIZE -lt $BEST_AGGRESSIVE_COMPRESSED ]; then
    BEST_AGGRESSIVE_COMPRESSED=$AGGRESSIVE_ZSTD_SIZE
    BEST_AGGRESSIVE_NAME="zstd"
fi
BEST_AGGRESSIVE_RATIO=$(awk "BEGIN {printf \"%.1f\", ($BEST_AGGRESSIVE_COMPRESSED / $AGGRESSIVE_STRIPPED_SIZE) * 100}")
BEST_AGGRESSIVE_VS_ORIGINAL=$(awk "BEGIN {printf \"%.1f\", ($BEST_AGGRESSIVE_COMPRESSED / $ORIGINAL_SIZE) * 100}")

echo -e "  Normal + ${BEST_NORMAL_NAME}:        ${BEST_NORMAL_COMPRESSED} bytes (${BEST_NORMAL_VS_ORIGINAL}% of original)"
echo -e "  Aggressive + ${BEST_AGGRESSIVE_NAME}:     ${BEST_AGGRESSIVE_COMPRESSED} bytes (${BEST_AGGRESSIVE_VS_ORIGINAL}% of original)"
echo

echo -e "${GREEN}Test suite completed successfully!${NC}"
