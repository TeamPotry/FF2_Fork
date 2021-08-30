#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <freak_fortress_2>
#include <ff2_potry>
#include <tf2>
#include <tf2_stocks>
#include <morecolors>

#undef REQUIRE_PLUGIN
#tryinclude <goomba>
#define REQUIRE_PLUGIN

#pragma newdecls required

#define THIS_PLUGIN_NAME        "mario detail"

#define GOOMBA_BONUS            "goomba bonus"      // 굼바 시, 반동 대폭 증가와 분노 충
#define GOOMBA_IMMUNITY         "goomba immunity"   // 굼바 면역
#define STAR                    "star"              // 마리오 분노 능력

float g_flStarTime[MAXPLAYERS+1];
char g_strStarSoundPath[MAXPLAYERS+1][PLATFORM_MAX_PATH];

int g_hStarLight[MAXPLAYERS+1] = {-1, ...};
float g_flStarLastFlickTime[MAXPLAYERS+1];

static const int g_iRainbowColors[7][4] = {
	{255, 0, 0, 255},
	{255, 50, 0, 255},
	{255, 255, 0, 255},
	{0, 255, 0, 255},
	{0, 0, 255, 255},
	{0, 5, 255, 255},
	{100, 0, 255, 255}
};

public Plugin myinfo=
{
	name="Freak Fortress 2: Mario Abilities",
	author="Nopied◎",
	description="It's me.. mario...",
	version="1.0",
};

public void OnPluginStart()
{
	FF2_RegisterSubplugin(THIS_PLUGIN_NAME);
}

public void FF2_OnPlayBoss(int boss)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));

	g_flStarTime[client] = 0.0;
	g_hStarLight[client] = -1;
	FF2_GetAbilityArgumentString(boss, THIS_PLUGIN_NAME, STAR, "sound", g_strStarSoundPath[client], PLATFORM_MAX_PATH, "");
}

public void FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));
	if(!strcmp(abilityName, STAR))
	{
		Mario_Star_Start(client, slot);
	}
}

public Action OnStomp(int attacker, int victim, float &damageMultiplier, float &damageBonus, float &JumpPower)
{
    int boss = FF2_GetBossIndex(victim);
    if(boss != -1 && FF2_HasAbility(boss, THIS_PLUGIN_NAME, GOOMBA_IMMUNITY))
    {
        EmitStompParticles(victim);
        FF2_SpecialAttackToBoss(attacker, boss, _, "goomba", 0.0);
        return Plugin_Handled;
    }

    boss = FF2_GetBossIndex(attacker);
    if(boss != -1 && FF2_HasAbility(boss, THIS_PLUGIN_NAME, GOOMBA_BONUS))
    {
        JumpPower = 1600.0;
        return Plugin_Changed;
    }

    return Plugin_Continue;
}

public int OnStompPost(int attacker, int victim, float damageMultiplier, float damageBonus, float jumpPower)
{// WHy iS tHiS INT????
    int boss = FF2_GetBossIndex(attacker);
    if(boss != -1 && FF2_HasAbility(boss, THIS_PLUGIN_NAME, GOOMBA_BONUS))
    {
        FF2_AddBossCharge(boss, 0, 100.0);
    }
}

void Mario_Star_Start(int client, int slot)
{
    /*
        - 무지개 광채 표현
        // 분노 브금
        // 충돌 시 피해 판정 (보스 제외)
        // 이동속도 증가(다른 플러그인 사용)
        // 무적
        // 만약 시간 도중에 재발동 된 경우, 넉백 면역 부여
    */
	int boss = FF2_GetBossIndex(client);
	float time = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, STAR, "time", 10.0, slot);
	float volume = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, STAR, "sound volume", 1.0, slot);
	float pos[3];

	GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);

	if(g_flStarTime[client] < GetGameTime())
	{
		StartStarSoundAll(client, g_strStarSoundPath[client], volume);
		g_hStarLight[client] = MakeLightToParent(client, pos);

		SDKHook(client, SDKHook_StartTouchPost, OnTouchStar);
		SDKHook(client, SDKHook_TouchPost, OnTouchStar);
		SDKHook(client, SDKHook_PostThink, OnStarThink);
	}
    else
    {
		StopStarSoundAll(g_strStarSoundPath[client]);
		StartStarSoundAll(client, g_strStarSoundPath[client], volume);

		TF2_AddCondition(client, TFCond_MegaHeal, time);
    }

	TF2_AddCondition(client, TFCond_UberchargedHidden, time); // TODO: 테스트
	g_flStarTime[client] = GetGameTime() + time;
	g_flStarLastFlickTime[client] = GetGameTime();
}

