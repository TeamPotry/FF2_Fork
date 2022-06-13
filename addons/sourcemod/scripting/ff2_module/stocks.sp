public void GetHudSettingString(int value, char[] statusString, int buffer)
{
    switch(value)
    {
      case HudSetting_None:
      {
          Format(statusString, buffer, "NONE");
      }
      case HudSetting_View:
      {
          Format(statusString, buffer, "VIEW");
      }
      case HudSetting_ViewAble:
      {
          Format(statusString, buffer, "PUBLIC");
      }
      case HudSetting_ViewDisable:
      {
          Format(statusString, buffer, "PRIVATE");
      }
    }
}

stock ArrayList CreateChancesArray(int client)
{
    char config[64], ruleName[80], tempRuleName[80], value[120];
    ArrayList chancesArray = new ArrayList();
    KeyValues bossKv;
    Action action;
    bool multipleCheck;

    kvCharacterConfig.Rewind();
    kvCharacterConfig.JumpToKey(FF2CharSetString); // This *should* always return true

    if(kvCharacterConfig.GotoFirstSubKey(false))
    {
        int readIndex = 0, realIndex, tempChance;
        do
        {
            bool checked = true, changed = false;
            kvCharacterConfig.GetSectionName(config, sizeof(config));
            int chance = kvCharacterConfig.GetNum(NULL_STRING, -1);
            bossKv = GetCharacterKV(readIndex);

            tempChance = chance;
            realIndex = readIndex;
            readIndex++;

            // LogMessage("%d - Readed %s's config. chance = %d", readIndex, config, chance);

            if(kvCharacterConfig.GetDataType(NULL_STRING) == KvData_None || chance < 0 || bossKv == null)
            {
                LogError("[FF2 Bosses] Character %s has an invalid chance (%d) - assuming 0", config, chance);
                continue;
            }

            bossKv.Rewind();
            if(bossKv.GetNum("hidden", 0) > 0) continue;
            else if(bossKv.JumpToKey("require") && bossKv.JumpToKey("playable") && bossKv.GotoFirstSubKey(false))
            {
                do
                {
                    bossKv.GetSectionName(ruleName, sizeof(ruleName));

                    if(StrEqual(ruleName, "multiple") && bossKv.GotoFirstSubKey())
                    {
                        do
                        {
                            multipleCheck = false;
                            if(bossKv.GotoFirstSubKey(false))
                            {
                                do
                                {
                                    bossKv.GetSectionName(tempRuleName, sizeof(tempRuleName));

                                    Call_StartForward(OnCheckRules);
                                    Call_PushCell(client);
                                    Call_PushCell(realIndex);
                                    Call_PushCellRef(tempChance);
                                    Call_PushStringEx(tempRuleName, sizeof(tempRuleName), SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
                                    bossKv.GetString(NULL_STRING, value, 120);
                                    Call_PushStringEx(value, sizeof(value), SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
                                    Call_Finish(action);

                                    multipleCheck = action == Plugin_Stop || action == Plugin_Handled ? false : true;
                                    if(!multipleCheck) break;

                                    changed = action == Plugin_Changed;
                                }
                                while(bossKv.GotoNextKey(false));
                                bossKv.GoBack();
                            }
                        }
                        while(bossKv.GotoNextKey());
                        bossKv.GoBack();
                    }
                    else
                    {
                        Call_StartForward(OnCheckRules);
                        Call_PushCell(client);
                        Call_PushCell(realIndex);
                        Call_PushCellRef(tempChance);
                        Call_PushStringEx(ruleName, sizeof(ruleName), SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
                        bossKv.GetString(NULL_STRING, value, 120);
                        Call_PushStringEx(value, sizeof(value), SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
                        Call_Finish(action);
                    }

                    checked = action == Plugin_Stop || action == Plugin_Handled ? false : true;
                    if(!checked && !multipleCheck) continue;

                    changed = action == Plugin_Changed;
                }
                while(bossKv.GotoNextKey(false));
            }

            if(checked)
            {
                int count = changed ? tempChance : chance;
                for(int j; j < count; j++)
                {
                    chancesArray.Push(realIndex);
                    // LogMessage("added %s's index = %d", config, count);
                }
            }
        }
        while(kvCharacterConfig.GotoNextKey(false));
    }

    return chancesArray;
}

public bool GetWeaponHint(int client, int weapon, char[] text, int buffer)
{
    int index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
    char classname[32], temp[8], languageId[4];

    GetLanguageInfo(GetClientLanguage(client), languageId, sizeof(languageId));
    GetEntityClassname(weapon, classname, sizeof(classname));
    IntToString(index, temp, sizeof(temp));

    kvWeaponMods.Rewind();

    if(kvWeaponMods.JumpToKey(temp) || kvWeaponMods.JumpToKey(classname))
    {
        if(kvWeaponMods.JumpToKey("hint_text"))
        {
            kvWeaponMods.GetString(languageId, text, buffer, "Empty.");
            return true;
        }
    }

    return false;
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

public void ReAddPercentCharacter(char[] str, int buffer, int percentImplodeCount)
{
    char implode[32];
    for(int loop = 0; loop < percentImplodeCount; loop++)
        implode[loop] = '%';

    ReplaceString(str, buffer, "%", implode);
}

stock Handle FindCookieEx(char[] cookieName)
{
    Handle cookieHandle = FindClientCookie(cookieName);
    if(cookieHandle == null)
    {
        cookieHandle = RegClientCookie(cookieName, "", CookieAccess_Protected);
    }

    return cookieHandle;
}

stock int FindEntityByClassname2(int startEnt, const char[] classname)
{
	while(startEnt>-1 && !IsValidEntity(startEnt))
	{
		startEnt--;
	}
	return FindEntityByClassname(startEnt, classname);
}

stock void PlayShieldBreakSound(int client, float position[3], float volume = 0.7)
{
	// EmitSoundToClient(client, "player/spy_shield_break.wav", _, _, _, _, 0.7, _, _, position, _, false);
	// EmitSoundToClient(attacker, "player/spy_shield_break.wav", _, _, _, _, 0.7, _, _, position, _, false);
	// EmitSoundToClient(attacker, "player/spy_shield_break.wav", _, _, _, _, 0.7, _, _, position, _, false);
    for(int target = 1; target <= MaxClients; target++)
    {
        if(IsClientInGame(target))
            EmitSoundToClient(target, "player/spy_shield_break.wav", _, _, _, _, volume, _, _, position, _, false);
    }
}

stock float fmax(float x, float y)
{
	return x < y ? y : x;
}

stock float fmin(float x, float y)
{
	return x > y ? y : x;
}

stock void DoOverlay(int client, const char[] overlay)
{
	int flags=GetCommandFlags("r_screenoverlay");
	SetCommandFlags("r_screenoverlay", flags & ~FCVAR_CHEAT);
	ClientCommand(client, "r_screenoverlay \"%s\"", overlay);
	SetCommandFlags("r_screenoverlay", flags);
}

void ForceTeamWin(TFTeam team)
{
	int entity=FindEntityByClassname2(-1, "team_control_point_master");
	if(!IsValidEntity(entity))
	{
		entity=CreateEntityByName("team_control_point_master");
		DispatchSpawn(entity);
		AcceptEntityInput(entity, "Enable");
	}
	SetVariantInt(view_as<int>(team));
	AcceptEntityInput(entity, "SetWinner");
}

stock void GetClientCloakIndex(int client)
{
	if(!IsValidClient(client, false))
	{
		return -1;
	}

	int weapon=GetPlayerWeaponSlot(client, 4);
	if(!IsValidEntity(weapon))
	{
		return -1;
	}

	char classname[64];
	GetEntityClassname(weapon, classname, sizeof(classname));
	if(strncmp(classname, "tf_wea", 6, false))
	{
		return -1;
	}
	return GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
}

stock void SpawnSmallHealthPackAt(int client, TFTeam team)
{
	if(!IsValidClient(client, false) || !IsPlayerAlive(client))
	{
		return;
	}

	int healthpack=CreateEntityByName("item_healthkit_small");
	float position[3];
	GetClientAbsOrigin(client, position);
	position[2]+=20.0;
	if(IsValidEntity(healthpack))
	{
		DispatchKeyValue(healthpack, "OnPlayerTouch", "!self,Kill,,0,-1");
		DispatchSpawn(healthpack);
		SetEntProp(healthpack, Prop_Send, "m_iTeamNum", view_as<int>(team), 4);
		SetEntityMoveType(healthpack, MOVETYPE_VPHYSICS);
		float velocity[3];//={float(GetRandomInt(-10, 10)), float(GetRandomInt(-10, 10)), 50.0};  //Q_Q
		velocity[0]=float(GetRandomInt(-10, 10)), velocity[1]=float(GetRandomInt(-10, 10)), velocity[2]=50.0;  //I did this because setting it on the creation of the vel variable was creating a compiler error for me.
		TeleportEntity(healthpack, position, NULL_VECTOR, velocity);
	}
}

stock void IncrementHeadCount(int client)
{
	if(!TF2_IsPlayerInCondition(client, TFCond_DemoBuff))
	{
		TF2_AddCondition(client, TFCond_DemoBuff, -1.0);
	}

	int decapitations=GetEntProp(client, Prop_Send, "m_iDecapitations");
	int health=GetClientHealth(client);
	SetEntProp(client, Prop_Send, "m_iDecapitations", decapitations+1);
	SetEntityHealth(client, health+15);
	TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.01);
}

stock int FindTeleOwner(int client)
{
	if(!IsValidClient(client) || !IsPlayerAlive(client))
	{
		return -1;
	}

	int teleporter=GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
	char classname[32];
	if(IsValidEntity(teleporter) && GetEntityClassname(teleporter, classname, sizeof(classname)) && StrEqual(classname, "obj_teleporter", false))
	{
		int owner=GetEntPropEnt(teleporter, Prop_Send, "m_hBuilder");
		if(IsValidClient(owner, false))
		{
			return owner;
		}
	}
	return -1;
}

stock int GetIndexOfWeaponSlot(int client, int slot)
{
	int weapon=GetPlayerWeaponSlot(client, slot);
	return (weapon>MaxClients && IsValidEntity(weapon) ? GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") : -1);
}

stock bool TF2_IsPlayerCritBuffed(int client)
{
	return (TF2_IsPlayerInCondition(client, TFCond_Kritzkrieged) || TF2_IsPlayerInCondition(client, TFCond_HalloweenCritCandy) || TF2_IsPlayerInCondition(client, view_as<TFCond>(34)) || TF2_IsPlayerInCondition(client, view_as<TFCond>(35)) || TF2_IsPlayerInCondition(client, TFCond_CritOnFirstBlood) || TF2_IsPlayerInCondition(client, TFCond_CritOnWin) || TF2_IsPlayerInCondition(client, TFCond_CritOnFlagCapture) || TF2_IsPlayerInCondition(client, TFCond_CritOnKill) || TF2_IsPlayerInCondition(client, TFCond_CritMmmph));
}

stock int FindSentry(int client)
{
	int entity=-1;
	while((entity=FindEntityByClassname2(entity, "obj_sentrygun"))!=-1)
	{
		if(GetEntPropEnt(entity, Prop_Send, "m_hBuilder")==client)
		{
			return entity;
		}
	}
	return -1;
}

stock int FindPlayerBack(int client, int index)
{
	int entity=MaxClients+1;
	while((entity=FindEntityByClassname2(entity, "tf_wearable*"))!=-1)
	{
		char netclass[32];
		if(GetEntityNetClass(entity, netclass, sizeof(netclass)) && StrContains(netclass, "CTFWearable")!=-1 && GetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex")==index && GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")==client && !GetEntProp(entity, Prop_Send, "m_bDisguiseWearable"))
		{
			return entity;
		}
	}
	return -1;
}

stock void RemovePlayerBack(int client, int[] indices, int length)
{
	if(length<=0)
	{
		return;
	}

	int entity=MaxClients+1;
	while((entity=FindEntityByClassname2(entity, "tf_wearable"))!=-1)
	{
		char netclass[32];
		if(GetEntityNetClass(entity, netclass, sizeof(netclass)) && StrEqual(netclass, "CTFWearable"))
		{
			int index=GetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex");
			if(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")==client && !GetEntProp(entity, Prop_Send, "m_bDisguiseWearable"))
			{
				for(int i; i<length; i++)
				{
					if(index==indices[i])
					{
						TF2_RemoveWearable(client, entity);
					}
				}
			}
		}
	}
}

stock void RemovePlayerTarge(int client)
{
	int entity=MaxClients+1;
	while((entity=FindEntityByClassname2(entity, "tf_wearable_demoshield"))!=-1)
	{
		int index=GetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex");
		if(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")==client && !GetEntProp(entity, Prop_Send, "m_bDisguiseWearable"))
		{
			if(index==131 || index==406 || index==1099 || index==1144)  //Chargin' Targe, Splendid Screen, Tide Turner, Festive Chargin' Targe
			{
				TF2_RemoveWearable(client, entity);
			}
		}
	}
}

stock bool MapHasMusic(bool forceRecalc=false)  //SAAAAAARGE
{
	static bool hasMusic;
	static bool found;
	if(forceRecalc)
	{
		found=false;
		hasMusic=false;
	}

	if(!found)
	{
		int entity=-1;
		char name[64];
		while((entity=FindEntityByClassname2(entity, "info_target"))!=-1)
		{
			GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name));
			if(StrEqual(name, "hale_no_music", false))
			{
				hasMusic=true;
			}
		}
		found=true;
	}
	return hasMusic;
}

stock void SetControlPoint(bool enable)
{
	int controlPoint=MaxClients+1;
	while((controlPoint=FindEntityByClassname2(controlPoint, "team_control_point"))!=-1)
	{
		if(controlPoint>MaxClients && IsValidEntity(controlPoint))
		{
			AcceptEntityInput(controlPoint, (enable ? "ShowModel" : "HideModel"));
			SetVariantInt(enable ? 0 : 1);
			AcceptEntityInput(controlPoint, "SetLocked");
		}
	}
}

stock void SetArenaCapTime(int time)
{
    int controlPoint=MaxClients+1;
    char temp[8];
    IntToString(time, temp, 8);

    while((controlPoint=FindEntityByClassname2(controlPoint, "trigger_capture_area"))!=-1)
    {
        if(controlPoint>MaxClients && IsValidEntity(controlPoint))
        {
            DispatchKeyValue(controlPoint, "area_time_to_cap", temp);
        }
    }
}

stock void SetArenaCapEnableTime(float time)
{
	int entity=-1;
	if((entity=FindEntityByClassname2(-1, "tf_logic_arena"))!=-1 && IsValidEntity(entity))
	{
		char timeString[32];
		FloatToString(time, timeString, sizeof(timeString));
		DispatchKeyValue(entity, "CapEnableDelay", timeString);
	}
}

stock void RandomlyDisguise(int client)	//Original code was mecha's, but the original code is broken and this uses a better method now.
{
	if(IsValidClient(client) && IsPlayerAlive(client))
	{
		int disguiseTarget=-1;
		TFTeam team=TF2_GetClientTeam(client);

		ArrayList disguiseArray=CreateArray();
		for(int clientcheck; clientcheck<=MaxClients; clientcheck++)
		{
			if(IsValidClient(clientcheck) && TF2_GetClientTeam(clientcheck)==team && clientcheck!=client)
			{
				disguiseArray.Push(clientcheck);
			}
		}

		if(disguiseArray.Length<=0)
		{
			disguiseTarget=client;
		}
		else
		{
			disguiseTarget=disguiseArray.Get(GetRandomInt(0, disguiseArray.Length-1));
			if(!IsValidClient(disguiseTarget))
			{
				disguiseTarget=client;
			}
		}

		int playerclass=GetRandomInt(0, 4);
		TFClassType classArray[]={TFClass_Scout, TFClass_Pyro, TFClass_Medic, TFClass_Engineer, TFClass_Sniper};
		delete disguiseArray;

		if(TF2_GetPlayerClass(client)==TFClass_Spy)
		{
			TF2_DisguisePlayer(client, team, classArray[playerclass], disguiseTarget);
		}
		else
		{
			TF2_AddCondition(client, TFCond_Disguised, -1.0);
			SetEntProp(client, Prop_Send, "m_nDisguiseTeam", view_as<int>(team));
			SetEntProp(client, Prop_Send, "m_nDisguiseClass", classArray[playerclass]);
			SetEntProp(client, Prop_Send, "m_iDisguiseTargetIndex", disguiseTarget);
			SetEntProp(client, Prop_Send, "m_iDisguiseHealth", 200);
		}
	}
}

float GetMeleeDamage(int weapon, TFClassType class = TFClass_Unknown)
{
    // FIXME: Yeah. a Hardcoded stuff.
    // Change g_MeleeDamage to In-game function that can get actual damage.
    // NOTE: ANNND this only multiplies mult_dmg for now.
    static float g_MeleeDamage = 65.0;
    static float g_WeakMeleeDamage = 35.0;

    float damage = (class == TFClass_Scout || class == TFClass_Spy) ? g_WeakMeleeDamage
        : g_MeleeDamage;

    float multiplier = TF2Attrib_HookValueFloat(1.0, "mult_dmg", weapon);
    return damage * multiplier * 1.13793; // THIS 1.13793 I DO NOT KNOW
}

/**
 * From https://github.com/nosoop/stocksoup/blob/master/tf/econ.inc
 * Creates a wearable DemoShield entity.
 *
 * Wearables spawned via this method and equipped on human players are not visible to other
 * human players due to economy rules.  You're on your own there.
 *
 * If defindex is set to DEFINDEX_UNDEFINED, the item is not initialized, and no quality or
 * level is applied.
 *
 * @param defindex		Wearable definition index.
 * @param quality		Wearable quality.
 * @param level			Wearable level.
 */
stock int TF2_SpawnDemoShield(int defindex = DEFINDEX_UNDEFINED, int quality = 6, int level = 1) {
	int wearable = CreateEntityByName("tf_wearable_demoshield");

	if (IsValidEntity(wearable)) {
		SetEntProp(wearable, Prop_Send, "m_iItemDefinitionIndex", defindex);

		if (defindex != DEFINDEX_UNDEFINED) {
			// using defindex of a valid item
			SetEntProp(wearable, Prop_Send, "m_bInitialized", 1);

			SetEntProp(wearable, Prop_Send, "m_iEntityLevel", level);

			// Something about m_iEntityQuality doesn't play nice with SetEntProp.
			SetEntData(wearable, FindSendPropInfo("CTFWearable", "m_iEntityQuality"), quality);
		}

		// Spawn.
		DispatchSpawn(wearable);
	}
	return wearable;
}

/*
 * Equips a new weapon for a given client
 *
 * @param client		Client to equip new weapon for
 * @param classname		Classname of the weapon
 * @param index			Index of the weapon
 * @param level			Level of the weapon
 * @param quality		Quality of the weapon
 * @param attributeList	String of attributes in a 'name ; value' pattern (optional)
 *
 * @return				Weapon entity index on success, -1 on failure
 */
stock int SpawnWeapon(int client, char[] classname, int index, int level=1, int quality=0, char[] attributeList="")
{
	Handle weapon=TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	if(weapon==null)
	{
		return -1;
	}

	TF2Items_SetClassname(weapon, classname);
	TF2Items_SetItemIndex(weapon, index);
	TF2Items_SetLevel(weapon, level);
	TF2Items_SetQuality(weapon, quality);
	char attributes[32][32];
	int count=ExplodeString(attributeList, ";", attributes, 32, 32);

	if(count==1) // ExplodeString returns the original string if no matching delimiter was found so we need to special-case this
	{
		if(attributeList[0]!='\0') // Ignore empty attribute list
		{
			LogError("[FF2 Weapons] Unbalanced attributes array '%s' for weapon %s", attributeList, classname);
			delete weapon;
			return -1;
		}
		else
		{
			TF2Items_SetNumAttributes(weapon, 0);
		}
	}
	else if(count % 2) // Unbalanced array, eg "2 ; 10 ; 3"
	{
		LogError("[FF2 Weapons] Unbalanced attributes array '%s' for weapon %s", attributeList, classname);
		delete weapon;
		return -1;
	}
	else
	{
		TF2Items_SetNumAttributes(weapon, count/2);
		int i2;
		for(int i; i<count; i+=2)
		{
			int attribute=StringToInt(attributes[i]);
			if(!attribute)
			{
				LogError("[FF2 Weapons] Bad weapon attribute passed: %s ; %s", attributes[i], attributes[i+1]);
				delete weapon;
				return -1;
			}

			TF2Items_SetAttribute(weapon, i2, attribute, StringToFloat(attributes[i+1]));
			i2++;
		}
	}

	int entity=TF2Items_GiveNamedItem(client, weapon);
	delete weapon;
	EquipPlayerWeapon(client, entity);
	return entity;
}

stock bool IsValidClient(int client, bool replaycheck=true)
{
	if(client<=0 || client>MaxClients)
	{
		return false;
	}

	if(!IsClientInGame(client))
	{
		return false;
	}

	if(GetEntProp(client, Prop_Send, "m_bIsCoaching"))
	{
		return false;
	}

	if(replaycheck)
	{
		if(IsClientSourceTV(client) || IsClientReplay(client))
		{
			return false;
		}
	}
	return true;
}

stock bool IsBoss(int client)
{
	if(IsValidClient(client))
	{
		for(int boss; boss<=MaxClients; boss++)
		{
			if(Boss[boss]==client)
			{
				return true;
			}
		}
	}
	return false;
}

// md5 stocks by sslice, Thomas "Thomasjosif" Dick, OBEK Technologies Inc.
stock void MD5_String(char[] str, char[] output, int maxlen)
{
    int placeholder[64];

    Handle md5 = MD5Init();
    MD5Update(md5, strlen(str), str, placeholder);
    MD5Final(md5, output, maxlen);
    delete md5;
}

stock Handle MD5Init()
{
    int x[2];
    int buf[4];
    int input[64];
    int update[16];

    // MD5Init
    x[0] = x[1] = 0;
    buf[0] = 0x67452301;
    buf[1] = 0xefcdab89;
    buf[2] = 0x98badcfe;
    buf[3] = 0x10325476;

    StringMap map = CreateTrie();
    map.SetArray("x", x, 2);
    map.SetArray("buf", buf, 4);
    map.SetArray("input", input, 64);
    map.SetArray("update", update, 16);
    return view_as<Handle>(map);
}

stock void MD5Update(Handle maph, int len, char[] str, int[] inputfromfile)
{
    StringMap map = view_as<StringMap>(maph);
    // MD5Update
    int x[2]; map.GetArray("x", x, 2);
    int buf[4]; map.GetArray("buf", buf, 4);
    int input[64]; map.GetArray("input", input, 64);
    int update[16]; map.GetArray("update", update, 16);
    int i, ii;

    update[14] = x[0];
    update[15] = x[1];

    int mdi = (x[0] >>> 3) & 0x3F;

    if ((x[0] + (len << 3)) < x[0]) {
        x[1] += 1;
    }

    x[0] += len << 3;
    x[1] += len >>> 29;

    int c = 0;
    while (len--) {
        if(StrEqual(str, ""))
            input[mdi] = inputfromfile[c];
        else
            input[mdi] = str[c];
        mdi += 1;
        c += 1;

        if (mdi == 0x40) {

            for (i = 0, ii = 0; i < 16; ++i, ii += 4)
            {
                update[i] = (input[ii + 3] << 24) | (input[ii + 2] << 16) | (input[ii + 1] << 8) | input[ii];
            }

            // Transform
            MD5Transform(buf, update);

            mdi = 0;
        }
    }

    map.SetArray("x", x, 2);
    map.SetArray("buf", buf, 4);
    map.SetArray("input", input, 64);
    map.SetArray("update", update, 16);
}

stock void MD5Final(Handle maph, char[] md5, int maxlen)
{
    StringMap map = view_as<StringMap>(maph);
    // MD5Final
    int x[2]; map.GetArray("x", x, 2);
    int buf[4]; map.GetArray("buf", buf, 4);
    int input[64]; map.GetArray("input", input, 64);
    int update[16]; map.GetArray("update", update, 16);
    int i, ii;

    int padding[64] = {
        0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    };

    int inx[16];
    inx[14] = x[0];
    inx[15] = x[1];

    int mdi = (x[0] >>> 3) & 0x3F;

    int len = (mdi < 56) ? (56 - mdi) : (120 - mdi);
    update[14] = x[0];
    update[15] = x[1];

    mdi = (x[0] >>> 3) & 0x3F;

    if ((x[0] + (len << 3)) < x[0]) {
        x[1] += 1;
    }

    x[0] += len << 3;
    x[1] += len >>> 29;

    int c = 0;
    while (len--) {
        input[mdi] = padding[c];
        mdi += 1;
        c += 1;

        if (mdi == 0x40) {

            for (i = 0, ii = 0; i < 16; ++i, ii += 4) {
                update[i] = (input[ii + 3] << 24) | (input[ii + 2] << 16) | (input[ii + 1] << 8) | input[ii];

            }

            // Transform
            MD5Transform(buf, update);

            mdi = 0;
        }
    }

    for (i = 0, ii = 0; i < 14; ++i, ii += 4) {
        inx[i] = (input[ii + 3] << 24) | (input[ii + 2] << 16) | (input[ii + 1] << 8) | input[ii];
    }

    MD5Transform(buf, inx);

    int digest[16];
    for (i = 0, ii = 0; i < 4; ++i, ii += 4) {
        digest[ii] = (buf[i]) & 0xFF;
        digest[ii + 1] = (buf[i] >>> 8) & 0xFF;
        digest[ii + 2] = (buf[i] >>> 16) & 0xFF;
        digest[ii + 3] = (buf[i] >>> 24) & 0xFF;
    }

    FormatEx(md5, maxlen, "%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
        digest[0], digest[1], digest[2], digest[3], digest[4], digest[5], digest[6], digest[7],
        digest[8], digest[9], digest[10], digest[11], digest[12], digest[13], digest[14], digest[15]);
}

static stock void MD5Transform_FF(int &a, int &b, int &c, int &d, int x, int s, int ac)
    {
    a += (((b) & (c)) | ((~b) & (d))) + x + ac;
    a = (((a) << (s)) | ((a) >>> (32-(s))));
    a += b;
}

static stock void MD5Transform_GG(int &a, int &b, int &c, int &d, int x, int s, int ac)
    {
    a += (((b) & (d)) | ((c) & (~d))) + x + ac;
    a = (((a) << (s)) | ((a) >>> (32-(s))));
    a += b;
}

static stock void MD5Transform_HH(int &a, int &b, int &c, int &d, int x, int s, int ac)
    {
    a += ((b) ^ (c) ^ (d)) + x + ac;
    a = (((a) << (s)) | ((a) >>> (32-(s))));
    a += b;
}

static stock void MD5Transform_II(int &a, int &b, int &c, int &d, int x, int s, int ac)
{
    a += ((c) ^ ((b) | (~d))) + x + ac;
    a = (((a) << (s)) | ((a) >>> (32-(s))));
    a += b;
}

static stock void MD5Transform(int[] buf, int[] input){
    int a = buf[0];
    int b = buf[1];
    int c = buf[2];
    int d = buf[3];

    MD5Transform_FF(a, b, c, d, input[0], 7, 0xd76aa478);
    MD5Transform_FF(d, a, b, c, input[1], 12, 0xe8c7b756);
    MD5Transform_FF(c, d, a, b, input[2], 17, 0x242070db);
    MD5Transform_FF(b, c, d, a, input[3], 22, 0xc1bdceee);
    MD5Transform_FF(a, b, c, d, input[4], 7, 0xf57c0faf);
    MD5Transform_FF(d, a, b, c, input[5], 12, 0x4787c62a);
    MD5Transform_FF(c, d, a, b, input[6], 17, 0xa8304613);
    MD5Transform_FF(b, c, d, a, input[7], 22, 0xfd469501);
    MD5Transform_FF(a, b, c, d, input[8], 7, 0x698098d8);
    MD5Transform_FF(d, a, b, c, input[9], 12, 0x8b44f7af);
    MD5Transform_FF(c, d, a, b, input[10], 17, 0xffff5bb1);
    MD5Transform_FF(b, c, d, a, input[11], 22, 0x895cd7be);
    MD5Transform_FF(a, b, c, d, input[12], 7, 0x6b901122);
    MD5Transform_FF(d, a, b, c, input[13], 12, 0xfd987193);
    MD5Transform_FF(c, d, a, b, input[14], 17, 0xa679438e);
    MD5Transform_FF(b, c, d, a, input[15], 22, 0x49b40821);

    MD5Transform_GG(a, b, c, d, input[1], 5, 0xf61e2562);
    MD5Transform_GG(d, a, b, c, input[6], 9, 0xc040b340);
    MD5Transform_GG(c, d, a, b, input[11], 14, 0x265e5a51);
    MD5Transform_GG(b, c, d, a, input[0], 20, 0xe9b6c7aa);
    MD5Transform_GG(a, b, c, d, input[5], 5, 0xd62f105d);
    MD5Transform_GG(d, a, b, c, input[10], 9, 0x02441453);
    MD5Transform_GG(c, d, a, b, input[15], 14, 0xd8a1e681);
    MD5Transform_GG(b, c, d, a, input[4], 20, 0xe7d3fbc8);
    MD5Transform_GG(a, b, c, d, input[9], 5, 0x21e1cde6);
    MD5Transform_GG(d, a, b, c, input[14], 9, 0xc33707d6);
    MD5Transform_GG(c, d, a, b, input[3], 14, 0xf4d50d87);
    MD5Transform_GG(b, c, d, a, input[8], 20, 0x455a14ed);
    MD5Transform_GG(a, b, c, d, input[13], 5, 0xa9e3e905);
    MD5Transform_GG(d, a, b, c, input[2], 9, 0xfcefa3f8);
    MD5Transform_GG(c, d, a, b, input[7], 14, 0x676f02d9);
    MD5Transform_GG(b, c, d, a, input[12], 20, 0x8d2a4c8a);

    MD5Transform_HH(a, b, c, d, input[5], 4, 0xfffa3942);
    MD5Transform_HH(d, a, b, c, input[8], 11, 0x8771f681);
    MD5Transform_HH(c, d, a, b, input[11], 16, 0x6d9d6122);
    MD5Transform_HH(b, c, d, a, input[14], 23, 0xfde5380c);
    MD5Transform_HH(a, b, c, d, input[1], 4, 0xa4beea44);
    MD5Transform_HH(d, a, b, c, input[4], 11, 0x4bdecfa9);
    MD5Transform_HH(c, d, a, b, input[7], 16, 0xf6bb4b60);
    MD5Transform_HH(b, c, d, a, input[10], 23, 0xbebfbc70);
    MD5Transform_HH(a, b, c, d, input[13], 4, 0x289b7ec6);
    MD5Transform_HH(d, a, b, c, input[0], 11, 0xeaa127fa);
    MD5Transform_HH(c, d, a, b, input[3], 16, 0xd4ef3085);
    MD5Transform_HH(b, c, d, a, input[6], 23, 0x04881d05);
    MD5Transform_HH(a, b, c, d, input[9], 4, 0xd9d4d039);
    MD5Transform_HH(d, a, b, c, input[12], 11, 0xe6db99e5);
    MD5Transform_HH(c, d, a, b, input[15], 16, 0x1fa27cf8);
    MD5Transform_HH(b, c, d, a, input[2], 23, 0xc4ac5665);

    MD5Transform_II(a, b, c, d, input[0], 6, 0xf4292244);
    MD5Transform_II(d, a, b, c, input[7], 10, 0x432aff97);
    MD5Transform_II(c, d, a, b, input[14], 15, 0xab9423a7);
    MD5Transform_II(b, c, d, a, input[5], 21, 0xfc93a039);
    MD5Transform_II(a, b, c, d, input[12], 6, 0x655b59c3);
    MD5Transform_II(d, a, b, c, input[3], 10, 0x8f0ccc92);
    MD5Transform_II(c, d, a, b, input[10], 15, 0xffeff47d);
    MD5Transform_II(b, c, d, a, input[1], 21, 0x85845dd1);
    MD5Transform_II(a, b, c, d, input[8], 6, 0x6fa87e4f);
    MD5Transform_II(d, a, b, c, input[15], 10, 0xfe2ce6e0);
    MD5Transform_II(c, d, a, b, input[6], 15, 0xa3014314);
    MD5Transform_II(b, c, d, a, input[13], 21, 0x4e0811a1);
    MD5Transform_II(a, b, c, d, input[4], 6, 0xf7537e82);
    MD5Transform_II(d, a, b, c, input[11], 10, 0xbd3af235);
    MD5Transform_II(c, d, a, b, input[2], 15, 0x2ad7d2bb);
    MD5Transform_II(b, c, d, a, input[9], 21, 0xeb86d391);

    buf[0] += a;
    buf[1] += b;
    buf[2] += c;
    buf[3] += d;
}
