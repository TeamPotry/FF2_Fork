#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2utils>
#include <tf2attributes>
#include <freak_fortress_2>
#include <ff2_potry>
#include <stocksoup/sdkports/util>

#define PLUGIN_NAME 	"simple abilities"
#define PLUGIN_VERSION 	"20211113"

public Plugin myinfo=
{
	name="Freak Fortress 2: Simple Abilities",
	author="Nopied◎",
	description="FF2?",
	version=PLUGIN_VERSION,
};

#define CLIP_ADD_NAME 						"set clip"
#define DELAY_ABILITY_NAME 					"delay"
#define REGENERATE_ABILITY_NAME 			"regenerate"
#define SCREENFADE_ABILITY_NAME				"screen fade"
#define HIDEHUD_ABILITY_NAME				"hide hud"
#define PLAYERFADE_ABILITY_NAME				"player fade"
#define PLAYERWEAPONDROP_ABILITY_NAME		"player weapon drop"
#define INSERT_ATTIBUTES_ABILITY_NAME		"insert attributes"
#define REPLACE_BUTTONS_NAME				"replace buttons"
#define REMOVE_EMPTY_ABILITY_NAME			"remove weapon when empty"
#define CHANGE_FIRE_DURATION				"change fire duration"
#define SIMPLE_HINT_NAME					"simple hint"

#define ADDITIONAL_HEALTH_NAME							"additional health"
// slot must be more than 0.
#define ADDITIONAL_HEALTH_DRAIN_RATE					"drain rate"
#define ADDITIONAL_HEALTH_ON_KILL						"on kill"
#define ON_KILL_ADDITIONAL_HEALTH_STUN_DURATION			"on kill stun duration"
#define ON_KILL_ADDITIONAL_HEALTH_IN_DURATION			"on kill duration multiplier"

#define ADD_ADDITIONAL_HEALTH_NAME						"add additional health"

#define PAINIS_NOTICE							"painis notice"
#define PAINIS_EAT_NOTICE						"painis eat sound"

#define HIDEHUD_FLAGS			0b101101001010
/*
https://github.com/TheAlePower/TeamFortress2/blob/1b81dded673d49adebf4d0958e52236ecc28a956/tf2_src/game/shared/shareddefs.h

#define	HIDEHUD_WEAPONSELECTION		( 1<<0 )	// Hide ammo count & weapon selection
#define	HIDEHUD_FLASHLIGHT			( 1<<1 )
#define	HIDEHUD_ALL					( 1<<2 )
#define HIDEHUD_HEALTH				( 1<<3 )	// Hide health & armor / suit battery
#define HIDEHUD_PLAYERDEAD			( 1<<4 )	// Hide when local player's dead
#define HIDEHUD_NEEDSUIT			( 1<<5 )	// Hide when the local player doesn't have the HEV suit
#define HIDEHUD_MISCSTATUS			( 1<<6 )	// Hide miscellaneous status elements (trains, pickup history, death notices, etc)
#define HIDEHUD_CHAT				( 1<<7 )	// Hide all communication elements (saytext, voice icon, etc)
#define	HIDEHUD_CROSSHAIR			( 1<<8 )	// Hide crosshairs
#define	HIDEHUD_VEHICLE_CROSSHAIR	( 1<<9 )	// Hide vehicle crosshair
#define HIDEHUD_INVEHICLE			( 1<<10 )
#define HIDEHUD_BONUS_PROGRESS		( 1<<11 )	// Hide bonus progress display (for bonus map challenges)
*/

float g_flCurrentDelay[MAXPLAYERS+1];
float g_flHideHudTime[MAXPLAYERS+1];
float g_flPlayerFadeTime[MAXPLAYERS+1];

int g_hDroppedWeapons[MAXPLAYERS+1];
int g_hDisabledWeapon[MAXPLAYERS+1];
int g_hDisabledWeaponSlot[MAXPLAYERS+1];
float g_flWeaponDisabledTime[MAXPLAYERS+1];

int g_iCurrentAdditionalHealth[MAXPLAYERS+1];
float g_flAdditionalHealthMultiplierDuration[MAXPLAYERS+1];

enum
{
	Effect_OtherTeam = 0,
	Effect_Everyone,
	Effect_OnlyInvoker,
	Effect_OnlyHuman
};

