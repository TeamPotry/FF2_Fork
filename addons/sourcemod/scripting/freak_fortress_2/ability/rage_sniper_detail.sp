#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>

#include <freak_fortress_2>
#include <ff2_modules/general>
#include <ff2_modules/stocks>

#define PLUGININFO_NAME 	    "Freak Fortress 2: rage sniper details"
#define PLUGIN_AUTHOR       "Nopied◎"
#define PLUGIN_DESCRIPTION  ""
#define PLUGIN_VERSION 	    ""

public Plugin myinfo=
{
	name=PLUGININFO_NAME,
	author=PLUGIN_AUTHOR,
	description=PLUGIN_DESCRIPTION,
	version=PLUGIN_VERSION,
};

#define FOREACH_PLAYER(%1) for(int %1 = 1; %1 <= MaxClients; %1++)

#define PLUGIN_NAME 	    "rage sniper detail"

#define DISABLE_CHARGE_DAMAGE_NAME                 "disable charge damage"
#define FORCE_HEADSHOT_NAME                 "force headshot"
#define FORCE_HEADSHOT_EFFECT_NAME          "dxhr_sniper_rail_blue"


float g_flForceHeadshotDuration[MAXPLAYERS+1];

public void OnPluginStart()
{
    // LoadTranslations("ff2_extra_abilities.phrases");

    HookEvent("arena_round_start", OnRoundStartOrEnd);
    HookEvent("teamplay_round_active", OnRoundStartOrEnd); // for non-arena maps

    HookEvent("teamplay_round_win", OnRoundStartOrEnd);

    // HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);

    FF2_RegisterSubplugin(PLUGIN_NAME);
}

public void OnMapStart()
{
	FF2_PrecacheEffect();
	FF2_PrecacheParticleEffect(FORCE_HEADSHOT_EFFECT_NAME);
}

public void FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status)
{
    if(!StrEqual(PLUGIN_NAME, pluginName))
        return;

    int client = GetClientOfUserId(FF2_GetBossUserId(boss));

    if(StrEqual(FORCE_HEADSHOT_NAME, abilityName))
    {
        float duration = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, FORCE_HEADSHOT_NAME, "duration", 10.0, slot);

        g_flForceHeadshotDuration[client] = GetGameTime() + duration;
    }

	// TODO: laser effect
/*
	if(g_flForceHeadshotDuration[client] > GetGameTime())
	{
		float clientPos[3], targetPos[3];
		int team = GetClientTeam(client);

		FOREACH_PLAYER(target)
		{
			if(!IsClientInGame(target) || !IsPlayerAlive(target)
				|| team == GetClientTeam(target))
				continue;

			GetClientEyePosition(client, clientPos);
			GetClientEyePosition(target, targetPos);

			TR_TraceRayFilter(effectPos, targetPos, ( MASK_SOLID | CONTENTS_HITBOX ), RayType_EndPoint, AimTargetFilter, iAttacker);
			if (TR_GetFraction() < 1.0
				&& (ent = TR_GetEntityIndex()) != -1)
			{

			}
		}
	}
*/
}

public Action OnTakeDamageAlive(int client, int& iAttacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(!(damagetype & (DMG_BULLET | DMG_BUCKSHOT))
	|| (damagetype & DMG_CRIT) > 0
	|| !IsValidClient(iAttacker))
		return Plugin_Continue;

	int boss = FF2_GetBossIndex(iAttacker);
	if(!FF2_HasAbility(boss, PLUGIN_NAME, FORCE_HEADSHOT_NAME))
		return Plugin_Continue;

	float effectPos[3], targetPos[3];
	int effectEnt = /* IsValidEntity(weapon) ? weapon : */ iAttacker;

	GetClientEyePosition(effectEnt, effectPos);
	GetClientEyePosition(client, targetPos);

	TR_TraceRayFilter(effectPos, targetPos, ( MASK_SOLID | CONTENTS_HITBOX ), RayType_EndPoint, AimTargetFilter, iAttacker);
	if (TR_GetFraction() < 1.0)
	{
		int ent = TR_GetEntityIndex();
		if(ent == -1)
			return Plugin_Handled;

		TE_DispatchEffect(FORCE_HEADSHOT_EFFECT_NAME, targetPos, effectPos);
		TE_SendToAll();

		damagecustom = TF_CUSTOM_HEADSHOT;
		damagetype |= DMG_CRIT;

		damage *= 3.0;
		if(TF2_IsPlayerInCondition(iAttacker, TFCond_Buffed))
			damage *= 0.74074; // /= 1.35;

		return Plugin_Changed;
	}
	
	return Plugin_Handled;
}

public void OnRoundStartOrEnd(Event event, const char[] name, bool dontBroadcast)
{
    FOREACH_PLAYER(client)
    {
        g_flForceHeadshotDuration[client] = 0.0;
    }
}

public void OnClientPostAdminCheck(int client)
{
    SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
}

public bool AimTargetFilter(int entity, int contentsMask, any iExclude)
{
	char class[64];
	GetEntityClassname(entity, class, sizeof(class));

	if(StrEqual(class, "monster_generic"))
	{
		return false;
	}
	if(!(entity == iExclude))
	{
		if(HasEntProp(iExclude, Prop_Send, "m_iTeamNum"))
		{
			int team = GetEntProp(entity, Prop_Send, "m_iTeamNum");
			return team != GetEntProp(iExclude, Prop_Send, "m_iTeamNum");
		}

		return true;
	}

	return false;
}

stock bool TF2_IsPlayerCritBuffed(int client)
{
	return (TF2_IsPlayerInCondition(client, TFCond_Kritzkrieged) || TF2_IsPlayerInCondition(client, TFCond_HalloweenCritCandy) || TF2_IsPlayerInCondition(client, view_as<TFCond>(34)) || TF2_IsPlayerInCondition(client, view_as<TFCond>(35)) || TF2_IsPlayerInCondition(client, TFCond_CritOnFirstBlood) || TF2_IsPlayerInCondition(client, TFCond_CritOnWin) || TF2_IsPlayerInCondition(client, TFCond_CritOnFlagCapture) || TF2_IsPlayerInCondition(client, TFCond_CritOnKill) || TF2_IsPlayerInCondition(client, TFCond_CritMmmph));
}

stock bool IsValidClient(int client)
{
	return (0 < client && client <= MaxClients && IsClientInGame(client));
}
