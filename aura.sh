#!/bin/bash

aur() {
	pushd /tmp >> /dev/null
	git clone https://aur.archlinux.org/$1
	cd $1
	makepkg -si
	cd ..
	rm -rf $1
	popd >> /dev/null
}

aurs() {
	curl -s "https://aur.archlinux.org/rpc/?v=5&type=search&by=name&arg=$1" | jq '.results[] | "\(.Name) -> \(.Description)"'
}

auru() {
    local PACKAGES=$(pacman -Q)
    local TOTAL=$(pacman -Q | wc -l)

    for i in $(seq 0 200 $TOTAL); do
        local UPDATES+=$(echo $PACKAGES \
            | tr ' ' '\n' \
            | tail -n $((TOTAL - i)) \
            | head -n 200 \
            | cut -d" " -f1 \
            | tr '\n' ' ' \
            | curl -s $(echo "https://aur.archlinux.org/rpc/?v=5&type=info"$(sed -r 's/(\S*)\s/\&arg[]=\1/g')));
    done;

    local AURPKG=$(echo $UPDATES \
                    | jq -M '.results[] | "\(.Name)"' \
                    | tr -d '"')

    for f in $AURPKG; do
        local PKGVER+=$(echo "$(pacman -Qs "^$f\$" | cut -d" " -f2) ");
    done;

    local i=1 
    local UPS=$(echo $UPDATES \
        | jq '.results[] | "\(.Name)>\(.Version)"' \
        | tr -d '"')
    
    for ver in $PKGVER; do
        local FINAL+=$(echo "$(echo $UPS| cut -d" " -f$i)>$ver ")
        i=$((i+1));
    done;

    echo $FINAL \
        | tr ' ' '\n' \
        | sed -E 's/([^>]+)>([^>]+)>([^>]+)/\1>\3>\2/g' \
        | column -ts'>' -N PKG,INSTALED,REMOTE
}

case $1 in
    -R*)
        sudo pacman -Rsn $2
        ;;
    -S)
        aur $2
        ;;
    -Ss)
        aurs $2
        ;;
    -Syu|-Syyu)
        auru
        ;;
esac
