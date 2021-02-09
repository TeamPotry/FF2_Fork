#include <sourcemod>
#include <morecolors>
#include <freak_fortress_2>
#include <ff2_potry>
// #include <ff2_boss_selection>

// int triggerHurtdamaged[MAXPLAYERS+1];

public Plugin myinfo=
{
	name="Freak Fortress 2: Correction",
	author="Nopied",
	description="",
	version="2(1.0)",
};

public Action FF2_OnTriggerHurt(int boss, int triggerHurt, float& damage)
{
    // int client = GetClientOfUserId(FF2_GetBossUserId(boss));
    // triggerHurtdamaged[client] += damage;
    if(damage > 100.0)
    {
        damage = 100.0;
        return Plugin_Changed;
    }

    return Plugin_Continue;
}
