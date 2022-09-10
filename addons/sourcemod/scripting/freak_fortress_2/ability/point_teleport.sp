/*
	"point_teleport"
	"slot"			"2"			// ability slot (2: In Unofficial FF2, to avoid view angle check.)
	"charge time"	"1.5"		// Only for Unofficial FF2.
	"arg1" 		"1000.0" 	// "rocket speed"
	"arg2"		"2.5"		// "rocket duration"
	"arg3"		"75.0"		// "portal size"
	"arg4"		"15.0"		// "portal duration"
	"arg5"		"600.0"		// "portal launch power"
	"arg6"		"2.0"		// "portal sound loop time"

	"arg7"		"eyeboss_death_vortex"							// "portal entrance paticle name"
	"arg8"		"eyeboss_vortex_blue"							// "portal exit paticle name"
	"arg9"		"misc/halloween/spell_athletic.wav"				// "portal open sound path"
	"arg10"		"potry_v2/saxton_hale/portal_loop.wav"			// "portal loop sound path"
	"arg11"		"misc/halloween/spell_spawn_boss_disappear.wav" // "portal close sound path"

	"arg12"		"weapons/teleporter_send.wav"					// "portal enter entrance sound path"
	"arg13"		"weapons/teleporter_receive.wav"				// "portal enter exit sound path"
*/
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2utils>
#include <freak_fortress_2>
#include <stocksoup/sdkports/util>

#tryinclude <ff2_modules/general>
#if !defined _ff2_fork_general_included
	#include <freak_fortress_2_subplugin>
#endif

#pragma newdecls required

#define PLUGIN_VERSION "20220803"

public Plugin myinfo=
{
	name = "Freak Fortress 2: Pointing Abilities",
	author = "Nopied◎",
	description = "Replace default Teleport ability",
	version = PLUGIN_VERSION,
};		

#if defined _ff2_fork_general_included
	#define PLUGIN_NAME						"pointing abilities"
	#define POINT_TELEPORT_NAME				"point teleport"

	#define PORTAL_ROCKET_SPEED_NAME		"rocket speed"
	#define PORTAL_ROCKET_DURATION_NAME		"rocket duration"
	#define PORTALS_SIZE_NAME				"portal size"
	#define PORTALS_DURATION_NAME			"portal duration"
	#define PORTALS_LAUNCH_POWER_NAME		"portal launch power"
	#define PORTALS_SOUND_LOOP_TIME_NAME	"portal sound loop time"

	#define PORTALS_ENTRANCE_PARTICLE_NAME	"portal entrance paticle name"
	#define PORTALS_EXIT_PARTICLE_NAME		"portal exit paticle name"
	#define PORTALS_OPEN_SOUND_PATH_NAME	"portal open sound path"
	#define PORTALS_LOOP_SOUND_PATH_NAME	"portal loop sound path"
	#define PORTALS_CLOSE_SOUND_PATH_NAME	"portal close sound path"

	#define PORTALS_ENTER_ENTRANCE_SOUND_PATH_NAME	"portal enter entrance sound path"
	#define PORTALS_EXIT_ENTRANCE_SOUND_PATH_NAME	"portal enter exit sound path"
#else
	#define PLUGIN_NAME						this_plugin_name
	#define POINT_TELEPORT_NAME				"point_teleport"

	#define PORTAL_ROCKET_SPEED_NAME		1
	#define PORTAL_ROCKET_DURATION_NAME		2
	#define PORTALS_SIZE_NAME				3
	#define PORTALS_DURATION_NAME			4
	#define PORTALS_LAUNCH_POWER_NAME		5
	#define PORTALS_SOUND_LOOP_TIME_NAME	6

	#define PORTALS_ENTRANCE_PARTICLE_NAME	7
	#define PORTALS_EXIT_PARTICLE_NAME		8
	#define PORTALS_OPEN_SOUND_PATH_NAME	9
	#define PORTALS_LOOP_SOUND_PATH_NAME	10
	#define PORTALS_CLOSE_SOUND_PATH_NAME	11

	#define PORTALS_ENTER_ENTRANCE_SOUND_PATH_NAME	12
	#define PORTALS_EXIT_ENTRANCE_SOUND_PATH_NAME	13
#endif

static const int WHITE_COLOR[4] = {255, 255, 255, 255};

#define SPHERE_MODEL		"models/props_gameplay/ball001.mdl"
#define EMPTY_MODEL		"models/empty.mdl"
// #define EMPTY_MODEL		"models/props_lakeside_event/vortex_lakeside2.mdl"

#define min(%1,%2)            (((%1) < (%2)) ? (%1) : (%2))
#define max(%1,%2)            (((%1) > (%2)) ? (%1) : (%2))

#define	MAX_EDICT_BITS		12
#define	MAX_EDICTS		(1 << MAX_EDICT_BITS)

#define DIST_EPSILON		0.03125

#define POINT_TELEPORT_REENTER_TIME		0.5 // Do not modify below 0.1.

#define ENTERFLAG_APPLY_WEAPONDISABLE 		(1<<0)
#define ENTERFLAG_APPLY_OFFSET 			(1<<1)

Handle jumpHUD;

int g_iBeamModel, g_iHaloModel;
float g_flTeleportDistance[MAXPLAYERS+1];
float g_flTeleportEnterCooldown[2049]; // MAX Entity Count

enum
{
	Portal_Owner,
	Portal_Size,
	Portal_LifeTime,
	Portal_BreakableIndex,
	Portal_InDuck,

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

