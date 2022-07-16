#include <sourcemod>
#include <morecolors>
#include <freak_fortress_2>
#include <ff2_modules>
#include <ff2_boss_selection>

public Plugin myinfo=
{
	name="Freak Fortress 2: Developer Mode",
	author="Nopied",
	description="FF2: Abilities test.",
	version="2(1.0)",
};

bool g_bDEVmode = false;

public void OnPluginStart()
{
	RegAdminCmd("ff2_devmode", Cmd_DevMode, ADMFLAG_CHEATS, "WOW! INFINITE RAGE!");
	RegAdminCmd("ff2_disable_timer", Cmd_DisableTimer, ADMFLAG_CHEATS, "WOW! NO TIMER!");
	RegAdminCmd("ff2_change_boss", Cmd_ChangeBoss, ADMFLAG_CHEATS, "WOW! CHANGE USER's BOSS!");
	RegAdminCmd("ff2_ability", Cmd_UseAbility, ADMFLAG_CHEATS, "WOW! TRIGGER BOSS's ABILITIES!");
	RegAdminCmd("ff2_export", Cmd_ExportBoss, ADMFLAG_CHEATS, "WOW! EXPORT BOSS's CONFIG!");

	HookEvent("teamplay_round_start", OnRoundStart);

	LoadTranslations("freak_fortress_2.phrases");
	LoadTranslations("common.phrases");
}

public Action Cmd_DevMode(int client, int args)
{
    CPrintToChatAll("{olive}[FF2]{default} DEVMode: %s", !g_bDEVmode ? "ON" : "OFF");
    g_bDEVmode = !g_bDEVmode;

    return Plugin_Handled;
}

public Action Cmd_DisableTimer(int client, int args)
{
	CPrintToChatAll("{olive}[FF2]{default} Disabled Timer.");
	FF2_SetRoundTime(-1.0); // 라운드 타이머 끄기
	return Plugin_Handled;
}

public Action Cmd_ChangeBoss(int client, int args)
{
	if(!FF2_IsFF2Enabled())
		return Plugin_Continue;

	char pattern[MAX_TARGET_LENGTH];
	GetCmdArg(1, pattern, sizeof(pattern));
	char targetName[MAX_TARGET_LENGTH];
	int targets[MAXPLAYERS];
	bool targetNounIsMultiLanguage;

	// This is only for test.
	if(ProcessTargetString(pattern, client, targets, 1, 0, targetName, sizeof(targetName), targetNounIsMultiLanguage)<=0)
	{
		Format(pattern, MAX_TARGET_LENGTH, "@me");
	}

	char bossName[64], realName[64];
	Menu menu = new Menu(ChangeBossMenuHandler);
	KeyValues BossKV;

	menu.AddItem(pattern, "", ITEMDRAW_IGNORE);
	for (int i = 0; (BossKV = FF2_GetCharacterKV(i)) != null; i++)
	{
		GetCharacterName(BossKV, realName, 64, 0);
		GetCharacterName(BossKV, bossName, 64, client);
		menu.AddItem(realName, bossName);
	}
	menu.ExitButton = true;
	menu.Display(client, 90);

	return Plugin_Handled;
}

public int ChangeBossMenuHandler(Menu menu, MenuAction action, int client, int item)
{
	switch(action)
	{
		case MenuAction_End:
		{
			delete menu;
		}

		case MenuAction_Select:
		{
			char pattern[MAX_TARGET_LENGTH], targetName[MAX_TARGET_LENGTH];
			char realName[64];
			int targets[MAXPLAYERS], matches;
			bool targetNounIsMultiLanguage;

			menu.GetItem(0, pattern, MAX_TARGET_LENGTH);
			if((matches=ProcessTargetString(pattern, client, targets, MAXPLAYERS, 0, targetName, sizeof(targetName), targetNounIsMultiLanguage))<=0)
			{
				ReplyToTargetError(client, matches);
				return 0;
			}

			for(int loop = 0; loop <= matches; loop++)
			{
				if(targets[loop] == 0 || IsClientSourceTV(targets[loop]) || IsClientReplay(targets[loop]))
					continue;

				KeyValues BossKV = FF2_GetCharacterKV(item - 1);
				GetCharacterName(BossKV, realName, 64, targets[loop]);
				CPrintToChatAll("{olive}[FF2]{default} %N → {orange}%s", targets[loop], realName);
				FF2_MakePlayerToBoss(targets[loop], item - 1);
			}
		}
	}
	return 0;
}

