#if defined _ff2_potry_included
 #endinput
#endif
#define _ff2_potry_included

#define FF2BOSSCREATOR_MODEL                (1<<1)
#define FF2BOSSCREATOR_PLUGIN               (1<<2)
#define FF2BOSSCREATOR_SOUND                (1<<3)

enum
{
    FF2BossCreator_Other = 0,
    FF2BossCreator_Model,
    FF2BossCreator_Plugin,
    FF2BossCreator_Sound
};

enum
{
    FF2Timer_Disable = 0,
    FF2Timer_RoundTimer,
    FF2Timer_WaveTimer
};

/**
 * Add Boss's charge.
 *
 * @param boss      Boss's index
 * @param slow      Charge slot
 * @param charge    charge amount
 *                      (negative is also allowed. But it only effects when boss's charge < 90.0)
 * @noreturn
 */
native void FF2_AddBossCharge(int boss, int slot, float charge);
/**
 * Get timer's type.
 *
 * @return          Remaining round time
 */
native int FF2_GetTimerType();

/**
 * Get remaining round time.
 *
 * @return          Remaining round time
 */
native int FF2_GetRoundTime();

/**
 * Set remaining round time.
 *
 * @param time      New round time (set -1.0 to disable timer)
 * @noreturn
 */
native void FF2_SetRoundTime(float time);

/**
 * Sets assist by this client
 *
 * @param client 	Client's index
 * @param damage	New damage dealt
 * @noreturn
 */
native void FF2_SetClientAssist(int client, int assist);

/**
 * Regenerate Boss weapons.
 *
 * @param boss 	boss's index
 * @noreturn
 */
native void FF2_EquipBoss(int boss);

/*
* @param client 	     attacker's index
* @param characterIndex	 boss index
*/
native void FF2_MakePlayerToBoss(int client, int characterIndex);

/**
 * @param attacker 	    attacker's index
 * @param victimBoss    victim's boss index
 * @param weapon        attacker's weapon
 * @param name          Special Attack name
 * @param damage        Special Attack damage
 * @noreturn
 */
native void FF2_SpecialAttackToBoss(int attacker, int victimBoss, int weapon = -1, const char[] name, float damage);

/**
 * Gets a Character's KV handle
 *
 * @param characterIndex    character's index (config)
 * @return                  Character's KV handle or null if character index is invalid
 */
native KeyValues FF2_GetCharacterKV(int characterIndex);

/**
 * Get client's boss creator flags.
 *
 * @param steamId               client's STEAMID (64 Bits)
 * @param boss                  boss index
 * @param pushCharacterIndex    if true, @boss is character index.
 * @return                      client's boss creator flags.
 */
native int FF2_GetBossCreatorFlags(char[] steamId, int boss, bool pushCharacterIndex=false);

/**
 * Gets a Character's KV handle
 *
 * @param boss              boss index
 * @param creatorType       Type of FF2BossCreator
 * @param pushCharacterIndex    if true, @boss is character index.
 * @return                  return ArrayList that has STEAMID of boss creators.
 */
native ArrayList FF2_GetBossCreators(int boss, int creatorType, bool pushCharacterIndex=false);

/**
 * Called when boss uses minion spawn ability.
 *
 * @param client    victim client index
 * @param ownerBossIndex    owner boss index
 * @return
 *  - Plugin_Continue: Nothing..
 *  - Plugin_Changed: Change result.
 *  - Plugin_Stop, Plugin_Handled: Block this event.
 */
forward Action FF2_OnMinionSpawn(int client, int &ownerBossIndex);

/**
 * Called when each wave starts.
 *
 * @param wave    wave that started
 * @noreturn
 */
forward void FF2_OnWaveStarted(int wave);

/**
 * Called when Player became boss.
 *
 * @param boss    boss index
 * @noreturn
 */
forward void FF2_OnPlayBoss(int boss);

