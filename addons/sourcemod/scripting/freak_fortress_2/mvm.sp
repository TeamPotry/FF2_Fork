#include <sourcemod>
#include <freak_fortress_2>
#include <ff2_modules/general>
#include <tf2>
#include <tf2_stocks>
#include <dhooks>
#include <tf2items>
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

Handle g_SDKCallInitDroppedWeapon;
Handle g_SDKCallPickupWeaponFromOther;

enum
{
	Dropped_Index,
	Dropped_Owner,
	Dropped_Flags,
	Dropped_ClassName,
	Dropped_ItemIndex,
	Dropped_ItemClass,
	Dropped_ItemSlot,
	Dropped_Clip,
	Dropped_Ammo,
	Dropped_AmmoType,
	Dropped_ChargeMeter,
	Dropped_AttributeCount,

	Dropped_ItemCount_MAX
};

methodmap CTFDroppedWeapon < ArrayList {
	// NOTE: 내부 취급에만 쓰임
    public static native CTFDroppedWeapon Create(int owner, int droppedWeapon, int flags = 0);

	property int Index {
		public get() {
			return this.Get(Dropped_Index);
		}
		public set(int index) {
			this.Set(Dropped_Index, index);
		}
	}
	property int Owner {
		public get() {
			return this.Get(Dropped_Owner);
		}
		public set(int owner) {
			this.Set(Dropped_Owner, owner);
		}
	}
	property int Flags {
		public get() {
			return this.Get(Dropped_Flags);
		}
		public set(int flags) {
			this.Set(Dropped_Flags, flags);
		}
	}
	property int ItemIndex {
		public get() {
			return this.Get(Dropped_ItemIndex);
		}
		public set(int index) {
			this.Set(Dropped_ItemIndex, index);
		}
	}
	property TFClassType ItemClass {
		public get() {
			return this.Get(Dropped_ItemClass);
		}
		public set(TFClassType class) {
			this.Set(Dropped_ItemClass, class);
		}
	}
	property int ItemSlot {
		public get() {
			return this.Get(Dropped_ItemSlot);
		}
		public set(int slot) {
			this.Set(Dropped_ItemSlot, slot);
		}
	}
	property int Clip {
		public get() {
			return this.Get(Dropped_Clip);
		}
		public set(int clip) {
			this.Set(Dropped_Clip, clip);
		}
	}
	property int Ammo {
		public get() {
			return this.Get(Dropped_Ammo);
		}
		public set(int ammo) {
			this.Set(Dropped_Ammo, ammo);
		}
	}
	property int AmmoType {
		public get() {
			return this.Get(Dropped_AmmoType);
		}
		public set(int ammotype) {
			this.Set(Dropped_AmmoType, ammotype);
		}
	}
	property float ChargeMeter {
		public get() {
			return this.Get(Dropped_ChargeMeter);
		}
		public set(float charge) {
			this.Set(Dropped_ChargeMeter, charge);
		}
	}
	property int AttributeCount {
		public get() {
			return this.Get(Dropped_AttributeCount);
		}
		public set(int count) {
			this.Set(Dropped_AttributeCount, count);
		}
	}

	public void GetClassname(char[] name, int buffer)
	{
		this.GetString(Dropped_ClassName, name, buffer);
	}

	public void SetClassname(const char[] name)
	{
		this.SetString(Dropped_ClassName, name);
	}

	public void ExportAttributes(int newWeapon)
	{
		int itemMax = Dropped_ItemCount_MAX + 40;
		for(int loop = Dropped_ItemCount_MAX; loop <= itemMax; loop++)
		{
			int attributeIndex = this.Get(loop);
			if(attributeIndex == 0)			break;

			float attributes = this.Get(++loop);
			TF2Attrib_SetByDefIndex(newWeapon, attributeIndex, attributes);
		}
	}

	public void ImportAttributes(int weapon)
	{
		int attributeIndexs[20];
		this.AttributeCount = TF2Attrib_ListDefIndices(weapon, attributeIndexs, 20);

		for(int loop = 0; loop < 20; loop++)
		{
			int realIndex = loop * 2;
			this.Set(Dropped_ItemCount_MAX + realIndex, attributeIndexs[loop]);

			Address address = TF2Attrib_GetByDefIndex(weapon, attributeIndexs[loop]);
			if(address == Address_Null)
			{
				this.Set(Dropped_ItemCount_MAX + (realIndex + 1), 0.0);
			}
			else
			{
				float attribute = TF2Attrib_GetValue(address);
				this.Set(Dropped_ItemCount_MAX + (realIndex + 1), attribute);
			}
		}
	}
}

