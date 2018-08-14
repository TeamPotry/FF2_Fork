#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>
#include <morecolors>
#include <goomba>

new Handle:g_Cvar_StompMinSpeed = INVALID_HANDLE;
new Handle:g_Cvar_UberImun = INVALID_HANDLE;
new Handle:g_Cvar_CloakImun = INVALID_HANDLE;
new Handle:g_Cvar_StunImun = INVALID_HANDLE;
new Handle:g_Cvar_StompUndisguise = INVALID_HANDLE;
new Handle:g_Cvar_CloakedImun = INVALID_HANDLE;
new Handle:g_Cvar_BonkedImun = INVALID_HANDLE;
new Handle:g_Cvar_FriendlyFire = INVALID_HANDLE;

new Goomba_SingleStomp[MAXPLAYERS+1] = 0;

#define PL_NAME "Goomba Stomp TF2"
#define PL_DESC "Goomba Stomp TF2 plugin"
#define PL_VERSION "1.1.0"

public Plugin:myinfo =
{
    name = PL_NAME,
    author = "Flyflo",
    description = PL_DESC,
    version = PL_VERSION,
    url = "http://www.geek-gaming.fr"
}

public OnPluginStart()
{
    decl String:modName[32];
    GetGameFolderName(modName, sizeof(modName));

    if(!StrEqual(modName, "tf", false))
    {
        SetFailState("This plugin only works with Team Fortress 2");
    }

    LoadTranslations("goomba.phrases");

    g_Cvar_CloakImun = CreateConVar("goomba_cloak_immun", "1.0", "Prevent cloaked spies from stomping", 0, true, 0.0, true, 1.0);
    g_Cvar_StunImun = CreateConVar("goomba_stun_immun", "1.0", "Prevent stunned players from being stomped", 0, true, 0.0, true, 1.0);
    g_Cvar_UberImun = CreateConVar("goomba_uber_immun", "1.0", "Prevent ubercharged players from being stomped", 0, true, 0.0, true, 1.0);
    g_Cvar_StompUndisguise = CreateConVar("goomba_undisguise", "1.0", "Undisguise spies after stomping", 0, true, 0.0, true, 1.0);
    g_Cvar_CloakedImun = CreateConVar("goomba_cloaked_immun", "0.0", "Prevent cloaked spies from being stomped", 0, true, 0.0, true, 1.0);
    g_Cvar_BonkedImun = CreateConVar("goomba_bonked_immun", "1.0", "Prevent bonked scout from being stomped", 0, true, 0.0, true, 1.0);
    g_Cvar_FriendlyFire = CreateConVar("goomba_friendlyfire", "0.0", "Enable friendly fire, \"tf_avoidteammates\" and \"mp_friendlyfire\" must be set to 1", 0, true, 0.0, true, 1.0);

    AutoExecConfig(true, "goomba.tf");

    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);

    // Support for plugin late loading
    for (new client = 1; client <= MaxClients; client++)
    {
        if(IsClientInGame(client))
        {
            OnClientPutInServer(client);
        }
    }
}

public OnConfigsExecuted()
{
    g_Cvar_StompMinSpeed = FindConVar("goomba_minspeed");
    if(g_Cvar_StompMinSpeed == INVALID_HANDLE)
    {
        SetFailState("Unable to find the goomba_minspeed cvar, make sure goomba core plugin is correctly loaded.");
    }
}

public Action:OnStomp(attacker, victim, &Float:damageMultiplier, &Float:damageBonus, &Float:reboundPower)
{
    if(TF2_IsPlayerInCondition(victim, TFCond_Ubercharged) && !GetConVarBool(g_Cvar_UberImun))
    {
        TF2_RemoveCondition(victim, TFCond_Ubercharged);
    }

    return Plugin_Continue;
}

public OnClientPutInServer(client)
{
    SDKHook(client, SDKHook_StartTouch, OnStartTouch);
}

