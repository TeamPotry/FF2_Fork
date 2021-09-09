#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
// #include <morecolors>
#include <freak_fortress_2>
#include <ff2_potry>
#include <stocksoup/sdkports/util>

#pragma newdecls required

#define PLUGIN_NAME "pointing abilities"
#define PLUGIN_VERSION "20210820"

public Plugin myinfo=
{
	name="Freak Fortress 2: Pointing Abilities",
	author="Nopied◎",
	description="Replace default Teleport ability",
	version=PLUGIN_VERSION,
};

Handle jumpHUD;

#define	MAX_EDICT_BITS		12
#define	MAX_EDICTS			(1 << MAX_EDICT_BITS)

int g_iBeamModel, g_iHaloModel;
float g_flTeleportDistance[MAXPLAYERS+1];

enum
{
	Portal_Owner,
    Portal_Size,
	Portal_LifeTime,
	Portal_BreakableIndex,

	Portal_EntranceParticleIndex,
	Portal_EntranceParticleName, // MAX 64
	Portal_EntrancePosX,
	Portal_EntrancePosZ,
	Portal_EntrancePosY,

	Portal_ExitParticleIndex,
	Portal_ExitParticleName, // MAX 64
	Portal_ExitPosX,
	Portal_ExitPosZ,
	Portal_ExitPosY,

	Portal_LaunchPower,
	Portal_LaunchAngleX,
	Portal_LaunchAngleZ,
	Portal_LaunchAngleY,

	Portal_OpenSoundPath,
	Portal_SoundLoopTime,
	Portal_SoundNextLoopTime,
	Portal_LoopSoundPath,
	Portal_CloseSoundPath,
	Portal_EnterEntranceSoundPath,
	Portal_EnterExitSoundPath,

	Portal_Max
};