/**
 * Called when Boss damaged that was Special Attack.
 *
 * @param attacker    attacker client index
 * @param victimBoss    victim boss index
 * @param name    Special Attack name
 * @param damage    Special Attack damage
 * @return
 *  - Plugin_Continue: Nothing..
 *  - Plugin_Changed: Change result.
 *  - Plugin_Stop, Plugin_Handled: Change result.
 */
forward Action FF2_OnSpecialAttack(int attacker, int victimBoss, int weapon, const char[] name, float &damage);
forward void FF2_OnSpecialAttack_Post(int attacker, int victimBoss, const char[] name, float damage);

/*
*   Before FF2_OnBossSelected.
*   with CreateChancesArray();
*
*/
forward Action FF2_OnCheckRules(int client, int characterIndex, int &chance, const char[] ruleName, const char[] value);

/****
    THE HUD UPDATE
****/

enum
{
    HudSetting_None = -1, // Cookie is ""
    HudSetting_View = 0,
    HudSetting_ViewAble,
    HudSetting_ViewDisable,

    HudSettingValue_Last
};

enum
{
    HudQueue_ClientIndex = 0,
    HudQueue_Name,

    HudQueueValue_Last
};

enum
{
    Hud_Info = 0,
    Hud_Display,

    HudValue_Last
};

methodmap FF2HudConfig {
    public static native int GetDefaultSettiing(const char[] name, const char[] info);
}

methodmap FF2HudDisplay < KeyValues
{
    public static native FF2HudDisplay CreateDisplay(char[] info, char[] display);

    public native void ShowSyncHudDisplayText(int client, Handle sync = null);
}

methodmap FF2HudQueue < KeyValues
{
    // TODO: Add Replace
    public static native FF2HudQueue CreateHudQueue(const char[] name);

    public native int PushDisplay(FF2HudDisplay display);

    public native void GetName(char[] name, int length);

    public native void SetName(const char[] name);

    public native void DeleteDisplay(int posId);

    public native void DeleteAllDisplay();

    // NOTE: other = 타인 정보를 볼 경우, 그 클라이언트의 index
    public native int AddHud(FF2HudDisplay hudDisplay, int client, int other = 0);

    public native int FindHud(const char[] hudId);

    public native void ShowSyncHudQueueText(int client, Handle sync = null);
}

forward void FF2_OnCalledQueue(FF2HudQueue hudQueue, int client);
forward Action FF2_OnDisplayHud(const int client, const char[] info, char[] display);
forward void FF2_OnDisplayHud_Post(const int client, const char[] info, const char[] display);

stock void ResetBossCharge(int boss, int slot)
{
    ArrayList pack = new ArrayList();
    CreateTimer(0.001, ResetTimer, pack);

    pack.Push(boss);
    pack.Push(slot);
}

public Action ResetTimer(Handle timer, ArrayList pack)
{
    int boss = pack.Get(0);
    int slot = pack.Get(1);
    FF2_SetBossCharge(boss, slot, 0.0);
    delete pack;
}

public SharedPlugin __pl_ff2_potry=
{
	name="ff2_potry",
	file="freak_fortress_2.smx",
	#if defined REQUIRE_PLUGIN
		required=1,
	#else
		required=0,
	#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_ff2_potry_SetNTVOptional()
{
    MarkNativeAsOptional("FF2_AddBossCharge");
    MarkNativeAsOptional("FF2_GetTimerType");
    MarkNativeAsOptional("FF2_GetRoundTime");
    MarkNativeAsOptional("FF2_SetRoundTime");
    MarkNativeAsOptional("FF2_GetClientAssist");
    MarkNativeAsOptional("FF2_SetClientAssist");
    MarkNativeAsOptional("FF2_EquipBoss");
    MarkNativeAsOptional("FF2_SpecialAttackToBoss");
    MarkNativeAsOptional("FF2_GetCharacterKV");
    MarkNativeAsOptional("FF2_MakePlayerToBoss");
    MarkNativeAsOptional("FF2_GetBossCreatorFlags");
    MarkNativeAsOptional("FF2_GetBossCreators");
}
#endif
