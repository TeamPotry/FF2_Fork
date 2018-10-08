#include <sourcemod>
#include <morecolors>
#include <sdkhooks>
#include <freak_fortress_2>
#include <ff2_potry>

public Plugin myinfo=
{
	name="Freak Fortress 2: HUD DPS",
	author="Nopied",
	description="",
	version="2.0",
};

// NOTE: LOL

float g_flPlayerDPS[MAXPLAYERS+1][5];
int g_Count=0;

public void OnPluginStart()
{
    HookEvent("teamplay_round_start", OnRoundStart);
}

public void OnMapStart()
{
	CreateTimer(0.2, DPSTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
    for(int client = 1; client < MaxClients; client++)
        for(int loop = 0; loop < sizeof(g_flPlayerDPS[]); loop++)
            g_flPlayerDPS[client][loop] = 0.0;
}

public Action DPSTimer(Handle timer)
{
    g_Count += g_Count >= (sizeof(g_flPlayerDPS[]) - 1) ? -g_Count : 1;

    for(int client = 1; client < MaxClients; client++)
    {
        g_flPlayerDPS[client][g_Count] = 1.0 < g_flPlayerDPS[client][g_Count] ? g_flPlayerDPS[client][g_Count] / 5.0 : 0.0;
    }
}

public void OnClientPostAdminCheck(int client)
{
    SDKHook(client, SDKHook_OnTakeDamageAlivePost, OnTakeDamageAlivePost);
}

public void OnTakeDamageAlivePost(int client, int attacker, int inflictor, float damageFloat, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
    if(!IsBoss(client) || !IsValidClient(attacker)) return;

    g_flPlayerDPS[attacker][g_Count] += damageFloat;
}

public void FF2_OnCalledQueue(FF2HudQueue hudQueue)
{
    int client = hudQueue.ClientIndex;

    char text[256];
    hudQueue.GetName(text, sizeof(text));

    if(StrEqual(text, "Player"))
    {
        Format(text, sizeof(text), "DPS: %.1f", GetPlayerDPS(client));
        hudQueue.AddHud(new FF2HudDisplay("Your DPS", text));
		// PrintToChat(client, "%d", hudQueue.AddHud(new FF2HudDisplay("Your DPS", text)));
    }
    else if(StrEqual(text, "Observer"))
    {
        int observer = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
        if(!IsBoss(observer))
        {
			Format(text, sizeof(text), "DPS: %.1f", GetPlayerDPS(observer));
			hudQueue.AddHud(new FF2HudDisplay("Observer Target Player DPS", text), observer);
			// PrintToChat(client, "%d", hudQueue.AddHud(new FF2HudDisplay("Observer Target Player DPS", text), observer));
		}
    }
}

float GetPlayerDPS(int client)
{
    float total = 0.0;
    for(int loop = 0; loop < sizeof(g_flPlayerDPS[]); loop++)
    {
        total += g_flPlayerDPS[client][loop];
    }

    if(total < 0.5)
        return 0.0;
    return total / sizeof(g_flPlayerDPS[]);
}

//////////////////////

stock bool IsBoss(int client)
{
    return FF2_GetBossIndex(client) != -1;
}

stock bool IsValidClient(int client, bool replaycheck=true)
{
	if(client<=0 || client>MaxClients)
	{
		return false;
	}

	if(!IsClientInGame(client))
	{
		return false;
	}

	if(GetEntProp(client, Prop_Send, "m_bIsCoaching"))
	{
		return false;
	}

	if(replaycheck)
	{
		if(IsClientSourceTV(client) || IsClientReplay(client))
		{
			return false;
		}
	}
	return true;
}
