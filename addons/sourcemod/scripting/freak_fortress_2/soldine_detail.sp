#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2items>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <ff2_potry>

#define PLUGIN_NAME "soldine detail"
#define PLUGIN_VERSION 	"20210827"

#define	MAX_EDICT_BITS		12
#define	MAX_EDICTS			(1 << MAX_EDICT_BITS)

public Plugin myinfo=
{
	name="Freak Fortress 2: Soldine Abilities",
	author="Nopied◎",
	description="",
	version=PLUGIN_VERSION,
};

#define BLACKHOLE_NAME      "blackhole"

char g_strBlackHoleClassname[MAXPLAYERS+1][64];
char g_strBlackHoleSoundOpenPath[MAXPLAYERS+1][PLATFORM_MAX_PATH];
char g_strBlackHoleSoundLoopPath[MAXPLAYERS+1][PLATFORM_MAX_PATH];
char g_strBlackHoleSoundClosePath[MAXPLAYERS+1][PLATFORM_MAX_PATH];

float g_flInitTime[MAXPLAYERS+1];
float g_flDuration[MAXPLAYERS+1];
float g_flPower[MAXPLAYERS+1];
float g_flSoundLoopTime[MAXPLAYERS+1];

enum
{
	Hole_Owner,
    Hole_Index,
    Hole_Power,
    Hole_AttachedRef,
	Hole_InitTime,
	Hole_Duration,

	Hole_OpenSoundPath,
	Hole_SoundLoopPath,
	Hole_SoundLoopTime,
	Hole_CloseSoundPath,

    Hole_UpdatePosX,
    Hole_UpdatePosZ,
    Hole_UpdatePosY,

	Hole_Max
};

methodmap CTFBlackHole < ArrayList {
    public static native CTFBlackHole Create(int owner, int index);

    property int Owner {
		public get() {
			return this.Get(Hole_Owner);
		}
		public set(int owner) {
			this.Set(Hole_Owner, owner);
		}
	}
    property int Index {
		public get() {
			return this.Get(Hole_Index);
		}
		public set(int index) {
			this.Set(Hole_Index, index);
		}
	}
	property float Power {
		public get() {
			return this.Get(Hole_Power);
		}
		public set(float power) {
			this.Set(Hole_Power, power);
		}
	}
    property int AttachedRef {
		public get() {
			return this.Get(Hole_AttachedRef);
		}
		public set(int index) {
			this.Set(Hole_AttachedRef, index);
		}
	}
	property float InitTime {
		public get() {
			return this.Get(Hole_InitTime);
		}
		public set(float time) {
			this.Set(Hole_InitTime, time);
		}
	}
	property float Duration {
		public get() {
			return this.Get(Hole_Duration);
		}
		public set(float duration) {
			this.Set(Hole_Duration, duration);
		}
	}
    property float SoundLoopTime {
		public get() {
			return this.Get(Hole_SoundLoopTime);
		}
		public set(float time) {
			this.Set(Hole_SoundLoopTime, time);
		}
	}

    public void GetUpdatePosition(float pos[3])
	{
		int index;
		for(int loop = Hole_UpdatePosX; loop <= Hole_UpdatePosY; loop++)
		{
			index = loop - Hole_UpdatePosX;
			pos[index] = this.Get(loop);
		}
	}

	public void SetUpdatePosition(const float pos[3])
	{
		int index;
		for(int loop = Hole_UpdatePosX; loop <= Hole_UpdatePosY; loop++)
		{
			index = loop - Hole_UpdatePosX;
			this.Set(loop, pos[index]);
		}
	}

	public void GetOpenSound(char[] path, int buffer)
	{
		this.GetString(Hole_OpenSoundPath, path, buffer);
	}

	public void SetOpenSound(const char[] path)
	{
		this.SetString(Hole_OpenSoundPath, path);
	}

    public void GetLoopSound(char[] path, int buffer)
	{
		this.GetString(Hole_SoundLoopPath, path, buffer);
	}

	public void SetLoopSound(const char[] path)
	{
		this.SetString(Hole_SoundLoopPath, path);
	}

	public void GetCloseSound(char[] path, int buffer)
	{
		this.GetString(Hole_CloseSoundPath, path, buffer);
	}

	public void SetCloseSound(const char[] path)
	{
		this.SetString(Hole_CloseSoundPath, path);
	}

    public void Init()
	{
        RequestFrame(BlackHole_Init_Update, this);
    }

	public void Open()
    {
        // PrintToServer("this.Duration: %.1f", this.Duration);
        this.Duration = g_flDuration[this.Owner] + GetGameTime();

        float pos[3];
        char sound[PLATFORM_MAX_PATH];
        this.GetOpenSound(sound, PLATFORM_MAX_PATH);
        this.GetUpdatePosition(pos);

        for(int target=1; target<=MaxClients; target++)
        {
            if(IsClientInGame(target))
            {
                EmitSoundToClient(target, sound, this.Index, _, _, _, _, _, this.Index, pos);
                EmitSoundToClient(target, sound, this.Index, _, _, _, _, _, this.Index, pos);
            }
        }

        RequestFrame(BlackHole_Open_Update, this);
    }

    public void Close()
	{
		RemoveEntity(this.Index);

		delete this;
	}
}

