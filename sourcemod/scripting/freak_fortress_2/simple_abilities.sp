#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <ff2_potry>

#define PLUGIN_NAME "simple abilities"
#define PLUGIN_VERSION "20190501"

public Plugin myinfo=
{
	name="Freak Fortress 2: Simple Abilities",
	author="Nopied",
	description="FF2?",
	version=PLUGIN_VERSION,
};

#define CLIP_ADD_NAME "set clip"

public void OnPluginStart()
{
    FF2_RegisterSubplugin(PLUGIN_NAME);
}

public void FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status)
{
    if(StrEqual(CLIP_ADD_NAME, abilityName))
    {
        SetWeaponClip(boss);
    }
}

void SetWeaponClip(int boss)
{
    int client = GetClientOfUserId(FF2_GetBossUserId(boss));
    char name[16];

    for(int loop = TFWeaponSlot_Primary; loop <= TFWeaponSlot_PDA; loop++)
    {
        Format(name, sizeof(name), "slot %d clip", loop);
        int clip = FF2_GetAbilityArgument(boss, PLUGIN_NAME, CLIP_ADD_NAME, name, 0);

        Format(name, sizeof(name), "slot %d ammo", loop);
        int ammo = FF2_GetAbilityArgument(boss, PLUGIN_NAME, CLIP_ADD_NAME, name, 0);

        FF2_SetAmmo(client, GetPlayerWeaponSlot(client, loop), ammo, clip);
    }
}
