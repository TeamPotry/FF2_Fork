public void GetHudSettingString(HudSettingValue value, char[] statusString, int buffer)
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
