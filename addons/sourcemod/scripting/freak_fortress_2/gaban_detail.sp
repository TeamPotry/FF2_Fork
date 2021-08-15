#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <tf2items>
#include <tf2utils>
#include <tf2wearables>
#include <freak_fortress_2>

#tryinclude <ff2_potry>
#if !defined _ff2_potry_included
	#include <freak_fortress_2_subplugin>
#endif

#define PLUGIN_VERSION "20210813"

public Plugin myinfo=
{
	name="Freak Fortress 2: Gaben Abilities",
	author="Nopied",
	description="FF2: Special abilities for Gaben",
	version=PLUGIN_VERSION,
};

#define DISCOUNT_NAME		"discount"

#if defined _ff2_potry_included
	#define DISCOUNTMARK_PATH	"materials/potry/steam_sale/"
	#define PLUGIN_NAME 		"gaben detail"
#else
	#define DISCOUNTMARK_PATH	"materials/freak_fortress_2/steam_sale/"
	#define PLUGIN_NAME 		this_plugin_name

	#define FF2_GetFF2Flags		FF2_GetFF2flags
	#define FF2_SetFF2Flags		FF2_SetFF2flags
#endif

#define CARD_THROW			"card throw"

#define LOADOUT_DISABLE		"loadout disable"

#define	MAX_EDICT_BITS	12
#define	MAX_EDICTS		(1 << MAX_EDICT_BITS)

char g_strSpriteModelPath[11][PLATFORM_MAX_PATH];
int g_iSpriteModelIndex[11];
int g_iDiscountValue[MAXPLAYERS+1];
float g_flDiscountDisplayTime[MAXPLAYERS+1];

float g_flCardLifeTime[MAX_EDICTS+1];

float g_flLoadoutDisableTime[MAXPLAYERS+1];
char g_strCurrentLoadoutSoundPath[MAXPLAYERS+1][PLATFORM_MAX_PATH];


#if defined _ff2_potry_included
	public void OnPluginStart()
#else
	public void OnPluginStart2()
#endif
{
	HookEvent("arena_round_start", OnRoundStart);
	HookEvent("teamplay_round_active", OnRoundStart); // for non-arena maps

	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);

	LoadTranslations("ff2_gabe.phrases");

	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
			OnClientPostAdminCheck(client);
	}
#if defined _ff2_potry_included
	FF2_RegisterSubplugin(PLUGIN_NAME);
#endif
}

public void OnMapStart()
{
	char path[PLATFORM_MAX_PATH];

	for(int loop = 1; loop <= 10; loop++)
	{
		Format(path, PLATFORM_MAX_PATH, "%s%i", DISCOUNTMARK_PATH, loop * 10);
		Format(g_strSpriteModelPath[loop], PLATFORM_MAX_PATH, "%s.vmt", path);

		g_iSpriteModelIndex[loop] = PrecacheModel(g_strSpriteModelPath[loop]);
	}
}

public Action OnPlayerDeath(Handle event, const char[] name, bool dontBroadcast)  //For Gaben Ban
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int boss = FF2_GetBossIndex(GetClientOfUserId(GetEventInt(event, "attacker")));
	if(client && GetClientHealth(client) <= 0 && FF2_HasAbility(boss, PLUGIN_NAME, "Gaben Ban"))
	{
		PrintToChatAll("%t", "Ban by Gabe", client);
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
    SDKHook(entity, SDKHook_SpawnPost, OnProjectileSpawn);
}

