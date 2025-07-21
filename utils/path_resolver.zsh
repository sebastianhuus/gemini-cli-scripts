# Utility for finding the path to this repository when called from path. 
# Is able to navigate symlinks.
find_script_base() {
    local real_script="${0:A}"
    local script_dir="${real_script:h}"

    [[ -d "$script_dir/utils" ]] && echo "$script_dir" && return
    [[ -d "$script_dir/../utils" ]] && echo "$script_dir/.." && return
    echo "$script_dir"
}