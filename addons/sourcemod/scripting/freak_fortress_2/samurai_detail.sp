#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>

#include <freak_fortress_2>
#tryinclude <ff2_potry>
#if defined _ff2_potry_included
    #define THIS_PLUGIN_NAME   "samurai detail"

	#define RUSH               		"rush"
        #define RUSH_READY_TIME    	"ready time"
		#define RUSH_SLASH_TIME    	"slash time"
		#define RUSH_REST_TIME     	"rest time"

		#define RUSH_SLASH_DISTANCE	"slash distance"
		#define RUSH_SLASH_RANGE	"slash range"
		#define RUSH_SLASH_DAMAGE	"slash damage"
#else
    #include <freak_fortress_2_subplugin>
    #define THIS_PLUGIN_NAME   this_plugin_name

	#define RUSH                   	"rush"
        #define RUSH_READY_TIME    	1
		#define RUSH_SLASH_TIME    	2
		#define RUSH_REST_TIME     	3

		#define RUSH_SLASH_DISTANCE	4
		#define RUSH_SLASH_RANGE	5
		#define RUSH_SLASH_DAMAGE	6
#endif

#define min(%1,%2)            (((%1) < (%2)) ? (%1) : (%2))
#define max(%1,%2)            (((%1) > (%2)) ? (%1) : (%2))
#define mclamp(%1,%2,%3)        min(max(%1,%2),%3)

public Plugin myinfo=
{
	name="Freak Fortress 2: Samurai Abilities",
	author="Nopied◎",
	description="FF2: Special abilities",
	version="20220306",
};

enum
{
    Rush_Inactive = 0,
    Rush_Ready,
    Rush_Slash,
    Rush_Rest
};

int g_iRushState[MAXPLAYERS+1];
float g_flRushStateTime[MAXPLAYERS+1];

#if defined _ff2_potry_included
	public void OnPluginStart()
#else
	public void OnPluginStart2()
#endif
{
    // HookEvent("arena_round_start", Event_RoundInit);
    // HookEvent("teamplay_round_active", Event_RoundInit); // for non-arena maps

    HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Pre);

	// HookEvent("arena_win_panel", Event_RoundInit);
	// HookEvent("teamplay_round_win", Event_RoundInit); // for non-arena maps

#if defined _ff2_potry_included
	FF2_RegisterSubplugin(THIS_PLUGIN_NAME);
#endif
}

public void OnMapStart()
{
    for(int client = 1; client <= MaxClients; client++)
    {
        InitRushState(client);
    }
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    InitRushState(client);
}

#if defined _ff2_potry_included
public void FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status)
#else
public Action FF2_OnAbility2(int boss, const char[] pluginName, const char[] abilityName, int status)
#endif
{
    if(!strcmp(abilityName, RUSH))
        TriggerRush(boss, status);
}

void TriggerRush(int boss, int status)
{
    // Only for 'not in use' state
    // TODO: 버튼모드 지원
    if(status != 3)  return;

    int client = GetClientOfUserId(FF2_GetBossUserId(boss));
    float readyTime = GetRushStateTime(boss, Rush_Ready);

    // TODO: 준비 사운드, 준비 애니메이션 (애니메이션 값 (레이어) 캡쳐)
    g_iRushState[client] = Rush_Ready;
    g_flRushStateTime[client] = GetGameTime() + readyTime;

    float stopTime = 0.0;
    for(int loop = Rush_Ready; loop <= Rush_Rest; loop++)
        stopTime += GetRushStateTime(boss, loop);

    TF2_AddCondition(client, TFCond_HalloweenKartNoTurn, stopTime);
    SetEntityGravity(client, 0.0);

    OnRushTick(client);
}