public void OnProjectileSpawn(int entity)
{
    char classname[60];
    GetEntityClassname(entity, classname, sizeof(classname));

    if(StrEqual(classname, "tf_projectile_pipe"))
    {
		int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"), boss = FF2_GetBossIndex(client);
		if(IsValidClient(client)
		&& FF2_HasAbility(boss, PLUGIN_NAME, CARD_THROW))
		{
			int currentWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"), currentSlot = TFWeaponSlot_Primary;
			for(int loop = TFWeaponSlot_Primary; loop <= TFWeaponSlot_Melee; loop++)
			{
				if(currentWeapon == GetPlayerWeaponSlot(client, loop)) {
					currentSlot = loop;
					break;
				}
			}


			float origin[3], angles[3], speed;

#if defined _ff2_potry_included
			speed = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, CARD_THROW, "speed", 2000.0);
#else
			speed = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, CARD_THROW, 1, 2000.0);
#endif

			GetEntPropVector(entity, Prop_Data, "m_vecOrigin", origin);
			GetClientEyeAngles(client, angles);

			int count;
#if defined _ff2_potry_included
			char key[64];
			Format(key, sizeof(key), "slot %d card count", currentSlot);
			count = FF2_GetAbilityArgument(boss, PLUGIN_NAME, CARD_THROW, key, 3);
#else
			count = FF2_GetAbilityArgument(boss, this_plugin_name, CARD_THROW, 5+(currentSlot*100), 3);
#endif

			RemoveEntity(entity);

			CreateCard(client, origin, angles, speed, currentSlot, count);
		}
	}
}

void CreateCard(int owner, float pos[3], float angles[3], float speed, int currentSlot = TFWeaponSlot_Primary, int count = 1)
{
	int boss = FF2_GetBossIndex(owner), touchType;
	float velocity[3], degreeDiff;
	char modelPath[PLATFORM_MAX_PATH];

#if defined _ff2_potry_included
	char key[64];
	Format(key, sizeof(key), "slot %d degree diff", currentSlot);
	degreeDiff = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, CARD_THROW, key, 5.0);
	FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, CARD_THROW, "model path", modelPath, sizeof(modelPath), "");
	touchType = FF2_GetAbilityArgument(boss, PLUGIN_NAME, CARD_THROW, "touch type", 0);
#else
	degreeDiff = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, CARD_THROW, 4+(currentSlot*100), 5.0);
	FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, CARD_THROW, 3, modelPath, sizeof(modelPath));
	touchType = FF2_GetAbilityArgument(boss, PLUGIN_NAME, CARD_THROW, 6, 0);
#endif

	for(int loop = 0; loop < count; loop++)
	{
		SetRandomSeed(GetTime() + loop);

		for(int velocityLoop = 0; velocityLoop < 2; velocityLoop++)
		{
			velocity[velocityLoop] = angles[velocityLoop] + GetRandomFloat(degreeDiff * -0.5, degreeDiff * 0.5);
		}
		GetAngleVectors(velocity, velocity, NULL_VECTOR, NULL_VECTOR);
		ScaleVector(velocity, speed);

		int prop = CreateEntityByName("prop_physics_override");
		if(!IsValidEntity(prop))	return;

		SetEntityModel(prop, modelPath);
		SetEntityMoveType(prop, MOVETYPE_VPHYSICS);
		SetEntPropEnt(prop, Prop_Send, "m_hOwnerEntity", owner);

		if(touchType == 0)
		{
			SetEntProp(prop, Prop_Send, "m_CollisionGroup", 0x200);
			SetEntProp(prop, Prop_Send, "m_usSolidFlags", 512);
		}
		else
		{
			SetEntProp(prop, Prop_Send, "m_CollisionGroup", 2);
			SetEntProp(prop, Prop_Send, "m_usSolidFlags", 0x0004);
		}

		DispatchSpawn(prop);

		TeleportEntity(prop, pos, angles, velocity);
		g_flCardLifeTime[prop] = GetGameTime() + 3.0;
		SDKHook(prop, SDKHook_StartTouch, OnTouchCard);
		SDKHook(prop, SDKHook_Touch, OnTouchCard);

		CreateTimer(0.02, OnCardThink, prop, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action OnTouchCard(int prop, int other)
{
	int owner = GetEntPropEnt(prop, Prop_Send, "m_hOwnerEntity"), boss = FF2_GetBossIndex(owner), touchType;

	if(boss != -1)
	{
#if defined _ff2_potry_included
		touchType = FF2_GetAbilityArgument(boss, PLUGIN_NAME, CARD_THROW, "touch type", 0);
#else
		touchType = FF2_GetAbilityArgument(boss, PLUGIN_NAME, CARD_THROW, 6, 0);
#endif
		if(other == 0)
		{
			SDKUnhook(prop, SDKHook_StartTouch, OnTouchCard);
			SDKUnhook(prop, SDKHook_Touch, OnTouchCard);

			g_flCardLifeTime[prop] = GetGameTime() + 3.0;
			return Plugin_Continue;
		}
		else if(touchType == 0 && IsValidClient(other))
		{
			if(GetClientTeam(owner) == GetClientTeam(other))
				return Plugin_Handled;

			HitCard(owner, other, prop);
		}
	}
	return Plugin_Continue;
}

void HitCard(int owner, int target, int prop)
{
	int boss = FF2_GetBossIndex(owner), onHitSale;
	float damage;

#if defined _ff2_potry_included
			onHitSale = FF2_GetAbilityArgument(boss, PLUGIN_NAME, DISCOUNT_NAME, "on hit sale", 10);
			damage = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, CARD_THROW, "damage", 10.0);
#else
			onHitSale = FF2_GetAbilityArgument(boss, PLUGIN_NAME, DISCOUNT_NAME, 1, 10);
			damage = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, CARD_THROW, 2, 10.0);
#endif

	if(g_iDiscountValue[target] >= 100)
		if(FF2_GetBossIndex(target) == -1)
			damage = 10000.0;
		else
			damage *= 1.0 + (g_iDiscountValue[target] * 0.01);
	else
		damage *= 1.0 + (g_iDiscountValue[target] * 0.01);

	SDKHooks_TakeDamage(target, owner, owner,
		damage, DMG_DIRECT);

	AddDiscount(target, owner, onHitSale);

	SDKUnhook(prop, SDKHook_StartTouch, OnTouchCard);
	SDKUnhook(prop, SDKHook_Touch, OnTouchCard);

	g_flCardLifeTime[prop] == 0.0;
	AcceptEntityInput(prop, "Kill");
}

