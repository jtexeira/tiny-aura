#!/bin/bash
#shellcheck disable=2155

shopt -s extglob

aur() {
    while [ $# -gt 0 ]; do
        pushd /tmp >> /dev/null || return
        git clone https://aur.archlinux.org/"$1"
        cd "$1" || return
        [ "$edit" ] && ${EDITOR:-vi} PKGBUILD
        makepkg -si --clean "${@:2}"
        cd ..
        rm -rf "$1"
        popd >> /dev/null || return
        shift
    done
}

aurs() {
    curl -s "https://aur.archlinux.org/rpc/?v=5&type=search&by=name&arg=$1" |
        jq '.results[] | "\(.Name) -> \(.Description)"'
}

auru() {
    local PACKAGES=$(pacman -Q)
    local TOTAL=$(pacman -Q | wc -l)

    for i in $(seq 0 200 "$TOTAL"); do
        local UPDATES+=$(echo "$PACKAGES" \
            | tr ' ' '\n' \
            | tail -n $((TOTAL - i)) \
            | head -n 200 \
            | cut -d" " -f1 \
            | tr '\n' ' ' \
            | curl -s "https://aur.archlinux.org/rpc/?v=5&type=info$(sed -r 's/(\S*)\s/\&arg[]=\1/g')");
    done;

    local AURPKG=$(echo "$UPDATES" \
                    | jq -M '.results[] | "\(.Name)"' \
                    | tr -d '"')

    for f in $AURPKG; do
        local PKGVER+=("$(pacman -Qs "^$f\$" | cut -d" " -f2) ");
    done;

    local i=1
    local UPS=$(echo "$UPDATES" \
        | jq '.results[] | "\(.Name)>\(.Version)"' \
        | tr -d '"')

    for ver in "${PKGVER[@]}"; do
        local FINAL+=("$(echo "$UPS" | cut -d" " -f$i)>$ver ")
        i=$((i+1));
    done;

    echo "${FINAL[@]}" \
       | tr ' ' '\n' \
       | sed -E 's/([^>]+)>([^>]+)>([^>]+)/\1>\3>\2/g' \
       | column -ts'>' -N PKG,INSTALED,REMOTE

    local conf
    read -r -p 'Wanna Update? ' conf
    case $conf in
        y|yes|Y|Yes)
            aur "$(echo "${FINAL[@]}" | sed -E 's/([^>]+)>([^>]+)>([^ ]+)/\1/g')"
            ;;
        *)
            echo Bye
            ;;
    esac
}

main() {
    case $1 in
        -e)
            edit=1
            main "${@:2}"
            ;;
        -R*)
            sudo pacman -Rsn "$2"
            ;;
        -S)
            shift
            aur "$@"
            ;;
        -Ss)
            aurs "$2"
            ;;
        -S+(y)u )
            auru
            ;;
    esac
}

main "$@"
