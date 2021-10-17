#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2items>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <ff2_potry>
#include <tf2attributes>
#include <tf2utils>

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
Handle g_SDKCallGetMaxAmmo;

bool g_bRageBlock[MAXPLAYERS+1];
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
		g_SDKCallGetMaxAmmo = PrepSDKCall_GetMaxAmmo(gamedata);
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

	if(g_bRageBlock[client] || g_bOneOfUs[client])
		return Plugin_Handled;

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

	g_bRageBlock[target] = true;

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
			dp = new DataPack();
			CreateDataTimer(aimTime, HotSwitch_Item, dp, TIMER_FLAG_NO_MAPCHANGE);
			dp.WriteCell(client);
			dp.WriteCell(target);
			dp.Reset();

			if(!IsBoss(target))
			{
				dp = new DataPack();
				CreateDataTimer(aimTime + 0.1, OneOfUs_Boss, dp, TIMER_FLAG_NO_MAPCHANGE);
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

	if(IsPlayerAlive(client))
		SetEntityMoveType(client, MOVETYPE_WALK);

	if(!IsValidClient(client) || !IsValidClient(target)
		|| !IsPlayerAlive(client) || !IsPlayerAlive(target))
			return Plugin_Continue;

	SetEntProp(client, Prop_Send, "m_bDucked", 1);
	SetEntityFlags(client, GetEntityFlags(client)|FL_DUCKING);

	float targetPos[3];
	targetPos[0] = data.ReadFloat();
	targetPos[1] = data.ReadFloat();
	targetPos[2] = data.ReadFloat();

	TeleportEntity(client, targetPos, NULL_VECTOR, NULL_VECTOR);
	// LookatTarget(client, target);

	return Plugin_Continue;
}

public Action HotSwitch_Item(Handle timer, DataPack data)
{
	int client = data.ReadCell(), target = data.ReadCell();
	if(!IsValidClient(client) || !IsValidClient(target)
		|| !IsPlayerAlive(client) || !IsPlayerAlive(target))
			return Plugin_Continue;

	TF2_SetPlayerClass(client, TF2_GetPlayerClass(target), false, false);

	char classname[64];
	for(int slot = TFWeaponSlot_Item2; slot >= TFWeaponSlot_Primary; slot--)
	{
		if(slot == TFWeaponSlot_Melee
			// 엔지니어 필터링
			|| (TF2_GetPlayerClass(target) == TFClass_Engineer && (slot == 3 || slot == 4 || slot == 5))
			)
			continue;

		int index, beforeWeapon = GetPlayerWeaponSlot(target, slot), weapon;
		if(!IsValidEntity(beforeWeapon))
			continue;

		// ArrayList array = new ArrayList();
		// ArrayStack stack = new ArrayStack(), attribStack = new ArrayStack();
		char attributes[256];
		int attribDefIndexs[20], attribDefCount, clip, count = 0;
		float attribDefAttribs[20];
		index = GetEntProp(beforeWeapon, Prop_Send, "m_iItemDefinitionIndex");
		GetEntityClassname(beforeWeapon, classname, sizeof(classname));
		attribDefCount = TF2Attrib_ListDefIndices(beforeWeapon, attribDefIndexs, sizeof(attribDefIndexs));

		// PrintToServer("slot: %d, %s", slot, classname);
		Address address;
		for(int loop = 0; loop < attribDefCount; loop++)
		{
			// if(IsBanned(attribDefIndexs[loop]))
				// continue;

			address = TF2Attrib_GetByDefIndex(beforeWeapon, attribDefIndexs[loop]);
			if(address != Address_Null)
			{
				attribDefAttribs[loop] = TF2Attrib_GetValue(address);

				if(count == 0)
					Format(attributes, sizeof(attributes), "%d ; %.1f", attribDefIndexs[loop], attribDefAttribs[loop]);
				else
					Format(attributes, sizeof(attributes), "%s ; %d ; %.1f", attributes, attribDefIndexs[loop], attribDefAttribs[loop]);
				// stack.Push(attribDefIndexs[loop]);
				// attribStack.Push(attribDefAttribs[loop]);

				count++;
			}
		}

		TF2_RemoveWeaponSlot(client, slot);
		weapon = SpawnWeapon(client, classname, index, 101, 0, attributes);

		if(StrEqual(classname, "tf_weapon_spellbook"))
		{
			SetEntProp(weapon, Prop_Send, "m_iSpellCharges", GetEntProp(beforeWeapon, Prop_Send, "m_iSpellCharges"));
			SetEntProp(weapon, Prop_Send, "m_iSelectedSpellIndex", GetEntProp(beforeWeapon, Prop_Send, "m_iSelectedSpellIndex"));
		}

		/*
			NOTE: 용의 격노는 현재 작동되지 않음
			일부 클라이언트의 경우, 한번에 능력치를 적용하면 크래쉬가 생기는 현상이 있어
			한 프레임에 능력치 하나씩 밀어넣는 구조로 변경됨.
		*/
		// 기본 화염방사기 지급
/*
		if(index == 1178)
		{
			PrintCenterText(client, "THIS IS BUG. I WILL FIX THIS AS SOON.");
			weapon = SpawnWeapon(client, "tf_weapon_flamethrower", 208, 101, 0, "");
		}
		else
			weapon = SpawnWeapon(client, classname, index, 101, 0, attributes);
*/
		// weapon = SpawnWeapon(client, classname, index, 101, 0, attributes);
		// TF2Attrib_RemoveAll(weapon);

		// array.Push(weapon);
		// array.Push(stack);
		// array.Push(attribStack);

		// RequestFrame(AddAttribs, array);

		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);

		if(HasEntProp(weapon, Prop_Data, "m_iClip1"))
		{
			clip = GetEntProp(weapon, Prop_Data, "m_iClip1");
			SetEntProp(weapon, Prop_Data, "m_iClip1", clip);
			int ammoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
			if(ammoType != -1)
			{
				int maxAmmo = SDKCall_GetMaxAmmo(client, ammoType, view_as<int>(TF2_GetPlayerClass(target)));
				// int ammo = GetEntProp(target, Prop_Data, "m_iAmmo", _, ammoType);
				SetEntProp(client, Prop_Data, "m_iAmmo",
					maxAmmo, _, ammoType);
			}
		}

		SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime()+1.0);
		SetEntPropFloat(client, Prop_Send, "m_flNextAttack", GetGameTime()+1.0);
		SetEntPropFloat(client, Prop_Send, "m_flStealthNextChangeTime", GetGameTime()+1.0);
	}

	// FIXME: TF2Util_GetPlayerWearableCount always return 0.
	int wearableCount = TF2Util_GetPlayerWearableCount(client);
	// PrintToServer("wearableCount: %d", wearableCount);
	for(int slot = 0; slot < wearableCount; slot++)
	{
		int index, weapon = TF2Util_GetPlayerWearable(target, slot);
		if(!IsValidEntity(weapon))
			continue;

		int attribDefIndexs[20], attribDefCount, count = 0;
		float attribDefAttribs[20];
		Address address;

		index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
		GetEntityClassname(weapon, classname, sizeof(classname));
		attribDefCount = TF2Attrib_ListDefIndices(weapon, attribDefIndexs, sizeof(attribDefIndexs));

		for(int loop = 0; loop < attribDefCount; loop++)
		{
			address = TF2Attrib_GetByDefIndex(weapon, attribDefIndexs[loop]);
			attribDefAttribs[loop] = TF2Attrib_GetValue(address);
		}

		// PrintToServer("%s", classname);
		if(StrEqual(classname, "tf_wearable_demoshield"))
		{
			weapon = TF2_SpawnDemoShield(index);
		}
		else // tf_wearable
		{
			TF2Util_EquipPlayerWearable(client, weapon);
			weapon = GetWearableSlotOfIndex(client, index);
		}

		for(int loop = 0; loop < attribDefCount; loop++)
		{
			TF2Attrib_SetByDefIndex(weapon, attribDefIndexs[loop], attribDefAttribs[loop]);
		}
	}

	g_bRageBlock[target] = false;
	return Plugin_Continue;
}

