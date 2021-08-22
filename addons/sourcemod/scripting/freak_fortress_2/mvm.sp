#include <sourcemod>
#include <freak_fortress_2>
#include <ff2_potry>
#include <tf2>
#include <tf2_stocks>
#include <dhooks>
#include <tf2attributes>
#include <mannvsmann>
#include <morecolors>

#define PLUGIN_VERSION "0.1"

public Plugin myinfo=
{
	name="Freak Fortress 2: Mann Vs Mann",
	author="Nopied◎",
	description="Compatible with Mann vs. Mann plugins.",
	version=PLUGIN_VERSION,
};

// Handle g_SDKCallGetChargeMaxTime;
Handle g_SDKCallPickupWeaponFromOther;

public void OnPluginStart()
{
	LoadTranslations("ff2_mvm.phrases");

	GameData gamedata = new GameData("potry");
	if (gamedata)
	{
		// g_SDKCallGetChargeMaxTime = PrepSDKCall_GetChargeMaxTime(gamedata);
		g_SDKCallPickupWeaponFromOther = PrepSDKCall_PickupWeaponFromOther(gamedata);


		// TODO: 원래 로직을 통한 무기 부여가 아닌 새로운 무기 부여로 바꿀 것
		// 무기 던지기 추가 (CTFDroppedWeapon::InitDroppedWeapon > bSwap)
		// 무기가 떨어진 무기가 되는 순간에 능력치 등의 정보들을 복사할 것. (CTFDroppedWeapon::InitDroppedWeapon)
		// 능력치 모두 삭제시킨 장비에 슈퍼핫의 능력치 복사를 이용하여 새로 부여할 것 (DHookCallback_PickupWeaponFromOther_Pre)
		// 보스팀 유저 필터링 (DHookCallback_CanPickupDroppedWeapon_Pre)
		CreateDynamicDetour(gamedata, "CTFPlayer::CanPickupDroppedWeapon", DHookCallback_CanPickupDroppedWeapon_Pre);
		CreateDynamicDetour(gamedata, "CTFPlayer::PickupWeaponFromOther", DHookCallback_PickupWeaponFromOther_Pre);
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

public MRESReturn DHookCallback_CanPickupDroppedWeapon_Pre(int client, DHookReturn ret, DHookParam params)
{
	if(client==-1)			return MRES_Ignored;

	int weapon = params.Get(1),
		weaponOwner = GetIndexOfAccountID(GetEntProp(weapon, Prop_Send, "m_iAccountID"));

	PrintToChatAll("client = %N, weaponOwner = %d, weapon = %d", client, weaponOwner, weapon);
	ret.Value = true;

	PrintToChatAll("%s, %X", SDKCall_PickupWeaponFromOther(client, weapon) ? "picked" : "no", g_SDKCallPickupWeaponFromOther);

	return MRES_ChangedOverride;
}

public MRESReturn DHookCallback_PickupWeaponFromOther_Pre(int client, DHookReturn ret, DHookParam params)
{
	if(client==-1)			return MRES_Ignored;

	PrintToChatAll("client = %N, trying to pick", client);
	// 무기 던지기

	// 무기 복사 후
	ret.Value = true;
	return MRES_ChangedOverride;
}

public void OnMapStart()
{
	PrecacheSound("mvm/mvm_money_pickup.wav");
}

public void FF2_OnCalledQueue(FF2HudQueue hudQueue, int client)
{
	float carteenCooltime = MVM_GetPlayerCarteenCooldown(client);
	// float sapperMaxCooldown, sapperBegintime;

	if(!IsPlayerAlive(client))	return;

	char text[60];
	FF2HudDisplay hudDisplay = null;
	hudQueue.GetName(text, sizeof(text));

// 	int sapper = GetPlayerWeaponSlot(client, 1);
	bool hasCarteenCooldown = carteenCooltime > 0.0;
/*
	bool hasSapperCooldown = ((sapper != -1 && IsSapper(sapper)) && (sapperMaxCooldown = SDKCall_GetChargeMaxTime(sapper)) > 0.0
			&& (GetGameTime() - ((sapperBegintime = GetEntPropFloat(sapper, Prop_Send, "m_flChargeBeginTime")) + sapperMaxCooldown)) < 0.0);

	PrintToChatAll("hasSapper = %s, hasSapperCooldown = %s, sapperBegintime = %.1f, sapperMaxCooldown = %.1f", (sapper != -1 && IsSapper(sapper)) ? "true" : "false", hasSapperCooldown ? "true" : "false", sapperBegintime, sapperMaxCooldown);
*/
	if(StrEqual(text, "Player Additional"))
	{
		if(hasCarteenCooldown)
		{
			Format(text, sizeof(text), "%t: %.1f", "Carteen Cooldown", carteenCooltime);
			hudDisplay = FF2HudDisplay.CreateDisplay("Carteen Cooldown", text);
			hudQueue.PushDisplay(hudDisplay);
		}
		/*
		if(hasSapperCooldown)
		{
			Format(text, sizeof(text), "%t: %d%%", "Sapper Charge",
				RoundFloat(GetGameTime() / (sapperBegintime + sapperMaxCooldown)));
			hudDisplay = FF2HudDisplay.CreateDisplay("Sapper Charge", text);
			hudQueue.PushDisplay(hudDisplay);
		}
		*/
	}
}

public Action FF2_OnSpecialAttack(int attacker, int victimBoss, int weapon, const char[] name, float &damage)
{
	Address address = Address_Null;

	if(StrEqual("backstab", name))
	{
		address = TF2Attrib_GetByDefIndex(weapon, 399); // armor_piercing
		if(address != Address_Null)
		{
			damage *= (TF2Attrib_GetValue(address) * 0.01) + 1.0;
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

public void FF2_OnWaveStarted(int wave)
{
	int boss;

	for(int client = 1; client <= MaxClients; client++)
	{
		if(!IsClientInGame(client)) 		continue;

		MVM_SetPlayerCurrency(client, MVM_GetPlayerCurrency(client) + 200);

		if(IsBoss(client) && FF2_GetBossTeam() == TF2_GetClientTeam(client))
		{
			boss = FF2_GetBossIndex(client);

			int beforeHealth = FF2_GetBossMaxHealth(boss), heal = RoundFloat(FF2_GetBossMaxHealth(boss) * 1.03);
			heal -= beforeHealth;

			FF2_SetBossHealth(boss, FF2_GetBossHealth(boss) + heal);
			FF2_SetBossMaxHealth(boss, FF2_GetBossMaxHealth(boss) + (heal / FF2_GetBossMaxLives(boss)));

			Address address = TF2Attrib_GetByDefIndex(client, 252);

			float value = 0.98;
			if(address != Address_Null)
				value = TF2Attrib_GetValue(address) - 0.02;

			TF2Attrib_SetByDefIndex(client, 252, value);
		}
		else
		{
			EmitSoundToClient(client, "mvm/mvm_money_pickup.wav");
		}
	}

	CPrintToChatAll("{olive}[FF2]{default} %t", "Wave Started");
}

public Action MVM_OnTouchedUpgradeStation(int upgradeStation, int client)
{
	if(IsBoss(client) || (FF2_GetFF2Flags(client) & FF2FLAG_CLASSTIMERDISABLED) > 0)
		return Plugin_Handled;

	return Plugin_Continue;
}

Handle PrepSDKCall_PickupWeaponFromOther(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFPlayer::PickupWeaponFromOther");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);

	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDK call: CTFPlayer::PickupWeaponFromOther");

	return call;
}

bool SDKCall_PickupWeaponFromOther(int player, int weapon)
{
	if (g_SDKCallPickupWeaponFromOther)
		return SDKCall(g_SDKCallPickupWeaponFromOther, player, weapon);

	return false;
}

/*
Handle PrepSDKCall_GetChargeMaxTime(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFWeaponSapper::GetChargeMaxTime");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);

	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDK call: CTFWeaponSapper::GetChargeMaxTime");

	return call;
}

float SDKCall_GetChargeMaxTime(int sapper)
{
	if (g_SDKCallGetChargeMaxTime)
		return SDKCall(g_SDKCallGetChargeMaxTime, sapper);

	return -1.0;
}
*/

stock bool IsBoss(int client)
{
	return FF2_GetBossIndex(client) != -1;
}

stock bool IsSapper(int sapper)
{
	char classname[64];
	GetEntityClassname(sapper, classname, sizeof(classname));

	return StrEqual(classname, "tf_weapon_builder") || StrEqual(classname, "tf_weapon_sapper");
}

stock int GetIndexOfAccountID(int id)
{
	char auth[32], idString[3][32];
	for(int client = 1; client <= MaxClients; client++)
	{
		if(!IsClientInGame(client) || IsFakeClient(client))
			continue;

		GetClientAuthId(client, AuthId_Steam3, auth, 32);
		ExplodeString(auth, ":", idString, 3, 32);

		if(StringToInt(idString[2]) == id)
			return client;
	}
	return -1;
}
