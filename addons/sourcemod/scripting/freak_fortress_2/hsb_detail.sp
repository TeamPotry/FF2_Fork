#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <freak_fortress_2>
// #include <ff2_modules/general>

public Plugin myinfo=
{
	name="Freak Fortress 2: HSB Detail",
	author="Nopied",
	description="",
	version="2(1.0)",
};

#define THIS_PLUGIN_NAME "hsb_detail"

public void OnPluginStart()
{
    FF2_RegisterSubplugin(THIS_PLUGIN_NAME);
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool& result)
{
    int boss = FF2_GetBossIndex(client);
    if(boss != -1 && FF2_HasAbility(boss, THIS_PLUGIN_NAME, "infinite detonations"))
    {
        if(GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 307)
        {
			char classname[32];
			GetEntityClassname(weapon, classname, 32);
			if(StrEqual(classname, "tf_weapon_stickbomb"))
			{
				SetEntProp(weapon, Prop_Send, "m_bBroken", 0);
				SetEntProp(weapon, Prop_Send, "m_iDetonated", 0);
			}
        }
    }

    return Plugin_Continue;
}
