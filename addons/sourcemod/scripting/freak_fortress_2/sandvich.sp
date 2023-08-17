#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2attributes>
#include <tf2utils>
#include <freak_fortress_2>
#include <ff2_modules/general>

public Plugin:myinfo =
{
	name = "Sandvich Invulnerable",
	author = "Nopied◎",
	description = "the Picnics",
	version = "20230813",
	url = ""
}

// https://wiki.teamfortress.com/wiki/Sandvich
#define SANDVICH_EAT_TIME			4.3

float g_flEatHealthTime[MAXPLAYERS+1];
float g_flEatEndTime[MAXPLAYERS+1];

public void OnPluginStart()
{
	HookEvent("teamplay_round_start", OnRoundStart);

	AddNormalSoundHook(SoundHook);
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for(int client = 1; client <= MaxClients; client++)
	{
		g_flEatHealthTime[client] = 0.0;
		g_flEatEndTime[client] = 0.0;
	}

	return Plugin_Continue;
}

bool IsPlaying = false;
public Action SoundHook(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH],
	  int &entity, int &channel, float &volume, int &level, int &pitch, int &flags,
	  char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	// vo/SandwichEat09.mp3
	if(!StrEqual(sample, "vo/SandwichEat09.mp3") || FF2_GetBossIndex(entity) != -1 || IsPlaying)
		return Plugin_Continue;

	int weapon = GetEntPropEnt(entity, Prop_Send, "m_hActiveWeapon"),
		mode = TF2Attrib_HookValueInt(0, "set_weapon_mode", weapon);

	switch(mode)
	{
		// default
		case 0, 6: 
		{
			g_flEatEndTime[entity] = GetGameTime() + SANDVICH_EAT_TIME;
			g_flEatHealthTime[entity] = 0.0;
		
			RequestFrame(SandvichHealThink, entity);
		}
		case 1: // LUNCHBOX_ADDS_MAXHEALTH
		{
			Address address = TF2Attrib_GetByDefIndex(entity, 125);

			float value = 10.0;
			if(address != Address_Null)
				value += TF2Attrib_GetValue(address);

			TF2Attrib_SetByDefIndex(entity, 125, value);
		}
	}

	IsPlaying = true;
	RequestFrame(SoundEnd);
	return Plugin_Continue;
}

public void SoundEnd()
{
	IsPlaying = false;
}

public void SandvichHealThink(int client)
{
	if(g_flEatEndTime[client] < GetGameTime() || !TF2_IsPlayerInCondition(client, TFCond_Taunting))
	{
		g_flEatEndTime[client] = 0.0;
		g_flEatHealthTime[client] = 0.0;
		return;
	}

	if(g_flEatHealthTime[client] > GetGameTime())
	{
		RequestFrame(SandvichHealThink, client);
		return;
	}

	int maxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth"),
		currentHealth = GetEntProp(client, Prop_Data, "m_iHealth");

	if(currentHealth < maxHealth)
	{
		RequestFrame(SandvichHealThink, client);
		return;
	}

	TF2Util_TakeHealth(client, 1.0, TAKEHEALTH_IGNORE_MAXHEALTH);

	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	float multiplier = 1.0 / TF2Attrib_HookValueFloat(1.0, "lunchbox_healing_scale", weapon);

	g_flEatHealthTime[client] = GetGameTime() + (GetTickInterval() * multiplier);
	RequestFrame(SandvichHealThink, client);
}

stock bool IsValidClient(int client)
{
	return (0 < client && client <= MaxClients && IsClientInGame(client));
}
