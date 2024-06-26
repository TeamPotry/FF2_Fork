#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2attributes>
#include <dhooks>
#include <tf2utils>
#include <freak_fortress_2>
#include <ff2_modules/general>

#tryinclude <mannvsmann>

#define PLUGIN_VERSION "20240418"

public Plugin myinfo=
{
	name="Freak Fortress 2: Shotgun Special",
	author="Nopied◎",
	description="FF2: Shotgun's special abilities",
	version=PLUGIN_VERSION,
};

#define min(%1,%2)            (((%1) < (%2)) ? (%1) : (%2))
#define max(%1,%2)            (((%1) > (%2)) ? (%1) : (%2))

#define FOREACH_PLAYER(%1) for(int %1 = 1; %1 <= MaxClients; %1++)

enum
{
    Shotgun_Normal = 0,
    Shotgun_Vampire,
// #if defined _MVM_included
//     Shotgun_Gold,
// #endif

    ShotgunType_MAX  
};

bool g_bShotgunFired[MAXPLAYERS+1] = {false, ...};
int g_iCurrentShotgunType[MAXPLAYERS+1] = {Shotgun_Normal, ...};

int g_iPlayerShotgunType[MAXPLAYERS+1];
bool g_bPressed[MAXPLAYERS+1];

// Vampire
int g_iVampireHealRemaining[MAXPLAYERS+1];
float g_flVampireHealNextThinkTime[MAXPLAYERS+1];

public void OnPluginStart()
{
    LoadTranslations("ff2_extra_abilities.phrases");

    GameData gamedata = new GameData("potry");
    CreateDynamicDetour(gamedata, "CTFShotgun::PrimaryAttack", DHookCallback_PrimaryAttack_Pre);

    HookEvent("teamplay_round_start", OnRoundStart);
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	FOREACH_PLAYER(client)
	{
        g_iVampireHealRemaining[client] = 0;
        g_flVampireHealNextThinkTime[client] = 0.0;
	}

	return Plugin_Continue;
}

static void CreateDynamicDetour(GameData gamedata, const char[] name, DHookCallback callbackPre = INVALID_FUNCTION, DHookCallback callbackPost = INVALID_FUNCTION)
{
	DynamicDetour detour = DynamicDetour.FromConf(gamedata, name);
	if (detour)
	{
		if (callbackPre != INVALID_FUNCTION)
			detour.Enable(Hook_Pre, callbackPre);

		if (callbackPost != INVALID_FUNCTION)
			detour.Enable(Hook_Post, callbackPost);
	}
	else
	{
		LogError("Failed to create detour setup handle for %s", name);
	}
}

public MRESReturn DHookCallback_PrimaryAttack_Pre(int weapon)
{
    int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
    if(!IsValidClient(owner))                   return MRES_Ignored;

    int flags = FF2_GetFF2Flags(owner);
    if(flags & FF2FLAG_CLASSTIMERDISABLED)      return MRES_Ignored;

    ShotgunAbility_Ready(owner, g_iPlayerShotgunType[owner]);
    switch(g_iCurrentShotgunType[owner])
    {
        case Shotgun_Vampire:
        {
            ShotgunVampire_Init(owner);
        }
        // case Shotgun_Gold:
        // {
        // }
    }

    return MRES_Ignored;
}

public void OnClientPostAdminCheck(int client)
{
    g_iPlayerShotgunType[client] = Shotgun_Normal;
    SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& newWeapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
    if(!IsValidClient(client) || IsBoss(client))  return Plugin_Continue;
    
    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if(IsValidEntity(weapon))
    {
        // Is buttons called only once?
        if(!g_bPressed[client] && (buttons & IN_ATTACK2) > 0 && IsShotgun(weapon))
        {
            g_bPressed[client] = true;
            g_iPlayerShotgunType[client] = ++g_iPlayerShotgunType[client] % ShotgunType_MAX;

            RequestFrame(CancelFF2WeaponAbility, client);

            SetEntProp(weapon, Prop_Data, "m_iClip1", 0);

            FOREACH_PLAYER(target)
            {
                if(IsClientInGame(target))
                {
                    EmitSoundToClient(target, "weapons/shotgun_empty.wav", target, _, _, _, _, _, target);
                    EmitSoundToClient(target, "weapons/shotgun_empty.wav", target, _, _, _, _, _, target);
                }
            }
        }
        else if(g_bPressed[client] && !(buttons & IN_ATTACK2))
            g_bPressed[client] = false;

        
        // float attackTime = GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack");
        // if(attackTime < GetGameTime() 
        //     && (buttons & IN_ATTACK2) > 0)
        // {
        //     if(IsShotgun(weapon))
        //     {
        //         buttons &= ~IN_ATTACK2;
        //         buttons |= IN_ATTACK;
        //         bChanged = true;
        //     }
        // }
    }

    if(g_iVampireHealRemaining[client] > 0 
        && g_flVampireHealNextThinkTime[client] < GetGameTime())
    {
        g_iVampireHealRemaining[client]--;
        g_flVampireHealNextThinkTime[client] = GetGameTime() + (GetTickInterval() / 24.0); // medigun heal rate

        int maxHealth = TF2Util_GetPlayerMaxHealthBoost(client, false, false),
            currentHealth = GetEntProp(client, Prop_Data, "m_iHealth");

        if(currentHealth + 1 <= maxHealth)
            TF2Util_TakeHealth(client, 1.0, TAKEHEALTH_IGNORE_MAXHEALTH);

    }
    
    return Plugin_Continue;
}

