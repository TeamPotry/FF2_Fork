public int Handler_Temp(Menu menu, MenuAction action, int client, int selection)
{
	// Nop
}

public int Handler_FF2Panel(Menu menu, MenuAction action, int client, int selection)
{
	if(action==MenuAction_Select)
	{
		switch(selection)
		{
			case 1:
			{
				Command_GetHP(client);
			}
			case 2:
			{
				HelpPanelClass(client);
			}
			case 3:
			{
				Command_ShowChangelog(client, 0);
			}
			case 4:
			{
				QueuePanelCmd(client, 0);
			}
			case 5:
			{
				MusicTogglePanel(client);
			}
			case 6:
			{
				VoiceTogglePanel(client);
			}
			case 7:
			{
				HelpPanel3Cmd(client, 0);
			}
			case 8:
			{
				AdvanceMenu(client, 0);
			}
			default:
			{
				return;
			}
		}
	}
}

public int Handler_AdvanceMenuPanel(Menu menu, MenuAction action, int client, int selection)
{
	if(action==MenuAction_Select)
	{
		switch(selection)
		{
			case 1:
			{
				BossDifficultyMenu(client, 0);
			}
			case 2:
			{
				HudMenu(client, 0);
			}
			case 3:
			{
				HumanTeamBossMenu(client, 0);
			}
			default:
			{
				return;
			}
		}
	}
}

public int HudMenu_Handler(Menu menu, MenuAction action, int client, int selection)
{
	if(action==MenuAction_Select)
	{
		int drawStyle;
		char infoBuf[64];
		menu.GetItem(selection, infoBuf, sizeof(infoBuf), drawStyle);
		HudSettingMenu(client, infoBuf);
	}
}

public int HudSetting_Handler(Menu menu, MenuAction action, int client, int selection)
{
	if(action==MenuAction_Select)
	{
		int drawStyle;
		char infoBuf[64];
		menu.GetItem(selection, infoBuf, sizeof(infoBuf), drawStyle);

		HudDataMenu(client, infoBuf);
	}
}

public int HudData_Handler(Menu menu, MenuAction action, int client, int selection)
{
	if(action==MenuAction_Select)
	{
		int drawStyle;
		char infoBuf[64], statusString[8];
		menu.GetItem(selection, infoBuf, sizeof(infoBuf), drawStyle);

		int value = selection-1;
		SetHudSetting(client, infoBuf, value);
		GetHudSettingString(value, statusString, 8);

		CPrintToChat(client, "{olive}[FF2]{default} %s: %s", infoBuf, statusString);
		HudMenu(client, 0);
	}
}

public int HumanTeamBossMenu_Handler(Menu menu, MenuAction action, int client, int selection)
{
	if(action==MenuAction_Select)
	{
		// 0: ON, 1: OFF
		SetSettingData(client, "human_team_boss_play", selection, DBSData_Int);
		CPrintToChat(client, "{olive}[FF2]{default} %t: %s",
			"Human Team Boss Setting Title", selection > 0 ? "OFF" : "ON");
	}
}

public int ClassInfoTogglePanelH(Menu menu, MenuAction action, int client, int selection)
{
	if(IsValidClient(client))
	{
		if(action==MenuAction_Select)
		{
			// class_info_view: 0: VIEW, 1: OFF, 2, VIEW: Main boss's help panel
			SetSettingData(client, "class_info_view", selection - 1, DBSData_Int);
			CPrintToChat(client, "{olive}[FF2]{default} %t", "FF2 Class Info", selection==2 ? "off" : "on");
		}
	}
}

public int Handler_ChangelogMenu(Menu menu, MenuAction action, int client, int selection)
{
	if(IsValidClient(client) && action==MenuAction_Select)
	{
		KeyValues kv=LoadChangelog();
		Menu logMenu=new Menu(Handler_Temp);
		int id;
		char infoBuf[8], text[256], temp[32];
		menu.GetItem(selection, infoBuf, 8, id, temp, sizeof(temp));

		id=StringToInt(infoBuf);
		kv.JumpToKeySymbol(id);
		kv.GetSectionName(text, sizeof(text));
		logMenu.SetTitle(text);
		logMenu.ExitButton=true;

		if(kv.GotoFirstSubKey(false))
		{
			do
			{
				kv.GetString(NULL_STRING, text, sizeof(text));
				logMenu.AddItem(temp, text, ITEMDRAW_DISABLED);
			}
			while(kv.GotoNextKey(false));
		}
		logMenu.Display(client, MENU_TIME_FOREVER);
	}
}

public int MusicTogglePanelH(Menu menu, MenuAction action, int client, int selection)
{
	if(IsValidClient(client) && action==MenuAction_Select)
	{
		if(selection == 3)
		{
			MusicTrackMenu(client);
			return 0;
		}
		else if(selection==2)  //Off
		{
			SetSoundFlags(client, FF2SOUND_MUTEMUSIC);
			StopMusic(client, true);
		}
		else  //On
		{
			//If they already have music enabled don't do anything
			if(!CheckSoundFlags(client, FF2SOUND_MUTEMUSIC))
			{
				ClearSoundFlags(client, FF2SOUND_MUTEMUSIC);
				StartMusic(client, true);
			}
		}
		CPrintToChat(client, "{olive}[FF2]{default} %t", "FF2 Music", selection==2 ? "off" : "on");
	}
	return 0;
}

enum
{
	MusicTrackMenu_SelectCurrentMusic = 0,

	MusicTrackMenu_Count
};

public int MusicTrackMenu_Handler(Menu menu, MenuAction action, int client, int selection)
{
	char packName[128];

	switch(action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Cancel:
		{
			if(selection == MenuCancel_ExitBack)
				MusicTogglePanel(client);
		}
		case MenuAction_Select:
		{
			GetMenuItem(menu, selection, packName, sizeof(packName));
			switch(selection)
			{
				case MusicTrackMenu_SelectCurrentMusic:
				{
					bool value = !GetMusicSetting(client, packName);
					SetMusicSetting(client, packName, value);

					CPrintToChat(client, "{olive}[FF2]{default} %T", "Menu Music Track Choose Music Setting",
						client, value ? "ON" : "OFF");
					MusicTrackMenu(client);

					StopMusic(client);
					StartMusic(client, true);
				}
				default:
				{
					MusicTrackDetailMenu(client, view_as<KeyValues>(StringToInt(packName)));
				}
			}
		}
	}
}

public int VoiceTogglePanelH(Menu menu, MenuAction action, int client, int selection)
{
	if(IsValidClient(client))
	{
		if(action==MenuAction_Select)
		{
			if(selection==2)
			{
				SetSoundFlags(client, FF2SOUND_MUTEVOICE);
			}
			else
			{
				ClearSoundFlags(client, FF2SOUND_MUTEVOICE);
			}

			CPrintToChat(client, "{olive}[FF2]{default} %t", "FF2 Voice", selection==2 ? "off" : "on");
			if(selection==2)
			{
				CPrintToChat(client, "%t", "FF2 Voice 2");
			}
		}
	}
}
