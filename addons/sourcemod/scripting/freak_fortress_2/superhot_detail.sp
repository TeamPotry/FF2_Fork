#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2items>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <ff2_potry>
#include <tf2attributes>

#define PLUGIN_NAME "superhot detail"
#define PLUGIN_VERSION 	"20210814"

public Plugin myinfo=
{
	name="Freak Fortress 2: SUPERHOT Abilities",
	author="Nopied◎",
	description="One of us.",
	version=PLUGIN_VERSION,
};

#define HOTSWITCH_NAME      "hotswitch"
#define ONEOFUS_NAME        "one of us"

enum
{
	Skill_HotSwitch = 0,
	Skill_OneOfUs
}

Handle g_SDKCallGiveAmmo;

bool g_bOneOfUs[MAXPLAYERS+1];

public void OnPluginStart()
{
	HookEvent("player_spawn", OnPlayerSpawn);
	HookEvent("player_death", OnPlayerDeath);

	LoadTranslations("superhot_detail.phrases");
	FF2_RegisterSubplugin(PLUGIN_NAME);

	GameData gamedata = new GameData("potry");
	if (gamedata)
	{
		g_SDKCallGiveAmmo = PrepSDKCall_GiveAmmo(gamedata);
		delete gamedata;
	}
	else
	{
		SetFailState("Could not find potry gamedata");
	}
}

public Action FF2_PreAbility(int boss, const char[] pluginName, const char[] abilityName, int slot)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));

	if(FF2_HasAbility(boss, PLUGIN_NAME, HOTSWITCH_NAME, slot)
		|| FF2_HasAbility(boss, PLUGIN_NAME, ONEOFUS_NAME, slot))
	{
		// int target;
		bool able = GetClientAimTarget2(client) > 0;
/*
		if(able)
			able = FF2_GetBossIndex(target) == -1;
*/
		PrintCenterText(client, "%T", "Must Aim Human", client);
		return able ? Plugin_Continue : Plugin_Handled;
	}
	return Plugin_Continue;
}

public void FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status)
{
	if(StrEqual(HOTSWITCH_NAME, abilityName))
	{
		HotSwitch_Init(boss, abilityName, slot, Skill_HotSwitch);
	}

	if(StrEqual(ONEOFUS_NAME, abilityName))
	{
		HotSwitch_Init(boss, abilityName, slot, Skill_OneOfUs);
	}
}

public void HotSwitch_Init(int boss, const char[] abilityName, int slot, int type)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss)),
		target = GetClientAimTarget2(client);

	float aimTime = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, abilityName, "aim time", 2.0, slot);
	float targetPos[3];

	LookatTarget(client, target);
	LookatTarget(target, client);

	SetEntityMoveType(client, MOVETYPE_NONE);
	SetEntityMoveType(target, MOVETYPE_NONE);

	TF2_AddCondition(client, view_as<TFCond>(87), aimTime, client);
	TF2_AddCondition(target, view_as<TFCond>(87), aimTime, client);

	TF2_AddCondition(target, TFCond_Sapped, aimTime, client);

	char sound[PLATFORM_MAX_PATH];
	if(FF2_FindSound("beep", sound, PLATFORM_MAX_PATH, boss))
	{
		EmitSoundToAll(sound, client);
		EmitSoundToAll(sound, client);
		EmitSoundToAll(sound, target);
		EmitSoundToAll(sound, target);
	}

	GetEntPropVector(target, Prop_Data, "m_vecOrigin", targetPos);
	DataPack dp = new DataPack();
	CreateDataTimer(aimTime, HotSwitch_Teleport, dp, TIMER_FLAG_NO_MAPCHANGE);
	dp.WriteCell(client);
	dp.WriteCell(target);
	dp.WriteFloat(targetPos[0]);
	dp.WriteFloat(targetPos[1]);
	dp.WriteFloat(targetPos[2]);
	dp.Reset();


	GetEntPropVector(client, Prop_Data, "m_vecOrigin", targetPos);
	dp = new DataPack();
	CreateDataTimer(aimTime, HotSwitch_Teleport, dp, TIMER_FLAG_NO_MAPCHANGE);
	dp.WriteCell(target);
	dp.WriteCell(client);
	dp.WriteFloat(targetPos[0]);
	dp.WriteFloat(targetPos[1]);
	dp.WriteFloat(targetPos[2]);
	dp.Reset();

	g_bOneOfUs[target] = true;

	switch(type)
	{
		case Skill_HotSwitch:
		{
		 	dp = new DataPack();
			CreateDataTimer(aimTime, HotSwitch_Item, dp, TIMER_FLAG_NO_MAPCHANGE);
			dp.WriteCell(client);
			dp.WriteCell(target);
			dp.Reset();
		}
		case Skill_OneOfUs:
		{
			if(!IsBoss(target))
			{
				dp = new DataPack();
				CreateDataTimer(aimTime, OneOfUs_Boss, dp, TIMER_FLAG_NO_MAPCHANGE);
				dp.WriteCell(client);
				dp.WriteCell(target);
				dp.Reset();
			}
		}
	}
}

