#include <sourcemod>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <ff2_modules/general>
#include <ff2_boss_selection>

#tryinclude <mannvsmann>

#define PLUGIN_VERSION "20230506"

public Plugin myinfo=
{
	name="Freak Fortress 2: Human Team Bosses",
	author="Nopied◎",
	description="",
	version=PLUGIN_VERSION,
};

#define FOREACH_PLAYER(%1) for(int %1 = 1; %1 <= MaxClients; %1++)

#define BECOME_HUMANTEAM_BOSS_MENUFUNCTION		"ff2_humanteamboss become boss"

ConVar ff2_htb_enable;
ConVar ff2_htb_mvm_cost;

public void OnPluginStart()
{
	ff2_htb_enable = CreateConVar("ff2_htb_enable", "1", "0 - disable, 1 - enable", _, true, 0.0, true, 1.0);
	ff2_htb_mvm_cost = CreateConVar("ff2_htb_mvm_cost", "400", "0 - Free, else: This cvar value is will be the price of play human team boss.", _, true, 0.0, false);

	// TODO: HTB Spec configable 

	LoadTranslations("ff2_humanteamboss.phrases");
}

public Action OnReviveMarkerSpawn(int client, int reviveMarker)
{
	if(FF2_GetBossIndex(client) != -1)
		return Plugin_Stop;

	return Plugin_Continue;
}

enum
{
	HTBBlocked_None = 0,
	HTBBlocked_InBossTeam, // Currently in boss team.
	HTBBlocked_AlreadyStarted, // round has already started.
	HTBBlocked_NotEnoughCurrency, // literally.
	HTBBlocked_NoCharacterRemaining, // the character is on battle.
	HTBBlocked_AlreadyBoss // already became boss.
};

static const char BlockReasonToken[][] = {
	"Activated", // Not used
	"In BossTeam",
	"Round Started",
	"Not Enough Currency",
	"No Character Remaining",
	"Already Boss"
};