methodmap CTFPortal < ArrayList {
    public static native CTFPortal Create(int owner);

	property int Owner {
		public get() {
			return this.Get(Portal_Owner);
		}
		public set(int owner) {
			this.Set(Portal_Owner, owner);
		}
	}
	property float Size {
		public get() {
			return this.Get(Portal_Size);
		}
		public set(float size) {
			this.Set(Portal_Size, size);
		}
	}
	property float LifeTime {
		public get() {
			return this.Get(Portal_LifeTime);
		}
		public set(float time) {
			this.Set(Portal_LifeTime, time);
		}
	}
	property int BreakableIndex {
		public get() {
			return this.Get(Portal_BreakableIndex);
		}
		public set(int index) {
			this.Set(Portal_BreakableIndex, index);
		}
	}
	property float LaunchPower {
		public get() {
			return this.Get(Portal_LaunchPower);
		}
		public set(float power) {
			this.Set(Portal_LaunchPower, power);
		}
	}
	property int EntranceParticleIndex {
		public get() {
			return this.Get(Portal_EntranceParticleIndex);
		}
		public set(int ent) {
			this.Set(Portal_EntranceParticleIndex, ent);
		}
	}
	property int ExitParticleIndex {
		public get() {
			return this.Get(Portal_ExitParticleIndex);
		}
		public set(int ent) {
			this.Set(Portal_ExitParticleIndex, ent);
		}
	}
	property float SoundLoopTime {
		public get() {
			return this.Get(Portal_SoundLoopTime);
		}
		public set(float time) {
			this.Set(Portal_SoundLoopTime, time);
		}
	}
	property float SoundNextLoopTime {
		public get() {
			return this.Get(Portal_SoundNextLoopTime);
		}
		public set(float time) {
			this.Set(Portal_SoundNextLoopTime, time);
		}
	}

	public void GetEntranceParticleName(char[] name, int buffer)
	{
		this.GetString(Portal_EntranceParticleName, name, buffer);
	}

	public void SetEntranceParticleName(const char[] name)
	{
		this.SetString(Portal_EntranceParticleName, name);
	}

	public void GetEntrancePosition(float pos[3])
	{
		int index;
		for(int loop = Portal_EntrancePosX; loop <= Portal_EntrancePosY; loop++)
		{
			index = loop - Portal_EntrancePosX;
			pos[index] = this.Get(loop);
		}
	}

	public void SetEntrancePosition(const float pos[3])
	{
		int index;
		for(int loop = Portal_EntrancePosX; loop <= Portal_EntrancePosY; loop++)
		{
			index = loop - Portal_EntrancePosX;
			this.Set(loop, pos[index]);
		}
	}

	public void GetExitParticleName(char[] name, int buffer)
	{
		this.GetString(Portal_ExitParticleName, name, buffer);
	}

	public void SetExitParticleName(const char[] name)
	{
		this.SetString(Portal_ExitParticleName, name);
	}

	public void GetExitPosition(float pos[3])
	{
		int index;
		for(int loop = Portal_ExitPosX; loop <= Portal_ExitPosY; loop++)
		{
			index = loop - Portal_ExitPosX;
			pos[index] = this.Get(loop);
		}
	}

	public void SetExitPosition(const float pos[3])
	{
		int index;
		for(int loop = Portal_ExitPosX; loop <= Portal_ExitPosY; loop++)
		{
			index = loop - Portal_ExitPosX;
			this.Set(loop, pos[index]);
		}
	}

	public void GetLaunchAngles(float angles[3])
	{
		int index;
		for(int loop = Portal_LaunchAngleX; loop <= Portal_LaunchAngleY; loop++)
		{
			index = loop - Portal_LaunchAngleX;
			angles[index] = this.Get(loop);
		}
	}

	public void SetLaunchAngles(const float angles[3])
	{
		int index;
		for(int loop = Portal_LaunchAngleX; loop <= Portal_LaunchAngleY; loop++)
		{
			index = loop - Portal_LaunchAngleX;
			this.Set(loop, angles[index]);
		}
	}

	public void GetOpenSound(char[] path, int buffer)
	{
		this.GetString(Portal_OpenSoundPath, path, buffer);
	}

	public void SetOpenSound(const char[] path)
	{
		this.SetString(Portal_OpenSoundPath, path);
	}

	public void GetLoopSound(char[] path, int buffer)
	{
		this.GetString(Portal_LoopSoundPath, path, buffer);
	}

	public void SetLoopSound(const char[] path)
	{
		this.SetString(Portal_LoopSoundPath, path);
	}

	public void GetCloseSound(char[] path, int buffer)
	{
		this.GetString(Portal_CloseSoundPath, path, buffer);
	}

	public void SetCloseSound(const char[] path)
	{
		this.SetString(Portal_CloseSoundPath, path);
	}

	public void GetEnterEntranceSound(char[] path, int buffer)
	{
		this.GetString(Portal_EnterEntranceSoundPath, path, buffer);
	}

	public void SetEnterEntranceSound(const char[] path)
	{
		this.SetString(Portal_EnterEntranceSoundPath, path);
	}

	public void GetEnterExitSound(char[] path, int buffer)
	{
		this.GetString(Portal_EnterExitSoundPath, path, buffer);
	}

	public void SetEnterExitSound(const char[] path)
	{
		this.SetString(Portal_EnterExitSoundPath, path);
	}

	public void Open()
	{
		float pos[3], endPos[3];
		char entrancePaticleName[64], exitPaticleName[64];

		this.GetEntrancePosition(pos);
		this.GetExitPosition(endPos);

		this.GetEntranceParticleName(entrancePaticleName, sizeof(entrancePaticleName));
		this.GetExitParticleName(exitPaticleName, sizeof(exitPaticleName));

		this.EntranceParticleIndex = SpawnParticle(pos, entrancePaticleName);
		this.ExitParticleIndex = SpawnParticle(endPos, exitPaticleName);

		char sound[PLATFORM_MAX_PATH];
		this.GetOpenSound(sound, PLATFORM_MAX_PATH);

		for(int target=1; target<=MaxClients; target++)
		{
			if(IsClientInGame(target))
			{
				EmitSoundToClient(target, sound, this.EntranceParticleIndex, _, _, _, _, _, this.EntranceParticleIndex, pos);
				EmitSoundToClient(target, sound, this.ExitParticleIndex, _, _, _, _, _, this.ExitParticleIndex, endPos);
			}
		}

		float vecMin[3], vecMax[3];
		for(int loop = 0; loop < 3; loop++)
		{
			vecMin[loop] = pos[loop] + this.Size * -0.5;
			vecMax[loop] = pos[loop] + this.Size * 0.5;
		}

		int func = CreateEntityByName("func_breakable");
		if(IsValidEntity(func))
		{
			DispatchKeyValue(func, "propdata", "0");
			DispatchKeyValue(func, "health", "0");
			DispatchKeyValue(func, "material", "0");

			SetEntityModel(func, "models/error.mdl");
			SetEntityRenderMode(func, RENDER_TRANSCOLOR);
			SetEntityRenderColor(func, 255, 255, 255, 0);

			SetEntPropVector(func, Prop_Send, "m_vecMins", vecMin);
			SetEntPropVector(func, Prop_Send, "m_vecMaxs", vecMax);

			DispatchSpawn(func);
			TeleportEntity(func, pos, NULL_VECTOR, NULL_VECTOR);

			this.BreakableIndex = func;
			SDKHook(func, SDKHook_OnTakeDamage, Portal_OnTakeDamage);
		}
		PrintToServer("func: %d", func);

		this.SoundNextLoopTime = GetGameTime();

		int colors[4] = {255, 255, 255, 255};
		TE_SetupBeamPoints(pos, endPos, g_iBeamModel, g_iHaloModel, 0, 10, this.LifeTime - GetGameTime(), 30.0, 100.0, 10, 0.0, colors, 100);
		TE_SendToAll();

		RequestFrame(Portal_Update, this);
	}

	public void Close()
	{
		int entrancePaticle = this.EntranceParticleIndex,
			exitPaticle = this.ExitParticleIndex;

		RemoveEntity(entrancePaticle);
		RemoveEntity(exitPaticle);
		RemoveEntity(this.BreakableIndex);

		delete this;
	}
}

