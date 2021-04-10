#include <sourcemod>
// #include <morecolors>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <ff2_potry>
// #include <ff2_boss_selection>

public Plugin myinfo=
{
	name="Freak Fortress 2: Demopan",
	author="Nopied",
	description="",
	version="2(1.0)",
};

#define THIS_PLUGIN_NAME "demopan_detail"

public void OnPluginStart()
{
    FF2_RegisterSubplugin(THIS_PLUGIN_NAME);
}

public void FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status)
{
    if(StrEqual(abilityName, "democharge_detail"))
    {
        if(status == 0) return;

				int client = GetClientOfUserId(FF2_GetBossUserId(boss));
        if(status == 1)
        {
            SetEntPropFloat(client, Prop_Send, "m_flChargeMeter", 100.0);
            TF2_AddCondition(client, TFCond_Charging, 0.12);
        }
    }
}
