#pragma semicolon 1

#include <tf2>
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <freak_fortress_2>
// #include <ff2_modules/general>

#pragma newdecls required

#define VERSION_NUMBER "1.06"

public Plugin myinfo = {
	name = "Freak Fortress 2: Fog Effects",
	description = "Fog Effects, Darken Has Come", //"フォグ効果" Sorry Shadow. We really need something universal that everyone can understand
	author = "Koishi, J0BL3SS (Forked by Nopied◎)",
	version = VERSION_NUMBER,
};

#define INACTIVE 100000000.0

int envFog=-1;
float fogDuration[MAXPLAYERS+1]={INACTIVE, ...};
bool IsFogActive;

#define THIS_PLUGIN_NAME 		"ff2_fog"

public void OnPluginStart()
{
	HookEvent("arena_round_start", Event_RoundStart);
	HookEvent("teamplay_round_active", Event_RoundStart); // for non-arena maps

	HookEvent("arena_win_panel", Event_RoundEnd);
	HookEvent("teamplay_round_win", Event_RoundEnd); // for non-arena maps

	HookEvent("player_spawn", Event_PlayerSpawn);	// reanimator respawn - no fog bug fix

	PrepareAbilities();
	FF2_RegisterSubplugin(THIS_PLUGIN_NAME);
}

// reanimator respawn - no fog bug fix
public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int UserIdx = GetEventInt(event, "userid");
	int client = GetClientOfUserId(UserIdx);

	if(IsFogActive)
	{
		for(int i=1;i<=MaxClients;i++)
		{
			int boss=FF2_GetBossIndex(i);
			if(boss>=0)
			{
				if(FF2_HasAbility(boss, THIS_PLUGIN_NAME, "fog_fx"))
				{
					// effect; 0=all,1=non-boss team,2=everyone expect boss(s)
					int effectboss = FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, "fog_fx", "effect", 0);
					switch(effectboss)
					{
						case 0:
						{
							SetVariantString("MyFog");
							AcceptEntityInput(client, "SetFogController");
						}
						case 1:
						{
							if(GetClientTeam(client) != view_as<int>(FF2_GetBossTeam()))
							{
								SetVariantString("MyFog");
								AcceptEntityInput(client, "SetFogController");
							}
						}
						case 2:
						{
							if(FF2_GetBossIndex(client) != -1)
							{
								SetVariantString("MyFog");
								AcceptEntityInput(client, "SetFogController");
							}
						}
					}
				}
				if(FF2_HasAbility(boss, THIS_PLUGIN_NAME, "rage_fog_fx"))
				{
					int effectboss= FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, "rage_fog_fx", "effect", 0);
					switch(effectboss)
					{
						case 0:
						{
							SetVariantString("MyFog");
							AcceptEntityInput(client, "SetFogController");
						}
						case 1:
						{
							if(GetClientTeam(client) != view_as<int>(FF2_GetBossTeam()))
							{
								SetVariantString("MyFog");
								AcceptEntityInput(client, "SetFogController");
							}
						}
						case 2:
						{
							if(FF2_GetBossIndex(client) != -1)
							{
								SetVariantString("MyFog");
								AcceptEntityInput(client, "SetFogController");
							}
						}
					}
				}
			}
		}
	}
}

