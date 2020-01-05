#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <morecolors>
#include <tf2_stocks>
#include <freak_fortress_2>

#include <stocksoup/colors>

#tryinclude <ff2_potry>
#if !defined _ff2_potry_included
	#include <freak_fortress_2_subplugin>
#endif

#pragma newdecls required

#define THIS_PLUGIN_NAME    "beam"

#define STRAIGHT_BEAM_NAME	"straight beam"

int g_BeamSprite, g_HaloSprite;

public Plugin myinfo=
{
	name="Freak Fortress 2: Beam Abilities",
	author="Nopied",
	description="",
	version="20200103",
};

enum
{
	Manage_Owner,
    Manage_BeamType,

	Manage_StartRadius,
	Manage_EndRadius,

	Manage_Width,
	Manage_EndWidth,
	Manage_FadeLength,
	Manage_Amplitude,

	Manage_RGBColors,
	Manage_Alpha,
	Manage_LifeTime,

	Manage_StartTime,
	Manage_PosTracking,
	Manage_StartPosX,
	Manage_StartPosY,
	Manage_StartPosZ,

	Manage_AngleTracking,
	Manage_StartAngleX,
	Manage_StartAngleY,
	Manage_StartAngleZ,

	Manage_ModelIndex,
	Manage_HaloIndex,

	Manage_StartFrame,
	Manage_FrameRate,

	Manage_BeamDamage,
	Manage_BeamDamageCooldown,
	Management_Max
};

enum
{
	Tracking_None,
	Tracking_Pos,
	Tracking_Angles
};

enum
{
    BeamType_Straight = 0
};

/*
TODO:
	- 레이저 발사 및 트래킹을 클라이언트가 아닌 엔티티에서도 가능하게 할 것
*/

