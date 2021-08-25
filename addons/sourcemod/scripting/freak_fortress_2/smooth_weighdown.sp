#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#define PLUGIN_VERSION "20210822"

public Plugin myinfo=
{
	name="Freak Fortress 2: Smooth Weighdown",
	author="Nopied◎",
	description="FF2: Replacement for weighdown (It doesn't work at v2.0)",
	version=PLUGIN_VERSION,
};

#define WEIGHDOWN_NAME      "weighdown"

bool g_bWeighdownEnable[MAXPLAYERS+1];
float g_flNextTick[MAXPLAYERS+1];
float g_flSpeed[MAXPLAYERS+1];
float g_flAngle[MAXPLAYERS+1];

public void OnPluginStart2()
{
	HookEvent("arena_round_start", Event_RoundStart);
	HookEvent("teamplay_round_active", Event_RoundStart); // for non-arena maps

	// HookEvent("arena_win_panel", Event_RoundEnd);
	// HookEvent("teamplay_round_win", Event_RoundEnd); // for non-arena maps
}

public void OnMapStart()
{
	CreateTimer(0.05, OnTick, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action FF2_OnAbility2(int boss, const char[] pluginName, const char[] abilityName, int status)
{
	// Do nothing.
	return Plugin_Continue;
}

public Action OnTick(Handle timer)
{
    float currentTime = GetGameTime();
    for(int client = 1; client <= MaxClients; client++)
    {
		if(!IsClientInGame(client) || !IsPlayerAlive(client)
		    || !g_bWeighdownEnable[client] || g_flNextTick[client] > currentTime)
		    continue;

		float angles[3];
		GetClientEyeAngles(client, angles);

		if(angles[0] < g_flAngle[client]
		|| !(GetClientButtons(client) & IN_DUCK) || (GetEntityFlags(client) & FL_ONGROUND) > 0)
		    continue;

		float currentVelocity[3], velocity[3], cul = DegToRad(90.0 - angles[0]), currentSpeed, angleDiff;
		float multiplier = g_flSpeed[client], speed = multiplier * (Cosine(cul * 2.0)) + Cosine(cul), ratio, actualRatio;

		GetEntPropVector(client, Prop_Data, "m_vecVelocity", currentVelocity);
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);
		GetAngleVectors(angles, angles, NULL_VECTOR, NULL_VECTOR);

		currentSpeed = GetVectorLength(velocity);
		GetVectorAngles(velocity, velocity);
		GetAngleVectors(velocity, velocity, NULL_VECTOR, NULL_VECTOR);
		angleDiff = GetVectorDotProduct(velocity, angles);

		// NOTE: 속력을 받을 때를 늦춰야 한다면 GetVectorDotProduct가 점진적으로 값이 상승되도록 조정할 것
		ratio = (((currentSpeed / speed) * (1.5 * (currentSpeed / speed))) + 0.3) * (angleDiff + 0.1);
		actualRatio = (fmin(1.0, ratio) == 1.0) ? 1.0 : fmax(0.1, ratio);
		ScaleVector(angles, (speed * actualRatio));

		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, angles);
		g_flNextTick[client] = currentTime + 0.05;
    }

	return Plugin_Continue;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	int boss;
	for(int client = 1; client <= MaxClients; client++)
	{
		g_bWeighdownEnable[client] = false;
		g_flNextTick[client] = 0.0;
		g_flSpeed[client] = 0.0;
		g_flAngle[client] = 0.0;

		boss = FF2_GetBossIndex(client);
		if(boss == -1)	continue;

		if(FF2_HasAbility(boss, this_plugin_name, WEIGHDOWN_NAME))
		{
			g_bWeighdownEnable[client] = true;
			g_flSpeed[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, WEIGHDOWN_NAME, 1, 4000.0);
			g_flAngle[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, WEIGHDOWN_NAME, 2, 50.0);
		}
	}
}

/*
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    for(int client = 1; client <= MaxClients; client++)
	{
		g_bWeighdownEnable[client] = false;
        g_flNextTick[client] = 0.0;
	}
}
*/

stock float fmax(float x, float y)
{
	return x < y ? y : x;
}

stock float fmin(float x, float y)
{
	return x > y ? y : x;
}