	Portal_MAX
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
	property bool Ducked {
		public get() {
			return this.Get(Portal_InDuck);
		}
		public set(bool ducked) {
			this.Set(Portal_InDuck, ducked);
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

	public native void AddThisToList();

	public void DispatchTPEffect(float pos[3], float endPos[3])
	{
		float angles[3];

		SubtractVectors(pos, endPos, angles);
		GetVectorAngles(angles, angles);
		angles[0] = AngleNormalize(angles[0]);
		angles[1] = AngleNormalize(angles[1]);

		TE_DispatchEffect("merasmus_tp", endPos, endPos, angles);
		TE_SendToAll();

		TE_DispatchEffect("merasmus_tp_bits", endPos, endPos, angles);
		TE_SendToAll();

		TE_DispatchEffect("merasmus_tp_flash03", endPos, endPos, angles);
		TE_SendToAll();

		TE_DispatchEffect("merasmus_zap", pos, endPos, angles);
		TE_SendToAll();

		TE_DispatchEffect("merasmus_zap_beam03", pos, endPos, angles);
		TE_SendToAll();

		TE_DispatchEffect("merasmus_zap_beam_bits", pos, endPos, angles);
		TE_SendToAll();
	}

	public void Open()
	{
		float pos[3], endPos[3], angles[3];
		char entrancePaticleName[64], exitPaticleName[64];

		this.GetEntrancePosition(pos);
		this.GetExitPosition(endPos);

		SubtractVectors(pos, endPos, angles);
		GetVectorAngles(angles, angles);
		angles[0] = AngleNormalize(angles[0]);
		angles[1] = AngleNormalize(angles[1]);

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

		int func = CreateEntityByName("prop_physics_override");
		if(IsValidEntity(func))
		{
			SetEntProp(func, Prop_Data, "m_iMaxHealth", 10000);
			SetEntProp(func, Prop_Data, "m_iHealth", 10000);		

			SetEntityModel(func, SPHERE_MODEL);
			SetEntityRenderMode(func, RENDER_TRANSCOLOR);
			SetEntityRenderColor(func, 255, 255, 255, 0);

			SetEntProp(func, Prop_Data, "m_takedamage", 2);
			DispatchSpawn(func);

			// DispatchKeyValue(func, "propdata", "0");
			// DispatchKeyValue(func, "material", "0");

			static const float vecMin[3] = {-80.0, -80.0, -80.0}, vecMax[3] = {80.0, 80.0, 80.0};

			SetEntPropVector(func, Prop_Send, "m_vecMins", vecMin);
			SetEntPropVector(func, Prop_Send, "m_vecMaxs", vecMax);

			SetEntityMoveType(func, MOVETYPE_NONE);
			SetEntProp(func, Prop_Send, "m_CollisionGroup", 2); // 2 = COLLISION_GROUP_DEBRIS_TRIGGER
			// SetEntProp(func, Prop_Send, "m_usSolidFlags", 0x0084); // 0x0001: FSOLID_NOT_SOLID
			SetEntProp(func, Prop_Send, "m_nSolidType", 2); // 2: SOLID_BBOX
			SetEntPropFloat(func, Prop_Send, "m_flModelScale", 2.0);

			float funcPos[3];
			funcPos = pos;
			funcPos[2] += 48.0;

			TeleportEntity(func, pos, NULL_VECTOR, NULL_VECTOR);

			this.BreakableIndex = func;
			SDKHook(func, SDKHook_OnTakeDamagePost , Portal_OnTakeDamage);

			// PrintToServer("func: %d", func);
			this.AddThisToList();
		}

		this.SoundNextLoopTime = GetGameTime();

		int colors[4];
		if(!this.Ducked)
			colors = WHITE_COLOR;
		else
			colors = {255, 60, 60, 255};

		TE_SetupBeamPoints(pos, endPos, g_iBeamModel, g_iHaloModel, 0, 10, this.LifeTime - GetGameTime(), 2.0, 100.0, 10, 0.0, colors, 100);
		TE_SendToAll();

		DispatchParticleEffect(pos, angles, "bombonomicon_spell_trail", _, RoundFloat(this.LifeTime - GetGameTime()), this.ExitParticleIndex);

		RequestFrame(Portal_Update, this);
	}

	public void TeleportToExit(int ent, int flags)
	{
		float exitPos[3], angles[3], velocity[3];
		this.GetExitPosition(exitPos);

		if(ent <= MaxClients) // player
		{
			this.GetLaunchAngles(angles);
			ScaleVector(angles, this.LaunchPower);

			float currentPos[3];
			GetClientAbsOrigin(ent, currentPos);

			TeleportEntity(ent, exitPos, NULL_VECTOR, angles);
			UTIL_ScreenFade(ent, WHITE_COLOR, 0.1, 0.3, FFADE_IN);

			if(flags & ENTERFLAG_APPLY_WEAPONDISABLE)
				ApplyPlayerWeaponDisable(ent, 2.0);

			return;
		}
		
		// other entities
		float pos[3];

		GetEntPropVector(ent, Prop_Data, "m_vecOrigin", pos);
		GetEntPropVector(ent, Prop_Send, "m_angRotation", angles);
		GetEntPropVector(ent, Prop_Data, "m_vecVelocity", velocity);

		if(flags & ENTERFLAG_APPLY_OFFSET)
		{
			float startPos[3];
			this.GetEntrancePosition(startPos);

			SubtractVectors(startPos, pos, pos);
			SubtractVectors(exitPos, pos, exitPos);
		}

		float speed = GetVectorLength(velocity);
		if(speed <= 0.0)
			GetEntPropVector(ent, Prop_Send, "m_vInitialVelocity", velocity);

		TeleportEntity(ent, exitPos, angles, velocity);

		if(HasEntProp(ent, Prop_Send, "m_bTouched"))
			SetEntProp(ent, Prop_Send, "m_bTouched", 0);
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

methodmap CTFPortal_List < ArrayList
{
	// Yeah. linear search.
	public int SearchBreakable(int func)
	{
		int len = this.Length;
		for(int search = 0; search < len; search++)
		{
			CTFPortal tempPortal = this.Get(search);
			if(tempPortal.BreakableIndex == func)
				return search;
		}
		
		return -1;
	}

	public void DeleteFromThis(int func)
	{
		int index = this.SearchBreakable(func);
		if(index != -1)
			this.Erase(index);
	}
}

// LOL. There is no prototype definition in SourcePawn.
// This is the best spot for define this, I think..
CTFPortal_List g_hPortalList;

public void Portal_Update(CTFPortal portal)
{
	if(FF2_GetRoundState() != 1 || portal.LifeTime < GetGameTime())
	{
		g_hPortalList.DeleteFromThis(portal.BreakableIndex);
		portal.Close();
		return;
	}

	char sound[PLATFORM_MAX_PATH];
	float pos[3], exitPos[3];
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

	int target = -1;
	bool enter = false;
	
	while ((target = GetEntityInSpot(target, pos, portal.Size)) < 2048)
	{
		if(((IsValidClient(target) && g_flTeleportEnterCooldown[target] < GetGameTime()) 
			&& !TF2_IsPlayerInCondition(target, TFCond_Dazed)
			&& (!portal.Ducked || (portal.Ducked && GetEntProp(target, Prop_Send, "m_bDucked") > 0)))
			|| (target > MaxClients && IsValidEntity(target)))
		{
			enter = true;
			portal.TeleportToExit(target, ENTERFLAG_APPLY_OFFSET);
			break;
		}
	}

/* // SM 1.11
	TR_EnumerateEntitiesSphere(pos, portal.Size, PARTITION_TRIGGER_EDICTS, PortalFilter, portal);
	bool enter = TR_DidHit();
*/
	if(enter && g_flTeleportEnterCooldown[target] < GetGameTime())
	{
		g_flTeleportEnterCooldown[target] = GetGameTime() + POINT_TELEPORT_REENTER_TIME;
		portal.DispatchTPEffect(pos, exitPos);

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

public int Native_CTFPortal_Create(Handle plugin, int numParams)
{
	CTFPortal array = view_as<CTFPortal>(new ArrayList(PLATFORM_MAX_PATH, Portal_MAX));

	array.Owner = GetNativeCell(1);

	return view_as<int>(array);
}

public void Portal_OnTakeDamage(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	// PrintToServer("victim: %d, attacker: %d, damage: %.1f, damagetype: %d", victim, attacker, damage, damagetype);
	// PrintToServer("damageForce: %.1f %.1f %.1f, damagePosition: %.1f %.1f %.1f", damageForce[0], damageForce[1], damageForce[2], damagePosition[0], damagePosition[1], damagePosition[2]);
	
	if(!(damagetype & (DMG_BULLET | DMG_BUCKSHOT)))
		return;

	CTFPortal portal = g_hPortalList.Get(g_hPortalList.SearchBreakable(victim));

	float startPos[3], exitPos[3], angles[3];
	portal.GetEntrancePosition(startPos);
	portal.GetExitPosition(exitPos);

	SubtractVectors(startPos, damagePosition, angles);
	SubtractVectors(exitPos, angles, exitPos);
	float distance = GetVectorLength(angles);
	NormalizeVector(angles, angles);

	char effectName[64];
	GetBulletEffectName(TF2_GetClientTeam(attacker), effectName, sizeof(effectName));

	FireBullet(attacker, attacker, exitPos, angles, damage, distance * 500, damagetype, effectName);
}

// Is enum struct the best option?
methodmap SpotStacker < ArrayList
{
	// 0 ~ 2: position vector
	public int GetLastPosition(float pos[3])
	{
		int latest = this.Length - 1;
		ArrayList stackedPosition = this.Get(latest);

		for(int loop = 0; loop < 3; loop++)
			pos[loop] = stackedPosition.Get(loop);

		return latest;
	}

	public void StackPush(const float pos[3])
	{
		ArrayList stackposition = new ArrayList(_, 3);

		for(int loop = 0; loop < 3; loop++)
			stackposition.Set(loop, pos[loop]);

		if(this.Length >= 10)
		{
			ArrayList firstposition = this.Get(0);
			delete firstposition;

			this.Erase(0);
		}
		this.Push(stackposition);
	}

	public void KillSelf()
	{
		int len = this.Length;
		ArrayList temp;

		for(int loop = 0; loop < len; loop++)
		{
			temp = this.Get(loop);
			delete temp; 
		}

		delete this;
	}
}

enum 
{
	Rocket_Ref,
	Rocket_Owner,
	Rocket_PreviousSpots,
	Rocket_LifeTime,
	Rocket_Timer,

	Rocket_AnglesX,
	Rocket_AnglesY,
	Rocket_AnglesZ,

	Rocket_MAX
};

methodmap CTFPortalRocket < ArrayList
{
	public static native CTFPortalRocket Create(int owner);

	property int Ref {
		public get() {
			return this.Get(Rocket_Ref);
		}
		public set(int ref) {
			this.Set(Rocket_Ref, ref);
		}
	}

	property int Owner {
		public get() {
			return this.Get(Rocket_Owner);
		}
		public set(int owner) {
			this.Set(Rocket_Owner, owner);
		}
	}

	property SpotStacker PreviousSpots {
		public get() {
			return this.Get(Rocket_PreviousSpots);
		}
		public set(SpotStacker stack) {
			this.Set(Rocket_PreviousSpots, stack);
		}
	}

	property float LifeTime {
		public get() {
			return this.Get(Rocket_LifeTime);
		}
		public set(float time) {
			this.Set(Rocket_LifeTime, time);
		}
	}

	property Handle Timer {
		public get() {
			return this.Get(Rocket_Timer);
		}
		public set(Handle timer) {
			this.Set(Rocket_Timer, timer);
		}
	}

	public native void AddThisToList();

	public void KillSelf()
	{
		// This is supposed to use CTFPortalRocket_List.DeleteFromThis. But the code flow does not allow this.
		// so that moved to DeletePortalRocket (PortalRocket_Update, PortalRocket_Touch).
		
		Handle timer = this.Timer;
		if(timer != null) // TODO: check
			KillTimer(timer);

		SpotStacker temp = this.PreviousSpots;
		temp.KillSelf();

		delete this;
	}

	public void GetAngles(float angles[3])
	{
		for(int loop = 0; loop < 3; loop++)
		{
			int realIndex = loop + Rocket_AnglesX;
			angles[loop] = this.Get(realIndex);
		}
	}

	public void SetAngles(const float angles[3])
	{
		for(int loop = 0; loop < 3; loop++)
		{
			int realIndex = loop + Rocket_AnglesX;
			this.Set(realIndex, angles[loop]);
		}
	}

	public void Fire(float pos[3], float angles[3], float velocity[3])
	{
		this.SetAngles(angles);

		int rocket = SpawnRocket(this.Owner, pos, angles, velocity, 0.0, false);

		this.Ref = EntIndexToEntRef(rocket);
		this.AddThisToList();

		SetEntityModel(rocket, EMPTY_MODEL);
		SpawnParticle(pos, "spell_teleport_black", _, rocket);

		this.Timer = CreateTimer(0.2, PortalRocket_Update, this, TIMER_REPEAT); // NOTE: Don't add TIMER_FLAG_NO_MAPCHANGE.
		SDKHook(rocket, SDKHook_StartTouch, PortalRocket_Touch);
		SDKHook(rocket, SDKHook_Touch, PortalRocket_Touch);
	}
}

methodmap CTFPortalRocket_List < ArrayList
{
	// Yeah. linear search.
	public int SearchRocket(int ref)
	{
		int len = this.Length;
		for(int search = 0; search < len; search++)
		{
			CTFPortalRocket tempRocket = this.Get(search);
			if(tempRocket.Ref == ref)
				return search;
		}
		
		return -1;
	}

	public void DeleteFromThis(int ref)
	{
		int index = this.SearchRocket(ref);
		if(index != -1)
			this.Erase(index);
	}
}

// LOL. There is no prototype definition in SourcePawn.
// This is the best spot for define this, I think..
CTFPortalRocket_List g_hPortalRocketList; 

public Action PortalRocket_Update(Handle timer, CTFPortalRocket rocket)
{
	int index = EntRefToEntIndex(rocket.Ref);

	// index == -1 : invalid reference
	if(FF2_GetRoundState() != 1 || index == -1)
	{
		DeletePortalRocket(rocket);
		return Plugin_Stop;
	}
	
	SpotStacker spotStacker = rocket.PreviousSpots;
	float pos[3];
	
	GetEntPropVector(index, Prop_Data, "m_vecOrigin", pos);
	spotStacker.StackPush(pos);

	if(rocket.LifeTime < GetGameTime())
	{
		TryOpenPortal(rocket);
		
		DeletePortalRocket(rocket);
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public Action PortalRocket_Touch(int rocketIndex, int other)
{
	CTFPortalRocket rocket = 
		g_hPortalRocketList.Get(g_hPortalRocketList.SearchRocket(EntIndexToEntRef(rocketIndex)));

	SpotStacker spotStacker = rocket.PreviousSpots;
	float endPos[3], vecMin[3], vecMax[3];

	GetEntPropVector(rocketIndex, Prop_Data, "m_vecOrigin", endPos);
	GetEntPropVector(rocketIndex, Prop_Send, "m_vecMins", vecMin);
	GetEntPropVector(rocketIndex, Prop_Send, "m_vecMins", vecMax);

	// TODO: 최소한의 좌표 보정
	spotStacker.StackPush(endPos);
	TryOpenPortal(rocket);

	DeletePortalRocket(rocket);
	return Plugin_Continue;
}

void DeletePortalRocket(CTFPortalRocket rocket)
{
	// LogStackTrace("DeletePortalRocket Called");

	int rocketIndex = EntRefToEntIndex(rocket.Ref);
	if(rocketIndex != -1)
		RemoveEntity(rocketIndex);

	g_hPortalRocketList.DeleteFromThis(rocket.Ref);
	rocket.KillSelf();
}

public int Native_CTFPortalRocket_Create(Handle plugin, int numParams)
{
	CTFPortalRocket array = view_as<CTFPortalRocket>(new ArrayList(_, Rocket_MAX));

	array.Owner = GetNativeCell(1);
	array.PreviousSpots = view_as<SpotStacker>(new ArrayList()); 
	array.Timer = view_as<Handle>(0); // 0 = null 

	return view_as<int>(array);
}

public int Native_CTFPortal_AddThisToList(Handle plugin, int numParams)
{
	CTFPortal rocket = GetNativeCell(1);

	g_hPortalList.Push(rocket);
	return 0;
}

public int Native_CTFPortalRocket_AddThisToList(Handle plugin, int numParams)
{
	CTFPortalRocket rocket = GetNativeCell(1);

	g_hPortalRocketList.Push(rocket);
	return 0;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("CTFPortal.Create", Native_CTFPortal_Create);
	CreateNative("CTFPortalRocket.Create", Native_CTFPortalRocket_Create);

	CreateNative("CTFPortal.AddThisToList", Native_CTFPortal_AddThisToList);
	CreateNative("CTFPortalRocket.AddThisToList", Native_CTFPortalRocket_AddThisToList);

	return APLRes_Success;
}

#if defined _ff2_fork_general_included
public void OnPluginStart()
#else
public void OnPluginStart2()
#endif
{

	jumpHUD = CreateHudSynchronizer();
	if(jumpHUD == null)
		ThrowError("Failed to create HudSynchronizer");

	HookEvent("teamplay_round_start", OnRoundStart);

	LoadTranslations("ff2_point_teleport.phrases");

	// Wait.. Should reload on map change?
	g_hPortalRocketList = view_as<CTFPortalRocket_List>(new ArrayList()); 
	g_hPortalList = view_as<CTFPortal_List>(new ArrayList());

#if defined _ff2_fork_general_included
	FF2_RegisterSubplugin(PLUGIN_NAME);
#endif
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

	PrecacheEffect("ParticleEffect");
	PrecacheParticleEffect("bombonomicon_spell_trail");
	PrecacheParticleEffect("merasmus_tp");
	PrecacheParticleEffect("merasmus_tp_bits");
	PrecacheParticleEffect("merasmus_tp_flash03");
	PrecacheParticleEffect("merasmus_zap");
	PrecacheParticleEffect("merasmus_zap_beam03");
	PrecacheParticleEffect("merasmus_zap_beam_bits");

	PrecacheParticleEffect("bullet_pistol_tracer01_red_crit");
	PrecacheParticleEffect("bullet_pistol_tracer01_blue_crit");

	PrecacheParticleEffect("impact_dirt");
	PrecacheParticleEffect("blood_impact_heavy");

	PrecacheModel(SPHERE_MODEL, true);
	PrecacheModel(EMPTY_MODEL, true);
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for(int ent = 1; ent <= 2048; ent++)
	{
		g_flTeleportEnterCooldown[ent] = 0.0;
	}

	return Plugin_Continue;
}

#if defined _ff2_fork_general_included
public void FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status)
#else
public Action FF2_OnAbility2(int boss, const char[] pluginName, const char[] abilityName, int status)
#endif
{
#if defined _FFBAT_included
	int slot = FF2_GetArgNamedI(boss, pluginName, abilityName, "slot");	
#elseif !defined _ff2_fork_general_included
	int slot = FF2_GetAbilityArgument(boss, pluginName, abilityName, 0);
#endif

	if(!StrEqual(pluginName, PLUGIN_NAME, false))
		return;

	if(StrEqual(abilityName, POINT_TELEPORT_NAME, false))
		Charge_Teleport(boss, status, slot);

}


#if defined _ff2_fork_general_included
public void FF2_OnCalledQueue(FF2HudQueue hudQueue, int client)
{
	int boss = FF2_GetBossIndex(client);
	if(boss == -1)
		return;

	bool hasCharge = FF2_HasAbility(boss, PLUGIN_NAME, POINT_TELEPORT_NAME);

	char text[256];
	FF2HudDisplay hudDisplay = null;

	SetGlobalTransTarget(client);
	hudQueue.GetName(text, sizeof(text));

	if(StrEqual(text, "Boss Down Additional") && hasCharge)
	{
		int slot = FF2_GetAbilityArgument(boss, PLUGIN_NAME, POINT_TELEPORT_NAME, "slot");
		float charge = FF2_GetBossCharge(boss, slot);

		if(charge < 0.0)
			Format(text, sizeof(text), "%t", "Teleportation Cooldown", -RoundFloat(charge));
		else
		{
			// 힌트 HUD
			{
				SetHudTextParams(-1.0, 0.92, 0.12, 255, 255, 255, 255);

				Format(text, sizeof(text), "%t", "Point Teleportation Hint");
				ReAddPercentCharacter(text, sizeof(text), 4);

				FF2_ShowHudText(client, FF2HudChannel_Other, text);
				SetHudTextParams(-1.0, 0.88, 0.12, 255, 255, 255, 255);
			}

			
			Format(text, sizeof(text), "%t", "Point Teleportation Charge", RoundFloat(charge));

			// 분리
			int buttonMode = FF2_GetAbilityArgument(boss, PLUGIN_NAME, POINT_TELEPORT_NAME, "buttonmode", 0);
			Format(text, sizeof(text), "%s (%t)", text, buttonMode == 2 ? "Reload" : "Right Click");
		}

		hudDisplay = FF2HudDisplay.CreateDisplay("Point Teleportation", text);
		hudQueue.AddHud(hudDisplay, client);
	}
}
#endif

void Charge_Teleport(int boss, int status, int slot = -3)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));
	float charge = FF2_GetBossCharge(boss, slot);

	float vecMin[3], vecMax[3];
	GetEntPropVector(client, Prop_Send, "m_vecMins", vecMin);
	GetEntPropVector(client, Prop_Send, "m_vecMaxs", vecMax);

	switch(status)
	{
// !defined
#if !defined _ff2_fork_general_included 
		case 1:
		{
			SetHudTextParams(-1.0, 0.88, 0.15, 255, 255, 255, 255);
			FF2_ShowHudText(client, -1, "%t", "Teleportation Cooldown", -RoundFloat(charge));
		}
#endif
		case 0, 2:
		{
			SetHudTextParams(-1.0, 0.88, 0.15, 255, 255, 255, 255);

// !defined
#if defined _FFBAT_included
			char message[256];
			int buttonMode = FF2_GetArgNamedI(boss, PLUGIN_NAME, POINT_TELEPORT_NAME, "buttonmode", 0);
			Format(message, sizeof(message), "%t", "Point Teleportation Charge", RoundFloat(charge));
			Format(message, sizeof(message), "%s (%t)", message, buttonMode == 2 ? "Reload" : "Right Click");
			Format(message, sizeof(message), "%s\n%t", message, "Point Teleportation Hint");
			ReAddPercentCharacter(message, sizeof(message), 2);
			FF2_ShowSyncHudText(client, jumpHUD, "%s", message);
#elseif !defined _ff2_fork_general_included 
			char message[256];
			// char buttonText[32];
			// int buttonMode = FF2_GetAbilityArgument(boss, this_plugin_name, POINT_TELEPORT_NAME, "buttonmode", 0, slot);
			// Format(buttonText, sizeof(buttonText), "%t", buttonMode == 2 ? "Reload" : "Right Click");
			// Format(message, sizeof(message), "%t (%s)", "Point Teleportation Charge", RoundFloat(charge), buttonText);
			Format(message, sizeof(message), "%t", "Point Teleportation Charge", RoundFloat(charge));
			Format(message, sizeof(message), "%s\n%t", message, "Point Teleportation Hint");
			ReAddPercentCharacter(message, sizeof(message), 2);
			FF2_ShowSyncHudText(client, jumpHUD, "%s", message);
#endif
			float maxDistance = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, POINT_TELEPORT_NAME, PORTAL_ROCKET_SPEED_NAME, 1000.0);
			g_flTeleportDistance[client] = maxDistance * (charge * 0.01);
		}
		case 3:
		{
			if(slot == 0)
				g_flTeleportDistance[client] = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, POINT_TELEPORT_NAME, PORTAL_ROCKET_SPEED_NAME, 1000.0);

			// Throw rocket (portal gate)
			char abilitySound[PLATFORM_MAX_PATH];
			float eyePos[3], startPos[3], angles[3], velocity[3], endPos[3];
			GetClientEyePosition(client, eyePos);
			GetClientEyeAngles(client, angles);
			
#if defined _ff2_fork_general_included 
			if(FF2_FindSound("ability", abilitySound, PLATFORM_MAX_PATH, boss, true, slot))
#else 
			if(FF2_RandomSound("sound_point_teleport_rocket", abilitySound, PLATFORM_MAX_PATH, boss, slot))
#endif
			{
#if defined _ff2_fork_general_included 
				if(FF2_CheckSoundFlags(client, FF2SOUND_MUTEVOICE))
#endif		
				{
					EmitSoundToAll(abilitySound, client, _, _, _, 1.0, _, client, eyePos);
					EmitSoundToAll(abilitySound, client, _, _, _, 1.0, _, client, eyePos);
				}

				for(int target=1; target<=MaxClients; target++)
				{
					if(IsClientInGame(target) && target != client)
					{
#if defined _ff2_fork_general_included 
						if(FF2_CheckSoundFlags(target, FF2SOUND_MUTEVOICE))
#endif
						{
							EmitSoundToClient(target, abilitySound, client, _, _, _, _, _, client, eyePos);
							EmitSoundToClient(target, abilitySound, client, _, _, _, _, _, client, eyePos);
						}
					}
				}
			}

			CTFPortalRocket rocket = CTFPortalRocket.Create(client);
			rocket.LifeTime = GetGameTime() 
				+ FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, POINT_TELEPORT_NAME, PORTAL_ROCKET_DURATION_NAME, 2.5);
			
			// Effect Position
			{
				float fwd[3], right[3], up[3], sum[3];
				GetAngleVectors(angles, fwd, right, up);

				ScaleVector(up, -15.0);
				ScaleVector(right, 15.0);
				// ScaleVector(fwd, 25.0);
				AddVectors(up, right, sum);
				// AddVectors(sum, fwd, sum);
				AddVectors(eyePos, sum, startPos);

				NormalizeVector(fwd, endPos);
				NormalizeVector(fwd, velocity);
				ScaleVector(endPos, g_flTeleportDistance[client]);

				AddVectors(endPos, startPos, endPos);
				SubtractVectors(endPos, startPos, endPos);

				GetVectorAngles(endPos, angles);
				GetAngleVectors(angles, velocity, NULL_VECTOR, NULL_VECTOR);
				ScaleVector(velocity, g_flTeleportDistance[client]);
			}

			rocket.Fire(startPos, angles, velocity);
			// SpawnParticle(endPos, "eyeboss_tp_vortex");		// 이건 블랙홀 이펙트
			// SpawnParticle(endPos, "eyeboss_doorway_vortex"); // 이거 뭔가 차징 이펙트로 써볼만 한듯
		}
	}
}

void TryOpenPortal(CTFPortalRocket rocket)
{
	int owner = rocket.Owner;

	float currentPos[3], endPos[3], angles[3];
	float vecMin[3], vecMax[3];
	SpotStacker spotStacker = rocket.PreviousSpots;
	
	GetClientEyePosition(owner, currentPos);
	rocket.GetAngles(angles);
	GetAngleVectors(angles, angles, NULL_VECTOR, NULL_VECTOR);
	// NormalizeVector(angles, angles);

	GetEntPropVector(owner, Prop_Send, "m_vecMins", vecMin);
	GetEntPropVector(owner, Prop_Send, "m_vecMaxs", vecMax);

	bool stuck = true, initPosCheck = false;
	// int test = 0;

	do
	{
		// test++;
		int stackLastIndex = spotStacker.GetLastPosition(endPos);
		if(stackLastIndex == -1)
			return;

		TR_TraceRayFilter(currentPos, endPos, MASK_ALL, RayType_EndPoint, TraceAnything, owner);
		if(TR_DidHit())
		{
			spotStacker.Erase(stackLastIndex);
			continue;
		}

		stuck = IsStockInPosition(owner, endPos, vecMin, vecMax);
		if(!stuck)
			break;	

		if(!initPosCheck)
		{
			initPosCheck = true;
			CorrectCurrentPos(owner, endPos, angles, vecMin, vecMax, endPos);

			stuck = IsStockInPosition(owner, endPos, vecMin, vecMax);
			if(!stuck)
				break;
		}
		
		spotStacker.Erase(stackLastIndex);
	}
	while(spotStacker.Length > 0);

	// PrintToChatAll("final check: %s (on: %i)", !stuck ? "passed" : "blocked", test);
	if(!stuck)
		CreateAndOpenPortalByPlayer(owner, endPos);
}

public bool CorrectCurrentPos(int client, float currentPos[3], float angles[3], float vecMin[3], float vecMax[3], float result[3])
{
	float initPos[3], normal[3];

	TestFloorNormal(client, currentPos, angles, vecMin, vecMax, initPos, normal);

	// PrintToChatAll("initPos: %.1f %.1f %.1f", initPos[0], initPos[1], initPos[2]);
	// PrintToChatAll("angles: %.1f %.1f %.1f", angles[0], angles[1], angles[2]);

	if(!IsStockInPosition(client, initPos, vecMin, vecMax))
	{
		result = initPos;
		return true;
	}

	// tempAngles = angles;

	int rank[2];
	bool IsBackward[2];
	{
		bool usingNormal = normal[0] != 0.0 || normal[1] != 0.0;
		float realValue[2];

		for(int axis = 0; axis < 2; axis++)
		{
			realValue[axis] = usingNormal ? normal[axis] : angles[axis];
			IsBackward[axis] = usingNormal ? (realValue[axis] > 0.0) : (realValue[axis] < 0.0);
		}
		
		// PrintToChatAll("using normal: %.1f %.1f %.1f", normal[0], normal[1], normal[2]);
		// PrintToChatAll("using angles: %.1f %.1f %.1f", angles[0], angles[1], angles[2]);
		
		if(FloatAbs(realValue[0]) > FloatAbs(realValue[1]))
		{
			rank[0] = 0;
			rank[1] = 1;
		}
		// But, what would we do if this 0?
		else
		{
			rank[0] = 1;
			rank[1] = 0;
		}

		// PrintToChatAll("rank: %i %i, IsBackward: %s %s", rank[0], rank[1], IsBackward[0] ? "true" : "false", IsBackward[1] ? "true" : "false");
	}

	for(int testHeight = 0; testHeight < 2; testHeight++)
	{
		bool testYaxis = testHeight > 0;
		float testStart[3], testEnd[3];

		testStart = initPos;
		testEnd = initPos;

		testEnd[rank[0]] += IsBackward[rank[0]] ? vecMin[rank[0]] : vecMax[rank[0]];
		if(testYaxis)
		{
			testEnd[2] += vecMax[2];
		}
			
		AdjustPositionBySingleRay(client, testStart, testStart, testEnd, testStart);
		if(testYaxis)
		{
			float temp[3];
			temp = testStart;

			temp[2] += vecMax[2];
			testEnd[2] -= vecMax[2];

			AdjustPositionBySingleRay(client, testStart, temp, testEnd, testStart);
			
		}


		// PrintToChatAll("%.1f %.1f %.1f", testStart[0], testStart[1], testStart[2]);

		testEnd = testStart;
		testEnd[rank[0]] += IsBackward[rank[0]] ? vecMin[rank[0]] : vecMax[rank[0]];
		testEnd[rank[1]] += vecMax[rank[1]];
		if(testYaxis)
			testEnd[2] += vecMax[2];
		AdjustPositionBySingleRay(client, testStart, testStart, testEnd, testStart);
		if(testYaxis)
		{
			float temp[3];
			temp = testStart;

			temp[2] += vecMax[2];
			testEnd[2] -= vecMax[2];

			AdjustPositionBySingleRay(client, testStart, temp, testEnd, testStart);
			
		}

		
		// PrintToChatAll("TR_StartSolid: %s", TR_StartSolid() ? "true" : "false");
		// PrintToChatAll("%.1f %.1f %.1f", testStart[0], testStart[1], testStart[2]);

		// testStart[rank[0]] += IsBackward[rank[0]] ? vecMin[rank[0]] : vecMax[rank[0]];

		// testEnd = testStart;
		// testStart[rank[1]] += vecMin[rank[1]];
		// testEnd[rank[1]] += vecMax[rank[1]];
		// AdjustPositionBySingleRay(client, testStart, testStart, testEnd, testStart);

		// PrintToChatAll("TR_AllSolid: %s", TR_AllSolid() ? "true" : "false");

		testEnd = testStart;
		testEnd[rank[0]] += IsBackward[rank[0]] ? vecMin[rank[0]] : vecMax[rank[0]];
		testEnd[rank[1]] += vecMin[rank[1]];
		if(testYaxis)
			testEnd[2] += vecMax[2];
		AdjustPositionBySingleRay(client, testStart, testStart, testEnd, testStart);
		if(testYaxis)
		{
			float temp[3];
			temp = testStart;

			temp[2] += vecMax[2];
			testEnd[2] -= vecMax[2];

			AdjustPositionBySingleRay(client, testStart, temp, testEnd, testStart);
			
		}

		// PrintToChatAll("TR_StartSolid: %s", TR_StartSolid() ? "true" : "false");
		// PrintToChatAll("%.1f %.1f %.1f", testStart[0], testStart[1], testStart[2]);

		// float temp = testStart[rank[1]];
		// testStart[rank[1]] = testEnd[rank[1]];
		// testEnd[rank[1]] = temp;
		// AdjustPositionBySingleRay(client, testStart, testStart, testEnd, testStart);

		// PrintToChatAll("TR_AllSolid: %s", TR_AllSolid() ? "true" : "false");


		if(!IsStockInPosition(client, testStart, vecMin, vecMax))
		{
			result = testStart;
			return true;
		}
	}

	
/*
	ScaleVector(tempAngles, 1.0);
	AddVectors(endPos, tempAngles, endPos);

	TR_TraceRayFilter(initPos, endPos, MASK_ALL, RayType_EndPoint, TraceAnything, client);
	TR_GetEndPosition(initPos);
*/
	// TODO: 충돌 이면 false 반환
	return false;
}

public void TestFloorNormal(int client, float currentPos[3], float angles[3], float vecMin[3], float vecMax[3], float result[3], float normal[3])
{
	float initPos[3], endPos[3], tempAngles[3];

	// 이게 얕은 복사가 맞던가?
	initPos = currentPos;
	endPos = currentPos;
	tempAngles = angles;

	// -5.0, 4.2(* 5.0) = 21.0 = Hull side size (default)
	// 0.0135 = Epsilon, Just in case
	ScaleVector(tempAngles, -5.0);
	AddVectors(initPos, tempAngles, initPos);

	ScaleVector(tempAngles, -(4.2 + 0.0135));
	AddVectors(endPos, tempAngles, endPos);

	TR_TraceRayFilter(initPos, endPos, MASK_ALL, RayType_EndPoint, TraceAnything, client);
	TR_GetEndPosition(initPos);

	TR_GetPlaneNormal(null, normal);

	tempAngles = angles;
	ScaleVector(tempAngles, -15.0);
	AddVectors(initPos, tempAngles, initPos);

	if(0.3 < normal[2] && normal[2] < 1.0) 
	{
		float maxHeight = 0.0;
		for(int search = 0; search < 2; search++)
		{
			maxHeight = max(FloatAbs(normal[search]), maxHeight);
		}

		initPos[2] += (vecMax[2] - vecMin[2]) * maxHeight;
	}
	else if(normal[2] < 0.0 && TR_GetSurfaceFlags() & SURF_SKY) // NOTE: some ceiling has 0.0 (same as perfect floor)
	{
		// skybox or ceiling
		initPos[2] -= vecMax[2];
	}
/*
	else 
		initPos[2] += 1.0;
*/
	result = initPos;
}

public void AdjustPositionBySingleRay(int ent, float currentPos[3], float startPos[3], float endPos[3], float result[3])
{
	float temp[3];
	TR_TraceRayFilter(startPos, endPos, MASK_ALL, RayType_EndPoint, TraceAnything, ent);
	TR_GetEndPosition(temp);

	result = currentPos; 
	if(TR_DidHit() && !TR_StartSolid() && !TR_AllSolid())
	{
		for(int index = 0; index < 3; index++)
		{
			result[index] -= endPos[index] - temp[index];
			// PrintToChatAll("create gap %i: %.1f", index, endPos[index] - temp[index]);
		}
	}
/*
	static int colors[4] = {0, 255, 0, 255};

	float zeroVec[3];
	TE_SetupArmorRicochet(currentPos, zeroVec);
	TE_SendToClient(ent);

	TE_SetupBeamPoints(currentPos, endPos, g_iBeamModel, g_iHaloModel, 0, 10, 20.0, 10.0, 30.0, 0, 0.0, colors, 10);
	TE_SendToClient(ent);
*/
	// colors = {255, 0, 0, 255};
	// TE_SetupBeamPoints(endPos, result, g_iBeamModel, g_iHaloModel, 0, 10, 20.0/*0.1*/, 10.0, 30.0, 0, 0.0, colors, 10);
	// TE_SendToClient(ent);
}

CTFPortal CreateAndOpenPortalByPlayer(int player, float endPos[3], int abilitySlot = -3)
{
	CTFPortal portal = CTFPortal.Create(player);

	// only boss can use this... for now.
	int boss = FF2_GetBossIndex(player);
	if(boss != -1)
		ApplyPortalBossConfig(boss, portal, abilitySlot);

	float currentPos[3];
	GetEntPropVector(player, Prop_Data, "m_vecOrigin", currentPos);

	float fwd[3];
	GetClientEyeAngles(player, fwd);
	GetAngleVectors(fwd, fwd, NULL_VECTOR, NULL_VECTOR);

	portal.SetLaunchAngles(fwd);
	portal.SetEntrancePosition(currentPos);
	portal.SetExitPosition(endPos);

	portal.Ducked = GetEntProp(player, Prop_Send, "m_bDucked") > 0;

	ScaleVector(fwd, portal.LaunchPower);
	TeleportEntity(player, endPos, NULL_VECTOR, fwd);

	SetEntProp(player, Prop_Send, "m_bDucked", 1);
	SetEntityFlags(player, GetEntityFlags(player)|FL_DUCKING);

	portal.Open();
	portal.DispatchTPEffect(currentPos, endPos); // 보스가 이미 통과함

	portal.TeleportToExit(player, ENTERFLAG_APPLY_WEAPONDISABLE);

	return portal;
}

public void ApplyPortalBossConfig(int boss, CTFPortal portal, int slot)
{
	float size = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, POINT_TELEPORT_NAME, PORTALS_SIZE_NAME, 75.0),
		lifeTime = GetGameTime() + FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, POINT_TELEPORT_NAME, PORTALS_DURATION_NAME, 15.0),
		launchPower = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, POINT_TELEPORT_NAME, PORTALS_LAUNCH_POWER_NAME, 600.0),
		soundLoopTime = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, POINT_TELEPORT_NAME, PORTALS_SOUND_LOOP_TIME_NAME, 2.0);

	char entrancePaticleName[64], exitPaticleName[64],
		openSound[PLATFORM_MAX_PATH], loopSound[PLATFORM_MAX_PATH], closeSound[PLATFORM_MAX_PATH],
		enterEntranceSound[PLATFORM_MAX_PATH], enterExitSound[PLATFORM_MAX_PATH];

	FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, POINT_TELEPORT_NAME, PORTALS_ENTRANCE_PARTICLE_NAME, entrancePaticleName, sizeof(entrancePaticleName));
	FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, POINT_TELEPORT_NAME, PORTALS_EXIT_PARTICLE_NAME, exitPaticleName, sizeof(exitPaticleName));
	FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, POINT_TELEPORT_NAME, PORTALS_OPEN_SOUND_PATH_NAME, openSound, PLATFORM_MAX_PATH);
	FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, POINT_TELEPORT_NAME, PORTALS_LOOP_SOUND_PATH_NAME, loopSound, PLATFORM_MAX_PATH);
	FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, POINT_TELEPORT_NAME, PORTALS_CLOSE_SOUND_PATH_NAME, closeSound, PLATFORM_MAX_PATH);
	FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, POINT_TELEPORT_NAME, PORTALS_ENTER_ENTRANCE_SOUND_PATH_NAME, enterEntranceSound, PLATFORM_MAX_PATH);
	FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, POINT_TELEPORT_NAME, PORTALS_EXIT_ENTRANCE_SOUND_PATH_NAME, enterExitSound, PLATFORM_MAX_PATH);

	portal.Size = size;
	portal.LifeTime = lifeTime;
	portal.LaunchPower = launchPower;
	portal.SoundLoopTime = soundLoopTime;

	portal.SetEntranceParticleName(entrancePaticleName);
	portal.SetExitParticleName(exitPaticleName);

	portal.SetOpenSound(openSound);
	portal.SetLoopSound(loopSound);
	portal.SetOpenSound(closeSound);
	portal.SetEnterEntranceSound(enterEntranceSound);
	portal.SetEnterExitSound(enterExitSound);
}