public void FF2Selection_InfoMenuReady(int client, const int characterIndex)
{
	if(!ff2_htb_enable.BoolValue
		|| IsCharacterBanned(characterIndex))	return;

	char text[128];
	bool blocked = false;
	int blockReason = HTBBlocked_None;

	// Check block condition
	if(!IsCharacterRemaining(characterIndex))
		blockReason = HTBBlocked_NoCharacterRemaining;
	else if(FF2_GetRoundState() > 0)
		blockReason = HTBBlocked_AlreadyStarted;
	else if(TF2_GetClientTeam(client) == FF2_GetBossTeam())
		blockReason = HTBBlocked_InBossTeam;
	else if(IsBoss(client))
		blockReason = HTBBlocked_AlreadyBoss;

#if defined _MVM_included
	int currency = MVM_GetPlayerCurrency(client), currencyCost = ff2_htb_mvm_cost.IntValue;
	if(currencyCost > 0)
		Format(text, sizeof(text), "%T", "HTB Menu Prefix Use Currency",
			client, currencyCost);

	if(currencyCost > currency)
		blockReason = HTBBlocked_NotEnoughCurrency;
#endif

	Format(text, sizeof(text), "%s%T", text, "HTB Menu Name", client);

	if(blockReason != HTBBlocked_None)
	{
		char blockText[128];
		Format(blockText, sizeof(blockText), "HTB Menu Block Reason %s", BlockReasonToken[blockReason]);
		Format(blockText, sizeof(blockText), "%T", blockText, client);

		Format(text, sizeof(text), "%s\n - %s", text, blockText);

		blocked = true;
	}

	// NOTE: Since we are using SourceMod's Menu, ITEMDRAW_RAWLINE is not working here.
    // Probably you do better with using ITEMDRAW_DISABLED and use \n to inform about item.
	FF2Selection_AddInfoMenu(text, BECOME_HUMANTEAM_BOSS_MENUFUNCTION,
		blocked ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
}

public void FF2Selection_OnInfoMenuCreated(int client, const char[] functionName, const int characterIndex)
{
	if(!StrEqual(functionName, BECOME_HUMANTEAM_BOSS_MENUFUNCTION)
		|| IsCharacterBanned(characterIndex))		return;

	char text[128];
	int blockReason = HTBBlocked_None;

	// Check block condition once more.
	if(!IsCharacterRemaining(characterIndex))
		blockReason = HTBBlocked_NoCharacterRemaining;
	else if(FF2_GetRoundState() > 0)
		blockReason = HTBBlocked_AlreadyStarted;
	else if(TF2_GetClientTeam(client) == FF2_GetBossTeam())
		blockReason = HTBBlocked_InBossTeam;
	else if(IsBoss(client))
		blockReason = HTBBlocked_AlreadyBoss;

#if defined _MVM_included
	int currency = MVM_GetPlayerCurrency(client), currencyCost = ff2_htb_mvm_cost.IntValue;

	if(currencyCost > currency)
		blockReason = HTBBlocked_NotEnoughCurrency;
#endif

	if(blockReason != HTBBlocked_None)
	{
		Format(text, sizeof(text), "HTB Chat Block Reason %s", BlockReasonToken[blockReason]);
		Format(text, sizeof(text), "%T", text, client);

		CPrintToChat(client, "{olive}[FF2]{default} %s", text);
		return;
	}

	// TODO: 사운드 (자금 사용, 보스 효과음)
#if defined _MVM_included
	MVM_SetPlayerCurrency(client, currency - currencyCost);
#endif

	FF2_MakePlayerToBoss(client, characterIndex);

	int bossIndex = FF2_GetBossIndex(client);
	FF2_SetBossMaxHealth(bossIndex, 500);
	FF2_SetBossHealth(bossIndex, 500);
	FF2_SetBossLives(bossIndex, 1);
	FF2_SetBossMaxLives(bossIndex, 1);
	FF2_SetBossCharge(bossIndex, 0, 100.0);
	FF2_SetBossMaxCharge(bossIndex, 100.0);
	
	char bossName[64];
	KeyValues kv = FF2_GetCharacterKV(characterIndex);
	
	FOREACH_PLAYER(target)
	{
		if(IsClientInGame(target))
		{
			GetCharacterName(kv, bossName, sizeof(bossName), target);

			char reason[64];

#if defined _MVM_included
			Format(reason, sizeof(reason), " %T", "HTB Chat Player Become Boss Reason Currency", target, currencyCost);
#endif			

			CPrintToChat(target, "{olive}[FF2]{default} %T", "HTB Chat Player Become Boss", target, client, bossName, reason);
		}
	}
}

bool IsCharacterRemaining(int characterIndex)
{
	FOREACH_PLAYER(client)
	{
		int boss = -1;
		if(!IsClientInGame(client)
			|| (boss = FF2_GetBossIndex(client)) == -1)
			continue;

		if(FF2_GetCharacterIndex(boss) == characterIndex)
			return false;
	}

	return true;
}

bool IsCharacterBanned(int characterIndex)
{
	KeyValues kv = FF2_GetCharacterKV(characterIndex);
	kv.Rewind();
	return kv.GetNum("ban_boss_vs_boss", 0) > 0;
}

public void GetCharacterName(KeyValues characterKv, char[] bossName, int size, const int client)
{
	int currentSpot;
	characterKv.GetSectionSymbol(currentSpot);
	characterKv.Rewind();

	if(client > 0)
	{
		char language[8];
		GetLanguageInfo(GetClientLanguage(client), language, sizeof(language));
		if(characterKv.JumpToKey("name_lang"))
		{
			characterKv.GetString(language, bossName, size, "");
			if(bossName[0] != '\0')
				return;
		}
		characterKv.Rewind();
	}
	characterKv.GetString("name", bossName, size);
	characterKv.JumpToKeySymbol(currentSpot);
}

stock bool IsBoss(int client)
{
	return FF2_GetBossIndex(client) != -1;
}
