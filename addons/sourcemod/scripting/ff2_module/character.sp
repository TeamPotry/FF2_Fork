public void FindCharacters()
{
	char config[PLATFORM_MAX_PATH], charset[42];
	BuildPath(Path_SM, config, sizeof(config), "%s/%s", FF2_SETTINGS, BOSS_CONFIG);

	if(!FileExists(config))
	{
		LogError("[FF2 Bosses] Disabling Freak Fortress 2 - can not find %s!", config);
		Enabled2=false;
		return;
	}

	if(kvCharacterConfig!=null)
		delete kvCharacterConfig;

	kvCharacterConfig=new KeyValues("");
	kvCharacterConfig.ImportFromFile(config);

	Action action;
	Call_StartForward(OnLoadCharacterSet);
	strcopy(charset, sizeof(charset), FF2CharSetString);
	Call_PushStringEx(charset, sizeof(charset), SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_Finish(action);
	if(action==Plugin_Changed)
	{
		if(strlen(charset))
		{
			int i;

			kvCharacterConfig.Rewind();
			while(kvCharacterConfig.GotoNextKey())
			{
				kvCharacterConfig.GetSectionName(config, sizeof(config));
				if(StrEqual(config, charset))
				{
					FF2CharSet=i;
					strcopy(FF2CharSetString, sizeof(FF2CharSetString), charset);
					break;
				}
				i++;
			}
		}
	}

	kvCharacterConfig.Rewind();
	kvCharacterConfig.JumpToKey(FF2CharSetString); // This *should* always return true

	if(kvCharacterConfig.GotoFirstSubKey(false))
	{
		int index;
		do
		{
			kvCharacterConfig.GetSectionName(config, sizeof(config));
			LoadCharacter(config);
			index++;
		}
		while(kvCharacterConfig.GotoNextKey(false));
	}
	else
	{
		LogError("[FF2 Bosses] Disabling Freak Fortress 2 - no bosses in character set %s!", FF2CharSetString);
		Enabled2=false;
		return;
	}

	if(FileExists("sound/saxton_hale/9000.wav", true))
	{
		AddFileToDownloadsTable("sound/saxton_hale/9000.wav");
		PrecacheSound("saxton_hale/9000.wav", true);
	}

	if(FileExists("sound/potry_v2/se/homerun_bat.wav", true))
	{
		AddFileToDownloadsTable("sound/potry_v2/se/homerun_bat.wav");
		PrecacheSound("potry_v2/se/homerun_bat.wav", true);
	}
	PrecacheSound("vo/announcer_am_capincite01.mp3", true);
	PrecacheSound("vo/announcer_am_capincite03.mp3", true);
	PrecacheSound("vo/announcer_am_capenabled01.mp3", true);
	PrecacheSound("vo/announcer_am_capenabled02.mp3", true);
	PrecacheSound("vo/announcer_am_capenabled03.mp3", true);
	PrecacheSound("vo/announcer_am_capenabled04.mp3", true);
	PrecacheSound("weapons/barret_arm_zap.wav", true);
	PrecacheSound("vo/announcer_ends_5min.mp3", true);
	PrecacheSound("vo/announcer_ends_2min.mp3", true);
	PrecacheSound("player/doubledonk.wav", true);
	isCharSetSelected=false;
}

public void LoadCharacter(const char[] characterName)
{
	char config[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, config, sizeof(config), "%s/%s.cfg", FF2_CONFIGS, characterName);
	if(!FileExists(config))
	{
		LogError("[FF2 Bosses] Character %s does not exist!", characterName);
		return;
	}

	KeyValues kv=new KeyValues("character");
	bossesArray.Push(kv);
	kv.ImportFromFile(config);

	kv=new KeyValues("character");
	bossesArrayOriginal.Push(kv);
	kv.ImportFromFile(config);

	int version=kv.GetNum("version", 1);
	// if(version!=StringToInt(MAJOR_REVISION))
	if(version<=1)
	{
		LogError("[FF2 Bosses] Character %s is only compatible with FF2 v%i!", characterName, version);
		return;
	}

	if(kv.JumpToKey("abilities"))
	{
		if(kv.GotoFirstSubKey())
		{
			char pluginName[64];
			do
			{
				kv.GetSectionName(pluginName, sizeof(pluginName));
				if(FindStringInArray(subpluginArray, pluginName)<0)
				{
					LogError("[FF2 Bosses] Character %s needs plugin %s!", characterName, pluginName);
					return;
				}
			}
			while(kv.GotoNextKey());
		}
	}
	kv.Rewind();

	char file[PLATFORM_MAX_PATH], filePath[PLATFORM_MAX_PATH];
	char extensions[][]={".mdl", ".dx80.vtx", ".dx90.vtx", ".sw.vtx", ".vvd"};
	kv.SetString("filename", characterName);
	kv.GetString("name", config, sizeof(config));

	if(kv.JumpToKey("sounds"))
	{
		kv.GotoFirstSubKey();

		do
		{
			kv.GetSectionName(file, sizeof(file));
			Format(filePath, sizeof(filePath), "sound/%s", file);

			if(FileExists(filePath, true))
			{
				// LogMessage("Precache ''%s''\n = %s", filePath, PrecacheSound(file) ? "YES" : "NO");
				PrecacheSound(file); // PrecacheSound is relative to the sounds/ folder
			}
			else
			{
				LogError("[FF2 Bosses] Character %s is missing file '%s'!", characterName, filePath);
			}

			if(kv.GetNum("download", 0)>0)
			{
				if(FileExists(filePath, true))
				{
					// LogMessage("Add to Download ''%s''", filePath);
					AddFileToDownloadsTable(filePath); // ...but AddLateDownload isn't
				}
				else
				{
					LogError("[FF2 Bosses] Character %s is missing file '%s'!", characterName, filePath);
				}
			}
		}
		while(kv.GotoNextKey());
	}

	kv.Rewind();
	if(kv.JumpToKey("downloads"))
	{
		kv.GotoFirstSubKey();

		do
		{
			if(kv.GetNum("model"))
			{
				for(int extension; extension<sizeof(extensions); extension++)
				{
					kv.GetSectionName(file, sizeof(file));
					Format(file, sizeof(file), "%s%s", file, extensions[extension]);

					if(extension == 0) // .mdl
					{
						// LogMessage("Precache ''%s''\n = %s", file, PrecacheModel(file) != 0 ? "YES" : "NO");
						PrecacheModel(file);
					}

					if(FileExists(file, true))
					{
						AddFileToDownloadsTable(file);
					}
					else
					{
						LogError("[FF2 Bosses] Character %s is missing file '%s'!", character, file);
					}
				}

				if(kv.GetNum("phy"))
				{
					kv.GetSectionName(file, sizeof(file));
					Format(file, sizeof(file), "%s.phy", file);
					if(FileExists(file, true))
					{
						AddFileToDownloadsTable(file);
					}
					else
					{
						LogError("[FF2 Bosses] Character %s is missing file '%s'!", character, file);
					}
				}
			}
			else if(kv.GetNum("material"))
			{
				kv.GetSectionName(file, sizeof(file));
				Format(file, sizeof(file), "%s.vmt", file);
				if(FileExists(file, true))
				{
					AddFileToDownloadsTable(file);
				}
				else
				{
					LogError("[FF2 Bosses] Character %s is missing file '%s'!", character, file);
				}

				kv.GetSectionName(file, sizeof(file));
				Format(file, sizeof(file), "%s.vtf", file);
				if(FileExists(file, true))
				{
					if(kv.GetNum("precache") > 0)
					{
						// LogMessage("Precache ''%s''\n = %s", file, PrecacheModel(file) != 0 ? "YES" : "NO");
						PrecacheModel(file);
					}

					AddFileToDownloadsTable(file);
				}
				else
				{
					LogError("[FF2 Bosses] Character %s is missing file '%s'!", character, file);
				}
			}
			else if(FileExists(file, true))
			{
				kv.GetSectionName(file, sizeof(file));
				AddFileToDownloadsTable(file);
			}
			else
			{
				if(file[0] == '\0')	continue;
				LogError("[FF2 Bosses] Character %s is missing file '%s'!", character, file);
			}
		}
		while(kv.GotoNextKey());
	}
/*
	kv.Rewind();
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "data/ff2_dumps/%s.txt", characterName);
	OpenFile(path, "w");
	kv.ExportToFile(path);
*/
}

public bool PickCharacter(int boss, int companion)
{
	if(boss==companion)
	{
		ArrayList chancesArray = CreateChancesArray(Boss[boss]);
		character[boss]=Incoming[boss];
		Incoming[boss]=-1;
		if(character[boss]!=-1)  //We've already picked a boss through Command_SetNextBoss
		{
			Action action;
			Call_StartForward(OnBossSelected);
			Call_PushCell(boss);
			int newCharacter=character[boss];
			Call_PushCellRef(newCharacter);
			char newName[64];
			KeyValues kv = GetCharacterKV(character[boss]);
			kv.Rewind();
			kv.GetString("name", newName, sizeof(newName));
			Call_PushStringEx(newName, sizeof(newName), SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
			Call_PushCell(true);  //Preset
			Call_Finish(action);
			if(action==Plugin_Changed)
			{
				if(newName[0])
				{
					char characterName[64];
					int foundExactMatch=-1, foundPartialMatch=-1;
					for(int characterIndex; characterIndex < bossesArray.Length && (kv = GetCharacterKV(characterIndex)); characterIndex++)
					{
						kv.Rewind();
						kv.GetString("name", characterName, sizeof(characterName));
						if(StrEqual(newName, characterName, false))
						{
							foundExactMatch=characterIndex;
							break;  //If we find an exact match there's no reason to keep looping
						}
						else if(StrContains(newName, characterName, false)!=-1)
						{
							foundPartialMatch=characterIndex;
						}

						//Do the same thing as above here, but look at the filename instead of the boss name
						KvGetString(kv, "filename", characterName, sizeof(characterName));
						if(StrEqual(newName, characterName, false))
						{
							foundExactMatch=characterIndex;
							break;  //If we find an exact match there's no reason to keep looping
						}
						else if(StrContains(newName, characterName, false)!=-1)
						{
							foundPartialMatch=characterIndex;
						}
					}

					if(foundExactMatch!=-1)
					{
						character[boss]=foundExactMatch;
					}
					else if(foundPartialMatch!=-1)
					{
						character[boss]=foundPartialMatch;
					}
					else
					{
						return false;
					}
					return true;
				}
				character[boss]=newCharacter;
				return true;
			}
			return true;
		}

		character[boss]=chancesArray.Get(GetRandomInt(0, chancesArray.Length-1));
/*
		for(int tries; tries<100; tries++)
		{
			character[boss]=GetRandomInt(0, GetArraySize(chancesArray)-1);

			// TODO: It would be awesome if we didn't have to check for this.
			// Then we wouldn't need to wrap all of this in a for loop.
			// FindCharacters() doesn't deal with the individual boss KVs though...
			// And supplying 0 as the boss's chance won't load the character.
			KvRewind(GetArrayCell(bossesArray, character[boss]));
			if(KvGetNum(GetArrayCell(bossesArray, character[boss]), "hidden"))
			{
				character[boss]=-1;
				continue;
			}
			break;
		}
*/

		delete chancesArray;
	}
	else
	{
		KeyValues kv = GetCharacterKV(character[boss]);
		char bossName[64], companionName[64];

		kv.Rewind();
		kv.GetString("companion", companionName, sizeof(companionName), "=Failed companion name=");

		int characterIndex;
		while(characterIndex < bossesArray.Length)  //Loop through all the bosses to find the companion we're looking for
		{
			kv = GetCharacterKV(characterIndex);
			kv.Rewind();
			kv.GetString("name", bossName, sizeof(bossName), "=Failed name=");
			if(StrEqual(bossName, companionName, false))
			{
				character[companion]=characterIndex;
				break;
			}

			kv.GetString("filename", bossName, sizeof(bossName), "=Failed name=");
			if(StrEqual(bossName, companionName, false))
			{
				character[companion]=characterIndex;
				break;
			}
			characterIndex++;
		}

		if(characterIndex == bossesArray.Length)  //Companion not found
		{
			return false;
		}
	}

	//All of the following uses `companion` because it will always be the boss index we want
	Action action;
	Call_StartForward(OnBossSelected);
	Call_PushCell(companion);
	int newCharacter=character[companion];
	KeyValues kv = GetCharacterKV(newCharacter);

	Call_PushCellRef(newCharacter);
	char newName[64];
	kv.Rewind();
	kv.GetString("name", newName, sizeof(newName));
	Call_PushStringEx(newName, sizeof(newName), SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(false);  //Not preset
	Call_Finish(action);
	if(action==Plugin_Changed)
	{
		if(newName[0])
		{
			char characterName[64];
			int foundExactMatch=-1, foundPartialMatch=-1;
			for(int characterIndex;
				characterIndex < bossesArray.Length && (kv = GetCharacterKV(characterIndex)); characterIndex++)
			{
				kv.Rewind();
				kv.GetString("name", characterName, sizeof(characterName));
				if(StrEqual(newName, characterName, false))
				{
					foundExactMatch=characterIndex;
					break;  //If we find an exact match there's no reason to keep looping
				}
				else if(StrContains(newName, characterName, false)!=-1)
				{
					foundPartialMatch=characterIndex;
				}

				//Do the same thing as above here, but look at the filename instead of the boss name
				kv.GetString("filename", characterName, sizeof(characterName));
				if(StrEqual(newName, characterName, false))
				{
					foundExactMatch=characterIndex;
					break;  //If we find an exact match there's no reason to keep looping
				}
				else if(StrContains(newName, characterName, false)!=-1)
				{
					foundPartialMatch=characterIndex;
				}
			}

			if(foundExactMatch!=-1)
			{
				character[companion]=foundExactMatch;
			}
			else if(foundPartialMatch!=-1)
			{
				character[companion]=foundPartialMatch;
			}
			else
			{
				return false;
			}
			return true;
		}
		character[companion]=newCharacter;
		return true;
	}
	return true;
}

void FindCompanion(int boss, int players, bool[] omit)
{
	static int playersNeeded=3;
	char companionName[64];
	KeyValues kv = GetCharacterKV(character[boss]);
	kv.Rewind();
	kv.GetString("companion", companionName, sizeof(companionName));
	if(playersNeeded<players && strlen(companionName))  //Only continue if we have enough players and if the boss has a companion
	{
		int companion=RandomlySelectClient(false, omit);

		Boss[companion]=companion;  //Woo boss indexes!
		omit[companion]=true;
		if(PickCharacter(boss, companion))  //TODO: This is a bit misleading
		{
			playersNeeded++;
			FindCompanion(companion, players, omit);  //Make sure this companion doesn't have a companion of their own
		}
		else  //Can't find the companion's character, so just play without the companion
		{
			LogError("[FF2 Bosses] Could not find boss %s!", companionName);
			Boss[companion]=0;
			omit[companion]=false;
		}
	}
	playersNeeded=3;  //Reset the amount of players needed back to 3 after we're done
}
