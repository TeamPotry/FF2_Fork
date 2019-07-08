#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <morecolors>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <ff2_potry>

#include <stocksoup/colors>

#define THIS_PLUGIN_NAME    "fall effect"

#define FALL_BEAM_EFFECT	"circle beam"

int g_BeamSprite, g_HaloSprite;
float g_flLastBeamDamageTime[MAXPLAYERS+1];

public Plugin myinfo=
{
	name="Freak Fortress 2: Fall Abilities",
	author="Nopied",
	description="",
	version="20190707",
};

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
	Management_Max
};

/*
TE_SetupBeamRingPoint(vec, 10.0, g_Cvar_BeaconRadius.FloatValue, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 5.0, 0.0, greyColor, 10, 0);
TE_SendToAll();
*/

methodmap FallEffectManagement < ArrayList {
    //TODO: 스피드를 커스터마이징 할 수 있게 할 것
    public static native FallEffectManagement Create(int owner);

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
		int colors[4] = {255, 255, 255, 255};
		// RGBToIntArray(this.RGBColors, this.Alpha, colors);

		TE_SetupBeamRingPoint(startpos, this.StartRadius, this.EndRadius, g_BeamSprite, g_HaloSprite, 0, 30, this.LifeTime, this.Width, this.Amplitude, colors, 10, 0);
		TE_SendToAll();

		/*
		TE_SetupBeamRingPoint(startpos, this.EndRadius - 50.0, this.EndRadius, g_BeamSprite, g_HaloSprite, 0, 30, 10.0, this.Width, this.Amplitude, colors, 10, 0);
		TE_SendToAll();
		*/

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
	// PrintToChatAll("%.1f %.1f", totalRadius, currentRadius);

	for(int client = 1; client <= MaxClients; client++) {
		if(IsClientInGame(client) && ownerTeam != GetClientTeam(client)) {
			GetClientAbsOrigin(client, targetPos);
			distance = GetVectorDistance(startPos, targetPos);

			// 우선 거리가 유효한지 확인 (넓이 체크를 같이 함)
			if(distance <= currentRadius + (manage.Width * 0.5)
			&& distance >= currentRadius - (manage.Width * 0.5)) {
				// 플레이어 좌표와 시작지점 좌표와의 각도 백터를 구하기
				MakeVectorFromPoints(startPos, targetPos, finalPos); // ?
				GetVectorAngles(finalPos, toPlayerAngle);

				// PrintToChatAll("%.1f %.1f %.1f", toPlayerAngle[0], toPlayerAngle[1], toPlayerAngle[2]);
				if(toPlayerAngle[0] < beamAngle || toPlayerAngle[0] > 360.0 - beamAngle)	{ // TODO: 빔 넓이 커스터마이징
					/*
					PrintToChatAll("HIT");

					int colors[4] = {255, 255, 255, 255};
					TE_SetupBeamPoints(startPos, targetPos, g_BeamSprite, g_HaloSprite, 0, 15, 5.0, 20.0, 20.0, 10, 3.0, colors, 10);
					TE_SendToAll();
					*/

					SDKHooks_TakeDamage(client, manage.Owner, manage.Owner, 20.0, DMG_SHOCK|DMG_PREVENT_PHYSICS_FORCE);
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

public void OnPluginStart()
{
    FF2_RegisterSubplugin(THIS_PLUGIN_NAME);
}

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

public void FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status)
{
	if(StrEqual(abilityName, FALL_BEAM_EFFECT)) {
		Ability_CircleBeam(boss);
	}
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool& result)
{
	int boss = FF2_GetBossIndex(client);
	if(FF2_HasAbility(boss, THIS_PLUGIN_NAME, FALL_BEAM_EFFECT)) {
		Ability_CircleBeam(boss);
	}

	return Plugin_Continue;
}

void Ability_CircleBeam(int boss)
{
	float pos[3];
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));

	GetClientAbsOrigin(client, pos);
	pos[2] += 10.0;

	FallEffectManagement beam = FallEffectManagement.Create(client);
	beam.Send(pos);
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
	FallEffectManagement array = view_as<FallEffectManagement>(new ArrayList(8, clientMaxPosAt));

	array.Owner = GetNativeCell(1);
	array.StartRadius = 10.0;
	array.EndRadius = 1800.0;
	array.LifeTime = 5.0;
	array.Width = 10.0;
	array.Amplitude = 0.0;
	array.RGBColors = GetRandomColor();
	array.Alpha = 255;

	for(int client = Management_Max; client < clientMaxPosAt; client++) {
		array.Set(client, 0.0);
	}

	return view_as<int>(array);
}