public void GetBulletEffectName(TFTeam team, char[] name, int _buffer)
{
	switch(team)
	{
		case TFTeam_Red:
		{
			Format(name, _buffer, "bullet_pistol_tracer01_red_crit");
		}
		case TFTeam_Blue:
		{
			Format(name, _buffer, "bullet_pistol_tracer01_blue_crit");
		}
	}
}

stock void ApplyPlayerWeaponDisable(int client, float time = 2.0)
{
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(IsValidEntity(weapon))
		SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + time);

	SetEntPropFloat(client, Prop_Send, "m_flNextAttack", GetGameTime()+time);
	SetEntPropFloat(client, Prop_Send, "m_flStealthNextChangeTime", GetGameTime() + time);
}

stock int SpawnParticle(float pos[3], char[] particleType, float offset=0.0, int attachToEntity = -1)
{
	int particle=CreateEntityByName("info_particle_system");

	char targetName[128];
	pos[2]+=offset;
	TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
	DispatchKeyValue(particle, "targetname", "tf2particle");
	
	DispatchKeyValue(particle, "effect_name", particleType);
	DispatchSpawn(particle);
	SetVariantString(targetName);

	if(attachToEntity > 0)
	{
		Format(targetName, sizeof(targetName), "target%i", attachToEntity);
		DispatchKeyValue(attachToEntity, "targetname", targetName);
		DispatchKeyValue(particle, "parentname", targetName);

		SetVariantString(targetName);
		AcceptEntityInput(particle, "SetParent", particle, particle, 0);
		SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", attachToEntity);
	}

	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
	return particle;
}

