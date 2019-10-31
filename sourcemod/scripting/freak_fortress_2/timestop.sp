#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <freak_fortress_2>

#tryinclude <ff2_potry>
#if !defined _ff2_potry_included
	#include <freak_fortress_2_subplugin>
#endif

#define MAXENTITIES 2048

/*
	1: 지속시간
	2: 시전시간
	3: 사운드 경로 (시전)
	4: 사운드 경로 (발동)
*/
public Plugin myinfo=
{
	name="Freak Fortress 2: Time Stop",
	author="Nopied",
	description="",
	version="wat.",
};

#define THIS_PLUGIN_NAME "timestop"

int g_nEntityMovetype[MAXENTITIES+1];

float g_flTimeStop = -1.0;
float g_flTimeStopCooling = -1.0;

int g_hTimeStopParent;
float g_flTimeStopDamage[MAXPLAYERS + 1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, err_max)
{
	// TODO: 개별 플러그인화
	return APLRes_Success;
}

#if defined _ff2_potry_included
	public void OnPluginStart()
#else
	public void OnPluginStart2()
#endif
{
	HookEvent("player_spawn", OnPlayerSpawn);
	HookEvent("teamplay_round_win", OnRoundEnd);

	#if defined _ff2_potry_included
		FF2_RegisterSubplugin(THIS_PLUGIN_NAME);
	#endif
}

public Action OnRoundEnd(Handle event, const char[] name, bool dont)
{
	if(g_flTimeStop > GetGameTime() || g_flTimeStopCooling > GetGameTime())
	{
		g_flTimeStopCooling = -1.0;
		g_flTimeStop = -1.0;
		DisableTimeStop();
	}
}

public Action OnPlayerSpawn(Handle event, const char[] name, bool dont)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if(FF2_GetRoundState() != 1)    return Plugin_Continue;

	if(g_flTimeStop > GetGameTime())
	{
		g_nEntityMovetype[client] = view_as<int>(GetEntityMoveType(client));
		SetEntityMoveType(client, MOVETYPE_NONE);

		TF2_AddCondition(client, TFCond_HalloweenKartNoTurn, -1.0);

		DisableAnimation(client);

		SetEntPropFloat(client, Prop_Send, "m_flNextAttack", GetGameTime() + 10000.0);

		int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if(IsValidEntity(weapon))
			DisableAnimation(weapon);

		SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	}

	return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(g_flTimeStop != -1.0 && g_flTimeStop > GetGameTime() && g_flTimeStopCooling == -1.0)
	{
		SDKHook(entity, SDKHook_SpawnPost, OnEntitySpawnOnTimeStop);
	}
}

public Action OnEntitySpawnOnTimeStop(int entity)
{
	if(IsValidEntity(entity))
	{
		g_nEntityMovetype[entity] = view_as<int>(GetEntityMoveType(entity));
		SetEntityMoveType(entity, MOVETYPE_NONE);

		DisableAnimation(entity);
	}
}

public TF2_OnConditionAdded(client, TFCond:condition)
{
	if(g_flTimeStop != -1.0 && condition == TFCond_Taunting)
	{
		TF2_RemoveCondition(client, condition);
	}
}

#if defined _ff2_potry_included
public Action FF2_PreAbility(int boss, const char[] pluginName, const char[] abilityName, int slot)
#else
public FF2_PreAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, bool &enabled)
#endif
{
	if(!strcmp(abilityName, "timestop"))
	{
		if(g_flTimeStopCooling != -1.0 || g_flTimeStop != -1.0) {

			#if defined _ff2_potry_included
				return Plugin_Handled;
			#else
				enabled = false;
			#endif
		}
	}

	#if defined _ff2_potry_included
		return Plugin_Continue;
	#else
		return;
	#endif
}

#if defined _ff2_potry_included
public void FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status)
#else
public Action FF2_OnAbility2(int boss, const char[] pluginName, const char[] abilityName, int status)
#endif
{
    if(!strcmp(abilityName, "timestop"))
	{
		Rage_TimeStop(boss);
	}
}

