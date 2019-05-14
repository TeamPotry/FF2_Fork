#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <ff2_potry>

#define PLUGIN_NAME "gaben detail"
#define PLUGIN_VERSION "20190515"

float discountValue[MAXPLAYERS+1];

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
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Pre);

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

public Action OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	discountValue[client] = 0.0;
}

public void OnClientPostAdminCheck(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void FF2_OnCalledQueue(FF2HudQueue hudQueue)
{
	int client = hudQueue.ClientIndex;
	FF2HudDisplay hudDisplay = null;
	SetGlobalTransTarget(client);

	char text[64];

 	if(discountValue[client] > 5.0)	{
		Format(text, sizeof(text), "STEAM SALE: %.1f%%", discountValue[client]);

		hudDisplay = FF2HudDisplay.CreateDisplay("steam sale notice", text);
		hudQueue.AddHud(hudDisplay);
	}
}

public Action OnTakeDamage(int client, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	int boss = FF2_GetBossIndex(attacker);
	if(!FF2_IsFF2Enabled() || boss == -1 || !FF2_HasAbility(boss, PLUGIN_NAME, DISCOUNT_NAME))	return Plugin_Continue;

	float tempDamage = damage;
	damage *= (GetRoundDiscount(discountValue[client]) >= 10 && FF2_GetBossIndex(client) == -1) ? 999.0 : FloatDiv(discountValue[client], 10.0) + 1.0;
	discountValue[client] += tempDamage * FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, DISCOUNT_NAME, "multiplier", 1.0);

	if(discountValue[client] > 120.0)
		discountValue[client] = 120.0;

	return discountValue[client] >= 5.0 ? Plugin_Changed : Plugin_Continue;
}

int GetRoundDiscount(float value)
{
	int round = RoundFloat(FloatDiv(value, 10.0));
	return round > 10 ? round : 10;
}
