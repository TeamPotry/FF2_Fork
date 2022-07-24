bool bossHasReloadAbility[MAXPLAYERS+1];
bool bossHasRightMouseAbility[MAXPLAYERS+1];

Handle BossInfoTimer[MAXPLAYERS+1][2];

static const char g_strSkillNameKey[][] = {
	"rage",
	"200 rage",
	"lost life"
};

static const char g_strCreatorType[][] = {
    "other",
    "model",
    "plugin",
    "sound"
};

public int GetBossUserId(int boss)
{
	if(boss>=0 && boss<=MaxClients && IsValidClient(Boss[boss]))
	{
		return GetClientUserId(Boss[boss]);
	}
	return -1;
}

public int GetBossIndex(int client)
{
	if(client>0 && client<=MaxClients)
	{
		for(int boss; boss<=MaxClients; boss++)
		{
			if(Boss[boss]==client)
			{
				return boss;
			}
		}
	}
	return -1;
}

public int GetBossHealth(int boss)
{
	return BossHealth[boss];
}
public int SetBossHealth(int boss, int health)
{
	BossHealth[boss]=health;
}

public int GetBossMaxHealth(int boss)
{
	return BossHealthMax[boss];
}
public int SetBossMaxHealth(int boss, int health)
{
	BossHealthMax[boss]=health;
}

public int GetBossLives(int boss)
{
	return BossLives[boss];
}
public int SetBossLives(int boss, int lives)
{
	BossLives[boss]=lives;
}

public int GetBossMaxLives(int boss)
{
	return BossLivesMax[boss];
}
public int SetBossMaxLives(int boss, int lives)
{
	BossLivesMax[boss]=lives;
}

public float GetBossCharge(int boss, int slot)
{
	return BossCharge[boss][slot];
}
public int SetBossCharge(int boss, int slot, float charge)
{
	BossCharge[boss][slot]=charge;
}

public float GetBossMaxCharge(int boss)
{
	return BossMaxRageCharge[boss];
}
public int SetBossMaxCharge(int boss, float charge)
{
	BossMaxRageCharge[boss]=charge;
}

public void AddBossCharge(int boss, int slot, float charge)
{
	if(charge > 0.0)
	{
		BossCharge[boss][slot]+=charge;
		if(slot == 0)
			BossCharge[boss][slot] = BossCharge[boss][slot] > BossMaxRageCharge[boss] ? BossMaxRageCharge[boss] : BossCharge[boss][slot];
		else if(BossCharge[boss][slot] > 100.0)
			BossCharge[boss][slot] = 100.0;
	}
	else
	{
		BossCharge[boss][slot] += charge;
		if(BossCharge[boss][slot] < 0.0)
			BossCharge[boss][slot] = 0.0;
	}
}

public int GetBossRageDamage(int boss)
{
	return BossRageDamage[boss];
}
public int SetBossRageDamage(int boss, int damage)
{
	BossRageDamage[boss]=damage;
}

public TFTeam GetBossTeam()
{
	return BossTeam;
}

public bool GetBossName(int boss, char[] bossName, int length, int client)
{
	KeyValues bossKv = GetCharacterKV(character[boss]);
	int posId;

	bossKv.GetSectionSymbol(posId);
	bossKv.Rewind();

	if(client > 0)
	{
		char language[8];
		GetLanguageInfo(GetClientLanguage(client), language, sizeof(language));
		if(bossKv.JumpToKey("name_lang"))
		{
			bossKv.GetString(language, bossName, length, "");
			if(bossName[0]!='\0')
				return true;
		}
		bossKv.Rewind();
	}
	bossKv.GetString("name", bossName, length);
	bossKv.JumpToKeySymbol(posId);

	return true;
}

