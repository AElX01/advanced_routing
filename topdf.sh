#!/usr/bin/env bash

pandoc $1 -o $2 --from markdown+yaml_metadata_block+raw_html --template eisvogel --toc-depth 6 --top-level-division=chapter --highlight-style breezedark 
