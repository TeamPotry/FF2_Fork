#include <sourcemod>
#include <morecolors>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <ff2_modules/general>
// #include <ff2_boss_selection>

public Plugin myinfo=
{
	name="Freak Fortress 2: Rank Hud",
	author="Nopied",
	description="",
	version="2(1.0)",
};

int g_currentDamageRank[MAXPLAYERS+1];

public void OnPluginStart()
{
	CreateTimer(0.1, UpdateTimer, TIMER_REPEAT);

	LoadTranslations("ff2_just_hud_thing.phrases");
}

public Action UpdateTimer(Handle timer)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState() != 1)	return Plugin_Continue;
	UpdateDamageRank();
	return Plugin_Continue;
}

public void FF2_OnCalledQueue(FF2HudQueue hudQueue, int client)
{
	SetGlobalTransTarget(client);

	int ranking;
	char text[256];
	FF2HudDisplay hudDisplay = null;
	hudQueue.GetName(text, sizeof(text));

	UpdateDamageRank();

	if(StrEqual(text, "Player"))
	{
		ranking = GetClientRanking(client);
		GetClientRankingString(ranking, text, sizeof(text));

		Format(text, sizeof(text), "%t: %s ", "Rank", text);
		if(ranking != -1)
			Format(text, sizeof(text), "%s(↑ %d, ↓%d)", text, GetRankingGap(ranking, ranking-1),  GetRankingGap(ranking, ranking+1));

		hudDisplay = FF2HudDisplay.CreateDisplay("Your Rank", text);
		hudQueue.AddHud(hudDisplay, client);
	}
	else if(StrEqual(text, "Observer"))
	{
		int observer = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
		if(!IsBoss(observer))
		{
			ranking = GetClientRanking(observer);
			GetClientRankingString(ranking, text, sizeof(text));

			Format(text, sizeof(text), "%t: %s ", "Rank", text);
			if(ranking != -1)
				Format(text, sizeof(text), "%s(↑ %d, ↓%d)", text, GetRankingGap(ranking, ranking-1), GetRankingGap(ranking, ranking+1));

			hudDisplay = FF2HudDisplay.CreateDisplay("Observer Target Player Rank", text);
			hudQueue.AddHud(hudDisplay, client, observer);
		}
	}
}

public void GetClientRankingString(int rankingPos, char[] text, int bufferLength)
{
	if(rankingPos >= 0)
		Format(text, bufferLength, "%d", rankingPos + 1);
	else
		Format(text, bufferLength, "??");
}

int GetRankingGap(int ranking, int targetRanking)
{
	if(ranking < 0 || targetRanking < 0 || ranking == targetRanking
		|| !IsValidClient(g_currentDamageRank[ranking]) || !IsValidClient(g_currentDamageRank[targetRanking]))
		return 0;

	int result = FF2_GetClientDamage(g_currentDamageRank[ranking]) - FF2_GetClientDamage(g_currentDamageRank[targetRanking]);
	return result > 0 ? result : result * -1;
}

int GetClientRanking(int client)
{
	for(int loop = 0; loop < MAXPLAYERS + 1; loop++)
	{
		if(g_currentDamageRank[loop] == client)
			return loop;
	}

	return -1;
}

void UpdateDamageRank() // TODO: 정렬 방식 변경
{
	int tempTop[MAXPLAYERS+1];
	TFTeam bossTeam = FF2_GetBossTeam();

	CopyArray(tempTop, 0, MAXPLAYERS, g_currentDamageRank);

	for(int client = 1; client <= MaxClients; client++)
	{
		tempTop[client] = 0;

		if(!IsClientInGame(client) || (IsBoss(client) && TF2_GetClientTeam(client) == bossTeam))
			continue;

		tempTop[client] = FF2_GetClientDamage(client);
	}

	SortIntegers(tempTop, MAXPLAYERS+1, Sort_Descending);

	for(int client = 0; client <= MAXPLAYERS; client++)
	{
		for(int target = 1; target <= MaxClients; target++)
		{
			if(!IsClientInGame(target) || (IsBoss(target) && TF2_GetClientTeam(target) == bossTeam))
				continue;

			if(tempTop[client] == FF2_GetClientDamage(target)) {
				g_currentDamageRank[client] = target
				break;
			}
		}
	}
}

public void CopyArray(int[] array, int startPos, int endPos, int[] vicArray)
{
    for(int loop = startPos; loop == endPos; endPos > startPos ? loop-- : loop++)
    {
        vicArray[loop] = array[loop];
    }
}

stock bool IsBoss(int client)
{
    return FF2_GetBossIndex(client) != -1;
}

stock bool IsValidClient(int client)
{
	return (0 < client && client <= MaxClients && IsClientInGame(client));
}
