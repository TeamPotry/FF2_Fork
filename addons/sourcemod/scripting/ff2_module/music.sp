Handle OnMusic;

/////
// Functions
/////

public Action Timer_PrepareBGM_Delayed(Handle timer, int userid)
{
	int client=GetClientOfUserId(userid);
	if(CheckRoundState()!=FF2RoundState_RoundRunning || (!client && MapHasMusic()) || (!client && userid))
	{
		return Plugin_Stop;
	}

	StartMusic(client, true);
	return Plugin_Continue;
}


public Action Timer_PrepareBGM(Handle timer, int userid)
{
	int client=GetClientOfUserId(userid);
	if(CheckRoundState()!=FF2RoundState_RoundRunning || (!client && MapHasMusic()) || (!client && userid))
	{
		return Plugin_Stop;
	}

	if(!client)
	{
		for(client=1; client<=MaxClients; client++)
		{
			if(MusicTimer[client] != null)
			{
				KillTimer(MusicTimer[client]);
				MusicTimer[client] = null;
			}
			if(IsValidClient(client))
			{
				if(playBGM[client])
				{
					StopMusic(client);
					RequestFrame(PlayBGM, client); // Naydef: We might start playing the music before it gets stopped
				}
			}
		}
	}
	else
	{
		if(MusicTimer[client]!=null)
		{
			KillTimer(MusicTimer[client]);
			MusicTimer[client] = null;
		}

		if(playBGM[client])
		{
			StopMusic(client);
			RequestFrame(PlayBGM, client); // Naydef: We might start playing the music before it gets stopped
		}
	}
	return Plugin_Continue;
}

public int GetRandomBGM(int client, KeyValues characterKv, char[] path, int buffer, float &time, char[] information, int informationBuffer)
{
	char musicId[84], bossName[64];

	characterKv.Rewind();
	characterKv.GetString("name", bossName, sizeof(bossName));

	if(!characterKv.JumpToKey("sounds"))		return -1;

	KeyValues kv = new KeyValues("sounds");
	ArrayList musicArray = new ArrayList();
	char music[PLATFORM_MAX_PATH];
	int id;

	kv.Import(characterKv);
	kv.GotoFirstSubKey();
	do
	{
		kv.GetSectionName(music, sizeof(music));
		float tempTime = kv.GetFloat("time", 0.0);

		if(music[0] == '\0')
		{
			Debug("[FF2 Bosses] Character %s has a duplicate sound '%s'!", bossName, music);
		}
		else if(tempTime > 0.0)
		{
			MD5_String(music, musicId, sizeof(musicId));
			if(GetMusicSetting(client, musicId))
			{
				kv.GetSectionSymbol(id);
				musicArray.Push(id);
			}
		}
	}
	while(kv.GotoNextKey());

	if(!musicArray.Length) // No music found, exiting!
	{
		delete musicArray;
		delete kv;

		return -1;
	}

	int index = GetRandomInt(0, musicArray.Length-1);

	kv.Rewind();
	id = musicArray.Get(index);
	kv.JumpToKeySymbol(id);

	kv.GetSectionName(path, buffer);
	time = kv.GetFloat("time");
	kv.GetString("information", information, informationBuffer);

	if(kv.JumpToKey("phase"))
	{
		kv.GetString("starting phase", currentMusicPhase[client], sizeof(currentMusicPhase[]), "");

		if(kv.JumpToKey(currentMusicPhase[client]))
			time = kv.GetFloat("end");
	}

	delete musicArray;
	delete kv;

	return index;
}

public bool TryPlayNextPhase(int client, KeyValues characterKv, const char[] path, float &startTime, float &endTime)
{
	characterKv.Rewind();
	if(!characterKv.JumpToKey("sounds"))
		return false;

	// Yes, JumpToKey does't work on the names with slash.
	// Linear solution
	{
		bool foundKey = false;
		char sectionName[64];

		characterKv.GotoFirstSubKey();
		do
		{
			characterKv.GetSectionName(sectionName, sizeof(sectionName));
			if(StrEqual(sectionName, path) && characterKv.JumpToKey("phase"))
			{
				foundKey = true;
				break;
			}
		}
		while(characterKv.GotoNextKey());

		if(!foundKey)
			return false;
	}

	KeyValues kv = new KeyValues("phase");

	kv.Import(characterKv);
	kv.Rewind();

	if(!kv.JumpToKey(currentMusicPhase[client]))
	{
		// 아무것도 발견 못함.
		delete kv;
		return false;
	}

	kv.GetString("next", currentMusicPhase[client], sizeof(currentMusicPhase[]), "");
	// PrintToChatAll("next: %s", currentMusicPhase[client]);

	kv.Rewind();
	if(!kv.JumpToKey(currentMusicPhase[client]))
	{
		delete kv;
		return false;
	}

	startTime = kv.GetFloat("start", 0.0);
	endTime = kv.GetFloat("end", 0.0);

	// PrintToChatAll("startTime: %.1f, endTime: %.1f", startTime, endTime);

	if(startTime > endTime)
	{
		LogError("[FF2] Start time must be smaller than end time! (%s)", path);

		delete kv;
		return false;
	}

	delete kv;
	return true;
}