public Action OnCardThink(Handle timer, int prop)
{
	// LogMessage("FF2_GetRoundState = %d, g_flCardLifeTime[prop] = %.1f", FF2_GetRoundState(), g_flCardLifeTime[prop]);

	if(!IsValidEntity(prop))
		return Plugin_Stop;

	if(FF2_GetRoundState() != 1
		|| (g_flCardLifeTime[prop] == 0.0 || g_flCardLifeTime[prop] < GetGameTime()))
	{
		// 라운드가 다 끝나거나 시간이 다 된 경우
		{
			SDKUnhook(prop, SDKHook_StartTouch, OnTouchCard);
			SDKUnhook(prop, SDKHook_Touch, OnTouchCard);

			AcceptEntityInput(prop, "Kill");
		}
		g_flCardLifeTime[prop] = 0.0;

		return Plugin_Stop;
	}

	int owner = GetEntPropEnt(prop, Prop_Send, "m_hOwnerEntity"), boss = FF2_GetBossIndex(owner),
		touchType;
	float cardRange;

	#if defined _ff2_potry_included
		touchType = FF2_GetAbilityArgument(boss, PLUGIN_NAME, CARD_THROW, "touch type", 0);
		cardRange = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, CARD_THROW, "card range", 10.0);
	#else
		touchType = FF2_GetAbilityArgument(boss, PLUGIN_NAME, CARD_THROW, 6, 0);
		cardRange = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, CARD_THROW, 7, 10.0);
	#endif
	if(touchType != 1)		return Plugin_Continue;

	float pos[3], velocity[3], vecMin[3], vacMax[3], angles[3], endPos[3];
	int ent;
	GetEntPropVector(prop, Prop_Data, "m_vecOrigin", pos);
	GetEntPropVector(prop, Prop_Data, "m_vecVelocity", velocity);

	GetVectorAngles(velocity, angles);
	GetAngleVectors(angles, angles, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(angles, cardRange * 2.0);

	for(int loop = 0; loop < 3; loop++)
	{
		vecMin[loop] = cardRange * -0.5;
		vacMax[loop] = cardRange * 0.5;
	}

	AddVectors(pos, angles, endPos);
	TR_TraceHullFilter(pos, endPos, vecMin, vacMax, MASK_ALL, TraceDontHitSelf, owner);

	if(!TR_DidHit())
		return Plugin_Continue;

	ent = TR_GetEntityIndex();
	if(ent == 0 || GetClientTeam(owner) == GetClientTeam(ent))
		return Plugin_Continue;

	HitCard(owner, ent, prop);
	return Plugin_Continue;
}

