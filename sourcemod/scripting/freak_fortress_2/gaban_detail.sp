#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <ff2_potry>
#include <sprites>

#define PLUGIN_NAME "gaben detail"
#define PLUGIN_VERSION "20190505"

public Plugin myinfo=
{
	name="Freak Fortress 2: Gaben Abilities",
	author="Nopied",
	description="FF2: Special abilities for Gaben",
	version=PLUGIN_VERSION,
};

#define DISCOUNT_NAME		"discount"
#define DISCOUNTMARK_PATH	"materials/potry/steam_sale/"

int discountMarkIndex[11];
float discountValue[MAXPLAYERS+1];
Sprite discountSprite[MAXPLAYERS+1];

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
		discountMarkIndex[loop] = PrecacheModel(tempPath);
	}

	CreateTimer(0.05, DiscountTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	discountValue[client] = 0.0;
}

public Action DiscountTimer(Handle timer)
{
	for(int client = 1; client <= MaxClients; client++)
	{
		if(!IsClientInGame(client) || !IsPlayerAlive(client)) {
			discountSprite[client].Time = 0.0;
			continue;
		}

		if(GetRoundDiscount(discountSprite[client]) > 0)
		{
			SetClientDiscountMark(client, discountValue[client]);
			discountSprite[client].Time = 0.2;
			discountValue[client] -= discountValue[client] > 0.1 ? 0.1 : 0.0;
		}
	}

	return Plugin_Continue;
}

public void OnClientPostAdminCheck(int client)
{
	float pos[3];
	pos[2] += 15.0;

	discountSprite[client] = Sprite.Init("discount", 0);
	discountSprite[client].Parent = client;
	discountSprite[client].SetPos(pos);

	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int client, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	int boss = FF2_GetBossIndex(attacker);
	if(!FF2_IsFF2Enabled() || boss != -1 || !FF2_HasAbility(boss, PLUGIN_NAME, DISCOUNT_NAME))	return Plugin_Continue;

	float tempDamage = damage;
	damage *= (GetRoundDiscount(discountValue[client]) >= 10 && FF2_GetBossIndex(client) == -1) ? 999.0 : FloatDiv(discountValue[client], 10.0) + 1.0;
	discountValue[client] += tempDamage * FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, DISCOUNT_NAME, "multiplier", 1.0);

	if(discountValue[client] > 120.0)
		discountValue[client] = 120.0;

	return discountValue[client] >= 5.0 ? Plugin_Changed : Plugin_Continue;
}

public void OnClientDisconnect(int client)
{
	delete discountSprite[client];
}

void SetClientDiscountMark(int client, float value)
{
	int round = GetRoundDiscount(value);
	if(round > 0) {
		discountSprite[client].ModelIndex = discountMarkIndex[round];
	}
	else {
		discountSprite[client].Time = 0.0;
	}
}

int GetRoundDiscount(float value)
{
	int round = RoundFloat(FloatDiv(value, 10.0));
	return round > 10 ? round : 10;
}