public Action Cmd_UseAbility(int client, int args)
{
	if(!FF2_IsFF2Enabled() || args != 2)
		return Plugin_Continue;

	char pattern[MAX_TARGET_LENGTH];
	GetCmdArg(1, pattern, sizeof(pattern));

	char targetName[MAX_TARGET_LENGTH];
	int targets[MAXPLAYERS+1], targetCount;
	bool targetNounIsMultiLanguage;

	targetCount = ProcessTargetString(pattern, client, targets, MAXPLAYERS+1, 0, targetName, sizeof(targetName), targetNounIsMultiLanguage);
	if(targetCount <= 0)
		return Plugin_Continue;

	char slotStr[4], pluginName[64], abilityName[64];
	GetCmdArg(2, slotStr, sizeof(slotStr));

	int boss,
		slot = StringToInt(slotStr);
	KeyValues kv, bossKv;
	for(int loop = 0; loop <= targetCount; loop++)
	{
		boss = FF2_GetBossIndex(targets[loop]);
		if(boss == -1)		continue;

		kv = FF2_GetBossKV(boss);
		kv.Rewind();
		if(!kv.JumpToKey("abilities"))
			continue;

		bossKv = new KeyValues("abilities");
		bossKv.Import(kv);
		bossKv.GotoFirstSubKey();
		do
		{
			bossKv.GetSectionName(pluginName, sizeof(pluginName));

			bossKv.GotoFirstSubKey();
			do
			{
				bossKv.GetSectionName(abilityName, sizeof(abilityName));

				int currentSlot = bossKv.GetNum("slot", 0),
					buttonMode = bossKv.GetNum("buttonmode", 0);

				if(currentSlot != slot)		continue;
				
				FF2_UseAbility(boss, pluginName, abilityName, slot, buttonMode);
				CPrintToChat(client, "{olive}[FF2]{default} Activated %N's (%s - %s)", targets[loop], pluginName, abilityName);
			}
			while(bossKv.GotoNextKey());
			bossKv.GoBack();
		}
		while(bossKv.GotoNextKey());

		delete bossKv;
	}
	
	return Plugin_Continue;
}

public Action Cmd_ExportBoss(int client, int argc)
{
	if(!FF2_IsFF2Enabled())
		return Plugin_Continue;

	char pattern[MAX_TARGET_LENGTH];
	GetCmdArg(1, pattern, sizeof(pattern));

	char targetName[MAX_TARGET_LENGTH];
	int targets[MAXPLAYERS+1], targetCount;
	bool targetNounIsMultiLanguage;

	targetCount = ProcessTargetString(pattern, client, targets, MAXPLAYERS+1, 0, targetName, sizeof(targetName), targetNounIsMultiLanguage);
	if(targetCount <= 0)
		return Plugin_Continue;

	char bossName[64], path[PLATFORM_MAX_PATH];
	int boss, currentTime[2];
	KeyValues kv, bossKv;

	GetTime(currentTime);
	for(int loop = 0; loop <= targetCount; loop++)
	{
		boss = FF2_GetBossIndex(targets[loop]);
		if(boss == -1)		continue;

		kv = FF2_GetBossKV(boss);
		kv.Rewind();
		kv.GetSectionName(bossName, sizeof(bossName));

		bossKv = new KeyValues(bossName);
		bossKv.Import(kv);

		// int exportLen = bossKv.ExportLength;
		// char[] exportStr = new char[exportLen + 1];
		
		// bossKv.GetString("filename", bossName, sizeof(bossName));


		BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "data/ff2_dumps/%i%i.cfg", currentTime[0], currentTime[1]);
		bossKv.ExportToFile(path);

		LogMessage("[FF2] %N's boss config export (%s)", targets[loop], path);
		CPrintToChat(client, "{olive}[FF2]{default} Exported %N's boss config! (%s)", targets[loop], path);

		delete bossKv;
	}

	return Plugin_Continue;
}

public Action OnRoundStart(Event event, const char[] name, bool dontbroad)
{
    g_bDEVmode = false;

    return Plugin_Continue;
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool& result)
{
	if(g_bDEVmode && FF2_GetBossIndex(client) != -1) {
		FF2_AddBossCharge(FF2_GetBossIndex(client), 0, 100.0);
	}

	return Plugin_Continue;
}

public void FF2_OnCalledQueue(FF2HudQueue hudQueue, int client)
{
	if(!g_bDEVmode) return;

	char text[256];
	bool changed = false;
	FF2HudDisplay hudDisplay = null;

	SetGlobalTransTarget(client);
	hudQueue.GetName(text, sizeof(text));

	if(StrEqual(text, "Boss"))
	{
		int noticehudId = hudQueue.FindHud("Activate Rage");
		if(noticehudId != -1)
		{
			hudQueue.DeleteDisplay(noticehudId);
		}
		changed = true;
	}
	else if(StrEqual(text, "Observer"))
	{
		int observer = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
		changed = IsBoss(observer);
	}

	if(changed)
	{
		Format(text, sizeof(text), "%t", "Dev Mode");

		hudDisplay = FF2HudDisplay.CreateDisplay("Dev Mode", text);
		hudQueue.AddHud(hudDisplay, client);
	}

	return;
}

public Action FF2_OnCheckRules(int client, int characterIndex, int &chance, const char[] ruleName, const char[] value)
{
	if(StrEqual(ruleName, "need_dev_mode"))
		return g_bDEVmode ? Plugin_Continue : Plugin_Handled;

	return Plugin_Continue;
}

public Action FF2_OnCheckSelectRules(int client, int characterIndex, const char[] ruleName, const char[] value)
{
	if(StrEqual(ruleName, "need_dev_mode"))
		return g_bDEVmode ? Plugin_Continue : Plugin_Handled;

	return Plugin_Continue;
}

public void GetCharacterName(KeyValues characterKv, char[] bossName, int size, const int client)
{
	int currentSpot;
	characterKv.GetSectionSymbol(currentSpot);
	characterKv.Rewind();

	if(client > 0)
	{
		char language[8];
		GetLanguageInfo(GetClientLanguage(client), language, sizeof(language));
		if(characterKv.JumpToKey("name_lang"))
		{
			characterKv.GetString(language, bossName, size, "");
			if(bossName[0] != '\0')
				return;
		}
		characterKv.Rewind();
	}
	characterKv.GetString("name", bossName, size);
	characterKv.JumpToKeySymbol(currentSpot);
}

stock bool IsBoss(int client)
{
    return FF2_GetBossIndex(client) != -1;
}
