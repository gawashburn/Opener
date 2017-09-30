# OpenerPlugin 

A plugin for [Marta](https://marta.yanex.org) which allows for more 
configurable dispatching based upon the selected or current items.

This plugin was primarily motivated by the fact that generally the default
applications macOS chooses for opening files generally isn't to my liking. 
So using the "core.open" action doesn't offer the behavior I would like. 
However, just using "core.open.with" as my default isn't ideal either,
because I really don't want to bring up a menu just to traverse directories.

So this plugin lets you select a choice of action for directories, 
applications, packages, and files based upon their extensions.  Finally a 
default action can be chosen to fallback upon.

A simple configuration for opener looks like
```json
    "behavior": {
        "actions": {
            "net.existentialtype.opener": {
                "errorAlerts": true,
                "directoryAction": "core.open",
                "applicationAction": "core.open",
                "packageAction": "core.open.with",
                "extensionActions": {
                    "txt": "core.edit",
                    "sh": "core.get.info"
                },
                "defaultAction": "core.open.with"
            }
        }
    }
```
In the event that you do not supply a configuration, it defaults to using
`core.open` for directories and applications and `core.open.with` for 
everything else.

If you wish to specify an action for a file with no extension, you can
use the empty string "".

It is not possible to recursively proxy through the Opener plugin action, 
`net.existentialtype.opener"`.

Currently, the semantics of Opener is the that given a some set of
selected files and a current file (the one currently under the cursor),
if 
  * the current file is an application, the `applicationAction` is used.
  * the current file is a package, the `packageAction` is used.
  * the current file is a directory, the `directoryAction` is used.  
  * there are selected files, they will be divvied up into buckets by
    their file extension if they are found in `extensionActions`.
    Otherwise, they are placed into a catchall bucket.  Then all the
    buckets with a corresponding `extensionAction` definition will be
    applied to their respective action.  Finally, the catchall bucket
    will be applied to the `defaultAction`.  Note, that when passing the
    files to an action they will be treated as selected files, with
    there being no current file.  
  * there are no selected files, the current file will be applied using
    an action in `extensionActions` or the `defaultAction` otherwise.

The semantics of selected files is currently less than ideal.  It
attempts to roughly match the behavior of `core.open`.  However, it
seems that many actions ignore the selected files and act only on the
current file.  One option would be to instead apply each selected file
individually.  That is less than ideal in some cases, as for some
actions it might make sense to operate on multiple files simultaneously.

It may also make more sense to consolidate selected files and apply them by
action, rather than by extension.  For example if more than one
extension is assigned to `core.edit`, we should probably apply all of
them together rather than separately.  

Finally, one problem I am not sure how to resolve is that trying to
apply multiple actions that rely on user feedback (such as
`core.open.with`) in sequence will probably work, but yield a less than
pleasant user experience.
  
This is my first non-trivial Swift program, so it is probably suboptimal
in numerous ways.  If you have suggestions to improve the quality of the
code, let me know or just create a pull request. 

Todo
  * Further code cleanup.
  * Improve the semantics of action dispatch.
  * Allow regular expression extension specifications.

## Building

Use XCode 8.3 or later to build the project.

Open the project and select *Product* → *Archive*.
