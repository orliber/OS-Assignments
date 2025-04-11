#!/bin/bash

# Ensure the file is in Unix format before processing
dos2unix -n "$1" "$1" 2>/dev/null

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 path_to_pgn_file"
    exit 1
fi

pgn_file="$1"

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

# Show metadata
echo "Metadata from PGN file:"
grep "^\[" "$pgn_file"

# Read moves
pgn_moves=$(grep -v "^\[" "$pgn_file" | tr -d '\n')
uci_output=$(python3 parse_moves.py "$pgn_moves")
IFS=' ' read -r -a all_moves <<< "$uci_output"
total_moves=${#all_moves[@]}
current_index=0

# Board setup
declare -A board

init_board() {
    board=()
    for file in a b c d e f g h; do
        board["${file}2"]="P"
        board["${file}7"]="p"
    done
    board[a1]="R"; board[b1]="N"; board[c1]="B"; board[d1]="Q"
    board[e1]="K"; board[f1]="B"; board[g1]="N"; board[h1]="R"
    board[a8]="r"; board[b8]="n"; board[c8]="b"; board[d8]="q"
    board[e8]="k"; board[f8]="b"; board[g8]="n"; board[h8]="r"
}

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

apply_move() {
    from=${1:0:2}
    to=${1:2:2}
    board[$to]="${board[$from]}"
    unset board[$from]
}

apply_moves_up_to_index() {
    init_board
    for ((i = 0; i < current_index; i++)); do
        apply_move "${all_moves[$i]}"
    done
}

# Initial print
apply_moves_up_to_index
echo "Move $current_index/$total_moves"
print_board
echo -n "Press 'd' to move forward, 'a' to move back, 'w' to go to the start, 's' to go to the end, 'q' to quit: "
# Main loop
while true; do
    if [[ "$key" != "" && "$key" != " " ]]; then
        echo -n "Press 'd' to move forward, 'a' to move back, 'w' to go to the start, 's' to go to the end, 'q' to quit: "
    fi
    if ! IFS= read -rsn1 key; then
        key=""
    fi
    case "$key" in
        d)
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
        a)
            if [ "$current_index" -gt 0 ]; then
                current_index=$((current_index - 1))
            fi
            apply_moves_up_to_index
            printf "Move %d/%d\n" "$current_index" "$total_moves"
            print_board
            ;;
        w)
            current_index=0
            apply_moves_up_to_index
            printf "Move %d/%d\n" "$current_index" "$total_moves"
            print_board
            ;;
        s)
            current_index=$total_moves
            apply_moves_up_to_index
            printf "Move %d/%d\n" "$current_index" "$total_moves"
            print_board
            ;;
        q)
            echo -n "Exiting."
            echo
            echo "End of game."
            break
            ;;
        *)
        # check if key is not valid AND not empty or space
        if [[ "$key" != "" && "$key" != " " ]]; then
                echo -n "Invalid key pressed: $key"
                echo
        else
                echo -n 
        fi

        ;;
    esac
done
