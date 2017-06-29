#!/bin/bash
# vim: set filetype=sh syntax=sh et ts=4 sts=4 sw=4 si:

# This is to be invoked with the current default directory set to the Jenkins
# workspace, which contains the result of cloning the remote repository. Thus
# "tooling" must be a subdirectory of the current default directory.
#
# The source files intentionally exclude license and similar files that carry
# no real value as documentation.
#

# This searches all subdirectories of the Jenkins workspace (except for
# this one, of course) for 'tooling/docs-automation.d' directories.
# It then executes the scripts in each of those directories, and
# copies all tarballs named '*-doc_*.tar.gz' to the workspace level.

set -e

msg() {
    echo $* >&2
}

generate_docs() {
    local dir="$1"; shift
    local toolpath="./tooling/docs-automation.d"
    local f
    local script_name

    msg "Checking $dir"
    pushd $dir

    ls -1 "$toolpath" | \
        while read f; do
            script_name="$(realpath $toolpath/$f)"
            msg "Checking $script_name"
            if [ -x $script_name ] && [ ! -d $script_name ]; then
                msg "Running $script_name..."
                $script_name
            fi
        done
    popd
}

find . -name '*-doc_??????????????.tar.gz' -delete | true

find -path '*/tooling/docs-automation.d' -type d | \
    while read path; do
        if [ ! -f $path/.docignore ]; then
            dir=$(dirname $(dirname $path))
            generate_docs "$dir"
        else
            msg "Skipping $path because of .docignore file"
        fi
    done

find . -type f -name '*-doc_??????????????.tar.gz' | \
    while read file; do
        cp $file ./
    done

