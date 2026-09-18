## How to package

- The version comes from `package.json`. Packaging never raises it.

{
  "version": "1.2.3"
}

- Build the ZIP for that version. Running it again with the same version rebuilds and replaces the ZIP.

bash tools/package.sh
# builds/1.2.3/gohud-1.2.3.zip

- To release a new version, edit `package.json` first, then run the same command.