stock bool IsBanned(int index)
{
	switch(index)
	{
		case 719, 731:
		{
			return true;
		}
	}
	return false;
}

public void AddAttribs(ArrayList array)
{
	int weapon = array.Get(0);
	ArrayStack stack = array.Get(1), attribStack = array.Get(2);

	if(attribStack.Empty)
	{
		delete stack;
		delete attribStack;
		delete array;

		return;
	}
	int index = stack.Pop();
	float value = attribStack.Pop();

	Address address = TF2Attrib_GetByDefIndex(weapon, index);
	if(value != 0.0)
	{
		if(address == Address_Null)
		{
			TF2Attrib_SetByDefIndex(weapon, index, value);
		}
		else
		{
			TF2Attrib_RemoveByDefIndex(weapon, index);
			TF2Attrib_SetByDefIndex(weapon, index, value);
		}
	}

	RequestFrame(AddAttribs, array);
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
	FF2_SetBossMaxHealth(bossindex, 300);
	FF2_SetBossHealth(bossindex, 300);
	FF2_SetBossLives(bossindex, 1);
	FF2_SetBossMaxLives(bossindex, 1);
	FF2_SetBossRageDamage(bossindex, 9999999);

	// FF2_MakePlayerToBoss가 리스폰 취급이므로 필요함.
	g_bRageBlock[target] = true;
	PrintCenterText(target, "%T", "One Of Us", target);

	// Permanent Rage block
	g_bOneOfUs[target] = true;
	return Plugin_Continue;
}

public void FF2_OnCalledQueue(FF2HudQueue hudQueue, int client)
{
	if(!g_bRageBlock[client] && !g_bOneOfUs[client])		return;

	char text[128] = "SUPERHOTSUPERHOTSUPERHOTSUPERHOTSUPERHOTSUPERHOTSUPERHOTSUPERHOTSUPERHOTSUPERHOTSUPERHOTSUPERHOTSUPERHOT";
	FF2HudDisplay hudDisplay = null;

	hudQueue.DeleteAllDisplay();
	hudDisplay = FF2HudDisplay.CreateDisplay("dummy", text);
	hudQueue.PushDisplay(hudDisplay);
}

