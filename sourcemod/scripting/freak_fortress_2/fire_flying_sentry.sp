#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <sdkhooks>

#tryinclude <ff2_potry>

#define PLUGIN_NAME "fire_flying_sentry"

public Plugin myinfo=
{
    name="Freak Fortress 2 : Fire throw sentry",
    author="Nopied",
    description="....",
    version="2018_10_08",
};

public void OnPluginStart()
{
    #if defined _FF2_POTRY_included
        FF2_RegisterSubplugin(PLUGIN_NAME);
    #endif
}

public void OnEntityCreated(int entity, const char[] classname)
{
    SDKHook(entity, SDKHook_SpawnPost, OnProjectileSpawn);
}

public void OnProjectileSpawn(int entity)
{
    char classname[60];
    GetEntityClassname(entity, classname, sizeof(classname));

    if(StrEqual(classname, "tf_projectile_pipe"))
    {
        int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
        if(IsValidClient(client)
        && FF2_HasAbility(FF2_GetBossIndex(client), PLUGIN_NAME, "flying sentry"))
        {
            float origin[3], sentryPos[3], angles[3], angVector[3];

            GetClientEyePosition(client, origin);
            GetClientEyeAngles(client, angles);

            sentryPos[0] = origin[0];
            sentryPos[1] = origin[1];
            sentryPos[2] = origin[2];

            AcceptEntityInput(entity, "Kill");

            GetAngleVectors(angles, angVector, NULL_VECTOR, NULL_VECTOR);
            NormalizeVector(angVector, angVector);

            sentryPos[2] += 25.0;

            angVector[0] *= 1500.0;	// Test this,
            angVector[1] *= 1500.0;
            angVector[2] *= 1500.0;

            int sentry = TF2_BuildSentry(client, origin, angles, 3, _, _, _, 8);
            // SetEntityMoveType(sentry, MOVETYPE_VPHYSICS);
            SetEntityMoveType(sentry, MOVETYPE_FLYGRAVITY);

            /*
            int prop = CreateProp("models/props_td/atom_bomb.mdl", sentryPos, angVector);
            if(IsValidEntity(prop))
            {
                SetEntityRenderMode(prop, RENDER_TRANSCOLOR);
                SetEntityRenderColor(prop, 255, 255, 255, 0);

                int linkIndex = CreateLink(prop);

                SetVariantString("!activator");
                AcceptEntityInput(sentry, "SetParent", linkIndex);
                SetEntPropEnt(sentry, Prop_Send, "m_hEffectEntity", linkIndex);
            }
            else
            {
                SetEntityMoveType(sentry, MOVETYPE_FLYGRAVITY);
            }
            */

            TeleportEntity(sentry, sentryPos, angles, angVector);

            if(!IsSpotSafe(sentry, sentryPos, 1.0))
            {
                AcceptEntityInput(sentry, "Kill");
                // AcceptEntityInput(prop, "Kill");

                int weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);

                if(IsValidEntity(weapon))
                {
                    FF2_SetAmmo(client, weapon, 0, GetEntProp(weapon, Prop_Send, "m_iClip1") + 1);
                }
            }
        }
    }
}

stock bool IsBossTeam(int client)
{
    return FF2_GetBossTeam() == TF2_GetClientTeam(client);
}

stock int CreateProp(const char[] model, float position[3], float velocity[3])
{
    int prop = CreateEntityByName("prop_physics_override");

    if(!IsValidEntity(prop)) return -1;

    SetEntityModel(prop, model);
    SetEntityMoveType(prop, MOVETYPE_VPHYSICS);
    SetEntProp(prop, Prop_Send, "m_CollisionGroup", 2);

    SetEntProp(prop, Prop_Send, "m_usSolidFlags", 0x0004);
    DispatchSpawn(prop);

    TeleportEntity(prop, position, NULL_VECTOR, velocity);
    return prop;
}

stock int CreateLink(int entity)
{
	int linkIndex = CreateEntityByName("tf_taunt_prop");
	DispatchKeyValue(linkIndex, "targetname", "Link");
	DispatchSpawn(linkIndex);

	SetEntityModel(linkIndex, "models/empty.mdl");

	SetEntProp(linkIndex, Prop_Send, "m_fEffects", 16|64);

	SetVariantString("!activator");
	AcceptEntityInput(linkIndex, "SetParent", entity);

	// SetVariantString("flag");
	// AcceptEntityInput(linkIndex, "SetParentAttachment", entity);

	return linkIndex;
}

