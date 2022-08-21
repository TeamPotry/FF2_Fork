#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <morecolors>
#include <tf2_stocks>
#include <freak_fortress_2>

#include <stocksoup/colors>

#tryinclude <ff2_modules/general>
#if !defined _ff2_fork_general_included
	#include <freak_fortress_2_subplugin>
#endif

#pragma newdecls required

#define THIS_PLUGIN_NAME    "fall effect"

#define FALL_BEAM_EFFECT	"circle beam"

int g_BeamSprite, g_HaloSprite;

public Plugin myinfo=
{
	name="Freak Fortress 2: Fall Abilities",
	author="Nopied",
	description="",
	version="20190707",
};

/*
	"beam model path" // 1
	"halo model path"
	"start radius"
	"end radius"
	"life time"
	"width"
	"Amplitude"
	"color red"
	"color green"
	"color blue"
	"color alpha"
	"beam startframe"
	"beam framerate"
	"damage"
	"damage cooldown"
*/

enum
{
	Manage_Owner,

	Manage_StartRadius,
	Manage_EndRadius,

	Manage_Width, //
	Manage_Amplitude,

	Manage_RGBColors,
	Manage_Alpha,
	Manage_LifeTime,

	Manage_StartTime,
	Manage_StartPosX,
	Manage_StartPosY,
	Manage_StartPosZ,

	Manage_ModelIndex,
	Manage_HaloIndex,

	Manage_StartFrame,
	Manage_FrameRate,

	Manage_BeamDamage,
	Manage_BeamDamageCooldown,
	Management_Max
};

methodmap FallEffectManagement < ArrayList {
    //TODO: 스피드를 커스터마이징 할 수 있게 할 것
    public static native FallEffectManagement Create(int owner, const char[] beamModelPath = "", const char[] haloModelPath = "");

	property int Owner {
		public get() {
			return this.Get(Manage_Owner);
		}
		public set(int owner) {
			this.Set(Manage_Owner, owner);
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

	public void GetStartPos(float startpos[3])
	{
		startpos[0] = this.Get(Manage_StartPosX);
		startpos[1] = this.Get(Manage_StartPosY);
		startpos[2] = this.Get(Manage_StartPosZ);
	}

	public void SetStartPos(const float startpos[3])
	{
		this.Set(Manage_StartPosX, startpos[0]);
		this.Set(Manage_StartPosY, startpos[1]);
		this.Set(Manage_StartPosZ, startpos[2]);
	}

    public void Send(float startpos[3])
    {
		int colors[4] = {0, 0, 0, 255};
		RGBToIntArray(this.RGBColors, this.Alpha, colors);

		TE_SetupBeamRingPoint(startpos, this.StartRadius, this.EndRadius, this.ModelIndex, this.HaloIndex, this.StartFrame, this.FrameRate, this.LifeTime, this.Width, this.Amplitude, colors, 10, 0);
		TE_SendToAll();

		this.Set(Manage_StartTime, GetGameTime());
		this.SetStartPos(startpos);

		RequestFrame(FEM_Update, this);
    }
}

// TODO: float 연산자 조정
public void FEM_Update(FallEffectManagement manage)
{
	float currentTime = GetGameTime(), endTime = FloatAdd(manage.Get(Manage_StartTime), manage.LifeTime);
	if(FF2_GetRoundState() != 1 || currentTime > endTime) {
		delete manage;
		return;
	}

	int ownerTeam = GetClientTeam(manage.Owner);
	float startPos[3], targetPos[3], finalPos[3], toPlayerAngle[3];
	float totalRadius = FloatSub(manage.EndRadius, manage.StartRadius) * 0.5, currentRadius = ((totalRadius + manage.StartRadius) - FloatMul(totalRadius, FloatDiv((endTime - currentTime), manage.LifeTime))); // TODO: 스피드값 고려
	float distance, beamAngle = 15.0 + manage.Amplitude;

	manage.GetStartPos(startPos);

	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && ownerTeam != GetClientTeam(client) && manage.GetDamageCooldown(client) <= GetGameTime()) {
			GetClientAbsOrigin(client, targetPos);
			distance = GetVectorDistance(startPos, targetPos);

			// 우선 거리가 유효한지 확인 (넓이 체크를 같이 함)
			if(distance <= currentRadius + (manage.Width * 0.5)
			&& distance >= currentRadius - (manage.Width * 0.5)) {
				MakeVectorFromPoints(startPos, targetPos, finalPos);
				GetVectorAngles(finalPos, toPlayerAngle);

				if(toPlayerAngle[0] < beamAngle || toPlayerAngle[0] > 360.0 - beamAngle)	{
					SDKHooks_TakeDamage(client, manage.Owner, manage.Owner, manage.BeamDamage, DMG_SHOCK|DMG_PREVENT_PHYSICS_FORCE);
					manage.SetDamageCooldown(client, GetGameTime() + manage.BeamDamageCooldown);
				}
			}
		}
	}

	RequestFrame(FEM_Update, manage);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("FallEffectManagement.Create", Native_FallEffectManagement_Create);
}

#if defined _ff2_fork_general_included
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
#if defined _ff2_fork_general_included
public void FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status)
#else
public Action FF2_OnAbility2(int boss, const char[] pluginName, const char[] abilityName, int status)
#endif
{
	if(StrEqual(abilityName, FALL_BEAM_EFFECT)) {
		Ability_CircleBeam(boss);
	}
}

