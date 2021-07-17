#include <sourcemod>
#include <freak_fortress_2>
#include <ff2_potry>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>
#include <mannvsmann>
#include <morecolors>

#define PLUGIN_VERSION "0.1"

public Plugin myinfo=
{
	name="Freak Fortress 2: Mann Vs Mann",
	author="Nopied◎",
	description="Compatible with Mann vs. Mann plugins.",
	version=PLUGIN_VERSION,
};

public void OnPluginStart()
{
	LoadTranslations("freak_fortress_2.phrases");
}

public void OnMapStart()
{
	PrecacheSound("mvm/mvm_money_pickup.wav");
}

public Action FF2_OnSpecialAttack(int attacker, int victimBoss, int weapon, const char[] name, float &damage)
{
	Address address = Address_Null;

	if(StrEqual("backstab", name))
	{
		address = TF2Attrib_GetByDefIndex(weapon, 399); // armor_piercing
		if(address != Address_Null)
		{
			damage *= (TF2Attrib_GetValue(address) * 0.01) + 1.0;
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

public void FF2_OnWaveStarted(int wave)
{
	int boss;

	for(int client = 1; client <= MaxClients; client++)
	{
		if(!IsClientInGame(client)) 		continue;

		MVM_SetPlayerCurrency(client, MVM_GetPlayerCurrency(client) + 200);

		if(IsBoss(client) && FF2_GetBossTeam() == TF2_GetClientTeam(client))
		{
			boss = FF2_GetBossIndex(client);
			FF2_SetBossHealth(boss, RoundFloat(FF2_GetBossHealth(boss) * 1.03));
		}
		else
		{
			EmitSoundToClient(client, "mvm/mvm_money_pickup.wav");
		}
	}

	CPrintToChatAll("{olive}[FF2]{default} %t", "Wave Started");
}

public Action MVM_OnTouchedUpgradeStation(int upgradeStation, int client)
{
	if(IsBoss(client) || (FF2_GetFF2Flags(client) & FF2FLAG_CLASSTIMERDISABLED) > 0)
		return Plugin_Handled;

	return Plugin_Continue;
}

stock bool IsBoss(int client)
{
	return FF2_GetBossIndex(client) != -1;
}
