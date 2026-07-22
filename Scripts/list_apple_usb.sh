#!/usr/bin/env bash
set -euo pipefail

ioreg -p IOUSB -l -w 0 | awk '
  /idVendor/ && /1452/ { apple=1; print "---- Apple USB device ----" }
  apple && /"USB Product Name"/ { print }
  apple && /"idProduct"/ { print }
  apple && /"USB Serial Number"/ { print }
  apple && /"Serial Number"/ { print }
  apple && /^ *\}/ { apple=0 }
'