void OnRushTick(int client)
{
    if(FF2_GetRoundState() != 1)
        return;

    float zeroVec[3];
    int boss = FF2_GetBossIndex(client);

    if(g_flRushStateTime[client] < GetGameTime())
    {
        g_iRushState[client]++;

        if(g_iRushState[client] == Rush_Rest)
        {
            InitRushState(client);
            // TODO: 슬래쉬 범위 내에 있던 모든 적에게 피격 판정

            TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, zeroVec);
            SetEntityGravity(client, 1.0);

            return;
        }
        else
        {
            g_flRushStateTime[client] = GetGameTime() + GetRushStateTime(boss, g_iRushState[client]);
        }
    }

    float stateTime = GetRushStateTime(boss, g_iRushState[client]);
    if(g_iRushState[client] == Rush_Slash)
    {
        float speed = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, RUSH, RUSH_SLASH_DISTANCE, 1200.0),
            range = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, RUSH, RUSH_SLASH_RANGE, 106.0),
            damage = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, RUSH, RUSH_SLASH_DAMAGE, 106.0),
            velocity[3],
            slashCenterPos[3], targetCenterPos[3], betweenAngles[3], testPos[3];

        int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

        // GetClientEyePosition(client, slashCenterPos);
        slashCenterPos = WorldSpaceCenter(client);
        GetClientEyeAngles(client, velocity);

        // avoid movement logic
        velocity[0] = min(-3.62, velocity[0]);
        GetAngleVectors(velocity, velocity, NULL_VECTOR, NULL_VECTOR);

        speed /= stateTime;
        ScaleVector(velocity, speed);

        TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);

        // TODO: 근처 플레이어 피격판정과 파티클 효과
        int team = GetClientTeam(client);

        // 프레임 롱테이크 이슈?
        static const char slashTargetClassnames[][] = {
        	"player",
        	"obj_dispenser",
        	"obj_sentrygun",
        	"obj_teleporter"
        };

        for(int loop = 0; loop < sizeof(slashTargetClassnames); loop++)
        {
            int target = -1;
            while((target = FindEntityByClassname(target, slashTargetClassnames[loop])) != -1)
            {
                if(loop == 0 && !IsValidTarget(target))                 continue;
                if(GetEntProp(target, Prop_Send, "m_iTeamNum") == team) continue;

                targetCenterPos = WorldSpaceCenter(target);
                SubtractVectors(targetCenterPos, slashCenterPos, betweenAngles);
                NormalizeVector(betweenAngles, betweenAngles);
                ScaleVector(betweenAngles, range);

                AddVectors(slashCenterPos, betweenAngles, testPos);
                TR_TraceRayFilter(slashCenterPos, testPos, MASK_PLAYERSOLID, RayType_EndPoint, TraceAnything, client);

                // PrintToChatAll("%N, %.1f %.1f %.1f", target, testPos[0], testPos[1], testPos[2]);
                if(TR_GetEntityIndex() != target)   continue;

                NormalizeVector(betweenAngles, betweenAngles);
                ScaleVector(betweenAngles, damage * 8.0);

                // TODO: 범위 내의 적에게 파티클 효과
                // TODO: 딜레이 후 피격 판정 (밑 구문 옮기기)
                // 지금은 프레임 당 판정이라 연타로 들어갈거임 (일괄 적용으로 바꿀 것)
                SDKHooks_TakeDamage(target, client, client, damage, DMG_SLASH|DMG_VEHICLE, weapon, testPos, betweenAngles);
            }
        }
    }

    RequestFrame(OnRushTick, client);
}

void InitRushState(int client)
{
    g_iRushState[client] = Rush_Inactive;
    g_flRushStateTime[client] = 0.0;
}

float GetRushStateTime(int boss, int rushState)
{
    switch(rushState)
    {
        case Rush_Ready:
        {
            return FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, RUSH, RUSH_READY_TIME, 0.15);
        }
        case Rush_Slash:
        {
            return FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, RUSH, RUSH_SLASH_TIME, 0.3);
        }
        case Rush_Rest:
        {
            return FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, RUSH, RUSH_REST_TIME, 0.5);
        }
    }

    return 0.0;
}

public bool TraceAnything(int entity, int contentsMask, any data)
{
    return entity == 0 || entity != data;
}

bool IsValidTarget(int target)
{
    return (0 < target && target <= MaxClients && IsClientInGame(target) && IsPlayerAlive(target));
}

// https://github.com/Pelipoika/The-unfinished-and-abandoned/blob/master/CSGO_SentryGun.sp
stock float[] GetAbsOrigin(int client)
{
	float v[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", v);
	return v;
}

stock float[] GetOrigin(int client)
{
	float v[3];
	GetEntPropVector(client, Prop_Data, "m_vecOrigin", v);
	return v;
}

stock float[] WorldSpaceCenter(int ent)
{
	float v[3]; v = GetOrigin(ent);

	float max[3];
	GetEntPropVector(ent, Prop_Data, "m_vecMaxs", max);
	v[2] += max[2] / 2;

	return v;
}
