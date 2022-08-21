#include "ff2_module/cmd_handler.sp"

Menu changelogMenu;

void Cmd_Init()
{
    RegConsoleCmd("ff2", FF2Panel);
    RegConsoleCmd("ff2_advance", AdvanceMenu);
    RegConsoleCmd("ff2_hp", Command_GetHPCmd);
    RegConsoleCmd("ff2_next", QueuePanelCmd);
    RegConsoleCmd("ff2_classinfo", Command_HelpPanelClass);
    RegConsoleCmd("ff2_changelog", Command_ShowChangelog);
    RegConsoleCmd("ff2_music", MusicTogglePanelCmd);
    RegConsoleCmd("ff2_voice", VoiceTogglePanelCmd);
    RegConsoleCmd("ff2_resetpoints", ResetQueuePointsCmd);

    RegConsoleCmd("nextmap", Command_Nextmap);
    RegConsoleCmd("say", Command_Say);
    RegConsoleCmd("say_team", Command_Say);

    RegAdminCmd("ff2_special", Command_SetNextBoss, ADMFLAG_CHEATS, "Usage:  ff2_special <boss>.  Forces next round to use that boss");
    RegAdminCmd("ff2_addpoints", Command_Points, ADMFLAG_CHEATS, "Usage:  ff2_addpoints <target> <points>.  Adds queue points to any player");
    RegAdminCmd("ff2_point_enable", Command_Point_Enable, ADMFLAG_CHEATS, "Enable the control point if ff2_point_type is 0");
    RegAdminCmd("ff2_point_disable", Command_Point_Disable, ADMFLAG_CHEATS, "Disable the control point if ff2_point_type is 0");
    RegAdminCmd("ff2_start_music", Command_StartMusic, ADMFLAG_CHEATS, "Start the Boss's music");
    RegAdminCmd("ff2_stop_music", Command_StopMusic, ADMFLAG_CHEATS, "Stop any currently playing Boss music");
    RegAdminCmd("ff2_resetqueuepoints", ResetQueuePointsCmd, ADMFLAG_CHEATS, "Reset a player's queue points");
    RegAdminCmd("ff2_resetq", ResetQueuePointsCmd, ADMFLAG_CHEATS, "Reset a player's queue points");
    RegAdminCmd("ff2_charset", Command_Charset, ADMFLAG_CHEATS, "Usage:  ff2_charset <charset>.  Forces FF2 to use a given character set");
    RegAdminCmd("ff2_reload_subplugins", Command_ReloadSubPlugins, ADMFLAG_RCON, "Reload FF2's subplugins.");
}

