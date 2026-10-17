{
  lib,
  tagged ? false,
}:
let
  /**
    Serialize a supported Nix value as a compact XML plist fragment

    Support booleans, integers, floats, strings, lists, and dictionaries. Escape
    XML text and emit dictionaries in attribute-name order. Serialize floats
    through JSON to retain precision. Nulls and paths are unsupported, and
    `_module` is treated as an ordinary dictionary key

    When imported with `tagged = true`, recognize `{ _data = base64; }` and
    `{ _real = number; }` as plist data and real values before dictionary
    serialization. This module is shared by defaults and settings renderers and
    is not exported directly under `lib.darwin`

    # Inputs

    `value`
    : Supported plist value

    # Type

    ```
    xml :: Any -> String
    ```

    # Examples
    :::{.example}
    ## `plist.xml` usage example

    ```nix
    let
      plist = import ./plist.nix { inherit lib; };
    in
    plist.xml { enabled = true; }
    => "<dict><key>enabled</key><true/></dict>"
    ```

    :::
  */
  xml =
    value:
    if lib.isBool value then
      (if value then "<true/>" else "<false/>")
    else if lib.isInt value then
      "<integer>${toString value}</integer>"
    # JSON retains float precision that toString would round to six decimals
    else if lib.isFloat value then
      "<real>${builtins.toJSON value}</real>"
    else if lib.isString value then
      "<string>${lib.escapeXML value}</string>"
    else if lib.isList value then
      "<array>${lib.concatMapStrings xml value}</array>"
    # Wallpaper configurations distinguish binary data and real-valued numbers
    else if tagged && value ? _data then
      "<data>${lib.escapeXML value._data}</data>"
    else if tagged && value ? _real then
      "<real>${builtins.toJSON value._real}</real>"
    else
      "<dict>${
        lib.concatMapAttrsStringSep "" (k: v: "<key>${lib.escapeXML k}</key>${xml v}") value
      }</dict>";
in
{
  inherit xml;
  /**
    Wrap a serialized value in an XML declaration and plist root element

    Accept the same values and tagged forms as `xml`. This serializer does not
    omit nulls or module metadata. The defaults command generator performs its
    own normalization before calling it

    # Inputs

    `value`
    : Supported plist value

    # Type

    ```
    document :: Any -> String
    ```

    # Examples
    :::{.example}
    ## `plist.document` usage example

    ```nix
    let
      plist = import ./plist.nix { inherit lib; };
    in
    plist.document true
    => ''<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><true/></plist>''
    ```

    :::
  */
  document =
    value: ''<?xml version="1.0" encoding="UTF-8"?><plist version="1.0">${xml value}</plist>'';
}
