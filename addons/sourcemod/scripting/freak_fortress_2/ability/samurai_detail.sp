#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>

#include <freak_fortress_2>
#include <ff2_modules/stocks>
#tryinclude <ff2_modules/general>
#if defined _ff2_fork_general_included
    #define THIS_PLUGIN_NAME   "samurai detail"

	#define RUSH               		      "rush"
        #define RUSH_READY_TIME    	      "ready time"
		#define RUSH_SLASH_TIME    	      "slash time"
		#define RUSH_REST_TIME     	      "rest time"
        #define RUSH_DELAY_TIME     	  "delay time"


		#define RUSH_SLASH_DISTANCE	      "slash distance"
		#define RUSH_SLASH_RANGE          "slash range"
		#define RUSH_SLASH_DAMAGE         "slash damage"

        #define RUSH_EFFECT_REMAIN_TIME   "effect remain time"
#else
    #include <freak_fortress_2_subplugin>
    #define THIS_PLUGIN_NAME   this_plugin_name

	#define RUSH                   	"rush"
        #define RUSH_READY_TIME           1
		#define RUSH_SLASH_TIME    	      2
		#define RUSH_REST_TIME     	      3

		#define RUSH_SLASH_DISTANCE	      4
		#define RUSH_SLASH_RANGE	      5
		#define RUSH_SLASH_DAMAGE	      6

        #define RUSH_EFFECT_REMAIN_TIME   7
#endif

#define min(%1,%2)            (((%1) < (%2)) ? (%1) : (%2))
#define max(%1,%2)            (((%1) > (%2)) ? (%1) : (%2))
#define mclamp(%1,%2,%3)        min(max(%1,%2),%3)

public Plugin myinfo=
{
	name="Freak Fortress 2: Samurai Abilities",
	author="Nopied◎",
	description="FF2: Special abilities",
	version="20220421",
};

enum
{
    Rush_Inactive = 0,
    Rush_Ready,
    Rush_Slash,
    Rush_Rest,
    Rush_DelayDamage
};

#define MAXIMUM_RUSH_TARGET_COUNT 10

int g_iRushState[MAXPLAYERS+1];
float g_flRushStateTime[MAXPLAYERS+1];

int g_hRushTargetList[MAXPLAYERS+1][MAXIMUM_RUSH_TARGET_COUNT];
int g_iRushTargetCount[MAXPLAYERS+1];

#if defined _ff2_fork_general_included
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

#if defined _ff2_fork_general_included
	FF2_RegisterSubplugin(THIS_PLUGIN_NAME);

    // FF2_PrepareStocks();
#endif
}

public void OnMapStart()
{
    for(int client = 1; client <= MaxClients; client++)
    {
        InitRushState(client);
    }

    FF2_PrecacheEffect();
    FF2_PrecacheParticleEffect("sniper_dxhr_rail_noise");
    FF2_PrecacheParticleEffect("blood_bread_biting2");
    FF2_PrecacheParticleEffect("blood_spray_red_01");
    FF2_PrecacheParticleEffect("env_sawblood");
    FF2_PrecacheParticleEffect("blood_decap_fountain");
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    InitRushState(client);
}

bool PushRushTarget(int client, int target)
{
    if(g_iRushTargetCount[client] >= MAXIMUM_RUSH_TARGET_COUNT)  return false;

    int index = g_iRushTargetCount[client]++;

    for(int loop = 0; loop < index; loop++)
    {
        if(g_hRushTargetList[client][loop] == target)
        {
            return false;
        }
    }
    g_hRushTargetList[client][index] = target;
    return true;
}

void InitRushTargetList(int client)
{
    for(int loop = 0; loop < MAXIMUM_RUSH_TARGET_COUNT; loop++)
    {
        g_hRushTargetList[client][loop] = 0;
    }

    g_iRushTargetCount[client] = 0;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
    if(IsPlayerAlive(client) && g_flRushStateTime[client] > GetGameTime())
    {
        SetEntPropEnt(client, Prop_Send, "m_hGroundEntity", -1);
    }

    return Plugin_Continue;
}

