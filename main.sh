#!/usr/bin/env bash

function Usage {
    echo -e "Usage:  2048 [OPTIONS]";
    echo -e "\t-b | --board [0-9]\tBoard size (default)"
    echo -e "\t-t | --targe [0-9]\tCustom target"
    echo -e "\t-d | --debug [FILE]\tDebug info to file provided"
    echo -e "\t-h | --help\t\tDisplay this message"
    echo -e "\t-v | --version\t\tVersion information"
}

TEMP=$(getopt -o b:l:d:hv\
              -l board:,level:,debug:,help,version\
              -n "2048"\
              -- "$@")

if [ $? != "0" ]; then exit 1; fi

eval set -- "$TEMP"

board_size=4
target=2048

export WD="$(dirname $(readlink $0 || echo $0))"
exec 3> /dev/null

while true; do
    case $1 in
        -b|--board)   board_size=$2; shift 2;;
        -t|--target)  target=$2; shift 2;;
        -d|--debug)   exec 3>$2; shift 2;;
        -h|--help)    Usage; exit;;
        -v|--version) cat $WD/version; exit;;
        --)           shift; break
    esac
done

exec 2>&3 # redirecting errors

# extra argument
for arg do
    board_size=$arg
    break
done

#----------------------------------------------------------------------
# late loading

c0="\e[1;m"
c1="\e[1;31m"
c2="\e[1;38;5;22m"
c3="\e[1;32m"
c4="\e[1;38;5;226m"
c5="\e[1;34m"
c6="\e[1;35m"

header="${c1}2${c4}0${c5}4${c3}8${c0} (https://github.com/rhoit/2048)"

_colors[0]="\e[m"
_colors[2]="\e[1;33;48;5;24m"
_colors[4]="\e[1;39;48;5;12m"
_colors[8]="\e[1;38;5;227;48;5;202m"
_colors[16]="\e[1;39;48;5;208m"
_colors[32]="\e[1;39;48;5;9m"
_colors[64]="\e[1;39;48;5;1m"
_colors[128]="\e[46;39m"
_colors[256]="\e[48;5;27;39m"
_colors[512]="\e[1;38;5;9;48;5;11m"
_colors[1024]="\e[1;38;5;22;48;5;226m"
_colors[2048]="\e[1;38;5;8;48;5;237m"

export WD_BOARD=$WD/ASCII-board

source $WD_BOARD/board.sh

score=0 moves=0 won_flag=0
ESC=$'\e' # escape byte

trap "end_game 0; exit" INT #handle INT signal

function generate_piece {
    change=1
    while (( blocks < N )); do
        let index=RANDOM%N
        let board[index] || {
            local val=$((RANDOM%10?2:4))
            let blocks++

            # just for some delay effects/invert color
            # NOTE: this is the dirty hack!
            # local r=$((index/board_size))
            # local c=$((index-r*board_size))
            # local c_temp=${_colors[val]}
            # _colors[$val]="\e[30;48;5;15m"
            # LINES=$(tput lines)
            # block_update_ij $r $c $val # hack! shouldn't be accessed
            # _colors[$val]=$c_temp

            let board[index]=val
            break;
        }
    done
}

# perform push operation between two blocks
# inputs:
#   $1 - push position, for horizontal push this is row, for vertical column
#   $2 - recipient piece, this will hold result if moving or joining
#   $3 - originator piece, after moving or joining this will be left empty
#   $4 - direction of push, can be either "up", "down", "left" or "right"
#   $5 - if anything is passed, do not perform the push, only update number of valid moves

function push_blocks {
    case $4 in
        u) let first_="$2 * board_size + $1";
           let second="($2 + $3) * board_size + $1";;
        d) let first_="(board_size - 1 - $2) * board_size + $1";
           let second="(board_size - 1 - $2 - $3) * board_size + $1";;
        l) let first_="$1 * board_size + $2";
           let second="$1 * board_size + ($2 + $3)";;
        r) let first_="$1 * board_size + (board_size - 1 - $2)";
           let second="$1 * board_size + (board_size - 1 - $2 - $3)";;
    esac

    let ${board[$first_]} || {
        let ${board[$second]} && {
            if test -z $5; then
                board[$first_]=${board[$second]}
                let board[$second]=0
                let change=1
            else
                let next_mov++
            fi
        }
        return
    }

    let ${board[$second]} && let flag_skip=1
    let "${board[$first_]}==${board[second]}" && {
        if test -z $5; then
            let board[$first_]*=2
            test "${board[first_]}" = "$target" && won_flag=1
            let board[$second]=0
            let blocks-=1
            let change=1
            let score+=${board[$first_]}
        else
            let next_mov++
        fi
    }
}

function apply_push { # $1: direction; $2: mode
    for ((i=0; i < $board_size; i++)); do
        for ((j=0; j < $board_size; j++)); do
            flag_skip=0
            let increment_max="board_size - 1 - j"
            for ((k=1; k <= $increment_max; k++)); do
                let flag_skip && break
                push_blocks $i $j $k $1 $2
            done
        done
    done
    let won_flag && end_game 1
}

function check_moves {
    next_mov=0
    apply_push u fake
    apply_push d fake
    apply_push l fake
    apply_push r fake
    let next_mov==0 && end_game 0
}

function key_react {
    read -d '' -sn 1
    test "$REPLY" = "$ESC" && {
        read -d '' -sn 1 -t1
        test "$REPLY" = "[" && {
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

function figlet_wrap {
    > /dev/null which figlet && {
        # for calculation of rescaling
        let offset_figlet_y="board_max_y - size * b_height + 3"
        tput cup $offset_figlet_y 0;
        /usr/bin/figlet -c -w $COLUMNS "$*"
        tput cup $board_max_y 0;
        return
    }

    echo $*
    echo "install 'figlet' to display large characters."
}

function end_game {
    if (( $1 == 1 )); then
        box_board_update
        status="YOU WON"
        figlet_wrap $status
        tput cup $LINES 0;
        echo -n "Want to keep on going (Y/N): "
        read -d '' -sn 1 result > /dev/null
        if [[ $result != 'n' && $result != 'N' ]]; then
            echo -n "Y"
            target="∞"
            won_flag=0
            tput cup 2 0
            box_board_print $board_size
            unset old_board
            return
        fi
    else
        status="GAME OVER"
        figlet_wrap $status
    fi

    box_board_terminate
    exit
}

function status {
	printf "blocks: %-9d" "$blocks"
	printf "score: %-9d" "$score"
	printf "moves: %-9d" "$moves"
	printf "target: %-9s" "$target"
	echo
}

function main {
    let N="board_size * board_size"

    let blocks=0
    for ((i=0; i < N; i++)); do
        let old_board[i]=0
        let board[i]=0 #$i%3?0:1024
        # let board[i] && let blocks++
    done

    box_board_init $board_size
    echo -e $header
    status
    box_board_print $board_size

    generate_piece
    while true; do
        let change && {
            generate_piece
            # flick the generated piece
            box_board_tput_status; status
            box_board_update
            change=0
            echo moves: $moves >&3
            let moves++
        } #<&-

        key_react # before end game check, so player can see last board state
        let blocks==N && check_moves
    done
}

main