#define	MAX_EDICT_BITS		12
#define	MAX_EDICTS			(1 << MAX_EDICT_BITS)

CTFDroppedWeapon g_hDroppedWeapons[MAX_EDICTS];
bool g_bForceEquip;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("CTFDroppedWeapon.Create", Native_CTFDroppedWeapon_Create);

	// ff2_modules/general.inc
	CreateNative("FF2_DropWeapon", Native_DropWeapon);
	CreateNative("FF2_EqiupWeaponFromDropped", Native_EqiupWeaponFromDropped);

	return APLRes_Success;
}

public int Native_CTFDroppedWeapon_Create(Handle plugin, int numParams)
{
	// Dropped_ItemCount_MAX 이후부터 40칸 까지는 능력치 공간
	CTFDroppedWeapon array = view_as<CTFDroppedWeapon>(new ArrayList(64, Dropped_ItemCount_MAX + 40));

	array.Owner = GetNativeCell(1);
	array.Index = GetNativeCell(2);
	array.Flags = GetNativeCell(3);

	char classname[64];
	GetEntityClassname(array.Index, classname, sizeof(classname));
	array.SetClassname(classname);

	array.ItemIndex = GetEntProp(array.Index, Prop_Send, "m_iItemDefinitionIndex");
	array.ItemClass = TF2_GetPlayerClass(array.Owner);

	int id = GetSteamAccountID(array.Owner, true);
	SetEntProp(array.Index, Prop_Send, "m_iAccountID", id);

	int itemSlot = -1;
	for(int loop = TFWeaponSlot_Primary; loop <= TFWeaponSlot_Melee; loop++)
	{
		int weapon = GetPlayerWeaponSlot(array.Owner, loop);
		if(weapon > 0 && array.ItemIndex == GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"))
		{
			itemSlot = loop;
			break;
		}
	}
	// PrintToServer("array.Index: %d, ItemIndex: %d, itemSlot: %d", array.Index, array.ItemIndex, itemSlot);
	array.ItemSlot = itemSlot;

	array.Clip = 0;
	array.Ammo = 0;
	array.AmmoType = 0;
	array.ChargeMeter = 0.0;

	array.AmmoType = GetEntProp(array.Index, Prop_Send, "m_iPrimaryAmmoType");
	if(array.AmmoType != -1)
	{
		array.Clip = GetEntProp(array.Index, Prop_Data, "m_iClip1");
		array.Ammo = GetEntProp(array.Owner, Prop_Data, "m_iAmmo", _, array.AmmoType);
	}
	if(HasEntProp(array.Index, Prop_Send, "m_flChargeLevel"))
	{
		array.ChargeMeter = GetEntPropFloat(array.Index, Prop_Send, "m_flChargeLevel");
	}

	return view_as<int>(array);
}

public int Native_DropWeapon(Handle plugin, int numParams)
{
	return DropWeapon(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3), true);
}

public /*void*/int Native_EqiupWeaponFromDropped(Handle plugin, int numParams)
{
	EqiupWeaponFromDropped(GetNativeCell(1), GetNativeCell(2));
	return 0;
}

public void OnPluginStart()
{
	HookEvent("teamplay_round_start", OnRoundStart);
	HookEvent("player_death", OnPlayerDeath);

	LoadTranslations("ff2_mvm.phrases");

	GameData gamedata = new GameData("potry");
	if (gamedata)
	{
		g_SDKCallPickupWeaponFromOther = PrepSDKCall_PickupWeaponFromOther(gamedata);
		g_SDKCallInitDroppedWeapon = PrepSDKCall_InitDroppedWeapon(gamedata);

		// TODO: 원래 로직을 통한 무기 부여가 아닌 새로운 무기 부여로 바꿀 것
		// 무기 던지기 추가 (CTFDroppedWeapon::InitDroppedWeapon > bSwap)
		// 무기가 떨어진 무기가 되는 순간에 능력치 등의 정보들을 복사할 것. (CTFDroppedWeapon::InitDroppedWeapon)
		// 능력치 모두 삭제시킨 장비에 슈퍼핫의 능력치 복사를 이용하여 새로 부여할 것 (DHookCallback_PickupWeaponFromOther_Pre)
		// 보스팀 유저 필터링 (DHookCallback_CanPickupDroppedWeapon_Pre)
		CreateDynamicDetour(gamedata, "CTFDroppedWeapon::Create", DHookCallback_CTFDroppedWeapon_Create_Pre, DHookCallback_CTFDroppedWeapon_Create_Post);
		CreateDynamicDetour(gamedata, "CTFDroppedWeapon::InitDroppedWeapon", DHookCallback_InitDroppedWeapon_Pre, DHookCallback_InitDroppedWeapon_Post);
		// CreateDynamicDetour(gamedata, "CTFPlayer::CanPickupDroppedWeapon", DHookCallback_CanPickupDroppedWeapon_Post);
		CreateDynamicDetour(gamedata, "CTFPlayer::PickupWeaponFromOther", DHookCallback_PickupWeaponFromOther_Pre, DHookCallback_PickupWeaponFromOther_Post);

		delete gamedata;
	}
	else
	{
		SetFailState("Could not find potry gamedata");
	}
}

