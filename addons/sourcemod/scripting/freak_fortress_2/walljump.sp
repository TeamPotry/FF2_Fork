#pragma semicolon 1

#include <sourcemod>
#include <dhooks>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <ff2_modules/general>

public Plugin myinfo=
{
	name="Freak Fortress 2: Hit-Wall Jump",
	author="Nopied◎",
	description="",
	version="20231002",
};

public void OnPluginStart()
{
    GameData gamedata = new GameData("potry");
    if (gamedata == null)
    {
        SetFailState("Could not find potry gamedata");
        return;
    }

    CreateDynamicDetour(gamedata, "CTFWeaponBaseMelee::OnEntityHit", _, DHookCallback_OnEntityHit_Post);
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

    if(TF2_GetClientTeam(iOwner) != FF2_GetBossTeam() && !IsBoss(iOwner)
        && ent == 0)
    {
        // WallJump
        float velocity[3];
        GetEntPropVector(iOwner, Prop_Data, "m_vecVelocity", velocity);
        if(velocity[2] < -192.0)    return MRES_Ignored;
        
        // -48.0 ~ -192.0
        float multiplier = 1.0;
        if(velocity[2] < -48.0)
            multiplier = 1.0 - ((velocity[2] * -1.0) * 0.0052083); // 1/192

        velocity[2] = 600.0 * multiplier;
        SetEntPropEnt(iOwner, Prop_Send, "m_hGroundEntity", -1);
        SetEntityFlags(iOwner, GetEntityFlags(iOwner) & ~FL_ONGROUND);

        TeleportEntity(iOwner, NULL_VECTOR, NULL_VECTOR, velocity);
        SetEntPropVector(iOwner, Prop_Data, "m_vecAbsVelocity", velocity);
    }

    return MRES_Ignored;
}

stock bool IsBoss(int client)
{
    return FF2_GetBossIndex(client) != -1;
}