#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <ff2_potry>
#include <stocksoup/sdkports/util>

#define PLUGIN_NAME "simple abilities"
#define PLUGIN_VERSION 	"20210723"

public Plugin myinfo=
{
	name="Freak Fortress 2: Simple Abilities",
	author="Nopied",
	description="FF2?",
	version=PLUGIN_VERSION,
};

#define CLIP_ADD_NAME 				"set clip"
#define DELAY_ABILITY_NAME 			"delay"
#define REGENERATE_ABILITY_NAME 	"regenerate"
#define SCREENFADE_ABILITY_NAME		"screen fade"
#define HIDEHUD_ABILITY_NAME		"hide hud"
#define PLAYERFADE_ABILITY_NAME		"player fade"

#define HIDEHUD_FLAGS			0b101101001010
/*
https://github.com/TheAlePower/TeamFortress2/blob/1b81dded673d49adebf4d0958e52236ecc28a956/tf2_src/game/shared/shareddefs.h

#define	HIDEHUD_WEAPONSELECTION		( 1<<0 )	// Hide ammo count & weapon selection
#define	HIDEHUD_FLASHLIGHT			( 1<<1 )
#define	HIDEHUD_ALL					( 1<<2 )
#define HIDEHUD_HEALTH				( 1<<3 )	// Hide health & armor / suit battery
#define HIDEHUD_PLAYERDEAD			( 1<<4 )	// Hide when local player's dead
#define HIDEHUD_NEEDSUIT			( 1<<5 )	// Hide when the local player doesn't have the HEV suit
#define HIDEHUD_MISCSTATUS			( 1<<6 )	// Hide miscellaneous status elements (trains, pickup history, death notices, etc)
#define HIDEHUD_CHAT				( 1<<7 )	// Hide all communication elements (saytext, voice icon, etc)
#define	HIDEHUD_CROSSHAIR			( 1<<8 )	// Hide crosshairs
#define	HIDEHUD_VEHICLE_CROSSHAIR	( 1<<9 )	// Hide vehicle crosshair
#define HIDEHUD_INVEHICLE			( 1<<10 )
#define HIDEHUD_BONUS_PROGRESS		( 1<<11 )	// Hide bonus progress display (for bonus map challenges)
*/

float g_flCurrentDelay[MAXPLAYERS+1];
float g_flHideHudTime[MAXPLAYERS+1];
float g_flPlayerFadeTime[MAXPLAYERS+1];

enum
{
	Effect_OtherTeam = 0,
	Effect_Everyone,
	Effect_OnlyInvoker,
	Effect_OnlyHuman
};

public void OnPluginStart()
{
	HookEvent("arena_round_start", Event_RoundStart);
	HookEvent("teamplay_round_active", Event_RoundStart); // for non-arena maps

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

	if(StrEqual(SCREENFADE_ABILITY_NAME, abilityName))
	{
		InvokeScreenFade(boss);
	}

	if(StrEqual(HIDEHUD_ABILITY_NAME, abilityName))
	{
		InvokeHideHUD(boss);
	}

	if(StrEqual(PLAYERFADE_ABILITY_NAME, abilityName))
	{
		InvokePlayerFade(boss);
	}
}

void InvokeScreenFade(int boss)
{
	bool able = false;

	int client = GetClientOfUserId(FF2_GetBossUserId(boss)),
		effectTo = FF2_GetAbilityArgument(boss, PLUGIN_NAME, SCREENFADE_ABILITY_NAME, "effect to", Effect_OtherTeam),
		color[4];

	color[0] = FF2_GetAbilityArgument(boss, PLUGIN_NAME, SCREENFADE_ABILITY_NAME, "red", 255);
	color[1] = FF2_GetAbilityArgument(boss, PLUGIN_NAME, SCREENFADE_ABILITY_NAME, "blue", 255);
	color[2] = FF2_GetAbilityArgument(boss, PLUGIN_NAME, SCREENFADE_ABILITY_NAME, "green", 255);
	color[3] = FF2_GetAbilityArgument(boss, PLUGIN_NAME, SCREENFADE_ABILITY_NAME, "alpha", 255);

	float duration = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, SCREENFADE_ABILITY_NAME, "duration", 6.0),
		holdTime = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, SCREENFADE_ABILITY_NAME, "hold time", 6.0);

	int team = GetClientTeam(client);
	for(int target = 1; target <= MaxClients; target++)
	{
		if(!IsClientInGame(target) || !IsPlayerAlive(target))
			continue;

		able = false;

		switch(effectTo)
		{
			case Effect_OtherTeam:
			{
				able = GetClientTeam(target) != team;
			}
			case Effect_Everyone:
			{
				able = true;
			}
			case Effect_OnlyInvoker:
			{
				able = target == client;
			}
			case Effect_OnlyHuman:
			{
				able = FF2_GetBossIndex(target) == -1;
			}
		}

		if(able)
			UTIL_ScreenFade(target, color, duration, holdTime);
	}
}

