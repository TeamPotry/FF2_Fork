#include <sourcemod>
#include <morecolors>
#include <freak_fortress_2>
#include <ff2_potry>
#include <ff2_boss_selection>

public Plugin myinfo=
{
	name="Freak Fortress 2: Developer Mode",
	author="Nopied",
	description="FF2: Abilities test.",
	version="2(1.0)",
};

bool g_bDEVmode = false;

public void OnPluginStart()
{
	RegAdminCmd("ff2_devmode", Command_DevMode, ADMFLAG_CHEATS, "WOW! INFINITE RAGE!");

	HookEvent("teamplay_round_start", OnRoundStart);
	LoadTranslations("freak_fortress_2.phrases");
}

public Action Command_DevMode(int client, int args)
{
    CPrintToChatAll("{olive}[FF2]{default} DEVMode: %s", !g_bDEVmode ? "ON" : "OFF");
    g_bDEVmode = !g_bDEVmode;

    return Plugin_Continue;
}

public Action OnRoundStart(Event event, const char[] name, bool dontbroad)
{
    g_bDEVmode = false;

    return Plugin_Continue;
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool& result)
{
	if(g_bDEVmode && FF2_GetBossIndex(client) != -1) {
		FF2_SetBossCharge(FF2_GetBossIndex(client), 0, 100.0); // TODO: 최대 분노량 조절
	}

	return Plugin_Continue;
}

public void FF2_OnCalledQueue(FF2HudQueue hudQueue, int client)
{
	if(!g_bDEVmode) return;

	char text[256];
	bool changed = false;
	FF2HudDisplay hudDisplay = null;

	SetGlobalTransTarget(client);
	hudQueue.GetName(text, sizeof(text));

	if(StrEqual(text, "Boss"))
	{
		int noticehudId = hudQueue.FindHud("Activate Rage");
		if(noticehudId != -1)
		{
			hudQueue.DeleteDisplay(noticehudId);
		}
		changed = true;
	}
	else if(StrEqual(text, "Observer"))
	{
		int observer = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
		changed = IsBoss(observer);
	}

	if(changed)
	{
		Format(text, sizeof(text), "%t", "Dev Mode");

		hudDisplay = FF2HudDisplay.CreateDisplay("Dev Mode", text);
		hudQueue.AddHud(hudDisplay, client);
	}

	return;
}

public Action FF2_OnCheckRules(int client, int characterIndex, int &chance, const char[] ruleName, const char[] value)
{
	if(StrEqual(ruleName, "need_dev_mode"))
		return g_bDEVmode ? Plugin_Continue : Plugin_Handled;

	return Plugin_Continue;
}

public Action FF2_OnCheckSelectRules(int client, int characterIndex, const char[] ruleName, const char[] value)
{
	if(StrEqual(ruleName, "need_dev_mode"))
		return g_bDEVmode ? Plugin_Continue : Plugin_Handled;

	return Plugin_Continue;
}

stock bool IsBoss(int client)
{
    return FF2_GetBossIndex(client) != -1;
}
