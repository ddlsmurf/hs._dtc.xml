# hs._dtc.xml - Very simplistic XML support for Hammerspoon

A very simple and incomplete XML support extension for [Hammerspoon](https://www.hammerspoon.org/)


## Installation

0. Download [the latest release here](https://github.com/ddlsmurf/hs._dtc.xml/releases/latest).
1. Extract the downloaded archive
2. Copy the `hs/_dtc/xml` directory to `~/.hammerspoon/hs/_dtc/xml` (create folders as required)
3. Reload your Hammerspoon configuration or restart Hammerspoon

## Uninstallation

Just delete `~/.hammerspoon/hs/_dtc/xml`.

## Quick Start

```lua
local xml = require("hs._dtc.xml")

local xmlString = [[
  <root a="v">
    <item>
      <name>item 1</name>
      <other>other 1</other>
    </item>
    <item>
      <name>item 2</name>
    </item>
    <item>
      ...some text before...
      <name>item 3</name>
      ...some text after...
    </item>
  </root>
]]

local xmlAsTable = xml.xmlToTable(xmlString)
print(hs.inspect(xmlAsTable))
```

Would result in the following structure:

```lua
{
  root = {
    _attr = {
      a = "v"
    },
    item = { {
        name = "item 1",
        other = "other 1"
      }, {
        name = "item 2"
      }, {
        [""] = { "...some text before... ", "...some text after..." },
        name = "item 3"
      } }
  }
}
```

Modify in lua, then generate XML string:

```lua
xmlAsTable.root.item[2].added_simple = "I was added to the table after parsing"
xmlAsTable.root.item[2].added_with_attr = { _attr = { from = "lua code" }, [""] = "element with attributes" }

print(xml.tableToXML(xmlAsTable)) -- Without indent: xml.tableToXML(xmlAsTable, xml.constants.NSXMLNodeOptionsNone)
```

Generates the following XML:

```xml
<root a="v">
    <item>
        <name>item 1</name>
        <other>other 1</other>
    </item>
    <item>
        <name>item 2</name>
        <added_simple>I was added to the table after parsing</added_simple>
        <added_with_attr from="lua code">element with attributes</added_with_attr>
    </item>
    <item>...some text before... ...some text after...<name>item 3</name>
    </item>
</root>
```

## API Reference

Up to date reference in the console: `help.hs._dtc.xml`

## Notes

### Basic structure

- Elements without attributes nor child elements are represented as string values
- Attributes are in the `_attr` key, and any text is in the `""` key
- If the key would be duplicated, the value is a table with the multiple values

### Warning

This is of course a very incomplete representation of XML. It is lossy. Do not expect
generated XML to be the same nor even contain everything or respect the schema after
passing through `xmlToTable` and `tableToXML`.

## Building from Source

### Requirements

- Hammerspoon installed in `/Applications` (or set `HS_APPLICATION` environment
  variable - spaces in the path are not supported)
- macOS 10.13 or later
- Xcode Command Line Tools

### Compilation

```bash
make clean
make docs # Optional. Requires the `hs` cli, and Hammerspoon to be running with ipc
make all

# Install to ~/.hammerspoon
make install

# Or install to custom location
PREFIX=/custom/path make install

# Remove:
#[PREFIX=/custom/path] make uninstall
```

## License

MIT license.

## Credits

- [Hammerspoon](https://www.hammerspoon.org/) - macOS automation framework