/* just for debug
public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool& result)
{
	int boss = FF2_GetBossIndex(client);
	if(FF2_HasAbility(boss, THIS_PLUGIN_NAME, FALL_BEAM_EFFECT)) {
		Ability_CircleBeam(boss);
	}

	return Plugin_Continue;
}
*/

void Ability_CircleBeam(int boss)
{
	float pos[3];
	char beamModelPath[PLATFORM_MAX_PATH], haloModelPath[PLATFORM_MAX_PATH];
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));

	#if defined _ff2_fork_general_included
		FF2_GetAbilityArgumentString(boss, THIS_PLUGIN_NAME, FALL_BEAM_EFFECT, "beam model path", beamModelPath, PLATFORM_MAX_PATH, "");
		FF2_GetAbilityArgumentString(boss, THIS_PLUGIN_NAME, FALL_BEAM_EFFECT, "halo model path", haloModelPath, PLATFORM_MAX_PATH, "");
	#else
		FF2_GetAbilityArgumentString(boss, this_plugin_name, FALL_BEAM_EFFECT, 1, beamModelPath, PLATFORM_MAX_PATH);
		FF2_GetAbilityArgumentString(boss, this_plugin_name, FALL_BEAM_EFFECT, 2, haloModelPath, PLATFORM_MAX_PATH);
	#endif

	GetClientAbsOrigin(client, pos);
	pos[2] += 10.0;

	FallEffectManagement beam = FallEffectManagement.Create(client, beamModelPath, haloModelPath);
	GetBeamArgument(boss, beam);
	beam.Send(pos);
}

public void GetBeamArgument(const int boss, FallEffectManagement beam)
{
	// TODO: FF2 2.0과 1.15 동시 호환

	#if defined _ff2_fork_general_included
		beam.StartRadius = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, FALL_BEAM_EFFECT, "start radius", 10.0);
		beam.EndRadius = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, FALL_BEAM_EFFECT, "end radius", 600.0);

		beam.LifeTime = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, FALL_BEAM_EFFECT, "life time", 5.0);
		beam.Width = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, FALL_BEAM_EFFECT, "width", 10.0);
		beam.Amplitude = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, FALL_BEAM_EFFECT, "Amplitude", 0.0);

		beam.RGBColors = RGBColor(
			FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, FALL_BEAM_EFFECT, "color red", 255),
			FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, FALL_BEAM_EFFECT, "color green", 255),
			FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, FALL_BEAM_EFFECT, "color blue", 255));
		beam.Alpha = FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, FALL_BEAM_EFFECT, "color alpha", 255);

		beam.StartFrame = FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, FALL_BEAM_EFFECT, "beam startframe", 0);
		beam.FrameRate = FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, FALL_BEAM_EFFECT, "beam framerate", 10);

		beam.BeamDamage = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, FALL_BEAM_EFFECT, "damage", 20.0);
		beam.BeamDamageCooldown = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, FALL_BEAM_EFFECT, "damage cooldown", 0.0);
	#else
		beam.StartRadius = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, FALL_BEAM_EFFECT, 3, 10.0);
		beam.EndRadius = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, FALL_BEAM_EFFECT, 4, 600.0);

		beam.LifeTime = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, FALL_BEAM_EFFECT, 5, 5.0);
		beam.Width = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, FALL_BEAM_EFFECT, 6, 10.0);
		beam.Amplitude = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, FALL_BEAM_EFFECT, 7, 0.0);

		beam.RGBColors = RGBColor(
			FF2_GetAbilityArgument(boss, this_plugin_name, FALL_BEAM_EFFECT, 8, 255),
			FF2_GetAbilityArgument(boss, this_plugin_name, FALL_BEAM_EFFECT, 9, 255),
			FF2_GetAbilityArgument(boss, this_plugin_name, FALL_BEAM_EFFECT, 10, 255));
		beam.Alpha = FF2_GetAbilityArgument(boss, this_plugin_name, FALL_BEAM_EFFECT, 11, 255);

		beam.StartFrame = FF2_GetAbilityArgument(boss, this_plugin_name, FALL_BEAM_EFFECT, 12, 0);
		beam.FrameRate = FF2_GetAbilityArgument(boss, this_plugin_name, FALL_BEAM_EFFECT, 13, 10);

		beam.BeamDamage = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, FALL_BEAM_EFFECT, 14, 20.0);
		beam.BeamDamageCooldown = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, FALL_BEAM_EFFECT, 15, 0.0);
	#endif
}

public void RGBToIntArray(RGBColor rgb, int alpha, int output[4])
{
    output[0] = rgb.Red;
    output[1] = rgb.Green;
    output[2] = rgb.Blue;

    output[3] = alpha;
}

public int Native_FallEffectManagement_Create(Handle plugin, int numParams)
{
	int clientMaxPosAt = Management_Max + MAXPLAYERS;
	char beamModelPath[PLATFORM_MAX_PATH], haloModelPath[PLATFORM_MAX_PATH];

	GetNativeString(2, beamModelPath, PLATFORM_MAX_PATH);
	GetNativeString(3, haloModelPath, PLATFORM_MAX_PATH);
	FallEffectManagement array = view_as<FallEffectManagement>(new ArrayList(8, clientMaxPosAt));

	array.Owner = GetNativeCell(1);
	array.StartRadius = 10.0;
	array.EndRadius = 1800.0;
	array.LifeTime = 5.0;
	array.Width = 10.0;
	array.Amplitude = 0.0;
	array.RGBColors = GetRandomColor();
	array.Alpha = 255;

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
