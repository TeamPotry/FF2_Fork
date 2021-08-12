Handle OnMusic;

/////
// Functions
/////

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
			if(IsValidClient(client))
			{
				if(playBGM[client])
				{
					MusicTimer[client]=null;
					StopMusic(client);
					RequestFrame(PlayBGM, client); // Naydef: We might start playing the music before it gets stopped
				}
				else if(MusicTimer[client]!=null)
				{
					MusicTimer[client]=null;
				}
			}
			else if(MusicTimer[client]!=null)
			{
				MusicTimer[client]=null;
			}
		}
	}
	else
	{
		if(playBGM[client])
		{
			MusicTimer[client]=null;
			StopMusic(client);
			RequestFrame(PlayBGM, client); // Naydef: We might start playing the music before it gets stopped
		}
		else if(MusicTimer[client]!=null)
		{
			MusicTimer[client]=null;
			return Plugin_Stop;
		}
	}
	return Plugin_Continue;
}

void PlayBGM(int client)
{
	char bossName[64];
	KeyValues kv = GetCharacterKV(character[0]);

	kv.Rewind();
	kv.GetString("name", bossName, sizeof(bossName));

	if(!kv.JumpToKey("sounds"))		return;

	ArrayList musicArray = new ArrayList(PLATFORM_MAX_PATH), timeArray = new ArrayList();
	char music[PLATFORM_MAX_PATH];

	kv.GotoFirstSubKey();
	do
	{
		kv.GetSectionName(music, sizeof(music));
		float time = kv.GetFloat("time", 0.0);

		if(music[0] == '\0')
		{
			Debug("[FF2 Bosses] Character %s has a duplicate sound '%s'!", bossName, music);
		}
		else if(time > 0.0)
		{
			musicArray.PushString(music);
			timeArray.Push(time);
		}
	}
	while(kv.GotoNextKey());

	if(!musicArray.Length) // No music found, exiting!
	{
		return;
	}

	char temp[PLATFORM_MAX_PATH], buffer[PLATFORM_MAX_PATH];
	// char information[256];
	int index = GetRandomInt(0, musicArray.Length-1);
	Action action;

	musicArray.GetString(index, buffer, sizeof(buffer));
	strcopy(temp, sizeof(temp), buffer);
	float time2 = timeArray.Get(index), tempTime = time2;
	// kv.GetString("information", information, sizeof(information));

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

	Format(temp, sizeof(temp), "sound/%s", buffer);
	if(FileExists(temp, true))
	{
		if(CheckSoundFlags(client, FF2SOUND_MUTEMUSIC))
		{
			strcopy(currentBGM[client], PLATFORM_MAX_PATH, buffer);
			EmitSoundToClient(client, currentBGM[client]);
			MusicTimer[client]=CreateTimer(time2, Timer_PrepareBGM, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
/*
			if(information[0] != '\0')
			{
				CPrintToChat(client, "{olive}[FF2]{default} Now Playing: %s", information);
			}
*/
		}
	}
	else
	{
		PrintToServer("[FF2 Bosses] Character %s is missing BGM file '%s'!", bossName, music);
	}

	delete musicArray;
	delete timeArray;
}

void StartMusic(int client=0)
{
	if(client<=0)  //Start music for all clients
	{
		StopMusic();
		for(int target; target<=MaxClients; target++)
		{
			playBGM[target]=true;  //This includes the 0th index
		}
		CreateTimer(0.1, Timer_PrepareBGM, 0, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		StopMusic(client);
		playBGM[client]=true;
		CreateTimer(0.1, Timer_PrepareBGM, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
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

				if(MusicTimer[client]!=null)
				{
					delete MusicTimer[client];
				}
			}

			strcopy(currentBGM[client], PLATFORM_MAX_PATH, "");
			if(permanent)
			{
				playBGM[client]=false;
			}
		}
	}
	else
	{
		StopSound(client, SNDCHAN_AUTO, currentBGM[client]);
		StopSound(client, SNDCHAN_AUTO, currentBGM[client]);

		if(MusicTimer[client]!=null)
		{
			delete MusicTimer[client];
		}

		strcopy(currentBGM[client], PLATFORM_MAX_PATH, "");
		if(permanent)
		{
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
	SetSettingData(client, "sound_mute_flag", muteSound[client], KvData_Int);
}

public void ClearSoundFlags(int client, int soundFlags)
{
	if(!IsValidClient(client) || IsFakeClient(client))
	{
		return;
	}

	muteSound[client]&=~soundFlags;
	SetSettingData(client, "sound_mute_flag", muteSound[client], KvData_Int);
}


///
//NATIVES
///

public int Native_StartMusic(Handle plugin, int numParams)
{
	StartMusic(GetNativeCell(1));
}

public int Native_StopMusic(Handle plugin, int numParams)
{
	StopMusic(GetNativeCell(1));
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

public int Native_SetSoundFlags(Handle plugin, int numParams)
{
	SetSoundFlags(GetNativeCell(1), GetNativeCell(2));
}

public int Native_ClearSoundFlags(Handle plugin, int numParams)
{
	ClearSoundFlags(GetNativeCell(1), GetNativeCell(2));
}

public int Native_CheckSoundFlags(Handle plugin, int numParams)
{
	return CheckSoundFlags(GetNativeCell(1), GetNativeCell(2));
}