public Action OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client=GetClientOfUserId(event.GetInt("userid"));
	g_bRageBlock[client] = false;
	g_bOneOfUs[client] = false;
}

public Action OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client=GetClientOfUserId(event.GetInt("userid"));
	g_bRageBlock[client] = false;
	g_bOneOfUs[client] = false;
}

//////////////////////////////////////

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
/*
int SDKCall_GiveAmmo(int player, int iCount, int iAmmoIndex, bool bSuppressSound)
{
	if (g_SDKCallGiveAmmo)
		return SDKCall(g_SDKCallGiveAmmo, player, iCount, iAmmoIndex, bSuppressSound);

	return -1;
}
*/
Handle PrepSDKCall_GetMaxAmmo(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFPlayer::GetMaxAmmo");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);

	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDK call: CTFPlayer::GiveAmmo");

	return call;
}

int SDKCall_GetMaxAmmo(int player, int iAmmoIndex, int iClassIndex = -1)
{
	if (g_SDKCallGetMaxAmmo)
		return SDKCall(g_SDKCallGetMaxAmmo, player, iAmmoIndex, iClassIndex);

	return 0;
}

//////////////////////

stock int SpawnWeapon(int client, char[] name, int index, int level, int quality, char[] attribute)
{
	Handle weapon=TF2Items_CreateItem(FORCE_GENERATION|PRESERVE_ATTRIBUTES);
	TF2Items_SetClassname(weapon, name);
	TF2Items_SetItemIndex(weapon, index);
	TF2Items_SetLevel(weapon, level);
	TF2Items_SetQuality(weapon, quality);
	TF2Items_SetNumAttributes(weapon, 15);
	char attributes[32][32];
	int count = ExplodeString(attribute, ";", attributes, 32, 32);
	if(count%2!=0)
	{
		count--;
	}

	if(count>0)
	{
		// TF2Items_SetNumAttributes(weapon, count/2);
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

stock int min(int a, int b)
{
	return a < b ? a : b;
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

	static float range = 20.0;
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

	SubtractVectors(pos, targetPos, angles);
	GetVectorAngles(angles, angles);

	if(angles[0] > 90.0)
		angles[0] = -(angles[0] - 360.0);
	else
		angles[0] *= -1.0;
	angles[1] -= 180.0;

	// PrintToChatAll("%N, %.1f, %.1f, %.1f", client, angles[0], angles[1], angles[2]);

	// FIXME: 각도는 맞는데 이 값이 반영되지 않음
	SetEntPropFloat(client, Prop_Send, "m_angEyeAngles[0]", angles[0]);
	SetEntPropFloat(client, Prop_Send, "m_angEyeAngles[1]", angles[1]);
	// TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
	// ForcePlayerViewAngles(client, angles);
	//
	// PrintToChatAll("%N, NOW: %.1f, %.1f, %.1f", client, angles[0], angles[1], angles[2]);
}

/**
 * From https://github.com/nosoop/stocksoup/blob/master/tf/econ.inc
 * Creates a wearable DemoShield entity.
 *
 * Wearables spawned via this method and equipped on human players are not visible to other
 * human players due to economy rules.  You're on your own there.
 *
 * If defindex is set to DEFINDEX_UNDEFINED, the item is not initialized, and no quality or
 * level is applied.
 *
 * @param defindex		Wearable definition index.
 * @param quality		Wearable quality.
 * @param level			Wearable level.
 */
stock int TF2_SpawnDemoShield(int defindex = -1, int quality = 6, int level = 1) {
	int wearable = CreateEntityByName("tf_wearable_demoshield");

	if (IsValidEntity(wearable)) {
		SetEntProp(wearable, Prop_Send, "m_iItemDefinitionIndex", defindex);

		if (defindex != -1) {
			// using defindex of a valid item
			SetEntProp(wearable, Prop_Send, "m_bInitialized", 1);

			SetEntProp(wearable, Prop_Send, "m_iEntityLevel", level);

			// Something about m_iEntityQuality doesn't play nice with SetEntProp.
			SetEntData(wearable, FindSendPropInfo("CTFWearable", "m_iEntityQuality"), quality);
		}

		// Spawn.
		DispatchSpawn(wearable);
	}
	return wearable;
}

stock int GetWearableSlotOfIndex(int client, int defindex)
{
	int wearableCount = TF2Util_GetPlayerWearableCount(client), index, wearable;

	for(int slot = 0; slot < wearableCount; slot++)
	{
		wearable = TF2Util_GetPlayerWearable(client, slot);
		if((index = GetEntProp(wearable, Prop_Send, "m_iItemDefinitionIndex")) == defindex)
			return wearable;
	}

	return -1;
}


stock void ForcePlayerViewAngles(iClient, float vAng[3]) // TODO: Base this off of the info_player_teamspawn under you.
{
    Handle bf = StartMessageOne("ForcePlayerViewAngles", iClient);
    BfWriteByte(bf, 1);
    BfWriteByte(bf, iClient);
    BfWriteAngles(bf, vAng);
    EndMessage();
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