public Action FF2Panel(int client, int args)  //._.
{
	if(Enabled2 && IsValidClient(client, false))
	{
		Panel panel=CreatePanel();
		char text[512];
		SetGlobalTransTarget(client);
		Format(text, sizeof(text), "%t", "What's Up");
		panel.SetTitle(text);
		Format(text, sizeof(text), "%t", "Observe Health Value");
		panel.DrawItem(text);
		Format(text, sizeof(text), "%t", "Class Changes");
		panel.DrawItem(text);
		Format(text, sizeof(text), "%t", "What's New in FF2");
		panel.DrawItem(text);
		Format(text, sizeof(text), "%t", "View Queue Points");
		panel.DrawItem(text);
		Format(text, sizeof(text), "%t", "Toggle Music");
		panel.DrawItem(text);
		Format(text, sizeof(text), "%t", "Toggle Monologue");
		panel.DrawItem(text);
		Format(text, sizeof(text), "%t", "Toggle Class Changes");
		panel.DrawItem(text);
		Format(text, sizeof(text), "%t", "Advance Menu Title");
		panel.DrawItem(text);
		Format(text, sizeof(text), "%t", "Exit Menu");
		panel.DrawItem(text);
		panel.Send(client, Handler_FF2Panel, MENU_TIME_FOREVER);
		delete panel;
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action AdvanceMenu(int client, int args)
{
	if(Enabled2 && IsValidClient(client, false))
	{
		Panel panel=CreatePanel();
		char text[512];
		SetGlobalTransTarget(client);
		Format(text, sizeof(text), "%t", "Advance Menu Title");
		panel.SetTitle(text);
		Format(text, sizeof(text), "%t", "Boss Difficulty Setting");
		panel.DrawItem(text, ITEMDRAW_DISABLED); // TODO: For Now.
		Format(text, sizeof(text), "%t", "Hud Setting");
		panel.DrawItem(text);
		Format(text, sizeof(text), "%t", "Human Team Boss Setting Title");
		panel.DrawItem(text);
		Format(text, sizeof(text), "%t", "Exit Menu");
		panel.DrawItem(text);
		panel.Send(client, Handler_AdvanceMenuPanel, MENU_TIME_FOREVER);
		delete panel;
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action BossDifficultyMenu(int client, int args)
{
	return Plugin_Continue;
}

public Action HudMenu(int client, int args)
{
	if(Enabled2 && IsValidClient(client, false))
	{
		Menu menu=new Menu(HudMenu_Handler);
		char text[512];
		Format(text, sizeof(text), "%t", "Advance Menu Title");
		Format(text, sizeof(text), "%s > %t", text, "HudMenu Title");
		menu.SetTitle(text);
		Format(text, sizeof(text), "%t", "HudMenu Boss");
		menu.AddItem("Boss", text);
		Format(text, sizeof(text), "%t", "HudMenu Player");
		menu.AddItem("Player", text);
		Format(text, sizeof(text), "%t", "HudMenu Observer");
		menu.AddItem("Observer", text);
		Format(text, sizeof(text), "%t", "HudMenu Other");
		menu.AddItem("Other", text);

		menu.ExitButton=true;
		menu.Display(client, MENU_TIME_FOREVER);
	}

	return Plugin_Continue;
}

public void HudSettingMenu(int client, const char[] name)
{
	SetGlobalTransTarget(client);

	int posId;
	kvHudConfigs.GetSectionSymbol(posId);
	kvHudConfigs.Rewind();

	char infoBuf[64], text[512], languageId[4], statusString[8];
	if(!kvHudConfigs.JumpToKey(name))
	{
		CPrintToChat(client, "{olive}[FF2]{default} %t", "Hud Setting Not Found!");
		return;
	}

	GetLanguageInfo(GetClientLanguage(client), languageId, sizeof(languageId));
	Menu afterMenu=new Menu(HudSetting_Handler);
	int value;
	bool changedLanguage=false;

	afterMenu.SetTitle(name);

	if(kvHudConfigs.GotoFirstSubKey(true))
	{
		do
		{
			kvHudConfigs.GetSectionName(infoBuf, sizeof(infoBuf));
			value=GetHudSetting(client, infoBuf);
			if(!StrEqual(languageId, "en"))
				changedLanguage=kvHudConfigs.JumpToKey(languageId);
			else
				changedLanguage=false;

			GetHudSettingString(value, statusString, 8);
			kvHudConfigs.GetString("title", text, sizeof(text));
			Format(text, sizeof(text), "%s: %s", text, statusString);
			afterMenu.AddItem(infoBuf, text);

			if(changedLanguage)
				kvHudConfigs.GoBack();
		}
		while(kvHudConfigs.GotoNextKey(true));
	}

	afterMenu.ExitButton=true;
	afterMenu.Display(client, MENU_TIME_FOREVER);
	kvHudConfigs.JumpToKeySymbol(posId);
}

void HudDataMenu(int client, char[] name)
{
	char text[256], tempText[80];

	int value=GetHudSetting(client, name);
	Menu menu=new Menu(HudData_Handler);
	GetHudSettingString(value, text, 8);

	menu.SetTitle("HUD SETTING > %s: %s", name, text);

	for(int loop=HudSetting_None; loop < HudSettingValue_Last; loop++)
	{
		GetHudSettingString(loop, text, 8);
		Format(tempText, sizeof(tempText), "Hud Setting %s", text);

		Format(text, sizeof(tempText), "%s: %t", text, tempText);
		menu.AddItem(name, text, (loop == HudSetting_None || loop == value) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}

	menu.ExitButton=true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public Action HumanTeamBossMenu(int client, int args)
{
	if(Enabled2 && IsValidClient(client, false))
	{
		char text[512];
		Menu menu=new Menu(HumanTeamBossMenu_Handler);

		SetGlobalTransTarget(client);
		int currentSetting = GetSettingData(client, "human_team_boss_play", DBSData_Int);

		Format(text, sizeof(text), "%t", "Advance Menu Title");
		Format(text, sizeof(text), "%s > %t\n", text, "Human Team Boss Setting Title");
		Format(text, sizeof(text), "%s\n", text, "Human Team Boss Setting Description");
		menu.SetTitle(text);

		Format(text, sizeof(text), "ON");
		if(currentSetting == 0)
			Format(text, sizeof(text), "%s%t", text, "Menu Already Choose");
		menu.AddItem("ON", text, currentSetting == 0 ? ITEMDRAW_DISABLED : 0);

		Format(text, sizeof(text), "OFF");
		if(currentSetting == 1)
			Format(text, sizeof(text), "%s%t", text, "Menu Already Choose");
		menu.AddItem("OFF", text, currentSetting == 1 ? ITEMDRAW_DISABLED : 0);

		menu.ExitButton=true;
		menu.Display(client, MENU_TIME_FOREVER);
	}

	return Plugin_Continue;
}

public Action Command_ShowChangelog(int client, int args)
{
	if(!IsValidClient(client) || !Enabled2)
	{
		return Plugin_Continue;
	}

	DisplayMenu(changelogMenu, client, MENU_TIME_FOREVER);

	char timeStr[64];
	FormatTime(timeStr, sizeof(timeStr), "%Y-%m-%d %H:%M:%S");

	SetSettingStringData(client, "changelog_last_view_time", timeStr);

	return Plugin_Handled;
}

public Action HelpPanel3Cmd(int client, int args)
{
	if(!IsValidClient(client) || !Enabled2)
	{
		return Plugin_Continue;
	}

	Panel panel=CreatePanel();
	panel.SetTitle("FF2 병과 정보를..");
	panel.DrawItem("ON");
	panel.DrawItem("OFF");
	panel.DrawItem("ON: 이번 라운드 보스 설명");
	panel.Send(client, ClassInfoTogglePanelH, MENU_TIME_FOREVER);
	delete panel;

	return Plugin_Handled;
}

public Action Command_HelpPanelClass(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	HelpPanelClass(client);
	return Plugin_Handled;
}

public Action HelpPanelClass(int client)
{
	if(!Enabled)
	{
		return Plugin_Continue;
	}

	int boss=GetBossIndex(client);
	if(boss!=-1)
	{
		HelpPanelBoss(client, boss);
		return Plugin_Continue;
	}

	char text[512];
	TFClassType playerclass=TF2_GetPlayerClass(client);
	SetGlobalTransTarget(client);
	switch(playerclass)
	{
		case TFClass_Scout:
		{
			Format(text, sizeof(text), "%t", "Scout Advice");
		}
		case TFClass_Soldier:
		{
			Format(text, sizeof(text), "%t", "Soldier Advice");
		}
		case TFClass_Pyro:
		{
			Format(text, sizeof(text), "%t", "Pyro Advice");
		}
		case TFClass_DemoMan:
		{
			Format(text, sizeof(text), "%t", "Demo Advice");
		}
		case TFClass_Heavy:
		{
			Format(text, sizeof(text), "%t", "Heavy Advice");
		}
		case TFClass_Engineer:
		{
			Format(text, sizeof(text), "%t", "Engineer Advice");
		}
		case TFClass_Medic:
		{
			Format(text, sizeof(text), "%t", "Medic Advice");
		}
		case TFClass_Sniper:
		{
			Format(text, sizeof(text), "%t", "Sniper Advice");
		}
		case TFClass_Spy:
		{
			Format(text, sizeof(text), "%t", "Spy Advice");
		}
		default:
		{
			Format(text, sizeof(text), "");
		}
	}

	if(playerclass!=TFClass_Sniper)
	{
		Format(text, sizeof(text), "%t\n%s", "Melee Advice", text);
	}

	int weapon;
	char weaponHintText[100];
	for(int loop = TFWeaponSlot_Primary; loop <= TFWeaponSlot_PDA; loop++)
	{
		weapon = GetPlayerWeaponSlot(client, loop);
		if(IsValidEntity(weapon) && GetWeaponHint(client, weapon, weaponHintText, sizeof(weaponHintText)))
			Format(text, sizeof(text), "%s\n%s", text, weaponHintText);
	}

	Panel panel=CreatePanel();
	panel.SetTitle(text);
	panel.DrawItem("Exit");
	panel.Send(client, HintPanelH, 20);
	delete panel;
	return Plugin_Continue;
}

public int HintPanelH(Menu menu, MenuAction action, int client, int selection)
{
	if(IsValidClient(client) && (action==MenuAction_Select || (action==MenuAction_Cancel && selection==MenuCancel_Exit)))
	{
		FF2Flags[client]|=FF2FLAG_CLASSHELPED;
	}
	return 0;
}

void HelpPanelBoss(int client, int boss)
{
	if(!IsValidClient(Boss[boss]))
	{
		return;
	}

	KeyValues kv = GetCharacterKV(character[boss]);
	kv.Rewind();
	if(kv.JumpToKey("description"))
	{
		char text[512], language[8];
		GetLanguageInfo(GetClientLanguage(client), language, sizeof(language));
		//kv.SetEscapeSequences(true);  //Not working
		kv.GetString(language, text, sizeof(text));
		if(!text[0])
		{
			kv.GetString("en", text, sizeof(text));  //Default to English if their language isn't available
			if(!text[0])
			{
				return;
			}
		}
		ReplaceString(text, sizeof(text), "\\n", "\n");
		//kv.SetEscapeSequences(false);  //We don't want to interfere with the download paths

		Panel panel=CreatePanel();
		panel.SetTitle(text);
		panel.DrawItem("Exit");
		panel.Send(client, HintPanelH, 20);
		delete panel;
	}
}

public Action QueuePanelCmd(int client, int args)
{
	if(!Enabled2)
	{
		return Plugin_Continue;
	}

	char text[64];
	int items;
	bool[] added = new bool[MaxClients + 1];

	Panel panel = new Panel();
	SetGlobalTransTarget(client);
	Format(text, sizeof(text), "%t", "Boss Queue");  //"Boss Queue"
	panel.SetTitle(text);
	for(int boss = 0; boss <= MaxClients; boss++)  //Add the current bosses to the top of the list
	{
		if(IsBoss(boss))
		{
			added[boss] = true;  //Don't want the bosses to show up again in the actual queue list
			Format(text, sizeof(text), "%N-%i", boss, GetClientQueuePoints(boss));
			panel.DrawItem(text);
			items++;
		}
	}

	panel.DrawText("---");
	do
	{
		int target = GetClientWithMostQueuePoints(added);  //Get whoever has the highest queue points out of those who haven't been listed yet
		if(!IsValidClient(target))  //When there's no players left, fill up the rest of the list with blank lines
		{
			panel.DrawItem("");
			items++;
			continue;
		}

		Format(text, sizeof(text), "%N-%i", target, GetClientQueuePoints(target));
		if(client != target)
		{
			panel.DrawItem(text);
			items++;
		}
		else
		{
			panel.DrawText(text);  //DrawPanelText() is white, which allows the client's points to stand out
		}
		added[target] = true;
	}
	while(items < 9);

	Format(text, sizeof(text), "%t (%t)", "Your Queue Points", GetClientQueuePoints(client), "Reset Queue Points");  //"Your queue point(s) is {1} (set to 0)"
	panel.DrawItem(text);

	panel.Send(client, QueuePanelH, MENU_TIME_FOREVER);
	delete panel;

	return Plugin_Handled;
}

public int QueuePanelH(Menu menu, MenuAction action, int client, int selection)
{
	if(action == MenuAction_Select && selection == 10)
	{
		TurnToZeroPanel(client, client);
	}

	return 0;
}

public Action TurnToZeroPanel(int client, int target)
{
	if(!Enabled2)
	{
		return Plugin_Continue;
	}

	Panel panel = CreatePanel();
	char text[128];
	SetGlobalTransTarget(client);
	if(client == target)
	{
		Format(text, 512, "%t", "Reset Queue Points Confirmation");  //Do you really want to set your queue points to 0?
	}
	else
	{
		Format(text, 512, "%t", "Reset Player's Queue Points", client);  //Do you really want to set {1}'s queue points to 0?
	}

	PrintToChat(client, text);
	panel.SetTitle(text);
	Format(text, sizeof(text), "%t", "Yes");
	panel.DrawItem(text);
	Format(text, sizeof(text), "%t", "No");
	panel.DrawItem(text);
	shortname[client] = target;
	panel.Send(client, TurnToZeroPanelH, MENU_TIME_FOREVER);
	delete panel;

	return Plugin_Handled;
}

public int TurnToZeroPanelH(Menu menu, MenuAction action, int client, int position)
{
	if(action==MenuAction_Select && position==1)
	{
		if(shortname[client]==client)
		{
			CPrintToChat(client,"{olive}[FF2]{default} %t", "Reset Queue Points Done");  //Your queue points have been reset to {olive}0{default}
		}
		else
		{
			CPrintToChat(client, "{olive}[FF2]{default} %t", "Reset Player's Points Done", shortname[client]);  //{olive}{1}{default}'s queue points have been reset to {olive}0{default}
			CPrintToChat(shortname[client], "{olive}[FF2]{default} %t", "Queue Points Reset by Admin", client);  //{olive}{1}{default} reset your queue points to {olive}0{default}
		}
		SetClientQueuePoints(shortname[client], 0);
	}
}


public Action MusicTogglePanelCmd(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	MusicTogglePanel(client);
	return Plugin_Handled;
}

public Action MusicTogglePanel(int client)
{
	if(!Enabled || !IsValidClient(client))
	{
		return Plugin_Continue;
	}

	char text[128];
	Panel panel=CreatePanel();
	SetGlobalTransTarget(client);
	Format(text, sizeof(text), "%t", "Toggle Music Switch");

	panel.SetTitle(text);
	panel.DrawItem("ON");
	panel.DrawItem("OFF");
	Format(text, sizeof(text), "%T", "Music Track Select Title", client);
	panel.DrawItem(text);
	panel.Send(client, MusicTogglePanelH, MENU_TIME_FOREVER);
	delete panel;
	return Plugin_Continue;
}

public void MusicTrackMenu(int client)
{
	if(!Enabled || !IsValidClient(client))
	{
		return;
	}

	SetGlobalTransTarget(client);

	char text[128], musicId[84], bossName[64], kvString[64];
	Menu menu = new Menu(MusicTrackMenu_Handler);

	Format(text, sizeof(text), "%T", "Music Track Select Title", client);
	menu.SetTitle(text);

	MD5_String(currentBGM[client], musicId, sizeof(musicId));
	Format(text, sizeof(text), "[%s] %T", GetMusicSetting(client, musicId) ? "ON" : "OFF",
		"Menu Music Track Current Music", client);
	menu.AddItem(musicId, text);

	KeyValues bossKv;
	bool hasMusic;
	// TODO: 외부 팩 지원
	char language[8];
	int lang = GetClientLanguage(client);

	GetLanguageInfo(lang, language, sizeof(language));
	for(int characterIndex = 0; characterIndex < bossesArray.Length && (bossKv = GetCharacterKV(characterIndex)); characterIndex++)
	{
		hasMusic = false;

		bossKv.Rewind();
		if(bossKv.JumpToKey("name_lang"))
			bossKv.GetString(language, bossName, sizeof(bossName));
		else
			bossKv.GetString("name", bossName, sizeof(bossName));

		bossKv.Rewind();
		if(!bossKv.JumpToKey("sounds")) 	continue;

		bossKv.GotoFirstSubKey();
		do
		{
			int time = RoundFloat(bossKv.GetFloat("time", 0.0));
			if(time > 0)
			{
				hasMusic = true;
				break;
			}
		}
		while(bossKv.GotoNextKey());

		if(!hasMusic)	continue;

		IntToString(view_as<int>(bossKv), kvString, sizeof(kvString));
		Format(text, sizeof(text), "%T", "Menu Music Track Boss Music", client, bossName);
		menu.AddItem(kvString, text);
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public void MusicTrackDetailMenu(int client, KeyValues kv)
{
	if(!Enabled || !IsValidClient(client) || kv == null)
	{
		return;
	}

	SetGlobalTransTarget(client);

	char text[128], musicId[84], path[PLATFORM_MAX_PATH], information[258], bossName[64], language[8];
	Menu menu = new Menu(MusicTrackDetailMenu_Handler);
	int lang = GetClientLanguage(client);

	GetLanguageInfo(lang, language, sizeof(language));
	kv.Rewind();

	if(kv.JumpToKey("name_lang"))
		kv.GetString(language, bossName, sizeof(bossName), "");
	else
		kv.GetString("name", bossName, sizeof(bossName), "");

	kv.Rewind();
	if(!kv.JumpToKey("sounds"))		return;

	Format(text, sizeof(text), "%T", "Music Track Detail Title", client, bossName);
	menu.SetTitle(text);

	IntToString(view_as<int>(kv), musicId, sizeof(musicId));
	menu.AddItem(musicId, musicId, ITEMDRAW_IGNORE);

	int index = 1;

	kv.GotoFirstSubKey();
	do
	{
		kv.GetSectionName(path, PLATFORM_MAX_PATH);
		MD5_String(path, musicId, sizeof(musicId));
		int time = RoundFloat(kv.GetFloat("time", 0.0));
		if(time > 0)
		{
			kv.GetString("information", information, sizeof(information), "");
			if(information[0] == '\0')
			{
				Format(information, sizeof(information), "%T", "Boss Music Info", client, bossName, index);
			}

			Format(text, sizeof(text), "[%s] %s", GetMusicSetting(client, musicId) ? "ON" : "OFF",
				information);
			menu.AddItem(path, text);

			index++;
		}
	}
	while(kv.GotoNextKey());

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MusicTrackDetailMenu_Handler(Menu menu, MenuAction action, int client, int selection)
{
	char kvString[84], musicId[84], currentMusicId[84], path[PLATFORM_MAX_PATH];

	switch(action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Cancel:
		{
			if(selection == MenuCancel_ExitBack)
				MusicTrackMenu(client);
		}
		case MenuAction_Select:
		{
			GetMenuItem(menu, 0, kvString, sizeof(kvString));
			GetMenuItem(menu, selection, path, sizeof(path));
			MD5_String(path, musicId, sizeof(musicId));

			bool value = !GetMusicSetting(client, musicId);
			SetMusicSetting(client, musicId, value);

			CPrintToChat(client, "{olive}[FF2]{default} %T", "Menu Music Track Choose Music Setting", client, value ? "ON" : "OFF");

			MD5_String(currentBGM[client], currentMusicId, sizeof(currentMusicId));
			if(StrEqual(currentMusicId, musicId))
			{
				StopMusic(client);
				StartMusic(client, true);
			}

			KeyValues kv = view_as<KeyValues>(StringToInt(kvString));
			MusicTrackDetailMenu(client, kv);
		}
	}

	return 0;
}

public Action VoiceTogglePanelCmd(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	VoiceTogglePanel(client);
	return Plugin_Handled;
}

public Action VoiceTogglePanel(int client)
{
	if(!Enabled || !IsValidClient(client))
	{
		return Plugin_Continue;
	}

	char text[128];
	Panel panel=CreatePanel();
	SetGlobalTransTarget(client);
	Format(text, sizeof(text), "%t", "Toggle Monologue Switch");

	panel.SetTitle(text);
	panel.DrawItem("ON");
	panel.DrawItem("OFF");
	panel.Send(client, VoiceTogglePanelH, MENU_TIME_FOREVER);
	delete panel;
	return Plugin_Continue;
}

// Stocks
void ParseChangelog()
{
	KeyValues kv=LoadChangelog();
	if(kv == null)	return;

	changelogMenu=CreateMenu(Handler_ChangelogMenu);
	changelogMenu.SetTitle("%t", "Changelog");

	int id;
	if(kv.GotoFirstSubKey())
	{
		char version[64], temp[70];
		do
		{
			kv.GetSectionName(version, sizeof(version));
			kv.GetSectionSymbol(id);
			Format(temp, sizeof(temp), "%i", id);
			changelogMenu.AddItem(temp, version);
		}
		while(kv.GotoNextKey());

		delete kv;
	}
	else
	{
		LogError("[FF2] Changelog is empty!");
	}
}