public void OnPluginStart()
{
	LoadTranslations("ff2_extra_abilities.phrases");

	HookEvent("arena_round_start", Event_RoundStart);
	HookEvent("teamplay_round_active", Event_RoundStart); // for non-arena maps

	HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Post);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);

	FF2_RegisterSubplugin(PLUGIN_NAME);
}

public void OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid")),
		// attacker = GetClientOfUserId(event.GetInt("attacker")),
		damage = event.GetInt("damageamount"),
		boss = FF2_GetBossIndex(client);

	if(FF2_HasAbility(boss, PLUGIN_NAME, ADDITIONAL_HEALTH_NAME)
		&& g_iCurrentAdditionalHealth[client] > 0)
	{
		g_iCurrentAdditionalHealth[client] -= damage;
	}
}

public void OnPlayerDeath(Event event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid")), attacker = GetClientOfUserId(event.GetInt("attacker"));

	if((event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER) > 0
		|| attacker == 0 || attacker == client)
		return;

	int boss = FF2_GetBossIndex(attacker);
	if(FF2_HasAbility(boss, PLUGIN_NAME, ADDITIONAL_HEALTH_NAME))
	{
		int max = FF2_GetAbilityArgument(boss, PLUGIN_NAME, ADDITIONAL_HEALTH_NAME, ADDITIONAL_HEALTH_ON_KILL, 0);
		if(max > 0)
		{
			int addHealth = FF2_GetClientDamage(client) / 2;
			if(addHealth > max)
				addHealth = max;
			else if(addHealth <= 100)
				addHealth = 100;

			if(g_flAdditionalHealthMultiplierDuration[attacker] > GetGameTime())
				// *= operator doesn't work with float this time.
				addHealth = RoundFloat(addHealth * FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, ADDITIONAL_HEALTH_NAME, ON_KILL_ADDITIONAL_HEALTH_IN_DURATION, 1.0));

			AddAdditionalHealth(boss, addHealth);

			float stunDuration =
				FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, ADDITIONAL_HEALTH_NAME, ON_KILL_ADDITIONAL_HEALTH_STUN_DURATION, 0.0);
			if(stunDuration > 0.0)
				TF2_StunPlayer(attacker, stunDuration, 0.0, TF_STUNFLAG_BONKSTUCK|TF_STUNFLAG_THIRDPERSON|TF_STUNFLAG_NOSOUNDOREFFECT);

			// This was supposed for painis detail.
			if(FF2_GetAbilityArgument(boss, PLUGIN_NAME, ADDITIONAL_HEALTH_NAME, PAINIS_NOTICE, 0) > 0)
			{
				char bossName[64], sound[PLATFORM_MAX_PATH];
				KeyValues bossKv = FF2_GetBossKV(boss);
				FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, ADDITIONAL_HEALTH_NAME, PAINIS_EAT_NOTICE, sound, PLATFORM_MAX_PATH, "");

				for(int target = 1; target <= MaxClients; target++)
				{
					if(IsClientInGame(target))
					{
						GetCharacterName(bossKv, bossName, sizeof(bossName), target);
						CPrintToChat(target, "{olive}[FF2]{default} %T", "Eaten by Painis", target, bossName, client, addHealth);

						if(sound[0] != '\0')
							EmitSoundToAll(sound, attacker, 0, 140, 0, 0.6);
					}
				}
			}
		}
	}
}

