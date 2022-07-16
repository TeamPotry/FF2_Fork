#include <sourcemod>
#include <sdktools>
#include <freak_fortress_2>
#include <ff2_modules/general>

public Plugin:myinfo =
{
	name = "Sandvich Invulnerable",
	author = "Nopied◎",
	description = "the Picnics",
	version = "0.0",
	url = ""
}

public void OnPluginStart()
{
    AddNormalSoundHook(SoundHook);
}

public Action SoundHook(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH],
	  int &entity, int &channel, float &volume, int &level, int &pitch, int &flags,
	  char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	// vo/SandwichEat09.mp3
    if(StrEqual(sample, "vo/SandwichEat09.mp3") && FF2_GetBossIndex(entity) == -1)
		TF2_AddCondition(entity, TFCond_UberchargedCanteen, 3.0);
}

stock bool IsValidClient(int client)
{
	return (0 < client && client <= MaxClients && IsClientInGame(client));
}