void StartStarSoundAll(int owner, char[] sound, float volume)
{
	if(sound[0] == '\0')	return;
    EmitSoundToAll(sound, owner, 0, 140, 0, volume);
    // SNDCHAN_USER_BASE, SNDLEVEL_HELICOPTER, SNDVOL_NORMAL, SND_NOFLAGS, SNDPITCH_NORMAL
}

void StopStarSoundAll(char[] sound)
{
	if(sound[0] == '\0')	return;

	for(int target=1; target<=MaxClients; target++)
	{
		if(IsValidClient(target))
			StopSound(target, 0, sound);
	}
}

public void OnStarThink(int client)
{
    if(FF2_GetRoundState() != 1 || g_flStarTime[client] < GetGameTime())
    {
		if(IsValidEntity(g_hStarLight[client]))
			RemoveEntity(g_hStarLight[client]);
		g_hStarLight[client] = -1;

        g_flStarTime[client] = 0.0;

        SDKUnhook(client, SDKHook_StartTouchPost, OnTouchStar);
        SDKUnhook(client, SDKHook_TouchPost, OnTouchStar);
        SDKUnhook(client, SDKHook_PostThink, OnStarThink);

        StopStarSoundAll(g_strStarSoundPath[client]);
		return;
    }

	if(GetGameTime() - g_flStarLastFlickTime[client] > 0.15 && IsValidEntity(g_hStarLight[client]))
	{
		ChangeLightColor(g_hStarLight[client]);
		g_flStarLastFlickTime[client] = GetGameTime();
	}
}

public void OnTouchStar(int client, int other)
{
    if(IsValidClient(other) && !IsBoss(other))
        SDKHooks_TakeDamage(other, client, client, 1000.0,
            DMG_VEHICLE|DMG_SHOCK|DMG_ENERGYBEAM|DMG_DISSOLVE);
}

stock void ChangeLightColor(int light)
{
	char colors[20];
	int random = GetRandomInt(0, 6);

	// TODO: ?
	Format(colors, 20, "%d %d %d", g_iRainbowColors[random][0], g_iRainbowColors[random][1], g_iRainbowColors[random][2]);
	DispatchKeyValue(light, "rendercolor", colors);

	Format(colors, 20, "%s %d", colors, g_iRainbowColors[random][3]);
	DispatchKeyValue(light, "_light", colors);
}
stock int MakeLightToParent(int owner, float pos[3])
{
	pos[2] += 50.0;
	int Ent = CreateEntityByName("light_dynamic");
	DispatchKeyValue(Ent, "_light", "150 50 200 255");
	DispatchKeyValue(Ent, "brightness", "5");
	DispatchKeyValueFloat(Ent, "spotlight_radius", 400.0);
	DispatchKeyValueFloat(Ent, "distance", 600.0);
	DispatchKeyValue(Ent, "style", "0");
	DispatchKeyValue(Ent, "rendercolor", "150 50 200");
	DispatchSpawn(Ent);
	TeleportEntity(Ent, pos, NULL_VECTOR, NULL_VECTOR);
	SetVariantString("!activator");
	AcceptEntityInput(Ent, "SetParent", owner, Ent, 0);

	return Ent;
}

stock bool IsValidClient(int client)
{
    return (0 < client && client <= MaxClients && IsClientInGame(client));
}

stock bool IsBoss(int client)
{
    return FF2_GetBossIndex(client) != -1;
}