stock int SpawnRocket(int owner, float origin[3], float angles[3], float velocity[3], float damage, bool allowcrit)
{
	int ent=CreateEntityByName("tf_projectile_rocket");
	if(!IsValidEntity(ent))
		return -1;

	int clientTeam = GetClientTeam(owner);
	int damageOffset = FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4;

	SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", owner);
	SetEntProp(ent, Prop_Send, "m_bCritical", allowcrit ? 1 : 0);
	SetEntProp(ent, Prop_Send, "m_iTeamNum", clientTeam);

	SetEntProp(ent, Prop_Send, "m_CollisionGroup", 0);
	// SetEntProp(ent, Prop_Send, "m_usSolidFlags", 0x284); 
	// SetEntProp(ent, Prop_Send, "m_nSolidType", 2); // SOLID_BBOX

	SetEntProp(ent, Prop_Data, "m_takedamage", 0);
	// SetEntPropEnt(ent, Prop_Send, "m_nForceBone", -1);

	float zeroVec[3];
	SetEntPropVector(ent, Prop_Send, "m_vecMins", zeroVec);
	SetEntPropVector(ent, Prop_Send, "m_vecMaxs", zeroVec);

	SetEntDataFloat(ent, damageOffset, damage); // set damage
	SetVariantInt(clientTeam);
	AcceptEntityInput(ent, "TeamNum", -1, -1, 0);
	SetVariantInt(clientTeam);
	AcceptEntityInput(ent, "SetTeam", -1, -1, 0);
	DispatchSpawn(ent);
	SetEntPropEnt(ent, Prop_Send, "m_hOriginalLauncher", GetEntPropEnt(owner, Prop_Send, "m_hActiveWeapon"));
	SetEntPropEnt(ent, Prop_Send, "m_hLauncher", GetEntPropEnt(owner, Prop_Send, "m_hActiveWeapon"));

	TeleportEntity(ent, origin, angles, velocity);
	return ent;
}

