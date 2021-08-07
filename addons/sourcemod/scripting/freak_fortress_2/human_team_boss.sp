#include <sourcemod>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <ff2_potry>

public Plugin myinfo=
{
	name="FF2: Player team boss",
	author="Nopied",
	description="",
	version="00",
};

public void OnPluginStart()
{
	HookEvent("arena_round_start", OnRoundStart);
	HookEvent("teamplay_round_active", OnRoundStart); // for non-arena maps

	LoadTranslations("freak_fortress_2.phrases");
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(!FF2_IsFF2Enabled()) return Plugin_Continue;

	int bossCount;
	ArrayList clientArray = GetAlivePlayers(false);
	ArrayList bossArray = GetBossPlayers();
	ArrayList bossCharArray = GetBossArray();

	if((bossCount = (clientArray.Length / 8)) > 0)
	{
		int random, index, bossindex, randomBossIndex;
		char bossName[64];
		for(int loop = 0; loop < bossCount; loop++)
		{
			int clientCount = clientArray.Length, bossCharCount = bossCharArray.Length;
			if(clientCount == 0 || bossCharCount == 0)
				break;

			SetRandomSeed(GetTime() + loop);

			index = GetRandomInt(0, clientCount - 1);
			random = clientArray.Get(index);

			if(FF2_GetQueuePoints(random) < 0 || FF2_GetSettingData(random, "human_team_boss_play", KvData_Int) == 1)
			{	// 제외
				clientArray.Erase(index);
				continue;
			}

			randomBossIndex = GetRandomInt(0, bossCharCount - 1);
			bossindex = bossCharArray.Get(randomBossIndex);

			FF2_MakePlayerToBoss(random, bossindex);
			bossindex = FF2_GetBossIndex(random);

			FF2_SetBossMaxHealth(bossindex, 1000);
			FF2_SetBossHealth(bossindex, 1000);
			FF2_SetBossLives(bossindex, 1);
			FF2_SetBossMaxLives(bossindex, 1);
			FF2_SetBossRageDamage(bossindex, 500);

			for(int client = 1; client <= MaxClients; client++)
			{
				if(!IsClientInGame(client) || TF2_GetClientTeam(client) == FF2_GetBossTeam())
					continue;

				SetGlobalTransTarget(client);
				FF2_GetBossName(bossindex, bossName, sizeof(bossName), client);
				CPrintToChat(client, "{olive}[FF2]{default} %t", "Human Hero", random, bossName);
			}
			clientArray.Erase(index);
			bossCharArray.Erase(randomBossIndex);
		}
	}

	delete clientArray;
	delete bossArray;
	delete bossCharArray;
	return Plugin_Continue;
}

public Action OnReviveMarkerSpawn(int client, int reviveMarker)
{
	if(FF2_GetBossIndex(client) != -1)
		return Plugin_Stop;

	return Plugin_Continue;
}

stock int GetRandomBoss(bool includeBlocked=false) // TODO: includeBlocked
{
	ArrayList array = new ArrayList();
	KeyValues bossKV;
	int count = 0, index;

	for (int loop = 0; (bossKV = FF2_GetCharacterKV(loop)) != null; loop++)
	{
		bossKV.Rewind();
		if(bossKV.GetNum("ban_boss_vs_boss", 0) > 0)
			continue;

		array.Push(loop);
		count++;
	}

	if(count > 0)
	{
		ArrayList bossArray = GetBossPlayers();

		for (int loop = 0; loop < bossArray.Length; loop++)
		{
			index = array.FindValue(FF2_GetBossIndex(bossArray.Get(loop)));
			if(index != -1)
			{
				array.Erase(index);
				count--;
			}
		}

		delete bossArray;
	}

	int result = count > 0 ? array.Get(GetRandomInt(0, count-1)) : -1;

	delete array;
	return result;
}

public ArrayList GetBossPlayers()
{
	ArrayList array = new ArrayList();
	for(int client = 1; client <= MaxClients; client++)
	{
	    if(IsClientInGame(client) && IsPlayerAlive(client) && FF2_GetBossIndex(client) != -1)
	    {
	        array.Push(client);
	    }
	}

	return array;
}

public ArrayList GetAlivePlayers(bool includeBoss)
{
	ArrayList array = new ArrayList();
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && IsPlayerAlive(client) && FF2_GetQueuePoints(client) >= 0 && (!includeBoss && FF2_GetBossIndex(client) == -1))
		{
		    array.Push(client);
		}
	}

	return array;
}
