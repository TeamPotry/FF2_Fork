#if defined _ff2_stocks_included
 #endinput
#endif
#define _ff2_stocks_included

/*
// Unused for now.
stock void FF2_PrepareStocks()
{
	GameData gamedata = new GameData("potry");
	if (gamedata)
	{
	}
	else
	{
		SetFailState("Could not find potry gamedata");
	}
}
*/

stock void FF2_PlayAnimation(int client, const char[] anim, float duration = 0.0, float stopAt = 0.0)
{

	SetCommandFlags("mp_playanimation", GetCommandFlags("mp_playanimation") ^FCVAR_CHEAT);
	FakeClientCommand(client, "mp_playanimation %s", anim);
	SetCommandFlags("mp_playanimation", GetCommandFlags("mp_playanimation") | FCVAR_CHEAT);

	if(duration > 0.0)
		CreateTimer(duration, Timer_FF2AnimEnd, client, TIMER_FLAG_NO_MAPCHANGE);

	// FIXME: Not working
	if(stopAt > 0.0)
		CreateTimer(stopAt, Timer_FF2AnimStop, client, TIMER_FLAG_NO_MAPCHANGE);
}


// TODO: Replace this to Frame-dependent timer
// NOTE: Default Sourcemod Timer does not allow under 0.1s. and intarval follows server's tickrate.
public Action Timer_FF2AnimEnd(Handle timer, int client)
{
	if(!IsClientConnected(client) || !IsPlayerAlive(client))
		return Plugin_Continue;

	FF2_PlayAnimation(client, "0");
	
	SetEntProp(client, Prop_Send, "m_bIsPlayerSimulated", 1);
	SetEntProp(client, Prop_Send, "m_bSimulatedEveryTick", 1);
	SetEntProp(client, Prop_Send, "m_bAnimatedEveryTick", 1);
	// SetEntProp(client, Prop_Send, "m_bClientSideAnimation", 1);
	// SetEntProp(client, Prop_Send, "m_bClientSideFrameReset", 0);

	return Plugin_Continue;
}

public Action Timer_FF2AnimStop(Handle timer, int client)
{
	if(!IsClientConnected(client) || !IsPlayerAlive(client))
		return Plugin_Continue;

	// I wrote this on shulk's timestop ability. and it works at that time.
	// but i don't know why is this not working this time..
	SetEntProp(client, Prop_Send, "m_bIsPlayerSimulated", 0);
	SetEntProp(client, Prop_Send, "m_bSimulatedEveryTick", 0);
	SetEntProp(client, Prop_Send, "m_bAnimatedEveryTick", 0);
	// SetEntProp(client, Prop_Send, "m_bClientSideAnimation", 0);
	// SetEntProp(client, Prop_Send, "m_bClientSideFrameReset", 1);

	return Plugin_Continue;
}

// NOTE: Precache on OnMapStart
stock void FF2_PrecacheEffect()
{
    PrecacheEffect("ParticleEffect");
}

stock int CreateLink(int iClient)
{
	int link = CreateEntityByName("tf_taunt_prop");
	DispatchKeyValue(link, "targetname", "TauntProp");
	DispatchSpawn(link);

	SetEntityModel(link, "models/empty.mdl");

	SetEntProp(link, Prop_Send, "m_fEffects", 16|64);

	SetVariantString("!activator");
	AcceptEntityInput(link, "SetParent", iClient);

	return link;
}

/*
    https://github.com/xcalvinsz/zeustracerbullets/blob/master/addons/sourcemod/scripting/zeustracers.sp
    https://github.com/Source-Python-Dev-Team/Source.Python/blob/master/addons/source-python/data/source-python/effects/orangebox/CTEEffectDispatch.ini
*/
stock void TE_DispatchEffect(const char[] particle, const float pos[3], const float endpos[3], const float angles[3] = NULL_VECTOR, int parent = -1, int attachment = -1)
{
    TE_Start("EffectDispatch");
    TE_WriteVector("m_vStart[0]", pos);
    TE_WriteVector("m_vOrigin[0]", endpos);
    TE_WriteVector("m_vAngles", angles);
    TE_WriteNum("m_nHitBox", GetParticleEffectIndex(particle));
    TE_WriteNum("m_iEffectName", GetEffectIndex("ParticleEffect"));

    if(parent != -1)
    {
        TE_WriteNum("entindex", parent);
    }
    if(attachment != -1)
    {
        TE_WriteNum("m_nAttachmentIndex", attachment);
    }
}

stock void FF2_PrecacheParticleEffect(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;

	if (table == INVALID_STRING_TABLE)
		table = FindStringTable("ParticleEffectNames");

	bool save = LockStringTables(false);
	AddToStringTable(table, sEffectName);
	LockStringTables(save);
}

stock void PrecacheEffect(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;

	if (table == INVALID_STRING_TABLE)
		table = FindStringTable("EffectDispatch");

	bool save = LockStringTables(false);
	AddToStringTable(table, sEffectName);
	LockStringTables(save);
}

stock int GetEffectIndex(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;

	if (table == INVALID_STRING_TABLE)
		table = FindStringTable("EffectDispatch");

	int iIndex = FindStringIndex(table, sEffectName);

	if (iIndex != INVALID_STRING_INDEX)
		return iIndex;

	return 0;
}

stock int GetParticleEffectIndex(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;

	if (table == INVALID_STRING_TABLE)
		table = FindStringTable("ParticleEffectNames");

	int iIndex = FindStringIndex(table, sEffectName);

	if (iIndex != INVALID_STRING_INDEX)
		return iIndex;

	return 0;
}