public bool GetBossSkillName(int boss, int type, char[] skillName, int length, int client)
{
	KeyValues bossKv = GetCharacterKV(character[boss]);
	int posId;

	bossKv.GetSectionSymbol(posId);
	bossKv.Rewind();

	if(bossKv.JumpToKey("skill info") && bossKv.JumpToKey(g_strSkillNameKey[type]))
	{
		char language[12];
		GetLanguageInfo(client > 0 ? GetClientLanguage(client) : GetServerLanguage(),
			language, sizeof(language));

		Format(language, sizeof(language), "name %s", language);
		bossKv.GetString(language, skillName, length, "");
		if(skillName[0] != '\0')
			return true;
	}

	bossKv.Rewind();
	bossKv.JumpToKeySymbol(posId);

	return false;
}

float GetBossSkillDuration(int boss, int type)
{
	KeyValues bossKv = GetCharacterKV(character[boss]);
	int posId;

	bossKv.GetSectionSymbol(posId);
	bossKv.Rewind();

	if(bossKv.JumpToKey("skill info") && bossKv.JumpToKey(g_strSkillNameKey[type]))
	{
		return bossKv.GetFloat("duration", 0.0);
	}

	bossKv.Rewind();
	bossKv.JumpToKeySymbol(posId);

	return 0.0;
}

int GetBossCreatorFlags(char[] steamId, int boss, bool pushCharacterIndex=false)
{
    int totalFlags = 0;
    char targetId[32];
    KeyValues bossKv = view_as<KeyValues>(CloneHandle(!pushCharacterIndex ? GetBossKV(boss) : GetCharacterKV(boss)));

    for(int loop = 0; loop < sizeof(g_strCreatorType); loop++)
    {
        bossKv.Rewind();
        bossKv.JumpToKey("creator", true);
        bossKv.JumpToKey(g_strCreatorType[loop], true);

        if(bossKv.GotoFirstSubKey(false))
        {
            do
            {
                bossKv.GetSectionName(targetId, sizeof(targetId));
                if(StrEqual(steamId, targetId)) {
                    totalFlags += (1 << loop);
                    break;
                }
            }
            while(bossKv.GotoNextKey(false));
        }
    }

    return totalFlags;
}

ArrayList GetBossCreators(int boss, int creatorType, bool pushCharacterIndex=false)
{
	ArrayList array = new ArrayList(32);
	KeyValues bossKv = view_as<KeyValues>(CloneHandle(!pushCharacterIndex ? GetBossKV(boss) : GetCharacterKV(boss)));
	char targetId[32];

	bossKv.Rewind();
	bossKv.JumpToKey("creator", true);
	bossKv.JumpToKey(g_strCreatorType[creatorType], true);

	if(bossKv.GotoFirstSubKey(false))
	{
		do
		{
		    bossKv.GetSectionName(targetId, sizeof(targetId));
		    array.PushString(targetId);
		}
		while(bossKv.GotoNextKey(false));
	}

	return array;
}

public KeyValues GetBossKV(int boss)
{
	if(boss >= 0 && boss <= MaxClients && character[boss] >= 0 && character[boss] < bossesArray.Length)
	{
		return view_as<KeyValues>(GetCharacterKV(character[boss]));
	}
	return null;
}

bool HasAbility(int boss, const char[] pluginName, const char[] abilityName, int slot = -3)
{
	if(boss==-1 || character[boss]==-1 || !GetCharacterKV(character[boss]))  //Invalid boss
	{
		return false;
	}

	char temp[64];
	KeyValues kv=GetCharacterKV(character[boss]);

	kv.Rewind();
	if(kv.JumpToKey("abilities") && kv.JumpToKey(pluginName))
	{
		if(slot == -3)
		{
			return kv.JumpToKey(abilityName);
		}
		else
		{
			kv.GotoFirstSubKey();
			do
			{
				kv.GetSectionName(temp, sizeof(temp));
				if(StrEqual(temp, abilityName) && kv.GetNum("slot", 0) == slot)
				{
					return true;
				}
			}
			while(kv.GotoNextKey());
		}
	}
	return false;
}

public int GetAbilityArgumentWrapper(int boss, const char[] pluginName, const char[] abilityName, const char[] argument, int defaultValue, int slot)
{
	return GetAbilityArgument(boss, pluginName, abilityName, argument, defaultValue, slot);
}

