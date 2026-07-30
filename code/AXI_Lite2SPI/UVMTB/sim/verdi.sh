#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
verdi -dbdir /tmp/AXI-LITE2SPI/UVMTB/simv.daidir \
      -ssf "$SCRIPT_DIR/tb_top.fsdb" &
