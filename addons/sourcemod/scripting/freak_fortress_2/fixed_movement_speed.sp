#include <sourcemod>
#include <freak_fortress_2>
#include <ff2_potry>
#include <tf2>
#include <tf2_stocks>
#include <dhooks>

public Plugin myinfo=
{
	name="Freak Fortress 2: Fixed movement speed",
	author="Nopied◎",
	description="Fixed movement speed for boss.",
	version="20210824",
};

bool g_bPressSwitch[MAXPLAYERS+1] = false;
int g_hWeaponindex[MAXPLAYERS+1];

public void OnPluginStart()
{
    HookEvent("player_spawn", OnPlayerSpawn);

	GameData gamedata = new GameData("potry");
	if (gamedata)
	{
		CreateDynamicDetour(gamedata, "CTFPlayer::TeamFortress_SetSpeed()", DHookCallback_TeamFortress_SetSpeed_Pre);
		delete gamedata;
	}
	else
	{
		SetFailState("Could not find potry gamedata");
	}
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
	g_hWeaponindex[client] = 0;
    g_bPressSwitch[client] = false;
}

static void CreateDynamicDetour(GameData gamedata, const char[] name, DHookCallback callbackPre = INVALID_FUNCTION, DHookCallback callbackPost = INVALID_FUNCTION)
{
	DynamicDetour detour = DynamicDetour.FromConf(gamedata, name);
	if (detour)
	{
		if (callbackPre != INVALID_FUNCTION)
			detour.Enable(Hook_Pre, callbackPre);

		if (callbackPost != INVALID_FUNCTION)
			detour.Enable(Hook_Post, callbackPost);
	}
	else
	{
		LogError("Failed to create detour setup handle for %s", name);
	}
}


public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
    if(g_hWeaponindex[client] == 0 && weapon > 0)
    {
        g_hWeaponindex[client] = weapon;
    }
    else if(g_hWeaponindex[client] > 0 && weapon > 0)
    {
        g_hWeaponindex[client] = weapon;
        g_bPressSwitch[client] = true;

        RequestFrame(ReleaseButton, client);
    }

    return Plugin_Continue;
}

public void ReleaseButton(int client)
{
    g_bPressSwitch[client] = false;
}

public MRESReturn DHookCallback_TeamFortress_SetSpeed_Pre(int pThis)
{
    if(pThis == -1)     return MRES_Ignored;
/*
    if(!IsFakeClient(pThis))
        PrintToChatAll("%N, %s", pThis, g_bPressSwitch[pThis] ? "true" : "false");
*/
    if(g_bPressSwitch[pThis])
    {
        if(FF2_GetBossIndex(pThis) != -1 /*|| TF2_IsPlayerInCondition(pThis, TFCond_Dazed)*/)
        {
            return MRES_Supercede;
        }
    }

    return MRES_Ignored;
}
