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
	LoadedHudData[client].GoToHudData(hudId);
	return LoadedHudData[client].GetNum("setting_value", -1);
}

stock void SetHudSetting(int client, char[] hudId, int value)
{
	LoadedHudData[client].GoToHudData(hudId, true);
	LoadedHudData[client].SetNum("setting_value", value);
}

// Native things

void HudInit()
{
	// CreateNative("FF2HudConfig.GetConfigKeyValue", Native_FF2HudConfig_GetConfigKeyValue);
	CreateNative("FF2HudConfig.GetDefaultSettiing", Native_FF2HudConfig_GetDefaultSettiing);

	CreateNative("FF2HudDisplay.CreateDisplay", Native_FF2HudDisplay_CreateDisplay);
	CreateNative("FF2HudDisplay.ShowSyncHudDisplayText", Native_FF2HudDisplay_ShowSyncHudDisplayText);

	CreateNative("FF2HudQueue.KillSelf", Native_FF2HudQueue_KillSelf);
	CreateNative("FF2HudQueue.AddHud", Native_FF2HudQueue_AddHud);
	CreateNative("FF2HudQueue.FindHud", Native_FF2HudQueue_FindHud);
	CreateNative("FF2HudQueue.ShowSyncHudQueueText", Native_FF2HudQueue_ShowSyncHudQueueText);

	OnCalledQueue = CreateGlobalForward("FF2_OnCalledQueue", ET_Hook, Param_Cell);
	OnDisplayHud = CreateGlobalForward("FF2_OnDisplayHud", ET_Hook, Param_Cell, Param_String, Param_String);
	OnDisplayHudPost = CreateGlobalForward("FF2_OnDisplayHud_Post", ET_Hook, Param_Cell, Param_String, Param_String);
}

public int Native_FF2HudQueue_KillSelf(Handle plugin, int numParams)
{
	FF2HudQueue queue = GetNativeCell(1);
	FF2HudDisplay willDeleted;

	for(int loop = HudQueueValue_Last; loop < queue.Length; loop++)
	{
		willDeleted = queue.GetHud(loop);
		if(willDeleted != null)	{
			// Debug("deleted %x", willDeleted);
			delete willDeleted;
		}
	}

	delete queue;
}

public int Native_FF2HudQueue_AddHud(Handle plugin, int numParams)
{
	FF2HudQueue queue = GetNativeCell(1);
	FF2HudDisplay hudDisplay = GetNativeCell(2);
	int other = GetNativeCell(3);

	char info[80], name[64];
	queue.GetName(name, sizeof(name));
	hudDisplay.GetInfo(info, sizeof(info));
	int value = GetHudSetting(queue.ClientIndex, info);
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

	int index = queue.FindValue(view_as<FF2HudDisplay>(null));
	if(index != -1) {
		queue.SetHud(index, hudDisplay);
		// Debug("Added %x", hudDisplay);
	}

	return index;
}
public int Native_FF2HudQueue_FindHud(Handle plugin, int numParams)
{
	FF2HudQueue queue = GetNativeCell(1);
	char hudId[80];
	GetNativeString(2, hudId, sizeof(hudId));

	char info[80];
	FF2HudDisplay hudDisplay;

	for(int loop = HudQueueValue_Last; queue.Length > loop; loop++)
	{
		if((hudDisplay = queue.GetHud(loop)) != null)
		{
			hudDisplay.GetInfo(info, sizeof(info));
			if(StrEqual(info, hudId))
				return loop;
		}
	}

	return -1;
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

	FF2HudDisplay array = view_as<FF2HudDisplay>(new ArrayList(64, view_as<int>(HudValue_Last)));
	array.SetString(Hud_Info, info);
	array.SetString(Hud_Display, display);

	return view_as<int>(array);
}

public int Native_FF2HudDisplay_ShowSyncHudDisplayText(Handle plugin, int numParams)
{
    FF2HudDisplay displayArray = GetNativeCell(1);
    int client = GetNativeCell(2);
    Handle sync = GetNativeCell(3);
    char info[64], display[64];

    displayArray.GetInfo(info, 64);
    displayArray.GetDisplay(display, 64);
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
    Handle sync = GetNativeCell(2);
    FF2HudDisplay displayArray;

    char text[300], info[64], display[64];
    int displayCount = 0;
    Forward_OnCalledQueue(queue);

    for(int loop = HudQueueValue_Last; loop < queue.Length; loop++)
    {
        displayArray = queue.GetHud(loop);
        if(displayArray == null)
            continue;

        displayCount++;
        displayArray.GetInfo(info, 64);
        displayArray.GetDisplay(display, 64);
        Action action = Forward_OnDisplayHud(queue.ClientIndex, info, display);

        if(action != Plugin_Handled && action != Plugin_Stop)
        {
            if(displayCount > 1)
                Format(text, sizeof(text), "%s | ", text);
            Format(text, sizeof(text), "%s%s", text, display);
        }
    }

    if(sync != null)
        FF2_ShowSyncHudText(queue.ClientIndex, sync, text);
    else
        FF2_ShowHudText(queue.ClientIndex, -1, text);
}

public void Forward_OnCalledQueue(FF2HudQueue hudQueue)
{
    Call_StartForward(OnCalledQueue);
    Call_PushCell(hudQueue);
    Call_Finish();
}

public Action Forward_OnDisplayHud(int client, const char[] info, char[] display)
{
    Action action;
    char[] tempDisplay = new char[strlen(display)+1];
    Format(tempDisplay, strlen(tempDisplay)*2, "%s", display);

    Call_StartForward(OnDisplayHud);
    Call_PushCell(client);
    Call_PushString(info);
    Call_PushStringEx(tempDisplay, strlen(tempDisplay)*2, SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
    Call_Finish(action);

    if(action == Plugin_Changed)
    {
        strcopy(display, strlen(display)*2, tempDisplay);
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
