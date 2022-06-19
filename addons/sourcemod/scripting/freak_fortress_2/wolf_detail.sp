#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2items>
#include <tf2_stocks>
#include <tf2attributes>
#include <tf2utils>
#include <freak_fortress_2>
#include <ff2_potry>
#include <ff2_stocks>
#include <dhooks>

#undef REQUIRE_PLUGIN
#tryinclude <mannvsmann>
#define REQUIRE_PLUGIN

#define PLUGIN_NAME "wolf detail"
#define PLUGIN_VERSION 	"20210904"

public Plugin myinfo=
{
	name="Freak Fortress 2: Wolf Abilities",
	author="Nopied◎",
	description="",
	version=PLUGIN_VERSION,
};

#define DELETE_AFTER_CHARGE_NAME        "delete after chargeshot"
#define REFLECTER_NAME                  "reflect"
#define REFLECTER_BY_FORCE_NAME         "turn on reflect by force"

#define min(%1,%2)            (((%1) < (%2)) ? (%1) : (%2))
#define max(%1,%2)            (((%1) > (%2)) ? (%1) : (%2))
#define mclamp(%1,%2,%3)        min(max(%1,%2),%3)

Handle g_SDKCallGetVelocity;
Handle g_SDKCallSetAbsVelocity;
// Handle g_SDKCallFireBullets;
// Handle g_SDKCallApplyLocalAngularVelocityImpulse;

// Handle g_SDKCallVPhysicsGetObjectList;

bool g_bReflecter[MAXPLAYERS+1];
bool g_bReflecterForce[MAXPLAYERS+1];
float g_flReflecterHealth[MAXPLAYERS+1];
int g_hReflecterEffect[MAXPLAYERS+1] = -1;

public void OnPluginStart()
{
	LoadTranslations("ff2_extra_abilities.phrases");

	HookEvent("player_spawn", OnPlayerSpawnOrDead);
	HookEvent("player_death", OnPlayerSpawnOrDead);

	FF2_RegisterSubplugin(PLUGIN_NAME);

	GameData gamedata = new GameData("potry");
	if (gamedata)
	{
		g_SDKCallGetVelocity = PrepSDKCall_GetVelocity(gamedata);
		g_SDKCallSetAbsVelocity = PrepSDKCall_SetAbsVelocity(gamedata);
		// g_SDKCallFireBullets = PrepSDKCall_FireBullets(gamedata);
		// g_SDKCallApplyLocalAngularVelocityImpulse = PrepSDKCall_ApplyLocalAngularVelocityImpulse(gamedata);
		// g_SDKCallVPhysicsGetObjectList = PrepSDKCall_VPhysicsGetObjectList(gamedata);

		CreateDynamicDetour(gamedata, "CTFParticleCannon::FireChargedShot", _, DHookCallback_FireChargedShot_Post);
		delete gamedata;
	}
	else
	{
		SetFailState("Could not find potry gamedata");
	}
}

public void OnMapStart()
{
	FF2_PrecacheEffect();
	FF2_PrecacheParticleEffect("bullet_pistol_tracer01_blue_crit");
	FF2_PrecacheParticleEffect("impact_dirt");
	FF2_PrecacheParticleEffect("blood_impact_heavy");
	FF2_PrecacheParticleEffect("deflect_fx");
	FF2_PrecacheParticleEffect("pyro_blast");
}

public Action OnPlayerSpawnOrDead(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    g_flReflecterHealth[client] = 0.0;
}

public void FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status)
{
	if(StrEqual(REFLECTER_NAME, abilityName))
	{
		InvokeReflecterRage(boss);
	}
	if(StrEqual(REFLECTER_BY_FORCE_NAME, abilityName))
	{
		InvokeReflecter(boss);
	}
}

public void FF2_OnCalledQueue(FF2HudQueue hudQueue, int client)
{
	int boss = FF2_GetBossIndex(client);
	if(!FF2_HasAbility(boss, PLUGIN_NAME, REFLECTER_NAME))  return;

	char text[128];
	FF2HudDisplay hudDisplay = null;

	SetGlobalTransTarget(client);
	hudQueue.GetName(text, sizeof(text));

	if(StrEqual(text, "Boss"))
	{
		if(g_flReflecterHealth[client] > 0.0)
			Format(text, sizeof(text), "%t", "Reflecter Health", RoundFloat(g_flReflecterHealth[client]));
		else if(FF2_HasAbility(boss, PLUGIN_NAME, REFLECTER_BY_FORCE_NAME))
			Format(text, sizeof(text), "%t", "Reflecter By Force");
		else
			return;

		hudDisplay = FF2HudDisplay.CreateDisplay("Reflecter", text);
		hudQueue.AddHud(hudDisplay, client);
	}
}