methodmap BeamManagement < ArrayList {
    //TODO: 스피드를 커스터마이징 할 수 있게 할 것
    public static native BeamManagement Create(int owner, const char[] beamModelPath = "", const char[] haloModelPath = "");

	property int Owner {
		public get() {
			return this.Get(Manage_Owner);
		}
		public set(int owner) {
			this.Set(Manage_Owner, owner);
		}
	}

    property int BeamType {
		public get() {
			return this.Get(Manage_BeamType);
		}
		public set(int type) {
			this.Set(Manage_BeamType, type);
		}
	}

	property float StartRadius {
		public get() {
			return this.Get(Manage_StartRadius);
		}
		public set(float radius) {
			this.Set(Manage_StartRadius, radius);
		}
	}

	property float EndRadius {
		public get() {
			return this.Get(Manage_EndRadius);
		}
		public set(float radius) {
			this.Set(Manage_EndRadius, radius);
		}
	}

	property float Width {
		public get() {
			return this.Get(Manage_Width);
		}
		public set(float width) {
			this.Set(Manage_Width, width);
		}
	}

	property float EndWidth {
		public get() {
			return this.Get(Manage_EndWidth);
		}
		public set(float endWidth) {
			this.Set(Manage_EndWidth, endWidth);
		}
	}

	property int FadeLength {
		public get() {
			return this.Get(Manage_FadeLength);
		}
		public set(int fadeLength) {
			this.Set(Manage_FadeLength, fadeLength);
		}
	}

	property float Amplitude {
		public get() {
			return this.Get(Manage_Amplitude);
		}
		public set(float amplitude) {
			this.Set(Manage_Amplitude, amplitude);
		}
	}

	property RGBColor RGBColors {
		public get() {
			return this.Get(Manage_RGBColors);
		}
		public set(RGBColor RGBColors) {
			this.Set(Manage_RGBColors, RGBColors);
		}
	}

	property int Alpha {
		public get() {
			return this.Get(Manage_Alpha);
		}
		public set(int alpha) {
			this.Set(Manage_Alpha, alpha);
		}
	}

	property float LifeTime {
		public get() {
			return this.Get(Manage_LifeTime);
		}
		public set(float lifetime) {
			this.Set(Manage_LifeTime, lifetime);
		}
	}

	property bool PosTracking {
		public get() {
			int owner = this.Owner;
			return IsValidEntity(owner) ? this.Get(Manage_PosTracking) : false;
		}
		public set(bool posTracking) {
			this.Set(Manage_PosTracking, posTracking);
		}
	}

	property bool AngleTracking {
		public get() {
			int owner = this.Owner;
			return IsValidEntity(owner) ? this.Get(Manage_AngleTracking) : false;
		}
		public set(bool angleTracking) {
			this.Set(Manage_AngleTracking, angleTracking);
		}
	}

	property int ModelIndex {
		public get() {
			return this.Get(Manage_ModelIndex);
		}
		public set(int modelIndex) {
			this.Set(Manage_ModelIndex, modelIndex);
		}
	}

	property int HaloIndex {
		public get() {
			return this.Get(Manage_HaloIndex);
		}
		public set(int haloIndex) {
			this.Set(Manage_HaloIndex, haloIndex);
		}
	}

	property int StartFrame {
		public get() {
			return this.Get(Manage_StartFrame);
		}
		public set(int startFrame) {
			this.Set(Manage_StartFrame, startFrame);
		}
	}

	property int FrameRate {
		public get() {
			return this.Get(Manage_FrameRate);
		}
		public set(int frameRate) {
			this.Set(Manage_FrameRate, frameRate);
		}
	}

	property float BeamDamage {
		public get() {
			return this.Get(Manage_BeamDamage);
		}
		public set(float damage) {
			this.Set(Manage_BeamDamage, damage);
		}
	}

	property float BeamDamageCooldown {
		public get() {
			return this.Get(Manage_BeamDamageCooldown);
		}
		public set(float time) {
			this.Set(Manage_BeamDamageCooldown, time);
		}
	}

	public float GetDamageCooldown(int client)
	{
		return this.Get(Management_Max + client);
	}

	public float SetDamageCooldown(int client, float time)
	{
		this.Set(Management_Max + client, time);
	}

	public void GetStartPos(float startPos[3])
	{
		startPos[0] = this.Get(Manage_StartPosX);
		startPos[1] = this.Get(Manage_StartPosY);
		startPos[2] = this.Get(Manage_StartPosZ);
	}

	public void SetStartPos(const float startPos[3])
	{
		this.Set(Manage_StartPosX, startPos[0]);
		this.Set(Manage_StartPosY, startPos[1]);
		this.Set(Manage_StartPosZ, startPos[2]);
	}

	public void GetStartAngles(float angles[3])
	{
		angles[0] = this.Get(Manage_StartAngleX);
		angles[1] = this.Get(Manage_StartAngleY);
		angles[2] = this.Get(Manage_StartAngleZ);
	}

	public void SetStartAngles(const float angles[3])
	{
		this.Set(Manage_StartAngleX, angles[0]);
		this.Set(Manage_StartAngleY, angles[1]);
		this.Set(Manage_StartAngleZ, angles[2]);
	}

	public void GetCurrentVector(int trackingType, float vector[3])
	{
		bool tracking = false;
		int owner = this.Owner;

		switch(trackingType)
		{
			case Tracking_Pos:
			{
				tracking = this.PosTracking;

				if(tracking)
					GetClientEyePosition(owner, vector);
				else
					this.GetStartPos(vector);
			}

			case Tracking_Angles:
			{
				tracking = this.AngleTracking;

				if(tracking)
					GetClientEyeAngles(owner, vector);
				else
					this.GetStartAngles(vector);
			}
		}
	}

    public void Send()
    {
		int type = this.BeamType;
		int colors[4] = {0, 0, 0, 255};
		float startPos[3], startAngles[3], finalPos[3], angles[3];

		this.GetCurrentVector(Tracking_Pos, startPos);
		this.GetCurrentVector(Tracking_Angles, startAngles);
		RGBToIntArray(this.RGBColors, this.Alpha, colors);

		switch(type)
		{
			case BeamType_Straight:
			{
				// 빔의 종료지점 구하기
				GetAngleVectors(startAngles, angles, NULL_VECTOR, NULL_VECTOR);
				ScaleVector(angles, 10000.0);
				AddVectors(startPos, angles, finalPos);

				TE_SetupBeamPoints(startPos, finalPos, this.ModelIndex, this.HaloIndex, this.StartFrame, this.FrameRate, (this.PosTracking || this.AngleTracking) ? 0.1 : this.LifeTime, this.Width, this.EndWidth, this.FadeLength, this.Amplitude, colors, 10);
			}
		}
		TE_SendToAll();

		this.Set(Manage_StartTime, GetGameTime());
		this.SetStartPos(startPos);

		RequestFrame(BM_Update, this);
    }
}

enum
{
	Filter_Owner = 0,
	Filter_PosX,
	Filter_PosY,
	Filter_PosZ,

	Filter_Max
};

