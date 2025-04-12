#!/bin/bash

# Convert the input PGN file to Unix format silently (remove Windows line endings)
dos2unix -n "$1" "$1" 2>/dev/null

# Ensure exactly one argument (the PGN file path) is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 path_to_pgn_file"
    exit 1
fi

pgn_file="$1"

# Validate that the PGN file exists
if [ ! -f "$pgn_file" ]; then
    echo "Error: File '$pgn_file' does not exist."
    exit 1
fi

# Ensure file has a .pgn extension
if [ "${pgn_file##*.}" != "pgn" ]; then
    echo "Error: File '$pgn_file' is not a PGN file."
    exit 1
fi

# Ensure the file is not empty
if [ ! -s "$pgn_file" ]; then
    echo "Error: File '$pgn_file' is empty."
    exit 1
fi

# Print PGN metadata (lines starting with [ )
echo "Metadata from PGN file:"
grep "^\[" "$pgn_file"

# Extract move section (removing metadata)
pgn_moves=$(grep -v "^\[" "$pgn_file" | tr -d '\n')

# Convert PGN moves to UCI format using parse_moves.py and remove invalid lines
uci_output=$(python3 parse_moves.py "$pgn_moves" 2>/dev/null | grep -v "illegal san")

# If the output is empty, parsing failed
if [[ -z "$uci_output" ]]; then
    echo "Error: Failed to parse PGN moves."
    exit 1
fi

# Convert UCI string into a Bash array
IFS=' ' read -r -a all_moves <<< "$uci_output"
total_moves=${#all_moves[@]}      # Total number of moves
current_index=0                   # Start from move 0

# Array to store FEN (board position snapshots) for each move
declare -a fen_snapshots

# Function to generate the board state (FEN) after n moves using python-chess
get_fen_after_n_moves() {
    python3 -c "
import chess
board = chess.Board()
moves = '${all_moves[*]}'.split()
for move in moves[:$1]:
    board.push_uci(move)  # Apply move
print(board.board_fen())  # Output FEN of board state
" 2>/dev/null
}

# Pre-compute all board states from 0 to total_moves
for ((i = 0; i <= total_moves; i++)); do
    fen_snapshots[$i]=$(get_fen_after_n_moves "$i")
done

# Function to print a chessboard from a FEN string (only the piece layout part)
print_board_from_fen() {
    fen="$1"
    echo "  a b c d e f g h"  # Top file labels
    rank=8
    for row in $(echo "$fen" | tr '/' ' '); do
        echo -n "$rank "
        for ((i=0; i<${#row}; i++)); do
            ch="${row:$i:1}"
            if [[ "$ch" =~ [0-9] ]]; then
                for ((j=0; j<ch; j++)); do echo -n ". "; done  # Print empty squares
            else
                echo -n "$ch "  # Print piece character
            fi
        done
        echo "$rank"
        ((rank--))
    done
    echo "  a b c d e f g h"  # Bottom file labels
}

# Print the initial board state
echo "Move $current_index/$total_moves"
print_board_from_fen "${fen_snapshots[$current_index]}"
echo -n "Press 'd' to move forward, 'a' to move back, 'w' to go to the start, 's' to go to the end, 'q' to quit: "

# Main interactive loop - waits for user key press
while true; do
    # Repeat prompt if user typed something
    if [[ "$key" != "" && "$key" != " " ]]; then
        echo -n "Press 'd' to move forward, 'a' to move back, 'w' to go to the start, 's' to go to the end, 'q' to quit: "
    fi

    # Read a single keypress (non-blocking)
    if ! IFS= read -rsn1 key; then key=""; fi

    case "$key" in
        d)  # Move forward one move
            if [ "$current_index" -lt "$total_moves" ]; then
                ((current_index++))
                echo "Move $current_index/$total_moves"
                print_board_from_fen "${fen_snapshots[$current_index]}"
            else
                echo "No more moves available."
            fi
            ;;
        a)  # Move backward one move
            if [ "$current_index" -gt 0 ]; then
                ((current_index--))
            fi
            echo "Move $current_index/$total_moves"
            print_board_from_fen "${fen_snapshots[$current_index]}"
            ;;
        w)  # Go to start of game
            current_index=0
            echo "Move $current_index/$total_moves"
            print_board_from_fen "${fen_snapshots[$current_index]}"
            ;;
        s)  # Go to end of game
            current_index=$total_moves
            echo "Move $current_index/$total_moves"
            print_board_from_fen "${fen_snapshots[$current_index]}"
            ;;
        q)  # Quit the simulator
            echo "Exiting."
            echo "End of game."
            break
            ;;
        *)  # Handle invalid keys
            if [[ "$key" != "" && "$key" != " " ]]; then
                echo "Invalid key pressed: $key"
            fi
            ;;
    esac
done