stock void UpdateEntityHitbox(const int client, const float fScale)
{
    static const Float:vecTF2PlayerMin[3] = { -50.5, -70.5, 0.0 }, Float:vecTF2PlayerMax[3] = { 50.5,  70.5, 80.0 };
    // static const Float:vecTF2PlayerMin[3] = { -24.5, -24.5, 0.0 }, Float:vecTF2PlayerMax[3] = { 24.5,  24.5, 83.0 };

    decl Float:vecScaledPlayerMin[3], Float:vecScaledPlayerMax[3];

    vecScaledPlayerMin = vecTF2PlayerMin;
    vecScaledPlayerMax = vecTF2PlayerMax;

    ScaleVector(vecScaledPlayerMin, fScale);
    ScaleVector(vecScaledPlayerMax, fScale);

    SetEntPropVector(client, Prop_Send, "m_vecSpecifiedSurroundingMins", vecScaledPlayerMin);
    SetEntPropVector(client, Prop_Send, "m_vecSpecifiedSurroundingMaxs", vecScaledPlayerMax);
}

stock bool IsValidClient(int client)
{
    return (0 < client && client < MaxClients && IsClientInGame(client));
}

stock int TF2_BuildSentry(int builder, float fOrigin[3], float fAngle[3], int level, bool mini=false, bool disposable=false, bool carried=false, int flags=4)
{
    static const float m_vecMinsMini[3] = {-15.0, -15.0, 0.0};
    float m_vecMaxsMini[3] = {15.0, 15.0, 49.5};
    static const float m_vecMinsDisp[3] = {-13.0, -13.0, 0.0};
    float m_vecMaxsDisp[3] = {13.0, 13.0, 42.9};

    int sentry = CreateEntityByName("obj_sentrygun");

    if(IsValidEntity(sentry))
    {
        AcceptEntityInput(sentry, "SetBuilder", builder);

        DispatchKeyValueVector(sentry, "origin", fOrigin);
        DispatchKeyValueVector(sentry, "angles", fAngle);

        if(mini)
        {
            SetEntProp(sentry, Prop_Send, "m_bMiniBuilding", 1);
            SetEntProp(sentry, Prop_Send, "m_iUpgradeLevel", level);
            SetEntProp(sentry, Prop_Send, "m_iHighestUpgradeLevel", level);
            SetEntProp(sentry, Prop_Data, "m_spawnflags", flags);
            // SetEntProp(sentry, Prop_Send, "m_bBuilding", 1);
            SetEntProp(sentry, Prop_Send, "m_bBuilding", 0);
            SetEntProp(sentry, Prop_Send, "m_nSkin", level == 1 ? GetClientTeam(builder) : GetClientTeam(builder) - 2);
            DispatchSpawn(sentry);

            SetVariantInt(100);
            AcceptEntityInput(sentry, "SetHealth");

            SetEntPropFloat(sentry, Prop_Send, "m_flModelScale", 0.75);
            SetEntPropVector(sentry, Prop_Send, "m_vecMins", m_vecMinsMini);
            SetEntPropVector(sentry, Prop_Send, "m_vecMaxs", m_vecMaxsMini);
        }
        else if(disposable)
        {
            SetEntProp(sentry, Prop_Send, "m_bMiniBuilding", 1);
            SetEntProp(sentry, Prop_Send, "m_bDisposableBuilding", 1);
            SetEntProp(sentry, Prop_Send, "m_iUpgradeLevel", level);
            SetEntProp(sentry, Prop_Send, "m_iHighestUpgradeLevel", level);
            SetEntProp(sentry, Prop_Data, "m_spawnflags", flags);
            // SetEntProp(sentry, Prop_Send, "m_bBuilding", 1);
            SetEntProp(sentry, Prop_Send, "m_bBuilding", 0);
            SetEntProp(sentry, Prop_Send, "m_nSkin", level == 1 ? GetClientTeam(builder) : GetClientTeam(builder) - 2);
            DispatchSpawn(sentry);

            SetVariantInt(100);
            AcceptEntityInput(sentry, "SetHealth");

            SetEntPropFloat(sentry, Prop_Send, "m_flModelScale", 0.60);
            SetEntPropVector(sentry, Prop_Send, "m_vecMins", m_vecMinsDisp);
            SetEntPropVector(sentry, Prop_Send, "m_vecMaxs", m_vecMaxsDisp);
        }
        else
        {
            SetEntProp(sentry, Prop_Send, "m_iUpgradeLevel", level);
            SetEntProp(sentry, Prop_Send, "m_iHighestUpgradeLevel", level);
            SetEntProp(sentry, Prop_Data, "m_spawnflags", flags);
            // SetEntProp(sentry, Prop_Send, "m_bBuilding", 1);
            SetEntProp(sentry, Prop_Send, "m_bBuilding", 0);
            SetEntProp(sentry, Prop_Send, "m_nSkin", GetClientTeam(builder) - 2);
            DispatchSpawn(sentry);
        }

        // SetEntProp(sentry, Prop_Send, "m_bPlayerControlled", 1);
        SetEntProp(sentry, Prop_Send, "m_iTeamNum", builder > 0 ? GetClientTeam(builder) : view_as<int>(FF2_GetBossTeam()));

        return sentry;
    }

    return -1;
}