int GetParticleEffectIndex(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;

	if (table == INVALID_STRING_TABLE)
		table = FindStringTable("ParticleEffectNames");

	int iIndex = FindStringIndex(table, sEffectName);

	if (iIndex != INVALID_STRING_INDEX)
		return iIndex;

	return 0;
}

int GetEffectIndex(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;

	if (table == INVALID_STRING_TABLE)
		table = FindStringTable("EffectDispatch");

	int iIndex = FindStringIndex(table, sEffectName);

	if (iIndex != INVALID_STRING_INDEX)
		return iIndex;

	return 0;
}

void PrecacheEffect(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;

	if (table == INVALID_STRING_TABLE)
		table = FindStringTable("EffectDispatch");

	bool save = LockStringTables(false);
	AddToStringTable(table, sEffectName);
	LockStringTables(save);
}

void PrecacheParticleEffect(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;

	if (table == INVALID_STRING_TABLE)
		table = FindStringTable("ParticleEffectNames");

	bool save = LockStringTables(false);
	AddToStringTable(table, sEffectName);
	LockStringTables(save);
}

void TE_DispatchEffect(const char[] particle, const float pos[3], const float endpos[3], const float angles[3] = NULL_VECTOR, int parent = -1, int attachment = -1)
{
	TE_Start("EffectDispatch");
	TE_WriteVector("m_vStart[0]", pos);
	TE_WriteVector("m_vOrigin[0]", endpos);
	TE_WriteVector("m_vAngles", angles);
	TE_WriteNum("m_nHitBox", GetParticleEffectIndex(particle));
	TE_WriteNum("m_iEffectName", GetEffectIndex("ParticleEffect"));

	if(parent != -1)
	{
		TE_WriteNum("entindex", parent);
	}
	if(attachment != -1)
	{
		TE_WriteNum("m_nAttachmentIndex", attachment);
	}
}