public Action:OnStartTouch(client, other)
{
    if(other > 0 && other <= MaxClients)
    {
        if(IsClientInGame(client) && IsPlayerAlive(client))
        {
            decl Float:ClientPos[3];
            decl Float:VictimPos[3];
            decl Float:VictimVecMaxs[3];
            GetClientAbsOrigin(client, ClientPos);
            GetClientAbsOrigin(other, VictimPos);
            GetEntPropVector(other, Prop_Send, "m_vecMaxs", VictimVecMaxs);
            new Float:victimHeight = VictimVecMaxs[2];
            new Float:HeightDiff = ClientPos[2] - VictimPos[2];

            if(HeightDiff > victimHeight)
            {
                decl Float:vec[3];
                GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vec);

                if(vec[2] < GetConVarFloat(g_Cvar_StompMinSpeed) * -1.0)
                {
                    if(Goomba_SingleStomp[client] == 0)
                    {
                        if(AreValidStompTargets(client, other))
                        {
                            new immunityResult = CheckStompImmunity(client, other);

                            if(immunityResult == GOOMBA_IMMUNFLAG_NONE)
                            {
                                if(GoombaStomp(client, other))
                                {
                                    PlayStompReboundSound(client);
                                    EmitStompParticles(other);
                                }
                                Goomba_SingleStomp[client] = 1;
                                CreateTimer(0.5, SinglStompTimer, client);
                            }
                            else if(immunityResult & GOOMBA_IMMUNFLAG_VICTIM)
                            {
                                CPrintToChat(client, "%t", "Victim Immun");
                            }
                        }
                    }
                }
            }
        }
    }

    return Plugin_Continue;
}

bool:AreValidStompTargets(client, victim)
{
    if(victim <= 0 || victim > MaxClients)
    {
        return false;
    }

    decl String:edictName[32];
    GetEdictClassname(victim, edictName, sizeof(edictName));

    if(!StrEqual(edictName, "player"))
    {
        return false;
    }
    if(!IsPlayerAlive(victim))
    {
        return false;
    }

    if(GetClientTeam(client) == GetClientTeam(victim))
    {
        if( !GetConVarBool(g_Cvar_FriendlyFire) ||
            !GetConVarBool(FindConVar("mp_friendlyfire")) ||
            GetConVarBool(FindConVar("tf_avoidteammates")))
        {
            return false;
        }
    }

    if(GetEntProp(victim, Prop_Data, "m_takedamage", 1) == 0)
    {
        return false;
    }

    if((GetConVarBool(g_Cvar_UberImun) && TF2_IsPlayerInCondition(victim, TFCond_Ubercharged)))
    {
        return false;
    }
    if(GetConVarBool(g_Cvar_StunImun) && TF2_IsPlayerInCondition(victim, TFCond_Dazed))
    {
        return false;
    }
    if(GetConVarBool(g_Cvar_CloakImun) && TF2_IsPlayerInCondition(client, TFCond_Cloaked))
    {
        return false;
    }
    if(GetConVarBool(g_Cvar_CloakedImun) && TF2_IsPlayerInCondition(victim, TFCond_Cloaked))
    {
        return false;
    }
    if(GetConVarBool(g_Cvar_BonkedImun) && TF2_IsPlayerInCondition(victim, TFCond_Bonked))
    {
        return false;
    }

    return true;
}


public Action:SinglStompTimer(Handle:timer, any:client)
{
    Goomba_SingleStomp[client] = 0;
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
    if(GetEventBool(event, "goomba"))
    {
        new victim = GetClientOfUserId(GetEventInt(event, "userid"));
        new killer = GetClientOfUserId(GetEventInt(event, "attacker"));

        // CPrintToChatAllEx(killer, "%t", "Goomba Stomp", killer, victim);

        new damageBits = GetEventInt(event, "damagebits");

        SetEventString(event, "weapon_logclassname", "goomba");
        SetEventString(event, "weapon", "taunt_scout");
        SetEventInt(event, "damagebits", damageBits |= DMG_ACID);
        SetEventInt(event, "customkill", 0);
        SetEventInt(event, "playerpenetratecount", 0);

        if(!(GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER))
        {
            PlayStompSound(victim);
            PrintHintText(victim, "%t", "Victim Stomped");
        }

        if(GetConVarBool(g_Cvar_StompUndisguise))
        {
            TF2_RemovePlayerDisguise(killer);
        }
    }

    return Plugin_Continue;
}