void Rage_TimeStop(int boss)
{
    // float abilityDuration = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, "timestop", 1, 10.0);
	if(g_flTimeStopCooling <= 0.0)
	{
		for(int client = 1; client <= MaxClients; client++)
		{
			g_flTimeStopDamage[client] = 0.0;
		}
	}

	char sound[PLATFORM_MAX_PATH];

	#if defined _ff2_potry_included
		g_flTimeStopCooling = GetGameTime() + FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, "timestop", "cooldown", 5.0);
		g_flTimeStop = GetGameTime()+FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, "timestop", "duration", 10.0);
		FF2_GetAbilityArgumentString(boss, THIS_PLUGIN_NAME, "timestop", "warning sound path", sound, sizeof(sound));
	#else
		g_flTimeStopCooling = GetGameTime() + FF2_GetAbilityArgumentFloat(boss, this_plugin_name, "timestop", 1, 5.0);
		g_flTimeStop = GetGameTime()+FF2_GetAbilityArgumentFloat(boss, this_plugin_name, "timestop", 2, 10.0);
		FF2_GetAbilityArgumentString(boss, this_plugin_name, "timestop", 3, sound, sizeof(sound));
	#endif

	SDKHook(GetClientOfUserId(FF2_GetBossUserId(boss)), SDKHook_PreThinkPost, RageTimer);
	SDKUnhook(GetClientOfUserId(FF2_GetBossUserId(boss)), SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(GetClientOfUserId(FF2_GetBossUserId(boss)), SDKHook_OnTakeDamage, OnTakeDamage);

	if(sound[0] != '\0')
	{
		EmitSoundToAll(sound);
	}
}


public void RageTimer(int client)
{
	if(FF2_GetRoundState() != 1)
	{
		if(g_flTimeStopCooling != -1.0)
		{
			g_flTimeStopCooling = -1.0;
		}
		else if(g_flTimeStop != -1.0)
		{
			g_flTimeStop = -1.0;
			DisableTimeStop();
		}

		SDKUnhook(client, SDKHook_PreThinkPost, RageTimer);
	}

	int glowIndex;
	for(int target = 1; target <= MaxClients; target++)
	{
		if(!IsClientInGame(target) || !IsPlayerAlive(target)) continue;

		// int currentHP = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, target);
		int currentHP = GetEntProp(target, Prop_Send, "m_iHealth");
		int color[4] = {255, 255, 0, 255}, totalColor, temp;

		float ratio = g_flTimeStopDamage[target] * 100.0 / float(currentHP);
		totalColor = (temp = 510 - RoundFloat(5.1 * ratio)) > 0 ? temp : 0;
		color[0] = totalColor <= 255 ? ((temp = (totalColor - 255) * -1) > 255 ? 0 : temp) : 0;
		color[1] = totalColor < 255 ? 0 : totalColor - 255;

		if((glowIndex = TF2_HasGlow(target)) != -1 && IsValidEntity(glowIndex)) {
			TF2_SetGlowColor(glowIndex, color);
		}
	}

	if(g_flTimeStopCooling <= GetGameTime() && g_flTimeStopCooling != -1.0)
	{
		EnableTimeStop(client);
		g_flTimeStopCooling = -1.0;

	}
	else if(g_flTimeStop <= GetGameTime() && g_flTimeStop != -1.0)
	{
		g_flTimeStop = -1.0;
		DisableTimeStop();
		SDKUnhook(client, SDKHook_PreThinkPost, RageTimer);
	}
}

