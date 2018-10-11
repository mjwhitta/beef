#!/usr/bin/env bash
#
# Requires ~400MB of free disk space
#
# Build docker image with:
# $ ./docker_build_alpine_image.sh
#
# Run the docker image:
#
# $ beef_alpine() {
#    local rm
#    case "$1" in
#        "-r"|"--rm") rm="--rm" && shift ;;
#    esac
#
#    sudo iptables -I INPUT --dport 3000 -j ACCEPT
#    sudo iptables -I INPUT --dport 6789 -j ACCEPT
#
#    mkdir -p /tmp/beef
#    docker run --cap-drop=ALL -i --name beef_$(date +%F_%H%M%S%N) \
#       -p 3000:3000 -p 6789:6789 $rm -tv /tmp/beef:/beef:Z \
#       beef_alpine:latest $@
#
#    sudo iptables -D INPUT --dport 3000 -j ACCEPT
#    sudo iptables -D INPUT --dport 6789 -j ACCEPT
# }
# $ alias beef="beef_alpine --rm ./beef"
# $ beef -ax
#
# Once you quit the session, get the container id with something like:
#
# $ containerid="$(docker ps -a | awk '/beef/ {print $NF}')"
#
# To get into that shell again just type:
#
# $ docker start -ai $containerid
#
# To share those images:
#
# $ docker export $containerid | xz >container.tar.xz
# $ xz -d <container.tar.xz | docker import -
#
# When finished:
#
# $ docker rm -f $containerid
#
# If you need sudo to install more packages within Docker, remove
# --cap-drop=ALL from the beef function.

### Helpers begin
check_deps() {
    for d in "${deps[@]}"; do
        [[ -n $(command -v "$d") ]] || errx 128 "$d is not installed"
    done; unset d
}
err() { echo -e "${color:+\e[31m}[!] $*\e[0m"; }
errx() { echo -e "${color:+\e[31m}[!] ${*:2}\e[0m"; cleanup "$1"; }
good() { echo -e "${color:+\e[32m}[+] $*\e[0m"; }
info() { echo -e "${color:+\e[37m}[*] $*\e[0m"; }
long_opt() {
    local arg shift="0"
    case "$1" in
        "--"*"="*) arg="${1#*=}"; [[ -n $arg ]] || usage 127 ;;
        *) shift="1"; shift; [[ $# -gt 0 ]] || usage 127; arg="$1" ;;
    esac
    echo "$arg"
    return $shift
}
subinfo() { echo -e "${color:+\e[36m}[=] $*\e[0m"; }
warn() { echo -e "${color:+\e[33m}[-] $*\e[0m"; }
### Helpers end

cleanup() {
    rm -rf "$tmp_docker_dir"
    [[ "${1:-0}" -eq 0 ]] || exit "$1"
}

usage() {
    cat <<EOF
Usage: ${0##*/} [OPTIONS]

Build a beef docker image that uses local user/group IDs.

Options:
    -b, --branch=BRANCH    Use specified beef branch (default: master)
    -h, --help             Display this help message
    --no-color             Disable colorized output

EOF
    exit "$1"
}

declare -a args deps
unset help
branch="master"
color="true"
deps+=("curl")
deps+=("docker")
deps+=("jq")
# repo="beefproject/beef"
repo="mjwhitta/beef"
github="https://github.com/$repo.git"

# Check for missing dependencies
check_deps

# Parse command line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        "--") shift && args+=("$@") && break ;;
        "-b"|"--branch"*) branch="$(long_opt "$@")" || shift ;;
        "-h"|"--help") help="true" ;;
        "--no-color") unset color ;;
        *) args+=("$1") ;;
    esac
    shift