bool ResizeTraceFailed;

stock void constrainDistance(const float[] startPoint, float[] endPoint, float distance, float maxDistance)
{
	float constrainFactor = maxDistance / distance;
	endPoint[0] = ((endPoint[0] - startPoint[0]) * constrainFactor) + startPoint[0];
	endPoint[1] = ((endPoint[1] - startPoint[1]) * constrainFactor) + startPoint[1];
	endPoint[2] = ((endPoint[2] - startPoint[2]) * constrainFactor) + startPoint[2];
}

public bool IsSpotSafe(clientIdx, float playerPos[3], float sizeMultiplier)
{
	ResizeTraceFailed = false;
	static Float:mins[3];
	static Float:maxs[3];
	mins[0] = -24.0 * sizeMultiplier;
	mins[1] = -24.0 * sizeMultiplier;
	mins[2] = 0.0;
	maxs[0] = 24.0 * sizeMultiplier;
	maxs[1] = 24.0 * sizeMultiplier;
	maxs[2] = 82.0 * sizeMultiplier;

	// the eight 45 degree angles and center, which only checks the z offset
	if (!Resize_TestResizeOffset(playerPos, mins[0], mins[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, mins[0], 0.0, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, mins[0], maxs[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, 0.0, mins[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, 0.0, 0.0, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, 0.0, maxs[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0], mins[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0], 0.0, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0], maxs[1], maxs[2])) return false;

	// 22.5 angles as well, for paranoia sake
	if (!Resize_TestResizeOffset(playerPos, mins[0], mins[1] * 0.5, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, mins[0], maxs[1] * 0.5, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0], mins[1] * 0.5, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0], maxs[1] * 0.5, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, mins[0] * 0.5, mins[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0] * 0.5, mins[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, mins[0] * 0.5, maxs[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0] * 0.5, maxs[1], maxs[2])) return false;

	// four square tests
	if (!Resize_TestSquare(playerPos, mins[0], maxs[0], mins[1], maxs[1], maxs[2])) return false;
	if (!Resize_TestSquare(playerPos, mins[0] * 0.75, maxs[0] * 0.75, mins[1] * 0.75, maxs[1] * 0.75, maxs[2])) return false;
	if (!Resize_TestSquare(playerPos, mins[0] * 0.5, maxs[0] * 0.5, mins[1] * 0.5, maxs[1] * 0.5, maxs[2])) return false;
	if (!Resize_TestSquare(playerPos, mins[0] * 0.25, maxs[0] * 0.25, mins[1] * 0.25, maxs[1] * 0.25, maxs[2])) return false;

	return true;
}

bool Resize_TestResizeOffset(const float bossOrigin[3], float xOffset, float yOffset, float zOffset)
{
	static Float:tmpOrigin[3];
	tmpOrigin[0] = bossOrigin[0];
	tmpOrigin[1] = bossOrigin[1];
	tmpOrigin[2] = bossOrigin[2];
	static Float:targetOrigin[3];
	targetOrigin[0] = bossOrigin[0] + xOffset;
	targetOrigin[1] = bossOrigin[1] + yOffset;
	targetOrigin[2] = bossOrigin[2];

	if (!(xOffset == 0.0 && yOffset == 0.0))
		if (!Resize_OneTrace(tmpOrigin, targetOrigin))
			return false;

	tmpOrigin[0] = targetOrigin[0];
	tmpOrigin[1] = targetOrigin[1];
	tmpOrigin[2] = targetOrigin[2] + zOffset;

	if (!Resize_OneTrace(targetOrigin, tmpOrigin))
		return false;

	targetOrigin[0] = bossOrigin[0];
	targetOrigin[1] = bossOrigin[1];
	targetOrigin[2] = bossOrigin[2] + zOffset;

	if (!(xOffset == 0.0 && yOffset == 0.0))
		if (!Resize_OneTrace(tmpOrigin, targetOrigin))
			return false;

	return true;
}

bool Resize_TestSquare(const float bossOrigin[3], float xmin, float xmax, float ymin, float ymax, float zOffset)
{
	static Float:pointA[3];
	static Float:pointB[3];
	for (new phase = 0; phase <= 7; phase++)
	{
		// going counterclockwise
		if (phase == 0)
		{
			pointA[0] = bossOrigin[0] + 0.0;
			pointA[1] = bossOrigin[1] + ymax;
			pointB[0] = bossOrigin[0] + xmax;
			pointB[1] = bossOrigin[1] + ymax;
		}
		else if (phase == 1)
		{
			pointA[0] = bossOrigin[0] + xmax;
			pointA[1] = bossOrigin[1] + ymax;
			pointB[0] = bossOrigin[0] + xmax;
			pointB[1] = bossOrigin[1] + 0.0;
		}
		else if (phase == 2)
		{
			pointA[0] = bossOrigin[0] + xmax;
			pointA[1] = bossOrigin[1] + 0.0;
			pointB[0] = bossOrigin[0] + xmax;
			pointB[1] = bossOrigin[1] + ymin;
		}
		else if (phase == 3)
		{
			pointA[0] = bossOrigin[0] + xmax;
			pointA[1] = bossOrigin[1] + ymin;
			pointB[0] = bossOrigin[0] + 0.0;
			pointB[1] = bossOrigin[1] + ymin;
		}
		else if (phase == 4)
		{
			pointA[0] = bossOrigin[0] + 0.0;
			pointA[1] = bossOrigin[1] + ymin;
			pointB[0] = bossOrigin[0] + xmin;
			pointB[1] = bossOrigin[1] + ymin;
		}
		else if (phase == 5)
		{
			pointA[0] = bossOrigin[0] + xmin;
			pointA[1] = bossOrigin[1] + ymin;
			pointB[0] = bossOrigin[0] + xmin;
			pointB[1] = bossOrigin[1] + 0.0;
		}
		else if (phase == 6)
		{
			pointA[0] = bossOrigin[0] + xmin;
			pointA[1] = bossOrigin[1] + 0.0;
			pointB[0] = bossOrigin[0] + xmin;
			pointB[1] = bossOrigin[1] + ymax;
		}
		else if (phase == 7)
		{
			pointA[0] = bossOrigin[0] + xmin;
			pointA[1] = bossOrigin[1] + ymax;
			pointB[0] = bossOrigin[0] + 0.0;
			pointB[1] = bossOrigin[1] + ymax;
		}

		for (new shouldZ = 0; shouldZ <= 1; shouldZ++)
		{
			pointA[2] = pointB[2] = shouldZ == 0 ? bossOrigin[2] : (bossOrigin[2] + zOffset);
			if (!Resize_OneTrace(pointA, pointB))
				return false;
		}
	}

	return true;
}

public bool TraceAnything(int entity, int contentsMask)
{
    return false;
}

bool Resize_OneTrace(const float startPos[3], const float endPos[3])
{
	static Float:result[3];
	TR_TraceRayFilter(startPos, endPos, MASK_PLAYERSOLID, RayType_EndPoint, TraceAnything);
	if (ResizeTraceFailed)
	{
		return false;
	}
	TR_GetEndPosition(result);
	if (endPos[0] != result[0] || endPos[1] != result[1] || endPos[2] != result[2])
	{
		return false;
	}

	return true;
}
