#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <tf2items>
#include <tf2utils>
#include <tf2attributes>
#include <freak_fortress_2>
#include <tf2wearables>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>

#tryinclude <ff2_modules/general>

#undef REQUIRE_PLUGIN
#tryinclude <mannvsmann>
#define REQUIRE_PLUGIN

#define PLUGIN_NAME             "bob detail"

#define FLYING_SENTRY_NAME      "fire flying sentry"
#define SENTRY_FULL_CHARGE      "sentry full charge"
#define SENTRY_MINION           "upgrade sentry to spawn minion"
#define SENTRY_ALL_UPGRADE      "sentry all upgrade"
#define INSTANT_BUILDING_NAME   "instant sentry building"
#define BOMB_BUILDING_NAME      "bomb building"

public Plugin myinfo=
{
    name="Freak Fortress 2 : Bob abilities",
    author="Nopied◎",
    description="....",
    version="20211105",
};

Handle g_SDKCallSentryDeploy;
int g_iRobotOwnerIndex[MAXPLAYERS+1];

public void OnPluginStart()
{
    HookEvent("teamplay_round_start", OnRoundStart);
    HookEvent("player_death", OnPlayerDeath);

    HookEvent("player_upgradedobject", OnUpgradedObject);

    LoadTranslations("ff2_extra_abilities.phrases");

    #if defined _ff2_fork_general_included
        FF2_RegisterSubplugin(PLUGIN_NAME);
    #endif

    GameData gamedata = new GameData("potry");
    if (gamedata)
    {
        g_SDKCallSentryDeploy = PrepSDKCall_SentryDeploy(gamedata);
    }

    // CreateDynamicDetour(gamedata, "CTFWeaponBaseMelee::OnEntityHit", _, DHookCallback_OnEntityHit_Post);
}

public void OnMapStart()
{
    PrecacheEffect("ParticleEffect");
    PrecacheParticleEffect("dxhr_sniper_rail_blue");
    PrecacheParticleEffect("teleported_blue");
    PrecacheParticleEffect("teleportedin_blue");

    char classname[10], path[PLATFORM_MAX_PATH];
    for (TFClassType loop = TFClass_Scout; loop <= TFClass_Engineer; loop++)
    {
        TF2_GetNameOfClass(loop, classname, sizeof(classname));
        Format(path, sizeof(path), "models/bots/%s/bot_%s.mdl", classname, classname);
        PrecacheModel(path, true);
    }
}

/*
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
*/

public void OnEntityCreated(int entity, const char[] classname)
{
    if(StrEqual(classname, "tf_projectile_pipe"))
    {
        SDKHook(entity, SDKHook_SpawnPost, OnProjectileSpawn);
    }
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for(int client = 1; client <= MaxClients; client++)
	{
		g_iRobotOwnerIndex[client] = -1;
	}

	return Plugin_Continue;
}

public Action OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client=GetClientOfUserId(event.GetInt("userid"));
    TFTeam bossTeam = FF2_GetBossTeam();

    if(g_iRobotOwnerIndex[client]!=-1)  //Switch clones back to the other team after they die
    {
        g_iRobotOwnerIndex[client]=-1;
        FF2_SetFF2Flags(client, FF2_GetFF2Flags(client) & ~FF2FLAG_CLASSTIMERDISABLED);
        TF2_ChangeClientTeam(client, bossTeam == TFTeam_Blue ? TFTeam_Red : TFTeam_Blue);
    }
    return Plugin_Continue;
}

public void FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status)
{
    if(!StrEqual(pluginName, PLUGIN_NAME))
        return;

    if(StrEqual(abilityName, SENTRY_FULL_CHARGE))
    {
        RefillAllSentryAmmo(boss);
    }

    if(StrEqual(abilityName, SENTRY_ALL_UPGRADE))
    {
        UpgradeAllSentry(boss);
    }
}

