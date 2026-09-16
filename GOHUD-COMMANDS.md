## How to package

- By default, the command below bumps the patch version only

bash tools/package.sh
# 1.0.0 → 1.0.1

- To bump the minor version, run this instead.

bash tools/package.sh --increase-minor-version
# 1.0.1 → 1.1.0