#include <sourcemod>
#include <morecolors>
#include <freak_fortress_2>
#include <ff2_potry>

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

public void FF2_OnCalledQueue(FF2HudQueue hudQueue)
{
	if(!g_bDEVmode) return;

	int client = hudQueue.ClientIndex;
	SetGlobalTransTarget(client);
	FF2HudDisplay hudDisplay = null;
	char text[256];
	hudQueue.GetName(text, sizeof(text));

	bool changed = false;

	if(StrEqual(text, "Boss"))
	{
		int noticehudId = hudQueue.FindHud("Activate Rage");
		if(noticehudId != -1)
		{
			hudQueue.SetHud(noticehudId, hudQueue.GetHud(noticehudId).KillSelf());
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

		hudDisplay = new FF2HudDisplay("Dev Mode", text);
		hudQueue.AddHud(hudDisplay);
		delete hudDisplay;
	}

	return;
}

stock bool IsBoss(int client)
{
    return FF2_GetBossIndex(client) != -1;
}
