#!/usr/bin/bash

__PKG_NAME__="2048-puzzle"

function Usage {
    echo -e "Usage: $__PKG_NAME__ [OPTIONS]";
    echo -e "\t-b | --board [0-9]\tboard size (default)"
    echo -e "\t-t | --target [0-9]\tcustom target"
    echo -e "\t-d | --debug [FILE]\tdebug info to file provided"
    echo -e "\t-h | --help\t\tdisplay this message"
    echo -e "\t-v | --version\t\tversion information"
}


GETOPT=$(getopt -o b:l:d:hv \
                -l board:,level:,debug:,help,version \
                -n "$__PKG_NAME__" \
                -- "$@")

[[ $? != "0" ]] && exit 1

eval set -- "$GETOPT"

export WD="$(dirname $(readlink $0 || echo $0))"
BOARD_SIZE=4
TARGET=2048
exec 3>/dev/null

while true; do
    case $1 in
        -b|--board)   BOARD_SIZE=$2; shift 2;;
        -t|--target)  TARGET=$2; shift 2;;
        -d|--debug)   exec 3>$2; shift 2;;
        -h|--help)    Usage; exit;;
        -v|--version) cat $WD/.version; exit;;
        --)           shift; break
    esac
done

# extra argument
for arg do
    BOARD_SIZE=$arg
    break
done

#----------------------------------------------------------------------
# game LOGIC

name_fancy="\e[1;31m2\e[33m0\e[32m4\e[34m8\e[m"
header="${name_fancy}\e[1m-puzzle\e[m (https://github.com/rhoit/2048)"

colors[0]="\e[8m"
colors[2]="\e[1;33;48;5;24m"
colors[4]="\e[1;39;48;5;12m"
colors[8]="\e[1;38;5;227;48;5;202m"
colors[16]="\e[1;39;48;5;208m"
colors[32]="\e[1;39;48;5;9m"
colors[64]="\e[1;39;48;5;1m"
colors[128]="\e[46;39m"
colors[256]="\e[48;5;27;39m"
colors[512]="\e[1;38;5;9;48;5;11m"
colors[1024]="\e[1;38;5;22;48;5;226m"
colors[2048]="\e[1;38;5;8;48;5;237m"

export WD_BOARD="$WD/ASCII-board"
source $WD_BOARD/board.sh


function generate_piece {
    change=1
    while (( tiles < N )); do
        let index=RANDOM%N
        let board[index] || {
            local val=$((RANDOM%10?2:4))
            let tiles++
            # just for some delay effects/invert color
            local r=$((index/BOARD_SIZE))
            local c=$((index-r*BOARD_SIZE))
            board_vt100_tile="\e[30;48;5;15m"
            board_tile_update_ij $r $c $val
            let board[index]=val
            break;
        }
    done
}


# perform push operation between two tiles
# inputs:
#   $1 - push position, for horizontal push this is row, for vertical column
#   $2 - recipient piece, this will hold result if moving or joining
#   $3 - originator piece, after moving or joining this will be left empty
#   $4 - direction of push, can be either "up", "down", "left" or "right"
#   $5 - if anything is passed, do not perform the push, only update number of valid moves
function push_tiles {
    case $4 in
        u) let first="$2 * BOARD_SIZE + $1";
           let secon="($2 + $3) * BOARD_SIZE + $1";;
        d) let first="(BOARD_SIZE - 1 - $2) * BOARD_SIZE + $1";
           let secon="(BOARD_SIZE - 1 - $2 - $3) * BOARD_SIZE + $1";;
        l) let first="$1 * BOARD_SIZE + $2";
           let secon="$1 * BOARD_SIZE + ($2 + $3)";;
        r) let first="$1 * BOARD_SIZE + (BOARD_SIZE - 1 - $2)";
           let secon="$1 * BOARD_SIZE + (BOARD_SIZE - 1 - $2 - $3)";;
    esac

    let "${board[first]}" || {
        let "${board[secon]}" && {
            if test -z $5; then
                board[$first]="${board[$secon]}"
                let board[$secon]=0
                let change=1
            else
                let next_mov++
            fi
        }
        return
    }

    let "${board[secon]}" && let flag_skip=1
    test "${board[first]}" == "${board[secon]}" && {
        if test -z $5; then
            let board[$first]*=2
            test "${board[first]}" = "$TARGET" && won_flag=1
            let board[$secon]=0
            let tiles-=1
            let change=1
            let score+=${board[$first]}
        else
            let next_mov++
        fi
    }
}


function apply_push { # $1: direction; $2: mode
    for ((i=0; i < $BOARD_SIZE; i++)); do
        for ((j=0; j < $BOARD_SIZE; j++)); do
            flag_skip=0
            let increment_max="BOARD_SIZE - 1 - j"
            for ((k=1; k <= $increment_max; k++)); do
                let flag_skip && break
                push_tiles $i $j $k $1 $2
            done
        done
    done
    let won_flag && check_endgame 1
}


function check_moves {
    next_mov=0
    apply_push u fake
    apply_push d fake
    apply_push l fake
    apply_push r fake
    let next_mov==0 && check_endgame 0
}


function key_react {
    read -d '' -sn 1
    test "$REPLY" == $'\e' && {
        read -d '' -sn 1 -t1
        test "$REPLY" == "[" && {
            read -d '' -sn 1 -t1
            case $REPLY in
                A) apply_push u;;
                B) apply_push d;;
                C) apply_push r;;
                D) apply_push l;;
            esac
        }
    }
}


function check_endgame {
    board_update
    board_banner "YOU WON"
    tput cup $((offset_figlet_y+6)) $offset_x
    tput cnorm # show cursor
    stty echo # enable output
    echo -n "Want to keep on going (Y/N): "
    read result
    if [[ $result != 'n' && $result != 'N' ]]; then
        tput civis # hide cursor
        stty -echo # disable output
        TARGET="∞" won_flag=0
        unset board_old
        board_tput_status; status
        board_print $BOARD_SIZE
    fi
}


function status {
    printf "tiles: %-9d" "$tiles"
    printf "score: %-9d" "$score"
    printf "moves: %-9d" "$moves"
    printf "target: %-9s" "$TARGET"
    echo
}


function game_loop {
    declare tiles=0
    # let board[1]=1024
    # let board[2]=1024
    generate_piece
    while true; do
        let change && {
            generate_piece
            board_tput_status; status
            board_update
            change=0
            let moves++
        }

        key_react # before end game check, so player can see last board state
        test $tiles == $N && check_moves
    done
}


declare score=0 moves=0 won_flag=0
trap "board_banner 'GAME OVER'; exit" INT #handle INTERRUPT
let N="BOARD_SIZE * BOARD_SIZE"
board_init $BOARD_SIZE
exec 2>&3 # redirecting errors

echo -e $header
status
board_print $BOARD_SIZE
game_loop
