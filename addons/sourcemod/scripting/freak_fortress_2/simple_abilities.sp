#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <ff2_potry>

#define PLUGIN_NAME "simple abilities"
#define PLUGIN_VERSION "20200913"

public Plugin myinfo=
{
	name="Freak Fortress 2: Simple Abilities",
	author="Nopied",
	description="FF2?",
	version=PLUGIN_VERSION,
};

#define CLIP_ADD_NAME "set clip"
#define DELAY_ABILITY_NAME "delay"
#define REGENERATE_ABILITY_NAME "regenerate"

float g_flCurrentDelay[MAXPLAYERS+1];

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

	if(StrEqual(DELAY_ABILITY_NAME, abilityName))
	{
		DelayAbility(boss);
	}

	if(StrEqual(REGENERATE_ABILITY_NAME, abilityName))
	{
		FF2_EquipBoss(boss);
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

void DelayAbility(int boss)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));

	g_flCurrentDelay[client] = GetGameTime() + FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, DELAY_ABILITY_NAME, "time", 6.0);
	RequestFrame(Delay_Update, boss);
}

public void Delay_Update(int boss)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss)), loop = 0, slot, buttonMode;
	char abilityName[128], pluginName[128], temp[128];

	if(FF2_GetRoundState() != 1)
		return;

	if(GetGameTime() > g_flCurrentDelay[client])
	{
		while(client > 0) // YEAH IT IS JUST 'TRUE'
		{
			loop++;

			Format(abilityName, sizeof(abilityName), "delay %d ability name", loop);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, DELAY_ABILITY_NAME, abilityName, abilityName, 128, "");

			Format(pluginName, sizeof(pluginName), "delay %d plugin name", loop);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, DELAY_ABILITY_NAME, pluginName, pluginName, 128, "");

			if(!strlen(abilityName) || !strlen(pluginName)) break;

			Format(temp, sizeof(temp), "delay %d slot", loop);
			slot = FF2_GetAbilityArgument(boss, PLUGIN_NAME, DELAY_ABILITY_NAME, temp, 0);

			Format(temp, sizeof(temp), "delay %d button mode", loop);
			buttonMode = FF2_GetAbilityArgument(boss, PLUGIN_NAME, DELAY_ABILITY_NAME, temp, 0);

			FF2_UseAbility(boss, pluginName, abilityName, slot, buttonMode);
		}

		return;
	}

	RequestFrame(Delay_Update, boss);
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
