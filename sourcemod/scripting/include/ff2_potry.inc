#if defined _FF2_POTRY_included
 #endinput
#endif
#define _FF2_POTRY_included

/**
 * Gets assist by this client
 *
 * @param client    Client's index
 * @return          Damage dealt
 */
native int FF2_GetClientAssist(int client);

/**
 * Sets assist by this client
 *
 * @param client 	Client's index
 * @param damage	New damage dealt
 * @noreturn
 */
native void FF2_SetClientAssist(int client, int assist);

/*
* @param client 	     attacker's index
* @param characterIndex	 boss index
*/
native void FF2_MakePlayerToBoss(int client, int characterIndex);

/**
 * @param attacker 	attacker's index
 * @param victimBoss	victim boss index
 * @param name    Special Attack name
 * @param damage    Special Attack damage
 * @noreturn
 */
native void FF2_SpecialAttackToBoss(int attacker, int victimBoss, const char[] name, float damage);

/**
 * Gets a Character's KV handle
 *
 * @param characterIndex    character's index (config)
 * @return                  Character's KV handle or null if character index is invalid
 */
native KeyValues FF2_GetCharacterKV(int characterIndex);

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
forward Action FF2_OnSpecialAttack(int attacker, int victimBoss, const char[] name, float &damage);
forward void FF2_OnSpecialAttack_Post(int attacker, int victimBoss, const char[] name, float damage);

/*
*   Before FF2_OnBossSelected.
*   with CreateChancesArray();
*
*/
forward Action FF2_OnCheckRules(int client, int &characterIndex, int &chance, const char[] ruleName, int value);

// boss_selection.sp
forward Action FF2_OnCheckSelectRules(int client, int characterIndex, const char[] ruleName, int value);

/****
    THE HUD UPDATE
****/

enum HudSettingValue
{
    HudSetting_None = -1, // Cookie is ""
    HudSetting_View = 0,
    HudSetting_ViewAble,
    HudSetting_ViewDisable,

    HudSettingValue_Last
};

enum HudQueueValue
{
    HudQueue_ClientIndex = 0,
    HudQueue_Name,

    HudQueueValue_Last
};

enum HudValue
{
    Hud_Info = 0,
    Hud_Display,

    HudValue_Last
};

methodmap FF2HudConfig {
    // public static native FF2HudConfig GetConfigKeyValue();
    public static native HudSettingValue GetDefaultSettiing(const char[] name, const char[] info);
}

methodmap FF2HudDisplay < ArrayList
{
    public FF2HudDisplay(char[] info, char[] display)
    {
        FF2HudDisplay array = view_as<FF2HudDisplay>(new ArrayList(64, view_as<int>(HudValue_Last)));
        array.SetString(view_as<int>(Hud_Info), info);
        array.SetString(view_as<int>(Hud_Display), display);

        return array;
    }
/*
    public FF2HudDisplay KillSelf()
    {
        delete this;
        return null;
    }
*/
    public any GetValue(HudValue valueType)
    {
        return this.Get(view_as<int>(valueType));
    }

    public void SetValue(HudValue valueType, any value)
    {
        this.Set(view_as<int>(valueType), value);
    }

    public void GetInfo(char[] infoStr, int length)
    {
        this.GetString(view_as<int>(Hud_Info), infoStr, length);
    }

    public void SetInfo(const char[] infoStr)
    {
        this.SetString(view_as<int>(Hud_Info), infoStr);
    }

    public void GetDisplay(char[] displayStr, int length)
    {
        this.GetString(view_as<int>(Hud_Display), displayStr, length);
    }

    public void SetDisplay(const char[] displayStr)
    {
        this.SetString(view_as<int>(Hud_Display), displayStr);
    }
/*
    property Handle ParentHud {
        public Get()
        {
            return this.GetValue(Hud_ParentHud);
        }

        public Set(Handle sync)
        {
            this.SetValue(Hud_ParentHud, sync);
        }
    }
*/
    public native void ShowSyncHudDisplayText(int client, Handle sync = null);
}

methodmap FF2HudQueue < ArrayList
{
    public FF2HudQueue(int client, const char[] name, int initialSize = 8)
    {
        FF2HudQueue array = view_as<FF2HudQueue>(new ArrayList(64, initialSize + view_as<int>(HudQueueValue_Last)));
        array.Set(view_as<int>(HudQueue_ClientIndex), client);
        array.SetString(view_as<int>(HudQueue_Name), name);

        for(int loop = view_as<int>(HudQueueValue_Last); loop < initialSize + view_as<int>(HudQueueValue_Last); loop++)
            array.Set(loop, view_as<FF2HudDisplay>(null));

        return array;
    }

    property int ClientIndex {
        public get()
        {
            return this.Get(view_as<int>(HudQueue_ClientIndex));
        }

        public set(int client)
        {
            this.Set(view_as<int>(HudQueue_ClientIndex), client);
        }
    }

    public void GetName(char[] name, int length)
    {
        this.GetString(view_as<int>(HudQueue_Name), name, length);
    }

    public void SetName(const char[] name)
    {
        this.SetString(view_as<int>(HudQueue_Name), name);
    }

    public FF2HudDisplay GetHud(int index)
    {
        return this.Get(index);
    }

    public void SetHud(int index, FF2HudDisplay hudDisplay)
    {
        this.Set(index, hudDisplay);
    }
/*
    public void ResizeQueue(int size)
    {
        int beforeSize = this.Length;
        if(beforeSize > size)
        {
            int between = beforeSize - size;
            FF2HudDisplay willDeleted;
            for(int loop = 0; between > loop; loop++) {
                willDeleted = this.GetHud(size + loop);
                if(willDeleted != null)
                    willDeleted.KillSelf();
            }
        }
        this.Resize(size + view_as<int>(HudQueueValue_Last));

        if(size > beforeSize)
        {
            for(int loop = beforeSize; this.Length > loop; loop++)
            {
                this.SetHud(loop, view_as<FF2HudDisplay>(null));
            }
        }
    }
*/
    public native void KillSelf();
/*
    // NOTE: 서브 플러그인에서 직접 사용하지 마세요. DO NOT Use this function on any subplugin.
    // TODO: 은닉
    public native int PushHud(FF2HudDisplay hudDisplay);
*/
    // NOTE: other = 타인 정보를 볼 경우, 그 클라이언트의 index
    public native int AddHud(FF2HudDisplay hudDisplay, int other = 0);

    public native int FindHud(const char[] hudId);

    public native void ShowSyncHudQueueText(Handle sync = null);
}

forward void FF2_OnCalledQueue(FF2HudQueue hudQueue);
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

public SharedPlugin __pl_FF2_POTRY=
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
public __pl_FF2_POTRY_SetNTVOptional()
{
    MarkNativeAsOptional("FF2_GetClientAssist");
    MarkNativeAsOptional("FF2_SetClientAssist");
    MarkNativeAsOptional("FF2_SpecialAttackToBoss");
    MarkNativeAsOptional("FF2_GetCharacterKV");
}
#endif