void InvokeReflecter(int boss)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));

	g_bReflecterForce[client] =
		(GetEntProp(client, Prop_Send, "m_bDucked")) > 0;

	InitReflecter(client);
}

void InvokeReflecterRage(int boss)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));
	ArrayList humanArray = GetAlivePlayers(client);

	int count = humanArray.Length;
	float health = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, REFLECTER_NAME, "initial health", 2000.0);
	health += FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, REFLECTER_NAME, "health per person", 200.0) * count;

	g_flReflecterHealth[client] = health;
	InitReflecter(client);

	delete humanArray;
}

void InitReflecter(int client)
{
	bool able = g_flReflecterHealth[client] > 0.0 || g_bReflecterForce[client];
	if(able && !g_bReflecter[client])
    {
		g_bReflecter[client] = true;

		SDKHook(client, SDKHook_PostThink, OnReflecterThink);
		SDKHook(client, SDKHook_OnTakeDamageAlive, OnReflecterDamage);

		if(g_flReflecterHealth[client] > 0.0)
			TF2_AddCondition(client, TFCond_UberBlastResist, TFCondDuration_Infinite);
		else
			TF2_AddCondition(client, TFCond_UberBulletResist, TFCondDuration_Infinite);

		float pos[3];
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);

		for(int target=1; target<=MaxClients; target++)
		{
			if(IsClientInGame(target))
			{
				EmitSoundToClient(target, "player/quickfix_invulnerable_on.wav", client, _, _, _, _, _, client, pos);
			}
		}
    }
	else if(g_bReflecter[client] && g_flReflecterHealth[client] > 0.0)
	{
		TF2_RemoveCondition(client, TFCond_UberBulletResist);
		TF2_AddCondition(client, TFCond_UberBlastResist, TFCondDuration_Infinite);
	}
}

void PlayReflectSound(int ent, float pos[3])
{
	char path[PLATFORM_MAX_PATH];
	Format(path, sizeof(path), "player/resistance_heavy%i.wav", GetRandomInt(1, 4));

	for(int target=1; target<=MaxClients; target++)
	{
		if(IsClientInGame(target))
		{
			EmitSoundToClient(target, path, ent, _, _, _, _, _, ent, pos);
		}
	}
}

void PlayProjectileReflectSound(int projectile, float pos[3])
{
	for(int target=1; target<=MaxClients; target++)
	{
		if(IsClientInGame(target))
		{
			EmitSoundToClient(target, "weapons/flame_thrower_airblast_rocket_redirect.wav", projectile, _, _, _, _, _, projectile, pos);
		}
	}
}