public bool TraceDontHitSelf(int entity, int contentsMask, any data)
{
	return (IsValidClient(entity) && entity != data);
}

#if defined _ff2_potry_included
public void FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status)
#else
public Action FF2_OnAbility2(int boss, const char[] pluginName, const char[] abilityName, int status)
#endif
{
	if(StrEqual(abilityName, LOADOUT_DISABLE))
	{
		LoadoutDisable(boss);
	}
}

void LoadoutDisable(int boss)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss)), currentSlot;
	float duration;
	char soundPath[PLATFORM_MAX_PATH];

	#if defined _ff2_potry_included
		duration = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, LOADOUT_DISABLE, "duration", 20.0);
		FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "sound path", soundPath, PLATFORM_MAX_PATH, "");
	#else
		duration = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, LOADOUT_DISABLE, 1, 20.0);
		FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 2, soundPath, PLATFORM_MAX_PATH);
	#endif

	for(int target = 1; target <= MaxClients; target++)
	{
		int flags;
		currentSlot = TFWeaponSlot_Primary;
		if(!IsClientInGame(target) || !IsPlayerAlive(target)
			|| GetClientTeam(client) == GetClientTeam(target) || FF2_GetBossIndex(target) != -1
				|| (((flags = FF2_GetFF2Flags(target)) & FF2FLAG_CLASSTIMERDISABLED) > 0 && g_flLoadoutDisableTime[client] == 0.0))		continue;

		FF2_SetFF2Flags(target, flags | FF2FLAG_CLASSTIMERDISABLED);
		SetEntProp(target, Prop_Send, "m_bLoadoutUnavailable", 1);

		int currentWeapon = GetEntPropEnt(target, Prop_Send, "m_hActiveWeapon");
		for(int loop = TFWeaponSlot_Primary; loop <= TFWeaponSlot_Melee; loop++)
		{
			if(currentWeapon == GetPlayerWeaponSlot(target, loop)) {
				currentSlot = loop;
				break;
			}
		}

		TF2_RemoveAllWeapons(target);
		TF2_RemoveAllWearables(target);
		SwitchToDefalutWeapon(boss, target, currentSlot);

		if(g_flLoadoutDisableTime[target] <= 0.0)
		{
			if(soundPath[0] != '\0')
			{
				strcopy(g_strCurrentLoadoutSoundPath[target], PLATFORM_MAX_PATH, soundPath);
				EmitSoundToClient(target, soundPath);
				EmitSoundToClient(target, soundPath);
			}

			SDKHook(target, SDKHook_PostThink, OnLoadoutThink);
		}

		g_flLoadoutDisableTime[target] = GetGameTime() + duration;
	}
}

public void OnLoadoutThink(int client)
{
	// Wut
	if(!IsClientInGame(client))
	{
		g_flLoadoutDisableTime[client] = 0.0;
		SDKUnhook(client, SDKHook_PostThink, OnLoadoutThink);
		return;
	}

	if(!IsPlayerAlive(client) || g_flLoadoutDisableTime[client] == 0.0 || g_flLoadoutDisableTime[client] < GetGameTime())
	{
		g_flLoadoutDisableTime[client] = 0.0;
		SetEntProp(client, Prop_Send, "m_bLoadoutUnavailable", 0);

		if(IsPlayerAlive(client))
		{
			TF2_RegeneratePlayer(client);
		}

		int flags = FF2_GetFF2Flags(client);
		FF2_SetFF2Flags(client, flags & ~FF2FLAG_CLASSTIMERDISABLED);
		SDKUnhook(client, SDKHook_PostThink, OnLoadoutThink);

		StopSound(client, 0, g_strCurrentLoadoutSoundPath[client]);
		StopSound(client, 0, g_strCurrentLoadoutSoundPath[client]);
		return;
	}

	SetGlobalTransTarget(client);
	PrintCenterText(client, "%t", "Loadout Unavailable", RoundToCeil(g_flLoadoutDisableTime[client] - GetGameTime()));
}