void RefillAllSentryAmmo(int boss)
{
    int client = GetClientOfUserId(FF2_GetBossUserId(boss));
    float effectDuration = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, SENTRY_FULL_CHARGE, "effect duration", 10.0);

    int sentry = -1;

    float pos[3], sentryPos[3], temp[3];
    GetEntPropVector(client, Prop_Data, "m_vecOrigin", pos);

    while((sentry = FindEntityByClassname(sentry, "obj_sentrygun")) != -1)
    {
        int owner = GetEntPropEnt(sentry, Prop_Send, "m_hBuilder");
        if(owner != client)     continue;

        GetEntPropVector(sentry, Prop_Data, "m_vecOrigin", sentryPos);
        SetEntProp(sentry, Prop_Send, "m_iAmmoShells", 200);

        DispatchParticleEffect(sentryPos, temp, "mvm_path_marker", sentry, RoundFloat(effectDuration));
        DispatchParticleEffect(sentryPos, temp, "mvm_emergencylight_glow", sentry, RoundFloat(effectDuration));
    }
}

void UpgradeAllSentry(int boss)
{
    int client = GetClientOfUserId(FF2_GetBossUserId(boss));
    float effectDuration = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, SENTRY_FULL_CHARGE, "effect duration", 10.0);

    int sentry = -1;

    float pos[3], eyeAngles[3], right[3]
    float sentryPos[3], temp[3];
    GetClientEyePosition(client, pos);
    GetClientEyeAngles(client, eyeAngles);
    GetAngleVectors(eyeAngles, NULL_VECTOR, right, NULL_VECTOR);

    pos[2] -= 20.0;
    ScaleVector(right, 20.0);
    AddVectors(pos, right, pos);

    while((sentry = FindEntityByClassname(sentry, "obj_sentrygun")) != -1)
    {
        int owner = GetEntPropEnt(sentry, Prop_Send, "m_hBuilder");
        if(owner != client || GetEntProp(sentry, Prop_Send, "m_iUpgradeLevel") >= 3)     continue;

        GetEntPropVector(sentry, Prop_Data, "m_vecOrigin", sentryPos);

        SetEntProp(sentry, Prop_Send, "m_iUpgradeLevel", 3);
        SetEntProp(sentry, Prop_Send, "m_iHighestUpgradeLevel", 3);
        SetEntProp(sentry, Prop_Send, "m_iState", 3);

        Event event = CreateEvent("player_upgradedobject", true);
        event.SetInt("userid", GetClientUserId(client));
        event.SetInt("index", sentry);
        event.SetBool("isbuilder", false);
        event.Fire(false);

        TE_DispatchEffect("dxhr_sniper_rail_blue", pos, sentryPos);
        TE_SendToAll();

        DispatchParticleEffect(sentryPos, temp, "mvm_emergencylight_glow", -1, RoundFloat(effectDuration));
    }
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
    int boss = FF2_GetBossIndex(client);
    if(FF2_HasAbility(boss, PLUGIN_NAME, INSTANT_BUILDING_NAME))
    {
        int currentWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
        if(GetPlayerWeaponSlot(client, 3) == weapon)
        {
            float temp[3];
            int maxCount = FF2_GetAbilityArgument(boss, PLUGIN_NAME, INSTANT_BUILDING_NAME, "sentry max count", 10),
                count = GetSentryCount(client),
                pda = GetPlayerWeaponSlot(client, TFWeaponSlot_PDA);

            if(pda == currentWeapon)
                return Plugin_Handled;

            int sentry;
            if(maxCount >= count + 1)
                sentry = TF2_BuildSentry(client, temp, temp, 2);
            else
            {
                sentry = GetFurthestSentry(client);
                float pos[3], sentryPos[3], eyeAngles[3];
                float right[3];

                GetClientEyePosition(client, pos);
                GetClientEyeAngles(client, eyeAngles);
                GetAngleVectors(eyeAngles, NULL_VECTOR, right, NULL_VECTOR);

                pos[2] -= 20.0;
                ScaleVector(right, 20.0);
                AddVectors(pos, right, pos);

                GetEntPropVector(sentry, Prop_Data, "m_vecOrigin", sentryPos);

                TE_DispatchEffect("dxhr_sniper_rail_blue", pos, sentryPos);
                TE_WriteFloat("m_flScale", 100.0);
                TE_SendToAll();

                TE_DispatchEffect("teleported_blue", sentryPos, sentryPos);
                TE_SendToAll();

                TE_DispatchEffect("teleportedin_blue", sentryPos, sentryPos);
                TE_SendToAll();

                for(int target=1; target<=MaxClients; target++)
        		{
        			if(IsClientInGame(target))
        			{
        				EmitSoundToClient(target, "weapons/teleporter_receive.wav", sentry, _, _, _, _, _, sentry, sentryPos);
        				EmitSoundToClient(target, "weapons/teleporter_send.wav", target, _, _, _, _, _, target, pos);
        			}
        		}
            }

            SetEntProp(sentry, Prop_Send, "m_bCarried", 1);
            SetEntProp(sentry, Prop_Send, "m_bPlacing", 1);
            SetEntProp(sentry, Prop_Send, "m_bCarryDeploy", 0);
            SetEntProp(sentry, Prop_Send, "m_iDesiredBuildRotations", 0);
            SetEntProp(sentry, Prop_Send, "m_iUpgradeLevel", 1);

            SetEntPropEnt(pda, Prop_Send, "m_hObjectBeingBuilt", sentry);
            SetEntProp(pda, Prop_Send, "m_iBuildState", 2);
            SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", pda);

            SDKCall_SentryDeploy(pda);
            FF2_SetBossHealth(boss, FF2_GetBossHealth(boss) - 100);
            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}

public Action OnUpgradedObject(Event event, const char[] name, bool dontBroadcast)
{
    int sentry = event.GetInt("index");
    int owner = GetEntPropEnt(sentry, Prop_Send, "m_hBuilder");

    int boss = FF2_GetBossIndex(owner);
    if(!FF2_HasAbility(boss, PLUGIN_NAME, SENTRY_MINION))
        return Plugin_Continue;

    RequestFrame(OnSentryMinionQueue, EntIndexToEntRef(sentry));
    return Plugin_Continue;
}

public void OnSentryMinionQueue(int sentryRef)
{
    int sentry = EntRefToEntIndex(sentryRef);
    if(FF2_GetRoundState() != 1 || !IsValidEntity(sentry))
        return;

    int owner = GetEntPropEnt(sentry, Prop_Send, "m_hBuilder");
    float sentryPos[3];
    GetEntPropVector(sentry, Prop_Data, "m_vecOrigin", sentryPos);

    int target = GetMinionTarget(owner);
    if(target == -1)
        RequestFrame(OnSentryMinionQueue, sentry);
    else
    {
        static TFClassType classes[8] = {
            TFClass_Scout,
            TFClass_Sniper,
            TFClass_Soldier,
            TFClass_DemoMan,
            TFClass_Medic,
            TFClass_Heavy,
            TFClass_Pyro,
            TFClass_Spy,
        };

        #if defined _MVM_included
        	SetMannVsMachineMode(false);
        #endif

        g_iRobotOwnerIndex[target] = owner;
        int classRandom = GetRandomInt(0, 7);

        FF2_SetFF2Flags(target, FF2_GetFF2Flags(target)|FF2FLAG_ALLOWSPAWNINBOSSTEAM|FF2FLAG_CLASSTIMERDISABLED);

        TF2_ChangeClientTeam(target, TF2_GetClientTeam(owner));
        TF2_SetPlayerClass(target, classes[classRandom], false, false);
        TF2_RespawnPlayer(target);

        #if defined _MVM_included
        	ResetMannVsMachineMode();
        #endif

        RemoveEntity(sentry);
        TeleportEntity(target, sentryPos, NULL_VECTOR, NULL_VECTOR);

        // 이펙트 씹히는 느낌
        sentryPos[2] += 20.0;
        TE_DispatchEffect("teleported_blue", sentryPos, sentryPos);
        TE_SendToAll();

        TE_DispatchEffect("teleportedin_blue", sentryPos, sentryPos);
        TE_SendToAll();

        float temp[3];
        DispatchParticleEffect(temp, temp, "player_glowblue", target, 5);

        for(int client = 1; client <= MaxClients; client++)
        {
            if(IsClientInGame(client))
            {
                EmitSoundToClient(client, "weapons/teleporter_receive.wav", sentry, _, _, _, _, _, sentry, sentryPos);
            }
        }

        TF2_AddCondition(target, TFCond_Ubercharged, 5.0);
        SetEntProp(target, Prop_Data, "m_iMaxHealth", 125);
        SetEntProp(target, Prop_Data, "m_iHealth", 125);
        SetEntProp(target, Prop_Send, "m_iHealth", 125);

        char model[PLATFORM_MAX_PATH];
        GetRobotModelPath(classes[classRandom], model, PLATFORM_MAX_PATH);

        DataPack data;
        CreateDataTimer(0.1, Timer_MakeRobotMinion, data, TIMER_FLAG_NO_MAPCHANGE);
        data.WriteCell(GetClientUserId(target));
        data.WriteCell(classes[classRandom]);
        data.WriteString(model);
    }
}

public Action Timer_MakeRobotMinion(Handle timer, DataPack pack)
{
	pack.Reset();
	int client=GetClientOfUserId(pack.ReadCell());
	TFClassType class = pack.ReadCell();
	if(client && IsClientInGame(client) && IsPlayerAlive(client))
	{
		TF2Attrib_RemoveAll(client);
		TF2_RemoveAllWeapons(client);
		TF2_RemoveAllWearables(client);

		SwitchToDefalutWeapon(client, class);

		char model[PLATFORM_MAX_PATH];
		pack.ReadString(model, PLATFORM_MAX_PATH);
		SetVariantString(model);
		AcceptEntityInput(client, "SetCustomModel");
		SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
	}

	return Plugin_Continue;
}

public void GetRobotModelPath(TFClassType class, char[] path, int buffer)
{
    char classname[10];
    TF2_GetNameOfClass(class, classname, sizeof(classname));
    Format(path, buffer, "models/bots/%s/bot_%s.mdl", classname, classname);
}

public void TF2_GetNameOfClass(TFClassType class, char[] name, int maxlen)
{
	switch (class)
	{
		case TFClass_Scout: Format(name, maxlen, "scout");
		case TFClass_Soldier: Format(name, maxlen, "soldier");
		case TFClass_Pyro: Format(name, maxlen, "pyro");
		case TFClass_DemoMan: Format(name, maxlen, "demo");
		case TFClass_Heavy: Format(name, maxlen, "heavy");
		case TFClass_Engineer: Format(name, maxlen, "engineer");
		case TFClass_Medic: Format(name, maxlen, "medic");
		case TFClass_Sniper: Format(name, maxlen, "sniper");
		case TFClass_Spy: Format(name, maxlen, "spy");
	}

}
void SwitchToDefalutWeapon(int client, TFClassType class, int currentSlot = TFWeaponSlot_Primary)
{
	int weapon;

	switch(class)
	{
		case TFClass_Scout:
		{
			SpawnWeapon(client, "tf_weapon_scattergun", 200, 1, 0, "");
			SpawnWeapon(client, "tf_weapon_pistol", 209, 1, 0, "");
			SpawnWeapon(client, "tf_weapon_bat", 190, 1, 0, "");
		}
		case TFClass_Soldier:
		{
			SpawnWeapon(client, "tf_weapon_rocketlauncher", 205, 1, 0, "");
			SpawnWeapon(client, "tf_weapon_shotgun_soldier", 199, 1, 0, "");
			SpawnWeapon(client, "tf_weapon_shovel", 196, 1, 0, "");
		}
		case TFClass_Pyro:
		{
			SpawnWeapon(client, "tf_weapon_flamethrower", 208, 1, 0, "");
			SpawnWeapon(client, "tf_weapon_shotgun_pyro", 199, 1, 0, "");
			SpawnWeapon(client, "tf_weapon_fireaxe", 192, 1, 0, "");
		}
		case TFClass_DemoMan:
		{
			SpawnWeapon(client, "tf_weapon_grenadelauncher", 206, 1, 0, "");
			SpawnWeapon(client, "tf_weapon_pipebomblauncher", 207, 1, 0, "");
			SpawnWeapon(client, "tf_weapon_bottle", 191, 1, 0, "");
		}
		case TFClass_Heavy:
		{
			SpawnWeapon(client, "tf_weapon_minigun", 202, 1, 0, "");
			SpawnWeapon(client, "tf_weapon_shotgun_hwg", 199, 1, 0, "");
			SpawnWeapon(client, "tf_weapon_fists", 195, 1, 0, "");
		}
		case TFClass_Engineer:
		{
			SpawnWeapon(client, "tf_weapon_shotgun_primary", 199, 1, 0, "");
			SpawnWeapon(client, "tf_weapon_pistol", 209, 1, 0, "");
			SpawnWeapon(client, "tf_weapon_wrench", 197, 1, 0, "");
			SpawnWeapon(client, "tf_weapon_pda_engineer_build", 737, 1, 0, "");
			SpawnWeapon(client, "tf_weapon_pda_engineer_destroy", 26, 1, 0, "");
			weapon = SpawnWeapon(client, "tf_weapon_builder", 28, 1, 0, "");

			SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 1, _, 0);
			SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 1, _, 1);
			SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 1, _, 2);
			SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 3);
		}
		case TFClass_Medic:
		{
			SpawnWeapon(client, "tf_weapon_syringegun_medic", 204, 1, 0, "");
			SpawnWeapon(client, "tf_weapon_medigun", 211, 1, 0, "");
			SpawnWeapon(client, "tf_weapon_bonesaw", 198, 1, 0, "");
		}
		case TFClass_Sniper:
		{
			SpawnWeapon(client, "tf_weapon_sniperrifle", 201, 1, 0, "");
			SpawnWeapon(client, "tf_weapon_smg", 203, 1, 0, "");
			SpawnWeapon(client, "tf_weapon_club", 193, 1, 0, "");
		}
		case TFClass_Spy:
		{
			SpawnWeapon(client, "tf_weapon_revolver", 210, 1, 0, "");
			weapon = SpawnWeapon(client, "tf_weapon_builder", 736, 1, 0, "");

			SetEntProp(weapon, Prop_Send, "m_iObjectType", 3);
			SetEntProp(weapon, Prop_Data, "m_iSubType", 3);
			SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 0);
			SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 1);
			SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 2);
			SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 1, _, 3);

			SpawnWeapon(client, "tf_weapon_knife", 194, 1, 0, "");
			SpawnWeapon(client, "tf_weapon_pda_spy", 27, 1, 0, "");
			SpawnWeapon(client, "tf_weapon_invis", 212, 1, 0, "");
		}
	}

	weapon = GetPlayerWeaponSlot(client, currentSlot);
	if(IsValidEntity(weapon))
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);

	// 업그레이드 초기화
	for(int slot = 0; slot < 6; slot++)
	{
		weapon = GetPlayerWeaponSlot(client, slot);
		if(IsValidEntity(weapon))
			TF2Attrib_RemoveAll(weapon);
	}
}

