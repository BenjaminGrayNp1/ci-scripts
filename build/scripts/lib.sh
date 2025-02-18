#!/bin/bash

function get_alternate_binds()
{
    local alternates
    local git_dir

    git_dir=$(cd $SRC; git rev-parse --absolute-git-dir)
    alternates="$git_dir/objects/info/alternates"
    if [[ -r "$alternates" ]]; then
        for line in $(cat "$alternates")
        do
            echo "-v $line:$line:ro "
        done
    fi
}

function get_output_dir()
{
    local script_base="$1"
    local subarch="$2"
    local distro="$3"
    local version="$4"
    local task="$5"
    local defconfig="$6"
    local targets="$7"
    local clang="$8"
    local d

    if [[ -z "$script_base" || -z "$subarch" || -z "$distro" ]]; then
        echo "Error: not enough arguments to get_output_dir()" >&2
        return 1
    fi

    if [[ -n "$CI_OUTPUT" ]]; then
        d="$CI_OUTPUT/$subarch@$distro"
    else
        d="$script_base/../output/$subarch@$distro"
    fi

    if [[ -n "$version" ]]; then
        d="$d@$version"
    fi

    case "$task" in
        kernel) ;&
        clean-kernel)
            if [[ -n "$defconfig" ]]; then
                defconfig="${defconfig//\//_}"
                d="$d/$defconfig"
            fi
            ;;
        ppctests) ;&
        selftests) ;&
        clean-selftests)
            if [[ -n "$targets" ]]; then
                targets=${targets// /_}
                targets=${targets//\//_}
                d="$d/selftests_$targets"
            else
                d="$d/selftests"
            fi
            ;;
        perf) ;&
        clean-perf)
            d="$d/perf"
            ;;
    esac

    if [[ -n "$clang" ]]; then
	d="${d}_clang"
    fi

    echo "$d"

    return 0
}

function get_default_version()
{
    local distro="$1"
    local latest

    case "$distro" in
        ubuntu) latest="$UBUNTU_LATEST" ;;
        ubuntu-allcross) latest="$UBUNTU_LATEST" ;;
        fedora) latest="$FEDORA_LATEST" ;;
    esac

    if [[ -z "$latest" ]]; then
        echo "Error: No default version for $distro" >&2
        return 1
    fi

    echo "$latest"

    return 0
}

DOCKER="docker"
PODMAN_OPTS=""
DOCKER_REGISTRY=""
if command -v podman > /dev/null; then
    if (command -v docker && docker --version | grep -q podman) > /dev/null || ! command -v docker > /dev/null; then
        DOCKER="podman"
        PODMAN_OPTS="--security-opt label=disable --userns=keep-id"
        DOCKER_REGISTRY="docker.io/"
    fi
fi