public void FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));

	if(StrEqual(CLIP_ADD_NAME, abilityName))
	{
		SetWeaponClip(boss);
	}

	if(StrEqual(DELAY_ABILITY_NAME, abilityName))
	{
		DelayAbility(boss);
	}

	if(StrEqual(REGENERATE_ABILITY_NAME, abilityName))
	{
		// 스파이일 경우, 이 컨디션 안지우면 끝까지 남음
		TF2_RemovePlayerDisguise(client);
		TF2_RemoveCondition(client, TFCond_Cloaked);

		FF2_EquipBoss(boss);
	}

	if(StrEqual(SCREENFADE_ABILITY_NAME, abilityName))
	{
		InvokeScreenFade(boss);
	}

	if(StrEqual(HIDEHUD_ABILITY_NAME, abilityName))
	{
		InvokeHideHUD(boss);
	}

	if(StrEqual(PLAYERFADE_ABILITY_NAME, abilityName))
	{
		InvokePlayerFade(boss);
	}

	if(StrEqual(PLAYERWEAPONDROP_ABILITY_NAME, abilityName))
	{
		InvokePlayerWeaponDrop(boss, slot);
	}

	if(StrEqual(INSERT_ATTIBUTES_ABILITY_NAME, abilityName))
	{
		InvokeInsertAttributes(boss, slot);
	}

	if(StrEqual(ADDITIONAL_HEALTH_NAME, abilityName))
	{
		if(g_iCurrentAdditionalHealth[client] > 0)
		{
			float multiplier = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, ADDITIONAL_HEALTH_NAME, ADDITIONAL_HEALTH_DRAIN_RATE, 40.0);
			int drainHealth = RoundFloat(GetTickInterval() * multiplier);

			g_iCurrentAdditionalHealth[client] -= drainHealth;
			FF2_SetBossHealth(boss, FF2_GetBossHealth(boss) - drainHealth);
		}
	}

	if(StrEqual(ADD_ADDITIONAL_HEALTH_NAME, abilityName))
	{
		int addhealth = FF2_GetAbilityArgument(boss, PLUGIN_NAME, ADD_ADDITIONAL_HEALTH_NAME, "add health", 2000);
		AddAdditionalHealth(boss, addhealth);

		float duration = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, ADD_ADDITIONAL_HEALTH_NAME, "duration", 10.0);
		g_flAdditionalHealthMultiplierDuration[client] = GetGameTime() + duration;
	}
}

void AddAdditionalHealth(int boss, int addhealth)
{
	int health = FF2_GetBossHealth(boss);
	FF2_SetBossHealth(boss, health + addhealth);

	int client = GetClientOfUserId(FF2_GetBossUserId(boss));
	if(g_iCurrentAdditionalHealth[client] > 0)
		g_iCurrentAdditionalHealth[client] += addhealth;
	else
		g_iCurrentAdditionalHealth[client] = addhealth;
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

void InvokeInsertAttributes(int boss, int slot)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));
/*
	// NOTE: TF2Attrib_AddCustomPlayerAttribute Is only works for player.
	bool isWearable = FF2_GetAbilityArgument(boss, PLUGIN_NAME, INSERT_ATTIBUTES_ABILITY_NAME, "is wearable", 0, slot) > 0;
	int weapon = -1,
		weaponSlot = FF2_GetAbilityArgument(boss, PLUGIN_NAME, INSERT_ATTIBUTES_ABILITY_NAME, "weapon slot", 0, slot);

	if(!isWearable)
		weapon = GetPlayerWeaponSlot(client, weaponSlot);
	else
		weapon = TF2Util_GetPlayerWearable(client, weaponSlot);
*/
	char key[32], name[128];
	float value, duration;
	int loop = 1;

	do
	{
		Format(key, sizeof(key), "name %d", loop);
		FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, INSERT_ATTIBUTES_ABILITY_NAME, key, name, sizeof(name), "", slot);
		if(name[0] == '\0')
			break;

		Format(key, sizeof(key), "value %d", loop);
		value = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, INSERT_ATTIBUTES_ABILITY_NAME, key, 0.0, slot);

		Format(key, sizeof(key), "duration %d", loop);
		duration = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, INSERT_ATTIBUTES_ABILITY_NAME, key, 0.0, slot);

		TF2Attrib_AddCustomPlayerAttribute(client, name, value, duration);
	}
	while(loop++);
}

void InvokePlayerWeaponDrop(int boss, int slot)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss)),
		weaponSlot = FF2_GetAbilityArgument(boss, PLUGIN_NAME, PLAYERWEAPONDROP_ABILITY_NAME, "weapon slot", 0, slot);
	float duration = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, PLAYERWEAPONDROP_ABILITY_NAME, "duration", 6.0, slot);

	int team = GetClientTeam(client);
	for(int target = 1; target <= MaxClients; target++)
	{
		if(!IsClientInGame(target) || !IsPlayerAlive(target) || GetClientTeam(target) == team
			|| FF2_GetBossIndex(target) != -1)
			continue;

		int weapon = GetPlayerWeaponSlot(target, weaponSlot);
		if(IsValidEntity(weapon))
		{
			if(g_flWeaponDisabledTime[target] < GetGameTime())
			{
				g_hDisabledWeapon[target] = weapon;
				g_hDisabledWeaponSlot[target] = weaponSlot;
				g_hDroppedWeapons[target] = FF2_DropWeapon(target, weapon, DROPPED_DONTALLOW_SWAP);

				SDKHook(target, SDKHook_PostThink, OnWeaponDisableThink);

				SetEntityRenderMode(weapon, RENDER_TRANSCOLOR);
				SetEntityRenderColor(weapon, 255, 255, 255, 75);
			}

			g_flWeaponDisabledTime[target] = GetGameTime() + duration;
		}
	}
}

