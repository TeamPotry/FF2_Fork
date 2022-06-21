#if defined _ff2_stocks_included
 #endinput
#endif
#define _ff2_stocks_included

enum // PlayerAnimEvent_t
{
	PLAYERANIMEVENT_ATTACK_PRIMARY,
	PLAYERANIMEVENT_ATTACK_SECONDARY,
	PLAYERANIMEVENT_ATTACK_GRENADE,
	PLAYERANIMEVENT_RELOAD,
	PLAYERANIMEVENT_RELOAD_LOOP,
	PLAYERANIMEVENT_RELOAD_END,
	PLAYERANIMEVENT_JUMP,
	PLAYERANIMEVENT_SWIM,
	PLAYERANIMEVENT_DIE,
	PLAYERANIMEVENT_FLINCH_CHEST,
	PLAYERANIMEVENT_FLINCH_HEAD,
	PLAYERANIMEVENT_FLINCH_LEFTARM,
	PLAYERANIMEVENT_FLINCH_RIGHTARM,
	PLAYERANIMEVENT_FLINCH_LEFTLEG,
	PLAYERANIMEVENT_FLINCH_RIGHTLEG,
	PLAYERANIMEVENT_DOUBLEJUMP,

	// Cancel.
	PLAYERANIMEVENT_CANCEL,
	PLAYERANIMEVENT_SPAWN,

	// Snap to current yaw exactly
	PLAYERANIMEVENT_SNAP_YAW,

	PLAYERANIMEVENT_CUSTOM,				// Used to play specific activities
	PLAYERANIMEVENT_CUSTOM_GESTURE,
	PLAYERANIMEVENT_CUSTOM_SEQUENCE,	// Used to play specific sequences
	PLAYERANIMEVENT_CUSTOM_GESTURE_SEQUENCE,

	// TF Specific. Here until there's a derived game solution to this.
	PLAYERANIMEVENT_ATTACK_PRE,
	PLAYERANIMEVENT_ATTACK_POST,
	PLAYERANIMEVENT_GRENADE1_DRAW,
	PLAYERANIMEVENT_GRENADE2_DRAW,
	PLAYERANIMEVENT_GRENADE1_THROW,
	PLAYERANIMEVENT_GRENADE2_THROW,
	PLAYERANIMEVENT_VOICE_COMMAND_GESTURE,
	PLAYERANIMEVENT_DOUBLEJUMP_CROUCH,
	PLAYERANIMEVENT_STUN_BEGIN,
	PLAYERANIMEVENT_STUN_MIDDLE,
	PLAYERANIMEVENT_STUN_END,
	PLAYERANIMEVENT_PASSTIME_THROW_BEGIN,
	PLAYERANIMEVENT_PASSTIME_THROW_MIDDLE,
	PLAYERANIMEVENT_PASSTIME_THROW_END,
	PLAYERANIMEVENT_PASSTIME_THROW_CANCEL,

	PLAYERANIMEVENT_ATTACK_PRIMARY_SUPER,

	PLAYERANIMEVENT_COUNT
};

// NOTE: Precache on OnMapStart
stock void FF2_PrecacheEffect()
{
    PrecacheEffect("ParticleEffect");
}

stock int PlayAnimation(int entity, char[] anim, float stopDelay = -1.0, float killDelay = 0.0, bool following = false)
{
	SetEntityRenderMode(entity, RENDER_NONE);
	// SetEntityRenderColor(client, 255, 255, 255, 0);
	// SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 0);

	float vecOrigin[3], vecAngles[3];
    GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vecOrigin);
    GetEntPropVector(entity, Prop_Data, "m_angRotation", vecAngles);

	vecAngles[0] = 0.0;

	char modelPath[PLATFORM_MAX_PATH];
    GetEntPropString(entity, Prop_Data, "m_ModelName", modelPath, PLATFORM_MAX_PATH);

	int animationentity = CreateEntityByName("prop_dynamic_override");
	if(IsValidEntity(animationentity))
	{
// 		DispatchKeyValueVector(animationentity, "origin", vecOrigin);
// 		DispatchKeyValueVector(animationentity, "angles", vecAngles);
		DispatchKeyValue(animationentity, "model", modelPath);
		// DispatchKeyValue(animationentity, "defaultanim", anim);
		DispatchSpawn(animationentity);
        TeleportEntity(animationentity, vecOrigin, vecAngles, NULL_VECTOR);
		SetEntPropEnt(animationentity, Prop_Send, "m_hOwnerEntity", entity);

		if(GetEntProp(entity, Prop_Send, "m_iTeamNum") == 0)
			SetEntProp(animationentity, Prop_Send, "m_nSkin", GetEntProp(entity, Prop_Send, "m_nForcedSkin"));
		else
			SetEntProp(animationentity, Prop_Send, "m_nSkin", GetClientTeam(entity) - 2);

        char outputString[128];
        if(stopDelay > 0.0)
        {
            Format(outputString, sizeof(outputString), "OnAnimationBegun !self:SetPlaybackRate:0.0:%.1f:1", stopDelay);
            SetVariantString(outputString);
            AcceptEntityInput(animationentity, "AddOutput");
        }

        Format(outputString, sizeof(outputString), "OnAnimationDone !self:KillHierarchy::%.1f:1", killDelay);
		SetVariantString(outputString);
		AcceptEntityInput(animationentity, "AddOutput");

		HookSingleEntityOutput(animationentity, "OnAnimationDone", OnAnimationDone, true);

		if(following)
		{
			int link = CreateLink(entity);

			SetVariantString("!activator");
			AcceptEntityInput(animationentity, "SetParent", link);

			SetEntPropEnt(animationentity, Prop_Send, "m_hEffectEntity", link);
		}

        SetVariantString(anim);
        AcceptEntityInput(animationentity, "SetAnimation");

		return animationentity;
	}

	return -1;
}

public void OnAnimationDone(const char[] output, int caller, int activator, float delay)
{
    if(IsValidEntity(caller))
    {
        int owner = GetEntPropEnt(caller, Prop_Send, "m_hOwnerEntity");
        CreateTimer(delay + 2.8, Timer_EnableModel, owner, TIMER_FLAG_NO_MAPCHANGE); // 0.8?
    }
}

public Action Timer_EnableModel(Handle timer, int owner)
{
    SetEntityRenderMode(owner, RENDER_TRANSCOLOR);
    return Plugin_Continue;
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
// https://github.com/Source-Python-Dev-Team/Source.Python/blob/master/addons/source-python/data/source-python/effects/orangebox/tf/CTEPlayerAnimEvent.ini
// https://github.com/Chdata/TF2-Bumper-Cars/blob/ecc90ee4eb06fbdc70ca508dc2384f9c67dc5842/scripting/bumpercar.sp#L771
stock void TE_PlayerAnimEvent(int client, int event, int data = 0)
{
    TE_Start("PlayerAnimEvent");
	TE_WriteNum("m_iPlayerIndex", client);
	TE_WriteNum("m_iEvent", event);
	TE_WriteNum("m_nData", data);
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
