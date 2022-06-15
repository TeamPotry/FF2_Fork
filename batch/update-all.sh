#!/bin/bash
# a batch file, used for codespace.
# use this for compile at first.

cd /
sudo mkdir ./sourcemod_lib && cd ./sourcemod_lib
sudo wget --input-file=http://sourcemod.net/smdrop/1.10/sourcemod-latest-linux
sudo tar -xzf $(cat sourcemod-latest-linux)

sudo mv ./addons/sourcemod/scripting/* ./ 
sudo rm -rf ./addons ./cfg

# Setup Include (same as Github Action)
sudo wget "http://www.doctormckay.com/download/scripting/include/morecolors.inc" -P include
sudo wget "https://raw.githubusercontent.com/asherkin/TF2Items/master/pawn/tf2items.inc" -P include
sudo wget "https://raw.githubusercontent.com/nosoop/tf2attributes/master/scripting/include/tf2attributes.inc" -O include/tf2attributes.inc
sudo wget "https://raw.githubusercontent.com/TeamPotry/tutorial_text/master/addons/sourcemod/scripting/include/tutorial_text.inc" -P include
sudo wget "https://raw.githubusercontent.com/TeamPotry/SourceMod-DBSimple/master/include/db_simple.inc" -P include
sudo wget "https://raw.githubusercontent.com/TeamPotry/plugins_in_FF2/master/addons/sourcemod/scripting/include/unixtime_sourcemod.inc" -P include
sudo wget "https://raw.githubusercontent.com/nosoop/SM-TFUtils/master/scripting/include/tf2utils.inc" -P include
sudo wget "https://raw.githubusercontent.com/nosoop/sourcemod-tf2wearables/master/addons/sourcemod/scripting/include/tf2wearables.inc" -P include
sudo wget "https://raw.githubusercontent.com/peace-maker/DHooks2/dynhooks/sourcemod_files/scripting/include/dhooks.inc" -P include
sudo wget "https://raw.githubusercontent.com/Nopied/MannVsMann/master/addons/sourcemod/scripting/include/mannvsmann.inc" -P include
sudo wget "https://raw.githubusercontent.com/TeamPotry/FF2_boss_selection/master/addons/sourcemod/scripting/include/ff2_boss_selection.inc" -P include
sudo wget "https://raw.githubusercontent.com/TeamPotry/plugins_in_FF2/master/addons/sourcemod/scripting/include/medigun_patch.inc" -P include
sudo wget "https://forums.alliedmods.net/attachment.php?attachmentid=164494&d=1501170745" -O include/CBaseAnimatingOverlay.inc