public void OnWeaponDisableThink(int client)
{
	if(FF2_GetRoundState() != 1 || !IsClientInGame(client) || !IsPlayerAlive(client)
	|| g_flWeaponDisabledTime[client] < GetGameTime())
	{
		int weapon = GetPlayerWeaponSlot(client, g_hDisabledWeaponSlot[client]);
		if(g_hDisabledWeapon[client] == weapon)
		{
			SetEntityRenderMode(weapon, RENDER_TRANSCOLOR);
			SetEntityRenderColor(weapon, 255, 255, 255, 255);
		}

		// NOTE: 스왑된 드롭 무기는 항상 서로의 인덱스가 맞음?
		if(IsValidEntity(g_hDroppedWeapons[client]))
			RemoveEntity(g_hDroppedWeapons[client]);

		g_hDroppedWeapons[client] = -1;
		g_hDisabledWeapon[client] = -1;
		g_hDisabledWeaponSlot[client] = -1;
		g_flWeaponDisabledTime[client] = 0.0;

		SDKUnhook(client, SDKHook_PostThink, OnWeaponDisableThink);
	}
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weaponSwitched, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if(FF2_GetRoundState() != 1 || !IsClientInGame(client) || !IsPlayerAlive(client))		return Plugin_Continue;

	bool bChange = false;
	int currentWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

	if(g_flWeaponDisabledTime[client] > GetGameTime())
	{
		if(IsValidEntity(weaponSwitched) && g_hDisabledWeapon[client] == weaponSwitched)
		{
			int remainTime = RoundFloat(g_flWeaponDisabledTime[client] - GetGameTime());
			PrintCenterText(client, "%T", "Weapon Disabled", client, remainTime);
			PrintToChat(client, "%T", "Weapon Disabled", client, remainTime);
		}

		int weapon = GetPlayerWeaponSlot(client, g_hDisabledWeaponSlot[client]);
		if(weapon == currentWeapon && currentWeapon == g_hDisabledWeapon[client])
		{
			bChange = true;
			buttons &= ~(IN_ATTACK|IN_ATTACK2|IN_ATTACK3);
			/*
			SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime()+0.3);
			SetEntPropFloat(client, Prop_Send, "m_flNextAttack", GetGameTime()+0.3);
			SetEntPropFloat(client, Prop_Send, "m_flStealthNextChangeTime", GetGameTime()+0.3);
			*/
		}
		else if(weapon != g_hDisabledWeapon[client])
		{
			g_flWeaponDisabledTime[client] = 0.0;
			OnWeaponDisableThink(client);
		}
	}

	int boss = FF2_GetBossIndex(client);
	if(boss != -1)
	{
		if(IsValidEntity(currentWeapon) && FF2_HasAbility(boss, PLUGIN_NAME, REPLACE_BUTTONS_NAME))
		{
			bChange = true;
			int disabled = GetDisabledButtons(boss, GetSlotOfWeapon(client, currentWeapon)),
				replace = GetReplaceButtons(boss, GetSlotOfWeapon(client, currentWeapon));

			if((buttons & disabled) > 0)
			{
				buttons &= ~(disabled);
				buttons |= replace;
			}
		}

		if(IsValidEntity(currentWeapon) && FF2_HasAbility(boss, PLUGIN_NAME, REMOVE_EMPTY_ABILITY_NAME))
		{
			int ammoType = GetEntProp(currentWeapon, Prop_Send, "m_iPrimaryAmmoType"),
				weaponSlot = GetSlotOfWeapon(client, currentWeapon);

			if(IsDetectWeaponEmpty(boss, weaponSlot))
			{
				// CPrintToChatAll("currentWeapon: %d: ammoType: %d, clip1: %d, ammo: %d", currentWeapon, ammoType, GetEntProp(currentWeapon, Prop_Data, "m_iClip1"), GetEntProp(client, Prop_Data, "m_iAmmo", _, ammoType));

				bool empty = false;
				if(GetEntProp(currentWeapon, Prop_Data, "m_iClip1") == 0 &&
					(ammoType == -1 || (ammoType != -1 && GetEntProp(client, Prop_Data, "m_iAmmo", _, ammoType) <= 0)))
				{
					empty = true;
				}

				if(empty)
				{
					RemoveEntity(currentWeapon);
					TryReplaceWeapon(client, boss, weaponSlot);
				}
			}
		}
	}

	return bChange ? Plugin_Changed : Plugin_Continue;
}