void SwitchToDefalutWeapon(int boss, int client, int currentSlot = TFWeaponSlot_Primary)
{
	TFClassType class = TF2_GetPlayerClass(client);
	char attribs[6][128];
	int weapon;

	switch(class)
	{
		case TFClass_Scout:
		{
#if defined _ff2_potry_included
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "scout 0", attribs[TFWeaponSlot_Primary], 128, "");
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "scout 1", attribs[TFWeaponSlot_Secondary], 128, "");
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "scout 2", attribs[TFWeaponSlot_Melee], 128, "");
#else
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 11, attribs[TFWeaponSlot_Primary], 128);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 12, attribs[TFWeaponSlot_Secondary], 128);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 13, attribs[TFWeaponSlot_Melee], 128);
#endif
			SpawnWeapon(client, "tf_weapon_scattergun", 200, 1, 0, attribs[TFWeaponSlot_Primary]);
			SpawnWeapon(client, "tf_weapon_pistol", 209, 1, 0, attribs[TFWeaponSlot_Secondary]);
			SpawnWeapon(client, "tf_weapon_bat", 190, 1, 0, attribs[TFWeaponSlot_Melee]);
		}
		case TFClass_Soldier:
		{
#if defined _ff2_potry_included
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "soldier 0", attribs[TFWeaponSlot_Primary], 128, "");
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "soldier 1", attribs[TFWeaponSlot_Secondary], 128, "");
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "soldier 2", attribs[TFWeaponSlot_Melee], 128, "");
#else
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 31, attribs[TFWeaponSlot_Primary], 128);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 32, attribs[TFWeaponSlot_Secondary], 128);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 33, attribs[TFWeaponSlot_Melee], 128);
#endif
			SpawnWeapon(client, "tf_weapon_rocketlauncher", 205, 1, 0, attribs[TFWeaponSlot_Primary]);
			SpawnWeapon(client, "tf_weapon_shotgun_soldier", 199, 1, 0, attribs[TFWeaponSlot_Secondary]);
			SpawnWeapon(client, "tf_weapon_shovel", 196, 1, 0, attribs[TFWeaponSlot_Melee]);
		}
		case TFClass_Pyro:
		{
#if defined _ff2_potry_included
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "pyro 0", attribs[TFWeaponSlot_Primary], 128, "");
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "pyro 1", attribs[TFWeaponSlot_Secondary], 128, "");
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "pyro 2", attribs[TFWeaponSlot_Melee], 128, "");
#else
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 71, attribs[TFWeaponSlot_Primary], 128);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 72, attribs[TFWeaponSlot_Secondary], 128);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 73, attribs[TFWeaponSlot_Melee], 128);
#endif
			SpawnWeapon(client, "tf_weapon_flamethrower", 208, 1, 0, attribs[TFWeaponSlot_Primary]);
			SpawnWeapon(client, "tf_weapon_shotgun_pyro", 199, 1, 0, attribs[TFWeaponSlot_Secondary]);
			SpawnWeapon(client, "tf_weapon_fireaxe", 192, 1, 0, attribs[TFWeaponSlot_Melee]);
		}
		case TFClass_DemoMan:
		{
#if defined _ff2_potry_included
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "demoman 0", attribs[TFWeaponSlot_Primary], 128, "");
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "demoman 1", attribs[TFWeaponSlot_Secondary], 128, "");
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "demoman 2", attribs[TFWeaponSlot_Melee], 128, "");
#else
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 41, attribs[TFWeaponSlot_Primary], 128);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 42, attribs[TFWeaponSlot_Secondary], 128);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 43, attribs[TFWeaponSlot_Melee], 128);
#endif
			SpawnWeapon(client, "tf_weapon_grenadelauncher", 206, 1, 0, attribs[TFWeaponSlot_Primary]);
			SpawnWeapon(client, "tf_weapon_pipebomblauncher", 207, 1, 0, attribs[TFWeaponSlot_Secondary]);
			SpawnWeapon(client, "tf_weapon_bottle", 191, 1, 0, attribs[TFWeaponSlot_Melee]);
		}
		case TFClass_Heavy:
		{
#if defined _ff2_potry_included
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "heavy 0", attribs[TFWeaponSlot_Primary], 128, "");
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "heavy 1", attribs[TFWeaponSlot_Secondary], 128, "");
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "heavy 2", attribs[TFWeaponSlot_Melee], 128, "");
#else
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 61, attribs[TFWeaponSlot_Primary], 128);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 62, attribs[TFWeaponSlot_Secondary], 128);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 63, attribs[TFWeaponSlot_Melee], 128);
#endif
			SpawnWeapon(client, "tf_weapon_minigun", 202, 1, 0, attribs[TFWeaponSlot_Primary]);
			SpawnWeapon(client, "tf_weapon_shotgun_hwg", 199, 1, 0, attribs[TFWeaponSlot_Secondary]);
			SpawnWeapon(client, "tf_weapon_fists", 195, 1, 0, attribs[TFWeaponSlot_Melee]);
		}
		case TFClass_Engineer:
		{
#if defined _ff2_potry_included
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "engineer 0", attribs[TFWeaponSlot_Primary], 128, "");
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "engineer 1", attribs[TFWeaponSlot_Secondary], 128, "");
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "engineer 2", attribs[TFWeaponSlot_Melee], 128, "");
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "engineer 3", attribs[TFWeaponSlot_Grenade], 128, "");
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "engineer 4", attribs[TFWeaponSlot_Building], 128, "");
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "engineer 5", attribs[TFWeaponSlot_PDA], 128, "");
#else
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 91, attribs[TFWeaponSlot_Primary], 128);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 92, attribs[TFWeaponSlot_Secondary], 128);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 93, attribs[TFWeaponSlot_Melee], 128);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 94, attribs[TFWeaponSlot_Grenade], 128);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 95, attribs[TFWeaponSlot_Building], 128);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 96, attribs[TFWeaponSlot_PDA], 128);
#endif
			SpawnWeapon(client, "tf_weapon_shotgun_primary", 199, 1, 0, attribs[TFWeaponSlot_Primary]);
			SpawnWeapon(client, "tf_weapon_pistol", 209, 1, 0, attribs[TFWeaponSlot_Secondary]);
			SpawnWeapon(client, "tf_weapon_wrench", 197, 1, 0, attribs[TFWeaponSlot_Melee]);
			SpawnWeapon(client, "tf_weapon_pda_engineer_build", 737, 1, 0, attribs[TFWeaponSlot_Building]);
			SpawnWeapon(client, "tf_weapon_pda_engineer_destroy", 26, 1, 0, attribs[TFWeaponSlot_PDA]);
			weapon = SpawnWeapon(client, "tf_weapon_builder", 28, 1, 0, attribs[TFWeaponSlot_Grenade]);

			SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 1, _, 0);
			SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 1, _, 1);
			SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 1, _, 2);
			SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 3);
		}
		case TFClass_Medic:
		{
#if defined _ff2_potry_included
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "medic 0", attribs[TFWeaponSlot_Primary], 128, "");
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "medic 1", attribs[TFWeaponSlot_Secondary], 128, "");
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "medic 2", attribs[TFWeaponSlot_Melee], 128, "");
#else
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 51, attribs[TFWeaponSlot_Primary], 128);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 52, attribs[TFWeaponSlot_Secondary], 128);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 53, attribs[TFWeaponSlot_Melee], 128);
#endif
			SpawnWeapon(client, "tf_weapon_syringegun_medic", 204, 1, 0, attribs[TFWeaponSlot_Primary]);
			SpawnWeapon(client, "tf_weapon_medigun", 211, 1, 0, attribs[TFWeaponSlot_Secondary]);
			SpawnWeapon(client, "tf_weapon_bonesaw", 198, 1, 0, attribs[TFWeaponSlot_Melee]);
		}
		case TFClass_Sniper:
		{
#if defined _ff2_potry_included
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "sniper 0", attribs[TFWeaponSlot_Primary], 128, "");
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "sniper 1", attribs[TFWeaponSlot_Secondary], 128, "");
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "sniper 2", attribs[TFWeaponSlot_Melee], 128, "");
#else
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 21, attribs[TFWeaponSlot_Primary], 128);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 22, attribs[TFWeaponSlot_Secondary], 128);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 23, attribs[TFWeaponSlot_Melee], 128);
#endif
			SpawnWeapon(client, "tf_weapon_sniperrifle", 201, 1, 0, attribs[TFWeaponSlot_Primary]);
			SpawnWeapon(client, "tf_weapon_smg", 203, 1, 0, attribs[TFWeaponSlot_Secondary]);
			SpawnWeapon(client, "tf_weapon_club", 193, 1, 0, attribs[TFWeaponSlot_Melee]);
		}
		case TFClass_Spy:
		{
#if defined _ff2_potry_included
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "spy 0", attribs[TFWeaponSlot_Primary], 128, "");
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "spy 1", attribs[TFWeaponSlot_Secondary], 128, "");
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "spy 2", attribs[TFWeaponSlot_Melee], 128, "");
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "spy 3", attribs[TFWeaponSlot_Grenade], 128, "");
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "spy 4", attribs[TFWeaponSlot_Building], 128, "");
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, "spy 5", attribs[TFWeaponSlot_PDA], 128, "");
#else
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 81, attribs[TFWeaponSlot_Primary], 128);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 82, attribs[TFWeaponSlot_Secondary], 128);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 83, attribs[TFWeaponSlot_Melee], 128);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 84, attribs[TFWeaponSlot_Grenade], 128);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, LOADOUT_DISABLE, 85, attribs[TFWeaponSlot_Building], 128);
#endif
			SpawnWeapon(client, "tf_weapon_revolver", 210, 1, 0, attribs[TFWeaponSlot_Primary]);
			weapon = SpawnWeapon(client, "tf_weapon_builder", 736, 1, 0, attribs[TFWeaponSlot_Secondary]);

			SetEntProp(weapon, Prop_Send, "m_iObjectType", 3);
			SetEntProp(weapon, Prop_Data, "m_iSubType", 3);
			SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 0);
			SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 1);
			SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 2);
			SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 1, _, 3);

			SpawnWeapon(client, "tf_weapon_knife", 194, 1, 0, attribs[TFWeaponSlot_Melee]);
			SpawnWeapon(client, "tf_weapon_pda_spy", 27, 1, 0, attribs[TFWeaponSlot_Grenade]);
			SpawnWeapon(client, "tf_weapon_invis", 212, 1, 0, attribs[TFWeaponSlot_Building]);
		}
	}

	weapon = GetPlayerWeaponSlot(client, currentSlot);
	if(IsValidEntity(weapon))
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for(int client = 1; client <= MaxClients; client++)
	{
		g_iDiscountValue[client] = 0;
		g_flLoadoutDisableTime[client] = 0.0;
		g_flDiscountDisplayTime[client] = 0.0;
	}
	for(int loop = 0; loop <= MAX_EDICTS; loop++)
	{
		g_flCardLifeTime[loop] = 0.0;
	}
}

