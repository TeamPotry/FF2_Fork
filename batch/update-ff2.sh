#!/bin/bash
# a batch file, used for codespace. copy all of ff2's stuff to out of workspace.
# use this for compile after editing ff2's stuff.

cd /workspaces/FF2_Fork
sudo cp -R ./addons/sourcemod/scripting/* /sourcemod_lib