Handle OnCalledQueue;
Handle OnDisplayHud, OnDisplayHudPost;

stock KeyValues LoadHudConfig()
{
	char config[PLATFORM_MAX_PATH];// , key[80];
	BuildPath(Path_SM, config, sizeof(config), "%s/%s", FF2_SETTINGS, HUDS_CONFIG);
	if(!FileExists(config))
	{
		LogError("[FF2] HUDS_CONFIG %s does not exist!", config);
		return null;
	}

	KeyValues kv=new KeyValues("hud_setting");
	// Handle cookie;
	kv.ImportFromFile(config);
	kv.Rewind();
/*
	if(kv.GotoFirstSubKey(true))
	{
		do
		{
			if(kv.GotoFirstSubKey(true))
			{
				do
				{
					kv.GetSectionName(key, sizeof(key));

					cookie = FF2HudCookie.FindHudCookie(key);
					delete cookie;
				}
				while(kv.GotoNextKey(true));
			}
			kv.GoBack();
		}
		while(kv.GotoNextKey(true));
	}

	kv.Rewind();
*/
	return kv;
}

stock int GetHudSetting(int client, char[] hudId)
{
	return (DBSPlayerData.GetClientData(client)).GetData(FF2DATABASE_CONFIG_NAME, FF2_DB_PLAYER_HUDDATA_TABLENAME, hudId, "setting_value");
}

stock void SetHudSetting(int client, char[] hudId, int value)
{
	char timeStr[32];
	FormatTime(timeStr, sizeof(timeStr), "%Y-%m-%d %H:%M:%S", GetTime());

	(DBSPlayerData.GetClientData(client)).SetData(FF2DATABASE_CONFIG_NAME, FF2_DB_PLAYER_HUDDATA_TABLENAME, hudId, "setting_value", value);
	(DBSPlayerData.GetClientData(client)).SetStringData(FF2DATABASE_CONFIG_NAME, FF2_DB_PLAYER_HUDDATA_TABLENAME, hudId, "last_saved_time", timeStr);
}

// Native things

void HudInit()
{
	// CreateNative("FF2HudConfig.GetConfigKeyValue", Native_FF2HudConfig_GetConfigKeyValue);
	CreateNative("FF2HudConfig.GetDefaultSettiing", Native_FF2HudConfig_GetDefaultSettiing);

	CreateNative("FF2HudDisplay.CreateDisplay", Native_FF2HudDisplay_CreateDisplay);
	CreateNative("FF2HudDisplay.ShowSyncHudDisplayText", Native_FF2HudDisplay_ShowSyncHudDisplayText);

	CreateNative("FF2HudQueue.CreateHudQueue", Native_FF2HudQueue_CreateHudQueue);
	CreateNative("FF2HudQueue.PushDisplay", Native_FF2HudQueue_PushDisplay);
	CreateNative("FF2HudQueue.GetName", Native_FF2HudQueue_GetName);
	CreateNative("FF2HudQueue.SetName", Native_FF2HudQueue_SetName);
	CreateNative("FF2HudQueue.DeleteDisplay", Native_FF2HudQueue_DeleteDisplay);
	CreateNative("FF2HudQueue.DeleteAllDisplay", Native_FF2HudQueue_DeleteAllDisplay);
	CreateNative("FF2HudQueue.AddHud", Native_FF2HudQueue_AddHud);
	CreateNative("FF2HudQueue.FindHud", Native_FF2HudQueue_FindHud);
	CreateNative("FF2HudQueue.ShowSyncHudQueueText", Native_FF2HudQueue_ShowSyncHudQueueText);

	OnCalledQueue = CreateGlobalForward("FF2_OnCalledQueue", ET_Hook, Param_Cell, Param_Cell);
	OnDisplayHud = CreateGlobalForward("FF2_OnDisplayHud", ET_Hook, Param_Cell, Param_String, Param_String);
	OnDisplayHudPost = CreateGlobalForward("FF2_OnDisplayHud_Post", ET_Hook, Param_Cell, Param_String, Param_String);
}