public Action OnReflecterDamage(int client, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(FF2_GetRoundState() != 1 || (g_flReflecterHealth[client] <= 0.0 && !g_bReflecterForce[client]))  return Plugin_Continue;
/*
	PrintToServer("damage: %.1f", damage);
	float realDamage = damage;
	if(damagetype & DMG_CRIT && TF2_IsPlayerInCondition(attacker, TFCond_Buffed) && !TF2_IsPlayerCritBuffed(attacker))
		realDamage *= 1.35;
	else if(damagetype & DMG_CRIT)
		realDamage *= 3.0;
*/
	if(!(damagetype & (DMG_BULLET | DMG_BUCKSHOT)))
	{
		g_flReflecterHealth[client] -= damage;
		return Plugin_Continue;
	}

	int boss = FF2_GetBossIndex(client);
	if(g_flReflecterHealth[client] <= 0.0 && g_bReflecterForce[client])
	{
		float drainCharge = (damage * 100.0 / FF2_GetBossRageDamage(boss)) * -0.5;
		if(FF2_GetBossCharge(client, 0) < drainCharge)
			return Plugin_Continue;

		FF2_AddBossCharge(boss, 0, drainCharge);
	}
	else
	{
		g_flReflecterHealth[client] -= damage;
	}

	float playerPos[3], effectPos[3], angles[3], targetPos[3];
	playerPos = WorldSpaceCenter(client);

	if(IsValidEntity(inflictor))
		targetPos = WorldSpaceCenter(inflictor);
	else
		targetPos = WorldSpaceCenter(attacker);

	SubtractVectors(playerPos, damagePosition, effectPos);
	NormalizeVector(effectPos, angles);
	NormalizeVector(effectPos, effectPos);

	ScaleVector(effectPos, -40.0);
	ScaleVector(angles, -1.0);

	AddVectors(playerPos, effectPos, effectPos);

	TE_SetupArmorRicochet(effectPos, angles);
	TE_SendToAll();

	SubtractVectors(targetPos, effectPos, angles);

	float distance = GetVectorDistance(targetPos, effectPos);
	AddRandomDegree(angles, distance * 0.06);

	float distToTarget = GetVectorLength(angles);
	float traceAngles[3];
	GetVectorAngles(angles, traceAngles);
	traceAngles[0] = AngleNormalize(traceAngles[0]);
	traceAngles[1] = AngleNormalize(traceAngles[1]);

	// PrintToChatAll("angles: %.1f %.1f %.1f", traceAngles[0], traceAngles[1], traceAngles[2]);
	NormalizeVector(angles, angles);

#if defined _MVM_included
	SetMannVsMachineMode(false);
#endif

	// realDamage *= 1.0 / TF2Attrib_HookValueFloat(1.0, "mult_dmg", client);
	if(damagetype & DMG_CRIT && TF2_IsPlayerCritBuffed(attacker))
		damage /= 3.0;
	else if(damagetype & DMG_CRIT && TF2_IsPlayerInCondition(attacker, TFCond_Buffed))
		damage /= 1.35;

	FireBullet(client, client, effectPos, angles, damage, distToTarget * 500, damagetype, "bullet_pistol_tracer01_blue_crit");

#if defined _MVM_included
	ResetMannVsMachineMode();
#endif

	DispatchParticleEffect(effectPos, angles, "deflect_fx", 0, 1);
	PlayReflectSound(client, effectPos);
	DispatchReflectEffect(effectPos, effectPos, angles);

	if(g_flReflecterHealth[client] > 0.0)
	{
		float speed = GetVectorLength(damageForce),
			maxSpeed = max(damage, 100.0);
		ScaleVector(damageForce, maxSpeed / speed);

		float velocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);
		AddVectors(damageForce, velocity, damageForce);

		damage = 0.0;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, damageForce);
	}
	return g_flReflecterHealth[client] > 0.0 ? Plugin_Changed : Plugin_Continue;
}

