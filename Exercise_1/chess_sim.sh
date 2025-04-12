#!/bin/bash

# Convert the input PGN file to Unix format silently
dos2unix -n "$1" "$1" 2>/dev/null

# Ensure exactly one argument (the PGN file path) is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 path_to_pgn_file"
    exit 1
fi

pgn_file="$1"

# Check if the file exists
if [ ! -f "$pgn_file" ]; then
    echo "Error: File '$pgn_file' does not exist."
    exit 1
fi

# Check if the file has a .pgn extension
if [ "${pgn_file##*.}" != "pgn" ]; then
    echo "Error: File '$pgn_file' is not a PGN file."
    exit 1
fi

# Check if the file is not empty
if [ ! -s "$pgn_file" ]; then
    echo "Error: File '$pgn_file' is empty."
    exit 1
fi

# Print the PGN metadata (lines starting with [ )
echo "Metadata from PGN file:"
grep "^\[" "$pgn_file"

# Extract the move section (all non-metadata lines)
pgn_moves=$(grep -v "^\[" "$pgn_file" | tr -d '\n')

# Convert PGN moves to UCI format using the provided Python script
uci_output=$(python3 parse_moves.py "$pgn_moves")

# Store UCI moves into a Bash array
IFS=' ' read -r -a all_moves <<< "$uci_output"
total_moves=${#all_moves[@]}
current_index=0

# Declare an associative array for the board
declare -A board

# Initialize the chessboard with the starting position
init_board() {
    board=()
    for file in a b c d e f g h; do
        board["${file}2"]="P"   # White pawns
        board["${file}7"]="p"   # Black pawns
    done
    # White pieces
    board[a1]="R"; board[b1]="N"; board[c1]="B"; board[d1]="Q"
    board[e1]="K"; board[f1]="B"; board[g1]="N"; board[h1]="R"
    # Black pieces
    board[a8]="r"; board[b8]="n"; board[c8]="b"; board[d8]="q"
    board[e8]="k"; board[f8]="b"; board[g8]="n"; board[h8]="r"
}

# Print the current state of the chessboard
print_board() {
    echo "  a b c d e f g h"
    for ((rank = 8; rank >= 1; rank--)); do
        echo -n "$rank "
        for file in a b c d e f g h; do
            piece="${board[$file$rank]:-.}"
            echo -n "$piece "
        done
        echo "$rank"
    done
    echo "  a b c d e f g h"
}

# Apply a single move in UCI format
apply_move() {
    from=${1:0:2}
    to=${1:2:2}
    board[$to]="${board[$from]}"
    unset board[$from]
}

# Apply all moves up to the current index to rebuild board state
apply_moves_up_to_index() {
    init_board
    for ((i = 0; i < current_index; i++)); do
        apply_move "${all_moves[$i]}"
    done
}

# Initial board setup and print
apply_moves_up_to_index
echo "Move $current_index/$total_moves"
print_board
echo -n "Press 'd' to move forward, 'a' to move back, 'w' to go to the start, 's' to go to the end, 'q' to quit: "

# Main input loop to handle user navigation
while true; do
    if [[ "$key" != "" && "$key" != " " ]]; then
        echo -n "Press 'd' to move forward, 'a' to move back, 'w' to go to the start, 's' to go to the end, 'q' to quit: "
    fi
    if ! IFS= read -rsn1 key; then
        key=""
    fi
    case "$key" in
        d)  # Move forward
            if [ "$current_index" -lt "$total_moves" ]; then
                current_index=$((current_index + 1))
                apply_moves_up_to_index
                printf "Move %d/%d\n" "$current_index" "$total_moves"
                print_board
            else
                echo -n "No more moves available."
                echo
            fi
            ;;
        a)  # Move backward
            if [ "$current_index" -gt 0 ]; then
                current_index=$((current_index - 1))
            fi
            apply_moves_up_to_index
            printf "Move %d/%d\n" "$current_index" "$total_moves"
            print_board
            ;;
        w)  # Go to start of game
            current_index=0
            apply_moves_up_to_index
            printf "Move %d/%d\n" "$current_index" "$total_moves"
            print_board
            ;;
        s)  # Go to end of game
            current_index=$total_moves
            apply_moves_up_to_index
            printf "Move %d/%d\n" "$current_index" "$total_moves"
            print_board
            ;;
        q)  # Quit the game
            echo -n "Exiting."
            echo
            echo "End of game."
            break
            ;;
        *)  # Invalid key press
            if [[ "$key" != "" && "$key" != " " ]]; then
                echo -n "Invalid key pressed: $key"
                echo
            else
                echo -n
            fi
            ;;
    esac
done