// reanimator respawn - no fog bug fix
public void OnClientPutInServer(int client)
{
	if(IsFogActive)
	{
		for(int i=1;i<=MaxClients;i++)
		{
			int boss=FF2_GetBossIndex(i);
			if(boss>=0)
			{
				if(FF2_HasAbility(boss, THIS_PLUGIN_NAME, "fog_fx"))
				{
					int effectboss = FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, "fog_fx", "effect", 0);
					switch(effectboss)
					{
						case 0:
						{
							SetVariantString("MyFog");
							AcceptEntityInput(client, "SetFogController");
						}
						case 1:
						{
							if(GetClientTeam(client) != view_as<int>(FF2_GetBossTeam()))
							{
								SetVariantString("MyFog");
								AcceptEntityInput(client, "SetFogController");
							}
						}
						case 2:
						{
							if(FF2_GetBossIndex(client) != -1)
							{
								SetVariantString("MyFog");
								AcceptEntityInput(client, "SetFogController");
							}
						}
					}
				}
				if(FF2_HasAbility(boss, THIS_PLUGIN_NAME, "rage_fog_fx"))
				{
					int effectboss= FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, "rage_fog_fx", "effect", 0);
					switch(effectboss)
					{
						case 0:
						{
							SetVariantString("MyFog");
							AcceptEntityInput(client, "SetFogController");
						}
						case 1:
						{
							if(GetClientTeam(client) != view_as<int>(FF2_GetBossTeam()))
							{
								SetVariantString("MyFog");
								AcceptEntityInput(client, "SetFogController");
							}
						}
						case 2:
						{
							if(FF2_GetBossIndex(client) != -1)
							{
								SetVariantString("MyFog");
								AcceptEntityInput(client, "SetFogController");
							}
						}
					}
				}
			}
		}
	}
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	PrepareAbilities();
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	KillFog(envFog);

	for(int client=MaxClients;client;client--)
	{
		if(client<=0||client>MaxClients||!IsClientInGame(client))
		{
			continue;
		}

		if(fogDuration[client]!=INACTIVE)
		{
			fogDuration[client]=INACTIVE;
			SDKUnhook(client, SDKHook_PreThinkPost, FogTimer);
		}
	}
	envFog=-1;

}

public void PrepareAbilities()
{
	for(int client=MaxClients;client;client--)
	{
		if(client<=0||client>MaxClients||!IsClientInGame(client))
		{
			continue;
		}

		fogDuration[client]=INACTIVE;

		int boss=FF2_GetBossIndex(client);
		if(boss>=0)
		{
			if(FF2_HasAbility(boss, THIS_PLUGIN_NAME, "fog_fx"))
			{
				int fogcolor[3][3];
				// fog color
				fogcolor[0][0]=FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, "fog_fx", "color 1 red", 255);
				fogcolor[0][1]=FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, "fog_fx", "color 1 green", 255);
				fogcolor[0][2]=FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, "fog_fx", "color 1 blue", 255);
				// fog color 2
				fogcolor[1][0]=FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, "fog_fx", "color 2 red", 255);
				fogcolor[1][1]=FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, "fog_fx", "color 2 green", 255);
				fogcolor[1][2]=FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, "fog_fx", "color 2 blue", 255);
				// fog start
				float fogstart=FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, "fog_fx", "start distance", 64.0);
				// fog end
				float fogend=FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, "fog_fx", "end distance", 384.0);
				// fog density
				float fogdensity=FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, "fog_fx", "density", 1.0);

				int effectboss = FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, "fog_fx", "effect", 0);

				envFog = StartFog(FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, "fog_fx", "blend", 0), fogcolor[0], fogcolor[1], fogstart, fogend, fogdensity);

				switch(effectboss)
				{
					case 0:
					{
						for (int i = 1; i <= MaxClients; i++)
						{
							if(IsClientInGame(i))
							{
								SetVariantString("MyFog");
								AcceptEntityInput(i, "SetFogController");
							}
						}
					}
					case 1:
					{
						for (int i = 1; i <= MaxClients; i++)
						{
							if(IsClientInGame(i) && GetClientTeam(i) != view_as<int>(FF2_GetBossTeam()))
							{
								SetVariantString("MyFog");
								AcceptEntityInput(i, "SetFogController");
							}
						}
					}
					case 2:
					{
						for (int i = 1; i <= MaxClients; i++)
						{
							if(IsClientInGame(i) && FF2_GetBossIndex(i) == -1)
							{
								SetVariantString("MyFog");
								AcceptEntityInput(i, "SetFogController");
							}
						}
					}
				}
			}
		}
	}
}

// ????? Why is this compiled?
public Action FF2_OnAbility2(int boss,const char[] plugin_name,const char[] ability_name,int status)
{
	int client=GetClientOfUserId(FF2_GetBossUserId(boss));

	if(!strcmp(ability_name, "rage_fog_fx"))
	{
		FOG_Invoke(client);
	}
	return Plugin_Continue;
}

public bool FOG_CanInvoke(int client)
{
	return true;
}

