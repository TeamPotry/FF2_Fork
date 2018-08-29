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

/**
 * Gets a Character's KV handle
 *
 * @param characterIndex    character's index (config)
 * @return                  Character's KV handle or null if character index is invalid
 */
native KeyValues FF2_GetCharacterKV(int characterIndex);

/****
    THE HUD UPDATE
****/

enum HudQueueValue
{
    HudQueue_ClientIndex = 0,

    HudQueueValue_Last
};

enum HudValue
{
    Hud_Info = 0,
    Hud_Display,

    HudValue_Last
};

methodmap FF2HudDisplay < ArrayList
{
    public FF2HudDisplay(char[] info, char[] display)
    {
        FF2HudDisplay array = view_as<FF2HudDisplay>(new ArrayList(64, view_as<int>(HudValue_Last)));
        array.SetString(view_as<int>(Hud_Info), info);
        array.SetString(view_as<int>(Hud_Display), display);

        return array;
    }

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
    public FF2HudQueue(int client, int initialSize = 2)
    {
        FF2HudQueue array = view_as<FF2HudQueue>(new ArrayList());
        this.Set(view_as<int>(HudQueue_ClientIndex), client);
        this.Resize(initialSize + 1);

        for(int loop = view_as<int>(HudQueueValue_Last); loop < initialSize + 1; loop++)
            this.Set(loop, INVALID_HANDLE);

        return array;
    }

    public FF2HudDisplay GetHud(int index)
    {
        return this.Get(index);
    }

    public void SetHud(int index, FF2HudDisplay hudDisplay)
    {
        this.Set(index, hudDisplay);
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
                    delete willDeleted;// willDeleted.KillSelf();
            }
        }
        this.Resize(size + 1);
    }

    public FF2HudQueue KillSelf()
    {
        FF2HudDisplay willDeleted;
        for(int loop = 0; this.Length > loop; loop++)
        {
            willDeleted = this.GetHud(loop);
            if(willDeleted != null)
                delete willDeleted;// willDeleted.KillSelf();
        }

        delete this;
        return null;
    }

    public native void ShowSyncHudQueueText(Handle sync = null);
}

forward Action FF2_OnDisplayHud(const int client, const char[] info, char[] display);
forward void FF2_OnDisplayHud_Post(const int client, const char[] info, const char[] display);

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
    MarkNativeAsOptional("FF2_GetCharacterKV");
}
#endif