CTFPortal g_hPortal[MAX_EDICTS+1];

public void Portal_Update(CTFPortal portal)
{
	if(FF2_GetRoundState() != 1 || portal.LifeTime < GetGameTime())
	{
		portal.Close();
		return;
	}

	char sound[PLATFORM_MAX_PATH];
	float pos[3], angles[3], exitPos[3];
	portal.GetEntrancePosition(pos);
	portal.GetExitPosition(exitPos);

	if(portal.SoundNextLoopTime < GetGameTime())
	{
		portal.GetLoopSound(sound, PLATFORM_MAX_PATH);

		for(int target=1; target<=MaxClients; target++)
		{
			if(IsClientInGame(target))
			{
				EmitSoundToClient(target, sound, portal.EntranceParticleIndex, _, _, _, _, _, portal.EntranceParticleIndex, pos);
				EmitSoundToClient(target, sound, portal.ExitParticleIndex, _, _, _, _, _, portal.ExitParticleIndex, exitPos);
			}
		}

		portal.SoundNextLoopTime = GetGameTime() + portal.SoundLoopTime;
	}

	bool enter = false;
	int target = GetEntityInSpot(pos, portal.Size);
	if(IsValidClient(target))
	{
		enter = true;
		portal.GetLaunchAngles(angles);
		// GetAngleVectors(angles, angles, NULL_VECTOR, NULL_VECTOR);
		ScaleVector(angles, portal.LaunchPower);

		TryTeleport(target, pos, exitPos);
		TeleportEntity(target, NULL_VECTOR, NULL_VECTOR, angles);

		int colors[4] = {255, 255, 255, 255};
		UTIL_ScreenFade(target, colors, 0.1, 0.3, FFADE_IN);
	}
	else if(IsValidEntity(target))
	{
		GetEntPropVector(target, Prop_Data, "m_vecVelocity", angles);
		float speed = GetVectorLength(angles);
		float tempAngles[3];

		portal.GetLaunchAngles(angles);
		portal.GetLaunchAngles(tempAngles);
		ScaleVector(angles, speed);
		TeleportEntity(target, exitPos, tempAngles, angles);

		if(HasEntProp(target, Prop_Send, "m_bTouched"))
			SetEntProp(target, Prop_Send, "m_bTouched", 0);
	}

	portal.GetExitPosition(exitPos);
	if(enter)
	{
		portal.GetEnterEntranceSound(sound, PLATFORM_MAX_PATH);
		for(int client=1; client<=MaxClients; client++)
		{
			if(IsClientInGame(client))
			{
				EmitSoundToClient(client, sound, portal.EntranceParticleIndex, _, _, _, _, _, portal.EntranceParticleIndex, pos);
				EmitSoundToClient(client, sound, portal.ExitParticleIndex, _, _, _, _, _, portal.ExitParticleIndex, exitPos);
			}
		}

		portal.GetEnterExitSound(sound, PLATFORM_MAX_PATH);
		for(int client=1; client<=MaxClients; client++)
		{
			if(IsClientInGame(client))
			{
				EmitSoundToClient(client, sound, portal.EntranceParticleIndex, _, _, _, _, _, portal.EntranceParticleIndex, pos);
				EmitSoundToClient(client, sound, portal.ExitParticleIndex, _, _, _, _, _, portal.ExitParticleIndex, exitPos);
			}
		}
	}

	if(portal.LifeTime < (GetGameTime() - 1.3))
	{	// 이펙트 먼저 멈추는 연출
		int entrancePaticle = portal.EntranceParticleIndex,
			exitPaticle = portal.ExitParticleIndex;
		AcceptEntityInput(entrancePaticle, "stop");
		AcceptEntityInput(exitPaticle, "stop");

		portal.GetCloseSound(sound, PLATFORM_MAX_PATH);
		EmitSoundToAll(sound, _, _, _, _, 1.0, _, _, pos, _, false);
		EmitSoundToAll(sound, _, _, _, _, 1.0, _, _, pos, _, false);

		EmitSoundToAll(sound, _, _, _, _, 1.0, _, _, exitPos, _, false);
		EmitSoundToAll(sound, _, _, _, _, 1.0, _, _, exitPos, _, false);
	}

	RequestFrame(Portal_Update, portal);
}

