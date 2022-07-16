#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>

#include <freak_fortress_2>
#include <ff2_modules/general>

#include <CBaseAnimatingOverlay>
#include <dhooks>

#pragma newdecls required

public Plugin myinfo=
{
	name="Freak Fortress 2: Freddy Krueger Abilities",
	author="Nopied◎",
	description="Welcome to Wonderland!",
	version="1.0",
};

#define THIS_PLUGIN_NAME        "krueger detail"

#define NOISE_REDUCE			"noise reduce"
#define PLAYER_HUD_NOISE		"player hud noise"
#define COPIED_DUMMY			"copied dummy"

Handle g_hMyNextBotPointer;
Handle g_hGetLocomotionInterface;
Handle g_hGetStepHeight;
Handle g_hStudioFrameAdvance;
Handle g_hAllocateLayer;
Handle g_hResetSequence;

bool g_bNoiseReduced;
float g_flHudNoiseTime;

public void OnPluginStart()
{
	HookEvent("arena_round_start", Event_RoundStart);
	HookEvent("teamplay_round_active", Event_RoundStart); // for non-arena maps

	HookEvent("arena_win_panel", Event_RoundEnd);
	HookEvent("teamplay_round_win", Event_RoundEnd); // for non-arena maps

	AddNormalSoundHook(SoundHook);
	FF2_RegisterSubplugin(THIS_PLUGIN_NAME);

	GameData gamedata = new GameData("potry");
    if (gamedata)
    {
        g_hStudioFrameAdvance = PrepSDKCall_StudioFrameAdvance(gamedata);
        g_hAllocateLayer = PrepSDKCall_AllocateLayer(gamedata);
        g_hResetSequence = PrepSDKCall_ResetSequence(gamedata);

        CreateDynamicDetour(gamedata, "CTFBaseBoss::GetCurrencyValue", DHookCallback_GetCurrencyValue_Pre);
        delete gamedata;
    }
    else
    {
        SetFailState("Could not find potry gamedata");
    }
}

public void FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status)
{
	if(StrEqual(abilityName, PLAYER_HUD_NOISE))
	{
		AddHudNoiseTime(boss);
	}
	if(StrEqual(abilityName, COPIED_DUMMY))
	{
		ActivateCopiedDummys(boss);
	}
}

void AddHudNoiseTime(int boss)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));
	float duration = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, PLAYER_HUD_NOISE, "duration", 12.0);
	g_flHudNoiseTime = GetGameTime() + duration;

	float inOut = duration / 4.0, fadeDuration = inOut * 2.0;

	for(int target = 1; target <= MaxClients; target++)
	{
		if(!IsClientInGame(target) || !IsPlayerAlive(target)
			|| GetClientTeam(client) == GetClientTeam(target))
				continue;

		FadeClientVolume(target, 80.0, inOut, fadeDuration, inOut);
	}
}

public Action SoundHook(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH],
	  int &entity, int &channel, float &volume, int &level, int &pitch, int &flags,
	  char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if(!g_bNoiseReduced || !IsValidClient(entity))
		return Plugin_Continue;

	// LogMessage("sample = %s, entity = %N, numClients = %d", sample, entity, numClients);

	float pos[3], targetpos[3];
	int newClients[MAXPLAYERS], newNumClients = 0;
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);

	for(int loop = 0; loop < numClients; loop++)
	{
		if(!IsValidClient(clients[loop]))		continue;
		GetEntPropVector(clients[loop], Prop_Send, "m_vecOrigin", targetpos);

		// LogMessage("clients[%d] = %N", loop, clients[loop]);

		if(GetVectorDistance(pos, targetpos) <= 800.0)
			newClients[newNumClients++] = clients[loop];
	}

	numClients = newNumClients;
	for(int loop = 0; loop < newNumClients; loop++)
		clients[loop] = newClients[loop];

	return Plugin_Changed;
}

void ActivateCopiedDummys(int boss)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss)),
		health = FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, COPIED_DUMMY, "dummy health", 1000);

	float bossPos[3], dummyPos[3], ang[3];

	GetClientEyePosition(client, bossPos);

	for(int target = 1; target <= MaxClients; target++)
	{
		if(!IsClientInGame(target) || !IsPlayerAlive(target)
			|| GetClientTeam(client) == GetClientTeam(target))
				continue;

		GetClientEyePosition(target, dummyPos);
        GetClientEyeAngles(target, ang);

        GetAngleVectors(ang, ang, NULL_VECTOR, NULL_VECTOR);
        ScaleVector(ang, 100.0);
        AddVectors(dummyPos, ang, dummyPos);

		SubtractVectors(dummyPos, bossPos, ang);
		GetVectorAngles(ang, ang);

		int dummy = CreateCopiedDummy(client, health);
		TeleportEntity(dummy, dummyPos, ang, NULL_VECTOR);
	}
}

