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
	int bossCount;
	ArrayList clientArray = GetAlivePlayers(false);
	ArrayList bossArray = GetBossPlayers();

	if((bossCount = (clientArray.Length + bossArray.Length) / 12) > 0)
	{
		int random, index, bossindex;
		int healthPoint = 500 + (300 * bossCount);
		char bossName[64];
		for(int loop = 0; loop < bossCount; loop++)
		{
			index = GetRandomInt(0, clientArray.Length-1);
			random = clientArray.Get(index);
			bossindex = GetRandomBoss();
			// TODO: 중복 보스 방지
			FF2_MakePlayerToBoss(random, bossindex);

			bossindex = FF2_GetBossIndex(random);

			FF2_SetBossMaxHealth(bossindex, healthPoint);
			FF2_SetBossHealth(bossindex, healthPoint);
			FF2_SetBossLives(bossindex, 1);
			FF2_SetBossRageDamage(bossindex, 550 + (150 * bossCount));

			for(int cloop=0; cloop < clientArray.Length; cloop++)
			{
				int client = clientArray.Get(cloop);
				SetGlobalTransTarget(client);
				FF2_GetBossName(bossindex, bossName, sizeof(bossName), client);
				CPrintToChat(client, "{olive}[FF2]{default} %t", "Human Hero", random, bossName);
			}
			clientArray.ShiftUp(index);
		}
	}

	delete clientArray;
	delete bossArray;
	return Plugin_Continue;
}

stock int GetRandomBoss(bool includeBlocked=false) // TODO: includeBlocked
{
	ArrayList array = new ArrayList();
	int count = 0;

	for (int loop = 0; FF2_GetCharacterKV(loop) != null; loop++)
	{
	    array.Push(loop);
	    count++;
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
	    if(IsClientInGame(client) && IsPlayerAlive(client) && FF2_GetBossIndex(client) == -1)
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
		if(IsClientInGame(client) && IsPlayerAlive(client) && (!includeBoss && FF2_GetBossIndex(client) == -1))
		{
		    array.Push(client);
		}
	}

	return array;
}