public Action Portal_OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	PrintToServer("victim: %d, attacker: %d, damage: %.1f, damagetype: %d", victim, attacker, damage, damagetype);
	PrintToServer("damageForce: %.1f %.1f %.1f, damagePosition: %.1f %.1f %.1f", damageForce[0], damageForce[1], damageForce[2], damagePosition[0], damagePosition[1], damagePosition[2]);
	return Plugin_Continue;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("CTFPortal.Create", Native_CTFPortal_Create);
}

public int Native_CTFPortal_Create(Handle plugin, int numParams)
{
	CTFPortal array = view_as<CTFPortal>(new ArrayList(PLATFORM_MAX_PATH, Portal_Max));

	array.Owner = GetNativeCell(1);

	return view_as<int>(array);
}

public void OnPluginStart()
{
	jumpHUD=CreateHudSynchronizer();

	LoadTranslations("ff2_point_teleport.phrases");
	FF2_RegisterSubplugin(PLUGIN_NAME);
}

public void OnMapStart()
{
	Handle gameConfig = LoadGameConfigFile("funcommands.games");
	if(gameConfig == null)
	{
		SetFailState("Unable to load game config funcommands.games");
		return;
	}

	char buffer[PLATFORM_MAX_PATH];
	if(GameConfGetKeyValue(gameConfig, "SpriteBeam", buffer, sizeof(buffer)) && buffer[0])
	{
		g_iBeamModel = PrecacheModel(buffer);
	}
	if(GameConfGetKeyValue(gameConfig, "SpriteHalo", buffer, sizeof(buffer)) && buffer[0])
	{
		g_iHaloModel = PrecacheModel(buffer);
	}
	delete gameConfig;

	return;
}

public void FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status)
{
	if(!StrEqual(pluginName, PLUGIN_NAME, false))
	{
		return;
	}

	if(StrEqual(abilityName, "point teleport", false))
	{
		Charge_Teleport(boss, abilityName, slot, status);
	}
}