public float GetAbilityArgumentFloatWrapper(int boss, const char[] pluginName, const char[] abilityName, const char[] argument, float defaultValue, int slot)
{
	return GetAbilityArgumentFloat(boss, pluginName, abilityName, argument, defaultValue, slot);
}

public int GetAbilityArgumentStringWrapper(int boss, const char[] pluginName, const char[] abilityName, const char[] argument, char[] abilityString, int length, const char[] defaultValue, int slot)
{
	GetAbilityArgumentString(boss, pluginName, abilityName, argument, abilityString, length, defaultValue, slot);
}

bool UseAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int buttonMode=0)
{
	Action action;
	Call_StartForward(PreAbility);
	Call_PushCell(boss);
	Call_PushString(pluginName);
	Call_PushString(abilityName);
	Call_PushCell(slot);
	Call_Finish(action);

	if(action==Plugin_Handled || action==Plugin_Stop)
	{
		return false;
	}

	Call_StartForward(OnAbility);
	Call_PushCell(boss);
	Call_PushString(pluginName);
	Call_PushString(abilityName);
	Call_PushCell(slot);
	if(slot==-1)
	{
		Call_PushCell(3);  //We're assuming here a life-loss ability will always be in use if it gets called
		Call_Finish();
	}
	else if(slot == 0 || slot == -2)
	{
		FF2Flags[Boss[boss]]&=~FF2FLAG_BOTRAGE;
		Call_PushCell(3);  //We're assuming here a rage ability will always be in use if it gets called
		Call_Finish();
	}
	else
	{
		SetHudTextParams(-1.0, 0.88, 0.15, 255, 255, 255, 255);
		int button;
		switch(buttonMode)
		{
			case 2:
			{
				button=IN_RELOAD;
				bossHasReloadAbility[boss]=true;
			}
			default:
			{
				button=IN_DUCK|IN_ATTACK2;
				bossHasRightMouseAbility[boss]=true;
			}
		}

		if(GetClientButtons(Boss[boss]) & button)
		{
			for(int timer; timer<=1; timer++)
			{
				if(BossInfoTimer[boss][timer]!=null)
				{
					KillTimer(BossInfoTimer[boss][timer]);
					BossInfoTimer[boss][timer]=null;
				}
			}

			if(BossCharge[boss][slot]>=0.0)
			{
				Call_PushCell(2);  //Ready
				Call_Finish();
				float charge=100.0*GetTickInterval()/GetAbilityArgumentFloat(boss, pluginName, abilityName, "charge", 1.0, slot);
				if(BossCharge[boss][slot]+charge<100.0)
				{
					BossCharge[boss][slot]+=charge;
				}
				else
				{
					BossCharge[boss][slot]=100.0;
				}
			}
			else
			{
				Call_PushCell(1);  //Recharging
				Call_Finish();

				BossCharge[boss][slot] += GetTickInterval();
				if(BossCharge[boss][slot] > 0.0)
					BossCharge[boss][slot] = 0.0;
			}
		}
		else if(BossCharge[boss][slot]>0.3)
		{
			Call_PushCell(3);  //In use
			float cooldown=GetAbilityArgumentFloat(boss, pluginName, abilityName, "cooldown", 0.0, slot);

			if(cooldown>0.0)
			{
				Call_Finish();
				BossCharge[boss][slot] = -1.0*cooldown;
			}
			else
			{
				// Call_PushCell(0);  //Not in use
				Call_Finish();
				BossCharge[boss][slot]=0.0;
			}
		}
		else if(BossCharge[boss][slot]<0.0)
		{
			Call_PushCell(1);  //Recharging
			Call_Finish();

			BossCharge[boss][slot] += GetTickInterval();
			if(BossCharge[boss][slot] > 0.0)
				BossCharge[boss][slot] = 0.0;
		}
		else
		{
			Call_PushCell(0);  //Not in use
			Call_Finish();
		}
	}
	return true;
}

#include "ff2_module/boss_native.sp"