stock int DispatchParticleEffect(float pos[3], float angles[3], char[] particleType, int parent=0, int time=1, int controlpoint=0)
{
	int particle = CreateEntityByName("info_particle_system");

	char temp[64], targetName[64];
	if (IsValidEdict(particle))
	{
		TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);

		Format(targetName, sizeof(targetName), "tf2particle%i", particle);
		DispatchKeyValue(particle, "targetname", targetName);
		DispatchKeyValue(particle, "effect_name", particleType);

		// Only one???
		if(controlpoint > 0)
		{
			// TODO: This shit does not work.
			int cpParticle = CreateEntityByName("info_particle_system");
			if (IsValidEdict(cpParticle))
			{
				char cpName[64], cpTargetName[64];
				Format(cpTargetName, sizeof(cpTargetName), "target%i", controlpoint);
				DispatchKeyValue(controlpoint, "targetname", cpTargetName);
				DispatchKeyValue(cpParticle, "parentname", cpTargetName);

				Format(cpName, sizeof(cpName), "tf2particle%i", cpParticle);
				DispatchKeyValue(cpParticle, "targetname", cpName);

				DispatchKeyValue(particle, "cpoint1", cpName);

				float cpPos[3];
				GetEntPropVector(controlpoint, Prop_Data, "m_vecOrigin", cpPos);
				TeleportEntity(cpParticle, cpPos, angles, NULL_VECTOR);
			}
		}

		DispatchSpawn(particle);
		ActivateEntity(particle);

		if(parent > 0)
		{
			Format(targetName, sizeof(targetName), "target%i", parent);
			DispatchKeyValue(parent, "targetname", targetName);
			SetVariantString(targetName);

			AcceptEntityInput(particle, "SetParent", particle, particle, 0);
			SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", parent);
		}

		Format(temp, sizeof(temp), "OnUser1 !self:kill::%i:1", time);
		SetVariantString(temp);

		AcceptEntityInput(particle, "AddOutput");
		AcceptEntityInput(particle, "FireUser1");

		DispatchKeyValueVector(particle, "angles", angles);
		AcceptEntityInput(particle, "start");

		return particle;
	}

	return -1;
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
		
		float multiplier = (800.0 / GetVectorDistance(m_vecSrc, endpos)) + 0.3;
		if(multiplier > 1.0)
			multiplier = 1.0;
		
		SDKHooks_TakeDamage(ent, m_pAttacker, m_pDamager, m_flDamage, nDamageType, m_pAttacker, CalculateBulletDamageForce(m_vecDirShooting, 1.0), endpos);

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