bool IsDetectWeaponEmpty(int boss, int weaponSlot)
{
	char key[32];
	Format(key, sizeof(key), "detect weapon slot %i", weaponSlot);
	return FF2_GetAbilityArgument(boss, PLUGIN_NAME, REMOVE_EMPTY_ABILITY_NAME, key, 0) > 0;
}

void TryReplaceWeapon(int client, int boss, int weaponSlot)
{
	char key[32];
	Format(key, sizeof(key), "replace weapon slot %i", weaponSlot);
	int slot = FF2_GetAbilityArgument(boss, PLUGIN_NAME, REMOVE_EMPTY_ABILITY_NAME, key, -1);
	if(slot > -1)
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", GetPlayerWeaponSlot(client, slot));
}

int GetDisabledButtons(int boss, int weaponSlot)
{
	char key[32];
	Format(key, sizeof(key), "detect weapon slot %i", weaponSlot);
	int buttons = FF2_GetAbilityArgument(boss, PLUGIN_NAME, REPLACE_BUTTONS_NAME, key, 0);
	return buttons;
}

int GetReplaceButtons(int boss, int weaponSlot)
{
	char key[32];
	Format(key, sizeof(key), "replace weapon slot %i", weaponSlot);
	int buttons = FF2_GetAbilityArgument(boss, PLUGIN_NAME, REPLACE_BUTTONS_NAME, key, 0);
	return buttons;
}

stock int GetSlotOfWeapon(int client, int weapon)
{
	for(int loop = 0; loop < 6; loop++)
	{
		int temp = GetPlayerWeaponSlot(client, loop);
		if(weapon == temp)
			return loop;
	}
	return -1;
}

public void FF2_OnCalledQueue(FF2HudQueue hudQueue, int client)
{
	char text[128];
	FF2HudDisplay hudDisplay = null;
	int boss = FF2_GetBossIndex(client);

	hudQueue.GetName(text, sizeof(text));
	if(StrEqual(text, "Player Additional"))
	{
		if(g_flWeaponDisabledTime[client] > GetGameTime())
		{
			int remainTime = RoundFloat(g_flWeaponDisabledTime[client] - GetGameTime());
			Format(text, sizeof(text), "%T", "Weapon Disabled Time", client, remainTime);
			hudDisplay = FF2HudDisplay.CreateDisplay("Weapon Disabled Time", text);
			hudQueue.PushDisplay(hudDisplay);
		}
	}
	else if(StrEqual(text, "Boss"))
	{
		if(FF2_HasAbility(boss, PLUGIN_NAME, ADDITIONAL_HEALTH_NAME)
			&& g_iCurrentAdditionalHealth[client] > 0)
		{
			Format(text, sizeof(text), "%T", "Extra HP", client, g_iCurrentAdditionalHealth[client]);
			hudDisplay = FF2HudDisplay.CreateDisplay("Extra HP", text);
			hudQueue.PushDisplay(hudDisplay);
		}
	}

	if(FF2_HasAbility(boss, PLUGIN_NAME, SIMPLE_HINT_NAME))
	{
		char phrase[64], languageId[8], display[128];
		GetLanguageInfo(GetClientLanguage(client), languageId, sizeof(languageId));

		//
		Format(phrase, sizeof(phrase), "hint %s: %s", text, languageId);
		FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, SIMPLE_HINT_NAME, phrase, display, sizeof(display));

		if(display[0] == '\0')
		{
			Format(phrase, sizeof(phrase), "hint %s", text, phrase);
			// "hint [Phrase Name]" is for server's language.
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, SIMPLE_HINT_NAME, phrase, display, sizeof(display));
		}

		if(display[0] != '\0')
		{
			hudDisplay = FF2HudDisplay.CreateDisplay(SIMPLE_HINT_NAME, display);
			hudQueue.PushDisplay(hudDisplay);
		}
	}
}