done
[[ ${#args[@]} -eq 0 ]] || set -- "${args[@]}"

# Check for valid params
[[ -z $help ]] || usage 0
[[ $# -eq 0 ]] || usage 1
if [[ "$(id -u)" -ne 0 ]] && id -Gn | grep -qvw "docker"; then
    errx 2 "You are not part of the docker group"
fi

trap "cleanup 126" INT

# Create Dockerfile
tmp_docker_dir=".docker_alpine"
commit="$(
    curl -Ls "http://api.github.com/repos/$repo/commits/$branch" | \
    jq -cMrS ".sha"
)"
mkdir -p "$tmp_docker_dir"
cat >"$tmp_docker_dir/Dockerfile" <<EOF
# Using super tiny alpine base image
FROM alpine:latest

# Install bash b/c it's better
RUN apk upgrade && apk add bash

# Bash is better than sh
SHELL ["/bin/bash", "-c"]

# All one RUN layer, splitting into 3 increases size to ~360MB, wtf
# 1. Install dependencies
# 2. Add some convenient aliases to .bashrc
# 3. Clone and install beef
# 4. Clean up unnecessary files and packages
RUN set -o pipefail && \
    ( \
        apk upgrade && \
        apk add \
            git \
            shadow \
            sudo \
    ) && ( \
        echo "alias la=\"\\ls -AF\"" >>/root/.bashrc && \
        echo "alias ll=\"\\ls -Fhl\"" >>/root/.bashrc && \
        echo "alias ls=\"\\ls -F\"" >>/root/.bashrc && \
        echo "alias q=\"exit\"" >>/root/.bashrc && \
        echo "alias vim=\"vi\"" >>/root/.bashrc \
    ) && ( \
        cd /usr/share && \
        git clone -b $branch $github && \
        cd beef && \
        git checkout $commit && \
        sed -i -r "s/passwd:.+/passwd: \"cake\"/g" config.yaml && \
        echo "y" | ./install \
    ) && ( \
        rm -rf /tmp/* /var/cache/apk/* /var/tmp/* \
    )

# Initialize env
WORKDIR /usr/share/beef

CMD ["/bin/bash"]
EOF

# Tag old images
info "Tagging any old beef images"
while read -r tag; do
    case "$tag" in
        "beef_alpine:"*) docker image tag "${tag#*:}" "$tag" ;;
    esac
done < <(docker images | awk '{print $1":"$3}'); unset tag

findbase="$(
    docker images | grep -E "^(docker\.io\/)?alpine +latest "
)"

# Build image (may take a while)
info "Building image..."
info "This may take a long time..."

# Pull newest base image and build beef image
docker pull alpine:latest
(
    cd $tmp_docker_dir || errx 3 "$tmp_docker_dir not found"
    # shellcheck disable=SC2154
    docker build \
        ${http_proxy:+--build-arg http_proxy=$http_proxy} \
        ${https_proxy:+--build-arg https_proxy=$https_proxy} \
        -t beef_alpine:latest .
)

# Only remove base image if it didn't already exist
[[ -n $findbase ]] || docker rmi alpine:latest

info "done"

old_base="^(docker\.io\/)?alpine +<none>"
old_beef="^beef_alpine +[^l ]"
found="$(docker images | grep -E "($old_base)|($old_beef)")"
if [[ -n $found ]]; then
    # List old images
    echo
    info "Old images:"
    docker images | head -n 1

    while read -r line; do
        echo "$line"
    done < <(docker images | grep -E "($old_base)|($old_beef)")
    unset line

    # Prompt to remove old images
    unset remove
    echo
    while :; do
        read -n 1 -p "Remove old images (y/N/q)? " -rs ans
        echo
        case "$ans" in
            ""|"n"|"N"|"q"|"Q") break ;;
            "y"|"Y") remove="true"; break ;;
            *) echo "Invalid choice" ;;
        esac
    done

    if [[ -n $remove ]]; then
        # Remove old images
        while read -r tag; do
            docker rmi "$tag"
        done < <(
            docker images | awk "/$old_beef/ {print \$1\":\"\$3}"
        ); unset tag

        while read -r id; do
            docker rmi "$id"
        done < <(docker images | awk "/$old_base/ {print \$3}")
        unset id
    fi
fi
unset found

cleanup 0

cat <<EOF

It's suggested you add something like the following to your ~/.bashrc:

beef_alpine() {
    local rm
    case "\$1" in
        "-r"|"--rm") rm="--rm" && shift ;;
    esac

    sudo iptables -I INPUT -p tcp --dport 3000 -j ACCEPT
    sudo iptables -I INPUT -p udp --dport 3000 -j ACCEPT
    sudo iptables -I INPUT -p tcp --dport 6789 -j ACCEPT
    sudo iptables -I INPUT -p udp --dport 6789 -j ACCEPT

    mkdir -p /tmp/beef
    docker run --cap-drop=ALL -i --name beef_\$(date +%F_%H%M%S%N) \\
        -p 3000:3000 -p 6789:6789 \$rm -tv /tmp/beef:/beef:Z \\
        beef_alpine:latest \$@

    sudo iptables -D INPUT -p tcp --dport 3000 -j ACCEPT
    sudo iptables -D INPUT -p udp --dport 3000 -j ACCEPT
    sudo iptables -D INPUT -p tcp --dport 6789 -j ACCEPT
    sudo iptables -D INPUT -p udp --dport 6789 -j ACCEPT
}
alias beef="beef_alpine --rm ./beef"
EOF