public void BlackHole_Init_Update(CTFBlackHole hole)
{
    if(FF2_GetRoundState() != 1)
    {
        delete hole;
        return;
    }

    float pos[3];
	int attachedIndex = EntRefToEntIndex(hole.AttachedRef);
    // 중간에 벽에 충돌해서 없어졌거나 시간이 다 되어서 오픈되거나

	hole.GetUpdatePosition(pos);

    if(hole.InitTime < GetGameTime())
    {
        hole.Index = SpawnParticle(pos, "eyeboss_tp_vortex");

        hole.Open();

        if(IsValidEntity(attachedIndex))
            RemoveEntity(attachedIndex);

        return;
    }
	else if(IsValidEntity(attachedIndex))
	{
		GetEntPropVector(attachedIndex, Prop_Send, "m_vecOrigin", pos);
	    hole.SetUpdatePosition(pos);
	}
	else
	{
		int particle = SpawnParticle(pos, "eyeboss_doorway_vortex");
		hole.AttachedRef = EntIndexToEntRef(particle);
	}

    RequestFrame(BlackHole_Init_Update, hole);
}

public void BlackHole_Open_Update(CTFBlackHole hole)
{
    if(FF2_GetRoundState() != 1 || hole.Duration < GetGameTime())
    {
        hole.Close();
        return;
    }

    float pos[3];
    char sound[PLATFORM_MAX_PATH];
    hole.GetUpdatePosition(pos);

    if(hole.Duration < (GetGameTime() - 1.3))
    {
        hole.GetCloseSound(sound, PLATFORM_MAX_PATH);
        EmitSoundToAll(sound, _, _, _, _, 1.0, _, _, pos, _, false);
        EmitSoundToAll(sound, _, _, _, _, 1.0, _, _, pos, _, false);
    }

    if(hole.SoundLoopTime < GetGameTime())
	{
		hole.GetLoopSound(sound, PLATFORM_MAX_PATH);

		for(int target=1; target<=MaxClients; target++)
		{
			if(IsClientInGame(target))
			{
				EmitSoundToClient(target, sound, hole.Index, _, _, _, _, _, hole.Index, pos);
				EmitSoundToClient(target, sound, hole.Index, _, _, _, _, _, hole.Index, pos);
			}
		}

		hole.SoundLoopTime = GetGameTime() + g_flSoundLoopTime[hole.Owner];
	}

	char classname[32];
    for(int target = 1; target < MAX_EDICTS; target++)
    {
        if(!IsValidEntity(target))
            continue;

		bool isPlayer = false;
		GetEntityClassname(target, classname, sizeof(classname));
        if((isPlayer = target <= MaxClients)
			&& (!IsPlayerAlive(target) || GetClientTeam(hole.Owner) == GetClientTeam(target)))
			continue;

        if(!HasEntProp(target, Prop_Send, "m_vecOrigin")
            || !HasEntProp(target, Prop_Data, "m_vecVelocity"))
            continue;

		bool isObject = target > MaxClients
			&& (StrEqual(classname, "obj_dispenser") || StrEqual(classname, "obj_sentrygun"));
		if(isObject)
			SetEntityMoveType(target, MOVETYPE_FLYGRAVITY);

		if(target > MaxClients
			&& (!isObject
				&& StrContains(classname, "tf_projectile") == -1
					&& StrContains(classname, "tf_dropped_weapon") == -1))
			continue;
        // PrintToServer("%d", target);

        float targetPos[3], targetAngles[3], velocity[3];
        GetEntPropVector(target, Prop_Send, "m_vecOrigin", targetPos);
        GetEntPropVector(target, Prop_Data, "m_vecVelocity", velocity);

        float realPower = hole.Power - GetVectorDistance(pos, targetPos);
        if(realPower <= 0.0)    continue;

        TR_TraceRayFilter(pos, targetPos, MASK_PLAYERSOLID, RayType_EndPoint, TraceDontHitMe, target);
        if(TR_GetEntityIndex() != target)       continue;

        SubtractVectors(pos, targetPos, targetAngles);
    	GetVectorAngles(targetAngles, targetAngles);
        GetAngleVectors(targetAngles, targetAngles, NULL_VECTOR, NULL_VECTOR);

        // 포탈에 근접한 경우 속도를 줄여 오히려 발을 묶기
		// TODO: 투사체와 플레이어 구분
		// 투사체: 단순 합연산
		// 플레이어의 경우: 이동키와 이동속도를 이용한 저항계수를 연산에 추가
        bool over = isPlayer && hole.Power - 50.0 < realPower;
        ScaleVector(targetAngles, over ? 100.0 : realPower);

        AddVectors(targetAngles, velocity, velocity);

        TeleportEntity(target, NULL_VECTOR, NULL_VECTOR, targetAngles);
    }

    RequestFrame(BlackHole_Open_Update, hole);
}

