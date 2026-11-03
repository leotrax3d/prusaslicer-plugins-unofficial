# Marketplace descriptions

One Markdown file per Marketplace package, named after its id.

The Prusa Plugin Marketplace takes a package's name and short description from
`manifest.json` on its **first** release only. After that they can be changed only in the
author console, where each edit is moderated. The text that every release can still
change is the release notes shown under each version.

`.github/workflows/marketplace.yml` therefore sends the matching file here as the release
notes, followed by the body of the GitHub release under "Changes in this version". Write
only what changed in the GitHub release; the description is added automatically.

Images are untested. The publish API has no field for them, and whether the Marketplace
renders Markdown images in release notes has not been tried.