methodmap FilterEntityInfo < ArrayList {
	public static native FilterEntityInfo Create(int owner, float pos[3]);

	public void GetPos(float pos[3])
	{
		pos[0] = this.Get(Filter_PosX);
		pos[1] = this.Get(Filter_PosY);
		pos[2] = this.Get(Filter_PosZ);
	}
}

// TODO: float 연산자 조정
public void BM_Update(BeamManagement manage)
{
	float currentTime = GetGameTime(), endTime = view_as<float>(manage.Get(Manage_StartTime)) + manage.LifeTime;

	if(FF2_GetRoundState() != 1 || currentTime > endTime) {
		delete manage;
		return;
	}

	int ownerTeam = GetClientTeam(manage.Owner), type = manage.BeamType, traceIndex = -1;
	float startPos[3], targetPos[3], finalPos[3], startAngles[3], angles[3];
	float vecHullMin[3], vecHullMax[3];
	float distance;
	// float totalRadius = manage.EndRadius, manage.StartRadius * 0.5, currentRadius = ((totalRadius + manage.StartRadius) - FloatMul(totalRadius, FloatDiv((endTime - currentTime), manage.LifeTime))); // TODO: 스피드값 고려

	for(int loop = 0; loop < 3; loop++)
	{
		vecHullMin[loop] = manage.Width;
		vecHullMax[loop] = manage.EndWidth;
	}
	manage.GetStartPos(startPos);

	if(manage.PosTracking || manage.AngleTracking)
	{
		int colors[4] = {0, 0, 0, 255};

		manage.GetCurrentVector(Tracking_Pos, startPos);
		manage.GetCurrentVector(Tracking_Angles, startAngles);
		RGBToIntArray(manage.RGBColors, manage.Alpha, colors);

		switch(type)
		{
			case BeamType_Straight:
			{
				// 빔의 종료지점 구하기
				GetAngleVectors(startAngles, angles, NULL_VECTOR, NULL_VECTOR);
				ScaleVector(angles, 10000.0);
				AddVectors(startPos, angles, finalPos);

				TE_SetupBeamPoints(startPos, finalPos, manage.ModelIndex, manage.HaloIndex, manage.StartFrame, manage.FrameRate, (manage.PosTracking || manage.AngleTracking) ? 0.1 : manage.LifeTime, manage.Width, manage.EndWidth, manage.FadeLength, manage.Amplitude, colors, 10);
			}
		}

		TE_SendToAll();
	}

	GetAngleVectors(startAngles, angles, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(angles, 10000.0);
	AddVectors(startPos, angles, finalPos);

	switch(type)
	{
		case BeamType_Straight:
		{
			ArrayList list = new ArrayList();
			Handle trace;

			list.Push(manage.Owner);
			do
			{
				trace = TR_TraceHullFilterEx(startPos, finalPos, vecHullMin, vecHullMax, MASK_ALL, StraightBeamPlayerFilter, list);
				g_hStraightBeamFilter = trace;
			}
			while(TR_DidHit());

			int length = list.Length, target;
			for(int loop = 0; loop < length; loop++)
			{
				target = list.Get(loop);

				SDKHooks_TakeDamage(target, manage.Owner, manage.Owner, manage.BeamDamage, DMG_SHOCK|DMG_PREVENT_PHYSICS_FORCE);
				manage.SetDamageCooldown(target, GetGameTime() + manage.BeamDamageCooldown);

				delete view_as<Handle>(target);
			}

			delete trace;
			delete list;
		}

	}

	RequestFrame(BM_Update, manage);
}

public bool StraightBeamPlayerFilter(int entity, int contentsMask, ArrayList list)
{
	int length = list.Length, target;
	FilterEntityInfo info;

	if(IsValidClient(entity) && !IsPlayerAlive(entity))
		return false;

	for(int loop = 0; loop < length; loop++)
	{
		info = view_as<FilterEntityInfo>(list.Get(loop));
		target = info.Get(Filter_Owner);

		if(target == entity)
		{
			return false;
		}
	}

	list.Push(FilterEntityInfo.Create(owner, pos));
	return true;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("BeamManagement.Create", Native_BeamManagement_Create);
	CreateNative("FilterEntityInfo.Create", Native_FilterEntityInfo_Create);
}

#if defined _ff2_potry_included
	public void OnPluginStart()
	{
	    FF2_RegisterSubplugin(THIS_PLUGIN_NAME);
	}
#else
	public void OnPluginStart2()
	{
		return;
	}
#endif

public void OnMapStart()
{
	PrecacheBeamPoint();
}

void PrecacheBeamPoint()
{
    Handle gameConfig = LoadGameConfigFile("funcommands.games");
    if (gameConfig == null)
    {
        SetFailState("Unable to load game config funcommands.games");
        return;
    }

    char buffer[PLATFORM_MAX_PATH];
    if (GameConfGetKeyValue(gameConfig, "SpriteBeam", buffer, sizeof(buffer)) && buffer[0])
    {
        g_BeamSprite = PrecacheModel(buffer);
    }

    if (GameConfGetKeyValue(gameConfig, "SpriteHalo", buffer, sizeof(buffer)) && buffer[0])
    {
        g_HaloSprite = PrecacheModel(buffer);
    }

    delete gameConfig;
}

#if defined _ff2_potry_included
public void FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status)
#else
public Action FF2_OnAbility2(int boss, const char[] pluginName, const char[] abilityName, int status)
#endif
{
	if(StrEqual(abilityName, STRAIGHT_BEAM_NAME)) {
		Ability_StraightBeam(boss);
	}
}