stock int SpawnWeapon(int client, char[] name, int index, int level, int quality, char[] attribute)
{
	Handle weapon=TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION|PRESERVE_ATTRIBUTES);
	TF2Items_SetClassname(weapon, name);
	TF2Items_SetItemIndex(weapon, index);
	TF2Items_SetLevel(weapon, level);
	TF2Items_SetQuality(weapon, quality);
	char attributes[32][32];
	int count = ExplodeString(attribute, ";", attributes, 32, 32);
	if(count%2!=0)
	{
		count--;
	}

	if(count>0)
	{
		TF2Items_SetNumAttributes(weapon, count/2);
		int i2=0;
		for(int i=0; i<count; i+=2)
		{
			int attrib=StringToInt(attributes[i]);
			if(attrib==0)
			{
				LogError("Bad weapon attribute passed: %s ; %s", attributes[i], attributes[i+1]);
				return -1;
			}
			TF2Items_SetAttribute(weapon, i2, attrib, StringToFloat(attributes[i+1]));
			i2++;
		}
	}
	else
	{
		TF2Items_SetNumAttributes(weapon, 0);
	}

	if(weapon==null)
	{
		return -1;
	}
	int entity=TF2Items_GiveNamedItem(client, weapon);
	CloseHandle(weapon);
	EquipPlayerWeapon(client, entity);
	return entity;
}