public void OnEntityDestroyed(int entity)
{
	if(entity == -1)	return;

	char classname[64];
	GetEntityClassname(entity, classname, sizeof(classname));
	if(StrEqual(classname, "tf_dropped_weapon"))
	{
		if(g_hDroppedWeapons[entity] != null)
			delete g_hDroppedWeapons[entity];
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

public MRESReturn DHookCallback_CTFDroppedWeapon_Create_Pre(int droppedWeapon, DHookReturn ret, DHookParam params)
{
	SetMannVsMachineMode(false);

	return MRES_Ignored;
}

public MRESReturn DHookCallback_CTFDroppedWeapon_Create_Post(int droppedWeapon, DHookReturn ret, DHookParam params)
{
	ResetMannVsMachineMode();

	return MRES_Ignored;
}

bool g_bSwapCheck = false;

public MRESReturn DHookCallback_InitDroppedWeapon_Pre(int droppedWeapon, DHookParam params)
{
	SetMannVsMachineMode(false);
	if(droppedWeapon == -1)			return MRES_Ignored;

	int weaponOwner = params.Get(1);
	// PrintToServer("droppedWeapon: %d, weaponOwner: %d", droppedWeapon, weaponOwner);

	if(g_bSwapCheck || FF2_GetBossTeam() == TF2_GetClientTeam(weaponOwner) || FF2_GetBossIndex(weaponOwner) != -1)
	{
		if(g_bSwapCheck)
			g_bSwapCheck = false;

		RemoveEntity(droppedWeapon);
		return MRES_Supercede;
	}

	int realWeapon = params.Get(2);
	// PrintToServer("Switching with realWeapon: %d", realWeapon);

	g_hDroppedWeapons[droppedWeapon] = CTFDroppedWeapon.Create(weaponOwner, realWeapon);
	g_hDroppedWeapons[droppedWeapon].ImportAttributes(realWeapon);

	if(g_hDroppedWeapons[droppedWeapon].ChargeMeter > 0.0)
		SetEntPropFloat(droppedWeapon, Prop_Send, "m_flChargeLevel", g_hDroppedWeapons[droppedWeapon].ChargeMeter);
	TF2Attrib_RemoveAll(droppedWeapon);

	return MRES_Ignored;
}

public MRESReturn DHookCallback_InitDroppedWeapon_Post(int droppedWeapon, DHookParam params)
{
	ResetMannVsMachineMode();
	return MRES_Ignored;
}

/*
public MRESReturn DHookCallback_CanPickupDroppedWeapon_Post(int client, DHookParam params)
{
	if(client==-1)			return MRES_Ignored;

	int weapon = params.Get(1),
		weaponOwner = g_hDroppedWeapons[weapon].Owner;

	if(weaponOwner > 0 && TF2_GetClientTeam(weaponOwner) != TF2_GetClientTeam(client))
		return MRES_Supercede;

	return MRES_Ignored;
}
*/
int g_hCurrentWeapon;

public MRESReturn DHookCallback_PickupWeaponFromOther_Pre(int client, DHookReturn ret, DHookParam params)
{
	SetMannVsMachineMode(false);

	int droppedWeapon = params.Get(1);
	// int weaponOwner = g_hDroppedWeapons[droppedWeapon].Owner;

	if(FF2_GetBossTeam() == TF2_GetClientTeam(client) || FF2_GetBossIndex(client) != -1)
	{
		ret.Value = false;
		return MRES_Supercede;
	}

	g_hCurrentWeapon = GetPlayerWeaponSlot(client, g_hDroppedWeapons[droppedWeapon].ItemSlot);
/*
	if(g_hDroppedWeapons[droppedWeapon].ItemClass != TF2_GetPlayerClass(client)
		|| TF2_GetClientTeam(weaponOwner) != TF2_GetClientTeam(client))
	{
		ret.Value = false;
		return MRES_Supercede;
	}
*/
	return MRES_Ignored;
}

public MRESReturn DHookCallback_PickupWeaponFromOther_Post(int client, DHookReturn ret, DHookParam params)
{
	ResetMannVsMachineMode();
	PrintToServer("client: %d, PickupWeaponFromOther: %s", client, ret.Value ? "true" : "false");
	if(!ret.Value || client==-1)			return MRES_Ignored;

	SetMannVsMachineMode(false);

	int droppedWeapon = params.Get(1);
	// NOTE: Freak Fortress 2의 아이템 보정을 통한 아이템 모두 떨어진 상태에서 주워지지 않음. 따라서 쭙는 것을 따라하는 것으로 변경
	// 떨어졌던 무기를 들었다면 지금 값이 변함, 그 외에는 막힌 것.
	// 따라한 로직은 아마 파이로의 용의 분노를 또 망가뜨릴 수 있음.. (SUPERHOT의 일반분노 버그)
	int currentWeapon = GetPlayerWeaponSlot(client, g_hDroppedWeapons[droppedWeapon].ItemSlot);
	bool allowSwap = g_hDroppedWeapons[droppedWeapon].Flags & DROPPED_DONTALLOW_SWAP == 0;

	// PrintToServer("g_hCurrentWeapon: %d, currentWeapon: %d", g_hCurrentWeapon, currentWeapon);

	if((IsValidEntity(currentWeapon) || g_bForceEquip) || g_hCurrentWeapon == currentWeapon)
	{
		if(allowSwap)
		{
			int dropped = DropWeapon(client, currentWeapon);
			if(dropped != -1)
				SDKCall_InitDroppedWeapon(dropped, client, currentWeapon, true, false);
		}
		// PrintToServer("client: %d, dropped: %d", client, dropped);
		RemoveEntity(currentWeapon);

		char classname[64];
		g_hDroppedWeapons[droppedWeapon].GetClassname(classname, sizeof(classname));
		int itemIndex = g_hDroppedWeapons[droppedWeapon].ItemIndex;
		TF2_RemoveWeaponSlot(client, g_hDroppedWeapons[droppedWeapon].ItemSlot);

		int newWeapon = SpawnWeapon(client, classname, itemIndex, 101, 1, "");
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", newWeapon);

		if(HasEntProp(newWeapon, Prop_Data, "m_iClip1"))
		{
			SetEntProp(newWeapon, Prop_Data, "m_iClip1", g_hDroppedWeapons[droppedWeapon].Clip);
			SetEntProp(newWeapon, Prop_Data, "m_iPrimaryAmmoType", g_hDroppedWeapons[droppedWeapon].AmmoType);
			SetEntProp(client, Prop_Data, "m_iAmmo", g_hDroppedWeapons[droppedWeapon].Ammo);
		}

		currentWeapon = newWeapon;
		allowSwap = true; // 체크 완료
	}

	g_bSwapCheck = !allowSwap;

	TF2Attrib_RemoveAll(currentWeapon);
	g_hDroppedWeapons[droppedWeapon].ExportAttributes(currentWeapon);
	delete g_hDroppedWeapons[droppedWeapon];

	ResetMannVsMachineMode();
	g_bForceEquip = false;

	if(IsValidEntity(droppedWeapon))
		RemoveEntity(droppedWeapon);

	return MRES_Handled;
}

public void OnMapStart()
{
	PrecacheSound("mvm/mvm_money_pickup.wav");
	// PrecacheModel("models/weapons/c_models/c_directhit/c_directhit.mdl", true);

	for(int loop = MaxClients + 1; loop < MAX_EDICTS; loop++)
	{
		if(g_hDroppedWeapons[loop] != null)
		{
			delete g_hDroppedWeapons[loop];
		}
	}
}

int	TotalSpend, TotalAlive;
float CorrectionRatio = 1.0;

int MaxSpent, MaxSpentIndex;

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	TotalAlive = 0, TotalSpend = 0;
	CorrectionRatio = 1.0;

	MaxSpent = 0, MaxSpentIndex = 0;

	return Plugin_Continue;
}

public Action FF2_OnApplyBossHealthCorrection(int boss, float &multiplier)
{
	// Round State?
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));
	if(TF2_GetClientTeam(client) != FF2_GetBossTeam())
		return Plugin_Continue;

	if(TotalSpend == 0)
	{
		for(int target = 1; target <= MaxClients; target++)
		{
			if(!IsClientInGame(target) || !IsPlayerAlive(target)
				|| TF2_GetClientTeam(target) == FF2_GetBossTeam())
				continue;

			TotalAlive++;

			int curSpent =
				MVM_GetPlayerCurrencySpent(target) + RoundFloat(MVM_GetPlayerCurrency(target) * 0.8); 
			TotalSpend += curSpent;

			if(MaxSpent < curSpent)
			{
				MaxSpentIndex = target;
				MaxSpent = curSpent;
			}
		}

		float avgSpend = float(TotalSpend) / float(TotalAlive);
		CorrectionRatio = (avgSpend / 4000.0) + 1.0;

		CPrintToChatAll("{olive}[FF2]{default} %t", "MVM Boss Health Correction",
			RoundFloat((CorrectionRatio - 1.0) * 100.0), RoundFloat(avgSpend));
		CPrintToChatAll("{olive}[FF2]{default} %t", "MVM Upgrade MVP", MaxSpentIndex, MaxSpent);
	}

	multiplier = CorrectionRatio;

	float value = 1.0, knockback;
	Address address = TF2Attrib_GetByDefIndex(client, 252);
	if(address != Address_Null)
		value = TF2Attrib_GetValue(address);

	knockback = CorrectionRatio - 1.0;
	if(knockback > 1.0)
		knockback = 1.0;

	value -= knockback * 0.5;
	// value min?
	TF2Attrib_SetByDefIndex(client, 252, value);

	return Plugin_Changed;
}