float[] CalculateBulletDamageForce( const float vecBulletDir[3], float flScale )
{
	float vecForce[3]; vecForce = vecBulletDir;
	NormalizeVector( vecForce, vecForce );
	ScaleVector(vecForce, FindConVar("phys_pushscale").FloatValue);
	ScaleVector(vecForce, flScale);
	return vecForce;
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


// NOTE: This is mess.
// If this gonna add object or something here, don't forget edit Portal_Update.
int GetEntityInSpot(int startIndex = -1, float pos[3], float size)
{
	float targetPos[3];
	int ent = startIndex + 1;

	for(; ent <= MaxClients; ent++)
	{
		if(!IsValidClient(ent) || !IsPlayerAlive(ent))
			continue;

		// GetClientEyePosition(client, targetPos);
		GetEntPropVector(ent, Prop_Data, "m_vecOrigin", targetPos);
		if(GetVectorDistance(pos, targetPos) <= size)
		{
			// FIXME:
			// TR_TraceRayFilter(pos, targetPos, MASK_ALL, RayType_EndPoint, TraceAnything, client);
			// if(!TR_DidHit())
			return ent;
		}
	}

// 	static const char[][]  =

	while((ent = FindEntityByClassname(ent, "tf_projectile_*")) != -1)
	{
		GetEntPropVector(ent, Prop_Data, "m_vecOrigin", targetPos);
		if(GetVectorDistance(pos, targetPos) <= size)
		{
			// FIXME:
			// TR_TraceRayFilter(pos, targetPos, MASK_ALL, RayType_EndPoint, TraceAnything, ent);
			// if(!TR_DidHit())
			return ent;
		}
	}

	return 2048; // or use GetMaxEntities()?
}

stock bool IsStockInPosition(int ent, float pos[3], float vecMin[3], float vecMax[3])
{
	TR_TraceHullFilter(pos, pos, vecMin, vecMax, MASK_ALL, TraceAnything, ent);
	return TR_DidHit();
}
/* // NOTE: SM 1.11
public bool PortalFilter(int ent, CTFPortal portal)
{
	if(portal.BreakableIndex == ent)	return false;

	if(((IsValidClient(ent) && g_flTeleportEnterCooldown[ent] < GetGameTime()) 
			&& !TF2_IsPlayerInCondition(ent, TFCond_Dazed)
			&& (!portal.Ducked || (portal.Ducked && GetEntProp(ent, Prop_Send, "m_bDucked") > 0)))
			|| (!IsValidClient(ent) && IsValidEntity(ent)))
	{
		portal.TeleportToExit(ent, ENTERFLAG_APPLY_OFFSET);
	}

	return true;
}
*/

public bool TraceAnything(int entity, int contentsMask, any data)
{
    return entity == 0 || entity != data;
}

/*
public void FloatToVector(float vector[3], float x, float z, float y)
{
	vector[0] = x, vector[1] = z, vector[2] = y;
}

public bool TraceRayPlayerOnly(int iEntity, int iMask, any iData)
{
    return (IsValidClient(iEntity) && IsValidClient(iData) && iEntity != iData);
}
*/

public void ReAddPercentCharacter(char[] str, int buffer, int percentImplodeCount)
{
    char implode[32];
    for(int loop = 0; loop < percentImplodeCount; loop++)
        implode[loop] = '%';

    ReplaceString(str, buffer, "%", implode);
}

stock bool IsValidClient(int client)
{
    return (0 < client && client <= MaxClients && IsClientInGame(client));
}