public void OnClientPostAdminCheck(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_PostThink, OnDiscountThink);
}

public void OnDiscountThink(int client)
{
	if(FF2_GetRoundState() != 1
		|| !IsClientInGame(client) || !IsPlayerAlive(client) || g_iDiscountValue[client] <= 0) 	return;

	if(GetGameTime() > g_flDiscountDisplayTime[client])
	{
		g_flDiscountDisplayTime[client] = GetGameTime() + 0.1;

		if(!TF2_IsPlayerInCondition(client, TFCond_Cloaked)
		 	&& !TF2_IsPlayerInCondition(client, TFCond_Stealthed))
			UpdateSaleSprite(client);
	}
}

public Action OnTakeDamage(int client, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(!FF2_IsFF2Enabled())					return Plugin_Continue;

	int boss = FF2_GetBossIndex(attacker);
	if(boss == -1 || !FF2_HasAbility(boss, PLUGIN_NAME, DISCOUNT_NAME))	return Plugin_Continue;

	bool insertKill = g_iDiscountValue[client] >= 100;
	int addDiscount;

#if defined _ff2_potry_included
	addDiscount = FF2_GetAbilityArgument(boss, PLUGIN_NAME, DISCOUNT_NAME, "on hit sale", 10);
#else
	addDiscount = FF2_GetAbilityArgument(boss, PLUGIN_NAME, DISCOUNT_NAME, 1, 10);
#endif

	if(insertKill)
	{
		if(FF2_GetBossIndex(client) == -1)
			damage = 10000.0;
		else
		 	damage *= 2.0;

		g_iDiscountValue[client] = 0;
	}
	else
	{
		damage *= (1.0 + (g_iDiscountValue[client] * 0.01));
	}

	AddDiscount(client, attacker, addDiscount);
	return Plugin_Changed;
}

