#!/bin/bash
#shellcheck disable=2155

readonly VERSION=1.0

shopt -s extglob

aur() {
    pushd /tmp >>/dev/null || return
    if [[ -d "$1" ]]; then
        cd "$1" || return
        git pull
    else
        git clone https://aur.archlinux.org/"$1"
        cd "$1" || return
    fi
    [ "$edit" ] && ${EDITOR:-vi} PKGBUILD
    makepkg -si --clean "${@:2}"
    cd ..
    rm -rf "$1"
    popd >>/dev/null || return
}

aurs() {
    curl -s "https://aur.archlinux.org/rpc/?v=5&type=search&by=name&arg=$1" |
        jq '.results[] | "\(.Name) -> \(.Description)"'
}

auru() {
    local other_args=()
    local pkg_args
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -*) other_args+=("$1") ;;
            *) pkg_args="${pkg_args}&arg[]=$1" ;;
        esac
        shift
    done
    if [ -z "$pkg_args" ]; then
        local pkg_args="&$(pacman -Qm |
            cut -d' ' -f1 |
            sed -r 's/(.*)/arg[]=\1/g' |
            tr '\n' '&' |
            sed -r 's/&$//g')"
    fi
    echo -n "Fetching info from aur"
    local url="https://aur.archlinux.org/rpc/?v=5&type=info&by=name$pkg_args"
    local AUR_JSON="$(curl --silent "$url" | jq .results)"
    echo -en "\r\e[K"
    echo -en "Compiling info"
    local PACKAGES
    mapfile -t PACKAGES < <(
        pacman -Qm |
            while read -r pkg version; do
                {
                    v="$(echo "$AUR_JSON" |
                        jq --raw-output ".[] | select(.Name == \"$pkg\") | .Version")"
                    [[ "$(echo -e "$v\n$version" | sort -V | tail -1)" != "$version" ]] &&
                        echo "$pkg,$version,$v"
                } &
            done |
            sort
    )
    echo -en "\r\e[K"
    [[ "${#PACKAGES[@]}" -lt 1 ]] && echo "no packages to upgrade" && return
    printf '%s\n' "${PACKAGES[@]}" | column -ts',' -N PKG,INSTALED,REMOTE
    read -r -p 'Wanna Update [N/y]? '
    case $REPLY in
        y | yes | Y | Yes)
            for p in $(printf '%s\n' "${PACKAGES[@]}" | cut -d',' -f1); do
                aur "$p" "${other_args[@]}"
            done
            ;;
        *)
            echo Bye
            ;;
    esac
}

self_update() {
    git clone https://github.com/jtexeira/tiny-aura.git /tmp/tiny-aura
    cd /tmp/tiny-aura || return 1
    sudo make
    cd || return 1
    rm -rf /tmp/tiny-aura
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
            other_args=()
            pkgs=()
            while [ "$#" -gt 0 ]; do
                case "$1" in
                    -*) other_args+=("$1") ;;
                    *) pkgs+=("$1") ;;
                esac
                shift
            done
            for p in "${pkgs[@]}"; do
                aur "$p" "${other_args[@]}"
            done
            ;;
        -Ss)
            aurs "$2"
            ;;
        -S+(y)u)
            auru "${@:2}"
            ;;
        update)
            self_update
            ;;
        -v | --version)
            echo "$0: $VERSION"
            ;;
        *)
            main -S "$@"
            ;;
    esac
}

main "$@"