#if defined _ff2_fork_general_included
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

    TF2_AddCondition(client, TFCond_HalloweenKartNoTurn, stopTime); // TODO: 커스터마이징
    SetEntityMoveType(client, MOVETYPE_NONE);

    // TODO: 특정 프레임에 고정
    /* int animationProp = */
    FF2_PlayAnimation(client, "Melee_Swing", _, 0.25);

    // // FIXME: 모델 문제로 각도가 이상하게 꺾여서 여기서 강제로 고정
    // float animationAngles[3];
    // GetEntPropVector(animationProp, Prop_Data, "m_angRotation", animationAngles);
    // animationAngles[1] += 90.0;
    // TeleportEntity(animationProp, NULL_VECTOR, animationAngles, NULL_VECTOR);

    InitRushTargetList(client);
    OnRushTick(client);

    float speed = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, RUSH, RUSH_SLASH_DISTANCE, 1200.0),
        effectTime = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, RUSH, RUSH_EFFECT_REMAIN_TIME, 1.0);

    float playerPos[3], eyeAngles[3], effectPos[3];
    float vecMin[3], vecMax[3];

    GetClientEyeAngles(client, eyeAngles);
    GetEntPropVector(client, Prop_Send, "m_vecMins", vecMin);
    GetEntPropVector(client, Prop_Send, "m_vecMaxs", vecMax);

    // eyeAngles[0] = min(-3.62, eyeAngles[0]);
    GetAngleVectors(eyeAngles, eyeAngles, NULL_VECTOR, NULL_VECTOR);
    ScaleVector(eyeAngles, speed);

    for(int loop = 0; loop < 5; loop++)
    {
        playerPos = WorldSpaceCenter(client);

        for(int axis = 0; axis < 3; axis++)
        {
            playerPos[axis] += GetRandomFloat(vecMin[axis], vecMax[axis]);
        }

        AddVectors(playerPos, eyeAngles, effectPos);
        TE_DispatchEffect("sniper_dxhr_rail_noise", playerPos, effectPos);
        TE_SendToAll();
    }
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

        switch(g_iRushState[client])
        {
            case Rush_Slash:
            {
                SetEntityMoveType(client, MOVETYPE_WALK);
            }
            case Rush_Rest:
            {
                TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, zeroVec);
            }
            case Rush_DelayDamage:
            {
                float damage = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, RUSH, RUSH_SLASH_DAMAGE, 106.0),
                victimPos[3];

                int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

                for(int loop = 0; loop < g_iRushTargetCount[client]; loop++)
                {
                    int target = g_hRushTargetList[client][loop];

                    if(IsValidTarget(target))
                    {
                        GetClientEyePosition(target, victimPos);
                        SDKHooks_TakeDamage(target, client, client, damage, DMG_SLASH|DMG_VEHICLE, weapon, victimPos);

                        DispatchParticleEffect(victimPos, NULL_VECTOR, "env_sawblood", target, 3.0);
                        DispatchParticleEffect(victimPos, NULL_VECTOR, "blood_decap_fountain", target, 3.0);
                    }
                }

                return;
            }
        }

        g_flRushStateTime[client] = GetGameTime() + GetRushStateTime(boss, g_iRushState[client]);
    }

    float stateTime = GetRushStateTime(boss, g_iRushState[client]);
    if(g_iRushState[client] == Rush_Slash)
    {
        float speed = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, RUSH, RUSH_SLASH_DISTANCE, 1200.0),
            range = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, RUSH, RUSH_SLASH_RANGE, 106.0),
            velocity[3],
            slashCenterPos[3], targetCenterPos[3], betweenAngles[3], testPos[3],
            targetHeadPos[3];

        slashCenterPos = WorldSpaceCenter(client);
        GetClientEyeAngles(client, velocity);
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

        float stopTime = 0.0,
            effectTime = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, RUSH, RUSH_EFFECT_REMAIN_TIME, 1.0);

        for(int loop = Rush_Slash; loop <= Rush_Rest; loop++)
            stopTime += GetRushStateTime(boss, loop);

        for(int loop = 0; loop < sizeof(slashTargetClassnames); loop++)
        {
            int target = -1;
            while((target = FindEntityByClassname(target, slashTargetClassnames[loop])) != -1)
            {
                if(loop == 0 && !IsValidTarget(target))                 continue;
                if(GetEntProp(target, Prop_Send, "m_iTeamNum") == team) continue;

                GetClientEyePosition(target, targetHeadPos);
                targetCenterPos = WorldSpaceCenter(target);
                SubtractVectors(targetCenterPos, slashCenterPos, betweenAngles);
                NormalizeVector(betweenAngles, betweenAngles);
                ScaleVector(betweenAngles, range);

                AddVectors(slashCenterPos, betweenAngles, testPos);
                TR_TraceRayFilter(slashCenterPos, testPos, MASK_PLAYERSOLID, RayType_EndPoint, TraceAnything, client);

                // PrintToChatAll("%N, %.1f %.1f %.1f", target, testPos[0], testPos[1], testPos[2]);
                if(TR_GetEntityIndex() != target)   continue;

                // NormalizeVector(betweenAngles, betweenAngles);
                // ScaleVector(betweenAngles, damage * 8.0);

                PushRushTarget(client, target);

                float totalEffectTime = stopTime + effectTime;
                DispatchParticleEffect(targetHeadPos, NULL_VECTOR, "blood_bread_biting2", target, totalEffectTime);
                DispatchParticleEffect(targetHeadPos, NULL_VECTOR, "blood_spray_red_01", target, totalEffectTime);
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
            return FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, RUSH, RUSH_READY_TIME, 0.4);
        }
        case Rush_Slash:
        {
            return FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, RUSH, RUSH_SLASH_TIME, 0.3);
        }
        case Rush_Rest:
        {
            return FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, RUSH, RUSH_REST_TIME, 0.5);
        }
        case Rush_DelayDamage:
        {
            return FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, RUSH, RUSH_DELAY_TIME, 5.0);
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

stock int DispatchParticleEffect(float pos[3], float angles[3], char[] particleType, int parent=0, float time=1.0, int controlpoint=0)
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
    /*
                // SetVariantString(cpTargetName);
                SetVariantString("!activator");
                AcceptEntityInput(cpParticle, "SetParent", controlpoint, cpParticle);

                SetVariantString("flag");
                AcceptEntityInput(cpParticle, "SetParentAttachment", controlpoint, cpParticle);
    */
            }
            // SetEntPropEnt(particle, Prop_Send, "m_hControlPointEnts", controlpoint, 1);
            // SetEntProp(particle, Prop_Send, "m_iControlPointParents", controlpoint, 1);
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

        Format(temp, sizeof(temp), "OnUser1 !self:kill::%.1f:1", time);
        SetVariantString(temp);

        AcceptEntityInput(particle, "AddOutput");
        AcceptEntityInput(particle, "FireUser1");

        DispatchKeyValueVector(particle, "angles", angles);
        AcceptEntityInput(particle, "start");

        return particle;
    }

    return -1;
}
