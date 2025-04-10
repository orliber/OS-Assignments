#!/bin/bash

# ---------------------------
# PGN File Splitter
# ---------------------------

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <source_pgn_file> <destination_directory>"
  exit 1
fi

input_file="$1"
dest_dir="$2"

if [ ! -f "$input_file" ]; then
  echo "Error: File '$input_file' does not exist."
  exit 1
fi

if [ ! -d "$dest_dir" ]; then
  mkdir -p "$dest_dir"
  echo "Created directory '$dest_dir'."
fi

game_count=0
game_data=""

while IFS= read -r line || [ -n "$line" ]; do
  game_data+="$line"$'\n'

  if [[ "$line" =~ (^|[[:space:]])(1-0|0-1|1/2-1/2)($|[[:space:]]) ]]; then
    ((game_count++))
    base_name=$(basename "$input_file" .pgn)
    output_file="$dest_dir/${base_name}_${game_count}.pgn"
    echo -n "$game_data" > "$output_file"
    echo "Saved game to $output_file"
    game_data=""
  fi
done < "$input_file"

echo "All games have been split and saved to '$dest_dir'."