void AddDiscount(int client, int attacker, int addValue)
{
	char soundPath[PLATFORM_MAX_PATH];
	int boss = FF2_GetBossIndex(attacker);

#if defined _ff2_potry_included
	FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, DISCOUNT_NAME, "free sale sound", soundPath, sizeof(soundPath), "");
#else
	FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, DISCOUNT_NAME, 2, soundPath, sizeof(soundPath));
#endif

	if(g_iDiscountValue[client] >= 100)
	{
		StopSound(client, 0, soundPath);
		StopSound(client, 0, soundPath);

		g_iDiscountValue[client] = 0;
	}
	else
		g_iDiscountValue[client] += addValue;

	if(g_iDiscountValue[client] >= 100)
	{
		EmitSoundToClient(client, soundPath);
		EmitSoundToClient(client, soundPath);

		if(FF2_GetBossIndex(client) == -1)
		{
			SetGlobalTransTarget(client);
			PrintToChat(client, "%t", "Free Sale");
		}
	}
}

void UpdateSaleSprite(int client)
{
	// PrintToChatAll("Updated, %d", g_iSpriteModelIndex[g_iDiscountValue[client] / 10]);
	float pos[3];
	GetClientEyePosition(client, pos);
	pos[2] += 20.0;
/*
	if(!IsValidEntity(g_hDiscountSprite[client]))
	{
		RemoveEntity(g_hDiscountSprite[client]);
		g_hDiscountSprite[client] = -1;
	}
	else if(g_hDiscountSprite[client] != -1)
	{
		SetEntityModel(g_hDiscountSprite[client], g_strSpriteModelPath[g_iDiscountValue[client] / 10]);
	}
	else
	{
		int sprite = CreateEntityByName("env_sprite_oriented");
        if(sprite != -1)
        {
            DispatchKeyValue(sprite, "spawnflags", "1");
            SetEntityModel(sprite, g_strSpriteModelPath[g_iDiscountValue[client] / 10]);

			DispatchKeyValue(sprite, "scale", "4.0" );
			DispatchKeyValue(sprite, "GlowProxySize", "2.0" );
			SetEntProp(sprite, Prop_Data, "m_bWorldSpaceScale", 1 );

            DispatchSpawn(sprite);
            TeleportEntity(sprite, pos, NULL_VECTOR, NULL_VECTOR);

			SetVariantString("!activator");
			AcceptEntityInput(sprite, "SetParent", client);

			AcceptEntityInput(sprite, "HideSprite");
			AcceptEntityInput(sprite, "ShowSprite");

			g_hDiscountSprite[client] = sprite;
        }
	}
*/
	TE_SetupGlowSprite(pos, g_iSpriteModelIndex[g_iDiscountValue[client] / 10], 0.1, 0.1, 200);
	TE_SendToAll();
}