public void FF2_OnCalledQueue(FF2HudQueue hudQueue, int client)
{
	if(g_flHudNoiseTime < GetGameTime() || !IsPlayerAlive(client))	return;

	char text[60];
	FF2HudDisplay hudDisplay = null;
	hudQueue.GetName(text, sizeof(text));

	if(StrEqual(text, "Player") || StrEqual(text, "Player Medic"))
	{
		hudQueue.DeleteAllDisplay();
		for(int loop = 0; loop < 60; loop++)
		{
			text[loop] = GetRandomInt(0, 65533);
			// 특수 문자 삭제
			if(text[loop] == '%')
				text[loop] = 'p';
		}

		hudDisplay = FF2HudDisplay.CreateDisplay("dummy", text);
		hudQueue.PushDisplay(hudDisplay);
	}
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_flHudNoiseTime = -1.0;
	g_bNoiseReduced = false;

	int boss;
	for(int client = 1; client <= MaxClients; client++)
	{
		boss = FF2_GetBossIndex(client);
		if(boss == -1)	continue;

		if(FF2_HasAbility(boss, THIS_PLUGIN_NAME, NOISE_REDUCE))
			g_bNoiseReduced = true;
	}
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_flHudNoiseTime = -1.0;
	g_bNoiseReduced = false;
}

stock bool IsValidClient(int client)
{
	return (0 < client && client <= MaxClients && IsClientInGame(client));
}

int CreateCopiedDummy(int client, int health)
{
	float vecMins[3], vecMaxs[3];

    GetEntPropVector(client, Prop_Data, "m_vecMins", vecMins);
    GetEntPropVector(client, Prop_Data, "m_vecMaxs", vecMaxs);

    char strModel[PLATFORM_MAX_PATH], temp[24];
    GetEntPropString(client, Prop_Data, "m_ModelName", strModel, PLATFORM_MAX_PATH);

    int npc = CreateEntityByName("base_boss");
    DispatchKeyValue(npc, "model", strModel);
    DispatchKeyValue(npc, "modelscale", "1.0");
    DispatchKeyValue(npc, "speed", "0.0");

	IntToString(health, temp, sizeof(temp));
    DispatchKeyValue(npc, "health", temp);
    DispatchSpawn(npc);

    SetEntPropVector(npc, Prop_Data, "m_vecMins", vecMins);
    SetEntPropVector(npc, Prop_Data, "m_vecMaxs", vecMaxs);

    // FIXME: 중력이 계속 적용됨.
    // 별도의 특수한 MOVETYPE가 있는 것으로 추정

    int item = CreateEntityByName("prop_dynamic");
    DispatchKeyValue(item, "model", strModel);
    DispatchSpawn(item);

    SetEntProp(item, Prop_Send, "m_nSkin", GetEntProp(client, Prop_Send, "m_nSkin"));
    SetEntProp(item, Prop_Send, "m_hOwnerEntity", npc);
    SetEntProp(item, Prop_Send, "m_fEffects", (1 << 0)|(1 << 9));

    SetEntPropVector(item, Prop_Data, "m_vecMins", vecMins);
    SetEntPropVector(item, Prop_Data, "m_vecMaxs", vecMaxs);

    SetVariantString("!activator");
    AcceptEntityInput(item, "SetParent", npc);

    SetVariantString("head");
    AcceptEntityInput(item, "SetParentAttachmentMaintainOffset");

    SetEntityGravity(npc, 0.0);
    SetEntityMoveType(npc, MOVETYPE_NONE);
    SetEntityRenderMode(npc, RENDER_NONE);

    SetEntityGravity(item, 0.0);
    SetEntityMoveType(item, MOVETYPE_NONE);

    SetEntProp(npc, Prop_Data, "m_bloodColor", -1); //Don't bleed
    SetEntProp(npc, Prop_Send, "m_nSkin", GetEntProp(client, Prop_Send, "m_nSkin")); //Don't bleed
    SetEntPropEnt(npc, Prop_Data, "m_hOwnerEntity", client);
    SetEntData(npc, FindSendPropInfo("CTFBaseBoss", "m_lastHealthPercentage") + 28, false, 4, true); //ResolvePlayerCollisions
    SetEntProp(npc, Prop_Send, "m_nSkin", GetEntProp(client, Prop_Send, "m_nSkin"));
    SetEntProp(npc, Prop_Send, "m_fEffects", (1 << 0)|(1 << 9));

    // 애니메이션 값 복사
    // Allocate 15 layers for max copycat
    for (int i = 0; i <= 12; i++)
    	SDKCall(g_hAllocateLayer, npc, 0);

    SDKCall(g_hResetSequence, npc, GetEntProp(client, Prop_Send, "m_nSequence"));

    CBaseAnimatingOverlay overlayP = CBaseAnimatingOverlay(client);
    CBaseAnimatingOverlay overlay = CBaseAnimatingOverlay(npc);

    for (int i = 0; i <= 12; i++)
    {
        CAnimationLayer layerP = overlayP.GetLayer(i);
        CAnimationLayer layer = overlay.GetLayer(i);

        if(!(layerP.IsActive()))
        	continue;

        layer.Set(m_fFlags, 			layerP.Get(m_fFlags));
        layer.Set(m_bSequenceFinished, 	layerP.Get(m_bSequenceFinished));
        layer.Set(m_bLooping,			layerP.Get(m_bLooping));
        layer.Set(m_nSequence,			layerP.Get(m_nSequence));
        layer.Set(m_flCycle,			layerP.Get(m_flCycle));
        layer.Set(m_flPrevCycle,		layerP.Get(m_flPrevCycle));
        // layer.Set(m_flWeight,			0.0);
        layer.Set(m_flWeight,			layerP.Get(m_flWeight));
        layer.Set(m_flPlaybackRate,		layerP.Get(m_flPlaybackRate));
        layer.Set(m_flBlendIn,			layerP.Get(m_flBlendIn));
        layer.Set(m_flBlendOut,			layerP.Get(m_flBlendOut));
        layer.Set(m_flKillRate, 		0.0);
        layer.Set(m_flKillDelay, 		50000000000.0);
        layer.Set(m_flLayerAnimtime, 	layerP.Get(m_flLayerAnimtime));
        layer.Set(m_flLayerFadeOuttime, layerP.Get(m_flLayerFadeOuttime));
        layer.Set(m_nActivity,			layerP.Get(m_nActivity));
        layer.Set(m_nPriority,			layerP.Get(m_nPriority));
        layer.Set(m_nOrder, 			layerP.Get(m_nOrder));
    }

    for (int i = 0; i < 24; i++)
    {
    	float flValue = GetEntPropFloat(client, Prop_Send, "m_flPoseParameter", i);
    	SetEntPropFloat(npc, Prop_Send, "m_flPoseParameter", flValue, i);
    }

    //Done
    SetEntityRenderMode(npc, RENDER_NORMAL);

    //Play anims a bit so they get played to their set values
    SDKCall(g_hStudioFrameAdvance, npc);
	return npc;
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

public MRESReturn DHookCallback_GetCurrencyValue_Pre(int ent, DHookReturn ret)
{
    // PrintToChatAll("%.1f", ret.Value);
    ret.Value = 0;
    return MRES_Supercede;
}

Handle PrepSDKCall_MyNextBotPointer(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CBaseEntity::MyNextBotPointer");
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);

	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDK call: CBaseEntity::MyNextBotPointer");

	return call;
}

