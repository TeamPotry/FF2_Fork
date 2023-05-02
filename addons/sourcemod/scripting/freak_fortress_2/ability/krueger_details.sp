#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>

#include <freak_fortress_2>
#include <ff2_modules/general>

#include <dhooks>

#pragma newdecls required

public Plugin myinfo=
{
	name="Freak Fortress 2: Freddy Krueger Abilities",
	author="Nopied◎",
	description="Welcome to Wonderland!",
	version="1.0",
};

#define THIS_PLUGIN_NAME        "krueger detail"

#define NOISE_REDUCE			"noise reduce"
#define TRANSMIT_BLOCK			"transmit block"
#define PLAYER_HUD_NOISE		"player hud noise"
#define COPIED_DUMMY			"copied dummy"

bool g_bNoiseReduced;
float g_flHudNoiseTime;

// bool g_bTransmitBlock[MAXPLAYERS+1];
float g_flTransmitBlockTime[MAXPLAYERS+1];

public void OnPluginStart()
{
	HookEvent("arena_round_start", Event_RoundStart);
	HookEvent("teamplay_round_active", Event_RoundStart); // for non-arena maps

	HookEvent("arena_win_panel", Event_RoundEnd);
	HookEvent("teamplay_round_win", Event_RoundEnd); // for non-arena maps

	AddNormalSoundHook(SoundHook);
	FF2_RegisterSubplugin(THIS_PLUGIN_NAME);
}

public void OnClientPostAdminCheck(int client)
{
	SDKHook(client, SDKHook_SetTransmit, TransmitHook);
}

public void FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status)
{
	if(StrEqual(abilityName, PLAYER_HUD_NOISE))
	{
		AddHudNoiseTime(boss);
	}
	if(StrEqual(abilityName, TRANSMIT_BLOCK))
	{
		TransmitBlock(boss);
	}
}

void AddHudNoiseTime(int boss)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));
	float duration = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, PLAYER_HUD_NOISE, "duration", 12.0);
	g_flHudNoiseTime = GetGameTime() + duration;

	float inOut = duration / 4.0, fadeDuration = inOut * 2.0;

	for(int target = 1; target <= MaxClients; target++)
	{
		if(!IsClientInGame(target) || !IsPlayerAlive(target)
			|| GetClientTeam(client) == GetClientTeam(target))
				continue;

		FadeClientVolume(target, 80.0, inOut, fadeDuration, inOut);
	}
}

void TransmitBlock(int boss)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));
	float duration = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, TRANSMIT_BLOCK, "duration", 12.0);

	for(int target = 1; target <= MaxClients; target++)
	{
		if(!IsClientInGame(target) || !IsPlayerAlive(target)
			|| GetClientTeam(client) == GetClientTeam(target)
			|| FF2_GetBossIndex(target) != -1)
				continue;

		g_flTransmitBlockTime[target] = GetGameTime() + duration;
	}
}

public Action TransmitHook(int entity, int toClient)
{
	if(entity > MaxClients 
		|| g_flTransmitBlockTime[toClient] < GetGameTime()
		|| entity == toClient) // FIXME: BOT
			return Plugin_Continue;

	if(GetClientTeam(entity) != GetClientTeam(toClient))
		return Plugin_Continue;

	return Plugin_Handled;
}

public Action SoundHook(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH],
	  int &entity, int &channel, float &volume, int &level, int &pitch, int &flags,
	  char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if(!g_bNoiseReduced || !IsValidClient(entity))
		return Plugin_Continue;

	// LogMessage("sample = %s, entity = %N, numClients = %d", sample, entity, numClients);

	float pos[3], targetpos[3];
	int newClients[MAXPLAYERS], newNumClients = 0;
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);

	for(int loop = 0; loop < numClients; loop++)
	{
		if(!IsValidClient(clients[loop]))		continue;
		GetEntPropVector(clients[loop], Prop_Send, "m_vecOrigin", targetpos);

		// LogMessage("clients[%d] = %N", loop, clients[loop]);

		if(GetVectorDistance(pos, targetpos) <= 800.0)
			newClients[newNumClients++] = clients[loop];
	}

	numClients = newNumClients;
	for(int loop = 0; loop < newNumClients; loop++)
		clients[loop] = newClients[loop];

	return Plugin_Changed;
}

public void FF2_OnCalledQueue(FF2HudQueue hudQueue, int client)
{
	if(g_flHudNoiseTime < GetGameTime() || !IsPlayerAlive(client))	return;

	char text[60];
	FF2HudDisplay hudDisplay = null;
	hudQueue.GetName(text, sizeof(text));

	if(StrEqual(text, "Player") || StrEqual(text, "Player Medic"))
	{
		hudQueue.DeleteAllDisplay();
		for(int loop = 0; loop < 60; loop++)
		{
			text[loop] = GetRandomInt(0, 65533);
			// 특수 문자 삭제
			if(text[loop] == '%')
				text[loop] = 'p';
		}

		hudDisplay = FF2HudDisplay.CreateDisplay("dummy", text);
		hudQueue.PushDisplay(hudDisplay);
	}
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_flHudNoiseTime = -1.0;
	g_bNoiseReduced = false;

	int boss;
	for(int client = 1; client <= MaxClients; client++)
	{
		g_flTransmitBlockTime[client] = 0.0;

		boss = FF2_GetBossIndex(client);
		if(boss == -1)	continue;

		if(FF2_HasAbility(boss, THIS_PLUGIN_NAME, NOISE_REDUCE))
			g_bNoiseReduced = true;
	}
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_flHudNoiseTime = -1.0;
	g_bNoiseReduced = false;

	for(int client = 1; client <= MaxClients; client++)
	{
		g_flTransmitBlockTime[client] = 0.0;
	}
}

stock bool IsValidClient(int client)
{
	return (0 < client && client <= MaxClients && IsClientInGame(client));
}
