#include <sourcemod>
#include <tf2_stocks>
#include <freak_fortress_2>

#define THIS_PLUGIN_NAME    "ff2_ragemodel"

public Plugin:myinfo = {
	name = "Freak Fortress 2: Rage Model",
	author = "frog",
	version = "2.0 (Forked by Nopied)"
};

public void OnPluginStart()
{
	// HookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	// HookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_PostNoCopy);

	FF2_RegisterSubplugin(THIS_PLUGIN_NAME);
}

public void FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status)
{
    if (!strcmp(abilityName,"rage_model"))
        Rage_Model(abilityName, boss);	//change model on rage
    else if (!strcmp(abilityName,"life_model"))
        Life_Model(abilityName, boss);	//change model on life lost
}

void Rage_Model(const char[] abilityName, int boss)
{
    char rageModel[PLATFORM_MAX_PATH];
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));
	float duration = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, abilityName, "duration");	//duration

	FF2_GetAbilityArgumentString(boss, THIS_PLUGIN_NAME, abilityName, "rage model", rageModel, PLATFORM_MAX_PATH);	//rage model
	ChangeBossModel(rageModel, client);

	CreateTimer(view_as<float>(duration), RestoreModel, boss, TIMER_FLAG_NO_MAPCHANGE);
}

void Life_Model(const char[] abilityName, int boss)
{
    char model[PLATFORM_MAX_PATH];
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));

    Format(model, PLATFORM_MAX_PATH, "life %i model", FF2_GetBossLives(boss));
    FF2_GetAbilityArgumentString(boss, THIS_PLUGIN_NAME, abilityName, "", model, PLATFORM_MAX_PATH);	//normal model

	ChangeBossModel(model, client);
}

public Action RestoreModel(Handle timer, int boss)
{
    int client = GetClientOfUserId(FF2_GetBossUserId(boss));
    if(client <= 0 || !IsClientInGame(client) || !IsPlayerAlive(client)) return Plugin_Continue;

    char normalModel[PLATFORM_MAX_PATH];
	FF2_GetAbilityArgumentString(boss, THIS_PLUGIN_NAME, "rage_model", "normal model", normalModel, PLATFORM_MAX_PATH);	//normal model

    ChangeBossModel(normalModel, client);

    return Plugin_Continue;
}

public void ChangeBossModel(const char[] model, int client)
{
	SetVariantString(model);
	AcceptEntityInput(client, "SetCustomModel");
	SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
}
