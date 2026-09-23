## How to package

- The version comes from `package.json`. Packaging never raises it.

{
  "version": "1.2.3"
}

- Build the ZIP for that version. Running it again with the same version rebuilds and replaces the ZIP.

bash tools/package.sh
# builds/1.2.3/gohud-1.2.3.zip

- To release a new version, edit `package.json` first, then run the same command.

## How to release

- One command, in order: every check → the ZIP → that ZIP installed into an empty project.

bash tools/release.sh

- It stops at the first failure and never commits, tags or uploads. Those steps are printed at the end.
- The README lines that announce the version (`**Version 1.2.3.**` · `**버전 1.2.3.**`) must name the
  version being packaged, or packaging stops — what is new in a release is a sentence a person writes.
