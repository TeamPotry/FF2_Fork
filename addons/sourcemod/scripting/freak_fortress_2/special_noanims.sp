/*
special_noanims:	slot - unused.
					arg1 - 1=Custom Model Rotates (def.0)

rage_new_weapon:	slot - slot (def.0)
					arg1 - weapon's classname
					arg2 - weapon's index
					arg3 - weapon's attributes
					arg4 - weapon's slot (0 - primary. 1 - secondary. 2 - melee. 3 - pda. 4 - spy's watches)
					arg5 - weapon's ammo (set to 1 for clipless weapons, then set the actual ammo using clip)
					arg6 - force switch to this weapon
					arg7 - weapon's clip
*/
#pragma semicolon 1

#include <sourcemod>
#include <tf2items>
#include <tf2_stocks>
#include <tf2attributes>
#include <freak_fortress_2>

#pragma newdecls required

#define PLUGIN_NAME "noanims and new weapon"
#define PLUGIN_VERSION "2.0.0"

public Plugin myinfo=
{
	name="Freak Fortress 2: special_noanims",
	author="RainBolt Dash, Wliu",
	description="FF2: New Weapon and No Animations abilities",
	version=PLUGIN_VERSION
};

public void OnPluginStart()
{
	int version[3];
	FF2_GetFF2Version(version);
	if(version[0]==1 && (version[1]<10 || (version[1]==10 && version[2]<3)))
	{
		SetFailState("This subplugin depends on at least FF2 v1.10.3");
	}

	HookEvent("teamplay_round_start", OnRoundStart, EventHookMode_PostNoCopy);

	FF2_RegisterSubplugin(PLUGIN_NAME);
}

public void FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status)
{
	if(!StrEqual(pluginName, PLUGIN_NAME, false))
	{
		return;
	}

	if(StrEqual(abilityName, "equip weapon", false))
	{
		Rage_New_Weapon(boss, abilityName, slot);
	}
}

public Action OnRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if(FF2_IsFF2Enabled())
	{
		CreateTimer(0.41, Timer_Disable_Anims, TIMER_FLAG_NO_MAPCHANGE);
		CreateTimer(9.31, Timer_Disable_Anims, TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Continue;
}

public Action Timer_Disable_Anims(Handle timer)
{
	int client;
	for(int boss; (client=GetClientOfUserId(FF2_GetBossUserId(boss)))>0; boss++)
	{
		if(FF2_HasAbility(boss, PLUGIN_NAME, "no animations"))
		{
			SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 0);
			SetEntProp(client, Prop_Send, "m_bCustomModelRotates", FF2_GetAbilityArgument(boss, PLUGIN_NAME, "no animations", "rotate model", 0));
		}
	}
	return Plugin_Continue;
}

void Rage_New_Weapon(int boss, const char[] abilityName, int slot)
{
	int client=GetClientOfUserId(FF2_GetBossUserId(boss));
	if(!client || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return;
	}

	char classname[64], attributes[256], model[PLATFORM_MAX_PATH];
	FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, abilityName, "classname", classname, sizeof(classname), "", slot);
	FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, abilityName, "attributes", attributes, sizeof(attributes), "", slot);
	FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, abilityName, "projectile model", model, sizeof(model), "", slot);

	int weaponSlot=FF2_GetAbilityArgument(boss, PLUGIN_NAME, abilityName, "weapon slot", -1, slot);
	if(weaponSlot >= 0)
		TF2_RemoveWeaponSlot(client, weaponSlot);

	int index=FF2_GetAbilityArgument(boss, PLUGIN_NAME, abilityName, "index", slot);
	int weapon=SpawnWeapon(client, classname, index, 101, 5, attributes);
	if(StrEqual(classname, "tf_weapon_builder") && index!=735)  //PDA, normal sapper
	{
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 1, _, 0);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 1, _, 1);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 1, _, 2);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 3);
	}
	else if(StrEqual(classname, "tf_weapon_sapper") || index==735)  //Sappers, normal sapper
	{
		SetEntProp(weapon, Prop_Send, "m_iObjectType", 3);
		SetEntProp(weapon, Prop_Data, "m_iSubType", 3);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 0);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 1);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 2);
		SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 1, _, 3);
	}

	if(model[0] != '\0')
	{
		TF2Attrib_SetFromStringValue(weapon, "custom projectile model", model);
		// PrintToServer("%s", TF2Attrib_SetFromStringValue(weapon, "custom projectile model", model) ? "true" : "false");
	}


	if(FF2_GetAbilityArgument(boss, PLUGIN_NAME, abilityName, "set as active weapon", slot))
	{
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
	}

	int ammo=FF2_GetAbilityArgument(boss, PLUGIN_NAME, abilityName, "ammo", 0, slot);
	int clip=FF2_GetAbilityArgument(boss, PLUGIN_NAME, abilityName, "clip", 0, slot);

	if(ammo || clip)
	{
		FF2_SetAmmo(client, weapon, ammo, clip);
	}
}

/*
 * Equips a new weapon for a given client
 *
 * @param client		Client to equip new weapon for
 * @param classname		Classname of the weapon
 * @param index			Index of the weapon
 * @param level			Level of the weapon
 * @param quality		Quality of the weapon
 * @param attributeList	String of attributes in a 'name ; value' pattern (optional)
 *
 * @return				Weapon entity index on success, -1 on failure
 */
stock int SpawnWeapon(int client, char[] classname, int index, int level=1, int quality=0, char[] attributeList="")
{
	Handle weapon=TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	if(weapon==null)
	{
		return -1;
	}

	TF2Items_SetClassname(weapon, classname);
	TF2Items_SetItemIndex(weapon, index);
	TF2Items_SetLevel(weapon, level);
	TF2Items_SetQuality(weapon, quality);
	char attributes[32][32];
	int count=ExplodeString(attributeList, ";", attributes, 32, 32);

	if(count==1) // ExplodeString returns the original string if no matching delimiter was found so we need to special-case this
	{
		if(attributeList[0]!='\0') // Ignore empty attribute list
		{
			LogError("[FF2 Weapons] Unbalanced attributes array '%s' for weapon %s", attributeList, classname);
			delete weapon;
			return -1;
		}
		else
		{
			TF2Items_SetNumAttributes(weapon, 0);
		}
	}
	else if(count % 2) // Unbalanced array, eg "2 ; 10 ; 3"
	{
		LogError("[FF2 Weapons] Unbalanced attributes array '%s' for weapon %s", attributeList, classname);
		delete weapon;
		return -1;
	}
	else
	{
		TF2Items_SetNumAttributes(weapon, count/2);
		int i2;
		for(int i; i<count; i+=2)
		{
			int attribute=StringToInt(attributes[i]);
			if(!attribute)
			{
				LogError("[FF2 Weapons] Bad weapon attribute passed: %s ; %s", attributes[i], attributes[i+1]);
				delete weapon;
				return -1;
			}

			TF2Items_SetAttribute(weapon, i2, attribute, StringToFloat(attributes[i+1]));
			i2++;
		}
	}

	int entity=TF2Items_GiveNamedItem(client, weapon);
	delete weapon;
	EquipPlayerWeapon(client, entity);
	return entity;
}