static const char g_strShotgunAbilityTranslationToken[][] = {
    "Normal",
    "Vampire",
    // "Gold" // Deleted
    "ENDOFLINE"
};

public void FF2_OnCalledQueue(FF2HudQueue hudQueue, int client)
{
    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

    // NOTE: IsShotgun is quite heavy, on this call. 
    if(!IsValidEntity(weapon) || !IsShotgun(weapon))    return;
    SetGlobalTransTarget(client);

    FF2HudDisplay hudDisplay = null;
    char text[60];

    hudQueue.GetName(text, sizeof(text));

    if(StrEqual(text, "Player Additional"))
    {
        Format(text, sizeof(text), "Shotgun Ability %s",
            g_strShotgunAbilityTranslationToken[g_iPlayerShotgunType[client]]);
        Format(text, sizeof(text), "%t", text);
        Format(text, sizeof(text), "%t", "Shotgun Ability", text);

        hudDisplay = FF2HudDisplay.CreateDisplay("Shotgun Special", text);
        hudQueue.PushDisplay(hudDisplay);
    }
}

public Action OnTakeDamageAlive(int client, int& iAttacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
    if(!IsValidClient(iAttacker) 
        || !g_bShotgunFired[iAttacker] || !IsShotgun(weapon))    return Plugin_Continue;
    
    bool bChanged = false;

    switch(g_iCurrentShotgunType[iAttacker])
    {
        case Shotgun_Vampire:
        {
            bChanged = true;
            // damagetype = DMG_BUCKSHOT;

            static float healMaxCap = 30.0;
            float realDamage = damage;
            if(TF2_IsPlayerInCondition(iAttacker, TFCond_Buffed))
                realDamage *= 1.35;	

            float heal = min(healMaxCap, realDamage);
            g_iVampireHealRemaining[iAttacker] += RoundFloat(heal);
        }
// #if defined _MVM_included
//         case Shotgun_Gold:
//         {
//             static float cost = 100.0;
//             bChanged = true;

//             int money = MVM_GetPlayerCurrency(iAttacker);
//             float missingMoney = min(float(money) - cost, 0.0);
        
//             damage += cost + missingMoney;
//             MVM_SetPlayerCurrency(iAttacker, money - RoundFloat(cost + missingMoney));
//         }
// #endif
    }

    return bChanged ? Plugin_Changed : Plugin_Continue;
}

// On Fired
void ShotgunVampire_Init(int client)
{
	float tickInterval = GetTickInterval();

	TF2Attrib_AddCustomPlayerAttribute(client, "crits_become_minicrits", 1.0, tickInterval);
	TF2Attrib_AddCustomPlayerAttribute(client, "damage penalty", 0.5, tickInterval);
}

public void CancelFF2WeaponAbility(int client)
{
	g_bShotgunFired[client] = false;

    // Just in case
    // g_iCurrentShotgunType[client] = Shotgun_Normal;
}

void ShotgunAbility_Ready(int client, int type)
{
    g_bShotgunFired[client] = true;
    g_iCurrentShotgunType[client] = type;
}

bool IsShotgun(int weapon)
{
    char classname[64];
    GetEntityClassname(weapon, classname, sizeof(classname));

    if((StrContains(classname, "tf_weapon_shotgun") != -1
        || StrContains(classname, "tf_weapon_sentry_revenge") != -1
        || StrContains(classname, "tf_weapon_scattergun") != -1)
        // except this below.
        // TODO: NOT classname specific, use attribute.                 
        && !StrEqual(classname, "tf_weapon_shotgun_building_rescue")) 
    {
        return true;
    }

    return false;
}

stock bool IsValidClient(int client)
{
    return (0 < client && client <= MaxClients && IsClientInGame(client));
}

stock bool IsBoss(int client)
{
    return FF2_GetBossIndex(client) != -1;
}