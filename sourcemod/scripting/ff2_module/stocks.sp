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

int FindCharacterIndexByName(char[] bossName)
{
    char name[64];
    int characterIndex=0;
    Handle characterKv;
    // TODO: 1.7 문법

    while(characterIndex<GetArraySize(bossesArray))  //Loop through all the bosses to find the companion we're looking for
    {
        characterKv = GetCharacterKV(characterIndex);
        KvRewind(characterKv);
        KvGetString(characterKv, "name", name, sizeof(name), "");
        if(StrEqual(bossName, name, false))
        {
            return characterIndex;
        }

        KvGetString(characterKv, "filename", name, sizeof(name), "");
        if(StrEqual(bossName, name, false))
        {
            return characterIndex;
        }
        characterIndex++;
    }

	return -1;
}

stock ArrayList CreateChancesArray(int client)
{
    char config[64], ruleName[80], value[120], companionName[64];
    int readIndex = 0, realIndex, tempChance, needPlayer = 1;
    ArrayList chancesArray = new ArrayList();
    KeyValues bossKv, companionKv;
    Action action;

    kvCharacterConfig.Rewind();
    kvCharacterConfig.JumpToKey(FF2CharSetString); // This *should* always return true

    if(kvCharacterConfig.GotoFirstSubKey(false))
    {
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

            bossKv.GetString("name", ruleName, sizeof(ruleName));
            bossKv.GetString("companion", companionName, sizeof(companionName));

            if(strlen(companionName))
            {
                companionKv = bossKv;
                while((companionKv = GetCharacterKV(FindCharacterIndexByName(companionName))) != null) {
                    companionKv.GetString("companion", companionName, sizeof(companionName));
                    needPlayer++;
                }

                int totalPlayer=0;
            	for(int target=1; target<=MaxClients; target++)
            	{
            		if(IsValidClient(target) && TF2_GetClientTeam(target)>TFTeam_Spectator)
            		{
            			totalPlayer++;
            		}
            	}

                if(totalPlayer <= needPlayer)
                    continue;
            }

            if(bossKv.GetNum("hidden", 0) > 0) continue;
            else if(bossKv.JumpToKey("require") && bossKv.JumpToKey("playable") && bossKv.GotoFirstSubKey(false))
            {
                do
                {
                    bossKv.GetSectionName(ruleName, sizeof(ruleName));

                    Call_StartForward(OnCheckRules);
                    Call_PushCell(client);
                    Call_PushCell(realIndex);
                    Call_PushCellRef(tempChance);
                    Call_PushStringEx(ruleName, sizeof(ruleName), SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
                    bossKv.GetString(NULL_STRING, value, 120);
                    Call_PushStringEx(value, sizeof(value), SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
                    Call_Finish(action);

                    if(action == Plugin_Stop || action == Plugin_Handled)
                    {
                        checked = false;
                        break;
                    }
                    else if(action == Plugin_Changed)
                    {
                        changed = true;
                    }
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

void FireBossTTextEvent(KeyValues characterKv, char[] id, int client = 0)
{
    int currentSpot;
    char bossFileName[68], messageId[80];

    characterKv.GetSectionSymbol(currentSpot);
    characterKv.Rewind();

    characterKv.GetString("tutorial_text_filename", bossFileName, sizeof(bossFileName));
    if(characterKv.JumpToKey("tutorial_text"))
    {
        characterKv.GetString(id, messageId, sizeof(messageId), "");
        if(messageId[0] == '\0')    return;

        if(client > 0)
        {
            FireHelpTTextEvent(client, bossFileName, messageId);
        }
        else
        {
            for(int target = 1; target < MaxClients; target++)
            {
                if(IsClientInGame(target) && IsPlayerAlive(target) && !IsBoss(target))
                    FireHelpTTextEvent(target, bossFileName, messageId);
            }
        }
    }

    characterKv.JumpToKeySymbol(currentSpot);
}

void FireHelpTTextEvent(int client, char[] bossFileName, char[] messageId)
{
    // CPrintToChatAll("%s, %s", bossFileName, messageId);
    TTextEvent event = null;
    float position[3];
    GetEntPropVector(client, Prop_Send, "m_vecOrigin", position);

    event = TTextEvent.InitTTextEvent();
    TT_LoadMessageID(event, bossFileName, messageId);
    event.SetPosition(position);

    event.ChangeTextLanguage(bossFileName, messageId, client);
    event.FireTutorialText(bossFileName, messageId, client);
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

stock Handle FindCookieEx(char[] cookieName)
{
    Handle cookieHandle = FindClientCookie(cookieName);
    if(cookieHandle == null)
    {
        cookieHandle = RegClientCookie(cookieName, "", CookieAccess_Protected);
    }

    return cookieHandle;
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
