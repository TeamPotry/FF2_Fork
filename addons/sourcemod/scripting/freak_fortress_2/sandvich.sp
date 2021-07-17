#include <sourcemod>
#include <sdktools>
#include <freak_fortress_2>
#include <ff2_potry>

public Plugin:myinfo =
{
	name = "Sandvich Invulnerable",
	author = "Nopied◎",
	description = "the Picnics",
	version = "0.0",
	url = ""
}

public Action:OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if(FF2_GetBossIndex(client) == -1)
	{
		if(IsClientInGame(client) && IsPlayerAlive(client) && buttons & IN_ATTACK)
		{
			int activeWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			char classname[64];
			GetEdictClassname(activeWeapon, classname, sizeof(classname));

			if(StrEqual(classname, "tf_weapon_lunchbox", false))
			{
				TF2_AddCondition(client, TFCond_Ubercharged, 3.0);
			}
		}
	}
	return Plugin_Continue;
}
