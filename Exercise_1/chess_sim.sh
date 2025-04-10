#!/bin/bash

pgn_file="$1"

if [ ! -f "$pgn_file" ]; then
    python3 chess_sim.py "$pgn_file"
    exit 1
fi

# Show metadata without empty line
echo "Metadata from PGN file:"
grep '^\[' "$pgn_file"

# Extract and convert PGN
pgn_moves=$(grep -v '^\[' "$pgn_file" | paste -sd ' ' -)
uci_moves_output=$(python3 parse_moves.py "$pgn_moves" 2>/dev/null)
if [ -z "$uci_moves_output" ]; then
    echo "No moves found or parse_moves.py failed."
    exit 0
fi

read -ra uci_moves <<< "$uci_moves_output"
total_moves=${#uci_moves[@]}
current_move=0

get_board_fen() {
    python3 -c "
import chess
board = chess.Board()
for move in '${uci_moves[*]}'.split()[:$1]:
    board.push_uci(move)
print(board.board_fen())
"
}

print_board() {
    fen=$(get_board_fen "$1")
    rows=($(echo "$fen" | cut -d' ' -f1 | tr '/' ' '))
    echo "  a b c d e f g h"
    row=8
    for r in "${rows[@]}"; do
        line="$row "
        for ((i=0; i<${#r}; i++)); do
            c=${r:$i:1}
            if [[ "$c" =~ [1-8] ]]; then
                for ((j=0; j<$c; j++)); do
                    line+=". "
                done
            else
                line+="$c "
            fi
        done
        line+="$row"
        echo "$line"
        ((row--))
    done
    echo "  a b c d e f g h"
}

# Initial board (with Move 0/x)
echo "Move $current_move/$total_moves"
print_board "$current_move"

# Interaction loop
while true; do
    echo -n "Press 'd' to move forward, 'a' to move back, 'w' to go to the start, 's' to go to the end, 'q' to quit: "
    read -n1 key
    case "$key" in
        d)
            if [ "$current_move" -lt "$total_moves" ]; then
                ((current_move++))
                echo "Move $current_move/$total_moves"
                print_board "$current_move"
            else
                echo "No more moves available."
            fi
            ;;
        a)
            if [ "$current_move" -gt 0 ]; then
                ((current_move--))
                echo "Move $current_move/$total_moves"
                print_board "$current_move"
            fi
            ;;
        w)
            current_move=0
            echo "Move $current_move/$total_moves"
            print_board "$current_move"
            ;;
        s)
            current_move=$total_moves
            echo "Move $current_move/$total_moves"
            print_board "$current_move"
            ;;
        q)
            echo "Exiting."
            echo "End of game."
            break
            ;;
        *)
            echo "Invalid key pressed: $key"
            ;;
    esac
done
