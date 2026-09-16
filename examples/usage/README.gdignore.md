# Why this folder has a `.gdignore`

This folder is an example that shows, exactly as it is, **"what gohud looks like installed in a game
project"**. That means it holds **one more copy** of `addons/gohud/` inside it, and that copy
**declares the same 35 `class_name`s** — `GoUi`, `GoConfig`, `GoStyle` and the rest.

🛑 **When the same `class_name` exists twice, Godot picks one — and nobody gets to say which.**
Which one it picks depends on the project's scan order and the `.godot` cache, so the same repository
can resolve differently from machine to machine. And **not one line of error appears** — the old copy's
classes work perfectly well on their own, so if the old one wins, the screen quietly behaves the old way.

🔑 The release ZIP **does not contain** this folder (`tools/check_package.py` checks that). The risk is
on the side that uses the whole repository — the **git submodule** route the README recommends.

A single empty `.gdignore` file makes Godot skip this folder entirely. `examples/demo/` has one for the
same reason, and `tools/check_classes.py` watches that such an overlap never comes back.
**Whenever you put a copy of the project in a folder, put a `.gdignore` there with it.**