public int Native_FF2HudQueue_CreateHudQueue(Handle plugin, int numParams)
{
	char name[64];
	GetNativeString(1, name, sizeof(name));

	FF2HudQueue queueKv = view_as<FF2HudQueue>(new KeyValues("hud_queue", "queue name", name));
	return view_as<int>(queueKv);
}

public int Native_FF2HudQueue_PushDisplay(Handle plugin, int numParams)
{
	char hudId[128];
	int posId;
	FF2HudQueue queue = GetNativeCell(1);
	FF2HudDisplay display = GetNativeCell(2);

	queue.Rewind();
	display.Rewind();

	display.GetSectionName(hudId, sizeof(hudId));
	queue.JumpToKey(hudId, true);

	queue.Import(display);
	delete display;
	return queue.GetSectionSymbol(posId) ? posId : -1;
}

public int Native_FF2HudQueue_GetName(Handle plugin, int numParams)
{
	FF2HudQueue queue = GetNativeCell(1);
	char name[64];

	queue.Rewind();
	queue.GetString("queue name", name, sizeof(name));

	SetNativeString(2, name, GetNativeCell(3));
}

public int Native_FF2HudQueue_SetName(Handle plugin, int numParams)
{
	FF2HudQueue queue = GetNativeCell(1);
	char name[64];
	GetNativeString(2, name, sizeof(name));

	queue.Rewind();
	queue.SetString("queue name", name);
}

public int Native_FF2HudQueue_DeleteDisplay(Handle plugin, int numParams)
{
	FF2HudQueue queue = GetNativeCell(1);
	int posId = GetNativeCell(2);

	if(queue.JumpToKeySymbol(posId))
		queue.DeleteThis();
}

public int Native_FF2HudQueue_DeleteAllDisplay(Handle plugin, int numParams)
{
	ArrayList array = new ArrayList();
	FF2HudQueue queue = GetNativeCell(1);
	int posId;

	queue.Rewind();
	if(queue.GotoFirstSubKey())
	{
		do
		{
			queue.GetSectionSymbol(posId);
			array.Push(posId);
		}
		while(queue.GotoNextKey());
	}

	for(int loop = 0; loop < array.Length; loop++)
	{
		queue.Rewind();
		posId = array.Get(loop);
		queue.JumpToKeySymbol(posId);

		// CPrintToChatAll("%d", posId);
		queue.DeleteThis();
	}

	delete array;
}

public int Native_FF2HudQueue_AddHud(Handle plugin, int numParams)
{
	char info[80], name[64];
	FF2HudQueue queue = GetNativeCell(1);
	FF2HudDisplay hudDisplay = GetNativeCell(2);

	hudDisplay.Rewind();

	int client = GetNativeCell(3), other = GetNativeCell(4);
	queue.GetName(name, sizeof(name));
	hudDisplay.GetSectionName(info, sizeof(info));

	int value = GetHudSetting(client, info);
	bool visible = true;

	if(value == HudSetting_None)
	{
		value = FF2HudConfig.GetDefaultSettiing(name, info);
	}

	if(value > HudSetting_None) {
		if(other > 0) { // 나도 안보고 타인에게도 안보여줌
			if(GetHudSetting(other, info) == HudSetting_ViewDisable) {
				visible = false;
			}
		}
		else {
			if(value == HudSetting_ViewAble || value == HudSetting_ViewDisable) // 난 안보지만 타인은 볼 수 있음.
				visible = false;
		}
	}

	if(!visible) {
		delete hudDisplay;
		return -1;
	}

	return queue.PushDisplay(hudDisplay);
}
public int Native_FF2HudQueue_FindHud(Handle plugin, int numParams)
{
	FF2HudQueue queue = GetNativeCell(1);
	char hudId[80];
	int posId;
	GetNativeString(2, hudId, sizeof(hudId));

	queue.Rewind();
	return queue.GetNameSymbol(hudId, posId) ? posId : -1;
}

