"""A `.tres` reduced to what it actually says, so two spellings of one resource compare equal.

## Why this exists
`make_theme.py` writes the theme files, and a byte comparison used to decide whether they still match
their source. But the moment the theme is **opened and saved in the Godot editor**, the same theme comes
back spelled differently — and the check went red for a release that had nothing wrong with it
(measured 2026-09-23, `themes/gohud_dark.tres` · `themes/gohud_light.tres`):

| The editor writes | The generator writes |
|---|---|
| `uid="uid://bjn2g4jdcu67v"` on the resource and every `ext_resource` | no uid |
| `load_steps=72` | none |
| `content_margin_bottom = 10.0` | `content_margin_bottom = 10` |
| nothing — a property holding the engine default is dropped | `corner_detail = 8` |
| `ext_resource` lines sorted by path, sub-resource ids of its own | generator order and ids |

None of that changes one pixel. What does change a pixel is a colour, a margin, a border — or a theme
entry pointing at a different StyleBox. So references are resolved **by the content they point at**,
which keeps wrong wiring visible while the spelling is ignored.
"""
import re

# The editor drops a property that already holds the engine default; the generator writes it out.
# Only add a name here when the value is the engine's own default for that property.
ENGINE_DEFAULTS = {"corner_detail": "8"}
HEADER = re.compile(r'^\[(?P<kind>[a-z_]+)(?P<attrs>[^\]]*)\]\s*$')
ATTR = re.compile(r'(\w+)=("(?:[^"\\]|\\.)*"|[^\s\]]+)')
QUOTED = re.compile(r'"(?:[^"\\]|\\.)*"')
NUMBER = re.compile(r'(?<![\w.])-?\d+\.\d+(?![\w.])')


def _number(match):
    value = float(match.group())
    return str(int(value)) if value == int(value) else repr(value)


def _value(text):
    """`10.0` → `10`, inside compound values too, but never inside a quoted string."""
    out, last = [], 0
    for quote in QUOTED.finditer(text):
        out.append(NUMBER.sub(_number, text[last:quote.start()]))
        out.append(quote.group())
        last = quote.end()
    out.append(NUMBER.sub(_number, text[last:]))
    return "".join(out).strip()


def _blocks(text):
    """[(kind, attrs, properties)] in file order, with `\\n`-continued values joined."""
    blocks, kind, attrs, props, key, buffer = [], None, {}, {}, None, []

    def close_property():
        if key is not None:
            props[key] = _value("\n".join(buffer))

    for line in text.splitlines():
        header = HEADER.match(line)
        if header and not (key is not None and buffer and not line.startswith("[")):
            close_property()
            if kind is not None:
                blocks.append((kind, attrs, props))
            kind, props, key, buffer = header.group("kind"), {}, None, []
            attrs = {name: value.strip('"') for name, value in ATTR.findall(header.group("attrs"))}
            continue
        if kind is None:
            continue
        assignment = re.match(r'^(\w[\w/. ]*?)\s*=\s*(.*)$', line)
        if assignment:
            close_property()
            key, buffer = assignment.group(1), [assignment.group(2)]
        elif key is not None:
            buffer.append(line)
    close_property()
    if kind is not None:
        blocks.append((kind, attrs, props))
    return blocks


def canonical(text):
    """The resource as a comparable structure: what it holds, not how it is spelled."""
    externals, subs, resource, order = {}, {}, {}, []
    for kind, attrs, props in _blocks(text):
        if kind == "ext_resource":
            externals[attrs.get("id", "")] = ("ext", attrs.get("type", ""), attrs.get("path", ""))
        elif kind == "sub_resource":
            subs[attrs.get("id", "")] = (attrs.get("type", ""), props)
            order.append(attrs.get("id", ""))
        elif kind == "resource":
            resource = props
    resolved = {}

    def reference(name, seen):
        if name in resolved:
            return resolved[name]
        if name in seen:  # a cycle cannot be reduced further; its id is all there is
            return ("sub-cycle", name)
        if name not in subs:
            return ("sub-missing", name)
        kind, props = subs[name]
        value = (kind, tuple(sorted((key, resolve(text, seen | {name}))
                                    for key, text in props.items()
                                    if ENGINE_DEFAULTS.get(key) != text)))
        resolved[name] = value
        return value

    def resolve(text, seen=frozenset()):
        ext = re.fullmatch(r'ExtResource\("([^"]+)"\)', text)
        if ext:
            return externals.get(ext.group(1), ("ext-missing", ext.group(1)))
        sub = re.fullmatch(r'SubResource\("([^"]+)"\)', text)
        if sub:
            return reference(sub.group(1), seen)
        return text

    return {key: resolve(value) for key, value in resource.items()
            if ENGINE_DEFAULTS.get(key) != value}


def _detail(one, two):
    """The property that actually differs — "a StyleBoxFlat differs" says nothing you can act on."""
    if isinstance(one, tuple) and isinstance(two, tuple) and len(one) == len(two) == 2 \
            and isinstance(one[1], tuple) and isinstance(two[1], tuple):
        if one[0] != two[0]:
            return "%s ≠ %s" % (one[0], two[0])
        left, right = dict(one[1]), dict(two[1])
        parts = []
        for key in sorted(left.keys() | right.keys()):
            if left.get(key) != right.get(key):
                inner = _detail(left.get(key, "—"), right.get(key, "—"))
                parts.append("%s %s" % (key, inner))
        return "%s { %s }" % (one[0], " · ".join(parts[:4]))
    return "%.60s ≠ %.60s" % (one, two)


def differences(left, right):
    """The keys whose meaning differs, as readable lines (empty when the two say the same)."""
    one, two = canonical(left), canonical(right)
    lines = []
    for key in sorted(one.keys() | two.keys()):
        if one.get(key) != two.get(key):
            lines.append("    %s: %s" % (key, _detail(one.get(key, "—"), two.get(key, "—"))))
    return lines
