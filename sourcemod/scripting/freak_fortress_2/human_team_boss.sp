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
	HookEvent("teamplay_round_start", OnRoundStart);

	LoadTranslations("freak_fortress_2.phrases");
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(10.2, RoundStart, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action RoundStart(Handle timer)
{
	if(!FF2_IsFF2Enabled()) return Plugin_Continue;

	int bossCount;
	ArrayList clientArray = GetAlivePlayers(false);
	ArrayList bossArray = GetBossPlayers();

	if((bossCount = (clientArray.Length + bossArray.Length) / 6) > 0)
	{
		int random, index, bossindex;
		int healthPoint = 600 + (300 * bossCount);
		char bossName[64];
		for(int loop = 0; loop < bossCount; loop++)
		{
			SetRandomSeed(GetTime()+loop);

			index = GetRandomInt(0, clientArray.Length-1);
			random = clientArray.Get(index);
			bossindex = GetRandomBoss();

			if(bossindex == -1)
				break;

			FF2_MakePlayerToBoss(random, bossindex);

			bossindex = FF2_GetBossIndex(random);

			FF2_SetBossMaxHealth(bossindex, healthPoint);
			FF2_SetBossHealth(bossindex, healthPoint);
			FF2_SetBossLives(bossindex, 1);
			FF2_SetBossRageDamage(bossindex, 550 + (150 * bossCount));

			for(int cloop=0; cloop < clientArray.Length; cloop++)
			{
				// FIXME: 대기열 포인트가 0 미만일 경우, 아군이여도 누그 보스인지 메세지 출력이 안됨.
				int client = clientArray.Get(cloop);
				SetGlobalTransTarget(client);
				FF2_GetBossName(bossindex, bossName, sizeof(bossName), client);
				CPrintToChat(client, "{olive}[FF2]{default} %t", "Human Hero", random, bossName);
			}
			clientArray.Erase(index);
		}
	}

	delete clientArray;
	delete bossArray;
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
