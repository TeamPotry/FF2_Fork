bool HitOnSmack = false;

void DHooks_Init(GameData gamedata)
{
    if (gamedata == null)
    {
        SetFailState("Could not find potry gamedata");
        return;
    }

    CreateDynamicDetour(gamedata, "CTFLunchBox::DrainAmmo", DHookCallback_DrainAmmo_Pre);
    CreateDynamicDetour(gamedata, "CTFWeaponBaseMelee::OnEntityHit", _, DHookCallback_OnEntityHit_Post);
    CreateDynamicDetour(gamedata, "CTFWeaponBaseMelee::Smack", DHookCallback_Smack_Pre, DHookCallback_Smack_Post);
    CreateDynamicDetour(gamedata, "CTFPlayer::CanPlayerMove", DHookCallback_CanPlayerMove_Pre);
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

public MRESReturn DHookCallback_DrainAmmo_Pre(int weapon, DHookParam params)
{
    params.Set(1, true);
    return MRES_ChangedOverride;
}

public MRESReturn DHookCallback_OnEntityHit_Post(int weapon, DHookParam params)
{
    int iOwner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
    int ent = params.Get(1);

    if(!IsBoss(iOwner) && IsValidClient(ent))
    {
        // PrintToChatAll("iOwner: %d, ent: %d, speed_buff_ally: %d", iOwner, ent, TF2Attrib_HookValueInt(0, "speed_buff_ally", iOwner));
        if(TF2_GetClientTeam(iOwner) == TF2_GetClientTeam(ent))
        {
            if(TF2_IsPlayerInCondition(ent, TFCond_Dazed))
            {
                bool buffed = TF2Attrib_HookValueInt(0, "speed_buff_ally", iOwner) > 0;
                TF2_RemoveCondition(ent, TFCond_Dazed);
/*
                // TODO: configurable
                TF2Util_SetPlayerConditionDuration(ent, TFCond_Dazed,
                    TF2Util_GetPlayerConditionDuration(ent, TFCond_Dazed) - (buffed ? 4.0 : 2.0));
*/
                FF2BaseEntity owner = g_hBasePlayer[iOwner];
                owner.Assist += buffed ? 400 : 200;
            }
        }
    }

    return MRES_Ignored;
}

public MRESReturn DHookCallback_Smack_Pre(int weapon)
{
    HitOnSmack = false;
    return MRES_Ignored;
}

public MRESReturn DHookCallback_Smack_Post(int weapon)
{
    if(HitOnSmack)      return MRES_Ignored;
    int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
    int boss = -1;

    // PrintToChatAll("weapon = %d, owner = %d", weapon, owner);
    if(IsValidClient(owner) && (boss = GetBossIndex(owner)) != -1)
        OnBossSmackMiss(owner, boss, weapon);
    
    return MRES_Ignored;
}

public MRESReturn DHookCallback_CanPlayerMove_Pre(int client, DHookReturn hReturn)
{
    if(CheckRoundState() < FF2RoundState_RoundRunning
        && BossTeam == TF2_GetClientTeam(client))
    {
        hReturn.Value = false;
        return MRES_Supercede;
    }


    return MRES_Ignored;
}
