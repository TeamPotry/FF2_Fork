#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <ff2_potry>

#define PLUGIN_NAME "gaben detail"
#define PLUGIN_VERSION "20190505"

public Plugin myinfo=
{
	name="Freak Fortress 2: Gaben Abilities",
	author="Nopied",
	description="FF2: Special abilities for Gaben",
	version=PLUGIN_VERSION,
};

#define DISCOUNT_NAME "discount"

public void OnPluginStart()
{
    FF2_RegisterSubplugin(PLUGIN_NAME);
}