public void FOG_Invoke(int client)
{
	int fogcolor[3][3];

	int boss=FF2_GetBossIndex(client);

	// FF2_RandomSound("sound_fogeffect", sound, sizeof(sound), boss)
	// fog color
	fogcolor[0][0]=FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, "rage_fog_fx", "color 1 red", 255);
	fogcolor[0][1]=FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, "rage_fog_fx", "color 1 green", 255);
	fogcolor[0][2]=FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, "rage_fog_fx", "color 1 blue", 255);
	// fog color 2
	fogcolor[1][0]=FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, "rage_fog_fx", "color 2 red", 255);
	fogcolor[1][1]=FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, "rage_fog_fx", "color 2 green", 255);
	fogcolor[1][2]=FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, "rage_fog_fx", "color 2 blue", 255);
	// fog start
	float fogstart=FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, "rage_fog_fx", "start distance", 64.0);
	// fog end
	float fogend=FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, "rage_fog_fx", "end distance", 384.0);
	// fog density
	float fogdensity=FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, "rage_fog_fx", "density", 1.0);

	int effectboss= FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, "rage_fog_fx", "effect", 0);

	if(fogDuration[client]!=INACTIVE)
	{
		fogDuration[client]+=FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, "rage_fog_fx", "duration", 5.0);
	}
	else
	{
		envFog = StartFog(FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, "rage_fog_fx", "blend", 0), fogcolor[0], fogcolor[1], fogstart, fogend, fogdensity);
		fogDuration[client]=GetGameTime()+FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, "rage_fog_fx", "duration", 5.0);
		SDKHook(client, SDKHook_PreThinkPost, FogTimer);
	}
	switch(effectboss)
	{
		case 0:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i))
				{
					SetVariantString("MyFog");
					AcceptEntityInput(i, "SetFogController");
				}
			}
		}
		case 1:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && GetClientTeam(i) != view_as<int>(FF2_GetBossTeam()))
				{
					SetVariantString("MyFog");
					AcceptEntityInput(i, "SetFogController");
				}
			}
		}
		case 2:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && FF2_GetBossIndex(i) == -1)
				{
					SetVariantString("MyFog");
					AcceptEntityInput(i, "SetFogController");
				}
			}
		}
		default:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i))
				{
					SetVariantString("MyFog");
					AcceptEntityInput(i, "SetFogController");
				}
			}
		}
	}
}

public void FogTimer(int client)
{
	if(GetGameTime()>=fogDuration[client])
	{
		KillFog(envFog);
		fogDuration[client]=INACTIVE;
		SDKUnhook(client, SDKHook_PreThinkPost, FogTimer);
		envFog=-1;
	}
}

int StartFog(int fogblend, int fogcolor[3], int fogcolor2[3], float fogstart=64.0, float fogend=384.0, float fogdensity=1.0)
{
	int iFog = CreateEntityByName("env_fog_controller");
	char fogcolors[3][16];
	IntToString(fogblend, fogcolors[0], sizeof(fogcolors[]));
	Format(fogcolors[1], sizeof(fogcolors[]), "%i %i %i", fogcolor[0], fogcolor[1], fogcolor[2]);
	Format(fogcolors[2], sizeof(fogcolors[]), "%i %i %i", fogcolor2[0], fogcolor2[1], fogcolor2[2]);
	if(IsValidEntity(iFog))
	{
        DispatchKeyValue(iFog, "targetname", "MyFog");
        DispatchKeyValue(iFog, "fogenable", "1");
        DispatchKeyValue(iFog, "spawnflags", "1");
        DispatchKeyValue(iFog, "fogblend", fogcolors[0]);
        DispatchKeyValue(iFog, "fogcolor", fogcolors[1]);
        DispatchKeyValue(iFog, "fogcolor2", fogcolors[2]);
        DispatchKeyValueFloat(iFog, "fogstart", fogstart);
        DispatchKeyValueFloat(iFog, "fogend", fogend);
        DispatchKeyValueFloat(iFog, "fogmaxdensity", fogdensity);
        DispatchSpawn(iFog);

        AcceptEntityInput(iFog, "TurnOn");
	}
	IsFogActive = true;
	return iFog;
}

stock bool IsEntityValid(int ent)
{
	return 	IsValidEdict(ent) && ent > MaxClients;
}

stock void KillFog(int entity)
{
	if (IsEntityValid(entity))
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				SetVariantString("");
				AcceptEntityInput(i, "SetFogController");
			}
		}
		AcceptEntityInput(entity, "Kill");
		entity=-1;
		IsFogActive = false;
	}
}
