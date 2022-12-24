#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <ff2_modules/general>

public Plugin myinfo=
{
	name="Freak Fortress 2: HHH details",
	author="Nopied",
	description="",
	version="20221220",
};

#define THIS_PLUGIN_NAME 		"hhh detail"

#define SET_IT_NAME 		    "set it"

int g_hTarget[MAXPLAYERS+1];
int g_hEffect[MAXPLAYERS+1];
int g_hItEffect[MAXPLAYERS+1];
float g_flItTime[MAXPLAYERS+1];

public void OnPluginStart()
{
    HookEvent("arena_round_start", Event_RoundTrigger);
    HookEvent("teamplay_round_active", Event_RoundTrigger); // for non-arena maps

    HookEvent("arena_win_panel", Event_RoundTrigger);
    HookEvent("teamplay_round_win", Event_RoundTrigger); // for non-arena maps

    LoadTranslations("ff2_extra_abilities.phrases");
    FF2_RegisterSubplugin(THIS_PLUGIN_NAME);

    GameData gamedata = new GameData("potry");
	if (gamedata)
	{
        CreateDynamicDetour(gamedata, "CTFWeaponBaseMelee::OnEntityHit", _, DHookCallback_OnEntityHit_Post);
		delete gamedata;
	}
	else
	{
		SetFailState("Could not find potry gamedata");
	}
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

public MRESReturn DHookCallback_OnEntityHit_Post(int weapon, DHookParam params)
{
    int iOwner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
    int ent = params.Get(1);

    if(IsValidClient(ent) && GetClientTeam(iOwner) == GetClientTeam(ent))
    {
        int itOwner = GetItTargetOwner(iOwner);
        if(itOwner == -1)       return MRES_Ignored;
        
        g_hTarget[itOwner] = ent;
        NoticeYouAreIt(ent);
        NoticeLostAggro(iOwner);
        NoticeAnnounceTarget(iOwner, ent);
    }

    return MRES_Ignored;
}

public void Event_RoundTrigger(Event event, const char[] name, bool dontBroadcast)
{
	for(int client = 1; client <= MaxClients; client++)
	{
        g_hTarget[client] = 0;
        g_hEffect[client] = 0;
        g_hItEffect[client] = 0;
        g_flItTime[client] = 0.0;
	}
}

public void FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status)
{
	if(StrEqual(abilityName, SET_IT_NAME))
	{
		InvokeSetIt(boss, slot);
    }
}

void InvokeSetIt(int boss, int slot)
{
    int client = GetClientOfUserId(FF2_GetBossUserId(boss));

    float duration = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, SET_IT_NAME, "duration", 15.0, slot);
    float currentPos[3], eyeAngles[3];

    GetClientEyePosition(client, currentPos);
    GetClientEyeAngles(client, eyeAngles);
    GetAngleVectors(eyeAngles, eyeAngles, NULL_VECTOR, NULL_VECTOR);

    g_hTarget[client] = GetItTarget(client, currentPos, eyeAngles);
    g_flItTime[client] = GetGameTime() + duration;

    float effectPos[3];
    GetEntPropVector(client, Prop_Data, "m_vecOrigin", effectPos);

    effectPos[2] += 42.0;

    SpawnParticle(effectPos, "spell_batball_throw_blue", 0.0, client, 3.0);
    // 위치 확인 (parent 이후의 위치 참고?)
    g_hEffect[client] = DispatchParticleEffect(effectPos, eyeAngles, "utaunt_chain_cpfloor5_purple", client, duration, g_hTarget[client]);

    char abilitySound[PLATFORM_MAX_PATH];
    if(FF2_FindSound("ability", abilitySound, PLATFORM_MAX_PATH, boss, true, slot))
    {
        if(FF2_CheckSoundFlags(client, FF2SOUND_MUTEVOICE))
        {
            EmitSoundToAll(abilitySound, client, _, _, _, 1.0, _, client, currentPos);
            EmitSoundToAll(abilitySound, client, _, _, _, 1.0, _, client, currentPos);
        }

        for(int target = 1; target <= MaxClients; target++)
        {
            if(IsClientInGame(target) && target != client)
            {
                if(FF2_CheckSoundFlags(target, FF2SOUND_MUTEVOICE))
                {
                    EmitSoundToClient(target, abilitySound, client, _, _, _, _, _, client, currentPos);
                    EmitSoundToClient(target, abilitySound, client, _, _, _, _, _, client, currentPos);
                }
            }
        }
    }

    NoticeYouAreIt(g_hTarget[client]);
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float deVelocity[3], float deAngles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	int boss = FF2_GetBossIndex(client);
	if(!IsPlayerAlive(client) || boss == -1) return Plugin_Continue;

	if(FF2_HasAbility(boss, THIS_PLUGIN_NAME, SET_IT_NAME))
	{
        if(g_hTarget[client] == 0 || !IsClientInGame(g_hTarget[client])
            || !IsPlayerAlive(g_hTarget[client]) || g_flItTime[client] < GetGameTime())
            return Plugin_Continue;
        
        if(TF2_IsPlayerInCondition(g_hTarget[client], TFCond_Cloaked)
            || TF2_IsPlayerInCondition(g_hTarget[client], TFCond_Stealthed)
            || TF2_IsPlayerInCondition(g_hTarget[client], TFCond_StealthedUserBuffFade))
            return Plugin_Continue;

        float currentPos[3], targetPos[3], betweenAngles[3];
        GetClientEyePosition(client, currentPos);
        GetClientEyePosition(g_hTarget[client], targetPos);

        TR_TraceRayFilter(currentPos, targetPos, MASK_ALL, RayType_EndPoint, TraceAnything_Active, client);
        if(TR_DidHit())     return Plugin_Continue; 

        SubtractVectors(targetPos, currentPos, betweenAngles);
        NormalizeVector(betweenAngles, betweenAngles);
        GetVectorAngles(betweenAngles, betweenAngles);

        deAngles = betweenAngles;
        SetEntPropFloat(client, Prop_Send, "m_flChargeMeter", 100.0);
        TF2_AddCondition(client, TFCond_Charging, 0.12);  

        float yAngle = betweenAngles[0] * -1.0;
        if(yAngle > 0.0)
        {
            // float velocity[3];
            // GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);

            deVelocity[2] = 300.0;
            // TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
        }

        return Plugin_Changed;
	}

	return Plugin_Continue;
}