int GetMinionTarget(int owner)
{
    for(int client = 1; client <= MaxClients; client++)
    {
        if(!IsClientInGame(client) || IsPlayerAlive(client)
            || TF2_GetClientTeam(client) <= TFTeam_Spectator
            || FF2_GetBossIndex(client) != -1
            || client == owner)
            continue;

        return client;
    }

    return -1;
}

public void FF2_OnCalledQueue(FF2HudQueue hudQueue, int client)
{
    int boss = FF2_GetBossIndex(client);
    if(!FF2_HasAbility(boss, PLUGIN_NAME, INSTANT_BUILDING_NAME))  return;

    char text[128];
    FF2HudDisplay hudDisplay = null;

    SetGlobalTransTarget(client);
    hudQueue.GetName(text, sizeof(text));

    if(StrEqual(text, "Boss"))
    {
        int maxCount = FF2_GetAbilityArgument(boss, PLUGIN_NAME, INSTANT_BUILDING_NAME, "sentry max count", 10);
        Format(text, sizeof(text), "%t", "Sentry Count", GetSentryCount(client), maxCount);

        hudDisplay = FF2HudDisplay.CreateDisplay("Sentry Count", text);
        hudQueue.AddHud(hudDisplay, client);
    }
}

stock int GetFurthestSentry(int client)
{
    int ent = -1, maxEnt = -1;

    float pos[3], sentryPos[3], maxDistance = -1.0;
    GetEntPropVector(client, Prop_Data, "m_vecOrigin", pos);

    while((ent = FindEntityByClassname(ent, "obj_sentrygun")) != -1)
    {
        int owner = GetEntPropEnt(ent, Prop_Send, "m_hBuilder");
        if(owner != client)     continue;

        GetEntPropVector(ent, Prop_Data, "m_vecOrigin", sentryPos);
        if(maxDistance < GetVectorDistance(pos, sentryPos) || maxDistance < 0.0)
        {
            maxDistance = GetVectorDistance(pos, sentryPos);
            maxEnt = ent;
        }
    }

    return maxEnt;
}