public Action OnTakeDamage(int client, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(IsValidClient(client) && IsValidClient(attacker))
	{
		if(TF2_IsPlayerInCondition(client, TFCond_Ubercharged))
			return Plugin_Continue;

		int boss = IsBoss(attacker);
		#if defined _ff2_potry_included
			float multiplier = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, "timestop", "damage multiplier", 1.0);
		#else
			float multiplier = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, "timestop", 5, 1.0);
		#endif

		if(g_flTimeStop != -1.0 && client != attacker)
		{
			g_flTimeStopDamage[client] += damage * multiplier;
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

void EnableTimeStop(int client)
{
	int boss = FF2_GetBossIndex(client);
	g_hTimeStopParent = client;
	// float abilityDuration = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, "timestop", 1, 10.0);
	char classname[60];

	for(int entity=1; entity <= MAXENTITIES; entity++)
	{
		if(entity == client)
			continue;

		if(IsValidClient(entity))
		{
			SetClientOverlay(entity, "debug/yuv");
			if(IsPlayerAlive(entity))
			{
				TF2_AddCondition(entity, TFCond_HalloweenKartNoTurn, -1.0);

				DisableAnimation(entity);

				SetEntPropFloat(entity, Prop_Send, "m_flNextAttack", GetGameTime() + 10000.0);

				int weapon = GetEntPropEnt(entity, Prop_Send, "m_hActiveWeapon");
				if(IsValidEntity(weapon))
					DisableAnimation(weapon);

				SDKUnhook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
				SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);

				int glowIndex;
				if((glowIndex = TF2_HasGlow(entity)) == -1 || !IsValidEntity(glowIndex)) {
					glowIndex = TF2_CreateGlow(entity);
				}
			}
		}

		if(IsValidEntity(entity))
		{
			g_nEntityMovetype[entity] = view_as<int>(GetEntityMoveType(entity));
			SetEntityMoveType(entity, MOVETYPE_NONE);
			GetEntityClassname(entity, classname, sizeof(classname));

			if(!StrContains(classname, "obj_"))
			{
				if(TF2_GetObjectType(entity) == TFObject_Dispenser
				|| TF2_GetObjectType(entity) == TFObject_Teleporter
				|| TF2_GetObjectType(entity) == TFObject_Sentry)
				{
					SetEntProp(entity, Prop_Send, "m_bDisabled", 1);
					DisableAnimation(entity);
				}
			}
		}
	}

	if(boss != -1)
	{
		char sound[PLATFORM_MAX_PATH];
		#if defined _ff2_potry_included
			FF2_GetAbilityArgumentString(boss, THIS_PLUGIN_NAME, "timestop", "on sound", sound, sizeof(sound));
		#else
			FF2_GetAbilityArgumentString(boss, this_plugin_name, "timestop", 4, sound, sizeof(sound));
		#endif

		if(sound[0] != '\0')
		{
			EmitSoundToAll(sound);
		}
	}
}

void DisableTimeStop()
{
	char classname[60];

	for(int entity = 1; entity <= MAXENTITIES; entity++)
	{
		if(entity == g_hTimeStopParent)
		continue;

		if(IsValidClient(entity))
		{
			if(TF2_IsPlayerInCondition(entity, TFCond_HalloweenKartNoTurn))
			{
				TF2_RemoveCondition(entity, TFCond_HalloweenKartNoTurn);
			}

			SetClientOverlay(entity, "");
			EnableAnimation(entity);

			SetEntPropFloat(entity, Prop_Send, "m_flNextAttack", GetGameTime());
			SDKUnhook(entity, SDKHook_OnTakeDamage, OnTakeDamage);

			if(IsPlayerAlive(entity))
			{
				int weapon = GetEntPropEnt(entity, Prop_Send, "m_hActiveWeapon");
				if(IsValidEntity(weapon))
					EnableAnimation(weapon);

				SDKHooks_TakeDamage(entity, g_hTimeStopParent, g_hTimeStopParent, g_flTimeStopDamage[entity], DMG_GENERIC, -1);
				TF2_RemoveCondition(entity, TFCond_MarkedForDeath);

				int glowIndex = -1;
				if((glowIndex = TF2_HasGlow(entity)) != -1 && IsValidEntity(glowIndex)) {
					AcceptEntityInput(glowIndex, "Disable");
					RemoveEntity(glowIndex);
				}
			}

			g_flTimeStopDamage[entity] = 0.0;
		}

		if(IsValidEntity(entity))
		{
			GetEntityClassname(entity, classname, sizeof(classname));
			SetEntityMoveType(entity, view_as<MoveType>(g_nEntityMovetype[entity]));

			if(!StrContains(classname, "obj_"))
			{
				if(TF2_GetObjectType(entity) == TFObject_Dispenser
				|| TF2_GetObjectType(entity) == TFObject_Teleporter
				|| TF2_GetObjectType(entity) == TFObject_Sentry)
				{
					SetEntProp(entity, Prop_Send, "m_bDisabled", 0);

					EnableAnimation(entity);
				}
			}
			else if(!StrContains(classname, "tf_projectile_", false) || IsValidClient(entity))
			{
				continue;
			}
			else
			{
				float tempVelo[3];
				tempVelo[2] = 0.1;
				NormalizeVector(tempVelo, tempVelo);
				TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, tempVelo);
			}
		}

		/*
		TFObject_Dispenser
		TFObject_Teleporter
		TFObject_Sentry
		*/
	}

	g_hTimeStopParent = -1;
}