stock int SpawnWeapon(int client, char[] name, int index, int level, int quality, char[] attribute)
{
	Handle weapon=TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	TF2Items_SetClassname(weapon, name);
	TF2Items_SetItemIndex(weapon, index);
	TF2Items_SetLevel(weapon, level);
	TF2Items_SetQuality(weapon, quality);
	char attributes[32][32];
	int count = ExplodeString(attribute, ";", attributes, 32, 32);
	if(count%2!=0)
	{
		count--;
	}

	if(count>0)
	{
		TF2Items_SetNumAttributes(weapon, count/2);
		int i2=0;
		for(int i=0; i<count; i+=2)
		{
			int attrib=StringToInt(attributes[i]);
			if(attrib==0)
			{
				LogError("Bad weapon attribute passed: %s ; %s", attributes[i], attributes[i+1]);
				return -1;
			}
			TF2Items_SetAttribute(weapon, i2, attrib, StringToFloat(attributes[i+1]));
			i2++;
		}
	}
	else
	{
		TF2Items_SetNumAttributes(weapon, 0);
	}

	if(weapon==null)
	{
		return -1;
	}
	int entity=TF2Items_GiveNamedItem(client, weapon);
	CloseHandle(weapon);
	EquipPlayerWeapon(client, entity);
	return entity;
}

stock bool IsValidClient(int client)
{
	return (0 < client && client <= MaxClients && IsClientInGame(client));
}
