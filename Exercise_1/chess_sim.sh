#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 path_to_pgn_file"
    exit 1
fi

pgn_file="$1"

# Convert to Unix format just in case
dos2unix -n "$pgn_file" "$pgn_file" 2>/dev/null

if [ ! -f "$pgn_file" ]; then
    echo "Error: File '$pgn_file' does not exist."
    exit 1
fi

if [ "${pgn_file##*.}" != "pgn" ]; then
    echo "Error: File '$pgn_file' is not a PGN file."
    exit 1
fi

if [ ! -s "$pgn_file" ]; then
    echo "Error: File '$pgn_file' is empty."
    exit 1
fi

# Just run the Python script that already does everything
python3 chess_sim.py "$pgn_file"