public Action HotSwitch_Teleport(Handle timer, DataPack data)
{
	int client = data.ReadCell(), target = data.ReadCell();
	if(!IsValidClient(client) || !IsValidClient(target)
		|| !IsPlayerAlive(client) || !IsPlayerAlive(target))
			return Plugin_Continue;

	SetEntityMoveType(client, MOVETYPE_WALK);

	SetEntProp(client, Prop_Send, "m_bDucked", 1);
	SetEntityFlags(client, GetEntityFlags(client)|FL_DUCKING);

	float targetPos[3];
	targetPos[0] = data.ReadFloat();
	targetPos[1] = data.ReadFloat();
	targetPos[2] = data.ReadFloat();

	TeleportEntity(client, targetPos, NULL_VECTOR, NULL_VECTOR);
	return Plugin_Continue;
}

public Action HotSwitch_Item(Handle timer, DataPack data)
{
	int client = data.ReadCell(), target = data.ReadCell();
	if(!IsValidClient(client) || !IsValidClient(target)
		|| !IsPlayerAlive(client) || !IsPlayerAlive(target))
			return Plugin_Continue;

	char classname[64];
	int index, weapon = GetPlayerWeaponSlot(target, TFWeaponSlot_Primary);
	if(!IsValidEntity(weapon))
		return Plugin_Continue;

	int attribDefIndexs[20], staticDefIndexs[20], attribDefCount, staticDefCount;
	float attribDefAttribs[20], staticDefAttribs[20];
	index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	GetEntityClassname(weapon, classname, sizeof(classname));
	attribDefCount = TF2Attrib_ListDefIndices(weapon, attribDefIndexs, sizeof(attribDefIndexs));
	staticDefCount = TF2Attrib_GetStaticAttribs(index, staticDefIndexs, staticDefAttribs, sizeof(staticDefIndexs));

	Address address;
	for(int loop = 0; loop < attribDefCount; loop++)
	{
		address = TF2Attrib_GetByDefIndex(weapon, attribDefIndexs[loop]);
		if(address != Address_Null)
			attribDefAttribs[loop] = TF2Attrib_GetValue(address);
	}

	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
	weapon = SpawnWeapon(client, classname, index, 101, 0, "");

	for(int loop = 0; loop < staticDefCount; loop++)
		TF2Attrib_SetByDefIndex(weapon, staticDefIndexs[loop], staticDefAttribs[loop]);
	for(int loop = 0; loop < attribDefCount; loop++)
		TF2Attrib_SetByDefIndex(weapon, attribDefIndexs[loop], attribDefAttribs[loop]);

	SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
	for(int loop = 0; loop < 7; loop++)
	{
		SDKCall_GiveAmmo(client, 200, loop, false);
	}

	g_bOneOfUs[target] = false;
	return Plugin_Continue;
}

public Action OneOfUs_Boss(Handle timer, DataPack data)
{
	int client = data.ReadCell(), target = data.ReadCell();
	if(!IsValidClient(client) || !IsValidClient(target)
		|| !IsPlayerAlive(client) || !IsPlayerAlive(target))
			return Plugin_Continue;

	int characterIndex = GetCharacterIndexOfBoss(FF2_GetBossIndex(client));
	FF2_MakePlayerToBoss(target, characterIndex);
	int bossindex = FF2_GetBossIndex(target);

	TF2Attrib_RemoveAll(target);
	FF2_SetBossMaxHealth(bossindex, 250);
	FF2_SetBossHealth(bossindex, 250);
	FF2_SetBossLives(bossindex, 1);
	FF2_SetBossMaxLives(bossindex, 1);
	FF2_SetBossRageDamage(bossindex, 9999999);

	PrintCenterText(target, "%T", "One Of Us", target);
	return Plugin_Continue;
}

public void FF2_OnCalledQueue(FF2HudQueue hudQueue, int client)
{
	if(!g_bOneOfUs[client])		return;

	char text[60] = "SUPERHOTSUPERHOTSUPERHOTSUPERHOTSUPERHOTSUPERHOTSUPERHOT";
	FF2HudDisplay hudDisplay = null;

	hudQueue.DeleteAllDisplay();
	hudDisplay = FF2HudDisplay.CreateDisplay("dummy", text);
	hudQueue.PushDisplay(hudDisplay);
}