void Ability_StraightBeam(int boss)
{
	char beamModelPath[PLATFORM_MAX_PATH], haloModelPath[PLATFORM_MAX_PATH];
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));

	#if defined _ff2_potry_included
		FF2_GetAbilityArgumentString(boss, THIS_PLUGIN_NAME, STRAIGHT_BEAM_NAME, "beam model path", beamModelPath, PLATFORM_MAX_PATH, "");
		FF2_GetAbilityArgumentString(boss, THIS_PLUGIN_NAME, STRAIGHT_BEAM_NAME, "halo model path", haloModelPath, PLATFORM_MAX_PATH, "");
	#else
		FF2_GetAbilityArgumentString(boss, this_plugin_name, STRAIGHT_BEAM_NAME, 1, beamModelPath, PLATFORM_MAX_PATH);
		FF2_GetAbilityArgumentString(boss, this_plugin_name, STRAIGHT_BEAM_NAME, 2, haloModelPath, PLATFORM_MAX_PATH);
	#endif

	BeamManagement beam = BeamManagement.Create(client, beamModelPath, haloModelPath);
	GetBeamArgument(boss, beam, BeamType_Straight);
	beam.Send();
}

public void GetBeamArgument(const int boss, BeamManagement beam, int beamType)
{
	#if defined _ff2_potry_included
		switch(beamType)
		{
			case BeamType_Straight:
			{
				beam.BeamType = BeamType_Straight;
				beam.Width = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, STRAIGHT_BEAM_NAME, "width", 10.0);
				beam.EndWidth = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, STRAIGHT_BEAM_NAME, "end width", 10.0);
				beam.FadeLength  = FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, STRAIGHT_BEAM_NAME, "fade length", 0);
				beam.Amplitude = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, STRAIGHT_BEAM_NAME, "Amplitude", 0.0);

				beam.RGBColors = RGBColor(
					FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, STRAIGHT_BEAM_NAME, "color red", 255),
					FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, STRAIGHT_BEAM_NAME, "color green", 255),
					FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, STRAIGHT_BEAM_NAME, "color blue", 255));
				beam.Alpha = FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, STRAIGHT_BEAM_NAME, "color alpha", 255);
				beam.LifeTime = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, STRAIGHT_BEAM_NAME, "life time", 5.0);

				beam.StartFrame = FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, STRAIGHT_BEAM_NAME, "beam startframe", 0);
				beam.FrameRate = FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, STRAIGHT_BEAM_NAME, "beam framerate", 10);

				beam.BeamDamage = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, STRAIGHT_BEAM_NAME, "damage", 20.0);
				beam.BeamDamageCooldown = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, STRAIGHT_BEAM_NAME, "damage cooldown", 0.0);
			}

		}
	#else
		beam.StartRadius = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STRAIGHT_BEAM_NAME, 3, 10.0);
		beam.EndRadius = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STRAIGHT_BEAM_NAME, 4, 600.0);

		beam.LifeTime = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STRAIGHT_BEAM_NAME, 5, 5.0);
		beam.Width = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STRAIGHT_BEAM_NAME, 6, 10.0);
		beam.Amplitude = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STRAIGHT_BEAM_NAME, 7, 0.0);

		beam.RGBColors = RGBColor(
			FF2_GetAbilityArgument(boss, this_plugin_name, STRAIGHT_BEAM_NAME, 8, 255),
			FF2_GetAbilityArgument(boss, this_plugin_name, STRAIGHT_BEAM_NAME, 9, 255),
			FF2_GetAbilityArgument(boss, this_plugin_name, STRAIGHT_BEAM_NAME, 10, 255));
		beam.Alpha = FF2_GetAbilityArgument(boss, this_plugin_name, STRAIGHT_BEAM_NAME, 11, 255);

		beam.StartFrame = FF2_GetAbilityArgument(boss, this_plugin_name, STRAIGHT_BEAM_NAME, 12, 0);
		beam.FrameRate = FF2_GetAbilityArgument(boss, this_plugin_name, STRAIGHT_BEAM_NAME, 13, 10);

		beam.BeamDamage = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STRAIGHT_BEAM_NAME, 14, 20.0);
		beam.BeamDamageCooldown = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STRAIGHT_BEAM_NAME, 15, 0.0);
	#endif
}

