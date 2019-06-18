#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <ff2_potry>
#include <medigun_patch>

#define PLUGIN_NAME "medigun patch"
#define PLUGIN_VERSION "20190616"

#define GHOSTHEAL_NAME 	"ghost heal"
#define NOUBER_NAME 	"no uber"
#define STUN_NAME		"stun"

public Plugin myinfo=
{
	name="Freak Fortress 2: Medigun Abilities",
	author="Nopied",
	description="FF2: Special abilities for Medigun, GhostBuster",
	version=PLUGIN_VERSION,
};

int g_bGhost[MAXPLAYERS+1];
float g_flHealCooldown[MAXPLAYERS+1];

float g_flHealStun[MAXPLAYERS+1];

public void OnPluginStart()
{
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
	HookEvent("teamplay_round_start", OnRoundStart);

	FF2_RegisterSubplugin(PLUGIN_NAME);
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for(int client = 1; client < MaxClients; client++) {
		g_flHealCooldown[client] = 0.0;
		g_flHealStun[client] = 0.0;
	}
}

public Action OnPlayerDeath(Event event, const char[] eventName, bool dontBroadcast)
{
    int client=GetClientOfUserId(event.GetInt("userid"));
    g_bGhost[client] = false;
}

public void OnClientDisconnect(int client)
{
    g_bGhost[client] = false;
}

public Action FF2_OnMinionSpawn(int client, int &ownerBossIndex)
{
    if(FF2_HasAbility(ownerBossIndex, PLUGIN_NAME, GHOSTHEAL_NAME)) {
        g_bGhost = true;
    }

    return Plugin_Continue;
}

public Action TF2_OnHealTarget(int healer, int target, bool &result)
{
	int boss = FF2_GetBossIndex(healer), medigun = GetPlayerWeaponSlot(healer, TFWeaponSlot_Secondary);
	bool change = false;
	if(boss == -1 && !IsValidClient(target) && g_flHealCooldown[healer] <= GetGameTime()) return Plugin_Continue;

	g_flHealCooldown[healer] = GetGameTime() + 2.0;

	if(FF2_HasAbility(boss, PLUGIN_NAME, GHOSTHEAL_NAME))   {
		float damage = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, GHOSTHEAL_NAME, "amount", 10.0);

		if(g_bGhost[target])
			damage *= 2.0;

		SDKHooks_TakeDamage(target, healer, healer, damage, DMG_SHOCK|DMG_PREVENT_PHYSICS_FORCE);
		FF2_SetBossHealth(boss, AddToMax(RoundFloat(damage), FF2_GetBossHealth(boss), FF2_GetBossMaxHealth(boss)));

		result = true;
		change = true;
	}
	if(FF2_HasAbility(boss, PLUGIN_NAME, NOUBER_NAME))	{
		SetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel", 0.0);
	}
	if(FF2_HasAbility(boss, PLUGIN_NAME, STUN_NAME)) 	{
		float slowdown, multiplier = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, GHOSTHEAL_NAME, "multiplier", 5.0);

		g_flHealStun[target] += multiplier;
		slowdown = FloatDiv(g_flHealStun[target], 100.0);

		if(g_flHealStun[target] >= 100.0 && FF2_GetBossIndex(target) == -1) {
			g_flHealStun[target] = 0.0;
			TF2_StunPlayer(target, 8.0, 0.0, TF_STUNFLAGS_SMALLBONK|TF_STUNFLAG_NOSOUNDOREFFECT, healer);
		}
		else if(!TF2_IsPlayerInCondition(target, TFCond_Dazed)){
			TF2_StunPlayer(target, 0.1, slowdown > 1.0 ? 1.0 : slowdown, TF_STUNFLAG_SLOWDOWN|TF_STUNFLAG_NOSOUNDOREFFECT, healer);
		}

		result = true;
		change = true;
	}

	return change ? Plugin_Changed : Plugin_Continue;
}

stock int AddToMax(int amount, int health, int max)
{
    int result = health + amount;
    if(result > max)
        result = max;

    return max;
}

stock bool IsValidClient(int client)
{
	return (0 < client && client <= MaxClients && IsClientInGame(client));
}