void InvokeHideHUD(int boss)
{
	bool able = false;

	int client = GetClientOfUserId(FF2_GetBossUserId(boss)),
		effectTo =  FF2_GetAbilityArgument(boss, PLUGIN_NAME, HIDEHUD_ABILITY_NAME, "effect to", Effect_OtherTeam);

	float duration = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, HIDEHUD_ABILITY_NAME, "duration", 6.0),
		presetTime = GetGameTime() + duration;

	int team = GetClientTeam(client);
	for(int target = 1; target <= MaxClients; target++)
	{
		if(!IsClientInGame(target) || !IsPlayerAlive(target))
			continue;

		able = false;

		switch(effectTo)
		{
			case Effect_OtherTeam:
			{
				able = GetClientTeam(target) != team;
			}
			case Effect_Everyone:
			{
				able = true;
			}
			case Effect_OnlyInvoker:
			{
				able = target == client;
			}
			case Effect_OnlyHuman:
			{
				able = FF2_GetBossIndex(target) == -1;
			}
		}

		if(able)
		{
			if(g_flHideHudTime[target] < GetGameTime())
			{
				SDKHook(target, SDKHook_PostThink, OnHideHUDThink);
			}

			g_flHideHudTime[target] = presetTime;
			SetEntProp(target, Prop_Data, "m_iHideHUD", HIDEHUD_FLAGS);
		}
	}
}

public void OnHideHUDThink(int client)
{
	if(FF2_GetRoundState() != 1 || !IsClientInGame(client) || !IsPlayerAlive(client)
	|| g_flHideHudTime[client] < GetGameTime())
	{
		g_flHideHudTime[client] = 0.0;

		SetEntProp(client, Prop_Data, "m_iHideHUD", 0);
		SDKUnhook(client, SDKHook_PostThink, OnHideHUDThink);
	}
}

void InvokePlayerFade(int boss)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));

	float duration = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, PLAYERFADE_ABILITY_NAME, "duration", 6.0),
		startFade = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, PLAYERFADE_ABILITY_NAME, "start fade", 600.0),
		endFade = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, PLAYERFADE_ABILITY_NAME, "end fade", 900.0);

	SetEntPropFloat(client, Prop_Send, "m_fadeMinDist", startFade);
	SetEntPropFloat(client, Prop_Send, "m_fadeMaxDist", endFade);

	if(g_flPlayerFadeTime[client] < GetGameTime())
		SDKHook(client, SDKHook_PostThink, OnPlayerFadeThink);

	g_flPlayerFadeTime[client] = GetGameTime() + duration;
}

public void OnPlayerFadeThink(int client)
{
	if(FF2_GetRoundState() != 1 || !IsClientInGame(client) || !IsPlayerAlive(client)
	|| g_flPlayerFadeTime[client] < GetGameTime())
	{
		g_flPlayerFadeTime[client] = 0.0;

		SetEntPropFloat(client, Prop_Send, "m_fadeMinDist", 0.0);
		SetEntPropFloat(client, Prop_Send, "m_fadeMaxDist", 0.0);
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

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for(int client = 1; client <= MaxClients; client++)
	{
		g_flHideHudTime[client] = 0.0;
		g_flPlayerFadeTime[client] = 0.0;
	}
}
