#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <ff2_potry>

#define PLUGIN_NAME "simple abilities"
#define PLUGIN_VERSION "20200806"

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
		Format(name, sizeof(name), "slot %d ammo", loop);
		int ammo = FF2_GetAbilityArgument(boss, PLUGIN_NAME, CLIP_ADD_NAME, name, -1);

		Format(name, sizeof(name), "slot %d clip", loop);
		int clip = FF2_GetAbilityArgument(boss, PLUGIN_NAME, CLIP_ADD_NAME, name, -1);

		// TODO: Find safe way for setting ammo of the clipless weapons.
		// NOTE: Those statements are hard-coding.
		if(ammo >= 0 && clip <= -1)
			SetAmmo(client, loop, ammo);
		else
			FF2_SetAmmo(client, GetPlayerWeaponSlot(client, loop), ammo, clip);
	}
}


// Copied from ff2_otokiru
stock int SetAmmo(int client, int slot, int ammo)
{
	int weapon = GetPlayerWeaponSlot(client, slot);
	if(IsValidEntity(weapon))
	{
		int iOffset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1)*4;
		int iAmmoTable = FindSendPropInfo("CTFPlayer", "m_iAmmo");
		SetEntData(client, iAmmoTable+iOffset, ammo, 4, true);
	}
}
