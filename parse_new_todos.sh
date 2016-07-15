# Find all the currently modified lines with TODOs.
#
# TODO(riley|sergei): Flesh out docstring.

DATE_CMD='gdate'
POTENTIAL_TODOS=()

main() {
    process_changed_files < <(difiles)
    process_potential_todos
}

is_first_todo=true
process_changed_files() {
    if [ "$is_first_todo" = true ]; then
        echo -e "Here's a list of TODOs you added in this commit:"
        is_first_todo=false
    fi

    while read filename; do
        # NOTE: Added this because it would fail otherwise on a removed file.
        # TODO(sergei): Remove this comment :P
        if [ -f $filename ]; then
            lines=$(get_changed_lines "$filename")
            process_lines "$lines"
        fi
    done
}

get_changed_lines() {
    git diff HEAD "$1" \
        | grep '^+' \
        | grep -v '^+++ ' \
        | sed -e 's/^+//'
}

process_lines() {
    lines="$1"
    while read line; do
        # If this matches, we're pretty confident that it's a comment so we
        # print and process it for saving.
        grep -q '[#(//)] TODO[\(:]' <<< "$line"
        found_match=$?

        if [ $found_match -eq 0 ]; then
            echo -e "+ $filename | $line"
            save_todo "$filename" "$line"

        # If the above doesn't match, there's still a chance that it's a TODO.
        # We run it through a more permissive filter; if *that* matches we
        # prompt the user for input.
        elif [[ $line =~ "TODO" ]]; then
            # NOTE: Appending to global arrays must happen in the main process.
            # If this is ever refactored, make sure that this function is not
            # in a subshell.
            POTENTIAL_TODOS+=("$line")
        fi
    done < <(echo "$lines")
}

save_todo() {
    filename=$1
    todo=$2
    date_pattern="TODO\([^\)\[]*\[(.*)\]\):?\ *(.*)"

    shopt -s nocasematch
    if [[ $todo =~ $date_pattern ]]; then
        DATE="${BASH_REMATCH[1]}"
        MSG="${BASH_REMATCH[2]}"
        echo -e $("$DATE_CMD" --iso-8601 --date "$DATE")"  |  $filename  |  $MSG" >> ~/.todos
    fi
}

process_potential_todos() {
    for line in "${POTENTIAL_TODOS[@]}"; do
        # TODO(riley): We could split things into three lists:
        #
        # Definitely TODO: Automatically print and save all of these.
        # Maybe TODO, no date stamp: Automatically print all of these after a
        #                            "these *might* be todos" disclaimer.
        # Maybe TODO, date stamp: Prompt user and save accordingly.
        check_if_todo | save_todo
    done
}

check_if_todo() {
    while true; do
        read -p "Is this a TODO? [y/n]" -n 1 reply
        case $reply in
            [Yy]* ) echo $reply; break;;
            [Nn]* ) return;;
            * ) echo "Please answer y or n.";;
        esac
    done
}

difiles () {
    git status --porcelain | awk '{print $2}'
}

main $*
