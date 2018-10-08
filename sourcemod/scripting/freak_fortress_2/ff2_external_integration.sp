//Freak Fortress 2 External Integration Subplugin
//Used to balance popular external plugins with FF2
//Currently supports: Goomba Stomp, RTD
#pragma semicolon 1

#include <sourcemod>
#include <freak_fortress_2>
#include <ff2_potry>
#include <tf2>
#include <tf2_stocks>
#include <morecolors>
#undef REQUIRE_PLUGIN
#tryinclude <goomba>
#tryinclude <rtd>
#tryinclude <rtd2>
#define REQUIRE_PLUGIN

#pragma newdecls required

#define PLUGIN_VERSION "0.0.0"

ConVar cvarGoomba;
ConVar cvarGoombaDamage;
ConVar cvarGoombaRebound;
ConVar cvarRTD;
ConVar cvarBossRTD;

KeyValues KvText;

public Plugin myinfo=
{
	name="Freak Fortress 2 External Integration Subplugin",
	author="Wliu, WildCard65",
	description="Integrates with popular plugins commonly run on FF2 servers",
	version=PLUGIN_VERSION,
};

public void OnPluginStart()
{
	cvarGoomba=CreateConVar("ff2_goomba", "1", "Allow FF2 to integrate with Goomba Stomp?", _, true, 0.0, true, 1.0);
	cvarGoombaDamage=CreateConVar("ff2_goomba_damage", "0.05", "How much the Goomba damage should be multiplied by", _, true, 0.0, true, 1.0);
	cvarGoombaRebound=CreateConVar("ff2_goomba_rebound", "300.0", "How high players should rebound after a Goomba stomp", _, true, 0.0);
	cvarRTD=CreateConVar("ff2_rtd", "1", "Allow FF2 to integrate with RTD?", _, true, 0.0, true, 1.0);
	cvarBossRTD=CreateConVar("ff2_boss_rtd", "0", "Allow the boss to use RTD?", _, true, 0.0, true, 1.0);

	AutoExecConfig(false, "ff2_external_integration", "sourcemod/freak_fortress_2");

	LoadTranslations("ff2_external_integration.phrases");

	if(KvText != null)
		delete KvText;
	KvText = LoadSpecialAttackText();
}

public Action OnStomp(int attacker, int victim, float &damageMultiplier, float &damageBonus, float &JumpPower)
{
	if(FF2_IsFF2Enabled() && cvarGoomba.BoolValue)
	{
		if(FF2_GetBossTeam() == TF2_GetClientTeam(attacker))
		{
			/*
			float position[3];
			GetEntPropVector(attacker, Prop_Send, "m_vecOrigin", position);
			damageMultiplier=900.0;
			JumpPower=0.0;
			PrintCenterText(victim, "%t", "Human Got Goomba Stomped");
			PrintCenterText(attacker, "%t", "Boss Goomba Stomped");
			return Plugin_Changed;
			*/
			return Plugin_Handled;
		}
		else
		{
			damageMultiplier=cvarGoombaDamage.FloatValue;
			JumpPower=cvarGoombaRebound.FloatValue;
			PrintCenterText(victim, "%t", "Boss Got Goomba Stomped");
			PrintCenterText(attacker, "%t", "Human Goomba Stomped");

			int boss = FF2_GetBossIndex(victim);
			int adddmg = RoundFloat(FindConVar("goomba_dmg_add").FloatValue);
			if(boss != -1)
				FF2_SpecialAttackToBoss(attacker, boss, "goomba", ((FF2_GetBossHealth(boss) - FF2_GetBossMaxHealth(boss) * (FF2_GetBossLives(boss) - 1)) * damageMultiplier) + adddmg);
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

public void FF2_OnSpecialAttack_Post(int attacker, int victimBoss, const char[] name, float damage)
{
	if(KvText == null)	return;

	char bossName[64], how[80], langId[4];
	KvText.Rewind();
	if(!KvText.JumpToKey(name))
		return;

	int roundDamage = RoundFloat(damage);
	for(int client = 1; client <= MaxClients; client++)
	{
		if(!IsClientInGame(client)) continue;

		GetLanguageInfo(GetClientLanguage(client), langId, sizeof(langId));
		KvText.GetString(langId, how, sizeof(how), "EMPTY NAME!");
		FF2_GetBossName(victimBoss, bossName, sizeof(bossName), client);

		CPrintToChat(client, "{olive}[FF2]{default} %t", "Special Attack", attacker, bossName, how, roundDamage);
	}
}

stock KeyValues LoadSpecialAttackText()
{
	char config[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, config, sizeof(config), "data/freak_fortress_2/special_attack_text.cfg");
	if(!FileExists(config))
	{
		LogError("[FF2] special_attack_text %s does not exist!", config);
		return null;
	}

	KeyValues kv = new KeyValues("special_attack_text");
	kv.ImportFromFile(config);
	kv.Rewind();

	return kv;
}

public Action RTD_CanRollDice(int client)
{
	return (FF2_GetBossIndex(client)!=-1 && cvarRTD.BoolValue && !cvarBossRTD.BoolValue) ? Plugin_Handled : Plugin_Continue;
}

public Action RTD2_CanRollDice(int client)
{
	return (FF2_GetBossIndex(client)!=-1 && cvarRTD.BoolValue && !cvarBossRTD.BoolValue) ? Plugin_Handled : Plugin_Continue;
}
