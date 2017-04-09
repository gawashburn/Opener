# OpenerPlugin 

A plugin for [Marta](https://marta.yanex.org) which allows for more 
configurable dispatching based upon the selected or current items.

This plugin was primarily motivated by the fact that generally the default
applications macOS chooses for opening files generally isn't to my liking. 
So using the "core.open" action doesn't offer the behavior I would like. 
However, just using "core.open.with" as my default isn't ideal either,
because I really don't want to bring up a menu just to traverse directories.

So this plugin lets you select a choice of action for directories,
actions based upon file extensions, and finally a default action to fallback 
upon.

A simple configuration for opener looks like
```json
    "behavior": {
        
        "actions": {
            "net.existentialtype.opener": {
                "directoryAction": "core.open",
                "extensionActions": {
                    "txt": "core.edit",
                    "sh": "core.get.info"
                },
                "defaultAction": "core.open.with"
            }
        }
    }
```
In the event that you do not supply a configuration, it defaults to 
"core.open" for directories and "core.open.with" for everything else.

Currently, if you have multiple items selected and your current item is
a directory, the directoryAction will be used.  This appears to match
the behavior I have seen for "core.open".  If the current item isn't a 
directory, and you have multiple files selected, the plugin will unfortunately 
resort to using the defaultAction.  This is because I haven't yet determined a 
way to rewrite the context appropriately so that each action only sees
the selected files for a given extension.

This is my first non-trivial Swift program, so it is probably suboptimal
in numerous ways.

Todo
  * Further code cleanup.
  * Figure out how to rewrite ActionContexts.
  * Cache action lookups.
  * Allow regular expression extension specifications.

## Building

Use XCode 8.3 or later to build the project.

Open the project and select *Product* → *Archive*.
