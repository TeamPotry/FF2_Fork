#include <sourcemod>
// #include <morecolors>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <ff2_potry>
// #include <ff2_boss_selection>

public Plugin myinfo=
{
	name="Freak Fortress 2: Demopan",
	author="Nopied",
	description="",
	version="2(1.0)",
};

#define THIS_PLUGIN_NAME "demopan_detail"

#define AIR_CHARGE_ABILITY "air charge"

public void OnPluginStart()
{
	FF2_RegisterSubplugin(THIS_PLUGIN_NAME);
}

public void FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status)
{
	if(StrEqual(abilityName, "democharge_detail"))
	{
		if(status == 0) return;
		int client = GetClientOfUserId(FF2_GetBossUserId(boss));

		if(status == 1)
		{
			SetEntPropFloat(client, Prop_Send, "m_flChargeMeter", 100.0);
			TF2_AddCondition(client, TFCond_Charging, 0.12);
		}
    }
}

// 데모판의 돌진을 감지하고 Y축 속도값을 시야와 일치하도록 변경
public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	int boss = FF2_GetBossIndex(client);
	if(!IsPlayerAlive(client) || boss == -1) return Plugin_Continue;

	// Air charge
	if(TF2_IsPlayerInCondition(client, TFCond_Charging)
	&& FF2_HasAbility(boss, THIS_PLUGIN_NAME, AIR_CHARGE_ABILITY))
	{
		float angles[3], velocity[3];
		GetClientEyeAngles(client, angles);
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);

		// y: angle = 0, velocity = 2
		// 시야 기준에서 0도가 수치 상으로 몇 도인지 모름
	}

	return Plugin_Continue;
}

stock bool IsBoss(int client)
{
	return FF2_GetBossIndex(client) != -1;
}
