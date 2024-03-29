#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <ff2_modules/general>

public Plugin myinfo=
{
	name="Freak Fortress 2: Detect airshot",
	author="Nopied",
	description="just_subplugins",
	version="0.1",
};

int g_iTouched[MAXPLAYERS+1];

public void OnEntityCreated(int entity, const char[] classname)
{
    if(StrContains(classname, "tf_projectile_") != -1)
    {
        // SDKHook(entity, SDKHook_StartTouch, OnStartTouch);
        SDKHook(entity, SDKHook_Touch, OnStartTouch);
    }
}

public void OnClientPostAdminCheck(int client)
{
	g_iTouched[client] = 0;
	SDKHook(client, SDKHook_OnTakeDamageAlivePost, OnTakeDamageAlivePost);
}

public Action OnStartTouch(int entity, int other)
{
	if(MaxClients >= other && other > 0)
		g_iTouched[other]++;

	return Plugin_Continue;
}

public void OnTakeDamageAlivePost(int client, int attacker, int inflictor, float damageFloat, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	if(!(GetEntityFlags(client) & FL_ONGROUND) && !(GetEntityFlags(client) & FL_INWATER))
	{
		if(IsBoss(client) && TF2_IsPlayerInCondition(client, TFCond_BlastJumping))
		{
			if(damageFloat > 90.0)
				FF2_SpecialAttackToBoss(attacker, FF2_GetBossIndex(client), weapon, "projectile_airshot", g_iTouched[client]);
		}
	}
}

stock bool IsBoss(int client)
{
    return FF2_GetBossIndex(client) != -1;
}