void Charge_Teleport(int boss, const char[] abilityName, int slot, int status)
{
	char message[128];
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));
	float charge = FF2_GetBossCharge(boss, slot);

	int colors[4] = {255, 255, 255, 255};
	float currentPos[3], pos[3], angles[3], endPos[3];
	float maxDistance = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, abilityName, "max distance", 3000.0, slot);
	g_flTeleportDistance[client] = maxDistance * (charge * 0.01);

	GetClientEyePosition(client, pos);
	GetEntPropVector(client, Prop_Data, "m_vecOrigin", currentPos);
	GetClientEyeAngles(client, angles);

	pos[2] -= 15.0;
	GetAngleVectors(angles, angles, NULL_VECTOR, NULL_VECTOR);
	GetEndPos(pos, angles, g_flTeleportDistance[client], endPos);

	SetGlobalTransTarget(client);
	switch(status)
	{
		case 1:
		{
			SetHudTextParams(-1.0, 0.88, 0.15, 255, 255, 255, 255);
			FF2_ShowSyncHudText(client, jumpHUD, "%t", "Teleportation Cooldown", -RoundFloat(charge));
		}
		case 0, 2:
		{
			SetHudTextParams(-1.0, 0.88, 0.15, 255, 255, 255, 255);

			char buttonText[32];
			int buttonMode = FF2_GetAbilityArgument(boss, PLUGIN_NAME, abilityName, "buttonmode", 0, slot);
			Format(buttonText, sizeof(buttonText), "%t", buttonMode == 2 ? "Reload" : "Right Click");
			Format(message, sizeof(message), "%t", "Point Teleportation Charge", RoundFloat(charge), buttonText);
			ReAddPercentCharacter(message, sizeof(message), 2);
			FF2_ShowSyncHudText(client, jumpHUD, "%s", message);

			if(charge <= 10.0)	return;

			TE_SetupBeamPoints(pos, endPos, g_iBeamModel, g_iHaloModel, 0, 10, 0.1, 10.0, 30.0, 0, 0.0, colors, 10);
			TE_SendToClient(client);
		}
		case 3:
		{
			if(charge <= 10.0)
			{
				ResetBossCharge(boss, slot);
				return;
			}

			SetEntProp(client, Prop_Send, "m_bDucked", 1);
			SetEntityFlags(client, GetEntityFlags(client)|FL_DUCKING);

			if(!TryTeleport(client, pos, endPos) || IsPlayerStuck(client))
			{
				TeleportEntity(client, currentPos, NULL_VECTOR, NULL_VECTOR);
				ResetBossCharge(boss, slot);
				return;
			}

			float size = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, abilityName, "size", 75.0, slot),
				lifeTime = GetGameTime() + FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, abilityName, "life time", 15.0, slot),
				launchPower = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, abilityName, "launch power", 600.0, slot),
				soundLoopTime = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, abilityName, "sound loop time", 2.0, slot);

			char entrancePaticleName[64], exitPaticleName[64],
				openSound[PLATFORM_MAX_PATH], loopSound[PLATFORM_MAX_PATH], closeSound[PLATFORM_MAX_PATH],
				enterEntranceSound[PLATFORM_MAX_PATH], enterExitSound[PLATFORM_MAX_PATH], abilitySound[PLATFORM_MAX_PATH];

			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, abilityName, "entrance paticle name", entrancePaticleName, sizeof(entrancePaticleName), "eyeboss_death_vortex", slot);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, abilityName, "exit paticle name", exitPaticleName, sizeof(exitPaticleName), "eyeboss_vortex_blue", slot);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, abilityName, "portal open sound path", openSound, PLATFORM_MAX_PATH, "", slot);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, abilityName, "portal loop sound path", loopSound, PLATFORM_MAX_PATH, "", slot);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, abilityName, "portal close sound path", closeSound, PLATFORM_MAX_PATH, "", slot);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, abilityName, "portal enter entrance sound path", enterEntranceSound, PLATFORM_MAX_PATH, "", slot);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, abilityName, "portal enter exit sound path", enterExitSound, PLATFORM_MAX_PATH, "", slot);

			if(FF2_FindSound("ability", abilitySound, PLATFORM_MAX_PATH, boss, true, slot))
			{
				if(FF2_CheckSoundFlags(client, FF2SOUND_MUTEVOICE))
				{
					EmitSoundToAll(abilitySound, client, _, _, _, 1.0, _, client, endPos);
					EmitSoundToAll(abilitySound, client, _, _, _, 1.0, _, client, endPos);
				}

				for(int target=1; target<=MaxClients; target++)
				{
					if(IsClientInGame(target) && target!=client && FF2_CheckSoundFlags(target, FF2SOUND_MUTEVOICE))
					{
						EmitSoundToClient(target, abilitySound, client, _, _, _, _, _, client, endPos);
						EmitSoundToClient(target, abilitySound, client, _, _, _, _, _, client, endPos);
					}
				}
			}

			CTFPortal portal = CTFPortal.Create(client);
			portal.Size = size;
			portal.LifeTime = lifeTime;
			portal.LaunchPower = launchPower;
			portal.SoundLoopTime = soundLoopTime;

			portal.SetEntranceParticleName(entrancePaticleName);
			portal.SetExitParticleName(exitPaticleName);

			GetClientEyeAngles(client, angles);
			GetAngleVectors(angles, angles, NULL_VECTOR, NULL_VECTOR);

			portal.SetLaunchAngles(angles);
			portal.SetEntrancePosition(pos);
			portal.SetExitPosition(endPos);

			portal.SetOpenSound(openSound);
			portal.SetLoopSound(loopSound);
			portal.SetOpenSound(closeSound);
			portal.SetEnterEntranceSound(enterEntranceSound);
			portal.SetEnterExitSound(enterExitSound);

			ScaleVector(angles, launchPower);
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, angles);

			portal.Open();

			UTIL_ScreenFade(client, colors, 0.1, 0.3, FFADE_IN);

			int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			if(IsValidEntity(weapon))
				SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 1.0);

			SetEntPropFloat(client, Prop_Send, "m_flNextAttack", GetGameTime()+2.0);
			SetEntPropFloat(client, Prop_Send, "m_flStealthNextChangeTime", GetGameTime() + 1.0);

			// PrintToChatAll("launchPower = %.1f, angles = %.1f %.1f %.1f", launchPower, angles[0], angles[1], angles[2]);
			// SpawnParticle(endPos, "eyeboss_tp_vortex");		// 이건 블랙홀 이펙트
			// SpawnParticle(endPos, "eyeboss_doorway_vortex"); // 이거 뭔가 차징 이펙트로 써볼만 한듯
		}
	}
}

public void GetEndPos(float pos[3], float angles[3], float distance, float endPos[3])
{
	float tempAngle[3];
	tempAngle[0] = angles[0];
	tempAngle[1] = angles[1] - 20.0;
	tempAngle[2] = angles[2];

	GetAngleVectors(tempAngle, tempAngle, NULL_VECTOR, NULL_VECTOR);

	ScaleVector(angles, distance);
	ScaleVector(tempAngle, 30.0);

	AddVectors(pos, tempAngle, pos);
	AddVectors(pos, angles, endPos);

	TR_TraceRayFilter(pos, endPos, MASK_PLAYERSOLID, RayType_EndPoint, TraceAnything);
	TR_GetEndPosition(endPos);
}