void InvokeScreenFade(int boss)
{
	bool able = false;

	int client = GetClientOfUserId(FF2_GetBossUserId(boss)),
		effectTo = FF2_GetAbilityArgument(boss, PLUGIN_NAME, SCREENFADE_ABILITY_NAME, "effect to", Effect_OtherTeam),
		color[4];

	color[0] = FF2_GetAbilityArgument(boss, PLUGIN_NAME, SCREENFADE_ABILITY_NAME, "red", 255);
	color[1] = FF2_GetAbilityArgument(boss, PLUGIN_NAME, SCREENFADE_ABILITY_NAME, "blue", 255);
	color[2] = FF2_GetAbilityArgument(boss, PLUGIN_NAME, SCREENFADE_ABILITY_NAME, "green", 255);
	color[3] = FF2_GetAbilityArgument(boss, PLUGIN_NAME, SCREENFADE_ABILITY_NAME, "alpha", 255);

	float duration = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, SCREENFADE_ABILITY_NAME, "duration", 6.0),
		holdTime = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, SCREENFADE_ABILITY_NAME, "hold time", 6.0);

	int team = GetClientTeam(client);
	for(int target = 1; target <= MaxClients; target++)
	{
		if(!IsClientInGame(target) || !IsPlayerAlive(target))
			continue;

		able = false;

		switch(effectTo)
		{
			case Effect_OtherTeam:
			{
				able = GetClientTeam(target) != team;
			}
			case Effect_Everyone:
			{
				able = true;
			}
			case Effect_OnlyInvoker:
			{
				able = target == client;
			}
			case Effect_OnlyHuman:
			{
				able = FF2_GetBossIndex(target) == -1;
			}
		}

		if(able)
			UTIL_ScreenFade(target, color, duration, holdTime);
	}
}

void InvokeHideHUD(int boss)
{
	bool able = false;

	int client = GetClientOfUserId(FF2_GetBossUserId(boss)),
		effectTo =  FF2_GetAbilityArgument(boss, PLUGIN_NAME, HIDEHUD_ABILITY_NAME, "effect to", Effect_OtherTeam);

	float duration = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, HIDEHUD_ABILITY_NAME, "duration", 6.0),
		presetTime = GetGameTime() + duration;

	int team = GetClientTeam(client);
	for(int target = 1; target <= MaxClients; target++)
	{
		if(!IsClientInGame(target) || !IsPlayerAlive(target))
			continue;

		able = false;

		switch(effectTo)
		{
			case Effect_OtherTeam:
			{
				able = GetClientTeam(target) != team;
			}
			case Effect_Everyone:
			{
				able = true;
			}
			case Effect_OnlyInvoker:
			{
				able = target == client;
			}
			case Effect_OnlyHuman:
			{
				able = FF2_GetBossIndex(target) == -1;
			}
		}

		if(able)
		{
			if(g_flHideHudTime[target] < GetGameTime())
			{
				SDKHook(target, SDKHook_PostThink, OnHideHUDThink);
			}

			g_flHideHudTime[target] = presetTime;
			SetEntProp(target, Prop_Data, "m_iHideHUD", HIDEHUD_FLAGS);
		}
	}
}

public void OnHideHUDThink(int client)
{
	if(FF2_GetRoundState() != 1 || !IsClientInGame(client) || !IsPlayerAlive(client)
	|| g_flHideHudTime[client] < GetGameTime())
	{
		g_flHideHudTime[client] = 0.0;

		SetEntProp(client, Prop_Data, "m_iHideHUD", 0);
		SDKUnhook(client, SDKHook_PostThink, OnHideHUDThink);
	}
}

void InvokePlayerFade(int boss)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));

	float duration = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, PLAYERFADE_ABILITY_NAME, "duration", 6.0),
		startFade = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, PLAYERFADE_ABILITY_NAME, "start fade", 600.0),
		endFade = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, PLAYERFADE_ABILITY_NAME, "end fade", 900.0);

	SetEntPropFloat(client, Prop_Send, "m_fadeMinDist", startFade);
	SetEntPropFloat(client, Prop_Send, "m_fadeMaxDist", endFade);

	if(g_flPlayerFadeTime[client] < GetGameTime())
		SDKHook(client, SDKHook_PostThink, OnPlayerFadeThink);

	g_flPlayerFadeTime[client] = GetGameTime() + duration;
}