public Action OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	// client = GetClientOfUserId(event.GetInt("userid"))

	if(IsBoss(attacker) && TF2_GetClientTeam(attacker) == FF2_GetBossTeam())
	{
		if(!(event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER))
		{
			MVM_SetPlayerCurrency(attacker, MVM_GetPlayerCurrency(attacker) + 50);
		}
	}

	return Plugin_Continue;
}

public void FF2_OnCalledQueue(FF2HudQueue hudQueue, int client)
{
	float carteenCooltime = MVM_GetPlayerCarteenCooldown(client),
		sapperCharge;

	if(!IsPlayerAlive(client))	return;

	char text[60];
	FF2HudDisplay hudDisplay = null;
	hudQueue.GetName(text, sizeof(text));

 	int sapper = GetPlayerWeaponSlot(client, 1);
	bool hasCarteenCooldown = carteenCooltime > 0.0;

	bool hasSapperCooldown = ((sapper != -1 && IsSapper(sapper))
		&& ((sapperCharge = GetEntPropFloat(sapper, Prop_Send, "m_flEffectBarRegenTime")) > 0.0));

	// PrintToChatAll("hasSapper = %s, sapperCharge = %.3f", (sapper != -1 && IsSapper(sapper)) ? "true" : "false", sapperCharge);

	if(StrEqual(text, "Player Additional"))
	{
		if(hasCarteenCooldown)
		{
			Format(text, sizeof(text), "%t: %.1f", "Carteen Cooldown", carteenCooltime);
			hudDisplay = FF2HudDisplay.CreateDisplay("Carteen Cooldown", text);
			hudQueue.PushDisplay(hudDisplay);
		}

		if(hasSapperCooldown)
		{
			sapperCharge -= GetGameTime();

			Format(text, sizeof(text), "%t: %.1f", "Sapper Charge", sapperCharge);
			hudDisplay = FF2HudDisplay.CreateDisplay("Sapper Charge", text);
			hudQueue.PushDisplay(hudDisplay);
		}
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
	for(int client = 1; client <= MaxClients; client++)
	{
		if(!IsClientInGame(client)) 		continue;

		if(IsBoss(client) && FF2_GetBossTeam() == TF2_GetClientTeam(client))
		{
			/*
			boss = FF2_GetBossIndex(client);

			int beforeHealth = FF2_GetBossMaxHealth(boss), heal = RoundFloat(FF2_GetBossMaxHealth(boss) * 1.04);
			heal -= beforeHealth;

			FF2_SetBossHealth(boss, FF2_GetBossHealth(boss) + heal);
			FF2_SetBossMaxHealth(boss, (FF2_GetBossMaxHealth(boss) + (heal / FF2_GetBossMaxLives(boss))) - 1);
			*/
			Address address = TF2Attrib_GetByDefIndex(client, 252);

			float value = 0.97;
			if(address != Address_Null)
				value = TF2Attrib_GetValue(address) - 0.03;

			TF2Attrib_SetByDefIndex(client, 252, value);
		}
		else if(IsPlayerAlive(client))
		{
			MVM_SetPlayerCurrency(client, MVM_GetPlayerCurrency(client) + 200);
			EmitSoundToClient(client, "mvm/mvm_money_pickup.wav");
		}
	}

	CPrintToChatAll("{olive}[FF2]{default} %t", "Wave Started");
}

public Action MVM_OnTouchedUpgradeStation(int upgradeStation, int client)
{
	if((IsBoss(client) && FF2_GetBossTeam() == TF2_GetClientTeam(client)) 
		|| (FF2_GetFF2Flags(client) & FF2FLAG_CLASSTIMERDISABLED) > 0)
		return Plugin_Handled;

	return Plugin_Continue;
}

public Action MVM_OnTouchedMoney(int money, int client)
{
	if(FF2_GetBossTeam() == TF2_GetClientTeam(client))
		return Plugin_Handled;

	return Plugin_Changed;
}

Handle PrepSDKCall_InitDroppedWeapon(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFDroppedWeapon::InitDroppedWeapon");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);

	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDK call: CTFDroppedWeapon::InitDroppedWeapon");

	return call;
}

void SDKCall_InitDroppedWeapon(int pDroppedWeapon, int pPlayer, int pWeapon, bool bSwap = false, bool bIsSuicide = false)
{
	if (g_SDKCallInitDroppedWeapon)
		SDKCall(g_SDKCallInitDroppedWeapon, pDroppedWeapon, pPlayer, pWeapon, bSwap, bIsSuicide);
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

/*
	only set flags when forced is true.
*/
stock int DropWeapon(int owner, int weapon, int flags = 0, bool forced = false)
{
	int droppedWeapon = CreateEntityByName("tf_dropped_weapon");

	int index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	int modelIndex = GetEntProp(weapon, Prop_Send, "m_iWorldModelIndex");

	SetEntProp(droppedWeapon, Prop_Send, "m_iItemDefinitionIndex", index);
	SetEntProp(droppedWeapon, Prop_Send, "m_bInitialized", 1);

	// PrintToServer("modelIndex: %d", modelIndex);

	char modelPath[PLATFORM_MAX_PATH];
	int stringTable = FindStringTable("modelprecache"); // Should probably be a global
	ReadStringTable(stringTable, modelIndex, modelPath, PLATFORM_MAX_PATH);
	SetEntityModel(droppedWeapon, modelPath);

	DispatchSpawn(droppedWeapon);

	float pos[3];
	GetClientEyePosition(owner, pos);
	pos[2] -= 15.0;
	TeleportEntity(droppedWeapon, pos, NULL_VECTOR, NULL_VECTOR);

	if(forced)
	{
		g_hDroppedWeapons[droppedWeapon] = CTFDroppedWeapon.Create(owner, weapon, flags);
		g_hDroppedWeapons[droppedWeapon].ImportAttributes(weapon);

		if(g_hDroppedWeapons[droppedWeapon].ChargeMeter > 0.0)
			SetEntPropFloat(droppedWeapon, Prop_Send, "m_flChargeLevel", g_hDroppedWeapons[droppedWeapon].ChargeMeter);
		TF2Attrib_RemoveAll(droppedWeapon);
	}

	return droppedWeapon;
}

stock void EqiupWeaponFromDropped(int client, int droppedWeapon)
{
	SDKCall_PickupWeaponFromOther(client, droppedWeapon);
	g_bForceEquip = true;
}

stock int GetSlotOfWeapon(int client, int weapon)
{
	for(int loop = 0; loop < 6; loop++)
	{
		int temp = GetPlayerWeaponSlot(client, loop);
		if(weapon == temp)
			return loop;
	}
	return -1;
}

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