///////////////////////////

stock int SpawnParticle(float pos[3], char[] particleType, float offset=0.0)
{
	int particle=CreateEntityByName("info_particle_system");

	char targetName[128];
	pos[2]+=offset;
	TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);

	// Format(targetName, sizeof(targetName), "target%i", entity);
	// DispatchKeyValue(entity, "targetname", targetName);

	DispatchKeyValue(particle, "targetname", "tf2particle");
	DispatchKeyValue(particle, "parentname", targetName);
	DispatchKeyValue(particle, "effect_name", particleType);
	DispatchSpawn(particle);
	SetVariantString(targetName);

	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
	return particle;
}

// bool g_bTouched[MAXPLAYERS+1];
int GetEntityInSpot(float pos[3], float size)
{
	float targetPos[3];
	int ent = -1;

	for(int client = 1; client <= MaxClients; client++)
	{
		if(!IsValidClient(client) || !IsPlayerAlive(client))
			continue;

		GetClientEyePosition(client, targetPos);
		// GetEntPropVector(client, Prop_Data, "m_vecOrigin", targetPos);
		if(GetVectorDistance(pos, targetPos) <= size)
			return client;
	}

	while((ent = FindEntityByClassname(ent, "tf_projectile_*")) != -1)
	{
		GetEntPropVector(ent, Prop_Data, "m_vecOrigin", targetPos);
		if(GetVectorDistance(pos, targetPos) <= size)
			return ent;
	}


	return -1;
}

//Copied from Chdata's Fixed Friendly Fire
stock bool IsPlayerStuck(int ent)
{
	float vecMin[3], vecMax[3], vecOrigin[3];

	GetEntPropVector(ent, Prop_Send, "m_vecMins", vecMin);
	GetEntPropVector(ent, Prop_Send, "m_vecMaxs", vecMax);
	GetEntPropVector(ent, Prop_Send, "m_vecOrigin", vecOrigin);

	TR_TraceHullFilter(vecOrigin, vecOrigin, vecMin, vecMax, MASK_SOLID, TraceRayPlayerOnly, ent);
	return (TR_DidHit());
}

public bool TraceRayPlayerOnly(int iEntity, int iMask, any iData)
{
    return (IsValidClient(iEntity) && IsValidClient(iData) && iEntity != iData);
}

// Copied from sarysa's code.
bool ResizeTraceFailed;
public bool TryTeleport(int clientIdx, float startPos[3], float endPos[3])
{
	float sizeMultiplier = GetEntPropFloat(clientIdx, Prop_Send, "m_flModelScale");
	// static float startPos[3];
	// static float endPos[3];
	static float testPos[3];
	// static float eyeAngles[3];
	// GetClientEyePosition(clientIdx, startPos);
	// GetClientEyeAngles(clientIdx, eyeAngles);
	// TR_TraceRayFilter(startPos, eyeAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceAnything);
	// TR_GetEndPosition(endPos);

	// don't even try if the distance is less than 82
	float distance = GetVectorDistance(startPos, endPos);
	if (distance < 90.0)
	{
		return false;
	}
/*
	if (distance > 1500.0)
		constrainDistance(startPos, endPos, distance, 1500.0);
	else // shave just a tiny bit off the end position so our point isn't directly on top of a wall
		constrainDistance(startPos, endPos, distance, distance - 1.0);
*/
	constrainDistance(startPos, endPos, distance, distance - 1.0);

	// now for the tests. I go 1 extra on the standard mins/maxs on purpose.
	bool found = false;
	for (int x = 0; x < 3; x++)
	{
		if (found)
			break;

		float xOffset;
		if (x == 0)
			xOffset = 0.0;
		else if (x == 1)
			xOffset = 12.5 * sizeMultiplier;
		else
			xOffset = 25.0 * sizeMultiplier;

		if (endPos[0] < startPos[0])
			testPos[0] = endPos[0] + xOffset;
		else if (endPos[0] > startPos[0])
			testPos[0] = endPos[0] - xOffset;
		else if (xOffset != 0.0)
			break; // super rare but not impossible, no sense wasting on unnecessary tests

		for (int y = 0; y < 3; y++)
		{
			if (found)
				break;

			float yOffset;
			if (y == 0)
				yOffset = 0.0;
			else if (y == 1)
				yOffset = 12.5 * sizeMultiplier;
			else
				yOffset = 25.0 * sizeMultiplier;

			if (endPos[1] < startPos[1])
				testPos[1] = endPos[1] + yOffset;
			else if (endPos[1] > startPos[1])
				testPos[1] = endPos[1] - yOffset;
			else if (yOffset != 0.0)
				break; // super rare but not impossible, no sense wasting on unnecessary tests

			for (int z = 0; z < 3; z++)
			{
				if (found)
					break;

				float zOffset;
				if (z == 0)
					zOffset = 0.0;
				else if (z == 1)
					zOffset = 41.5 * sizeMultiplier;
				else
					zOffset = 83.0 * sizeMultiplier;

				if (endPos[2] < startPos[2])
					testPos[2] = endPos[2] + zOffset;
				else if (endPos[2] > startPos[2])
					testPos[2] = endPos[2] - zOffset;
				else if (zOffset != 0.0)
					break; // super rare but not impossible, no sense wasting on unnecessary tests

				// before we test this position, ensure it has line of sight from the point our player looked from
				// this ensures the player can't teleport through walls
				static float tmpPos[3];
				TR_TraceRayFilter(endPos, testPos, MASK_PLAYERSOLID, RayType_EndPoint, TraceAnything);
				TR_GetEndPosition(tmpPos);
				if (testPos[0] != tmpPos[0] || testPos[1] != tmpPos[1] || testPos[2] != tmpPos[2])
					continue;

				// now we do our very expensive test. thankfully there's only 27 of these calls, worst case scenario.
				found = IsSpotSafe(clientIdx, testPos, sizeMultiplier);
			}
		}
	}

	if (!found)
	{
		return false;
	}
	TeleportEntity(clientIdx, testPos, NULL_VECTOR, NULL_VECTOR);

	return true;
}