public Action OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client=GetClientOfUserId(event.GetInt("userid"));
	g_bOneOfUs[client] = false;
}

public Action OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client=GetClientOfUserId(event.GetInt("userid"));
	g_bOneOfUs[client] = false;
}

Handle PrepSDKCall_GiveAmmo(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFPlayer::GiveAmmo");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);

	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDK call: CTFPlayer::GiveAmmo");

	return call;
}

int SDKCall_GiveAmmo(int player, int iCount, int iAmmoIndex, bool bSuppressSound)
{
	if (g_SDKCallGiveAmmo)
		return SDKCall(g_SDKCallGiveAmmo, player, iCount, iAmmoIndex, bSuppressSound);

	return -1;
}

//////////////////////

stock int SpawnWeapon(int client, char[] name, int index, int level, int quality, char[] attribute)
{
	Handle weapon=TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
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

stock int GetCharacterIndexOfBoss(int boss)
{
	char bossName[64], targetName[64];
	KeyValues bossKv = FF2_GetBossKV(boss);

	bossKv.Rewind();
	bossKv.GetString("name", bossName, sizeof(bossName));

	for(int loop = 0; (bossKv = FF2_GetCharacterKV(loop)); loop++)
	{
		bossKv.Rewind();
		bossKv.GetString("name", targetName, sizeof(targetName));

		if(StrEqual(bossName, targetName))
			return loop;
	}

	return -1;
}

stock bool IsBoss(int client)
{
    return FF2_GetBossIndex(client) != -1;
}

stock bool IsValidClient(int client, bool replaycheck=true)
{
	if(client<=0 || client>MaxClients)
	{
		return false;
	}

	if(!IsClientInGame(client))
	{
		return false;
	}

	if(GetEntProp(client, Prop_Send, "m_bIsCoaching"))
	{
		return false;
	}

	if(replaycheck)
	{
		if(IsClientSourceTV(client) || IsClientReplay(client))
		{
			return false;
		}
	}
	return true;
}

stock int GetClientAimTarget2(int client)
{
	float pos[3], angles[3], vecMin[3], vecMax[3], endPos[3];
	GetClientEyePosition(client, pos);
	GetClientEyeAngles(client, angles);

	GetAngleVectors(angles, angles, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(angles, 10000.0);

	float range = 20.0;
	for(int loop = 0; loop < 2; loop++)
	{
		vecMin[loop] = range * -0.5;
		vecMax[loop] = range * -0.5;
	}
	vecMax[2] = 1.0;

	AddVectors(pos, angles, endPos);

	TR_TraceHullFilter(pos, endPos, vecMin, vecMax, MASK_ALL, TraceDontHitSelf, client);

	if(!TR_DidHit())
		return -1;

	int ent = TR_GetEntityIndex();

	if(ent == 0 || GetClientTeam(client) == GetClientTeam(ent))
		return -1;

	return ent;
}

public bool TraceDontHitSelf(int entity, int contentsMask, any data)
{
	return (IsValidClient(entity) && entity != data);
}

stock void LookatTarget(int client, int target)
{
	float pos[3], targetPos[3], angles[3];

	GetClientEyePosition(client, pos);
	GetClientEyePosition(target, targetPos);

	SubtractVectors(targetPos, pos, angles);
	GetVectorAngles(angles, angles);

// 	NegateVector(angles);
	TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
}

/*
	PrintToChatAll("%.1f %.1f %.1f\n %.1f %.1f %.1f",
		pos[0], pos[1], pos[2],
		endPos[0], endPos[1], endPos[2]);

	Handle gameConfig = LoadGameConfigFile("funcommands.games");
    if (gameConfig == null)
    {
        SetFailState("Unable to load game config funcommands.games");
        return - 1;
    }

	char buffer[PLATFORM_MAX_PATH];
	int model, halo, colors[4] = {255, 255, 255, 255};
    if (GameConfGetKeyValue(gameConfig, "SpriteBeam", buffer, sizeof(buffer)) && buffer[0])
    {
        model = PrecacheModel(buffer);
    }
	if (GameConfGetKeyValue(gameConfig, "SpriteHalo", buffer, sizeof(buffer)) && buffer[0])
    {
        halo = PrecacheModel(buffer);
    }

	delete gameConfig;

	TE_SetupBeamPoints(pos, endPos, model, halo, 0, 10, 10.0, 10.0, 10.0, 0, 0.0, colors, 10);
	TE_SendToAll();

	TR_GetEndPosition(pos);
	PrintToChatAll("%N\n end: %.1f %.1f %.1f", ent,
		pos[0], pos[1], pos[2]);
*/
