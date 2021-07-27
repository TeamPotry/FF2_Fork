#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <freak_fortress_2>

#tryinclude <ff2_potry>
#if !defined _ff2_potry_included
	#include <freak_fortress_2_subplugin>
#endif

public Plugin myinfo=
{
	name="Freak Fortress 2: shush.. shushshushshush!",
	author="Nopied◎",
	description="",
	version="1.0",
};

#define THIS_PLUGIN_NAME "dolhare detail"

#define THROW_KNIFE     "shush"

int g_iKnifeTick[MAXPLAYERS+1];
float g_iKnifeTickAngle[MAXPLAYERS+1];
float g_flKnifeAngle[MAXPLAYERS+1];
float g_flKnifeSpeed[MAXPLAYERS+1];

float g_flYAngleOffset[MAXPLAYERS+1];
float g_flYPosOffset[MAXPLAYERS+1];

#if defined _ff2_potry_included
public void OnPluginStart()
#else
public void OnPluginStart2()
#endif
{
    HookEvent("arena_round_start", Event_RoundStart);
    HookEvent("teamplay_round_active", Event_RoundStart); // for non-arena maps

#if defined _ff2_potry_included
    FF2_RegisterSubplugin(THIS_PLUGIN_NAME);
#endif

}

#if defined _ff2_potry_included
public void FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status)
#else
public Action FF2_OnAbility2(int boss, const char[] pluginName, const char[] abilityName, int status)
#endif
{
    if(StrEqual(abilityName, THROW_KNIFE))
    {
        InvokeShush(boss);
    }
}

void InvokeShush(int boss)
{
    int client = GetClientOfUserId(FF2_GetBossUserId(boss));

#if defined _ff2_potry_included
	int tick = FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, THROW_KNIFE, "tick", 36);
	g_flKnifeAngle[client] = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, THROW_KNIFE, "degree", 10.0);
	g_flKnifeSpeed[client] = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, THROW_KNIFE, "speed", 2000.0);
	g_flYPosOffset[client] = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, THROW_KNIFE, "y pos offset", 50.0);
	g_flYAngleOffset[client] = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, THROW_KNIFE, "y angle offset", 17.0);
#else
    int tick = FF2_GetAbilityArgument(boss, this_plugin_name, THROW_KNIFE, 1, 36);
    g_flKnifeAngle[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, THROW_KNIFE, 2, 10.0);
	g_flKnifeSpeed[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, THROW_KNIFE, 3, 2000.0);
	g_flYPosOffset[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, THROW_KNIFE, 4, 50.0);
	g_flYAngleOffset[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, THROW_KNIFE, 5, 17.0);
#endif
//

    g_iKnifeTickAngle[client] = 0.0;

    if(g_iKnifeTick[client] == 0)
        SDKHook(client, SDKHook_PostThink, OnShushThink);
    g_iKnifeTick[client] = tick;
}

public void OnShushThink(int client)
{
    if(FF2_GetRoundState() != 1 || !IsClientInGame(client) || !IsPlayerAlive(client)
    || g_iKnifeTick[client] == 0)
    {
        SDKUnhook(client, SDKHook_PostThink, OnShushThink);
        return;
    }

    float pos[3], eyeAngles[3];
    GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
    GetClientEyeAngles(client, eyeAngles);

    pos[2] += g_flYPosOffset[client];
    eyeAngles[0] -= g_flYAngleOffset[client];

    if(g_iKnifeTickAngle[client] > 360.0)
        g_iKnifeTickAngle[client] = 0.0;
    else
        eyeAngles[1] += g_iKnifeTickAngle[client];

    g_iKnifeTickAngle[client] += g_flKnifeAngle[client];
    SpawnCleaver(client, pos, eyeAngles, 2000.0);

    g_iKnifeTick[client]--;
}

void SpawnCleaver(int owner, float pos[3], float angles[3], float speed)
{
    int projectile = CreateEntityByName("tf_projectile_cleaver");
    if(!IsValidEntity(projectile))      return;

    float velocity[3];
    GetAngleVectors(angles, velocity, NULL_VECTOR, NULL_VECTOR);
    GetAngleVectors(angles, angles, NULL_VECTOR, NULL_VECTOR);

    ScaleVector(velocity, speed);

    SetEntPropEnt(projectile, Prop_Send, "m_hOwnerEntity", owner);
    SetEntProp(projectile, Prop_Send, "m_iTeamNum", GetClientTeam(owner));

    DispatchSpawn(projectile);
    TeleportEntity(projectile, pos, angles, velocity);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for(int client = 1; client <= MaxClients; client++)
	{
		g_iKnifeTick[client] = 0;
	}
}