public int Native_FF2HudConfig_GetConfigKeyValue(Handle plugin, int numParams)
{
    return view_as<int>(kvHudConfigs);
}

public int Native_FF2HudConfig_GetDefaultSettiing(Handle plugin, int numParams)
{
	char name[80];
	kvHudConfigs.Rewind();
	GetNativeString(1, name, sizeof(name));
	kvHudConfigs.JumpToKey(name);
	GetNativeString(2, name, sizeof(name));
	kvHudConfigs.JumpToKey(name);

	return kvHudConfigs.GetNum("default_setting", -1);
}

public int Native_FF2HudDisplay_CreateDisplay(Handle plugin, int numParams)
{
	char info[64], display[64];
	GetNativeString(1, info, sizeof(info));
	GetNativeString(2, display, sizeof(display));

	FF2HudDisplay displayKv = view_as<FF2HudDisplay>(new KeyValues(info, "display", display));
	return view_as<int>(displayKv);
}

public int Native_FF2HudDisplay_ShowSyncHudDisplayText(Handle plugin, int numParams)
{
	FF2HudDisplay displayKv = GetNativeCell(1);
	int client = GetNativeCell(2);
	Handle sync = GetNativeCell(3);
	char info[64], display[64];

	displayKv.Rewind();
	displayKv.GetSectionName(info, sizeof(info));
	displayKv.GetString("display", display, sizeof(display));

	Action action = Forward_OnDisplayHud(client, info, display);
	if(action != Plugin_Handled && action != Plugin_Stop)
	{
	    if(sync != null)
	        FF2_ShowSyncHudText(client, sync, display);
	    else
	        FF2_ShowHudText(client, -1, display);
	}
}

public int Native_FF2HudQueue_ShowSyncHudQueueText(Handle plugin, int numParams)
{
	FF2HudQueue queue = GetNativeCell(1);
	int displayCount = 0, client = GetNativeCell(2), len = 0;
	Handle sync = GetNativeCell(3);
	char text[300], info[80], display[128];

	Forward_OnCalledQueue(queue, client);
	queue.Rewind();
	if(queue.GotoFirstSubKey())
	{
		do
		{
			displayCount++;

			queue.GetSectionName(info, sizeof(info));
			queue.GetString("display", display, sizeof(display));

			// TODO: 밑의 함수 고치기
			Forward_OnDisplayHud(client, info, display);

			if(displayCount > 1)
			{
				if(len > 60)
				{
					Format(display, sizeof(display), "\n%s", display);
					len = 0;
				}
				else
				{
					Format(text, sizeof(text), "%s | ", text);
					len += strlen(display);
				}
			}

			Format(text, sizeof(text), "%s%s", text, display);
		}
		while(queue.GotoNextKey());
	}

	if(sync != null)
		FF2_ShowSyncHudText(client, sync, text);
	else
		FF2_ShowHudText(client, -1, text);
}

public void Forward_OnCalledQueue(FF2HudQueue hudQueue, int client)
{
	Call_StartForward(OnCalledQueue);
	Call_PushCell(hudQueue);
	Call_PushCell(client);
	Call_Finish();
}

public Action Forward_OnDisplayHud(int client, const char[] info, char[] display)
{
    Action action = Plugin_Continue;
    char[] tempDisplay = new char[strlen(display)+1];
    Format(tempDisplay, strlen(tempDisplay), "%s", display);

    Call_StartForward(OnDisplayHud);
    Call_PushCell(client);
    Call_PushString(info);
    Call_PushStringEx(tempDisplay, strlen(tempDisplay), SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
    Call_Finish(action);

    if(action == Plugin_Changed)
    {
        strcopy(display, strlen(display), tempDisplay);
    }

    Forward_OnDisplayHudPost(client, info, display);
    return Plugin_Continue;
}

public void Forward_OnDisplayHudPost(int client, const char[] info, const char[] display)
{
    Call_StartForward(OnDisplayHudPost);
    Call_PushCell(client);
    Call_PushString(info);
    Call_PushString(display);
    Call_Finish();
}
