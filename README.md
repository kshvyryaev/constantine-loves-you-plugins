# constantine-loves-you-plugins

## Plugins

| Plugin | Description |
|---|---|
| [open-montage](plugins/open-montage) | Guided macOS setup of OpenMontage: service keys, toolchain, dependencies, `.env` and verification |

## Installation

```shell
/plugin marketplace add https://github.com/kshvyryaev/constantine-loves-you-plugins
/plugin install <plugin-name>@constantine-loves-you-plugins
```

## Structure

```
.claude-plugin/marketplace.json   # marketplace registry
plugins/<plugin-name>/
├── .claude-plugin/plugin.json    # plugin manifest
├── skills/<skill-name>/SKILL.md  # skill entry point, with references/ and scripts/
├── CHANGELOG.md
└── README.md
```

Bump `plugin.json` `version` on every meaningful change, otherwise installed copies are not updated. Keep each skill's `metadata.version` in step and add a `CHANGELOG.md` entry.