public void OnReflecterThink(int client)
{
	if(FF2_GetRoundState() != 1 || (g_flReflecterHealth[client] <= 0.0 && !g_bReflecterForce[client]))
	{
		SDKUnhook(client, SDKHook_PostThink, OnReflecterThink);
		SDKUnhook(client, SDKHook_OnTakeDamageAlive, OnReflecterDamage);

		TF2_RemoveCondition(client, TFCond_UberBlastResist);
		TF2_RemoveCondition(client, TFCond_UberBulletResist);
/*
		if(IsValidEntity(g_hReflecterEffect[client]))
			RemoveEntity(g_hReflecterEffect[client]);
*/
		for(int target=1; target<=MaxClients; target++)
		{
			if(IsClientInGame(target))
			{
				StopSound(target, 0, "player/quickfix_invulnerable_on.wav");
			}
		}

		g_flReflecterHealth[client] = 0.0;
		g_hReflecterEffect[client] = -1;
		g_bReflecter[client] = false;
		return;
	}

	// PrintToServer("%.1f + %.1f", FF2_GetClientGlow(client), GetTickInterval());
	// TODO: 리플렉터 모델 작동되면 삭제
	// int boss = FF2_GetBossIndex(client);
	FF2_SetClientGlow(client, GetTickInterval() * 0.5);

	float playerPos[3], pos[3], endPos[3], velocity[3], speed;
	playerPos = WorldSpaceCenter(client);

	int projectile = -1, owner;

	while((projectile = FindEntityByClassname(projectile, "tf_projectile_*")) != -1)
	{
		GetEntPropVector(projectile, Prop_Send, "m_vecOrigin", pos);
		GetEntPropVector(projectile, Prop_Data, "m_vecVelocity", velocity);

		if(GetVectorDistance(playerPos, pos) > 100.0)
			continue;

		TR_TraceRayFilter(playerPos, pos, MASK_PLAYERSOLID, RayType_EndPoint, TraceHitMe, projectile);
		if(TR_GetEntityIndex() != projectile)       continue;

		speed = GetVectorLength(velocity);
		owner = GetEntPropEnt(projectile, Prop_Send, "m_hOwnerEntity");

		if(GetEntProp(projectile, Prop_Send, "m_iTeamNum") == GetClientTeam(client))
			continue;

		if(g_flReflecterHealth[client] <= 0.0 && g_bReflecterForce[client])
		{
			break;
		}

		if(!IsValidEntity(owner))
		{
			owner = GetEntPropEnt(GetEntPropEnt(projectile, Prop_Send, "m_hLauncher"),
					Prop_Send, "m_hOwnerEntity");
		}

		char classname[64];
		GetEntityClassname(projectile, classname, sizeof(classname));
		// PrintToServer("Detected %d(%s), owner: %d", projectile, classname, owner);

		if(speed <= 0.0)
		{
			// Does not work
			// SDKCall_GetVelocity(projectile, velocity, impulse);

			// FIXME: 현재 속도를 기준으로 할 것
			// GetEntPropVector(projectile, Prop_Send, "m_vecVelocity", velocity);
			GetEntPropVector(projectile, Prop_Send, "m_vInitialVelocity", velocity);
			speed = GetVectorLength(velocity);
			/*
			// QAngleToAngularImpulse(angles, impulse);
			// ScaleVector(impulse, speed * -1.0);

			// PrintToServer("%X", g_SDKCallApplyLocalAngularVelocityImpulse);
			// PrintToServer("before: velocity(%.1f %.1f %.1f), impulse(%.1f %.1f %.1f)", velocity[0], velocity[1], velocity[2], impulse[0], impulse[1], impulse[2]);

			// SDKCall_ApplyLocalAngularVelocityImpulse(projectile, impulse);
			// TeleportEntity(projectile, NULL_VECTOR, angles, velocity);
			// PrintToServer("after: velocity(%.1f %.1f %.1f), impulse(%.1f %.1f %.1f)", velocity[0], velocity[1], velocity[2], impulse[0], impulse[1], impulse[2]);
			*/
		}
		else if(!IsValidEntity(owner))
		{
			continue;
		}

		endPos = WorldSpaceCenter(owner);
		SubtractVectors(pos, endPos, endPos);

		float distance = GetVectorDistance(pos, endPos);
		AddRandomDegree(endPos, distance * 0.1);

		float actualAngles[3];
		GetVectorAngles(endPos, actualAngles);
		actualAngles[0] = AngleNormalize(actualAngles[0]);
		actualAngles[1] = AngleNormalize(actualAngles[1]);

		NormalizeVector(endPos, velocity);
		ScaleVector(velocity, speed * -1.0);

		TeleportEntity(projectile, NULL_VECTOR, actualAngles, velocity);

		DispatchParticleEffect(pos, actualAngles, "deflect_fx", projectile, 1);
		PlayProjectileReflectSound(projectile, pos);
		DispatchReflectEffect(pos, pos, actualAngles);

		SetEntPropEnt(projectile, Prop_Send, "m_hOwnerEntity", client);
		SetEntProp(projectile, Prop_Send, "m_iTeamNum", GetClientTeam(client));

		if(HasEntProp(projectile, Prop_Send, "m_iDeflected"))
			SetEntProp(projectile, Prop_Send, "m_iDeflected", 1);
		if(HasEntProp(projectile, Prop_Send, "m_hThrower"))
			SetEntPropEnt(projectile, Prop_Send, "m_hThrower", client);
		if(HasEntProp(projectile, Prop_Send, "m_hDeflectOwner"))
			SetEntPropEnt(projectile, Prop_Send, "m_hDeflectOwner", client);

		// TODO: 효과음, 붕붕이 FX 추가

		g_flReflecterHealth[client] -= 80.0;
	}

	g_flReflecterHealth[client] -= GetTickInterval() * 40.0;
}

public bool TraceHitMe(int entity, int contentsMask, any data)
{
    return entity == data;
}

