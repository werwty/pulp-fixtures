#!/usr/bin/env python3
# coding=utf-8

import argparse
import copy
import json

from urllib.parse import urljoin


def main(metadata_path, available_distributions):
    """Cut unwanted values out of the JSON metadata at ``metadata_path``."""
    with open(metadata_path) as fh:
        old_metadata = json.load(fh)
    available_distributions = json.loads(available_distributions)

    new_metadata = copy.deepcopy(old_metadata)
    for release, distributions in old_metadata['releases'].items():
        # release: e.g. "1.0.1"
        # distributions: e.g. [], or [{egg info}, {wheel info}]
        for i, distribution in enumerate(distributions):

            # remove distribution if it isn't in the list of available distributions
            if distribution['filename'] not in available_distributions:
                new_metadata['releases'][release].remove(distribution)

        if new_metadata['releases'][release] == []:
            del new_metadata['releases'][release]

    print(json.dumps(new_metadata, indent=4))

def replace_url(metadata_path, base_url):
    """Update distribution urls of the JSON metadata at ``metadata_path`` to ``base_url``"""
    with open(metadata_path) as fh:
        metadata = json.load(fh)

    # Update the urls for the new metadata
    for release, distributions in metadata['releases'].items():
        for distribution in distributions:
            distribution['url'] = \
                urljoin(urljoin(base_url, 'packages/'),
                        distribution['filename'])

    print(json.dumps(metadata, indent=4))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Script to process PyPI JSON metadata')
    parser.add_argument('metadata_path', help="PATH to a PYPI metadata file")
    parser.add_argument('--available_distributions', nargs='?',
                        help="A JSON list of distribution filenames to keep e.g. "
                             "[\"Django-1.8.5-py2.py3-none-any.whl\", \"Django-1.8.5.tar.gz\"]")
    parser.add_argument('--base_url', nargs='?', help="Base_url to download the distribution package")

    args = parser.parse_args()

    if(args.available_distributions):
        main(args.metadata_path, args.available_distributions)

    if (args.base_url):
        replace_url(args.metadata_path, args.base_url)