stock void constrainDistance(const float[] startPoint, float[] endPoint, float distance, float maxDistance)
{
	float constrainFactor = maxDistance / distance;
	endPoint[0] = ((endPoint[0] - startPoint[0]) * constrainFactor) + startPoint[0];
	endPoint[1] = ((endPoint[1] - startPoint[1]) * constrainFactor) + startPoint[1];
	endPoint[2] = ((endPoint[2] - startPoint[2]) * constrainFactor) + startPoint[2];
}

public bool IsSpotSafe(int clientIdx, float playerPos[3], float sizeMultiplier)
{
	ResizeTraceFailed = false;
	static float mins[3];
	static float maxs[3];
	mins[0] = -24.0 * sizeMultiplier;
	mins[1] = -24.0 * sizeMultiplier;
	mins[2] = 0.0;
	maxs[0] = 24.0 * sizeMultiplier;
	maxs[1] = 24.0 * sizeMultiplier;
	maxs[2] = 90.0 * sizeMultiplier;

	// the eight 45 degree angles and center, which only checks the z offset
	if (!Resize_TestResizeOffset(playerPos, mins[0], mins[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, mins[0], 0.0, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, mins[0], maxs[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, 0.0, mins[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, 0.0, 0.0, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, 0.0, maxs[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0], mins[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0], 0.0, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0], maxs[1], maxs[2])) return false;

	// 22.5 angles as well, for paranoia sake
	if (!Resize_TestResizeOffset(playerPos, mins[0], mins[1] * 0.5, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, mins[0], maxs[1] * 0.5, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0], mins[1] * 0.5, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0], maxs[1] * 0.5, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, mins[0] * 0.5, mins[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0] * 0.5, mins[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, mins[0] * 0.5, maxs[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0] * 0.5, maxs[1], maxs[2])) return false;

	// four square tests
	if (!Resize_TestSquare(playerPos, mins[0], maxs[0], mins[1], maxs[1], maxs[2])) return false;
	if (!Resize_TestSquare(playerPos, mins[0] * 0.75, maxs[0] * 0.75, mins[1] * 0.75, maxs[1] * 0.75, maxs[2])) return false;
	if (!Resize_TestSquare(playerPos, mins[0] * 0.5, maxs[0] * 0.5, mins[1] * 0.5, maxs[1] * 0.5, maxs[2])) return false;
	if (!Resize_TestSquare(playerPos, mins[0] * 0.25, maxs[0] * 0.25, mins[1] * 0.25, maxs[1] * 0.25, maxs[2])) return false;

	return true;
}

bool Resize_TestResizeOffset(const float bossOrigin[3], float xOffset, float yOffset, float zOffset)
{
	static float tmpOrigin[3];
	tmpOrigin[0] = bossOrigin[0];
	tmpOrigin[1] = bossOrigin[1];
	tmpOrigin[2] = bossOrigin[2];
	static float targetOrigin[3];
	targetOrigin[0] = bossOrigin[0] + xOffset;
	targetOrigin[1] = bossOrigin[1] + yOffset;
	targetOrigin[2] = bossOrigin[2];

	if (!(xOffset == 0.0 && yOffset == 0.0))
		if (!Resize_OneTrace(tmpOrigin, targetOrigin))
			return false;

	tmpOrigin[0] = targetOrigin[0];
	tmpOrigin[1] = targetOrigin[1];
	tmpOrigin[2] = targetOrigin[2] + zOffset;

	if (!Resize_OneTrace(targetOrigin, tmpOrigin))
		return false;

	targetOrigin[0] = bossOrigin[0];
	targetOrigin[1] = bossOrigin[1];
	targetOrigin[2] = bossOrigin[2] + zOffset;

	if (!(xOffset == 0.0 && yOffset == 0.0))
		if (!Resize_OneTrace(tmpOrigin, targetOrigin))
			return false;

	return true;
}

bool Resize_TestSquare(const float bossOrigin[3], float xmin, float xmax, float ymin, float ymax, float zOffset)
{
	static float pointA[3];
	static float pointB[3];
	for (int phase = 0; phase <= 7; phase++)
	{
		// going counterclockwise
		if (phase == 0)
		{
			pointA[0] = bossOrigin[0] + 0.0;
			pointA[1] = bossOrigin[1] + ymax;
			pointB[0] = bossOrigin[0] + xmax;
			pointB[1] = bossOrigin[1] + ymax;
		}
		else if (phase == 1)
		{
			pointA[0] = bossOrigin[0] + xmax;
			pointA[1] = bossOrigin[1] + ymax;
			pointB[0] = bossOrigin[0] + xmax;
			pointB[1] = bossOrigin[1] + 0.0;
		}
		else if (phase == 2)
		{
			pointA[0] = bossOrigin[0] + xmax;
			pointA[1] = bossOrigin[1] + 0.0;
			pointB[0] = bossOrigin[0] + xmax;
			pointB[1] = bossOrigin[1] + ymin;
		}
		else if (phase == 3)
		{
			pointA[0] = bossOrigin[0] + xmax;
			pointA[1] = bossOrigin[1] + ymin;
			pointB[0] = bossOrigin[0] + 0.0;
			pointB[1] = bossOrigin[1] + ymin;
		}
		else if (phase == 4)
		{
			pointA[0] = bossOrigin[0] + 0.0;
			pointA[1] = bossOrigin[1] + ymin;
			pointB[0] = bossOrigin[0] + xmin;
			pointB[1] = bossOrigin[1] + ymin;
		}
		else if (phase == 5)
		{
			pointA[0] = bossOrigin[0] + xmin;
			pointA[1] = bossOrigin[1] + ymin;
			pointB[0] = bossOrigin[0] + xmin;
			pointB[1] = bossOrigin[1] + 0.0;
		}
		else if (phase == 6)
		{
			pointA[0] = bossOrigin[0] + xmin;
			pointA[1] = bossOrigin[1] + 0.0;
			pointB[0] = bossOrigin[0] + xmin;
			pointB[1] = bossOrigin[1] + ymax;
		}
		else if (phase == 7)
		{
			pointA[0] = bossOrigin[0] + xmin;
			pointA[1] = bossOrigin[1] + ymax;
			pointB[0] = bossOrigin[0] + 0.0;
			pointB[1] = bossOrigin[1] + ymax;
		}

		for (int shouldZ = 0; shouldZ <= 1; shouldZ++)
		{
			pointA[2] = pointB[2] = shouldZ == 0 ? bossOrigin[2] : (bossOrigin[2] + zOffset);
			if (!Resize_OneTrace(pointA, pointB))
				return false;
		}
	}

	return true;
}

bool Resize_OneTrace(const float startPos[3], const float endPos[3])
{
	static float result[3];
	TR_TraceRayFilter(startPos, endPos, MASK_PLAYERSOLID, RayType_EndPoint, TraceAnything);
	if (ResizeTraceFailed)
	{
		return false;
	}
	TR_GetEndPosition(result);
	if (endPos[0] != result[0] || endPos[1] != result[1] || endPos[2] != result[2])
	{
		return false;
	}

	return true;
}

public bool TraceAnything(int entity, int contentsMask)
{
    return false;
}

public void ReAddPercentCharacter(char[] str, int buffer, int percentImplodeCount)
{
    char implode[32];
    for(int loop = 0; loop < percentImplodeCount; loop++)
        implode[loop] = '%';

    ReplaceString(str, buffer, "%", implode);
}

stock bool IsValidClient(int client)
{
    return (0<client && client<=MaxClients && IsClientInGame(client));
}
