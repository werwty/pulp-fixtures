#!/usr/bin/env python3
# coding=utf-8
import json
import sys
import copy


def main(metadata_path, available_distributions):
    """Cut unwanted values out of the JSON metadata at ``metadata_path``."""
    with open(metadata_path) as fh:
        old_metadata = json.load(fh)
    available_distributions = json.loads(available_distributions)

    new_metadata = copy.deepcopy(old_metadata)
    for release, distributions in old_metadata['releases'].items():
        # release: e.g. "1.0.1"
        # distributions: e.g. [], or [{egg info}, {wheel info}]
        for distribution in distributions:
            if distribution['filename'] not in available_distributions:
                new_metadata['releases'][release].remove(distribution)

        if new_metadata['releases'][release] == []:
            del new_metadata['releases'][release]

    print(json.dumps(new_metadata))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