public bool TraceDontHitMe(int entity, int contentsMask, any data)
{
    return entity == 0 || entity == data;
}


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("CTFBlackHole.Create", Native_CTFBlackHole_Create);
}

public int Native_CTFBlackHole_Create(Handle plugin, int numParams)
{
	CTFBlackHole array = view_as<CTFBlackHole>(new ArrayList(PLATFORM_MAX_PATH, Hole_Max));

	array.Owner = GetNativeCell(1);

	return view_as<int>(array);
}

public void OnPluginStart()
{
	FF2_RegisterSubplugin(PLUGIN_NAME);
}

public void OnEntityCreated(int entity, const char[] classname)
{
    SDKHook(entity, SDKHook_SpawnPost, OnEntitySpawned);
}

public void OnEntitySpawned(int entity)
{
    if(!HasEntProp(entity, Prop_Send, "m_hOwnerEntity"))    return;
    // CreateTimer(0.05, OnEntitySpawned_Delayed, entity, TIMER_FLAG_NO_MAPCHANGE);

    int owner = GetEntProp(entity, Prop_Send, "m_hOwnerEntity") & 0xff,
        boss = FF2_GetBossIndex(owner);

    // PrintToServer("entity: %d, owner: %d", entity, owner);

    if(boss == -1 || !FF2_HasAbility(boss, PLUGIN_NAME, BLACKHOLE_NAME))   return;

    SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
    SetEntityRenderColor(entity, 255, 255, 255, 0);

    int particle = AttachParticle(entity, "spell_teleport_black", _, true);
    CTFBlackHole blackhole = CTFBlackHole.Create(owner, particle);

    blackhole.AttachedRef = EntIndexToEntRef(entity);
    blackhole.InitTime = g_flInitTime[owner] + GetGameTime();
    blackhole.Duration = g_flDuration[owner];
    blackhole.Power = g_flPower[owner];

    float pos[3];
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
    blackhole.SetUpdatePosition(pos);

    blackhole.SetOpenSound(g_strBlackHoleSoundOpenPath[owner]);

    blackhole.SoundLoopTime = GetGameTime() + g_flSoundLoopTime[owner];
    blackhole.SetLoopSound(g_strBlackHoleSoundLoopPath[owner]);

    blackhole.SetCloseSound(g_strBlackHoleSoundClosePath[owner]);

    blackhole.Init();
}

public Action OnEntitySpawned_Delayed(Handle timer, int entity)
{
    // WHAT

    return Plugin_Continue;
}

public void FF2_OnPlayBoss(int boss)
{
    if(FF2_HasAbility(boss, PLUGIN_NAME, BLACKHOLE_NAME))
        BlackHole_Init(boss, -3);
}

public void FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status)
{
	if(StrEqual(BLACKHOLE_NAME, abilityName))
	{
		BlackHole_Init(boss, slot);
	}
}

/*
    // "particle name"     "eyeboss_tp_vortex"
    "classname"         "tf_projectile_rocket"
    "init time"         "2.0"
    "duration"          "10.0"
    "power"             "450.0"

    "sound open path"   ""

    "sound loop time"   "2.0"
    "sound loop path"   "potry_v2/saxton_hale/portal_loop.wav"

    "sound close path"   ""
*/

void BlackHole_Init(int boss, int slot)
{
    int client = GetClientOfUserId(FF2_GetBossUserId(boss));

    FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, BLACKHOLE_NAME, "classname", g_strBlackHoleClassname[client], sizeof(g_strBlackHoleClassname[]), "tf_projectile_rocket", slot);
    FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, BLACKHOLE_NAME, "sound open path", g_strBlackHoleSoundOpenPath[client], sizeof(g_strBlackHoleSoundOpenPath[]), "", slot);
    FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, BLACKHOLE_NAME, "sound loop path", g_strBlackHoleSoundLoopPath[client], sizeof(g_strBlackHoleSoundLoopPath[]), "", slot);
    FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, BLACKHOLE_NAME, "sound close path", g_strBlackHoleSoundClosePath[client], sizeof(g_strBlackHoleSoundClosePath[]), "", slot);

    g_flInitTime[client] = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, BLACKHOLE_NAME, "init time", 2.0, slot);
    g_flDuration[client] = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, BLACKHOLE_NAME, "duration", 10.0, slot);
    g_flPower[client] = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, BLACKHOLE_NAME, "power", 450.0, slot);
    g_flSoundLoopTime[client] = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, BLACKHOLE_NAME, "sound loop time", 2.0, slot);
}

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