int SDKCall_MyNextBotPointer(int ent)
{
    if(g_hMyNextBotPointer)
        SDKCall(g_hMyNextBotPointer, ent);

    return -1;
}

Handle PrepSDKCall_GetLocomotionInterface(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "INextBot::GetLocomotionInterface");
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);

	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDK call: INextBot::GetLocomotionInterface");

	return call;
}

any SDKCall_GetLocomotionInterface(int address)
{
    if(g_hGetLocomotionInterface)
        SDKCall(g_hGetLocomotionInterface, address);

    return -1;
}

Handle PrepSDKCall_StudioFrameAdvance(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CBaseAnimating::StudioFrameAdvance");

	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDK call: CBaseAnimating::StudioFrameAdvance");

	return call;
}

int SDKCall_StudioFrameAdvance(int ent)
{
	if (g_hAllocateLayer)
		return SDKCall(g_hAllocateLayer, ent);

	return -1;
}

Handle PrepSDKCall_AllocateLayer(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CBaseAnimatingOverlay::AllocateLayer");
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	//priority
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain); //return iOpenLayer

	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDK call: CBaseAnimatingOverlay::AllocateLayer");

	return call;
}

int SDKCall_AllocateLayer(int ent, int priority)
{
	if (g_hAllocateLayer)
		return SDKCall(g_hAllocateLayer, ent, priority);

	return -1;
}

Handle PrepSDKCall_ResetSequence(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CBaseAnimating::ResetSequence");
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // nSequence

	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDK call: CBaseAnimating::ResetSequence");

	return call;
}

int SDKCall_ResetSequence(int ent, int nSequence)
{
	if (g_hResetSequence)
		return SDKCall(g_hResetSequence, ent, nSequence);

	return -1;
}
