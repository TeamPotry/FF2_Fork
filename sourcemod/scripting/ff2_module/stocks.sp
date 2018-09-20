public void GetHudSettingString(HudSettingValue value, char[] statusString, int buffer)
{
    if(value <= HudSetting_View)
        Format(statusString, buffer, "VIEW");
    else if(value == HudSetting_ViewAble)
        Format(statusString, buffer, "PUBLIC");
    else if(value == HudSetting_ViewDisable)
        Format(statusString, buffer, "PRIVATE");
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
