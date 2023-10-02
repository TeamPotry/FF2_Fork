/*
	"ff2r_playanimation"
	{
		"intro_playanimation"
		{
			"activity"	"ACT_TRANSITION"					// If type is 1, sequence name or activity name. type is 2, activity name.
			"type"		"2"									// 1 - Force Sequence 2 - Play Gesture
		}

		"rage_playanimation"
		{
			"slot"		"0"									// Ability Slot
			"activity"	"ACT_MP_GESTURE_VC_HANDMOUTH_ITEM1" // If type is 1, sequence name or activity name. type is 2, activity name.
			"type"		"2"									// 1 - Force Sequence 2 - Play Gesture
		}
	}
	
*/

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <freak_fortress_2>
#include <ff2_modules/general>

static Handle g_SDKCallPlaySpecificSequence;
static Handle g_SDKCallPlayGesture;

public Plugin myinfo = {
	name = "[FF2R] Play Animation",
	author = "Sandy (Forked by Nopied◎)",
	description = "Let them dance",
	version = "1.0.0",
	url = ""
};

#define THIS_PLUGIN_NAME "ff2r_playanimation"

#define INTRO_ANIMATION_NAME	"intro_playanimation"
#define RAGE_ANIMATION_NAME		"rage_playanimation"

public void OnPluginStart() {
	GameData data = new GameData("PlayAnimation");
	if (data == null) {
		SetFailState("Missing PlayAnimation");
	}
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(data, SDKConf_Signature, "CTFPlayer::PlaySpecificSequence");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_SDKCallPlaySpecificSequence = EndPrepSDKCall();
	if (!g_SDKCallPlaySpecificSequence)
		SetFailState("Failed to create call: CTFPlayer::PlaySpecificSequence");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(data, SDKConf_Signature, "CTFPlayer::PlayGesture");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_SDKCallPlayGesture = EndPrepSDKCall();
	if (!g_SDKCallPlayGesture)
		SetFailState("Failed to create call: CTFPlayer::PlayGesture");
	
	delete data;

	FF2_RegisterSubplugin(THIS_PLUGIN_NAME);
}

public void FF2_OnPlayBoss(int boss) {
	if(!FF2_HasAbility(boss, THIS_PLUGIN_NAME, INTRO_ANIMATION_NAME))
		return;

	int client = GetClientOfUserId(FF2_GetBossUserId(boss));

	char animation[PLATFORM_MAX_PATH];
	FF2_GetAbilityArgumentString(boss, THIS_PLUGIN_NAME, INTRO_ANIMATION_NAME, "activity", animation, PLATFORM_MAX_PATH);

	int type = FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, INTRO_ANIMATION_NAME, "type", 2);
	SetAnimation(client, animation, type);
}

public void FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status) {
	if(!StrEqual(THIS_PLUGIN_NAME, pluginName)
		|| !StrEqual(RAGE_ANIMATION_NAME, abilityName))
		return;

	int client = GetClientOfUserId(FF2_GetBossUserId(boss));
	
	char animation[PLATFORM_MAX_PATH];
	FF2_GetAbilityArgumentString(boss, THIS_PLUGIN_NAME, RAGE_ANIMATION_NAME, "activity", animation, PLATFORM_MAX_PATH);
	
	int type = FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, RAGE_ANIMATION_NAME, "type", 2);
	SetAnimation(client, animation, type);	
}

static void SetAnimation(int client, const char[] animation, int animationType) {
	switch(animationType) {
		case 1: {
			SDKCall(g_SDKCallPlaySpecificSequence, client, animation);
		}
		case 2: {
			SDKCall(g_SDKCallPlayGesture, client, animation);
		}
	}
}