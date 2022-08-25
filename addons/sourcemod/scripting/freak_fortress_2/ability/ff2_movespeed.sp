#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>
#include <sdkhooks>
#include <sdktools>
#include <sdktools_functions>
#include <tf2utils>
#include <freak_fortress_2>
#include <ff2_modules/general>

#define MAJOR_REVISION "1"
#define MINOR_REVISION "3"
#define PATCH_REVISION "4"

#if !defined PATCH_REVISION
	#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION
#else
	#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION..."."...PATCH_REVISION
#endif

// Movespeed
new Float:NewSpeed[MAXPLAYERS+1];
new Float:NewSpeedDuration[MAXPLAYERS+1];
new bool:DSM_SpeedOverride[MAXPLAYERS+1];

#define THIS_PLUGIN_NAME 	"ff2_movespeed"
#define INACTIVE 			100000000.0
#define MOVESPEED 			"rage_movespeed"
#define MOVESPEEDALIAS 		"MVS"

public Plugin:myinfo = {
    name = "Freak Fortress 2: Move Speed",
    author = "SHADoW NiNE TR3S (Forked by Nopied◎)",
    version = PLUGIN_VERSION,
};

public OnPluginStart()
{
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("arena_win_panel", Event_WinPanel);

	PrepareAbilities(); // late-load ? reload?
	FF2_RegisterSubplugin(THIS_PLUGIN_NAME);
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrepareAbilities();
}

public PrepareAbilities()
{
	for(new client=1;client<=MaxClients;client++)
	{
		if (IsValidClient(client))
		{
			DSM_SpeedOverride[client]=false;
			NewSpeed[client]=0.0;
			NewSpeedDuration[client]=INACTIVE;
		}
	}
}


public void FF2_OnPlayBoss(int boss)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));

	DSM_SpeedOverride[client]=false;
	NewSpeed[client]=0.0;
	NewSpeedDuration[client]=INACTIVE;
}

public Action:Event_WinPanel(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(new client=1;client<=MaxClients;client++)
	{
		if (IsValidClient(client))
		{
			DSM_SpeedOverride[client]=false;
			SDKUnhook(client, SDKHook_PreThink, MoveSpeed_Prethink);
			NewSpeed[client]=0.0;
			NewSpeedDuration[client]=INACTIVE;
		}
	}
}

public bool:MVS_CanInvoke(client)
{
	return true;
}

Rage_MoveSpeed(client, slot)
{
	MVS_Invoke(client, slot); // Activate RAGE normally, if ability is configured to be used as a normal RAGE.
}

MVS_Invoke(client, slot = -3)
{
	new boss=FF2_GetBossIndex(client);
	char nSpeed[10], nDuration[10]; // Foolproof way so that args always return floats instead of ints
	FF2_GetAbilityArgumentString(boss, THIS_PLUGIN_NAME, MOVESPEED, "boss set speed", nSpeed, sizeof(nSpeed), _, slot);
	FF2_GetAbilityArgumentString(boss, THIS_PLUGIN_NAME, MOVESPEED, "boss duration", nDuration, sizeof(nDuration), _, slot);


	if(nSpeed[0]!='\0' || nDuration[0]!='\0')
	{
		if(nSpeed[0]!='\0')
		{
			NewSpeed[client]=StringToFloat(nSpeed); // Boss Move Speed
		}
		if(nDuration[0]!='\0')
		{
		/*
			if(NewSpeedDuration[client]!=INACTIVE)
			{
				NewSpeedDuration[client]+=StringToFloat(nDuration); // Add time if rage is active?
			}
			else
			{
				NewSpeedDuration[client]=GetEngineTime()+StringToFloat(nDuration); // Boss Move Speed Duration
			}
		*/
			NewSpeedDuration[client]=GetEngineTime()+StringToFloat(nDuration); // Boss Move Speed Duration
		}

		SDKHook(client, SDKHook_PreThink, MoveSpeed_Prethink);
	}

	new Float:dist2=FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, MOVESPEED, "victim range", 0.0, slot);
	if(dist2)
	{
		if(dist2 < 0.0)		return;

		FF2_GetAbilityArgumentString(boss, THIS_PLUGIN_NAME, MOVESPEED, "victim set speed", nSpeed, sizeof(nSpeed));
		FF2_GetAbilityArgumentString(boss, THIS_PLUGIN_NAME, MOVESPEED, "victim duration", nDuration, sizeof(nDuration));

		new Float:pos[3], Float:pos2[3], Float:dist;
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
		for(new target=1;target<=MaxClients;target++)
		{
			if(!IsValidClient(target))
				continue;

			GetEntPropVector(target, Prop_Send, "m_vecOrigin", pos2);
			dist=GetVectorDistance( pos, pos2 );
			if (dist<dist2 && IsPlayerAlive(target) && GetClientTeam(target)!=GetClientTeam(client))
			{
				SDKHook(target, SDKHook_PreThink, MoveSpeed_Prethink);
				NewSpeed[target]=StringToFloat(nSpeed); // Victim Move Speed
				if(NewSpeedDuration[target]!=INACTIVE)
				{
					NewSpeedDuration[target]+=StringToFloat(nDuration); // Add time if rage is active?
				}
				else
				{
					NewSpeedDuration[target]=GetEngineTime()+StringToFloat(nDuration); // Victim Move Speed Duration
				}
			}
		}
	}
}

public void FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return; // Because some FF2 forks still allow RAGE to be activated when the round is over....

	new client=GetClientOfUserId(FF2_GetBossUserId(boss));
	if(!strcmp(abilityName, MOVESPEED))
	{
		Rage_MoveSpeed(client, slot);
	}
	return;
}

public MoveSpeed_Prethink(client)
{
	if(!DSM_SpeedOverride[client])
	{
		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", NewSpeed[client]);
	}
	SpeedTick(client, GetEngineTime());
}

public SpeedTick(client, Float:gameTime)
{
	// Move Speed
	if(gameTime>=NewSpeedDuration[client])
	{
		if(DSM_SpeedOverride[client])
		{
			DSM_SpeedOverride[client]=false;
		}

		new boss=FF2_GetBossIndex(client);
		if(boss>=0)
		{
			new String:snd[PLATFORM_MAX_PATH];
			if(FF2_FindSound("movespeed finish", snd, sizeof(snd), boss))
			{
				EmitSoundToAll(snd, client);
				EmitSoundToAll(snd, client);
			}
		}

		NewSpeed[client]=0.0;
		NewSpeedDuration[client]=INACTIVE;
		TF2Util_UpdatePlayerSpeed(client, true);
		SDKUnhook(client, SDKHook_PreThink, MoveSpeed_Prethink);
	}
}

stock bool:IsValidClient(client, bool:isPlayerAlive=false)
{
	if (client <= 0 || client > MaxClients)
		return false;
	if(!isPlayerAlive)
		return IsClientInGame(client);
	return IsClientInGame(client) && IsPlayerAlive(client);
}
