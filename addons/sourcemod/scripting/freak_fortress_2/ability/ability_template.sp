#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>

#include <freak_fortress_2>
#include <ff2_modules/general>

#define PLUGIN_NAME 	    "PLUGIN NAME HERE"
#define PLUGIN_AUTHOR       ""
#define PLUGIN_DESCRIPTION  ""
#define PLUGIN_VERSION 	    ""

#define PLUGININFO_NAME 	    "Freak Fortress 2: ability name here"
public Plugin myinfo=
{
	name=PLUGININFO_NAME,
	author=PLUGIN_AUTHOR,
	description=PLUGIN_DESCRIPTION,
	version=PLUGIN_VERSION,
};

#define FOREACH_PLAYER(%1) for(int %1 = 1; %1 <= MaxClients; %1++)

#define SOME_ABILITY_NAME        ""

public void OnPluginStart()
{
    // LoadTranslations("ff2_extra_abilities.phrases");

    // HookEvent("arena_round_start", OnRoundStart);
    // HookEvent("teamplay_round_active", OnRoundStart); // for non-arena maps

    // HookEvent("teamplay_round_win", OnRoundEnd);

    // HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);

    FF2_RegisterSubplugin(PLUGIN_NAME);
}

public void OnMapStart()
{
	// FF2_PrecacheEffect();
	// FF2_PrecacheParticleEffect("bullet_pistol_tracer01_blue_crit");

    return;
}

public void FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status)
{
    if(!StrEqual(PLUGIN_NAME, pluginName))
        return;

    int client = GetClientOfUserId(FF2_GetBossUserId(boss));

    if(StrEqual(SOME_ABILITY_NAME, abilityName))
    {
        return;
    }
}

// public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
// {

// }

// public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
// {
   
// }

// public void OnPlayerDeath(Event event, const char[] eventName, bool dontBroadcast)
// {
//     // int client = GetClientOfUserId(event.GetInt("userid"));
//     int attacker = GetClientOfUserId(event.GetInt("attacker"));

//     if((event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER) > 0)
//         return;
// }