public void AddRandomDegree(float angles[3], float random)
{
    for(int loop = 0; loop < 3; loop++)
    {
        angles[loop] += GetRandomFloat(random * -0.5, random * 0.5);
    }
}

stock void DispatchReflectEffect(float startpos[3], float endpos[3], float angles[3])
{
	TE_DispatchEffect("pyro_blast", startpos, endpos, angles);
	TE_SendToAll();
}

// https://github.com/Pelipoika/The-unfinished-and-abandoned/blob/master/CSGO_SentryGun.sp
stock void FireBullet(int m_pAttacker, int m_pDamager, float m_vecSrc[3], float m_vecDirShooting[3], float m_flDamage, float m_flDistance, int nDamageType, const char[] tracerEffect)
{
	float vecEnd[3];
	vecEnd[0] = m_vecSrc[0] + (m_vecDirShooting[0] * m_flDistance);
	vecEnd[1] = m_vecSrc[1] + (m_vecDirShooting[1] * m_flDistance);
	vecEnd[2] = m_vecSrc[2] + (m_vecDirShooting[2] * m_flDistance);

	// Fire a bullet (ignoring the shooter).
	Handle trace = TR_TraceRayFilterEx(m_vecSrc, vecEnd, ( MASK_SOLID | CONTENTS_HITBOX ), RayType_EndPoint, AimTargetFilter, m_pAttacker);

	if ( TR_GetFraction(trace) < 1.0 )
	{
		// Verify we have an entity at the point of impact.
		int ent = TR_GetEntityIndex(trace);
		if(ent == -1)
		{
			delete trace;
			return;
		}

		int team = GetEntProp(m_pAttacker, Prop_Send, "m_iTeamNum");
		if(team == GetEntProp(ent, Prop_Send, "m_iTeamNum"))
		{
			// .. Just in case.
			delete trace;
			return;
		}

		float endpos[3]; TR_GetEndPosition(endpos, trace);
		/*
		float multiplier = (800.0 / GetVectorDistance(m_vecSrc, endpos)) + 0.3;
		if(multiplier > 1.0)
			multiplier = 1.0;
		*/
		SDKHooks_TakeDamage(ent, m_pAttacker, m_pDamager, m_flDamage, nDamageType, m_pAttacker, CalculateBulletDamageForce(m_vecDirShooting, 1.0), endpos);

		// Sentryguns are perfectly accurate, but this doesn't look good for tracers.
		// Add a little noise to them, but not enough so that it looks like they're missing.
		// endpos[0] += GetRandomFloat(-10.0, 10.0);
		// endpos[1] += GetRandomFloat(-10.0, 10.0);
		// endpos[2] += GetRandomFloat(-10.0, 10.0);

		// Bullet tracer
		TE_DispatchEffect(tracerEffect, endpos, m_vecSrc, NULL_VECTOR);
		// TE_WriteFloat("m_flRadius", 20.0);
		TE_SendToAll();

		float vecNormal[3];	TR_GetPlaneNormal(trace, vecNormal);
		GetVectorAngles(vecNormal, vecNormal);

		if(ent <= 0 || ent > MaxClients)
		{
			//Can't get surface properties from traces unfortunately.
			//Just another shortsighting from the SM devs :///
			TE_DispatchEffect("impact_dirt", endpos, endpos, vecNormal);
			TE_SendToAll();

			TE_Start("Impact");
			TE_WriteVector("m_vecOrigin", endpos);
			TE_WriteVector("m_vecNormal", vecNormal);
			TE_WriteNum("m_iType", GetRandomInt(1, 10));
			TE_SendToAll();
		}

		else if(ent > 0 && ent <= MaxClients)
		{
			TE_DispatchEffect("blood_impact_heavy", endpos, endpos, vecNormal);
			TE_SendToAll();
		}
	}

	delete trace;
}

stock float AngleNormalize(float angle)
{
	angle = fmodf(angle, 360.0);
	if (angle > 180)
	{
		angle -= 360;
	}
	if (angle < -180)
	{
		angle += 360;
	}
	return angle;
}

stock float fmodf(float num, float denom)
{
	return num - denom * RoundToFloor(num / denom);
}

