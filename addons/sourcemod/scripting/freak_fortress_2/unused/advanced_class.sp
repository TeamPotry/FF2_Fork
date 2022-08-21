#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2utils>
#include <tf2attributes>
#include <freak_fortress_2>
#include <ff2_modules/general>
#include <dhooks>
#include <mannvsmann>

#define PLUGIN_VERSION 	"20211204"

public Plugin myinfo=
{
	name="Freak Fortress 2: Advanced class abilities or fixes",
	author="Nopied◎",
	description="",
	version=PLUGIN_VERSION,
};

public void OnPluginStart()
{
	GameData gamedata = new GameData("potry");
	if (gamedata)
	{
		CreateDynamicDetour(gamedata, "CTFWeaponBase::GetProjectileFireSetup", DHookCallback_GetProjectileFireSetup_Pre, DHookCallback_GetProjectileFireSetup_Post);
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

public MRESReturn DHookCallback_GetProjectileFireSetup_Pre(int weapon, DHookParam params)
{
	LogMessage("weapon: %d, player: %d, vecSrc: %X, angForward: %X",
		weapon, params.Get(1), params.GetAddress(3), params.GetAddress(4));

	float vecOffset[3]; // , vecSrc[3], angForward[3];
	params.GetVector(2, vecOffset);

	LogMessage("vecOffset: %.1f, %.1f, %.1f",
		vecOffset[0], vecOffset[1], vecOffset[2]);

	SetMannVsMachineMode(false);
	return MRES_ChangedHandled;
}

public MRESReturn DHookCallback_GetProjectileFireSetup_Post(int weapon, DHookParam params)
{
	ResetMannVsMachineMode();
	return MRES_Ignored;
}

/*
public void OnGameFrame()
{
    float flOrigin[3];
    static float flMins[3] = { -6.0, ... };
    static float flMaxs[3] = { 6.0, ... };

    /// fff.sp
    int ent = -1, iOwnerEntity;
    while ((ent = FindEntityByClassname(ent, "tf_flame")) != -1)
    {
        iOwnerEntity = GetEntPropEnt(ent, Prop_Data, "m_hOwnerEntity");

        if (IsValidEdict(iOwnerEntity))
        {
            // tf_flame's initial owner SHOULD be the flamethrower that it originates from.
            // If not, then something's completely bogus.

            iOwnerEntity = GetEntPropEnt(iOwnerEntity, Prop_Data, "m_hOwnerEntity");
        }

        if (IsValidClient(iOwnerEntity))
        {
            GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", flOrigin);

            TR_EnumerateEntitiesHull(flOrigin, flOrigin, flMins, flMaxs, PARTITION_NON_STATIC_EDICTS, TraceEnumeratorDontHitSelf, iOwnerEntity);
        }
    }
}

public bool TraceEnumeratorDontHitSelf(int entity, any data)
{
    if(entity == data)  return true;
    if(!IsValidClient(entity))  return true;

    int team = GetClientTeam(data), targetTeam = GetClientTeam(entity);
    if(team == targetTeam)
    {
        TF2Attrib_AddCustomPlayerAttribute(entity, "fire rate bonus", 0.7, 0.1);
        TF2Attrib_AddCustomPlayerAttribute(entity, "Reload time decreased", 0.7, 0.1);

        FF2_SetClientAssist(data, FF2_GetClientAssist(data) + 1);
    }

    return true;
}
*/
stock bool IsValidClient(int client)
{
    return (0 < client && client <= MaxClients && IsClientInGame(client));
}
