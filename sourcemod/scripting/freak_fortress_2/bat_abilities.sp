#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <ff2_potry>

#define PLUGIN_NAME "bat abilities"
#define PLUGIN_VERSION "20190430"

public Plugin myinfo=
{
	name="Freak Fortress 2: Bat Abilities",
	author="Nopied",
	description="FF2: Special abilities for Scout's Bat",
	version=PLUGIN_VERSION,
};

#define BALL_EXPLOSION_NAME "ball explosion"

public void OnPluginStart()
{
    FF2_RegisterSubplugin(PLUGIN_NAME);
}

/*
public void FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status)
{

}
*/

public void OnEntityCreated(int entity, const char[] classname)
{
    if(StrEqual(classname, "tf_projectile_stun_ball"))
    {
        // It is ball.
        SDKHook(entity, SDKHook_SpawnPost, OnBallSpawned);
    }
}

public Action OnBallSpawned(int entity)
{
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");

	if(IsBoss(owner))
	{
		int boss = FF2_GetBossIndex(owner);

		if(FF2_HasAbility(boss, PLUGIN_NAME, "ball explosion"))
		{
			SDKHook(entity, SDKHook_Think, OnBallTouched_Explosion);
		}

	}

	return Plugin_Continue;
}

public void OnBallTouched_Explosion(int entity)
{
	int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"), boss = FF2_GetBossIndex(client);
	if(boss == -1) return;

	int magnitude = FF2_GetAbilityArgument(boss, PLUGIN_NAME, BALL_EXPLOSION_NAME, "magnitude", 60), team = GetClientTeam(client);
	float pos[3], targetPos[3], damage = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, BALL_EXPLOSION_NAME, "damage", 40.0);
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);

	for(int target = 1; target <= MaxClients; target++)
	{
		if(IsClientInGame(target) && IsPlayerAlive(target) && team != GetClientTeam(target)) {
			GetClientEyePosition(target, targetPos);
			if(RoundFloat(GetVectorDistance(pos, targetPos)) < (magnitude * 2)) {
				SpawnExplosion(client, pos, magnitude, damage);

				AcceptEntityInput(entity, "Kill");
				return;
			}
		}
	}
}

stock int SpawnExplosion(int owner, float pos[3], int magnitude, float damage)
{
	int explosion=CreateEntityByName("env_explosion");
	DispatchKeyValueFloat(explosion, "DamageForce", damage);

	SetEntProp(explosion, Prop_Data, "m_iMagnitude", magnitude, 4);
	SetEntProp(explosion, Prop_Data, "m_iRadiusOverride", magnitude*2, 4);
	SetEntPropEnt(explosion, Prop_Data, "m_hOwnerEntity", owner);

	DispatchSpawn(explosion);

	TeleportEntity(explosion, pos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(explosion, "Explode");
	AcceptEntityInput(explosion, "kill");
}

stock bool IsBoss(int client)
{
	return FF2_GetBossIndex(client) != -1;
}
