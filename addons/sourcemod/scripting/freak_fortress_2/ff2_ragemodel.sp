#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <ff2_modules/general>

// TODO: LITERALLY FIX THIS.
public Plugin:myinfo = {
	name = "Freak Fortress 2: Rage Model",
	author = "frog (Forked by Nopied)",
	version = "1.1"
};

#define PLUGIN_NAME			"ff2_ragemodel"

#define CHANGE_MODEL_NAME	"change model"

Handle g_hModelChangeTimer[MAXPLAYERS+1];

public OnPluginStart()
{
	HookEvent("arena_round_start", Event_RoundStartOrEnd);
	HookEvent("teamplay_round_active", Event_RoundStartOrEnd); // for non-arena maps

	HookEvent("arena_win_panel", Event_RoundStartOrEnd);
	HookEvent("teamplay_round_win", Event_RoundStartOrEnd); // for non-arena maps

	FF2_RegisterSubplugin(PLUGIN_NAME);
}

public void Event_RoundStartOrEnd(Event event, const char[] name, bool dontBroadcast)
{
	DeleteAllModelChangeTimer();
}

public void OnMapStart()
{
	DeleteAllModelChangeTimer(true);
}

public void FF2_OnAbility(int boss, const char[] pluginName, const char[] ability_name, int slot, int status)
{
	if (!strcmp(ability_name,CHANGE_MODEL_NAME))
		Rage_Model(ability_name, boss);	//change model on rage
}


Rage_Model(const String:ability_name[], boss)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));
	float duration = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, ability_name, "duration");	//duration

	char rageModel[PLATFORM_MAX_PATH];
	FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, ability_name, "rage model", rageModel, PLATFORM_MAX_PATH);	//rage model
	// FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, CHANGE_MODEL_NAME, "normal model", g_NormalModel, PLATFORM_MAX_PATH);	//normal model

	ChangeBossModel(rageModel, client);

	if(g_hModelChangeTimer[client] != null)
	{
		KillTimer(g_hModelChangeTimer[client]);
		g_hModelChangeTimer[client] = null;
	}

	if(duration > 0.0)
		g_hModelChangeTimer[client] = CreateTimer(duration, RestoreModel, client, TIMER_FLAG_NO_MAPCHANGE);
}

void DeleteAllModelChangeTimer(bool force = false)
{
	for(int client = 1; client <= MaxClients; client++)
	{
		if(g_hModelChangeTimer[client] != null)
		{
			if(!force)
				KillTimer(g_hModelChangeTimer[client]);
			g_hModelChangeTimer[client] = null;
		}
	}
}

public ChangeBossModel(const String:model[], any:client)
{
	SetVariantString(model);
	AcceptEntityInput(client, "SetCustomModel");
	SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
}

public Action:RestoreModel(Handle:timer, any:client)
{
	g_hModelChangeTimer[client] = null;

	int boss = FF2_GetBossIndex(client);
	if(IsClientInGame(client) && IsPlayerAlive(client) && boss != -1)
	{
		char normalModel[PLATFORM_MAX_PATH];
		FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, CHANGE_MODEL_NAME, "normal model", normalModel, PLATFORM_MAX_PATH);	//normal model
		ChangeBossModel(normalModel, client);
	}
}