stock int GetSentryCount(int client)
{
    int count = 0, ent = -1;

    while((ent = FindEntityByClassname(ent, "obj_sentrygun")) != -1)
    {
        int owner = GetEntPropEnt(ent, Prop_Send, "m_hBuilder");
        if(owner == client)
            count++;
    }

    return count;
}

public void OnProjectileSpawn(int entity)
{
    int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
    if(IsValidClient(client)
    && FF2_HasAbility(FF2_GetBossIndex(client), PLUGIN_NAME, FLYING_SENTRY_NAME))
    {
        float origin[3], sentryPos[3], angles[3], angVector[3];

        GetClientEyePosition(client, origin);
        GetClientEyeAngles(client, angles);

        sentryPos[0] = origin[0];
        sentryPos[1] = origin[1];
        sentryPos[2] = origin[2];

        AcceptEntityInput(entity, "Kill");

        angles[0] = 0.0;
        GetAngleVectors(angles, angVector, NULL_VECTOR, NULL_VECTOR);
        NormalizeVector(angVector, angVector);

        ScaleVector(angVector, 60.0);
        AddVectors(sentryPos, angVector, sentryPos);

        NormalizeVector(angVector, angVector);
        angVector[0] *= 1500.0;	// Test this,
        angVector[1] *= 1500.0;
        angVector[2] *= 1500.0;

        int sentry = TF2_BuildSentry(client, origin, angles, 2);
        // SetEntityMoveType(sentry, MOVETYPE_VPHYSICS);
        SetEntityMoveType(sentry, MOVETYPE_FLYGRAVITY);

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

stock bool IsBossTeam(int client)
{
    return FF2_GetBossTeam() == TF2_GetClientTeam(client);
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

int GetParticleEffectIndex(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;

	if (table == INVALID_STRING_TABLE)
		table = FindStringTable("ParticleEffectNames");

	int iIndex = FindStringIndex(table, sEffectName);

	if (iIndex != INVALID_STRING_INDEX)
		return iIndex;

	return 0;
}

int GetEffectIndex(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;

	if (table == INVALID_STRING_TABLE)
		table = FindStringTable("EffectDispatch");

	int iIndex = FindStringIndex(table, sEffectName);

	if (iIndex != INVALID_STRING_INDEX)
		return iIndex;

	return 0;
}

void PrecacheEffect(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;

	if (table == INVALID_STRING_TABLE)
		table = FindStringTable("EffectDispatch");

	bool save = LockStringTables(false);
	AddToStringTable(table, sEffectName);
	LockStringTables(save);
}

void PrecacheParticleEffect(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;

	if (table == INVALID_STRING_TABLE)
		table = FindStringTable("ParticleEffectNames");

	bool save = LockStringTables(false);
	AddToStringTable(table, sEffectName);
	LockStringTables(save);
}

void TE_DispatchEffect(const char[] particle, const float pos[3], const float endpos[3], const float angles[3] = NULL_VECTOR, int parent = -1, int attachment = -1)
{
	TE_Start("EffectDispatch");
	TE_WriteVector("m_vStart[0]", pos);
	TE_WriteVector("m_vOrigin[0]", endpos);
	TE_WriteVector("m_vAngles", angles);
	TE_WriteNum("m_nHitBox", GetParticleEffectIndex(particle));
	TE_WriteNum("m_iEffectName", GetEffectIndex("ParticleEffect"));

	if(parent != -1)
	{
		TE_WriteNum("entindex", parent);
	}
	if(attachment != -1)
	{
		TE_WriteNum("m_nAttachmentIndex", attachment);
	}
}

stock int DispatchParticleEffect(float pos[3], float angles[3], char[] particleType, int parent=0, int time=1, int controlpoint=0)
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

		Format(temp, sizeof(temp), "OnUser1 !self:kill::%i:1", time);
		SetVariantString(temp);

		AcceptEntityInput(particle, "AddOutput");
		AcceptEntityInput(particle, "FireUser1");

		DispatchKeyValueVector(particle, "angles", angles);
		AcceptEntityInput(particle, "start");

		return particle;
	}

	return -1;
}

stock float AngleNormalize(float angle)
{
	angle = fmodf(angle, 360.0);
	if (angle > 180)
	{
		angle -= 360;
	}
	if (angle < -180)
	{
		angle += 360;
	}
	return angle;
}

stock float fmodf(float num, float denom)
{
	return num - denom * RoundToFloor(num / denom);
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
        SetEntPropEnt(sentry, Prop_Send, "m_hBuilder", builder);

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

Handle PrepSDKCall_SentryDeploy(GameData gamedata)
{
    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFWeaponBuilder::Deploy");

    Handle call = EndPrepSDKCall();
    if (!call)
        LogMessage("Failed to create SDK call: CTFWeaponBuilder::Deploy");

    return call;
}

void SDKCall_SentryDeploy(int pda)
{
	if (g_SDKCallSentryDeploy)
		SDKCall(g_SDKCallSentryDeploy, pda);
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
