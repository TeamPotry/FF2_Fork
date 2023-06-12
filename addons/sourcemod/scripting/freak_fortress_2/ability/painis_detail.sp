#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>

#include <freak_fortress_2>
#include <ff2_modules/general>

#define PLUGIN_NAME 	"painis detail"
#define PLUGIN_VERSION 	"20230507"

public Plugin myinfo=
{
	name="Freak Fortress 2: Painis Abilities",
	author="Nopied◎",
	description="FF2?",
	version=PLUGIN_VERSION,
};

#define PAINIS_RAGE_NAME        "painis combo rage on kill"

float g_flPainisRageDuration[MAXPLAYERS+1];

public void OnPluginStart()
{
    // LoadTranslations("ff2_extra_abilities.phrases");

    HookEvent("arena_round_start", OnRoundStart);
    HookEvent("teamplay_round_active", OnRoundStart); // for non-arena maps

    HookEvent("teamplay_round_win", OnRoundEnd);

    HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);

    FF2_RegisterSubplugin(PLUGIN_NAME);
}

public void FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status)
{
    int client = GetClientOfUserId(FF2_GetBossUserId(boss));

    if(StrEqual(PAINIS_RAGE_NAME, abilityName))
    {
        float duration = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, PAINIS_RAGE_NAME, "duration", 10.0);
        g_flPainisRageDuration[client] = GetGameTime() + duration;
    }
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for(int client = 1; client <= MaxClients; client++)
	{
		g_flPainisRageDuration[client] = 0.0;
	}
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    // Rage sound stop on round end
    char sound[PLATFORM_MAX_PATH];

    for(int client = 1; client <= MaxClients; client++)
    {
        int boss;
        if(!IsClientInGame(client) || (boss = FF2_GetBossIndex(client)) == -1)
            continue;

        if(!FF2_HasAbility(boss, PLUGIN_NAME, PAINIS_RAGE_NAME))
            continue;
        
        FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, PAINIS_RAGE_NAME, "sound path", sound, PLATFORM_MAX_PATH, "");
        if(sound[0] != '\0')
            StopRageSound(sound);
    }
}

public void OnPlayerDeath(Event event, const char[] eventName, bool dontBroadcast)
{
    // int client = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));

    if((event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER) > 0)
        return;

    int boss = FF2_GetBossIndex(attacker);
    if(FF2_HasAbility(boss, PLUGIN_NAME, PAINIS_RAGE_NAME)
    && g_flPainisRageDuration[attacker] > GetGameTime())
    {
        char sound[PLATFORM_MAX_PATH];
        FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, PAINIS_RAGE_NAME, "sound path", sound, PLATFORM_MAX_PATH, "");
        if(sound[0] != '\0')
            PlayRageSound(attacker, sound);

        int slot = FF2_GetAbilityArgument(boss, PLUGIN_NAME, PAINIS_RAGE_NAME, "use ability of slot", -3);
        if(slot != -3)
            UseAbilityOfSlot(boss, slot);

        bool reset = FF2_GetAbilityArgument(boss, PLUGIN_NAME, PAINIS_RAGE_NAME, "reset duration") > 0;
        if(reset)
        {
            float duration = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, PAINIS_RAGE_NAME, "duration", 10.0);
            g_flPainisRageDuration[attacker] = GetGameTime() + duration;

            // TODO: not only SkillType_200Rage
            FF2_SetBossSkillDuration(boss, SkillType_200Rage, duration);
        }
    }
}

void PlayRageSound(int speaker, const char[] sound)
{
    if(g_flPainisRageDuration[speaker] > GetGameTime())
    {
        for(int target = 1; target <= MaxClients; target++)
    	{
    		if(IsClientInGame(target))
            {
                StopSound(target, 0, sound);
                StopSound(target, 0, sound);
            }
    	}
    }

    if(FF2_GetRoundState() == 1)
        EmitSoundToAll(sound, speaker, 0, 140, 0, 1.0);
}

void StopRageSound(const char[] sound)
{
    for(int target = 1; target <= MaxClients; target++)
    {
        if(IsClientInGame(target))
        {
            StopSound(target, 0, sound);
            StopSound(target, 0, sound);
        }
    }
}

void UseAbilityOfSlot(int boss, int targetSlot)
{
    char pluginName[64], abilityName[64];

    KeyValues kv = FF2_GetBossKV(boss);
    kv.Rewind();

    if(kv.JumpToKey("abilities"))
    {
        KeyValues abilityKv = new KeyValues("abilities");
        abilityKv.Import(kv);

        abilityKv.GotoFirstSubKey();
        do
        {
            abilityKv.GetSectionName(pluginName, sizeof(pluginName));

            abilityKv.GotoFirstSubKey();
            do
            {
                abilityKv.GetSectionName(abilityName, sizeof(abilityName));
                int slot = abilityKv.GetNum("slot", 0);

                if(slot == targetSlot)
                {
                    PrintToServer("pluginName: %s, abilityName: %s", pluginName, abilityName);
                    FF2_UseAbility(boss, pluginName, abilityName, slot);
                }
            }
            while(abilityKv.GotoNextKey());
            abilityKv.GoBack();
        }
        while(abilityKv.GotoNextKey());
        delete abilityKv;
    }
}