public void OnPlayerFadeThink(int client)
{
	if(FF2_GetRoundState() != 1 || !IsClientInGame(client) || !IsPlayerAlive(client)
	|| g_flPlayerFadeTime[client] < GetGameTime())
	{
		g_flPlayerFadeTime[client] = 0.0;

		SetEntPropFloat(client, Prop_Send, "m_fadeMinDist", 0.0);
		SetEntPropFloat(client, Prop_Send, "m_fadeMaxDist", 0.0);
	}
}

void SetWeaponClip(int boss)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));
	char name[16];

	for(int loop = TFWeaponSlot_Primary; loop <= TFWeaponSlot_PDA; loop++)
	{
		Format(name, sizeof(name), "slot %d ammo", loop);
		int ammo = FF2_GetAbilityArgument(boss, PLUGIN_NAME, CLIP_ADD_NAME, name, -1);

		Format(name, sizeof(name), "slot %d clip", loop);
		int clip = FF2_GetAbilityArgument(boss, PLUGIN_NAME, CLIP_ADD_NAME, name, -1);

		// TODO: Find safe way for setting ammo of the clipless weapons.
		// NOTE: Those statements are hard-coding.
		if(ammo >= 0 && clip <= -1)
			SetAmmo(client, loop, ammo);
		else
			FF2_SetAmmo(client, GetPlayerWeaponSlot(client, loop), ammo, clip);
	}
}

void DelayAbility(int boss)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));

	g_flCurrentDelay[client] = GetGameTime() + FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, DELAY_ABILITY_NAME, "time", 6.0);
	RequestFrame(Delay_Update, boss);
}

public void Delay_Update(int boss)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss)), loop = 0, slot, buttonMode;
	char abilityName[128], pluginName[128], temp[128];

	if(FF2_GetRoundState() != 1)
		return;

	if(GetGameTime() > g_flCurrentDelay[client])
	{
		while(client > 0) // YEAH IT IS JUST 'TRUE'
		{
			loop++;

			Format(abilityName, sizeof(abilityName), "delay %d ability name", loop);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, DELAY_ABILITY_NAME, abilityName, abilityName, 128, "");

			Format(pluginName, sizeof(pluginName), "delay %d plugin name", loop);
			FF2_GetAbilityArgumentString(boss, PLUGIN_NAME, DELAY_ABILITY_NAME, pluginName, pluginName, 128, "");

			if(!strlen(abilityName) || !strlen(pluginName)) break;

			Format(temp, sizeof(temp), "delay %d slot", loop);
			slot = FF2_GetAbilityArgument(boss, PLUGIN_NAME, DELAY_ABILITY_NAME, temp, 0);

			Format(temp, sizeof(temp), "delay %d button mode", loop);
			buttonMode = FF2_GetAbilityArgument(boss, PLUGIN_NAME, DELAY_ABILITY_NAME, temp, 0);

			FF2_UseAbility(boss, pluginName, abilityName, slot, buttonMode);
		}

		return;
	}

	RequestFrame(Delay_Update, boss);
}

public void TF2_OnConditionAdded(int client, TFCond condition)
{
	int attacker = TF2Util_GetPlayerConditionProvider(client, condition),
		boss = FF2_GetBossIndex(attacker);
	if(boss == -1)	return;

	if(condition == TFCond_OnFire
		&& FF2_HasAbility(boss, PLUGIN_NAME, CHANGE_FIRE_DURATION))
	{
		float duration = FF2_GetAbilityArgumentFloat(boss, PLUGIN_NAME, CHANGE_FIRE_DURATION, "fire time", 0.0);
		TF2Util_SetPlayerBurnDuration(client, duration);
	}
}


// Copied from ff2_otokiru
stock int SetAmmo(int client, int slot, int ammo)
{
	int weapon = GetPlayerWeaponSlot(client, slot);
	if(IsValidEntity(weapon))
	{
		int iOffset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1)*4;
		int iAmmoTable = FindSendPropInfo("CTFPlayer", "m_iAmmo");
		SetEntData(client, iAmmoTable+iOffset, ammo, 4, true);
	}
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for(int client = 1; client <= MaxClients; client++)
	{
		g_flHideHudTime[client] = 0.0;
		g_flPlayerFadeTime[client] = 0.0;

		g_hDisabledWeapon[client] = -1;
		g_flWeaponDisabledTime[client] = 0.0;

		g_iCurrentAdditionalHealth[client] = 0;
		g_flAdditionalHealthMultiplierDuration[client] = 0.0;
	}
}