stock int TF2_CreateGlow(int iEnt, int colors[4] = {255, 255, 255, 255})
{
	char strName[126], strClass[64];
	GetEntityClassname(iEnt, strClass, sizeof(strClass));
	Format(strName, sizeof(strName), "%s%i", strClass, iEnt);
	DispatchKeyValue(iEnt, "targetname", strName);

	char strGlowColor[18];
	Format(strGlowColor, sizeof(strGlowColor), "%i %i %i %i", colors[0], colors[1], colors[2], colors[3]);

	int ent = CreateEntityByName("tf_glow");
	DispatchKeyValue(ent, "targetname", "RainbowGlow");
	DispatchKeyValue(ent, "target", strName);
	DispatchKeyValue(ent, "Mode", "0");
	DispatchKeyValue(ent, "GlowColor", strGlowColor);
	DispatchSpawn(ent);

	AcceptEntityInput(ent, "Enable");

	return ent;
}

stock int TF2_HasGlow(int iEnt)
{
	int index = -1;
	while ((index = FindEntityByClassname(index, "tf_glow")) != -1)
	{
		if (GetEntPropEnt(index, Prop_Send, "m_hTarget") == iEnt)
		{
			return index;
		}
	}

	return -1;
}

stock void TF2_SetGlowColor(int ent, int colors[4])
{
	SetVariantColor(colors);
	AcceptEntityInput(ent, "SetGlowColor");
}

void EnableAnimation(int entity)
{
	if(HasEntProp(entity, Prop_Send, "m_bIsPlayerSimulated"))
		SetEntProp(entity, Prop_Send, "m_bIsPlayerSimulated", 1);
	if(HasEntProp(entity, Prop_Send, "m_bAnimatedEveryTick"))
		SetEntProp(entity, Prop_Send, "m_bAnimatedEveryTick", 1);
	if(HasEntProp(entity, Prop_Send, "m_bSimulatedEveryTick"))
		SetEntProp(entity, Prop_Send, "m_bSimulatedEveryTick", 1);
	if(HasEntProp(entity, Prop_Send, "m_bClientSideAnimation"))
		SetEntProp(entity, Prop_Send, "m_bClientSideAnimation", 1);
	if(HasEntProp(entity, Prop_Send, "m_bClientSideFrameReset"))
		SetEntProp(entity, Prop_Send, "m_bClientSideFrameReset", 0);
}

void DisableAnimation(int entity)
{
	if(HasEntProp(entity, Prop_Send, "m_bIsPlayerSimulated"))
		SetEntProp(entity, Prop_Send, "m_bIsPlayerSimulated", 0);
	if(HasEntProp(entity, Prop_Send, "m_bSimulatedEveryTick"))
		SetEntProp(entity, Prop_Send, "m_bSimulatedEveryTick", 0);
	if(HasEntProp(entity, Prop_Send, "m_bAnimatedEveryTick"))
		SetEntProp(entity, Prop_Send, "m_bAnimatedEveryTick", 0);
	if(HasEntProp(entity, Prop_Send, "m_bClientSideAnimation"))
		SetEntProp(entity, Prop_Send, "m_bClientSideAnimation", 0);
	if(HasEntProp(entity, Prop_Send, "m_bClientSideFrameReset"))
		SetEntProp(entity, Prop_Send, "m_bClientSideFrameReset", 1);
}

stock bool IsBoss(int client)
{
	return FF2_GetBossIndex(client) != client;
}

stock bool IsValidClient(int client)
{
    return (0 < client && client <= MaxClients && IsClientInGame(client));
}

void SetClientOverlay(int client, char[] strOverlay)
{
	new iFlags = GetCommandFlags("r_screenoverlay") & (~FCVAR_CHEAT);
	SetCommandFlags("r_screenoverlay", iFlags);

	ClientCommand(client, "r_screenoverlay \"%s\"", strOverlay);
}
