#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <ff2_potry>

#define PLUGIN_NAME "gaben detail"
#define PLUGIN_VERSION "20190515"

float discountValue;

public Plugin myinfo=
{
	name="Freak Fortress 2: Gaben Abilities",
	author="Nopied",
	description="FF2: Special abilities for Gaben",
	version=PLUGIN_VERSION,
};

#define DISCOUNT_NAME		"discount"
#define DISCOUNTMARK_PATH	"materials/potry/steam_sale/"

public void OnPluginStart()
{
	HookEvent("teamplay_round_start", OnRoundStart, EventHookMode_Pre);

	FF2_RegisterSubplugin(PLUGIN_NAME);
}

public void OnMapStart()
{
	char path[PLATFORM_MAX_PATH], tempPath[PLATFORM_MAX_PATH];

	for(int loop = 1; loop <= 10; loop++)
	{
		Format(path, PLATFORM_MAX_PATH, "%s%i", DISCOUNTMARK_PATH, loop * 10);

		Format(tempPath, PLATFORM_MAX_PATH, "%s.vmt", path);
	}
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	discountValue = 0.0;
}

public void OnClientPostAdminCheck(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void FF2_OnCalledQueue(FF2HudQueue hudQueue, int client)
{
	int boss = FF2_GetBossIndex(0);
	FF2HudDisplay hudDisplay = null;
	SetGlobalTransTarget(client);

	char text[64], discountText[8];
	hudQueue.GetName(text, sizeof(text));

 	if((FF2_HasAbility(boss, PLUGIN_NAME, DISCOUNT_NAME) || discountValue > 0.0) && StrEqual(text, "Timer")) {
		if(discountValue >= 100.0)
			Format(discountText, sizeof(discountText), "%.0f%%", discountValue);
		else
			Format(discountText, sizeof(discountText), "FREE!");
		Format(text, sizeof(text), "STEAM SALE: %s", discountText);

		hudDisplay = FF2HudDisplay.CreateDisplay("steam sale notice", text);
		hudQueue.AddHud(hudDisplay, client);
	}
}

public Action OnTakeDamage(int client, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	int boss = FF2_GetBossIndex(attacker);
	if(!FF2_IsFF2Enabled() || boss == -1 || !FF2_HasAbility(boss, PLUGIN_NAME, DISCOUNT_NAME))	return Plugin_Continue;

	bool insertKill = false;
	if(discountValue >= 100.0 && FF2_GetBossIndex(client) == -1) {
		insertKill = true;
		damage = 20000.0; // YEs
		discountValue = 0.0;
	}
	else
		discountValue += damage * FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, DISCOUNT_NAME, "multiplier", 1.00);

	return insertKill ? Plugin_Changed : Plugin_Continue;
}