public int Native_BeamManagement_Create(Handle plugin, int numParams)
{
	int clientMaxPosAt = Management_Max + MAXPLAYERS;
	char beamModelPath[PLATFORM_MAX_PATH], haloModelPath[PLATFORM_MAX_PATH];

	GetNativeString(2, beamModelPath, PLATFORM_MAX_PATH);
	GetNativeString(3, haloModelPath, PLATFORM_MAX_PATH);
	BeamManagement array = view_as<BeamManagement>(new ArrayList(8, clientMaxPosAt));

	array.Owner = GetNativeCell(1);
	array.BeamType = 0;
	array.StartRadius = 10.0;
	array.EndRadius = 1800.0;
	array.LifeTime = 5.0;
	array.Width = 10.0;
	array.EndWidth = 20.0;
	array.FadeLength = 0;
	array.Amplitude = 0.0;
	array.RGBColors = GetRandomColor();
	array.Alpha = 255;
	array.PosTracking = true;
	array.AngleTracking = true;

	if(strlen(beamModelPath) > 0)
		array.ModelIndex = PrecacheModel(beamModelPath); // TODO:프리캐싱 횟수를 줄일 필요가 있을지도
	else
		array.ModelIndex = g_BeamSprite;

	if(strlen(haloModelPath) > 0)
		array.HaloIndex = PrecacheModel(haloModelPath); // TODO:프리캐싱 횟수를 줄일 필요가 있을지도
	else
		array.HaloIndex = g_HaloSprite;

	array.StartFrame = 0;
	array.FrameRate = 10;

	array.BeamDamage = 20.0;
	array.BeamDamageCooldown = 0.0;

	for(int client = Management_Max; client < clientMaxPosAt; client++) {
		array.Set(client, 0.0);
	}

	return view_as<int>(array);
}

public int Native_FilterEntityInfo_Create(Handle plugin, int numParams)
{
	FilterEntityInfo array = view_as<FilterEntityInfo>(new ArrayList(12, Filter_Max));
	float pos[3];
	GetNativeArray(2, pos, 3);

	array.Set(Filter_Owner, GetNativeCell(1));
	array.Set(Filter_PosX, pos[0]);
	array.Set(Filter_PosY, pos[1]);
	array.Set(Filter_PosZ, pos[2]);

	return view_as<int>(array);
}

public void RGBToIntArray(RGBColor rgb, int alpha, int output[4])
{
    output[0] = rgb.Red;
    output[1] = rgb.Green;
    output[2] = rgb.Blue;

    output[3] = alpha;
}

public void GetEyeEndPos(int client, float max_distance, float endPos[3])
{
	if(IsClientInGame(client))
	{
		if(max_distance < 0.0)  max_distance=0.0;

		float PlayerEyePos[3], PlayerAimAngles[3], PlayerAimVector[3];
		GetClientEyePosition(client, PlayerEyePos);
		GetClientEyeAngles(client, PlayerAimAngles);
		GetAngleVectors(PlayerAimAngles, PlayerAimVector, NULL_VECTOR, NULL_VECTOR);

		if(max_distance > 0.0)
			ScaleVector(PlayerAimVector, max_distance);
		else
			ScaleVector(PlayerAimVector, 3000.0);

		AddVectors(PlayerEyePos, PlayerAimVector, endPos);
	}
}

stock bool IsValidClient(int client)
{
	return (0 < client && client <= MaxClients && IsClientInGame(client));
}
