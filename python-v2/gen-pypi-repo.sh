#!/usr/bin/env bash
# coding=utf-8
#
# Generate a PyPI-compatible Python repository.
#
set -euo pipefail

# See: http://mywiki.wooledge.org/BashFAQ/028
readonly script_name='gen-fixtures.sh'

# Print usage instructions to stdout.
show_help() {
fmt <<EOF
Usage: $script_name <output-dir> <assets-dir> <base-url>

Generate a PyPI-compatible Python repository from the data in <assets-dir>.
Place the repository's contents into <output-dir>. <output-dir> need not exist,
but all parent directories must exist.

<base-url> is the URL of where the fixtures will be hosted. It is needed for
generating absolute URLs.
EOF
}

# Fetch arguments from user.
if [ "$#" -lt 3 ]; then
    echo 1>&2 'Error: Too few arguments received.'
    echo 1>&2
    show_help 1>&2
    exit 1
elif [ "$#" -gt 3 ]; then
    echo 1>&2 'Error: Too many arguments received.'
    echo 1>&2
    show_help 1>&2
    exit 1
fi
output_dir="$(realpath "$1")"
assets_dir="$(realpath --canonicalize-existing "$2")"
base_url="$3"

# Create a workspace, and schedule it for deletion.
cleanup() { if [ -n "${working_dir:-}" ]; then rm -rf "${working_dir}"; fi }
trap cleanup EXIT  # bash pseudo signal
trap 'cleanup ; trap - SIGINT ; kill -s SIGINT $$' SIGINT
trap 'cleanup ; trap - SIGTERM ; kill -s SIGTERM $$' SIGTERM
working_dir="$(mktemp --directory)"

# Create the Simple API index.html page
mkdir "${working_dir}/simple/"
jinja2 --format json \
    "${assets_dir}/simple/index.html.template" \
    "${assets_dir}/projects.json" \
    > "${working_dir}/simple/index.html"

# Create the index.html pages for each individual package.
# TODO: Convert $projects to an array.
projects="$(jq --raw-output ".projects|keys|.[]" < "${assets_dir}/projects.json")"
mkdir "${working_dir}/packages"
for project in ${projects}; do

    # Create the simple distribution index from a jinja template.
    # The simple API should be layed out like:
    #   simple
    #   ├── index.html
    #   ├── Django
    #   |   └── index.html
    #   └── scipy
    #       └── index.html
    mkdir "${working_dir}/simple/${project}"
    jinja2 "${assets_dir}/simple/distribution.html.template" --format=json \
           "${assets_dir}/projects.json" -D base_url="${base_url}" -D \
           project="${project}" > "${working_dir}/simple/${project}/index.html"

    # Create the PyPI json API pages
    # This should be layed out like:
    #   pypi
    #   ├── Django
    #   |   └── json
    #   |       └── index.html
    #   └── scipy
    #       └── json
    #           └── index.html
    mkdir -p "${working_dir}/pypi/${project}/json/"

    # Get project JSON metadata from PyPI
    # NOTE: The index.html file is actually JSON.
    distributions="$(jq ".[\"projects\"]|.[\"${project}\"]" < "${assets_dir}/projects.json")"
    pushd "${working_dir}/pypi/${project}/json/"
    curl --silent "https://pypi.org/pypi/${project}/json" > index.html.raw
    "${assets_dir}/parser.py" index.html.raw --available_distributions "${distributions}" > index.html
    rm index.html.raw
    popd

    # Get all referenced eggs and wheels
    # TODO: Convert $urls to an array.
    urls="$(jq --raw-output '.["releases"]|.[]|.[]|.url' <"${working_dir}/pypi/${project}/json/index.html")"
    pushd "${working_dir}/packages"
    for url in ${urls}; do
        echo "Fetching ${url}"
        curl --silent -O "${url}" &
    done
    wait
    popd

    pushd "${working_dir}/pypi/${project}/json/"
   "${assets_dir}/parser.py" index.html --base_url "${base_url}" > index.html
    popd

done

cp -r --no-preserve=mode --reflink=auto "${working_dir}" "${output_dir}"