float[] CalculateBulletDamageForce( const float vecBulletDir[3], float flScale )
{
	float vecForce[3]; vecForce = vecBulletDir;
	NormalizeVector( vecForce, vecForce );
	ScaleVector(vecForce, FindConVar("phys_pushscale").FloatValue);
	ScaleVector(vecForce, flScale);
	return vecForce;
}

public bool AimTargetFilter(int entity, int contentsMask, any iExclude)
{
	char class[64];
	GetEntityClassname(entity, class, sizeof(class));

	if(StrEqual(class, "monster_generic"))
	{
		return false;
	}
	if(!(entity == iExclude))
	{
		if(HasEntProp(iExclude, Prop_Send, "m_iTeamNum"))
		{
			int team = GetEntProp(entity, Prop_Send, "m_iTeamNum");
			return team != GetEntProp(iExclude, Prop_Send, "m_iTeamNum");
		}

		return true;
	}

	return false;
}

// https://github.com/Pelipoika/The-unfinished-and-abandoned/blob/master/CSGO_SentryGun.sp
stock float[] GetAbsOrigin(int client)
{
	float v[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", v);
	return v;
}

stock float[] WorldSpaceCenter(int ent)
{
	float v[3]; v = GetAbsOrigin(ent);

	float max[3];
	GetEntPropVector(ent, Prop_Data, "m_vecMaxs", max);
	v[2] += max[2] / 2;

	return v;
}

public MRESReturn DHookCallback_FireChargedShot_Post(int weapon)
{
	int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity"),
		boss = FF2_GetBossIndex(owner);
	if(boss != -1 && FF2_HasAbility(boss, PLUGIN_NAME, DELETE_AFTER_CHARGE_NAME))
	{
		int slot = FF2_GetAbilityArgument(boss, PLUGIN_NAME, DELETE_AFTER_CHARGE_NAME, "replace slot", -1);
		if(slot > -1)
		{
			int replaceWeapon = GetPlayerWeaponSlot(owner, slot);

			if(IsValidEntity(replaceWeapon))
				SetEntPropEnt(owner, Prop_Send, "m_hActiveWeapon", replaceWeapon);
		}

		RemoveEntity(weapon);
	}
	return MRES_Ignored;
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

Handle PrepSDKCall_GetVelocity(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CBaseEntity::GetVelocity");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);

	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDK call: CBaseEntity::GetVelocity");

	return call;
}

public void SDKCall_GetVelocity(int entity, float velocity[3], float impulse[3])
{
	if (g_SDKCallGetVelocity)
		SDKCall(g_SDKCallGetVelocity, entity, velocity, impulse);
}

Handle PrepSDKCall_SetAbsVelocity(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CBaseEntity::SetAbsVelocity");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);

	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDK call: CBaseEntity::SetAbsVelocity");

	return call;
}

public void SDKCall_SetAbsVelocity(int entity, float velocity[3])
{
	if (g_SDKCallSetAbsVelocity)
		SDKCall(g_SDKCallSetAbsVelocity, entity, velocity);
}
/*
Handle PrepSDKCall_FireBullets(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "TE_FireBullets");
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
    PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_Pointer);
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);

	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDK call: TE_FireBullets");

	return call;
}

public void SDKCall_FireBullets(int iPlayerIndex, float vOrigin[3], float vAngles[3],
					 int iWeaponID, int	iMode, int iSeed, float flSpread, bool bCritical)
{
	if (g_SDKCallFireBullets)
		SDKCall(g_SDKCallFireBullets, iPlayerIndex, vOrigin, vAngles, iWeaponID, iMode, iSeed, flSpread, bCritical);
}

Handle PrepSDKCall_ApplyLocalAngularVelocityImpulse(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CBaseEntity::ApplyLocalAngularVelocityImpulse");
    PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);

	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDK call: CBaseEntity::ApplyLocalAngularVelocityImpulse");

	return call;
}

public void SDKCall_ApplyLocalAngularVelocityImpulse(int entity, float angImpulse[3])
{
	if (g_SDKCallApplyLocalAngularVelocityImpulse)
		SDKCall(g_SDKCallApplyLocalAngularVelocityImpulse, entity, angImpulse);
}


Handle PrepSDKCall_VPhysicsGetObjectList(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CBaseEntity::VPhysicsGetObjectList");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Pointer);
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);

	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDK call: CBaseEntity::VPhysicsGetObjectList");

	return call;
}

public int SDKCall_VPhysicsGetObjectList(int entity, int[] list, int maxCount)
{
	if (g_SDKCallVPhysicsGetObjectList)
		return SDKCall(g_SDKCallVPhysicsGetObjectList, entity, list, maxCount);

	return 0;
}
*/
/*
public void QAngleToAngularImpulse(const float angles[3], float impulse[3])
{
	// angles: (0: x, 1: z, 2: y)
	// angles[0] = impulse[2];
	// angles[2] = impulse[1];
	// angles[1] = impulse[0];

	impulse[2] = angles[0];
	impulse[1] = angles[2];
	impulse[0] = angles[1];
}
*/

stock int AttachParticle(int entity, char[] particleType, float offset=0.0, bool attach=true)
{
	int particle=CreateEntityByName("info_particle_system");

	char targetName[128];
	float position[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
	position[2]+=offset;
	TeleportEntity(particle, position, NULL_VECTOR, NULL_VECTOR);

	Format(targetName, sizeof(targetName), "target%i", entity);
	DispatchKeyValue(entity, "targetname", targetName);

	DispatchKeyValue(particle, "targetname", "tf2particle");
	DispatchKeyValue(particle, "parentname", targetName);
	DispatchKeyValue(particle, "effect_name", particleType);
	DispatchSpawn(particle);
	SetVariantString(targetName);
	if(attach)
	{
		AcceptEntityInput(particle, "SetParent", particle, particle, 0);
		SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", entity);
	}
	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
	return particle;
}

stock int DispatchParticleEffect(float pos[3], float angles[3], char[] particleType, int parent=0, int time=1, int controlpoint=0)
{
	int particle = CreateEntityByName("info_particle_system");

	char temp[64], targetName[64], cpName[64];
	if (IsValidEdict(particle))
	{
		TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);

		Format(targetName, sizeof(targetName), "tf2particle%i", particle);
		DispatchKeyValue(particle, "targetname", targetName);
		DispatchKeyValue(particle, "effect_name", particleType);
		DispatchSpawn(particle);

		Format(temp, sizeof(temp), "OnUser1 !self:kill::%i:1", time);
		SetVariantString(temp);

		AcceptEntityInput(particle, "AddOutput");
		AcceptEntityInput(particle, "FireUser1");

		// Only one???
		if(controlpoint > 0)
		{
			int cpParticle = CreateEntityByName("info_particle_system");
			if (IsValidEdict(cpParticle))
			{
				Format(cpName, sizeof(cpName), "tf2particle%i", cpParticle);
				DispatchKeyValue(cpParticle, "targetname", cpName);

				SetVariantString(targetName);
				AcceptEntityInput(cpParticle, "SetParent", particle, particle, 0);

				DispatchKeyValue(particle, "cpoint1", cpName);
			}
		}

		if(parent > 0)
		{
			Format(targetName, sizeof(targetName), "target%i", parent);
			DispatchKeyValue(parent, "targetname", targetName);
			SetVariantString(targetName);

			AcceptEntityInput(particle, "SetParent", particle, particle, 0);
			SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", parent);
		}

		ActivateEntity(particle);
		DispatchKeyValueVector(particle, "angles", angles);
		AcceptEntityInput(particle, "start");
	}
}

stock bool TF2_IsPlayerCritBuffed(int client)
{
	return (TF2_IsPlayerInCondition(client, TFCond_Kritzkrieged) || TF2_IsPlayerInCondition(client, TFCond_HalloweenCritCandy) || TF2_IsPlayerInCondition(client, view_as<TFCond>(34)) || TF2_IsPlayerInCondition(client, view_as<TFCond>(35)) || TF2_IsPlayerInCondition(client, TFCond_CritOnFirstBlood) || TF2_IsPlayerInCondition(client, TFCond_CritOnWin) || TF2_IsPlayerInCondition(client, TFCond_CritOnFlagCapture) || TF2_IsPlayerInCondition(client, TFCond_CritOnKill) || TF2_IsPlayerInCondition(client, TFCond_CritMmmph));
}

public ArrayList GetAlivePlayers(int target)
{
	ArrayList array = new ArrayList();
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && IsPlayerAlive(client)
		&& (GetClientTeam(client) != GetClientTeam(target)))
		{
			// PrintToServer("Pushed %N", client);
			array.Push(client);
		}
	}

	return array;
}
