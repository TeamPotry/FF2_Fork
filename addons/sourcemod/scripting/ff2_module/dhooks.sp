void DHooks_Init(GameData gamedata)
{
    if (gamedata == null)
    {
        SetFailState("Could not find potry gamedata");
        return;
    }

    CreateDynamicDetour(gamedata, "CTFWeaponBaseMelee::OnEntityHit", _, DHookCallback_OnEntityHit_Post);
}

static void CreateDynamicDetour(GameData gamedata, const char[] name, DHookCallback callbackPre = INVALID_FUNCTION, DHookCallback callbackPost = INVALID_FUNCTION)
{
	DynamicDetour detour = DynamicDetour.FromConf(gamedata, name);
	if (detour)
	{
		if (callbackPre != INVALID_FUNCTION)
			detour.Enable(Hook_Pre, callbackPre);

		if (callbackPost != INVALID_FUNCTION)
			detour.Enable(Hook_Post, callbackPost);
	}
	else
	{
		LogError("Failed to create detour setup handle for %s", name);
	}
}

public MRESReturn DHookCallback_OnEntityHit_Post(int weapon, DHookParam params)
{
    int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
    int ent = params.Get(1);

    if(!IsBoss(owner) && IsValidClient(ent))
    {
        // PrintToChatAll("owner: %d, ent: %d, speed_buff_ally: %d", owner, ent, TF2Attrib_HookValueInt(0, "speed_buff_ally", owner));
        if(TF2_GetClientTeam(owner) == TF2_GetClientTeam(ent))
        {
            if(TF2Attrib_HookValueInt(0, "speed_buff_ally", owner) > 0 && TF2_IsPlayerInCondition(ent, TFCond_Dazed))
            {
                TF2Util_SetPlayerConditionDuration(ent, TFCond_Dazed,
                    TF2Util_GetPlayerConditionDuration(ent, TFCond_Dazed) - 2.0);
            }
        }
    }

    return MRES_Ignored;
}