int GetItTarget(int client, float currentPos[3], float eyeAngles[3])
{
    float targetPos[3], betweenAngles[3];

    int currentTarget = -1, clientTeam = GetClientTeam(client);
    float nearestAngle = -2.0;

    for(int target = 1; target <= MaxClients; target++)
    {
        if(!IsClientInGame(target) || !IsPlayerAlive(target) || clientTeam == GetClientTeam(target))
            continue;

        GetEntPropVector(target, Prop_Data, "m_vecOrigin", targetPos);
        SubtractVectors(targetPos, currentPos, betweenAngles);
        NormalizeVector(betweenAngles, betweenAngles);

        float currentAngle = -1.0;
        TR_TraceRayFilter(currentPos, targetPos, MASK_ALL, RayType_EndPoint, TraceAnything, client);

        if(!TR_DidHit())
            currentAngle = GetVectorDotProduct(eyeAngles, betweenAngles);
        
        if(currentAngle > nearestAngle)
        {
            currentTarget = target;
            nearestAngle = currentAngle;
        }
    }

    return currentTarget;
}

int GetItTargetOwner(int client)
{
    for(int target = 1; target <= MaxClients; target++)
    {
        if(!IsClientInGame(target) || !IsPlayerAlive(target) || clientTeam == GetClientTeam(target))
            continue;

        if(g_hTarget[target] == client)
            return target;
    }

    return -1;
}

void NoticeYouAreIt(int client)
{
    char message[256];

    Format(message, sizeof(message), "%T", "HHH Warn Victim", client);
    PrintCenterText(client, message);
}

void NoticeLostAggro(int client)
{
    char message[256];

    Format(message, sizeof(message), "%T", "HHH Lost Aggro", client);
    PrintCenterText(client, message);
}

void NoticeAnnounceTarget(int client, int target)
{
    char message[256];

    for(int loop = 1; loop <= MaxClients; loop++)
    {
        if(!IsClientInGame(loop))       continue;

        Format(message, sizeof(message), "{olive}[FF2]{default} %T", "HHH Announce Tag", loop, client, target);
        CPrintToChat(loop, message);
    }
}

stock bool IsValidClient(int client)
{
    return (0 < client && client <= MaxClients && IsClientInGame(client));
}

stock int SpawnParticle(float pos[3], char[] particleType, float offset=0.0, int attachToEntity=-1, float time=1.0)
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

    char temp[128];
    Format(temp, sizeof(temp), "OnUser1 !self:kill::%.1f:1", time);
    SetVariantString(temp);

    AcceptEntityInput(particle, "AddOutput");
    AcceptEntityInput(particle, "FireUser1");

    AcceptEntityInput(particle, "start");
    return particle;
}

stock int DispatchParticleEffect(float pos[3], float angles[3], char[] particleType, int parent=0, float time=1.0, int controlpoint=0)
{
	int particle = CreateEntityByName("info_particle_system");

	char temp[128], targetName[64];
	if (IsValidEdict(particle))
	{
		TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);

		Format(targetName, sizeof(targetName), "tf2particle%i", particle);
		DispatchKeyValue(particle, "targetname", targetName);
		DispatchKeyValue(particle, "effect_name", particleType);

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

        // Only one???
		if(controlpoint > 0)
		{
			// TODO: This shit does not work.
			int cpParticle = CreateEntityByName("info_particle_system");
			if (IsValidEdict(cpParticle))
			{
                float cpPos[3]; // zero
				// GetEntPropVector(controlpoint, Prop_Data, "m_vecOrigin", cpPos);
				TeleportEntity(cpParticle, cpPos, angles, NULL_VECTOR);

				char cpName[64];
                // char cpTargetName[64];
				// Format(cpTargetName, sizeof(cpTargetName), "target%i", controlpoint);
				// DispatchKeyValue(controlpoint, "targetname", cpTargetName);

				Format(cpName, sizeof(cpName), "tf2particle%i", cpParticle);
				DispatchKeyValue(cpParticle, "targetname", cpName);

				DispatchKeyValue(particle, "cpoint1", cpName);

                DispatchSpawn(cpParticle);
		        ActivateEntity(cpParticle);

                Format(targetName, sizeof(targetName), "target%i", controlpoint);
                DispatchKeyValue(controlpoint, "targetname", targetName);
                SetVariantString(targetName);

                AcceptEntityInput(cpParticle, "SetParent", cpParticle, cpParticle, 0);
                SetEntPropEnt(cpParticle, Prop_Send, "m_hOwnerEntity", controlpoint);

                Format(temp, sizeof(temp), "OnUser1 !self:kill::%.1f:1", time);
                SetVariantString(temp);

                AcceptEntityInput(cpParticle, "AddOutput");
                AcceptEntityInput(cpParticle, "FireUser1");
			}
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

public bool TraceAnything(int entity, int contentsMask, any data)
{
    return entity == 0 || entity != data;
}

public bool TraceAnything_Active(int entity, int contentsMask, any data)
{
    return entity == 0 || (entity != data && entity != g_hTarget[data]);
}

stock bool IsBoss(int client)
{
	return FF2_GetBossIndex(client) != -1;
}