void PlayBGM(int client)
{
	KeyValues characterKv = GetCharacterKV(character[0]);
	char temp[PLATFORM_MAX_PATH], buffer[PLATFORM_MAX_PATH], information[256], bossName[64];
	float time2, startTime = 0.0, endTime = 0.0;
	int index;

	characterKv.Rewind();
	characterKv.GetString("name", bossName, sizeof(bossName));

	// 현재 페이즈가 없는 경우
	bool hasNextPhase = false;
	if(currentBGM[client][0] != '\0'
		&& TryPlayNextPhase(client, characterKv, currentBGM[client], startTime, endTime))
	{
		hasNextPhase = true;
		strcopy(buffer, PLATFORM_MAX_PATH, currentBGM[client]);
	}
	else
	{
		currentMusicPhase[client] = "";
		index = GetRandomBGM(client, characterKv, buffer, PLATFORM_MAX_PATH, time2, information, sizeof(information));

		// For test
		// startTime = 10.0;
		if(index == -1)
			return;
	}

	strcopy(temp, sizeof(temp), buffer);

	if(hasNextPhase)
	{
		time2 = endTime - startTime;
	}
	else
	{
		Action action;
		float tempTime = time2;

		Call_StartForward(OnMusic);
		Call_PushCell(client);
		Call_PushStringEx(temp, sizeof(temp), SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
		Call_PushCellRef(tempTime);
		Call_Finish(action);
		switch(action)
		{
			case Plugin_Stop, Plugin_Handled:
			{
				return;
			}
			case Plugin_Changed:
			{
				strcopy(buffer, sizeof(buffer), temp);
				time2 = tempTime;
			}
		}
	}

	Format(temp, sizeof(temp), "sound/%s", buffer);
	if(FileExists(temp, true))
	{
		if(CheckSoundFlags(client, FF2SOUND_MUTEMUSIC))
		{
			strcopy(currentBGM[client], PLATFORM_MAX_PATH, buffer);
			EmitSoundToClient(client, currentBGM[client], _, _, _, _, _, _, _, _, _, _, startTime * -1.0);
			MusicTimer[client]=CreateTimer(time2, Timer_PrepareBGM, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);

			if(!hasNextPhase)
			{
				if(information[0] != '\0')
				{
					CPrintToChat(client, "{olive}[FF2]{default} Now Playing: %s", information);
				}
				else
				{
					GetBossName(GetBossIndex(Boss[0]), information, sizeof(information), client);
					CPrintToChat(client, "{olive}[FF2]{default} Now Playing: %T", "Boss Music Info", client, information, index + 1);
				}
			}
		}
	}
	else
	{
		PrintToServer("[FF2 Bosses] Character %s is missing BGM file '%s'!", bossName, buffer);
	}

	// PrintToChatAll("%N's hasNextPhase(%s), %s %s\n time2: %.1f, %.1f %.1f", client, hasNextPhase ? "true" : "false", currentBGM[client], currentMusicPhase[client], time2, startTime, endTime);
}

void StartMusic(int client = 0, bool init = false)
{
	if(client<=0)  //Start music for all clients
	{
		// StopMusic();
		for(int target; target<=MaxClients; target++)
		{
			if(init)
				currentMusicPhase[client] = "";

			playBGM[target]=true;  //This includes the 0th index
		}

		Timer_PrepareBGM(null, 0);
		// CreateTimer(0.1, Timer_PrepareBGM, 0, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		if(init)
			currentMusicPhase[client] = "";

		// StopMusic(client);
		playBGM[client]=true;
		Timer_PrepareBGM(null, GetClientUserId(client));
		// CreateTimer(0.1, Timer_PrepareBGM, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

void StopMusic(int client=0, bool permanent=false)
{
	if(client<=0)  //Stop music for all clients
	{
		if(permanent)
		{
			playBGM[0]=false;
		}

		for(client=1; client<=MaxClients; client++)
		{
			if(IsValidClient(client))
			{
				StopSound(client, SNDCHAN_AUTO, currentBGM[client]);

				if(MusicTimer[client] != null)
				{
					KillTimer(MusicTimer[client]);
					MusicTimer[client] = null;
				}
			}

			if(permanent)
			{
				strcopy(currentBGM[client], PLATFORM_MAX_PATH, "");
				playBGM[client]=false;
			}
		}
	}
	else
	{
		StopSound(client, SNDCHAN_AUTO, currentBGM[client]);
		// StopSound(client, SNDCHAN_AUTO, currentBGM[client]);

		// PrintToChatAll("%N's music stopped. (%s)", client, currentBGM[client]);

		if(MusicTimer[client] != null)
		{
			KillTimer(MusicTimer[client]);
			MusicTimer[client] = null;
		}

		if(permanent)
		{
			strcopy(currentBGM[client], PLATFORM_MAX_PATH, "");
			playBGM[client]=false;
		}
	}
}

stock void EmitSoundToAllExcept(int soundFlags, const char[] sample, int entity=SOUND_FROM_PLAYER, int channel=SNDCHAN_AUTO, int level=SNDLEVEL_NORMAL, int flags=SND_NOFLAGS, float volume=SNDVOL_NORMAL, int pitch=SNDPITCH_NORMAL, int speakerentity=-1, const float origin[3]=NULL_VECTOR, const float dir[3]=NULL_VECTOR, bool updatePos=true, float soundtime=0.0)
{
	int[] clients=new int[MaxClients+1];
	int total;
	for(int client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client) && IsClientInGame(client))
		{
			if(CheckSoundFlags(client, soundFlags))
			{
				clients[total++]=client;
			}
		}
	}

	if(!total)
	{
		return;
	}

	EmitSound(clients, total, sample, entity, channel, level, flags, volume, pitch, speakerentity, origin, dir, updatePos, soundtime);
}

public bool CheckSoundFlags(int client, int soundFlags)
{
	if(!IsValidClient(client))
	{
		return false;
	}

	if(IsFakeClient(client))
	{
		return false;
	}

	if(muteSound[client] & soundFlags)
	{
		return false;
	}
	return true;
}

public void SetSoundFlags(int client, int soundFlags)
{
	if(!IsValidClient(client) || IsFakeClient(client))
	{
		return;
	}

	muteSound[client] |= soundFlags;
	SetSettingData(client, "sound_mute_flag", muteSound[client], DBSData_Int);
}

public void ClearSoundFlags(int client, int soundFlags)
{
	if(!IsValidClient(client) || IsFakeClient(client))
	{
		return;
	}

	muteSound[client]&=~soundFlags;
	SetSettingData(client, "sound_mute_flag", muteSound[client], DBSData_Int);
}

stock bool GetMusicSetting(int client, char[] musicId)
{
	return (DBSPlayerData.GetClientData(client)).GetData(FF2DATABASE_CONFIG_NAME, FF2_DB_PLAYER_MUSICDATA_TABLENAME, musicId, "setting_value") == 0;
}

stock void SetMusicSetting(int client, char[] musicId, bool value)
{
	char timeStr[32];
	FormatTime(timeStr, sizeof(timeStr), "%Y-%m-%d %H:%M:%S", GetTime());

	(DBSPlayerData.GetClientData(client)).SetData(FF2DATABASE_CONFIG_NAME, FF2_DB_PLAYER_MUSICDATA_TABLENAME, musicId, "setting_value", value ? 0 : 1);
	(DBSPlayerData.GetClientData(client)).SetStringData(FF2DATABASE_CONFIG_NAME, FF2_DB_PLAYER_MUSICDATA_TABLENAME, musicId, "last_saved_time", timeStr);
}

///
//NATIVES
///

public /*void*/int Native_StartMusic(Handle plugin, int numParams)
{
	StartMusic(GetNativeCell(1));
	return 0;
}

public /*void*/ Native_StopMusic(Handle plugin, int numParams)
{
	StopMusic(GetNativeCell(1));
	return 0;
}

public int Native_FindSound(Handle plugin, int numParams)
{
	char kv[64];
	GetNativeString(1, kv, sizeof(kv));

	int length=GetNativeCell(3);
	char[] sound=new char[length];
	bool soundExists=FindSound(kv, sound, length, GetNativeCell(4), view_as<bool>(GetNativeCell(5)), GetNativeCell(6));
	SetNativeString(2, sound, length);
	return soundExists;
}

public /*void*/int Native_SetSoundFlags(Handle plugin, int numParams)
{
	SetSoundFlags(GetNativeCell(1), GetNativeCell(2));
	return 0;
}

public /*void*/int Native_ClearSoundFlags(Handle plugin, int numParams)
{
	ClearSoundFlags(GetNativeCell(1), GetNativeCell(2));
	return 0;
}

public int Native_CheckSoundFlags(Handle plugin, int numParams)
{
	return CheckSoundFlags(GetNativeCell(1), GetNativeCell(2));
}
