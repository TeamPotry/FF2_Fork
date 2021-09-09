/*
===Freak Fortress 2===

By Rainbolt Dash: programmer, modeller, mapper, painter.
Author of Demoman The Pirate: http://www.randomfortress.ru/thepirate/
And one of two creators of Floral Defence: http://www.polycount.com/forum/showthread.php?t=73688
And author of VS Saxton Hale Mode
And notoriously famous for creating plugins with terrible code and then abandoning them.

Plugin thread on AlliedMods: http://forums.alliedmods.net/showthread.php?t=182108

Updated by Otokiru, Powerlord, and RavensBro after Rainbolt Dash got sucked into DOTA2

Updated by Wliu, Chris, Lawd, and Carge after Powerlord quit FF2
*/
#pragma semicolon 1

#include <sourcemod>
#include <clientprefs>
#include <freak_fortress_2>
#include <ff2_potry>

#undef REQUIRE_EXTENSIONS
#tryinclude <steamtools>
#define REQUIRE_EXTENSIONS
#undef REQUIRE_PLUGIN
#tryinclude <mannvsmann>
#include <db_simple>
#tryinclude <smac>
#tryinclude <updater>
#define REQUIRE_PLUGIN

#include <adt_array>
#include <morecolors>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2items>
#include <tf2attributes>
#include <tf2utils>
#include <tf2wearables>
#include <unixtime_sourcemod>

#include <stocksoup/tf/monster_resource>
#include <stocksoup/tf/econ>

#include "ff2_module/database.sp"
#include "ff2_module/global_var.sp"
#include "ff2_module/methodmap.sp"

#include "ff2_module/stocks.sp"

#include "ff2_module/hud.sp"
#include "ff2_module/music.sp"


#pragma newdecls required

#if defined _steamtools_included
bool steamtools;
#endif
bool mannvsmann = false;

int Incoming[MAXPLAYERS+1];

int Damage[MAXPLAYERS+1];
int Assist[MAXPLAYERS+1];
int uberTarget[MAXPLAYERS+1];
int shield[MAXPLAYERS+1];
int detonations[MAXPLAYERS+1];
int queuePoints[MAXPLAYERS+1];

int FF2Flags[MAXPLAYERS+1];

int BossHealthMax[MAXPLAYERS+1];
int BossHealth[MAXPLAYERS+1];
int BossHealthLast[MAXPLAYERS+1];
int BossLives[MAXPLAYERS+1];
int BossLivesMax[MAXPLAYERS+1];
int BossRageDamage[MAXPLAYERS+1];
float BossSpeed[MAXPLAYERS+1];
float BossCharge[MAXPLAYERS+1][8];
float BossMaxRageCharge[MAXPLAYERS+1];
float BossSkillDuration[MAXPLAYERS+1][3];

float Stabbed[MAXPLAYERS+1];
float Marketed[MAXPLAYERS+1];
float KSpreeTimer[MAXPLAYERS+1];
int KSpreeCount[MAXPLAYERS+1];
float GlowTimer[MAXPLAYERS+1];
int shortname[MAXPLAYERS+1];
bool emitRageSound[MAXPLAYERS+1];
bool bossHasReloadAbility[MAXPLAYERS+1];
bool bossHasRightMouseAbility[MAXPLAYERS+1];

int timeType;
float timeleft, maxTime;
int maxWave, currentWave;

// ConVar cvarVersion;
ConVar cvarPointDelay;
ConVar cvarAnnounce;
ConVar cvarEnabled;
ConVar cvarAliveToEnable;
ConVar cvarPointType;
ConVar cvarCrits;
ConVar cvarArenaRounds;
ConVar cvarCircuitStun;
ConVar cvarSpecForceBoss;
ConVar cvarEnableEurekaEffect;
ConVar cvarForceBossTeam;
ConVar cvarHealthBar;
ConVar cvarLastPlayerGlow;
ConVar cvarBossTeleporter;
ConVar cvarBossSuicide;
ConVar cvarShieldCrits;
ConVar cvarCaberDetonations;
ConVar cvarUpdater;
ConVar cvarDebug;
ConVar cvarPreroundBossDisconnect;
ConVar cvarTimerType;

Handle FF2Cookie_QueuePoints;

Menu changelogMenu;

Handle jumpHUD;
Handle rageHUD;
Handle livesHUD;
Handle timeleftHUD;
Handle abilitiesHUD;
Handle infoHUD;

bool Enabled=true;
bool Enabled2=true;
int PointDelay=6;
float Announce=120.0;
int AliveToEnable=5;
int PointType;
bool BossCrits=true;
int arenaRounds;
float circuitStun;
bool SpecForceBoss;
bool lastPlayerGlow=true;
bool bossTeleportation=true;
int shieldCrits;
int allowedDetonations;

Handle BossInfoTimer[MAXPLAYERS+1][2];
Handle doorCheckTimer;

int botqueuepoints;
float HPTime;
char currentmap[99];
bool checkDoors;
bool bMedieval;
bool firstBlood;

int tf_arena_preround_time;
int tf_arena_use_queue;
int mp_teams_unbalance_limit;
int tf_arena_first_blood;
int mp_forcecamera;
int tf_dropped_weapon_lifetime;
float tf_feign_death_activate_damage_scale;
float tf_feign_death_damage_scale;
char mp_humans_must_join_team[16];

ConVar cvarNextmap;

TFMonsterResource healthBar;
int g_Monoculus=-1;

static bool executed;

int changeGamemode;

enum
{
	SkillName_Rage = 0,
	SkillName_200Rage,
	SkillName_LostLife,

	SkillName_MaxCounts
}

static const char g_strSkillNameKey[][] = {
	"rage",
	"200 rage",
	"lost life"
};

//Handle kvWeaponSpecials;

Handle PreAbility;
Handle OnAbility;
Handle OnTriggerHurt;
Handle OnBossSelected;
Handle OnAddQueuePoints;
Handle OnLoadCharacterSet;
Handle OnLoseLife;
Handle OnAlivePlayersChanged;
Handle OnParseUnknownVariable;

// ff2_potry.inc
Handle OnWaveStarted;
Handle OnPlayBoss;
Handle OnSpecialAttack;
Handle OnSpecialAttack_Post;

public Plugin myinfo=
{
	name="Freak Fortress 2",
	author="Rainbolt Dash, FlaminSarge, Powerlord, the 50DKP team",
	description="RUUUUNN!! COWAAAARRDSS!",
	version=PLUGIN_VERSION,
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	char plugin[PLATFORM_MAX_PATH];
	GetPluginFilename(myself, plugin, sizeof(plugin));
	if(!StrContains(plugin, "freak_fortress_2/"))  //Prevent plugins/freak_fortress_2/freak_fortress_2.smx from loading if it exists -.-
	{
		strcopy(error, err_max, "There is a duplicate copy of Freak Fortress 2 inside the /plugins/freak_fortress_2 folder.  Please remove it");
		return APLRes_Failure;
	}

	CreateNative("FF2_IsFF2Enabled", Native_IsFF2Enabled);
	CreateNative("FF2_RegisterSubplugin", Native_RegisterSubplugin);
	CreateNative("FF2_UnregisterSubplugin", Native_UnregisterSubplugin);
	CreateNative("FF2_GetFF2Version", Native_GetFF2Version);
	CreateNative("FF2_GetRoundState", Native_GetRoundState);
	CreateNative("FF2_GetBossUserId", Native_GetBossUserId);
	CreateNative("FF2_GetBossIndex", Native_GetBossIndex);
	CreateNative("FF2_GetBossTeam", Native_GetBossTeam);
	CreateNative("FF2_GetBossName", Native_GetBossName);
	CreateNative("FF2_GetBossKV", Native_GetBossKV);
	CreateNative("FF2_GetBossHealth", Native_GetBossHealth);
	CreateNative("FF2_SetBossHealth", Native_SetBossHealth);
	CreateNative("FF2_GetBossMaxHealth", Native_GetBossMaxHealth);
	CreateNative("FF2_SetBossMaxHealth", Native_SetBossMaxHealth);
	CreateNative("FF2_GetBossLives", Native_GetBossLives);
	CreateNative("FF2_SetBossLives", Native_SetBossLives);
	CreateNative("FF2_GetBossMaxLives", Native_GetBossMaxLives);
	CreateNative("FF2_SetBossMaxLives", Native_SetBossMaxLives);
	CreateNative("FF2_GetBossCharge", Native_GetBossCharge);
	CreateNative("FF2_SetBossCharge", Native_SetBossCharge);
	CreateNative("FF2_GetBossRageDamage", Native_GetBossRageDamage);
	CreateNative("FF2_SetBossRageDamage", Native_SetBossRageDamage);
	CreateNative("FF2_GetBossRageDistance", Native_GetBossRageDistance);
	CreateNative("FF2_GetClientDamage", Native_GetClientDamage);
	CreateNative("FF2_SetClientDamage", Native_SetClientDamage);
	CreateNative("FF2_HasAbility", Native_HasAbility);
	CreateNative("FF2_GetAbilityArgument", Native_GetAbilityArgument);
	CreateNative("FF2_GetAbilityArgumentFloat", Native_GetAbilityArgumentFloat);
	CreateNative("FF2_GetAbilityArgumentString", Native_GetAbilityArgumentString);
	CreateNative("FF2_UseAbility", Native_UseAbility);
	CreateNative("FF2_GetFF2Flags", Native_GetFF2Flags);
	CreateNative("FF2_SetFF2Flags", Native_SetFF2Flags);
	CreateNative("FF2_GetQueuePoints", Native_GetQueuePoints);
	CreateNative("FF2_SetQueuePoints", Native_SetQueuePoints);
	CreateNative("FF2_GetClientGlow", Native_GetClientGlow);
	CreateNative("FF2_SetClientGlow", Native_SetClientGlow);
	CreateNative("FF2_Debug", Native_Debug);

	// ff2_module/music.sp
	CreateNative("FF2_StartMusic", Native_StartMusic);
	CreateNative("FF2_StopMusic", Native_StopMusic);
	CreateNative("FF2_FindSound", Native_FindSound);
	CreateNative("FF2_SetSoundFlags", Native_SetSoundFlags);
	CreateNative("FF2_ClearSoundFlags", Native_ClearSoundFlags);
	CreateNative("FF2_CheckSoundFlags", Native_CheckSoundFlags);

	// ff2_potry.inc
	CreateNative("FF2_AddBossCharge", Native_AddBossCharge);
	CreateNative("FF2_GetSettingData", Native_GetSettingData);
	CreateNative("FF2_GetSettingStringData", Native_GetSettingStringData);
	CreateNative("FF2_SetSettingData", Native_SetSettingData);
	CreateNative("FF2_SetSettingStringData", Native_SetSettingStringData);
	CreateNative("FF2_GetTimerType", Native_GetTimerType);
	CreateNative("FF2_GetRoundTime", Native_GetRoundTime);
	CreateNative("FF2_SetRoundTime", Native_SetRoundTime);
	CreateNative("FF2_GetClientAssist", Native_GetClientAssist);
	CreateNative("FF2_SetClientAssist", Native_SetClientAssist);
	CreateNative("FF2_EquipBoss", Native_EquipBoss);
	CreateNative("FF2_SpecialAttackToBoss", Native_SpecialAttackToBoss);
	CreateNative("FF2_GetCharacterKV", Native_GetCharacterKV);
	CreateNative("FF2_MakePlayerToBoss", Native_MakePlayerToBoss);
	CreateNative("FF2_GetBossCreatorFlags", Native_GetBossCreatorFlags);
	CreateNative("FF2_GetBossCreators", Native_GetBossCreators);

	OnWaveStarted=CreateGlobalForward("FF2_OnWaveStarted", ET_Hook, Param_Cell); // wave
	OnPlayBoss=CreateGlobalForward("FF2_OnPlayBoss", ET_Hook, Param_Cell); // Boss
	OnSpecialAttack=CreateGlobalForward("FF2_OnSpecialAttack", ET_Hook, Param_Cell, Param_Cell, Param_Cell, Param_String, Param_FloatByRef);
	OnSpecialAttack_Post=CreateGlobalForward("FF2_OnSpecialAttack_Post", ET_Hook, Param_Cell, Param_Cell, Param_String, Param_Float);
	OnCheckRules=CreateGlobalForward("FF2_OnCheckRules", ET_Hook, Param_Cell, Param_Cell, Param_CellByRef, Param_String, Param_String); // Client, characterIndex, chance, Rule String, value

	//ff2_module/hud.sp
	HudInit();

	PreAbility=CreateGlobalForward("FF2_PreAbility", ET_Hook, Param_Cell, Param_String, Param_String, Param_Cell, Param_CellByRef);  //Boss, plugin name, ability name, slot, enabled
	OnAbility=CreateGlobalForward("FF2_OnAbility", ET_Hook, Param_Cell, Param_String, Param_String, Param_Cell, Param_Cell);  //Boss, plugin name, ability name, slot, status
	OnMusic=CreateGlobalForward("FF2_OnMusic", ET_Hook, Param_Cell, Param_String, Param_CellByRef);
	OnTriggerHurt=CreateGlobalForward("FF2_OnTriggerHurt", ET_Hook, Param_Cell, Param_Cell, Param_FloatByRef);
	OnBossSelected=CreateGlobalForward("FF2_OnBossSelected", ET_Hook, Param_Cell, Param_CellByRef, Param_String, Param_Cell);  //Boss, character index, character name, preset
	OnAddQueuePoints=CreateGlobalForward("FF2_OnAddQueuePoints", ET_Hook, Param_Array);
	OnLoadCharacterSet=CreateGlobalForward("FF2_OnLoadCharacterSet", ET_Hook, Param_String);
	OnLoseLife=CreateGlobalForward("FF2_OnLoseLife", ET_Hook, Param_Cell, Param_CellByRef, Param_Cell);  //Boss, lives left, max lives
	OnAlivePlayersChanged=CreateGlobalForward("FF2_OnAlivePlayersChanged", ET_Hook, Param_Cell, Param_Cell);  //Players, bosses
	OnParseUnknownVariable=CreateGlobalForward("FF2_OnParseUnknownVariable", ET_Hook, Param_String, Param_FloatByRef);  //Variable, value

	RegPluginLibrary("freak_fortress_2");
	RegPluginLibrary("ff2_potry");

	subpluginArray=CreateArray(64); // Create this as soon as possible so that subplugins have access to it

	#if defined _steamtools_included
	MarkNativeAsOptional("Steam_SetGameDescription");
	#endif
	return APLRes_Success;
}

public void OnPluginStart()
{
	LogMessage("===Freak Fortress 2 Initializing-v%s===", PLUGIN_VERSION);

	// cvarVersion=CreateConVar("ff2_version", PLUGIN_VERSION, "Freak Fortress 2 Version", FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_SPONLY|FCVAR_DONTRECORD);
	cvarPointType=CreateConVar("ff2_point_type", "0", "0-Use ff2_point_alive, 1-Use ff2_point_time", _, true, 0.0, true, 1.0);
	cvarPointDelay=CreateConVar("ff2_point_delay", "6", "Seconds to add to the point delay per player", _, true, 0.0);
	cvarAliveToEnable=CreateConVar("ff2_point_alive", "5", "The control point will only activate when there are this many people or less left alive");
	cvarAnnounce=CreateConVar("ff2_announce", "150", "Amount of seconds to wait until FF2 info is displayed again.  0 to disable", _, true, 0.0);
	cvarEnabled=CreateConVar("ff2_enabled", "1", "0-Disable FF2 (WHY?), 1-Enable FF2", FCVAR_DONTRECORD, true, 0.0, true, 1.0);
	cvarCrits=CreateConVar("ff2_crits", "0", "Can the boss get random crits?", _, true, 0.0, true, 1.0);
	cvarArenaRounds=CreateConVar("ff2_arena_rounds", "1", "Number of rounds to make arena before switching to FF2 (helps for slow-loading players)", _, true, 0.0);
	cvarCircuitStun=CreateConVar("ff2_circuit_stun", "0.3", "Amount of seconds the Short Circuit stuns the boss for.  0 to disable", _, true, 0.0);
	cvarSpecForceBoss=CreateConVar("ff2_spec_force_boss", "0", "0-Spectators are excluded from the queue system, 1-Spectators are counted in the queue system", _, true, 0.0, true, 1.0);
	cvarEnableEurekaEffect=CreateConVar("ff2_enable_eureka", "0", "0-Disable the Eureka Effect, 1-Enable the Eureka Effect", _, true, 0.0, true, 1.0);
	cvarForceBossTeam=CreateConVar("ff2_force_team", "0", "0-Boss is always on Blu, 1-Boss is on a random team each round, 2-Boss is always on Red", _, true, 0.0, true, 3.0);
	cvarHealthBar=CreateConVar("ff2_health_bar", "1", "0-Disable the health bar, 1-Show the health bar", _, true, 0.0, true, 1.0);
	cvarLastPlayerGlow=CreateConVar("ff2_last_player_glow", "1", "0-Don't outline the last player, 1-Outline the last player alive", _, true, 0.0, true, 1.0);
	cvarBossTeleporter=CreateConVar("ff2_boss_teleporter", "1", "-1 to disallow all bosses from using teleporters, 0 to use TF2 logic, 1 to allow all bosses", _, true, -1.0, true, 1.0);
	cvarBossSuicide=CreateConVar("ff2_boss_suicide", "0", "Allow the boss to suicide after the round starts?", _, true, 0.0, true, 1.0);
	cvarPreroundBossDisconnect=CreateConVar("ff2_replace_disconnected_boss", "1", "If a boss disconnects before the round starts, use the next player in line instead? 0 - No, 1 - Yes", _, true, 0.0, true, 1.0);
	cvarCaberDetonations=CreateConVar("ff2_caber_detonations", "5", "Amount of times somebody can detonate the Ullapool Caber");
	cvarShieldCrits=CreateConVar("ff2_shield_crits", "1", "0 to disable grenade launcher crits when equipping a shield, 1 for minicrits, 2 for crits", _, true, 0.0, true, 2.0);
	cvarUpdater=CreateConVar("ff2_updater", "1", "0-Disable Updater support, 1-Enable automatic updating (recommended, requires Updater)", _, true, 0.0, true, 1.0);
	cvarDebug=CreateConVar("ff2_debug", "0", "0-Disable FF2 debug output, 1-Enable debugging (not recommended)", _, true, 0.0, true, 1.0);
	cvarTimerType=CreateConVar("ff2_timer_type", "0", "0-Disable FF2 round timer, 1-Enable round timer, 2-Enable wave timer", _, true, 0.0, true, 2.0);


	HookEvent("teamplay_round_start", OnRoundStart);
	HookEvent("teamplay_round_win", OnRoundEnd);
	HookEvent("teamplay_broadcast_audio", OnBroadcast, EventHookMode_Pre);
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Pre);
	HookEvent("post_inventory_application", OnPostInventoryApplication, EventHookMode_Pre);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
	HookEvent("player_chargedeployed", OnUberDeployed);
	HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Pre);
	HookEvent("object_destroyed", OnObjectDestroyed, EventHookMode_Pre);
	HookEvent("object_deflected", OnObjectDeflected, EventHookMode_Pre);
	HookEvent("deploy_buff_banner", OnDeployBackup);
	HookEvent("player_healed", OnPlayerHealed);

	HookUserMessage(GetUserMessageId("PlayerJarated"), OnJarate);  //Used to subtract rage when a boss is jarated (not through Sydney Sleeper)

	AddCommandListener(OnCallForMedic, "voicemenu");    //Used to activate rages
	AddCommandListener(OnSuicide, "explode");           //Used to stop boss from suiciding
	AddCommandListener(OnSuicide, "kill");              //Used to stop boss from suiciding
	AddCommandListener(OnSuicide, "spectate");			//Used to stop boss from suiciding
	AddCommandListener(OnJoinTeam, "jointeam");         //Used to make sure players join the right team
	AddCommandListener(OnJoinTeam, "autoteam");         //Used to make sure players don't kill themselves and change team
	AddCommandListener(OnChangeClass, "joinclass");     //Used to make sure bosses don't change class

	cvarEnabled.AddChangeHook(CvarChange);
	cvarPointDelay.AddChangeHook(CvarChange);
	cvarAnnounce.AddChangeHook(CvarChange);
	cvarPointType.AddChangeHook(CvarChange);
	cvarAliveToEnable.AddChangeHook(CvarChange);
	cvarCrits.AddChangeHook(CvarChange);
	cvarCircuitStun.AddChangeHook(CvarChange);
	cvarHealthBar.AddChangeHook(HealthbarEnableChanged);
	cvarLastPlayerGlow.AddChangeHook(CvarChange);
	cvarSpecForceBoss.AddChangeHook(CvarChange);
	cvarBossTeleporter.AddChangeHook(CvarChange);
	cvarShieldCrits.AddChangeHook(CvarChange);
	cvarCaberDetonations.AddChangeHook(CvarChange);
	cvarUpdater.AddChangeHook(CvarChange);
	cvarNextmap=FindConVar("sm_nextmap");
	cvarNextmap.AddChangeHook(CvarChangeNextmap);

	RegConsoleCmd("ff2", FF2Panel);
	RegConsoleCmd("ff2_advance", AdvanceMenu);
	RegConsoleCmd("ff2_hp", Command_GetHPCmd);
	RegConsoleCmd("ff2_next", QueuePanelCmd);
	RegConsoleCmd("ff2_classinfo", Command_HelpPanelClass);
	RegConsoleCmd("ff2_changelog", Command_ShowChangelog);
	RegConsoleCmd("ff2_music", MusicTogglePanelCmd);
	RegConsoleCmd("ff2_voice", VoiceTogglePanelCmd);
	RegConsoleCmd("ff2_resetpoints", ResetQueuePointsCmd);

	RegConsoleCmd("nextmap", Command_Nextmap);
	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say_team", Command_Say);

	RegAdminCmd("ff2_special", Command_SetNextBoss, ADMFLAG_CHEATS, "Usage:  ff2_special <boss>.  Forces next round to use that boss");
	RegAdminCmd("ff2_addpoints", Command_Points, ADMFLAG_CHEATS, "Usage:  ff2_addpoints <target> <points>.  Adds queue points to any player");
	RegAdminCmd("ff2_point_enable", Command_Point_Enable, ADMFLAG_CHEATS, "Enable the control point if ff2_point_type is 0");
	RegAdminCmd("ff2_point_disable", Command_Point_Disable, ADMFLAG_CHEATS, "Disable the control point if ff2_point_type is 0");
	RegAdminCmd("ff2_start_music", Command_StartMusic, ADMFLAG_CHEATS, "Start the Boss's music");
	RegAdminCmd("ff2_stop_music", Command_StopMusic, ADMFLAG_CHEATS, "Stop any currently playing Boss music");
	RegAdminCmd("ff2_resetqueuepoints", ResetQueuePointsCmd, ADMFLAG_CHEATS, "Reset a player's queue points");
	RegAdminCmd("ff2_resetq", ResetQueuePointsCmd, ADMFLAG_CHEATS, "Reset a player's queue points");
	RegAdminCmd("ff2_charset", Command_Charset, ADMFLAG_CHEATS, "Usage:  ff2_charset <charset>.  Forces FF2 to use a given character set");
	RegAdminCmd("ff2_reload_subplugins", Command_ReloadSubPlugins, ADMFLAG_RCON, "Reload FF2's subplugins.");

	AutoExecConfig(true, "freak_fortress_2", "sourcemod/freak_fortress_2");

	FF2Cookie_QueuePoints=RegClientCookie("ff2_cookie_queuepoints", "Client's queue points", CookieAccess_Protected);

	jumpHUD=CreateHudSynchronizer();
	rageHUD=CreateHudSynchronizer();
	livesHUD=CreateHudSynchronizer();
	abilitiesHUD=CreateHudSynchronizer();
	timeleftHUD=CreateHudSynchronizer();
	infoHUD=CreateHudSynchronizer();

	bossesArray = new ArrayList();
	bossesArrayOriginal = new ArrayList();

	LoadTranslations("freak_fortress_2.phrases");
	LoadTranslations("common.phrases");

	AddNormalSoundHook(HookSound);

	AddMultiTargetFilter("@hale", BossTargetFilter, "all current Bosses", false);
	AddMultiTargetFilter("@!hale", BossTargetFilter, "all non-Boss players", false);
	AddMultiTargetFilter("@boss", BossTargetFilter, "all current Bosses", false);
	AddMultiTargetFilter("@!boss", BossTargetFilter, "all non-Boss players", false);

	#if defined _steamtools_included
	steamtools=LibraryExists("SteamTools");
	#endif

	#if defined _MVM_included
	mannvsmann=LibraryExists("mannvsmann");
	#endif
}

public bool BossTargetFilter(const char[] pattern, Handle clients)
{
	bool non=StrContains(pattern, "!", false)!=-1;
	for(int client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client) && FindValueInArray(clients, client)==-1)
		{
			if(Enabled && IsBoss(client))
			{
				if(!non)
				{
					PushArrayCell(clients, client);
				}
			}
			else if(non)
			{
				PushArrayCell(clients, client);
			}
		}
	}
	return true;
}

public void OnLibraryAdded(const char[] name)
{
	#if defined _steamtools_included
	if(StrEqual(name, "SteamTools", false))
	{
		steamtools=true;
	}
	#endif

	#if defined _MVM_included
	if(StrEqual(name, "mannvsmann", false))
	{
		mannvsmann = true;
	}
	#endif

	#if defined _updater_included && !defined DEV_REVISION
	if(StrEqual(name, "updater") && cvarUpdater.BoolValue)
	{
		Updater_AddPlugin(UPDATE_URL);
	}
	#endif
}

public void OnLibraryRemoved(const char[] name)
{
	#if defined _steamtools_included
	if(StrEqual(name, "SteamTools", false))
	{
		steamtools=false;
	}
	#endif

	#if defined _MVM_included
	if(StrEqual(name, "mannvsmann", false))
	{
		mannvsmann = false;
	}
	#endif

	#if defined _updater_included
	if(StrEqual(name, "updater"))
	{
		Updater_RemovePlugin();
	}
	#endif
}

public void OnConfigsExecuted()
{
	tf_arena_preround_time=FindConVar("tf_arena_preround_time").IntValue;
	tf_arena_use_queue=FindConVar("tf_arena_use_queue").IntValue;
	mp_teams_unbalance_limit=FindConVar("mp_teams_unbalance_limit").IntValue;
	tf_arena_first_blood=FindConVar("tf_arena_first_blood").IntValue;
	mp_forcecamera=FindConVar("mp_forcecamera").IntValue;
	tf_dropped_weapon_lifetime=FindConVar("tf_dropped_weapon_lifetime").BoolValue;
	tf_feign_death_activate_damage_scale=FindConVar("tf_feign_death_activate_damage_scale").FloatValue;
	tf_feign_death_damage_scale=FindConVar("tf_feign_death_damage_scale").FloatValue;
	FindConVar("mp_humans_must_join_team").GetString(mp_humans_must_join_team, sizeof(mp_humans_must_join_team));

	if(IsFF2Map() && cvarEnabled.BoolValue)
	{
		EnableFF2();
	}
	else
	{
		DisableFF2();
	}

	#if defined _updater_included && !defined DEV_REVISION
	if(LibraryExists("updater") && cvarUpdater.BoolValue)
	{
		Updater_AddPlugin(UPDATE_URL);
	}
	#endif
}

public void OnMapStart()
{
	HPTime=0.0;
	doorCheckTimer=null;
	RoundCount=0;
	for(int client; client<=MaxClients; client++)
	{
		KSpreeTimer[client]=0.0;
		FF2Flags[client]=0;
		Incoming[client]=-1;
		MusicTimer[client]=null;
	}

	Handle temp;
	for(int index; index < bossesArray.Length; index++)
	{
		temp = view_as<Handle>(bossesArray.Get(index));
		if(temp != null)
		{
			delete temp;
			bossesArray.Set(index, INVALID_HANDLE);
		}
		temp = view_as<Handle>(bossesArrayOriginal.Get(index));
		if(temp != null)
		{
			delete temp;
			bossesArrayOriginal.Set(index, INVALID_HANDLE);
		}
	}

	bossesArray.Clear();
	bossesArrayOriginal.Clear();
}

public void OnMapEnd()
{
	if(Enabled || Enabled2)
	{
		DisableFF2();  //This resets all the variables for safety
	}
}

public void OnPluginEnd()
{
	OnMapEnd();
}

public void EnableFF2()
{
	Enabled=true;
	Enabled2=true;

	char config[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, config, sizeof(config), "%s/%s", FF2_SETTINGS, WEAPONS_CONFIG);

	if(kvWeaponMods!=null)
	{
		delete kvWeaponMods;
	}

	kvWeaponMods=new KeyValues("FF2Weapons");

	if(!kvWeaponMods.ImportFromFile(config))
	{
		LogError("[FF2 Configs] Failed to load weapon configuration file!");
		Enabled=false;
		Enabled2=false;
		return;
	}

	ParseChangelog();

	if(kvHudConfigs != null)
		delete kvHudConfigs;
	kvHudConfigs=LoadHudConfig();

	//Cache cvars
	// SetConVarString(FindConVar("ff2_version"), PLUGIN_VERSION);
	Announce=cvarAnnounce.FloatValue;
	PointType=cvarPointType.IntValue;
	PointDelay=cvarPointDelay.IntValue;
	AliveToEnable=cvarAliveToEnable.IntValue;
	BossCrits=cvarCrits.BoolValue;
	arenaRounds=cvarArenaRounds.IntValue;
	circuitStun=cvarCircuitStun.FloatValue;
	lastPlayerGlow=cvarLastPlayerGlow.BoolValue;
	bossTeleportation=cvarBossTeleporter.BoolValue;
	shieldCrits=cvarShieldCrits.IntValue;
	allowedDetonations=cvarCaberDetonations.IntValue;

	//Set some Valve cvars to what we want them to be
	FindConVar("tf_arena_use_queue").SetInt(0);
	FindConVar("mp_teams_unbalance_limit").SetInt(0);
	FindConVar("tf_arena_first_blood").SetInt(0);
	FindConVar("mp_forcecamera").SetInt(0);
	FindConVar("tf_dropped_weapon_lifetime").SetInt(0);
	FindConVar("tf_feign_death_activate_damage_scale").SetFloat(0.5);
	FindConVar("tf_feign_death_damage_scale").SetFloat(0.0);
	FindConVar("mp_humans_must_join_team").SetString("any");

	float time=Announce;
	if(time>1.0)
	{
		CreateTimer(time, Timer_Announce, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}

	CheckToChangeMapDoors();
	MapHasMusic(true);
	FindCharacters();
	strcopy(FF2CharSetString, 2, "");

	bMedieval=FindEntityByClassname(-1, "tf_logic_medieval")!=-1 || FindConVar("tf_medieval").BoolValue;
	FindHealthBar();

	#if defined _steamtools_included
	if(steamtools)
	{
		char gameDesc[64];
		Format(gameDesc, sizeof(gameDesc), "Freak Fortress 2 (%s)", PLUGIN_VERSION);
		Steam_SetGameDescription(gameDesc);
	}
	#endif

	changeGamemode=0;
}

public void DisableFF2()
{
	Enabled=false;
	Enabled2=false;

	FindConVar("tf_arena_use_queue").SetInt(tf_arena_use_queue);
	FindConVar("mp_teams_unbalance_limit").SetInt(mp_teams_unbalance_limit);
	FindConVar("tf_arena_first_blood").SetInt(tf_arena_first_blood);
	FindConVar("mp_forcecamera").SetInt(mp_forcecamera);
	FindConVar("tf_dropped_weapon_lifetime").SetInt(tf_dropped_weapon_lifetime);
	FindConVar("tf_feign_death_activate_damage_scale").SetFloat(tf_feign_death_activate_damage_scale);
	FindConVar("tf_feign_death_damage_scale").SetFloat(tf_feign_death_damage_scale);
	FindConVar("mp_humans_must_join_team").SetString(mp_humans_must_join_team);

	if(doorCheckTimer!=null)
	{
		KillTimer(doorCheckTimer);
		doorCheckTimer=null;
	}

	for(int client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client))
		{
			if(BossInfoTimer[client][1]!=null)
			{
				delete BossInfoTimer[client][1];
			}
		}

		if(MusicTimer[client]!=null)
		{
			delete MusicTimer[client];
		}

		bossHasReloadAbility[client]=false;
		bossHasRightMouseAbility[client]=false;
	}

	#if defined _steamtools_included
	if(steamtools)
	{
		Steam_SetGameDescription("Team Fortress");
	}
	#endif

	changeGamemode=0;
}

public void FindCharacters()
{
	char config[PLATFORM_MAX_PATH], charset[42];
	BuildPath(Path_SM, config, sizeof(config), "%s/%s", FF2_SETTINGS, BOSS_CONFIG);

	if(!FileExists(config))
	{
		LogError("[FF2 Bosses] Disabling Freak Fortress 2 - can not find %s!", config);
		Enabled2=false;
		return;
	}

	if(kvCharacterConfig!=null)
		delete kvCharacterConfig;

	kvCharacterConfig=new KeyValues("");
	kvCharacterConfig.ImportFromFile(config);

	Action action;
	Call_StartForward(OnLoadCharacterSet);
	strcopy(charset, sizeof(charset), FF2CharSetString);
	Call_PushStringEx(charset, sizeof(charset), SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_Finish(action);
	if(action==Plugin_Changed)
	{
		if(strlen(charset))
		{
			int i;

			kvCharacterConfig.Rewind();
			while(kvCharacterConfig.GotoNextKey())
			{
				kvCharacterConfig.GetSectionName(config, sizeof(config));
				if(StrEqual(config, charset))
				{
					FF2CharSet=i;
					strcopy(FF2CharSetString, sizeof(FF2CharSetString), charset);
					break;
				}
				i++;
			}
		}
	}

	kvCharacterConfig.Rewind();
	kvCharacterConfig.JumpToKey(FF2CharSetString); // This *should* always return true

	if(kvCharacterConfig.GotoFirstSubKey(false))
	{
		int index;
		do
		{
			kvCharacterConfig.GetSectionName(config, sizeof(config));
			LoadCharacter(config);
			index++;
		}
		while(kvCharacterConfig.GotoNextKey(false));
	}
	else
	{
		LogError("[FF2 Bosses] Disabling Freak Fortress 2 - no bosses in character set %s!", FF2CharSetString);
		Enabled2=false;
		return;
	}

	if(FileExists("sound/saxton_hale/9000.wav", true))
	{
		AddFileToDownloadsTable("sound/saxton_hale/9000.wav");
		PrecacheSound("saxton_hale/9000.wav", true);
	}

	if(FileExists("sound/potry_v2/se/homerun_bat.wav", true))
	{
		AddFileToDownloadsTable("sound/potry_v2/se/homerun_bat.wav");
		PrecacheSound("potry_v2/se/homerun_bat.wav", true);
	}
	PrecacheSound("vo/announcer_am_capincite01.mp3", true);
	PrecacheSound("vo/announcer_am_capincite03.mp3", true);
	PrecacheSound("vo/announcer_am_capenabled01.mp3", true);
	PrecacheSound("vo/announcer_am_capenabled02.mp3", true);
	PrecacheSound("vo/announcer_am_capenabled03.mp3", true);
	PrecacheSound("vo/announcer_am_capenabled04.mp3", true);
	PrecacheSound("weapons/barret_arm_zap.wav", true);
	PrecacheSound("vo/announcer_ends_5min.mp3", true);
	PrecacheSound("vo/announcer_ends_2min.mp3", true);
	PrecacheSound("player/doubledonk.wav", true);
	isCharSetSelected=false;
}

stock void ParseChangelog()
{
	KeyValues kv=LoadChangelog();
	if(kv == null)	return;

	changelogMenu=CreateMenu(Handler_ChangelogMenu);
	changelogMenu.SetTitle("%t", "Changelog");

	int id;
	if(kv.GotoFirstSubKey())
	{
		char version[64], temp[70];
		do
		{
			kv.GetSectionName(version, sizeof(version));
			kv.GetSectionSymbol(id);
			Format(temp, sizeof(temp), "%i", id);
			changelogMenu.AddItem(temp, version);
		}
		while(kv.GotoNextKey());

		delete kv;
	}
	else
	{
		LogError("[FF2] Changelog is empty!");
	}
}

stock KeyValues LoadChangelog()
{
	char changelog[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, changelog, sizeof(changelog), "%s/%s", FF2_SETTINGS, CHANGELOG);
	if(!FileExists(changelog))
	{
		LogError("[FF2] Changelog %s does not exist!", changelog);
		return null;
	}

	ChangeLogLastTime = GetFileTime(changelog, FileTime_LastChange);
	KeyValues kv=new KeyValues("Changelog");
	kv.ImportFromFile(changelog);

	return kv;
}

public void LoadCharacter(const char[] characterName)
{
	char config[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, config, sizeof(config), "%s/%s.cfg", FF2_CONFIGS, characterName);
	if(!FileExists(config))
	{
		LogError("[FF2 Bosses] Character %s does not exist!", characterName);
		return;
	}

	KeyValues kv=new KeyValues("character");
	bossesArray.Push(kv);
	kv.ImportFromFile(config);

	kv=new KeyValues("character");
	bossesArrayOriginal.Push(kv);
	kv.ImportFromFile(config);

	int version=kv.GetNum("version", 1);
	// if(version!=StringToInt(MAJOR_REVISION))
	if(version<=1)
	{
		LogError("[FF2 Bosses] Character %s is only compatible with FF2 v%i!", characterName, version);
		return;
	}

	if(kv.JumpToKey("abilities"))
	{
		if(kv.GotoFirstSubKey())
		{
			char pluginName[64];
			do
			{
				kv.GetSectionName(pluginName, sizeof(pluginName));
				if(FindStringInArray(subpluginArray, pluginName)<0)
				{
					LogError("[FF2 Bosses] Character %s needs plugin %s!", characterName, pluginName);
					return;
				}
			}
			while(kv.GotoNextKey());
		}
	}
	kv.Rewind();

	char file[PLATFORM_MAX_PATH], filePath[PLATFORM_MAX_PATH];
	char extensions[][]={".mdl", ".dx80.vtx", ".dx90.vtx", ".sw.vtx", ".vvd"};
	kv.SetString("filename", characterName);
	kv.GetString("name", config, sizeof(config));

	if(kv.JumpToKey("sounds"))
	{
		kv.GotoFirstSubKey();

		do
		{
			kv.GetSectionName(file, sizeof(file));
			Format(filePath, sizeof(filePath), "sound/%s", file);

			if(FileExists(filePath, true))
			{
				// LogMessage("Precache ''%s''\n = %s", filePath, PrecacheSound(file) ? "YES" : "NO");
				PrecacheSound(file); // PrecacheSound is relative to the sounds/ folder
			}
			else
			{
				LogError("[FF2 Bosses] Character %s is missing file '%s'!", characterName, filePath);
			}

			if(kv.GetNum("download", 0)>0)
			{
				if(FileExists(filePath, true))
				{
					// LogMessage("Add to Download ''%s''", filePath);
					AddFileToDownloadsTable(filePath); // ...but AddLateDownload isn't
				}
				else
				{
					LogError("[FF2 Bosses] Character %s is missing file '%s'!", characterName, filePath);
				}
			}
		}
		while(kv.GotoNextKey());
	}

	kv.Rewind();
	if(kv.JumpToKey("downloads"))
	{
		kv.GotoFirstSubKey();

		do
		{
			if(kv.GetNum("model"))
			{
				for(int extension; extension<sizeof(extensions); extension++)
				{
					kv.GetSectionName(file, sizeof(file));
					Format(file, sizeof(file), "%s%s", file, extensions[extension]);

					if(extension == 0) // .mdl
					{
						// LogMessage("Precache ''%s''\n = %s", file, PrecacheModel(file) != 0 ? "YES" : "NO");
						PrecacheModel(file);
					}

					if(FileExists(file, true))
					{
						AddFileToDownloadsTable(file);
					}
					else
					{
						LogError("[FF2 Bosses] Character %s is missing file '%s'!", character, file);
					}
				}

				if(kv.GetNum("phy"))
				{
					kv.GetSectionName(file, sizeof(file));
					Format(file, sizeof(file), "%s.phy", file);
					if(FileExists(file, true))
					{
						AddFileToDownloadsTable(file);
					}
					else
					{
						LogError("[FF2 Bosses] Character %s is missing file '%s'!", character, file);
					}
				}
			}
			else if(kv.GetNum("material"))
			{
				kv.GetSectionName(file, sizeof(file));
				Format(file, sizeof(file), "%s.vmt", file);
				if(FileExists(file, true))
				{
					AddFileToDownloadsTable(file);
				}
				else
				{
					LogError("[FF2 Bosses] Character %s is missing file '%s'!", character, file);
				}

				kv.GetSectionName(file, sizeof(file));
				Format(file, sizeof(file), "%s.vtf", file);
				if(FileExists(file, true))
				{
					if(kv.GetNum("precache") > 0)
					{
						// LogMessage("Precache ''%s''\n = %s", file, PrecacheModel(file) != 0 ? "YES" : "NO");
						PrecacheModel(file);
					}

					AddFileToDownloadsTable(file);
				}
				else
				{
					LogError("[FF2 Bosses] Character %s is missing file '%s'!", character, file);
				}
			}
			else if(FileExists(file, true))
			{
				kv.GetSectionName(file, sizeof(file));
				AddFileToDownloadsTable(file);
			}
			else
			{
				if(file[0] == '\0')	continue;
				LogError("[FF2 Bosses] Character %s is missing file '%s'!", character, file);
			}
		}
		while(kv.GotoNextKey());
	}
/*
	kv.Rewind();
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "data/ff2_dumps/%s.txt", characterName);
	OpenFile(path, "w");
	kv.ExportToFile(path);
*/
}

public void CvarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(convar==cvarPointDelay)
	{
		PointDelay=StringToInt(newValue);
	}
	else if(convar==cvarAnnounce)
	{
		Announce=StringToFloat(newValue);
	}
	else if(convar==cvarPointType)
	{
		PointType=StringToInt(newValue);
	}
	else if(convar==cvarAliveToEnable)
	{
		AliveToEnable=StringToInt(newValue);
	}
	else if(convar==cvarCrits)
	{
		BossCrits=view_as<bool>(StringToInt(newValue));
	}
	else if(convar==cvarArenaRounds)
	{
		arenaRounds=StringToInt(newValue);
	}
	else if(convar==cvarCircuitStun)
	{
		circuitStun=StringToFloat(newValue);
	}
	else if(convar==cvarLastPlayerGlow)
	{
		lastPlayerGlow=view_as<bool>(StringToInt(newValue));
	}
	else if(convar==cvarSpecForceBoss)
	{
		SpecForceBoss=view_as<bool>(StringToInt(newValue));
	}
	else if(convar==cvarBossTeleporter)
	{
		bossTeleportation=view_as<bool>(StringToInt(newValue));
	}
	else if(convar==cvarShieldCrits)
	{
		shieldCrits=StringToInt(newValue);
	}
	else if(convar==cvarCaberDetonations)
	{
		allowedDetonations=StringToInt(newValue);
	}
	else if(convar==cvarUpdater)
	{
		#if defined _updater_included && !defined DEV_REVISION
		cvarUpdater.IntValue ? Updater_AddPlugin(UPDATE_URL) : Updater_RemovePlugin();
		#endif
	}
	else if(convar==cvarEnabled)
	{
		StringToInt(newValue) ? (changeGamemode=Enabled ? 0 : 1) : (changeGamemode=!Enabled ? 0 : 2);
	}
}

#if defined _smac_included
public Action SMAC_OnCheatDetected(int client, const char[] module, DetectionType type, Handle info)
{
	Debug("SMAC: Cheat detected!");
	if(type==Detection_CvarViolation)
	{
		Debug("SMAC: Cheat was a cvar violation!");
		char cvar[PLATFORM_MAX_PATH];
		KvGetString(info, "cvar", cvar, sizeof(cvar));
		Debug("Cvar was %s", cvar);
		if((StrEqual(cvar, "sv_cheats") || StrEqual(cvar, "host_timescale")) && !(FF2Flags[Boss[client]] & FF2FLAG_CHANGECVAR))
		{
			Debug("SMAC: Ignoring violation");
			return Plugin_Stop;
		}
	}
	return Plugin_Continue;
}
#endif

public Action Timer_Announce(Handle timer)
{
	static int announcecount=-1;
	announcecount++;
	if(Announce>1.0 && Enabled2)
	{
		switch(announcecount)
		{
			case 1:
			{
				CPrintToChatAll("%t", "VSH and FF2 Group");
			}
			case 3:
			{
				CPrintToChatAll("%t", "FF2 Contributors", PLUGIN_VERSION);
			}
			case 4:
			{
				CPrintToChatAll("{olive}[FF2]{default} %t", "Type ff2 to Open Menu");
			}
			case 5:
			{
				CPrintToChatAll("{olive}[FF2]{default} %t", "Type ff2_advance to Open Menu");
			}
			case 6:
			{
				announcecount=0;
				char timeStr[64], targetTimeStr[64];
				FormatTime(timeStr, sizeof(timeStr), "%Y-%m-%d %H:%M:%S", ChangeLogLastTime);

				for(int client=1; client<=MaxClients; client++)
				{
					if(!IsClientInGame(client)) continue;
					SetGlobalTransTarget(client);

					GetSettingStringData(client, "changelog_last_view_time", targetTimeStr, sizeof(targetTimeStr));
					if(DateToTimestamp(targetTimeStr) < ChangeLogLastTime) // ???
					{
						CPrintToChat(client, "{olive}[FF2]{default} %t", "FF2 Changelog Notice", timeStr);
					}
					else
					{
						CPrintToChat(client, "{olive}[FF2]{default} %t", "Last FF2 Update", PLUGIN_VERSION);
					}
				}
			}
			default:
			{
				CPrintToChatAll("{olive}[FF2]{default} %t", "Type ff2 to Open Menu");
			}
		}
	}
	return Plugin_Continue;
}

stock bool IsFF2Map()
{
	char config[PLATFORM_MAX_PATH];
	GetCurrentMap(currentmap, sizeof(currentmap));
	if(FileExists("bNextMapToFF2"))
	{
		return true;
	}

	BuildPath(Path_SM, config, sizeof(config), "%s/%s", FF2_SETTINGS, MAPS_CONFIG);
	if(!FileExists(config))
	{
		LogError("[FF2] Unable to find %s, disabling plugin.", config);
		return false;
	}

	File file=OpenFile(config, "r");
	if(file==null)
	{
		LogError("[FF2] Error reading maps from %s, disabling plugin.", config);
		return false;
	}

	int tries;
	while(file.ReadLine(config, sizeof(config)) && tries<100)
	{
		tries++;
		if(tries==100)
		{
			LogError("[FF2] Breaking infinite loop when trying to check the map.");
			return false;
		}

		Format(config, strlen(config)-1, config);
		if(!strncmp(config, "//", 2, false))
		{
			continue;
		}

		if(!StrContains(currentmap, config, false) || !StrContains(config, "all", false))
		{
			delete file;
			return true;
		}
	}
	delete file;
	return false;
}

stock bool CheckToChangeMapDoors()
{
	if(!Enabled || !Enabled2)
	{
		return;
	}

	char config[PLATFORM_MAX_PATH];
	checkDoors=false;
	BuildPath(Path_SM, config, sizeof(config), "%s/%s", FF2_SETTINGS, DOORS_CONFIG);
	if(!FileExists(config))
	{
		if(!strncmp(currentmap, "vsh_lolcano_pb1", 15, false))
		{
			checkDoors=true;
		}
		return;
	}

	File file=OpenFile(config, "r");
	if(file==null)
	{
		if(!strncmp(currentmap, "vsh_lolcano_pb1", 15, false))
		{
			checkDoors=true;
		}
		return;
	}

	while(!file.EndOfFile() && file.ReadLine(config, sizeof(config)))
	{
		Format(config, strlen(config)-1, config);
		if(!strncmp(config, "//", 2, false))
		{
			continue;
		}

		if(StrContains(currentmap, config, false)!=-1 || !StrContains(config, "all", false))
		{
			delete file;
			checkDoors=true;
			return;
		}
	}
	delete file;
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(changeGamemode==1)
	{
		EnableFF2();
	}
	else if(changeGamemode==2)
	{
		DisableFF2();
	}

	if(!cvarEnabled.BoolValue)
	{
		#if defined _steamtools_included
		if(steamtools)
		{
			Steam_SetGameDescription("Team Fortress");
		}
		#endif
		Enabled2=false;
	}

	Enabled=Enabled2;
	if(!Enabled)
	{
		return Plugin_Continue;
	}

	if(FileExists("bNextMapToFF2"))
	{
		DeleteFile("bNextMapToFF2");
	}

	bool blueBoss;
	switch(cvarForceBossTeam.IntValue)
	{
		case 1:
		{
			blueBoss=view_as<bool>(GetRandomInt(0, 1));
		}
		case 2:
		{
			blueBoss=false;
		}
		default:
		{
			blueBoss=true;
		}
	}

	if(blueBoss)
	{
		SetTeamScore(view_as<int>(TFTeam_Red), GetTeamScore(view_as<int>(OtherTeam)));
		SetTeamScore(view_as<int>(TFTeam_Blue), GetTeamScore(view_as<int>(BossTeam)));
		OtherTeam=TFTeam_Red;
		BossTeam=TFTeam_Blue;
	}
	else
	{
		SetTeamScore(view_as<int>(TFTeam_Red), GetTeamScore(view_as<int>(BossTeam)));
		SetTeamScore(view_as<int>(TFTeam_Blue), GetTeamScore(view_as<int>(OtherTeam)));
		OtherTeam=TFTeam_Blue;
		BossTeam=TFTeam_Red;
	}

	playing=0;
	for(int client=1; client<=MaxClients; client++)
	{
		Damage[client]=0;
		Assist[client]=0;
		uberTarget[client]=-1;
		emitRageSound[client]=true;
		FF2Flags[client]=0; // TODO: 테스트
		if(IsValidClient(client) && TF2_GetClientTeam(client)>TFTeam_Spectator)
		{
			playing++;
		}
	}

	if(GetClientCount()<=1 || playing<=1)  //Not enough players D:
	{
		CPrintToChatAll("{olive}[FF2]{default} %t", "More Players Needed");
		Enabled=false;
		//DisableSubPlugins();
		SetControlPoint(true);
		return Plugin_Continue;
	}
	else if(RoundCount<arenaRounds)  //We're still in arena mode
	{
		CPrintToChatAll("{olive}[FF2]{default} %t", "Arena Rounds Left", arenaRounds-RoundCount);  //Waiting for players to finish loading.  FF2 will start in {1} more rounds
		Enabled=false;
		//DisableSubPlugins();
		SetArenaCapEnableTime(60.0);
		CreateTimer(71.0, Timer_EnableCap, _, TIMER_FLAG_NO_MAPCHANGE);
		bool toRed;
		TFTeam team;
		for(int client=1; client<=MaxClients; client++)
		{
			if(IsValidClient(client) && (team=TF2_GetClientTeam(client))>TFTeam_Spectator)
			{
				SetEntProp(client, Prop_Send, "m_lifeState", 2);
				if(toRed && team!=TFTeam_Red)
				{
					TF2_ChangeClientTeam(client, TFTeam_Red);
				}
				else if(!toRed && team!=TFTeam_Blue)
				{
					TF2_ChangeClientTeam(client, TFTeam_Blue);
				}
				SetEntProp(client, Prop_Send, "m_lifeState", 0);
				TF2_RespawnPlayer(client);
				toRed=!toRed;
			}
		}
		return Plugin_Continue;
	}

	for(int client; client<=MaxClients; client++)
	{
		Boss[client]=0;
		if(IsValidClient(client) && IsPlayerAlive(client) && !(FF2Flags[client] & FF2FLAG_HASONGIVED))
		{
			TF2_RespawnPlayer(client);
		}
	}

	Enabled=true;
	//EnableSubPlugins();
	CheckArena();

	bool[] omit=new bool[MaxClients+1];
	Boss[0]=GetClientWithMostQueuePoints(omit);
	if(Boss[0] == 0)
	{
		Boss[0]=RandomlySelectClient(omit);
		CPrintToChatAll("{olive}[FF2]{default} %t", "Randomly Choose Boss Player");
	}

	omit[Boss[0]]=true;

	bool teamHasPlayers[4]; // TODO: 컴파일러 버전 변경으로 인한 Enum 크기 구하는 방법 변경
	for(int client=1; client<=MaxClients; client++)  //Find out if each team has at least one player on it
	{
		if(IsValidClient(client))
		{
			TFTeam team=TF2_GetClientTeam(client);
			if(team>TFTeam_Spectator)
			{
				teamHasPlayers[team]=true;
			}

			if(teamHasPlayers[TFTeam_Blue] && teamHasPlayers[TFTeam_Red])
			{
				break;
			}
		}
	}

	if(!teamHasPlayers[TFTeam_Blue] || !teamHasPlayers[TFTeam_Red])  //If there's an empty team make sure it gets populated
	{
		if(IsValidClient(Boss[0]) && TF2_GetClientTeam(Boss[0])!=BossTeam)
		{
			AssignTeam(Boss[0], BossTeam);
		}

		for(int client=1; client<=MaxClients; client++)
		{
			if(IsValidClient(client) && !IsBoss(client) && TF2_GetClientTeam(client)!=OtherTeam)
			{
				CreateTimer(0.1, MakeNotBoss, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
			}
		}
		return Plugin_Continue;  //NOTE: This is needed because OnRoundStart gets fired a second time once both teams have players
	}

	PickCharacter(0, 0);
	if((character[0]<0) || !bossesArray.Get(character[0]))
	{
		LogError("[FF2 Bosses] Couldn't find a boss!");
		return Plugin_Continue;
	}

	FindCompanion(0, playing, omit);  //Find companions for the boss!

	for(int boss; boss<=MaxClients; boss++)
	{
		BossInfoTimer[boss][0]=null;
		BossInfoTimer[boss][1]=null;
		if(Boss[boss])
		{
			AssignTeam(Boss[boss], BossTeam);
			CreateTimer(0.3, MakeBoss, boss, TIMER_FLAG_NO_MAPCHANGE);
			BossInfoTimer[boss][0]=CreateTimer(30.2, BossInfoTimer_Begin, boss, TIMER_FLAG_NO_MAPCHANGE);
		}
	}

	CreateTimer((tf_arena_preround_time - 10.0) + 3.5, StartResponseTimer, _, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer((tf_arena_preround_time - 10.0) + 9.1, StartBossTimer, _, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer((tf_arena_preround_time - 10.0) + 9.6, MessageTimer, _, TIMER_FLAG_NO_MAPCHANGE);

	for(int entity=MaxClients+1; entity<MAXENTITIES; entity++)
	{
		if(!IsValidEntity(entity))
		{
			continue;
		}

		char classname[64];
		GetEntityClassname(entity, classname, sizeof(classname));
		if(StrEqual(classname, "func_regenerate"))
		{
			AcceptEntityInput(entity, "Kill");
		}
		else if(StrEqual(classname, "func_respawnroomvisualizer"))
		{
			AcceptEntityInput(entity, "Disable");
		}
	}

	healthcheckused=0;
	firstBlood=true;
	return Plugin_Continue;
}

public Action Timer_EnableCap(Handle timer)
{
	if((Enabled || Enabled2) && CheckRoundState()==FF2RoundState_Loading)
	{
		SetControlPoint(true);
		if(checkDoors)
		{
			int ent=-1;
			while((ent=FindEntityByClassname2(ent, "func_door"))!=-1)
			{
				AcceptEntityInput(ent, "Open");
				AcceptEntityInput(ent, "Unlock");
			}

			if(doorCheckTimer==null)
			{
				doorCheckTimer=CreateTimer(5.0, Timer_CheckDoors, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
}

public Action BossInfoTimer_Begin(Handle timer, int boss)
{
	BossInfoTimer[boss][0]=null;
	BossInfoTimer[boss][1]=CreateTimer(0.2, BossInfoTimer_ShowInfo, boss, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

public Action BossInfoTimer_ShowInfo(Handle timer, int boss)
{
	if(!IsValidClient(Boss[boss]))
	{
		BossInfoTimer[boss][1]=null;
		return Plugin_Stop;
	}

	if(bossHasReloadAbility[boss])
	{
		SetHudTextParams(0.75, 0.7, 0.15, 255, 255, 255, 255);
		SetGlobalTransTarget(Boss[boss]);
		if(bossHasRightMouseAbility[boss])
		{
			FF2_ShowSyncHudText(Boss[boss], abilitiesHUD, "%t\n%t", "Ability uses Reload", "Ability uses Right Mouse");
		}
		else
		{
			FF2_ShowSyncHudText(Boss[boss], abilitiesHUD, "%t", "Ability uses Reload");
		}
	}
	else if(bossHasRightMouseAbility[boss])
	{
		SetHudTextParams(0.75, 0.7, 0.15, 255, 255, 255, 255);
		SetGlobalTransTarget(Boss[boss]);
		FF2_ShowSyncHudText(Boss[boss], abilitiesHUD, "%t", "Ability uses Right Mouse");
	}
	else
	{
		BossInfoTimer[boss][1]=null;
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public Action Timer_CheckDoors(Handle timer)
{
	if(!checkDoors)
	{
		doorCheckTimer=null;
		return Plugin_Stop;
	}

	if((!Enabled && CheckRoundState()!=FF2RoundState_Loading) || (Enabled && CheckRoundState()!=FF2RoundState_RoundRunning))
	{
		return Plugin_Continue;
	}

	int entity=-1;
	while((entity=FindEntityByClassname2(entity, "func_door"))!=-1)
	{
		AcceptEntityInput(entity, "Open");
		AcceptEntityInput(entity, "Unlock");
	}
	return Plugin_Continue;
}

public void CheckArena()
{
	if(PointType)
	{
		SetArenaCapEnableTime(float(45+PointDelay*(playing-1)));
	}
	else
	{
		SetArenaCapEnableTime(0.0);
		SetControlPoint(false);
	}
}

public Action OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	RoundCount++;

	if(!Enabled)
	{
		return Plugin_Continue;
	}

	executed=false;
	bool bossWin;
	char sound[PLATFORM_MAX_PATH];
	if((view_as<TFTeam>(event.GetInt("team"))==BossTeam))
	{
		bossWin=true;
		if(FindSound("win", sound, sizeof(sound)))
		{
			EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, sound);
			EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, sound);
		}
	}

	StopMusic();

	bool isBossAlive;
	for(int boss; boss<=MaxClients; boss++)
	{
		if(IsValidClient(Boss[boss]))
		{
			SetClientGlow(Boss[boss], 0.0, 0.0);
			SDKUnhook(boss, SDKHook_GetMaxHealth, OnGetMaxHealth);  //Temporary:  Used to prevent boss overheal
			if(IsPlayerAlive(Boss[boss]))
			{
				isBossAlive=true;
			}

			for(int slot=1; slot<8; slot++)
			{
				BossCharge[boss][slot]=0.0;
			}

			bossHasReloadAbility[boss]=false;
			bossHasRightMouseAbility[boss]=false;
		}
		else if(IsValidClient(boss))  //Boss here is actually a client index
		{
			shield[boss]=0;
			detonations[boss]=0;
		}

		for(int timer; timer<=1; timer++)
		{
			if(BossInfoTimer[boss][timer]!=null)
			{
				delete BossInfoTimer[boss][timer];
			}
		}
	}

	if(isBossAlive && bossWin)
	{
		char bossName[64], lives[8], text[128];
		int bossindexs[MAXPLAYERS+1], bosscount=0;
		for(int target=1; target<=MaxClients; target++)
		{
			if(IsBoss(target) && BossTeam == TF2_GetClientTeam(target))
			{
				bossindexs[bosscount++]=Boss[target];
			}
		}

		SetHudTextParams(-1.0, 0.2, 10.0, 255, 255, 255, 255);
		for(int client=1; client<=MaxClients; client++)
		{
			if(IsValidClient(client) && !IsFakeClient(client))
			{
				SetGlobalTransTarget(client);
				Format(text, sizeof(text), "");

				for(int loop; loop<bosscount; loop++)
				{
					GetBossName(bossindexs[loop], bossName, sizeof(bossName), client);
					BossLives[bossindexs[loop]]>1 ? Format(lives, sizeof(lives), "x%i", BossLives[bossindexs[loop]]) : strcopy(lives, 2, "");

					if(loop == 0) {
						Format(text, sizeof(text), "%s\n%t", text, "Boss Win Final Health", bossName, Boss[bossindexs[loop]], BossHealth[bossindexs[loop]]-BossHealthMax[bossindexs[loop]]*(BossLives[bossindexs[loop]]-1), BossHealthMax[bossindexs[loop]], lives);
					}
					CPrintToChat(client, "{olive}[FF2]{default} %t", "Boss Win Final Health", bossName, Boss[bossindexs[loop]], BossHealth[bossindexs[loop]]-BossHealthMax[bossindexs[loop]]*(BossLives[bossindexs[loop]]-1), BossHealthMax[bossindexs[loop]], lives);
				}
				FF2_ShowHudText(client, -1, "%s", text);
			}
		}
	}
	else if(!bossWin && FindSound("lose", sound, sizeof(sound), 0))
	{
		EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, sound);
		EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, sound);
	}


	int top[3];
	Damage[0]=0;

	for(int client=0; client<=MaxClients; client++)
	{
		if(!IsValidClient(client) || Damage[client]<=0 || (IsBoss(client) && BossTeam == TF2_GetClientTeam(client)))
		{
			continue;
		}

		SetClientGlow(client, 0.0, 0.0);
		if(Assist[client]>10)
			Damage[client]+=Assist[client]/2;
		Assist[client]=0;

		if(Damage[client]>=Damage[top[0]])
		{
			top[2]=top[1];
			top[1]=top[0];
			top[0]=client;
		}
		else if(Damage[client]>=Damage[top[1]])
		{
			top[2]=top[1];
			top[1]=client;
		}
		else if(Damage[client]>=Damage[top[2]])
		{
			top[2]=client;
		}
	}

	if(Damage[top[0]]>9000)
	{
		CreateTimer(1.0, Timer_NineThousand, _, TIMER_FLAG_NO_MAPCHANGE);
	}

	char leaders[3][32];
	for(int i; i<=2; i++)
	{
		if(IsValidClient(top[i]))
		{
			GetClientName(top[i], leaders[i], 32);
		}
		else
		{
			Format(leaders[i], 32, "---");
			top[i]=0;
		}
	}

	SetHudTextParams(-1.0, 0.3, 10.0, 255, 255, 255, 255);
	PrintCenterTextAll("");

	char text[128];  //Do not decl this
	for(int client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client))
		{
			SetGlobalTransTarget(client);
			//TODO:  Clear HUD text here
			if(IsBoss(client))
			{
				FF2_ShowSyncHudText(client, infoHUD, "%s\n%t:\n1) %i-%s\n2) %i-%s\n3) %i-%s\n\n%t", text, "Top 3", Damage[top[0]], leaders[0], Damage[top[1]], leaders[1], Damage[top[2]], leaders[2], (bossWin ? "Boss Victory" : "Boss Defeat"));
			}
			else
			{
				FF2_ShowSyncHudText(client, infoHUD, "%s\n%t:\n1) %i-%s\n2) %i-%s\n3) %i-%s\n\n%t", text, "Top 3", Damage[top[0]], leaders[0], Damage[top[1]], leaders[1], Damage[top[2]], leaders[2], "Total Damage Dealt", Damage[client]);
			}
		}
	}

	CreateTimer(3.0, Timer_CalcQueuePoints, _, TIMER_FLAG_NO_MAPCHANGE);
	UpdateHealthBar(true);
	return Plugin_Continue;
}

public Action OnBroadcast(Event event, const char[] name, bool dontBroadcast)
{
    char sound[PLATFORM_MAX_PATH];
    event.GetString("sound", sound, sizeof(sound));
    if(!StrContains(sound, "Game.Your", false) || StrEqual(sound, "Game.Stalemate", false))
    {
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

public Action Timer_NineThousand(Handle timer)
{
	EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, "saxton_hale/9000.wav", _, SNDCHAN_VOICE, _, _, _, _, _, _, _, false);
	EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, "saxton_hale/9000.wav", _, SNDCHAN_VOICE, _, _, _, _, _, _, _, false);
	return Plugin_Continue;
}

public Action Timer_CalcQueuePoints(Handle timer)
{
	int damage;
	botqueuepoints+=5;
	int[] add_points=new int[MaxClients+1];
	int[] add_points2=new int[MaxClients+1];
	for(int client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client))
		{
			damage=Damage[client];
			Event event=CreateEvent("player_escort_score", true);
			event.SetInt("player", client);

			int points;
			while(damage-600>0)
			{
				damage-=600;
				points++;
			}
			event.SetInt("points", points);
			event.Fire();

			if(Boss[0]==client)
			{
				if(IsFakeClient(client))
				{
					botqueuepoints=0;
				}
				else
				{
					add_points[client]=-GetClientQueuePoints(client);
					add_points2[client]=add_points[client];
				}
			}
			else if(!IsFakeClient(client) && (TF2_GetClientTeam(client)>TFTeam_Spectator || SpecForceBoss))
			{
				add_points[client]=10;
				add_points2[client]=10;
			}
		}
	}

	Action action;
	Call_StartForward(OnAddQueuePoints);
	Call_PushArrayEx(add_points2, MaxClients+1, SM_PARAM_COPYBACK);
	Call_Finish(action);
	switch(action)
	{
		case Plugin_Stop, Plugin_Handled:
		{
			return;
		}
		case Plugin_Changed:
		{
			for(int client=1; client<=MaxClients; client++)
			{
				if(IsValidClient(client))
				{
					if(add_points2[client]>0)
					{
						CPrintToChat(client, "{olive}[FF2]{default} %t", "Points Earned", add_points2[client]);
					}
					SetClientQueuePoints(client, GetClientQueuePoints(client)+add_points2[client]);
				}
			}
		}
		default:
		{
			for(int client=1; client<=MaxClients; client++)
			{
				if(IsValidClient(client))
				{
					if(add_points[client]>0)
					{
						CPrintToChat(client, "{olive}[FF2]{default} %t", "Points Earned", add_points[client]);
					}
					SetClientQueuePoints(client, GetClientQueuePoints(client)+add_points[client]);
				}
			}
		}
	}
}

public Action StartResponseTimer(Handle timer)
{
	char sound[PLATFORM_MAX_PATH];
	if(FindSound("begin", sound, sizeof(sound)))
	{
		EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, sound);
		EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, sound);
	}
	return Plugin_Continue;
}

public Action StartBossTimer(Handle timer)
{
	CreateTimer(0.1, Timer_Move, _, TIMER_FLAG_NO_MAPCHANGE);
	bool isBossAlive;
	for(int boss; boss<=MaxClients; boss++)
	{
		if(IsValidClient(Boss[boss]) && IsPlayerAlive(Boss[boss]))
		{
			isBossAlive=true;
			SetEntityMoveType(Boss[boss], MOVETYPE_NONE);

			// 초기 쿨타임
			for(int slot = 1; slot < 8; slot++)
			{
				BossCharge[boss][slot] = -15.0;
			}
		}
	}

	if(!isBossAlive)
	{
		return Plugin_Continue;
	}

	playing=0;
	for(int client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client) && !IsBoss(client) && IsPlayerAlive(client))
		{
			playing++;
			CreateTimer(0.15, MakeNotBoss, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);  //TODO:  Is this needed?
		}
	}

	CreateTimer(0.05, BossTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(0.2, CheckAlivePlayers, _, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(0.2, StartRound, _, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(0.2, ClientTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(2.0, Timer_PrepareBGM, 0, TIMER_FLAG_NO_MAPCHANGE);

	if(!PointType)
	{
		SetControlPoint(false);
	}
	return Plugin_Continue;
}

public any GetSettingData(int client, const char[] settingId, KvDataTypes type)
{
	char data[128];
	GetSettingStringData(client, settingId, data, 128);

	switch(type)
	{
		case KvData_Int:
		{
			return data[0] != '\0' ? StringToInt(data) : 0;
		}
		case KvData_Float:
		{
			return data[0] != '\0' ? StringToFloat(data) : 0.0;
		}
		default:
		{
			ThrowError("KvData_Int, KvData_Float supported!");
		}
	}

	return -1;
}

public any Native_GetSettingData(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	char settingId[128];
	GetNativeString(2, settingId, sizeof(settingId));
	KvDataTypes type = GetNativeCell(3);

	return GetSettingData(client, settingId, type);
}

public void GetSettingStringData(int client, const char[] settingId, char[] value, int buffer)
{
	(DBSPlayerData.GetClientData(client)).GetData(FF2DATABASE_CONFIG_NAME, FF2_DB_PLAYERDATA_TABLENAME, settingId, "value", value, buffer);
}

public int Native_GetSettingStringData(Handle plugin, int numParams)
{
	int client = GetNativeCell(1), buffer = GetNativeCell(4);
	char settingId[128], value[128];
	GetNativeString(2, settingId, sizeof(settingId));

	GetSettingStringData(client, settingId, value, buffer);
	SetNativeString(3, value, sizeof(value));

	return 0; // ??
}

public void SetSettingData(int client, const char[] settingId, any value, KvDataTypes type)
{
	// (DBSPlayerData.GetClientData(client)).SetData(FF2DATABASE_CONFIG_NAME, FF2_DB_PLAYERDATA_TABLENAME, settingId, "value", value);
	char data[128];

	switch(type)
	{
		case KvData_Int:
		{
			Format(data, sizeof(data), "%d", value);
		}
		case KvData_Float:
		{
			Format(data, sizeof(data), "%.1f", value);
		}
		default:
		{
			ThrowError("KvData_Int, KvData_Float supported!");
		}
	}

	SetSettingStringData(client, settingId, data);
}

public any Native_SetSettingData(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	char settingId[128];
	GetNativeString(2, settingId, sizeof(settingId));
	KvDataTypes type = GetNativeCell(4);

	SetSettingData(client, settingId, GetNativeCellRef(3), type);
}

public void SetSettingStringData(int client, const char[] settingId, char[] value)
{
	(DBSPlayerData.GetClientData(client)).SetStringData(FF2DATABASE_CONFIG_NAME, FF2_DB_PLAYERDATA_TABLENAME, settingId, "value", value);
}

public any Native_SetSettingStringData(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	char settingId[128], value[128];
	GetNativeString(2, settingId, sizeof(settingId));

	SetSettingStringData(client, settingId, value);
	SetNativeString(3, value, sizeof(value));
}

public Action Timer_Move(Handle timer)
{
	for(int client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client) && IsPlayerAlive(client))
		{
			SetEntityMoveType(client, MOVETYPE_WALK);
		}
	}
}

public Action StartRound(Handle timer)
{
	CreateTimer(10.0, Timer_NextBossPanel, _, TIMER_FLAG_NO_MAPCHANGE);
	UpdateHealthBar(true);

	CreateTimer(6.5, Timer_StartDrawGame, _, TIMER_FLAG_NO_MAPCHANGE);

	return Plugin_Handled;
}

public Action Timer_StartDrawGame(Handle timer)
{
	int bosscount=0, playerCount=0;

	for(int client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client) && IsPlayerAlive(client))
		{
			playerCount++;

			if(IsBoss(client))
				bosscount++;
		}
	}

	timeType=cvarTimerType.IntValue;
	switch(timeType)
	{
		case FF2Timer_RoundTimer:
		{
			timeleft=(bosscount*40.0)+(playerCount*30.0)+60.0;
		}
		case FF2Timer_WaveTimer:
		{
			maxTime=30.0+(playerCount > 18 ? float(playerCount-18) : 0.0), timeleft = maxTime;
			maxWave=6+(playerCount > 18 ? 18 : playerCount);
			currentWave=1;
		}
		default:
		{
			timeleft=-1.0;
		}
	}

	CreateTimer(0.1, Timer_DrawGame, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_NextBossPanel(Handle timer)
{
	int clients;
	bool[] added=new bool[MaxClients+1];
	while(clients<3)  //TODO: Make this configurable?
	{
		int client=GetClientWithMostQueuePoints(added);
		if(!IsValidClient(client))  //No more players left on the server
		{
			break;
		}

		if(!IsBoss(client))
		{
			CPrintToChat(client, "{olive}[FF2]{default} %t", "Next Boss");  //"You will become the Boss soon. Type {olive}/ff2next{default} to make sure."
			clients++;
		}
		added[client]=true;
	}
}

public Action MessageTimer(Handle timer)
{
	if(CheckRoundState()!=FF2RoundState_Setup)
	{
		return Plugin_Continue;
	}

	if(checkDoors)
	{
		int entity=-1;
		while((entity=FindEntityByClassname2(entity, "func_door"))!=-1)
		{
			AcceptEntityInput(entity, "Open");
			AcceptEntityInput(entity, "Unlock");
		}

		if(doorCheckTimer==null)
		{
			doorCheckTimer=CreateTimer(5.0, Timer_CheckDoors, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}
	}

	SetHudTextParams(-1.0, 0.2, 10.0, 255, 255, 255, 255);
	char text[512], textChat[512], lives[8], name[64];  //Do not decl this
	int bossindexs[MAXPLAYERS+1], bosscount=0;

	for(int client=1; client<=MaxClients; client++)
	{
		if(IsBoss(client) && TF2_GetClientTeam(client) == BossTeam)
		{
			bossindexs[bosscount++]=Boss[client];
		}
	}

	for(int client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client) && !IsFakeClient(client))
		{
			SetGlobalTransTarget(client);
			Format(text, sizeof(text), "");

			for(int loop; loop<bosscount; loop++)
			{
				GetBossName(bossindexs[loop], name, sizeof(name), client);
				if(BossLives[bossindexs[loop]]>1)
				{
					Format(lives, sizeof(lives), "x%i", BossLives[bossindexs[loop]]);
				}
				else
				{
					strcopy(lives, 2, "");
				}

				Format(text, sizeof(text), "%s\n%t", text, "Boss Info", Boss[bossindexs[loop]], name, BossHealth[bossindexs[loop]]-BossHealthMax[bossindexs[loop]]*(BossLives[bossindexs[loop]]-1), lives);
				Format(textChat, sizeof(textChat), "{olive}[FF2]{default} %t!", "Boss Info", Boss[bossindexs[loop]], name, BossHealth[bossindexs[loop]]-BossHealthMax[bossindexs[loop]]*(BossLives[bossindexs[loop]]-1), lives);
				ReplaceString(textChat, sizeof(textChat), "\n", "");  //Get rid of newlines
				CPrintToChat(client, "%s", textChat);
			}

			FF2_ShowSyncHudText(client, infoHUD, text);
		}
	}
	return Plugin_Continue;
}

public Action MakeModelTimer(Handle timer, int boss)
{
	int client=Boss[boss];
	if(IsValidClient(client) && IsPlayerAlive(client) && CheckRoundState()!=FF2RoundState_RoundEnd)
	{
		char model[PLATFORM_MAX_PATH];
		KeyValues bossKv = GetCharacterKV(character[boss]);
		bossKv.Rewind();
		bossKv.GetString("model", model, sizeof(model));
		SetVariantString(model);
		AcceptEntityInput(client, "SetCustomModel");
		SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
		return Plugin_Continue;
	}
	return Plugin_Stop;
}

void EquipBoss(int boss)
{
	KeyValues kv = GetCharacterKV(character[boss]);
	char classname[64], attributes[256], oneAttrib[40][10], bossName[64];
	int client=Boss[boss];

	bool initCaptureAttribute = false;
	char captureAttributeStr[64] = "252 ; 0.8 ; 68 ; %i ; "; // 68: +2 cap rate, 252: knockback scale, 259: goomba

	TF2_RemoveAllWeapons(client);
	TF2_RemoveAllWearables(client);

	Format(captureAttributeStr, 64, captureAttributeStr, TF2_GetPlayerClass(client)==TFClass_Scout ? 1 : 2);

	kv.Rewind();
	kv.GetString("name", bossName, sizeof(bossName), "=Failed Name=");
	if(kv.JumpToKey("weapons"))
	{
		kv.GotoFirstSubKey();
		do
		{
			char sectionName[32];
			kv.GetSectionName(sectionName, sizeof(sectionName));
			int index=StringToInt(sectionName);

			//NOTE: StringToInt returns 0 on failure which corresponds to tf_weapon_bat,
			//so there's no way to distinguish between an invalid string and 0.
			//Blocked on bug 6438: https://bugs.alliedmods.net/show_bug.cgi?id=6438

			if(index>=0)
			{
				kv.JumpToKey(sectionName);
				kv.GetString("classname", classname, sizeof(classname));
				if(classname[0]=='\0')
				{
					LogError("[FF2 Bosses] No classname specified for weapon %i (character %s)!", index, bossName);
					continue;
				}

				kv.GetString("attributes", attributes, sizeof(attributes));

				int weapon = -1;

				if(StrContains(classname, "tf_wearable") != -1)
				{
					bool demoshield = StrEqual(classname, "tf_wearable_demoshield");
					weapon = demoshield ? TF2_SpawnDemoShield(index, 5, 101) : TF2_SpawnWearable(index, 5, 101);
					TF2Util_EquipPlayerWearable(client, weapon);

					int attributeCount = ExplodeString(attributes, ";", oneAttrib, sizeof(oneAttrib), sizeof(oneAttrib[]));
					if(attributes[0] != '\0')
					{
						if(attributeCount % 2 != 0)
							ThrowError("%s is not valid!", attributes);

						for(int loop = 0; loop < attributeCount; loop += 2)
						{
							int attribIndex = StringToInt(oneAttrib[loop]);
							float temp = StringToFloat(oneAttrib[loop + 1]);
							Address itemAddress = TF2Attrib_GetByDefIndex(weapon, attribIndex);

							if(itemAddress != Address_Null)
								TF2Attrib_RemoveByDefIndex(weapon, attribIndex);

							TF2Attrib_SetByDefIndex(weapon, attribIndex, temp);
						}
					}

					// 데모쉴드인 경우에만 사용
					if(demoshield)
						SetEntProp(client, Prop_Send, "m_bShieldEquipped", 1);
				}
				else
				{
					if(attributes[0]!='\0')
					{
						Format(attributes, sizeof(attributes), "%s2 ; 3.1 ; %s", !initCaptureAttribute ? captureAttributeStr : "", attributes);
							//2: x3.1 damage
					}
					else
					{
						Format(attributes, sizeof(attributes), "%s2 ; 3.1", !initCaptureAttribute ? captureAttributeStr : "");
							//2: x3.1 damage
					}

					weapon=SpawnWeapon(client, classname, index, 101, 5, attributes);
					if(StrEqual(classname, "tf_weapon_builder", false) && index!=735)  //PDA, normal sapper
					{
						SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 1, _, 0);
						SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 1, _, 1);
						SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 1, _, 2);
						SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 3);
					}
					else if(StrEqual(classname, "tf_weapon_sapper", false) || index==735)  //Sappers
					{
						SetEntProp(weapon, Prop_Send, "m_iObjectType", 3);
						SetEntProp(weapon, Prop_Data, "m_iSubType", 3);
						SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 0);
						SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 1);
						SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 2);
						SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 1, _, 3);
					}

					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
					initCaptureAttribute = true;
				}

				if(!kv.GetNum("show", 0))
				{
					SetEntPropFloat(weapon, Prop_Send, "m_flModelScale", 0.001);
				}
			}
			else
			{
				LogError("[FF2 Bosses] Invalid weapon index %s specified for character %s!", sectionName, bossName);
			}
		}
		while(kv.GotoNextKey());
	}

	kv.Rewind();
	TFClassType playerclass=view_as<TFClassType>(kv.GetNum("class", 1));
	if(TF2_GetPlayerClass(client)!=playerclass)
	{
		TF2_SetPlayerClass(client, playerclass, _, !GetEntProp(client, Prop_Send, "m_iDesiredPlayerClass") ? true : false);
	}

	TF2Attrib_RemoveByDefIndex(client, 112);
	TF2Attrib_RemoveByDefIndex(client, 113);
	TF2Attrib_RemoveByDefIndex(client, 252);
}

public Action MakeBoss(Handle timer, int boss)
{
	int client=Boss[boss];
	if(!IsValidClient(client) || CheckRoundState()==FF2RoundState_Loading)
	{
		return Plugin_Continue;
	}

	if(!IsPlayerAlive(client))
	{
		TF2_RespawnPlayer(client);
	}

	KeyValues kv=GetCharacterKV(character[boss]);
	kv.Rewind();

	BossHealthMax[boss]=ParseFormula(boss, "health", RoundFloat(Pow((760.8+float(playing))*(float(playing)-1.0), 1.0341)+2046.0));
	BossLivesMax[boss]=BossLives[boss]=ParseFormula(boss, "lives", 1);
	BossHealth[boss]=BossHealthLast[boss]=BossHealthMax[boss]*BossLivesMax[boss];
	BossRageDamage[boss]=ParseFormula(boss, "rage damage", 1900);
	BossMaxRageCharge[boss] = kv.GetFloat("rage max charge", 100.0);
	BossSpeed[boss]=float((ParseFormula(boss, "speed", 340)));

	SetEntProp(client, Prop_Send, "m_bGlowEnabled", 0);
	TF2_RemovePlayerDisguise(client);
	TF2_SetPlayerClass(client, view_as<TFClassType>(kv.GetNum("class", 1)), _, !GetEntProp(client, Prop_Send, "m_iDesiredPlayerClass") ? true : false);
	SDKHook(client, SDKHook_GetMaxHealth, OnGetMaxHealth);  //Temporary:  Used to prevent boss overheal

	switch(kv.GetNum("pickups", 0))  //Check if the boss is allowed to pickup health/ammo
	{
		case 1:
		{
			FF2Flags[client]|=FF2FLAG_ALLOW_HEALTH_PICKUPS;
		}
		case 2:
		{
			FF2Flags[client]|=FF2FLAG_ALLOW_AMMO_PICKUPS;
		}
		case 3:
		{
			FF2Flags[client]|=FF2FLAG_ALLOW_HEALTH_PICKUPS|FF2FLAG_ALLOW_AMMO_PICKUPS;
		}
	}

	CreateTimer(0.2, MakeModelTimer, boss, TIMER_FLAG_NO_MAPCHANGE);
	if(!IsFakeClient(client) && !IsVoteInProgress() && GetClientClassInfoCookie(client) != 1)
	{
		HelpPanelBoss(client, boss);
	}

	if(!IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}

	int entity=-1;
	while((entity=FindEntityByClassname2(entity, "tf_wear*"))!=-1)
	{
		if(IsBoss(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")))
		{
			switch(GetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex"))
			{
				case 493, 233, 234, 241, 280, 281, 282, 283, 284, 286, 288, 362, 364, 365, 536, 542, 577, 599, 673, 729, 791, 839, 5607:  //Action slot items
				{
					//NOOP
				}
				default:
				{
					TF2_RemoveWearable(client, entity);
				}
			}
		}
	}

	entity=-1;
	while((entity=FindEntityByClassname2(entity, "tf_powerup_bottle"))!=-1)
	{
		if(IsBoss(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")))
		{
			TF2_RemoveWearable(client, entity);
		}
	}

	EquipBoss(boss);
	KSpreeCount[boss]=0;
	BossCharge[boss][0]=0.0;

	for(int loop = 0; loop < 3; loop++)
	{
		BossSkillDuration[boss][loop] = 0.0;
	}

	if(Boss[0]==client)
		SetClientQueuePoints(client, 0);

	Call_StartForward(OnPlayBoss);
	Call_PushCell(boss);
	Call_Finish();

	return Plugin_Continue;
}

/*Soon(TM)
void CreateWeaponModsKeyValues()
{
	if(kvWeaponSpecials!=null)
	{
		delete kvWeaponSpecials;
	}

	kvWeaponSpecials=KeyValues("WeaponSpecials");
	for(int i=0; i<sizeof(WeaponSpecials); i++)
	{
		kvWeaponSpecials.JumpToKey(WeaponSpecials[i], true);

		kvWeaponSpecials.KvJumpToKey("ByClassname", true);
		kvWeaponSpecials.GoBack();

		kvWeaponSpecials.JumpToKey("ByIndex", true);
		kvWeaponSpecials.GoBack();

		kvWeaponSpecials.GoBack();
	}
}*/

public Action TF2Items_OnGiveNamedItem(int client, char[] classname, int iItemDefinitionIndex, Handle& item)
{
	if(!Enabled /*|| item!=null*/)
	{
		return Plugin_Continue;
	}

	//TODO: "onhit", "ontakedamage"
	//TODO: Also support comma-delimited strings, eg "38, 457" or "tf_weapon_knife, tf_weapon_katana"
	static Handle weapon;
	if(weapon!=null)
	{
		delete weapon;
	}

	if(!IsBoss(client))
	{
		char itemString[8];
		IntToString(iItemDefinitionIndex, itemString, sizeof(itemString));

		kvWeaponMods.Rewind();
		bool differentClass;
		if(kvWeaponMods.JumpToKey(classname) || kvWeaponMods.JumpToKey(itemString))
		{
			Debug("Entered classname %s or index %i", classname, iItemDefinitionIndex);
			if(kvWeaponMods.JumpToKey("replace"))
			{
				Debug("\tEntered replace");
				char newClass[64];
				kvWeaponMods.GetString("classname", newClass, sizeof(newClass));
				Debug("\t\tNew classname is %s", newClass);

				int flags=OVERRIDE_ITEM_DEF|OVERRIDE_ATTRIBUTES|FORCE_GENERATION;
				int index=kvWeaponMods.GetNum("index", -1);
				if(index<0)
				{
					LogError("[FF2 Weapons] \"replace\" is missing item definition index for classname %s or index %i!", classname, iItemDefinitionIndex);
					return Plugin_Stop;
				}

				if(!StrEqual(classname, newClass))
				{
					flags|=OVERRIDE_CLASSNAME;
					differentClass=true;
					strcopy(classname, 64, newClass);
				}

				int level=kvWeaponMods.GetNum("level", -1);
				if(level>-1)
				{
					flags|=OVERRIDE_ITEM_LEVEL;
				}
				else if(differentClass)  //If level wasn't set and we're switching classnames automatically set the level to 1
				{
					level=1;
				}

				int quality=kvWeaponMods.GetNum("quality", -1);
				if(quality>-1)
				{
					flags|=OVERRIDE_ITEM_QUALITY;
				}
				else if(differentClass)  //Ditto here
				{
					quality=0;
				}

				weapon=TF2Items_CreateItem(flags);
				TF2Items_SetClassname(weapon, classname);
				TF2Items_SetQuality(weapon, quality);
				TF2Items_SetLevel(weapon, level);
				Debug("\t\tGave new weapon with classname %s, index %i, quality %i, and level %i", classname, index, quality, level);
				int entity=TF2Items_GiveNamedItem(client, weapon);
				EquipPlayerWeapon(client, entity);

				delete weapon;

				kvWeaponMods.GoBack();
			}

			if(kvWeaponMods.JumpToKey("add"))
			{
				Debug("\tEntered add");
				char attributes[32][8];
				int attribCount;
				for(int key; kvWeaponMods.GotoNextKey(); key+=2)
				{
					if(key>=32)
					{
						LogError("[FF2 Weapons] Weapon %s (index %i) has more than 16 attributes, ignoring the rest", classname, iItemDefinitionIndex);
						break;
					}

					attribCount++;
					kvWeaponMods.GetSectionName(attributes[key], 8);
					kvWeaponMods.GetString(attributes[key], attributes[key+1], 8);
					Debug("\t\tAttribute set %i is %s ; %s", attribCount, attributes[key], attributes[key+1]);
				}

				if(attribCount)
				{
					int entity=FindEntityByClassname(-1, classname);
					for(int attribute; attribute<attribCount; attribute+=2)
					{
						int attrib=StringToInt(attributes[attribute]);
						if(!attrib)  //StringToInt will return 0 on failure, which probably means the attribute was specified by name, not index
						{
							TF2Attrib_SetByName(entity, attributes[attribute], StringToFloat(attributes[attribute+1]));
							Debug("\t\tAdded attribute set %s ; %s", attributes[attribute], attributes[attribute+1]);
						}
						else if(attrib<0)
						{
							LogError("[FF2 Weapons] Ignoring attribute %i passed for weapon %s (index %i) while adding attributes", attrib, classname, iItemDefinitionIndex);
						}
						else
						{
							TF2Attrib_SetByDefIndex(entity, attrib, StringToFloat(attributes[attribute+1]));
							Debug("\t\tAdded attribute set %s ; %s", attributes[attribute], attributes[attribute+1]);
						}
					}
				}
				kvWeaponMods.GoBack();
			}

			if(kvWeaponMods.JumpToKey("remove"))
			{
				Debug("\tEntered remove");
				char attributes[16][8];
				int entity=FindEntityByClassname(-1, classname);
				for(int key; kvWeaponMods.GotoNextKey() && key<16; key++)
				{
					kvWeaponMods.GetSectionName(attributes[key], 8);
					int attribute=StringToInt(attributes[key]);
					if(!attribute)  //StringToInt will return 0 on failure, which probably means the attribute was specified by name, not index
					{
						if(StrEqual(attributes[key], "all"))
						{
							TF2Attrib_RemoveAll(entity);
							Debug("\t\tRemoved all attributes");
							break;  //Just exit the for loop since we've already removed all attributes
						}
						else
						{
							TF2Attrib_RemoveByName(entity, attributes[key]);
							Debug("\t\tRemoved attribute %s", attributes[key]);
						}
					}
					else if(attribute<0)
					{
						LogError("[FF2 Weapons] Ignoring attribute %s passed for weapon %s (index %i) while removing attributes", attributes[key], classname, iItemDefinitionIndex);
					}
					else
					{
						TF2Attrib_RemoveByDefIndex(entity, attribute);
						Debug("\t\tRemoved attribute %i", attribute);
					}
				}
				kvWeaponMods.GoBack();
			}

			/*if(kvWeaponMods.JumpToKey("remove"))  //TODO: remove-all (TF2Attrib)
			{
				Debug("\tEntered remove");
				if(kvWeaponMods.GotoFirstSubKey(false))
				{
					Debug("\t\tEntered first subkey");
					int attributes[64];
					int attribCount=1;

					attributes[0]=kvWeaponMods.GetNum("1");
					Debug("\t\tKeyvalues classname>removeattribs: First attrib was %i", attributes[0]);

					for(int key=2; kvWeaponMods.GotoNextKey(false); key++)
					{
						char temp[4];
						IntToString(key, temp, sizeof(temp));
						attributes[key]=kvWeaponMods.GetNum(temp);
						Debug("\t\tKeyvalues classname>removeattribs: Got attrib %i", attributes[key]);
						attribCount++;
					}
					Debug("\t\tFinal attrib count was %i", attribCount);

					if(attribCount>0)
					{
						int i=0;
						for(int attribute=0; attribute<attribCount && i<16; attribute++)
						{
							if(!attributes[attribute])
							{
								LogError("[FF2 Weapons] Bad weapon attribute passed for weapon %s", classname);
								delete weapon;
								weapon=null;
								return Plugin_Stop;
							}

							Debug("\t\tRemoved attribute %i", attributes[attribute]);
							int entity=FindEntityByClassname(-1, classname);
							if(entity!=-1)
							{
								TF2Attrib_RemoveByDefIndex(entity, attributes[attribute]);
							}
							i++;
						}
					}
				}
				else
				{
					LogError("[FF2 Weapons] There was nothing under \"remove\" for classname %s!", classname);
				}
				kvWeaponMods.GoBack();
			}*/

			/*if(kvWeaponMods.JumpToKey("add"))  //TODO: Preserve attributes
			{
				if(kvWeaponMods.GotoFirstSubKey(false))
				{
					Debug("\t\tEntered first subkey");
					char attributes[64][64];
					int attribCount=1;

					kvWeaponMods.GetSectionName(attributes[0], sizeof(attributes));
					kvWeaponMods.GetString(attributes[0], attributes[1], sizeof(attributes));
					Debug("\t\tFirst attrib set was %s ; %s", attributes[0], attributes[1]);

					for(int key=3; kvWeaponMods.GotoNextKey(); key+=2)
					{
						kvWeaponMods.GetSectionName(attributes[key], sizeof(attributes));
						kvWeaponMods.GetString(attributes[key], attributes[key+1], sizeof(attributes));
						Debug("\t\tGot attrib set %s ; %s", attributes[key], attributes[key+1]);
						attribCount++;
					}
					Debug("\t\tFinal attrib count was %i", attribCount);

					if(attribCount%2!=0)
					{
						attribCount--;
					}

					if(attribCount>0)
					{
						int i=0;
						for(int attribute=0; attribute<attribCount && i<16; attribute+=2)
						{
							int attrib=StringToInt(attributes[attribute]);
							if(attrib==0)
							{
								LogError("[FF2 Weapons] Bad weapon attribute passed for weapon %s: %s ; %s", classname, attributes[attribute], attributes[attribute+1]);
								delete weapon;
								weapon=null;
								return Plugin_Stop;
							}

							Debug("\t\tKeyvalues classname>addattribs: Added attrib set %s ; %s", attributes[attribute], attributes[attribute+1]);
							int entity=FindEntityByClassname(-1, classname);
							{  //FIXME: THIS BRACKET
								TF2Attrib_SetByDefIndex(entity, StringToInt(attributes[attribute]), StringToFloat(attributes[attribute+1]));
							}
							i++;
						}
					}
				}
				else
				{
					LogError("[FF2 Weapons] There was nothing under \"Addattribs\" for classname %s!", classname);
				}
				kvWeaponMods.GoBack();
			}*/
		}

		/*if(differentClass)
		{
			Debug("Keyvalues differentClass: Gave weapon!");
			TF2Items_GiveNamedItem(client, weapon);
			delete weapon;
			weapon=null;
			return Plugin_Stop;
		}*/
	}

	switch(iItemDefinitionIndex)
	{
		case 38, 457:  //Axtinguisher, Postal Pummeler
		{
			Handle itemOverride=PrepareItemHandle(item, _, _, "", false);
			if(itemOverride!=null)
			{
				item=itemOverride;
				return Plugin_Changed;
			}
		}
		case 39, 351, 1081:  //Flaregun, Detonator, Festive Flaregun
		{
			Handle itemOverride=PrepareItemHandle(item, _, _, "25 ; 0.5 ; 58 ; 3.2 ; 144 ; 1.0 ; 207 ; 1.33", false);
				//25: -50% ammo
				//58: 220% self damage force
				//144: NOPE
				//207: +33% damage to self
			if(itemOverride!=null)
			{
				item=itemOverride;
				return Plugin_Changed;
			}
		}
		case 40, 1146:  //Backburner, Festive Backburner
		{
			Handle itemOverride=PrepareItemHandle(item, _, _, "165 ; 1.0");
			if(itemOverride!=null)
			{
				item=itemOverride;
				return Plugin_Changed;
			}
		}
/*
		case 215:  //The Degreaser
		{
			Handle itemOverride=PrepareItemHandle(item, _, _, "");
			if(itemOverride!=null)
			{
				item=itemOverride;
				return Plugin_Changed;
			}
		}
*/
		case 224:  //L'etranger
		{
			Handle itemOverride=PrepareItemHandle(item, _, _, "85 ; 0.5 ; 157 ; 1.0 ; 253 ; 1.0");
				//85: +50% time needed to regen cloak
				//157: +1 second needed to fully disguise
				//253: +1 second needed to fully cloak
			if(itemOverride!=null)
			{
				item=itemOverride;
				return Plugin_Changed;
			}
		}
		case 239, 1084, 1100:  //GRU, Festive GRU, Bread Bite
		{
			Handle itemOverride=PrepareItemHandle(item, _, _, "1 ; 0.5 ; 107 ; 1.5 ; 128 ; 1 ; 191 ; -7 ; 772 ; 1.5", false);
				//1: -50% damage
				//107: +50% move speed
				//128: Only when weapon is active
				//191: -7 health/second
				//772: Holsters 50% slower
			if(itemOverride!=null)
			{
				item=itemOverride;
				return Plugin_Changed;
			}
		}
		case 56, 1005, 1092:  //Huntsman, Festive Huntsman, Fortified Compound
		{
			Handle itemOverride=PrepareItemHandle(item, _, _, "2 ; 1.5 ; 76 ; 2");
				//2: +50% damage
				//76: +100% ammo
			if(itemOverride!=null)
			{
				item=itemOverride;
				return Plugin_Changed;
			}
		}
		/*case 132, 266, 482:  //Eyelander, HHHH, Nessie's Nine Iron - commented out because
		{
			Handle itemOverride=PrepareItemHandle(item, _, _, "202 ; 0.5 ; 125 ; -15", false);
			if(itemOverride!=null)
			{
				item=itemOverride;
				return Plugin_Changed;
			}
		}*/
		case 226:  //Battalion's Backup
		{
			Handle itemOverride=PrepareItemHandle(item, _, _, "140 ; 10.0");
			if(itemOverride!=null)
			{
				item=itemOverride;
				return Plugin_Changed;
			}
		}
		case 231:  //Darwin's Danger Shield
		{
			Handle itemOverride=PrepareItemHandle(item, _, _, "26 ; 50");  //+50 health
			if(itemOverride!=null)
			{
				item=itemOverride;
				return Plugin_Changed;
			}
		}
		case 305, 1079:  //Crusader's Crossbow, Festive Crusader's Crossbow
		{
			Handle itemOverride=PrepareItemHandle(item, _, _, "2 ; 1.2 ; 17 ; 0.15");
				//2: +20% damage
				//17: +15% uber on hit
			if(itemOverride!=null)
			{
				item=itemOverride;
				return Plugin_Changed;
			}
		}
		case 331:  //Fists of Steel
		{
			Handle itemOverride=PrepareItemHandle(item, _, _, "205 ; 0.8 ; 206 ; 2.0 ; 772 ; 2.0", false);
				//205: -80% damage from ranged while active
				//206: +100% damage from melee while active
				//772: Holsters 100% slower
			if(itemOverride!=null)
			{
				item=itemOverride;
				return Plugin_Changed;
			}
		}
		case 415:  //Reserve Shooter
		{
			Handle itemOverride=PrepareItemHandle(item, _, _, "2 ; 1.1 ; 3 ; 0.5 ; 114 ; 1 ; 179 ; 1 ; 547 ; 0.6", false);
				//2: +10% damage bonus
				//3: -50% clip size
				//114: Mini-crits targets launched airborne by explosions, grapple hooks or enemy attacks
				//179: Minicrits become crits
				//547: Deploys 40% faster
			if(itemOverride!=null)
			{
				item=itemOverride;
				return Plugin_Changed;
			}
		}
/*
		case 133, 444:  // Gunboats, Mantreads
		{
			Handle itemOverride;

			if(iItemDefinitionIndex==444)
				itemOverride=PrepareItemHandle(item, _, _, "58 ; 1.5");

			if(itemOverride!=null)
			{
				item=itemOverride;
				return Plugin_Changed;
			}
		}
*/
		case 648:  //Wrap Assassin
		{
			Handle itemOverride=PrepareItemHandle(item, _, _, "279 ; 2.0");
				//279: 2 ornaments
			if(itemOverride!=null)
			{
				item=itemOverride;
				return Plugin_Changed;
			}
		}
		case 656:  //Holiday Punch
		{
			Handle itemOverride=PrepareItemHandle(item, _, _, "199 ; 0 ; 547 ; 0 ; 358 ; 0 ; 362 ; 0 ; 363 ; 0 ; 369 ; 0", false);
				//199: Holsters 100% faster
				//547: Deploys 100% faster
				//Other attributes: Because TF2Items doesn't feel like stripping the Holiday Punch's attributes for some reason
			if(itemOverride!=null)
			{
				item=itemOverride;
				return Plugin_Changed;
			}
		}
		case 772:  //Baby Face's Blaster
		{
			Handle itemOverride=PrepareItemHandle(item, _, _, "1 ; 0.8 ; 109 ; 0.5 ; 125 ; -25 ; 236 ; 1.0 ; 394 ; 0.85 ; 418 ; 1 ; 419 ; 100 ; 532 ; 0.5 ; 651 ; 0.5 ; 709 ; 1", false);
				//1: -20% damage penalty
				//2: +15% damage bonus
				//109: -50% health from packs on wearer
				//125: -25 max health
				//236: Blocks healing while in use
				//394: 15% firing speed bonus hidden
				//418: Build hype for faster speed
				//419: Hype resets on jump
				//532: Hype decays
				//651: Fire rate increases as health decreases
				//709: Weapon spread increases as health decreases
			if(itemOverride!=null)
			{
				item=itemOverride;
				return Plugin_Changed;
			}
		}
		case 1103:  //Back Scatter
		{
			Handle itemOverride=PrepareItemHandle(item, _, _, "179 ; 1");
				//179: Crit instead of mini-critting
			if(itemOverride!=null)
			{
				item=itemOverride;
				return Plugin_Changed;
			}
		}
		case 588: // The Pomson 6000
		{
			Handle itemOverride=PrepareItemHandle(item, _, _, "6 ; 0.6 ; 97 ; 0.5");
			// 6: fire speed
			// 97: reload speed
			if(itemOverride!=null)
			{
				item=itemOverride;
				return Plugin_Changed;
			}
		}
		case 142: // The Gunslinger
		{
			Handle itemOverride=PrepareItemHandle(item, _, _, "6 ; 0.8 ; 140 ; 50.0");
			// 6: fire speed
			// 140: max health
			if(itemOverride!=null)
			{
				item=itemOverride;
				return Plugin_Changed;
			}
		}
/*
		case 527: // The Widowmaker
		{
			Handle itemOverride=PrepareItemHandle(item, _, _, "106 ; 0.8");
			// 6: fire speed
			// 106: accurate
			if(itemOverride!=null)
			{
				item=itemOverride;
				return Plugin_Changed;
			}
		}
*/
		case 594: // The Phlogistinator
		{
			Handle itemOverride=PrepareItemHandle(item, _, _, "841 ; 0 ; 843 ; 8.5 ; 865 ; 50 ; 844 ; 2450 ; 839 ; 2.8 ; 862 ; 0.6 ; 863 ; 0.1 ; 356 ; 1.0");
			// 6: fire speed
			// 106: accurate
			if(itemOverride!=null)
			{
				item=itemOverride;
				return Plugin_Changed;
			}
		}
	}

	if(!StrContains(classname, "tf_weapon_rocketpack"))  // Thermal Thruster
	{
		Handle itemOverride=PrepareItemHandle(item, _, _, "856 ; 1.0 ; 801 ; 18.0 ; 872 ; 1.0 ; 873 ; 1.0", false);
			//870: falling_impact_radius_pushback
			//871: falling_impact_radius_stun
			//872: thermal_thruster_air_launch
			//96: Reload time increased

		if(itemOverride!=null)
		{
			item=itemOverride;
			return Plugin_Changed;
		}
	}
/*
	if(!StrContains(classname, "tf_weapon_jar") && !StrEqual(classname, "tf_weapon_jar_gas"))  // exclude gas passer
	{
		Handle itemOverride=PrepareItemHandle(item, _, _, "313 ; 0.1", false);

		if(itemOverride!=null)
		{
			item=itemOverride;
			return Plugin_Changed;
		}
	}
*/
	if(TF2_GetPlayerClass(client)==TFClass_Soldier && (!StrContains(classname, "tf_weapon_rocketlauncher", false) || !StrContains(classname, "tf_weapon_shotgun", false)))
	{
		Handle itemOverride;
		if(iItemDefinitionIndex==127)  //Direct Hit
		{
			itemOverride=PrepareItemHandle(item, _, _, "114 ; 1 ; 179 ; 1.0");
				//114: Mini-crits targets launched airborne by explosions, grapple hooks or enemy attacks
				//179: Mini-crits become crits
		}
		else
		{
			itemOverride=PrepareItemHandle(item, _, _, "114 ; 1");
				//114: Mini-crits targets launched airborne by explosions, grapple hooks or enemy attacks
		}

		if(itemOverride!=null)
		{
			item=itemOverride;
			return Plugin_Changed;
		}
	}

	if(TF2_GetPlayerClass(client)==TFClass_Heavy && !StrContains(classname, "tf_weapon_shotgun", false))
	{
		Handle itemOverride=PrepareItemHandle(item, _, _, "741 ; 50.0");
		//741: On Hit: Gain up to +%1$s health per attack

		if(itemOverride!=null)
		{
			item=itemOverride;
			return Plugin_Changed;
		}
	}

	if(!StrContains(classname, "tf_weapon_pda_engineer_build"))  // Construction PDA
	{
		Handle itemOverride=PrepareItemHandle(item, _, _, "345 ; 4.00 ; 276 ; 1.0", false);
			//345: engy dispenser radius increased
			//276: bidirectional_teleport

		if(itemOverride!=null)
		{
			item=itemOverride;
			return Plugin_Changed;
		}
	}

	if(!StrContains(classname, "tf_weapon_syringegun_medic"))  //Syringe guns
	{
		Handle itemOverride=PrepareItemHandle(item, _, _, "17 ; 0.05 ; 144 ; 1", false);
			//17: 5% uber on hit
			//144: Sets weapon mode - *possibly* the overdose speed effect

		if(itemOverride!=null)
		{
			item=itemOverride;
			return Plugin_Changed;
		}
	}

	if(!StrContains(classname, "tf_weapon_medigun"))  //Mediguns
	{
		Handle itemOverride=PrepareItemHandle(item, _, _, "10 ; 1.75 ; 11 ; 1.5 ; 144 ; 2.0 ; 199 ; 0.75 ; 314 ; 4 ; 547 ; 0.75", false);
			//10: +75% faster charge rate
			//11: +50% overheal bonus
			//144: Quick-fix speed/jump effects
			//199: Deploys 25% faster
			//314: Ubercharge lasts 4 seconds longer (aka 50% longer)
			//547: Holsters 25% faster
		if(itemOverride!=null)
		{
			item=itemOverride;
			return Plugin_Changed;
		}
	}
/*
	if(!StrContains(classname, "tf_weapon_flamethrower"))
	{
		Handle itemOverride=PrepareItemHandle(item, _, _, "841 ; 0 ; 843 ; 8.5 ; 865 ; 50 ; 844 ; 2450 ; 839 ; 2.8 ; 862 ; 0.6 ; 863 ; 0.1 ; 255 ; 2.0 ; 255; 0.5", false);
		// 255: airblast push force
		if(itemOverride!=null)
		{
			item=itemOverride;
			return Plugin_Changed;
		}
	}

	if(!StrContains(classname, "tf_weapon_rocketlauncher_fireball"))
	{
		Handle itemOverride=PrepareItemHandle(item, _, _, "856 ; 1 ; 801 ; 0.8 ; 37 ; 0.2 ; 2062 ; 0.25 ; 2065 ; 1 ; 2063 ; 1 ; 255 ; 2.0 ; 255; 0.5", false);
		// 256: airblast_refire_time
		if(itemOverride!=null)
		{
			item=itemOverride;
			return Plugin_Changed;
		}
	}
*/
	return Plugin_Continue;
}

public Action Timer_NoHonorBound(Handle timer, int userid)
{
	int client=GetClientOfUserId(userid);
	if(IsValidClient(client) && IsPlayerAlive(client))
	{
		int melee=GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
		int index=((IsValidEntity(melee) && melee>MaxClients) ? GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex") : -1);
		int weapon=GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		char classname[64];
		if(IsValidEntity(weapon))
		{
			GetEntityClassname(weapon, classname, sizeof(classname));
		}
		if(index==357 && weapon==melee && StrEqual(classname, "tf_weapon_katana", false))
		{
			SetEntProp(melee, Prop_Send, "m_bIsBloody", 1);
			if(GetEntProp(client, Prop_Send, "m_iKillCountSinceLastDeploy")<1)
			{
				SetEntProp(client, Prop_Send, "m_iKillCountSinceLastDeploy", 1);
			}
		}
	}
}

/*
 * Prepares a new item handle based on an existing one
 *
 * @param item			Existing item handle
 * @param classname		Classname of the weapon
 * @param index			Index of the weapon
 * @param attributeList	String of attributes in a 'name ; value' pattern (optional)
 * @param preserve		Whether to preserve existing attributes or to overwrite them
 *
 * @return				Item handle on success, null on failure
 */
stock Handle PrepareItemHandle(Handle item, char[] classname="", int index=-1, const char[] attributeList="", bool preserve=true)
{
	// TODO: This duplicates a whole lot of logic in SpawnWeapon
	static Handle weapon;
	int addattribs;

	char attributes[32][32];
	int count=ExplodeString(attributeList, ";", attributes, 32, 32);

	if(count==1) // ExplodeString returns the original string if no matching delimiter was found so we need to special-case this
	{
		if(attributeList[0]!='\0') // Ignore empty attribute list
		{
			LogError("[FF2 Weapons] Unbalanced attributes array '%s' for weapon %s", attributeList, classname);
			if(weapon!=null)
			{
				delete weapon;
			}
			return weapon;
		}
		else
		{
			count=0;
		}
	}
	else if(count % 2) // Unbalanced array, eg "2 ; 10 ; 3"
	{
		LogError("[FF2 Weapons] Unbalanced attributes array %s for weapon %s", attributeList, classname);
		if(weapon!=null)
		{
			delete weapon;
		}
		return weapon;
	}

	int flags=OVERRIDE_ATTRIBUTES;
	if(preserve)
	{
		flags|=PRESERVE_ATTRIBUTES;
	}

	if(weapon==null)
	{
		weapon=TF2Items_CreateItem(flags);
	}
	else
	{
		TF2Items_SetFlags(weapon, flags);
	}

	if(item!=null)
	{
		addattribs=TF2Items_GetNumAttributes(item);
		if(addattribs>0)
		{
			for(int i; i<2*addattribs; i+=2)
			{
				bool dontAdd;
				int attribIndex=TF2Items_GetAttributeId(item, i);
				for(int z; z<count+i; z+=2)
				{
					if(StringToInt(attributes[z])==attribIndex)
					{
						dontAdd=true;
						break;
					}
				}

				if(!dontAdd)
				{
					IntToString(attribIndex, attributes[i+count], 32);
					FloatToString(TF2Items_GetAttributeValue(item, i), attributes[i+1+count], 32);
				}
			}
			count+=2*addattribs;
		}

		if(weapon!=item)  //FlaminSarge: Item might be equal to weapon, so closing item's handle would also close weapon's
		{
			delete item;  //probably returns false but whatever (rswallen-apparently not)
		}
	}

	if(classname[0]!='\0')
	{
		flags|=OVERRIDE_CLASSNAME;
		TF2Items_SetClassname(weapon, classname);
	}

	if(index!=-1)
	{
		flags|=OVERRIDE_ITEM_DEF;
		TF2Items_SetItemIndex(weapon, index);
	}

	if(count>0)
	{
		TF2Items_SetNumAttributes(weapon, count/2);
		int i2;
		for(int i; i<count && i2<16; i+=2)
		{
			int attrib=StringToInt(attributes[i]);
			if(!attrib)
			{
				LogError("[FF2 Weapons] Bad weapon attribute passed: %s ; %s", attributes[i], attributes[i+1]);
				delete weapon;
				return weapon;
			}

			TF2Items_SetAttribute(weapon, i2, StringToInt(attributes[i]), StringToFloat(attributes[i+1]));
			i2++;
		}
	}
	else
	{
		TF2Items_SetNumAttributes(weapon, 0);
	}
	TF2Items_SetFlags(weapon, flags);
	return weapon;
}

public Action MakeNotBoss(Handle timer, int userid)
{
	int client=GetClientOfUserId(userid);
	if(!IsValidClient(client) || !IsPlayerAlive(client) || CheckRoundState()==FF2RoundState_RoundEnd || IsBoss(client) || (FF2Flags[client] & FF2FLAG_ALLOWSPAWNINBOSSTEAM))
	{
		return Plugin_Continue;
	}

	if(!IsFakeClient(client) && CheckRoundState()==FF2RoundState_Setup
		&& !IsVoteInProgress() && !(FF2Flags[client] & FF2FLAG_CLASSHELPED))
	{
		if(!GetClientClassInfoCookie(client))
			HelpPanelClass(client);
		else if(GetClientClassInfoCookie(client) == 2)
			HelpPanelBoss(client, GetBossIndex(Boss[0]));
	}

	SetEntProp(client, Prop_Send, "m_bGlowEnabled", 0);  //This really shouldn't be needed but I've been noticing players who still have glow

	SetEntityHealth(client, GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, client)); //Temporary: Reset health to avoid an overheal bug
	if(TF2_GetClientTeam(client)==BossTeam)
	{
		AssignTeam(client, OtherTeam);
	}

	CreateTimer(0.1, CheckItems, userid, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

public Action CheckItems(Handle timer, int userid)
{
	int client=GetClientOfUserId(userid);
	if(!IsValidClient(client) || !IsPlayerAlive(client) || CheckRoundState()==FF2RoundState_RoundEnd || IsBoss(client) || (FF2Flags[client] & FF2FLAG_ALLOWSPAWNINBOSSTEAM))
	{
		return Plugin_Continue;
	}

	SetEntityRenderColor(client, 255, 255, 255, 255);
	shield[client]=0;
	int index=-1;
	int[] civilianCheck=new int[MaxClients+1];

	//Cloak and Dagger is NEVER allowed, even in Medieval mode
	int weapon=GetPlayerWeaponSlot(client, 4);
	if(IsValidEntity(weapon) && GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex")==60)  //Cloak and Dagger
	{
		TF2_RemoveWeaponSlot(client, 4);
		SpawnWeapon(client, "tf_weapon_invis", 30);
	}

	if(bMedieval)
	{
		return Plugin_Continue;
	}

	weapon=GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
	if(IsValidEntity(weapon))
	{
		index=GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
		switch(index)
		{
			case 41:  //Natascha
			{
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
				SpawnWeapon(client, "tf_weapon_minigun", 15);
			}
			case 237:  //Rocket Jumper
			{
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
				SpawnWeapon(client, "tf_weapon_rocketlauncher", 18, 1, 0, "114 ; 1");
					//114: Mini-crits targets launched airborne by explosions, grapple hooks or enemy attacks
				FF2_SetAmmo(client, weapon, 20);
			}
			case 402:  //Bazaar Bargain
			{
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
				SpawnWeapon(client, "tf_weapon_sniperrifle", 14);
			}
		}
	}
	else
	{
		civilianCheck[client]++;
	}

	weapon=GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
	if(IsValidEntity(weapon))
	{
		index=GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
		switch(index)
		{
			case 265:  //Stickybomb Jumper
			{
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
				SpawnWeapon(client, "tf_weapon_pipebomblauncher", 20);
				FF2_SetAmmo(client, weapon, 24);
			}
		}

		if(TF2_GetPlayerClass(client)==TFClass_Medic)
		{
			if(GetIndexOfWeaponSlot(client, TFWeaponSlot_Melee)==142)  //Gunslinger (Randomizer, etc. compatability)
			{
				SetEntityRenderMode(weapon, RENDER_TRANSCOLOR);
				SetEntityRenderColor(weapon, 255, 255, 255, 75);
			}
		}
	}
	else
	{
		civilianCheck[client]++;
	}

	int playerBack=FindPlayerBack(client, 57);  //Razorback
	shield[client]=IsValidEntity(playerBack) ? playerBack : 0;
	if(IsValidEntity(FindPlayerBack(client, 642)))  //Cozy Camper
	{
		SpawnWeapon(client, "tf_weapon_smg", 16, 1, 6, "149 ; 1.5 ; 15 ; 0.0 ; 1 ; 0.85");
	}

	// TODO: 이 구문 삭제
	if(IsValidEntity(FindPlayerBack(client, 444)))  //Mantreads
	{
		TF2Attrib_SetByDefIndex(client, 58, 1.5);  //+50% increased push force
	}
	else
	{
		TF2Attrib_RemoveByDefIndex(client, 58);
	}

	TF2Attrib_SetByDefIndex(client, 112, 0.05); // NOTE: 무한탄약
	TF2Attrib_SetByDefIndex(client, 113, 30.0); // NOTE: 무한금속
	TF2Attrib_RemoveByDefIndex(client, 252); // NOTE: 보스 넉백 저항

	int entity=-1;
	while((entity=FindEntityByClassname2(entity, "tf_wearable_demoshield"))!=-1)  //Demoshields
	{
		if(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")==client && !GetEntProp(entity, Prop_Send, "m_bDisguiseWearable"))
		{
			shield[client]=entity;
		}
	}

	weapon=GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
	if(IsValidEntity(weapon))
	{
		index=GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
		switch(index)
		{
			case 43:  //KGB
			{
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_Melee);
				SpawnWeapon(client, "tf_weapon_fists", 239, 1, 6, "1 ; 0.5 ; 107 ; 1.5 ; 128 ; 1 ; 191 ; -7 ; 772 ; 1.5");  //GRU
					//1: -50% damage
					//107: +50% move speed
					//128: Only when weapon is active
					//191: -7 health/second
					//772: Holsters 50% slower
			}
			case 357:  //Half-Zatoichi
			{
				CreateTimer(1.0, Timer_NoHonorBound, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
			}
			case 589:  //Eureka Effect
			{
				if(!cvarEnableEurekaEffect.BoolValue)
				{
					TF2_RemoveWeaponSlot(client, TFWeaponSlot_Melee);
					SpawnWeapon(client, "tf_weapon_wrench", 7);
				}
			}
		}
	}
	else
	{
		civilianCheck[client]++;
	}

	if(civilianCheck[client]==3)
	{
		civilianCheck[client]=0;
		Debug("Respawning %N to avoid civilian bug", client);
		TF2_RespawnPlayer(client);
	}
	civilianCheck[client]=0;
	return Plugin_Continue;
}

public Action OnObjectDestroyed(Event event, const char[] name, bool dontBroadcast)
{
	if(Enabled)
	{
		int attacker=GetClientOfUserId(event.GetInt("attacker"));
		if(!GetRandomInt(0, 2) && IsBoss(attacker))
		{
			int boss=GetBossIndex(attacker);
			char sound[PLATFORM_MAX_PATH];

			if(FindSound("destroy building", sound, sizeof(sound), boss))
			{
				EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, sound);
				EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, sound);
			}
		}
	}
	return Plugin_Continue;
}

public Action OnUberDeployed(Event event, const char[] name, bool dontBroadcast)
{
	int client=GetClientOfUserId(event.GetInt("userid"));
	if(Enabled && IsValidClient(client) && IsPlayerAlive(client))
	{
		int medigun=GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
		if(IsValidEntity(medigun))
		{
			char classname[64];
			GetEntityClassname(medigun, classname, sizeof(classname));
			if(StrEqual(classname, "tf_weapon_medigun"))
			{
				TF2_AddCondition(client, TFCond_HalloweenCritCandy, 0.5, client);
				TF2_AddCondition(client, TFCond_Ubercharged, 0.5);
				int target=GetHealingTarget(client);
				if(IsValidClient(target, false) && IsPlayerAlive(target))
				{
					TF2_AddCondition(target, TFCond_HalloweenCritCandy, 0.5, client);
					uberTarget[client]=target;
				}
				else
				{
					uberTarget[client]=-1;
				}
				CreateTimer(0.4, Timer_Uber, EntIndexToEntRef(medigun), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
	return Plugin_Continue;
}

public Action Timer_Uber(Handle timer, int medigunid)
{
	int medigun=EntRefToEntIndex(medigunid);
	if(medigun && IsValidEntity(medigun) && CheckRoundState()==FF2RoundState_RoundRunning && GetEntProp(medigun, Prop_Send, "m_bChargeRelease")>0)
	{
		int client=GetEntPropEnt(medigun, Prop_Send, "m_hOwnerEntity");
		float charge=GetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel");
		if(IsValidClient(client, false) && IsPlayerAlive(client) && GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon")==medigun)
		{
			int target=GetHealingTarget(client);
			if(charge>0.05)
			{
				TF2_AddCondition(client, TFCond_HalloweenCritCandy, 0.5);
				if(IsValidClient(target, false) && IsPlayerAlive(target))
				{
					TF2_AddCondition(target, TFCond_HalloweenCritCandy, 0.5);
					uberTarget[client]=target;
				}
				else
				{
					uberTarget[client]=-1;
				}
			}
			else
			{
				return Plugin_Stop;
			}
		}
	}
	else
	{
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public Action Command_GetHPCmd(int client, int args)
{
	if(!IsValidClient(client) || !Enabled || CheckRoundState()!=FF2RoundState_RoundRunning)
	{
		return Plugin_Continue;
	}

	Command_GetHP(client);
	return Plugin_Handled;
}

public Action Command_GetHP(int client)  //TODO: This can rarely show a very large negative number if you time it right
{
	if(IsBoss(client) || GetGameTime()>=HPTime)
	{
		char text[512];  //Do not decl this
		char lives[8], name[64];
		int bossindexs[MAXPLAYERS+1], bosscount=0;

		for(int target=1; target<=MaxClients; target++)
		{
			if(IsBoss(target) && BossTeam == TF2_GetClientTeam(target))
			{
				bossindexs[bosscount++]=Boss[target];
				BossHealthLast[bossindexs[bosscount]]=BossHealth[bossindexs[bosscount]]-BossHealthMax[bossindexs[bosscount]]*(BossLives[bossindexs[bosscount]]-1);
			}
		}

		for(int target=1; target<=MaxClients; target++)
		{
			if(IsValidClient(target) && !IsFakeClient(target) && !(FF2Flags[target] & FF2FLAG_HUDDISABLED))
			{
				SetGlobalTransTarget(target);
				Format(text, sizeof(text), "");

				for(int loop; loop<bosscount; loop++)
				{
					GetBossName(bossindexs[loop], name, sizeof(name), target);
					if(BossLives[bossindexs[loop]]>1)
					{
						Format(lives, sizeof(lives), "x%i", BossLives[bossindexs[loop]]);
					}
					else
					{
						strcopy(lives, 2, "");
					}
					Format(text, sizeof(text), "%s\n%t", text, "Boss Current Health", name, BossHealthLast[bossindexs[loop]], BossHealthMax[bossindexs[loop]], lives);
					CPrintToChat(target, "{olive}[FF2]{default} %t", "Boss Current Health", name, BossHealthLast[bossindexs[loop]], BossHealthMax[bossindexs[loop]], lives);
				}
				PrintCenterText(target, text);
			}
		}

		if(GetGameTime()>=HPTime)
		{
			healthcheckused++;
			HPTime=GetGameTime()+(healthcheckused<3 ? 20.0 : 80.0);
		}
		return Plugin_Continue;
	}

	if(RedAlivePlayers>1)
	{
		char waitTime[128];
		for(int target=1; target<=MaxClients; target++)
		{
			if(IsBoss(target))
			{
				Format(waitTime, sizeof(waitTime), "%s %i,", waitTime, BossHealthLast[Boss[target]]);
			}
		}
		CPrintToChat(client, "{olive}[FF2]{default} %t", "Wait for Health Value", RoundFloat(HPTime-GetGameTime()), waitTime);
	}
	return Plugin_Continue;
}

public Action Command_SetNextBoss(int client, int args)
{
	char name[64], boss[64];

	if(args<1)
	{
		CReplyToCommand(client, "{olive}[FF2]{default} Usage: ff2_special <boss>");
		return Plugin_Handled;
	}
	GetCmdArgString(name, sizeof(name));

	for(int config; config < bossesArray.Length; config++)
	{
		KeyValues kv = bossesArray.Get(config);
		kv.Rewind();
		kv.GetString("name", boss, sizeof(boss));
		if(StrContains(boss, name, false)!=-1)
		{
			Incoming[0]=config;
			CReplyToCommand(client, "{olive}[FF2]{default} Set the next boss to %s", boss);
			return Plugin_Handled;
		}

		kv.GetString("filename", boss, sizeof(boss));
		if(StrContains(boss, name, false)!=-1)
		{
			Incoming[0]=config;
			kv.GetString("name", boss, sizeof(boss));
			CReplyToCommand(client, "{olive}[FF2]{default} Set the next boss to %s", boss);
			return Plugin_Handled;
		}
	}
	CReplyToCommand(client, "{olive}[FF2]{default} Boss could not be found!");
	return Plugin_Handled;
}

public Action Command_Points(int client, int args)
{
	if(!Enabled2)
	{
		return Plugin_Continue;
	}

	if(args!=2)
	{
		CReplyToCommand(client, "{olive}[FF2]{default} Usage: ff2_addpoints <target> <points>");
		return Plugin_Handled;
	}

	char stringPoints[8];
	char pattern[PLATFORM_MAX_PATH];
	GetCmdArg(1, pattern, sizeof(pattern));
	GetCmdArg(2, stringPoints, sizeof(stringPoints));
	int points=StringToInt(stringPoints);

	char targetName[MAX_TARGET_LENGTH];
	int targets[MAXPLAYERS], matches;
	bool targetNounIsMultiLanguage;

	if((matches=ProcessTargetString(pattern, client, targets, sizeof(targets), 0, targetName, sizeof(targetName), targetNounIsMultiLanguage))<=0)
	{
		ReplyToTargetError(client, matches);
		return Plugin_Handled;
	}

	if(matches>1)
	{
		for(int target=1; target<matches; target++)
		{
			if(!IsClientSourceTV(targets[target]) && !IsClientReplay(targets[target]))
			{
				SetClientQueuePoints(targets[target], GetClientQueuePoints(targets[target])+points);
				LogAction(client, targets[target], "\"%L\" added %d queue points to \"%L\"", client, points, targets[target]);
			}
		}
	}
	else
	{
		SetClientQueuePoints(targets[0], GetClientQueuePoints(targets[0])+points);
		LogAction(client, targets[0], "\"%L\" added %d queue points to \"%L\"", client, points, targets[0]);
	}
	CReplyToCommand(client, "{olive}[FF2]{default} Added %d queue points to %s", points, targetName);
	return Plugin_Handled;
}

public Action Command_StartMusic(int client, int args)
{
	if(Enabled2)
	{
		if(args)
		{
			char pattern[MAX_TARGET_LENGTH];
			GetCmdArg(1, pattern, sizeof(pattern));
			char targetName[MAX_TARGET_LENGTH];
			int targets[MAXPLAYERS], matches;
			bool targetNounIsMultiLanguage;
			if((matches=ProcessTargetString(pattern, client, targets, sizeof(targets), COMMAND_FILTER_NO_BOTS, targetName, sizeof(targetName), targetNounIsMultiLanguage))<=0)
			{
				ReplyToTargetError(client, matches);
				return Plugin_Handled;
			}

			if(matches>1)
			{
				for(int target=1; target<matches; target++)
				{
					StartMusic(targets[target]);
				}
			}
			else
			{
				StartMusic(targets[0]);
			}
			CReplyToCommand(client, "{olive}[FF2]{default} Started boss music for %s.", targetName);
		}
		else
		{
			StartMusic();
			CReplyToCommand(client, "{olive}[FF2]{default} Started boss music for all clients.");
		}
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action Command_StopMusic(int client, int args)
{
	if(Enabled2)
	{
		if(args)
		{
			char pattern[MAX_TARGET_LENGTH];
			GetCmdArg(1, pattern, sizeof(pattern));
			char targetName[MAX_TARGET_LENGTH];
			int targets[MAXPLAYERS], matches;
			bool targetNounIsMultiLanguage;
			if((matches=ProcessTargetString(pattern, client, targets, sizeof(targets), COMMAND_FILTER_NO_BOTS, targetName, sizeof(targetName), targetNounIsMultiLanguage))<=0)
			{
				ReplyToTargetError(client, matches);
				return Plugin_Handled;
			}

			if(matches>1)
			{
				for(int target=1; target<matches; target++)
				{
					StopMusic(targets[target], true);
				}
			}
			else
			{
				StopMusic(targets[0], true);
			}
			CReplyToCommand(client, "{olive}[FF2]{default} Stopped boss music for %s.", targetName);
		}
		else
		{
			StopMusic(_, true);
			CReplyToCommand(client, "{olive}[FF2]{default} Stopped boss music for all clients.");
		}
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action Command_Charset(int client, int args)
{
	if(!args)
	{
		CReplyToCommand(client, "{olive}[FF2]{default} Usage: ff2_charset <charset>");
		return Plugin_Handled;
	}

	char charset[32], rawText[16][16];
	GetCmdArgString(charset, sizeof(charset));
	int amount=ExplodeString(charset, " ", rawText, 16, 16);
	for(int i; i<amount; i++)
	{
		StripQuotes(rawText[i]);
	}
	ImplodeStrings(rawText, amount, " ", charset, sizeof(charset));

	char config[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, config, sizeof(config), "%s/%s", FF2_SETTINGS, BOSS_CONFIG);

	KeyValues Kv=new KeyValues("");
	Kv.ImportFromFile(config);
	for(int i; ; i++)
	{
		Kv.GetSectionName(config, sizeof(config));
		if(StrContains(config, charset, false)>=0)
		{
			CReplyToCommand(client, "{olive}[FF2]{default} Charset for nextmap is %s", config);
			isCharSetSelected=true;
			FF2CharSet=i;
			break;
		}

		if(!Kv.GotoNextKey())
		{
			CReplyToCommand(client, "{olive}[FF2]{default} Charset not found");
			break;
		}
	}
	delete Kv;
	return Plugin_Handled;
}

public Action Command_ReloadSubPlugins(int client, int args)
{
	if(Enabled)
	{
		//DisableSubPlugins(true);
		//EnableSubPlugins(true);
		char path[PLATFORM_MAX_PATH], filename[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, path, sizeof(path), "plugins/freak_fortress_2");
		FileType filetype;
		DirectoryListing directory=OpenDirectory(path);
		while(directory.GetNext(filename, sizeof(filename), filetype))
		{
			if(filetype==FileType_File && StrContains(filename, ".smx", false)!=-1)
			{
				ServerCommand("sm plugins unload freak_fortress_2/%s", filename);
				ServerCommand("sm plugins load freak_fortress_2/%s", filename);
			}
		}
	}
	CReplyToCommand(client, "{olive}[FF2]{default} Reloaded subplugins!");
	return Plugin_Handled;
}

public Action Command_Point_Disable(int client, int args)
{
	if(Enabled)
	{
		SetControlPoint(false);
	}
	return Plugin_Handled;
}

public Action Command_Point_Enable(int client, int args)
{
	if(Enabled)
	{
		SetControlPoint(true);
	}
	return Plugin_Handled;
}

public void OnClientPostAdminCheck(int client)
{
	// TODO: Hook these inside of EnableFF2() or somewhere instead
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
	SDKHook(client, SDKHook_OnTakeDamageAlivePost, OnTakeDamageAlivePost);

	FF2Flags[client]=0;
	Damage[client]=0;
	Assist[client]=0;
	uberTarget[client]=-1;

	PlayerHudQueue[client] = FF2HudQueue.CreateHudQueue("Player");

	if(!IsFakeClient(client))
	{
		muteSound[client]=GetSettingData(client, "sound_mute_flag", KvData_Int);
	}

	if(playBGM[0])
	{
		playBGM[client]=true;
		if(Enabled)
		{
			StartMusic(client);
			// CreateTimer(0.1, Timer_PrepareBGM, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	else
	{
		playBGM[client]=false;
	}
}

public void OnClientCookiesCached(int client)
{
	char buffer[4];
	GetClientCookie(client, FF2Cookie_QueuePoints, buffer, sizeof(buffer));
	if(!buffer[0])
	{
		SetClientCookie(client, FF2Cookie_QueuePoints, "0");
	}
	queuePoints[client]=StringToInt(buffer);
}

public void OnClientDisconnect(int client)
{
	if(Enabled)
	{
		if(IsBoss(client) && !CheckRoundState() && cvarPreroundBossDisconnect.BoolValue)
		{
			int boss=GetBossIndex(client);
			bool[] omit=new bool[MaxClients+1];
			omit[client]=true;
			Boss[boss]=GetClientWithMostQueuePoints(omit);

			if(Boss[boss])
			{
				CreateTimer(0.1, MakeBoss, boss, TIMER_FLAG_NO_MAPCHANGE);
				CPrintToChat(Boss[boss], "{olive}[FF2]{default} %t", "Replace Disconnected Boss");
				CPrintToChatAll("{olive}[FF2]{default} %t", "Boss Disconnected", client, Boss[boss]);
			}
		}

		if(IsClientInGame(client) && IsPlayerAlive(client) && CheckRoundState()==FF2RoundState_RoundRunning)
		{
			CreateTimer(0.1, CheckAlivePlayers, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}

	if(MusicTimer[client]!=null)
	{
		delete MusicTimer[client];
	}

	delete PlayerHudQueue[client];
}

public Action OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if(Enabled && CheckRoundState()==FF2RoundState_RoundRunning)
	{
		CreateTimer(0.1, CheckAlivePlayers, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Continue;
}

public Action OnPostInventoryApplication(Event event, const char[] name, bool dontBroadcast)
{
	if(!Enabled)
	{
		return Plugin_Continue;
	}

	int client=GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	SetVariantString("");
	AcceptEntityInput(client, "SetCustomModel");

	if(IsBoss(client))
	{
		CreateTimer(0.1, MakeBoss, GetBossIndex(client), TIMER_FLAG_NO_MAPCHANGE);
	}

	if(!(FF2Flags[client] & FF2FLAG_ALLOWSPAWNINBOSSTEAM))
	{
		if(!(FF2Flags[client] & FF2FLAG_HASONGIVED))
		{
			FF2Flags[client]|=FF2FLAG_HASONGIVED;
			RemovePlayerBack(client, {57, 133, 405, 444, 608, 642}, 7);
			RemovePlayerTarge(client);
			TF2_RemoveAllWeapons(client);
			TF2_RegeneratePlayer(client);
			CreateTimer(0.1, Timer_RegenPlayer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		}
		CreateTimer(0.2, MakeNotBoss, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}

	FF2Flags[client]&=~(FF2FLAG_UBERREADY|FF2FLAG_ISBUFFED|FF2FLAG_ALLOWSPAWNINBOSSTEAM|FF2FLAG_USINGABILITY|FF2FLAG_CLASSHELPED|FF2FLAG_CHANGECVAR|FF2FLAG_ALLOW_HEALTH_PICKUPS|FF2FLAG_ALLOW_AMMO_PICKUPS|FF2FLAG_BLAST_JUMPING);
	FF2Flags[client]|=FF2FLAG_USEBOSSTIMER;
	return Plugin_Continue;
}

void MakePlayerToBoss(int client, int characterIndex)
{
	int boss = client;

	if(IsBoss(client))
	{
		boss=GetBossIndex(client);
		Boss[boss]=0;
		character[boss]=0;
	}

	if(characterIndex != -1)
	{
		Boss[boss]=client;
		character[boss]=characterIndex;
		MakeBoss(INVALID_HANDLE, boss);
	}
	else
	{
		float pos[3], angles[3], velocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecOrigin", pos);
		GetClientEyeAngles(client, angles);
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);

		if((GetEntityFlags(client) & FL_ONGROUND) > 0
			&& GetEntProp(client, Prop_Send, "m_bDucked") > 0)
			pos[2]-=20.0;

		TF2_RespawnPlayer(client);
		TeleportEntity(client, pos, angles, velocity);
	}
}

public int Native_MakePlayerToBoss(Handle plugin, int numParams)
{
	MakePlayerToBoss(GetNativeCell(1), GetNativeCell(2));
}

public Action Timer_RegenPlayer(Handle timer, int userid)
{
	int client=GetClientOfUserId(userid);
	if(IsValidClient(client) && IsPlayerAlive(client))
	{
		TF2_RegeneratePlayer(client);
	}
}

public Action ClientTimer(Handle timer)
{
	if(!Enabled || CheckRoundState()==FF2RoundState_RoundEnd || CheckRoundState()==FF2RoundState_Loading)
	{
		return Plugin_Stop;
	}

	char classname[32], hudText[64];
	TFCond cond;
	FF2HudDisplay hudDisplay;

	for(int client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client) && !IsBoss(client) && !(FF2Flags[client] & FF2FLAG_CLASSTIMERDISABLED))
		{
			SetHudTextParams(-1.0, 0.88, 0.35, 90, 255, 90, 255, 0, 0.35, 0.0, 0.1);
			SetGlobalTransTarget(client);

			PlayerHudQueue[client].SetName("Player");
			if(!IsPlayerAlive(client))
			{
				int observer=GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
				if(IsValidClient(observer) && observer!=client)
				{
					PlayerHudQueue[client].SetName("Observer");
					if(!IsBoss(observer))
					{
						Format(hudText, sizeof(hudText), "%t", "Your Damage Dealt", Damage[client]);
						if(Assist[client] > 0)
							Format(hudText, sizeof(hudText), "%s + ASSIST: %d", hudText, Assist[client]);

						hudDisplay=FF2HudDisplay.CreateDisplay("Your Damage Dealt", hudText);
						PlayerHudQueue[client].AddHud(hudDisplay, client);

						Format(hudText, sizeof(hudText), "%t", "Spectator Damage Dealt", observer, Damage[observer]);
						if(Assist[observer] > 0)
							Format(hudText, sizeof(hudText), "%s + ASSIST: %d", hudText, Assist[observer]);

						hudDisplay=FF2HudDisplay.CreateDisplay("Observer Target Player Damage", hudText);
						PlayerHudQueue[client].AddHud(hudDisplay, client, observer);
					}
					else if(IsBoss(observer))
					{
						int boss=GetBossIndex(observer);
						char lives[8];
						if(BossLives[boss]>1)
						{
							Format(lives, 8, "x%d", BossLives[boss]);
						}
						Format(hudText, sizeof(hudText), "HP: %d / %d%s", BossHealth[boss]-BossHealthMax[boss]*(BossLives[boss]-1), BossHealthMax[boss], lives);
						hudDisplay=FF2HudDisplay.CreateDisplay("Observer Target Boss HP", hudText);
						PlayerHudQueue[client].AddHud(hudDisplay, client);

						if(BossTeam != TF2_GetClientTeam(observer))
						{
							Format(hudText, sizeof(hudText), "%t", "Spectator Damage Dealt", observer, Damage[observer]);
							if(Assist[observer] > 0)
								Format(hudText, sizeof(hudText), "%s + ASSIST: %d", hudText, Assist[observer]);

							hudDisplay = FF2HudDisplay.CreateDisplay("Observer Target Player Damage", hudText);
							PlayerHudQueue[client].AddHud(hudDisplay, client, observer);
						}
					}
				}
				else
				{
					Format(hudText, sizeof(hudText), "%t", "Your Damage Dealt", Damage[client]);
					if(Assist[client] > 0)
						Format(hudText, sizeof(hudText), "%s + ASSIST: %d", hudText, Assist[client]);

					hudDisplay=FF2HudDisplay.CreateDisplay("Your Damage Dealt", hudText);
					PlayerHudQueue[client].AddHud(hudDisplay, client);
				}
			}
			else
			{
#if defined _MVM_included
				if(mannvsmann)
				{
					Format(hudText, sizeof(hudText), "$%d", MVM_GetPlayerCurrency(client));
					hudDisplay=FF2HudDisplay.CreateDisplay("Your Money", hudText);
					PlayerHudQueue[client].AddHud(hudDisplay, client);
				}
#endif

				Format(hudText, sizeof(hudText), "%t", "Your Damage Dealt", Damage[client]);
				if(Assist[client] > 0)
					Format(hudText, sizeof(hudText), "%s + ASSIST: %d", hudText, Assist[client]);

				hudDisplay=FF2HudDisplay.CreateDisplay("Your Damage Dealt", hudText);
				PlayerHudQueue[client].AddHud(hudDisplay, client);
			}
			PlayerHudQueue[client].ShowSyncHudQueueText(client, rageHUD);
			PlayerHudQueue[client].DeleteAllDisplay();

			if(!IsPlayerAlive(client)) continue;

			// Additional HUD Initialize
			PlayerHudQueue[client].SetName("Player Additional");
			SetHudTextParams(-1.0, 0.83, 0.35, 255, 255, 255, 255, 0, 0.2, 0.0, 0.1);

			// Movement speed limit
			float maxspeed = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");
			if(maxspeed > 500.0 && !TF2_IsPlayerInCondition(client, TFCond_Charging) && !TF2_IsPlayerInCondition(client, TFCond_SpeedBuffAlly))
				SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 500.0);

			TFClassType playerclass=TF2_GetPlayerClass(client);
			int weapon=GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			if(weapon<=MaxClients || !IsValidEntity(weapon) || !GetEntityClassname(weapon, classname, sizeof(classname)))
			{
				strcopy(classname, sizeof(classname), "");
			}
			bool validwep=!StrContains(classname, "tf_weapon", false);

			int index=(validwep ? GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") : -1);
			if(playerclass==TFClass_Medic)
			{
				int medigun=GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
				if(weapon==GetPlayerWeaponSlot(client, TFWeaponSlot_Primary))
				{
					char mediclassname[64];
					if(IsValidEntity(medigun) && GetEntityClassname(medigun, mediclassname, sizeof(mediclassname)) && !StrContains(mediclassname, "tf_weapon_medigun", false))
					{
						int charge=RoundToFloor(GetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel")*100);
						Format(hudText, sizeof(hudText), "%T", "Ubercharge", client, charge);
						hudDisplay=FF2HudDisplay.CreateDisplay("Ubercharge", hudText);
						PlayerHudQueue[client].AddHud(hudDisplay, client);

						if(charge==100 && !(FF2Flags[client] & FF2FLAG_UBERREADY))
						{
							FakeClientCommandEx(client, "voicemenu 1 7");
							FF2Flags[client]|=FF2FLAG_UBERREADY;
						}
					}

				}
				else if(weapon==GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary))
				{
					int healtarget=GetHealingTarget(client, true);
					if(IsValidClient(healtarget) && TF2_GetPlayerClass(healtarget)==TFClass_Scout
						&& GetClientTeam(healtarget) == GetClientTeam(client))
					{
						TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.3);
					}
				}

				int melee=GetPlayerWeaponSlot(client, TFWeaponSlot_Melee), meleeIndex;
				if(IsValidEntity(melee))
				{
					meleeIndex=GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");
					if(meleeIndex == 413)
					{
						int allRageDamage, bossIndex;
						float allCharge;

						for(int target=1; target<=MaxClients; target++)
						{
							if((bossIndex = GetBossIndex(target)) != -1 && TF2_GetClientTeam(target) == BossTeam) {
								allRageDamage += BossRageDamage[bossIndex];
								allCharge += BossCharge[bossIndex][0];
							}
						}
						Format(hudText, sizeof(hudText), "%t (%i / %i)", "Current Boss Rage", RoundFloat(allCharge), RoundFloat(allCharge*(allRageDamage/100.0)), allRageDamage);
						hudDisplay=FF2HudDisplay.CreateDisplay("Current Boss Rage", hudText);
						PlayerHudQueue[client].AddHud(hudDisplay, client);
					}
					if(meleeIndex == 173
						&& (IsValidEntity(medigun) && GetEntProp(medigun, Prop_Send, "m_bChargeRelease") == 0))
					{
						int decapitations=GetEntProp(client, Prop_Send, "m_iDecapitations");
						float minCharge=0.1*(decapitations > 6 ? 6 : decapitations),
							currentCharge=GetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel");

						if(minCharge > currentCharge)
							SetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel", minCharge);
					}
				}
			}
			else if(playerclass==TFClass_Soldier)
			{
				if((FF2Flags[client] & FF2FLAG_ISBUFFED) && !(GetEntProp(client, Prop_Send, "m_bRageDraining")))
				{
					FF2Flags[client]&=~FF2FLAG_ISBUFFED;
				}
			}

			if(RedAlivePlayers==1 && !TF2_IsPlayerInCondition(client, TFCond_Cloaked))
			{
				TF2_AddCondition(client, TFCond_HalloweenCritCandy, 0.3);
				if(playerclass==TFClass_Engineer && weapon==GetPlayerWeaponSlot(client, TFWeaponSlot_Primary) && StrEqual(classname, "tf_weapon_sentry_revenge", false))
				{
					SetEntProp(client, Prop_Send, "m_iRevengeCrits", 3);
				}
				TF2_AddCondition(client, TFCond_Buffed, 0.3);

				if(lastPlayerGlow)
				{
					SetClientGlow(client, 3600.0);
				}
			}
			else if(RedAlivePlayers==2 && !TF2_IsPlayerInCondition(client, TFCond_Cloaked))
			{
				TF2_AddCondition(client, TFCond_Buffed, 0.3);
			}
			else if(bMedieval)
			{
				PlayerHudQueue[client].DeleteAllDisplay();
				continue;
			}

			cond=TFCond_HalloweenCritCandy;
			if(TF2_IsPlayerInCondition(client, TFCond_CritCola) && (playerclass==TFClass_Scout /*|| playerclass==TFClass_Heavy*/))
			{
				TF2_AddCondition(client, cond, 0.3);
			}

			int healer=-1;
			for(int healtarget=1; healtarget<=MaxClients; healtarget++)
			{
				if(IsValidClient(healtarget) && IsPlayerAlive(healtarget) && GetHealingTarget(healtarget, true)==client)
				{
					healer=healtarget;
					break;
				}
			}

			bool addthecrit;
			if(validwep && weapon==GetPlayerWeaponSlot(client, TFWeaponSlot_Melee) && StrContains(classname, "tf_weapon_knife", false)==-1)  //Every melee except knives
			{
				addthecrit=true;
				if(index==416)  //Market Gardener
				{
					addthecrit=FF2Flags[client] & FF2FLAG_BLAST_JUMPING ? true : false;
				}
			}
			else if((!StrContains(classname, "tf_weapon_smg") && index!=751) ||  //Cleaner's Carbine
			         !StrContains(classname, "tf_weapon_compound_bow") ||
			         !StrContains(classname, "tf_weapon_crossbow") ||
			         !StrContains(classname, "tf_weapon_pistol") ||
			         !StrContains(classname, "tf_weapon_handgun_scout_secondary"))
			{
				addthecrit=true;
				cond=TFCond_Buffed;
				/*
				if(playerclass==TFClass_Scout && cond==TFCond_HalloweenCritCandy)
				{
					cond=TFCond_Buffed;
				}
				*/
			}

			if(index==16 && IsValidEntity(FindPlayerBack(client, 642)))  //SMG, Cozy Camper
			{
				addthecrit=false;
			}

			switch(playerclass)
			{
				case TFClass_Medic:
				{
					if(weapon==GetPlayerWeaponSlot(client, TFWeaponSlot_Primary))
					{
						int medigun=GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
						char mediclassname[64];
						if(IsValidEntity(medigun) && GetEntityClassname(medigun, mediclassname, sizeof(mediclassname)) && !StrContains(mediclassname, "tf_weapon_medigun", false))
						{
							int charge=RoundToFloor(GetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel")*100);
							if(charge==100 && !(FF2Flags[client] & FF2FLAG_UBERREADY))
							{
								FakeClientCommand(client, "voicemenu 1 7");  //"I am fully charged!"
								FF2Flags[client]|= FF2FLAG_UBERREADY;
							}
						}
					}
					else if(weapon==GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary))
					{
						int healtarget=GetHealingTarget(client, true);
						if(IsValidClient(healtarget) && TF2_GetPlayerClass(healtarget)==TFClass_Scout)
						{
							TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.3);
						}
					}
				}
				case TFClass_DemoMan:
				{
					if(weapon==GetPlayerWeaponSlot(client, TFWeaponSlot_Primary) && !IsValidEntity(GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary)) && shieldCrits)  //Demoshields
					{
						addthecrit=true;
						if(shieldCrits==1)
						{
							cond=TFCond_Buffed;
						}
					}
				}
				case TFClass_Spy:
				{
					if(validwep && weapon==GetPlayerWeaponSlot(client, TFWeaponSlot_Primary))
					{
						if(!TF2_IsPlayerCritBuffed(client) && !TF2_IsPlayerInCondition(client, TFCond_Buffed) && !TF2_IsPlayerInCondition(client, TFCond_Cloaked) && !TF2_IsPlayerInCondition(client, TFCond_Disguised))
						{
							TF2_AddCondition(client, TFCond_CritCola, 0.3);
						}
					}
				}
				case TFClass_Engineer:
				{
					if(weapon==GetPlayerWeaponSlot(client, TFWeaponSlot_Primary) && StrEqual(classname, "tf_weapon_sentry_revenge", false))
					{
						int sentry=FindSentry(client);
						if(IsValidEntity(sentry) && IsBoss(GetEntPropEnt(sentry, Prop_Send, "m_hEnemy")))
						{
							SetEntProp(client, Prop_Send, "m_iRevengeCrits", 3);
							TF2_AddCondition(client, TFCond_Kritzkrieged, 0.3);
						}
						else
						{
							if(GetEntProp(client, Prop_Send, "m_iRevengeCrits"))
							{
								SetEntProp(client, Prop_Send, "m_iRevengeCrits", 0);
							}
							else if(TF2_IsPlayerInCondition(client, TFCond_Kritzkrieged) && !TF2_IsPlayerInCondition(client, TFCond_Healing))
							{
								TF2_RemoveCondition(client, TFCond_Kritzkrieged);
							}
						}
					}
				}
			}

			PlayerHudQueue[client].ShowSyncHudQueueText(client, jumpHUD);
			PlayerHudQueue[client].DeleteAllDisplay();

			if(addthecrit)
			{
				TF2_AddCondition(client, cond, 0.3);
				if(healer!=-1 && cond!=TFCond_Buffed)
				{
					TF2_AddCondition(client, TFCond_Buffed, 0.3);
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action BossTimer(Handle timer)
{
	if(!Enabled || CheckRoundState()==FF2RoundState_RoundEnd)
	{
		return Plugin_Stop;
	}

	bool validBoss;
	for(int boss; boss<=MaxClients; boss++)
	{
		int client=Boss[boss];
		if(!IsValidClient(client) || !IsPlayerAlive(client) || !(FF2Flags[client] & FF2FLAG_USEBOSSTIMER))
		{
			continue;
		}
		// Debug("BossTimer has started for %d at %f", boss, GetGameTime());

		PlayerHudQueue[client].SetName("Boss");
		FF2HudDisplay bossHudDisplay;
		validBoss=true;
		SetGlobalTransTarget(client);
		char text[64];

		// TODO: "use_fixed_speed"
		if(!TF2_IsPlayerInCondition(client, TFCond_Charging))
		{
			if(TF2_GetClientTeam(client) == BossTeam)
				SetEntPropFloat(client, Prop_Data, "m_flMaxspeed", BossSpeed[boss]+0.8*(100-BossHealth[boss]*100/BossLivesMax[boss]/BossHealthMax[boss]));
			else
				SetEntPropFloat(client, Prop_Data, "m_flMaxspeed", BossSpeed[boss]);
		}

		if(BossHealth[boss]<=0 && IsPlayerAlive(client))  //Wat.  TODO:  Investigate
		{
			BossHealth[boss]=1;
		}

		if(BossLivesMax[boss]>1)
		{
			SetHudTextParams(-1.0, 0.77, 0.06, 255, 255, 255, 255);
			FF2_ShowSyncHudText(client, livesHUD, "%t", "Boss Lives Left", BossLives[boss], BossLivesMax[boss]);
		}

		SetHudTextParams(-1.0, 0.83, 0.06, 255, 255, 255, 255);

		for(int loop = SkillName_MaxCounts - 1; loop >= 0; loop--)
		{
			if(BossSkillDuration[boss][loop] <= GetGameTime())		continue;

			SetHudTextParams(-1.0, 0.83, 0.06, 0, 255, 0, 255);
			if(!GetBossSkillName(boss, loop, text, sizeof(text), client))
			{
				switch(loop)
				{
					case SkillName_Rage, SkillName_200Rage:
					{
						Format(text, sizeof(text), "%T", "Rage Duration", client);
					}
					case SkillName_LostLife:
					{
						Format(text, sizeof(text), "%T", "Life Skill Duration", client);
					}
				}
			}

			// FIXME: 라이프 스킬과 분노가 겹치는 경우, 라이프 스킬 이름이 씹힘
			Format(text, sizeof(text), "%s: %.1f", text, BossSkillDuration[boss][loop] - GetGameTime());
			bossHudDisplay=FF2HudDisplay.CreateDisplay("Skill Duration", text);
			PlayerHudQueue[client].AddHud(bossHudDisplay, client);
		}

		Format(text, sizeof(text), "%t (%i / %i)", "Rage Meter", RoundFloat(BossCharge[boss][0]), RoundFloat(BossMaxRageCharge[boss]), RoundFloat(BossCharge[boss][0]*(BossRageDamage[boss]/100.0)), BossRageDamage[boss]);

		bossHudDisplay=FF2HudDisplay.CreateDisplay("Rage Meter", text);
		PlayerHudQueue[client].AddHud(bossHudDisplay, client);

		if(RoundFloat(BossCharge[boss][0]) >= 100.0)
		{
			if(IsFakeClient(client) && !(FF2Flags[client] & FF2FLAG_BOTRAGE))
			{
				CreateTimer(1.0, Timer_BotRage, boss, TIMER_FLAG_NO_MAPCHANGE);
				FF2Flags[client]|=FF2FLAG_BOTRAGE;
			}
			else
			{
				if(BossSkillDuration[boss][SkillName_Rage] > GetGameTime()
					|| BossSkillDuration[boss][SkillName_200Rage] > GetGameTime())
					SetHudTextParams(-1.0, 0.83, 0.06, 0, 255, 0, 255);
				else if((RoundFloat(BossMaxRageCharge[boss]) >= 200
					&& (100 <= RoundFloat(BossCharge[boss][0]) && RoundFloat(BossCharge[boss][0]) < 200)))
					SetHudTextParams(-1.0, 0.83, 0.06, 255, 228, 0, 255);
				else
					SetHudTextParams(-1.0, 0.83, 0.06, 255, 64, 64, 255);

				Format(text, sizeof(text), "%T", "Activate Rage", client);
				bossHudDisplay=FF2HudDisplay.CreateDisplay("Activate Rage", text);
				PlayerHudQueue[client].AddHud(bossHudDisplay, client);

				char sound[PLATFORM_MAX_PATH];
				if(FindSound("full rage", sound, sizeof(sound), boss) && emitRageSound[boss])
				{
					EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, sound, client);
					EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, sound, client);

					emitRageSound[boss]=false;
				}
			}
		}
		else if(BossTeam != TF2_GetClientTeam(client))
		{
			Format(text, sizeof(text), "%t", "Your Damage Dealt", Damage[client]);
			if(Assist[client] > 0)
				Format(text, sizeof(text), "%s + ASSIST: %d", text, Assist[client]);

			bossHudDisplay=FF2HudDisplay.CreateDisplay("Your Damage Dealt", text);
			PlayerHudQueue[client].AddHud(bossHudDisplay, client);
		}

		PlayerHudQueue[client].ShowSyncHudQueueText(client, rageHUD);
		PlayerHudQueue[client].DeleteAllDisplay();

		SetHudTextParams(-1.0, 0.88, 0.06, 255, 255, 255, 255);

		SetClientGlow(client, -0.05);

		KeyValues kv = GetCharacterKV(character[boss]);
		kv.Rewind();
		if(kv.JumpToKey("abilities"))
		{
			char ability[10];
			kv.GotoFirstSubKey();
			do
			{
				char pluginName[64];
				kv.GetSectionName(pluginName, sizeof(pluginName));
				kv.GotoFirstSubKey();
				do
				{
					char abilityName[64];
					kv.GetSectionName(abilityName, sizeof(abilityName));
					int slot=kv.GetNum("slot", 0);
					int buttonmode=kv.GetNum("buttonmode", 0);
					if(slot<1) // We don't care about rage/life-loss abilities here
					{
						continue;
					}

					kv.GetString("life", ability, sizeof(ability), "");
					if(!ability[0]) // Just a regular ability that doesn't care what life the boss is on
					{
						UseAbility(boss, pluginName, abilityName, slot, buttonmode);
					}
					else // But these do
					{
						char temp[3];
						ArrayList livesArray=CreateArray(sizeof(temp));
						int count=ExplodeStringIntoArrayList(ability, " ", livesArray, sizeof(temp));
						for(int n; n<count; n++)
						{
							livesArray.GetString(n, temp, sizeof(temp));
							if(StringToInt(temp)==BossLives[boss])
							{
								UseAbility(boss, pluginName, abilityName, slot, buttonmode);
								break;
							}
						}
						delete livesArray;
					}
				}
				while(kv.GotoNextKey());
				kv.GoBack();
			}
			while(kv.GotoNextKey());
		}

		if(RedAlivePlayers==1)
		{
			char message[512], name[64], bossLives[10];  //Do not decl this
			int bossindexs[MAXPLAYERS+1], bosscount=0;

			for(int target=1; target<=MaxClients; target++)  //TODO: Why is this for loop needed when we're already in a boss for loop
			{
				if(IsBoss(target))
				{
					bossindexs[bosscount++]=GetBossIndex(target);
				}
			}

			for(int target=1; target<=MaxClients; target++)
			{
				if(IsValidClient(target) && !IsFakeClient(target) && !(FF2Flags[target] & FF2FLAG_HUDDISABLED))
				{
					SetGlobalTransTarget(target);
					Format(message, sizeof(message), "");

					for(int loop; loop<bosscount; loop++)
					{
						GetBossName(bossindexs[loop], name, sizeof(name), target);

						if(BossLives[bossindexs[loop]]>1)
							Format(bossLives, sizeof(bossLives), "x%i", BossLives[bossindexs[loop]]);
						else
							Format(bossLives, sizeof(bossLives), "");
						Format(message, sizeof(message), "%s\n%t", message, "Boss Current Health", name, BossHealth[bossindexs[loop]]-BossHealthMax[bossindexs[loop]]*(BossLives[bossindexs[loop]]-1), BossHealthMax[bossindexs[loop]], bossLives);
					}
					PrintCenterText(target, message);
				}
			}

			if(lastPlayerGlow)
			{
				SetClientGlow(client, 3600.0);
			}
		}

		// 분노 보정
		if(TF2_GetClientTeam(client) == BossTeam)
		{
			int other=0, fast = ScoutsLeft(other);
			fast -= other;
			AddBossCharge(boss, 0, fast > 0 ? fast*0.1 : 0.0);

			// stock
			AddBossCharge(boss, 0, 0.01);
		}

		HPTime-=0.05;
		if(HPTime<0)
		{
			HPTime=0.0;
		}

		for(int client2; client2<=MaxClients; client2++)
		{
			if(KSpreeTimer[client2]>0)
			{
				KSpreeTimer[client2]-=0.05;
			}
		}
	}

	if(!validBoss)
	{
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public Action Timer_BotRage(Handle timer, int bot)
{
	if(IsValidClient(Boss[bot], false))
	{
		FakeClientCommandEx(Boss[bot], "voicemenu 0 0");
	}
}

public int ScoutsLeft(int& others)
{
	int scouts=0;
	float velocity[3];
	for(int client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client) && IsPlayerAlive(client) && TF2_GetClientTeam(client)!=BossTeam)
		{
			if(TF2_GetPlayerClass(client) == TFClass_Scout)
			{
				scouts++;
				continue;
			}

			GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);
			if(GetVectorLength(velocity) >= 400.0)
				scouts++;
			else
				others++;
		}
	}
	return scouts;
}

public void TF2_OnConditionAdded(int client, TFCond condition)
{
	if(Enabled)
	{
		if(IsBoss(client) && (condition==TFCond_Jarated || condition==TFCond_MarkedForDeath || (condition==TFCond_Dazed && TF2_IsPlayerInCondition(client, view_as<TFCond>(42)))))
		{
			TF2_RemoveCondition(client, condition);

			if(condition == TFCond_MarkedForDeath) // Fan O' War(Yeah), Sandman balls
			{
				int boss = GetBossIndex(client);
				AddBossCharge(boss, 0, -5.0);
			}
		}
		else if(!IsBoss(client))
		{
			switch(condition)
			{
				case TFCond_BlastJumping:
				{
					FF2Flags[client]|=FF2FLAG_BLAST_JUMPING;
				}
				case TFCond_RestrictToMelee:
				{
					TF2_RemoveCondition(client, TFCond_RestrictToMelee);
					// TF2_AddCondition(client, TFCond_SpeedBuffAlly, 12.0);
				}
				case TFCond_Bonked:
				{
					TF2_RemoveCondition(client, TFCond_Bonked);
					TF2_AddCondition(client, TFCond_HalloweenQuickHeal, 2.0);
				}
			}

		}
	}
}

public void TF2_OnConditionRemoved(int client, TFCond condition)
{
	if(Enabled)
	{
		if(TF2_GetPlayerClass(client)==TFClass_Scout && condition==TFCond_CritHype)
		{
			TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.01);
		}
		else if(!IsBoss(client) && condition==TFCond_BlastJumping)
		{
			FF2Flags[client]&=~FF2FLAG_BLAST_JUMPING;
		}
	}
}

public Action OnCallForMedic(int client, const char[] command, int args)
{
	if(!Enabled || !IsPlayerAlive(client) || CheckRoundState()!=FF2RoundState_RoundRunning || !IsBoss(client) || args!=2)
	{
		return Plugin_Continue;
	}

	int boss=GetBossIndex(client);

	char arg1[4], arg2[4];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	if(StringToInt(arg1) || StringToInt(arg2))  //We only want "voicemenu 0 0"-thanks friagram for pointing out edge cases
	{
		return Plugin_Continue;
	}

	if(RoundFloat(BossCharge[boss][0])>=100)
	{
		KeyValues kv = GetCharacterKV(character[boss]), abilityKv = new KeyValues("abilities");
		int slot = RoundFloat(BossMaxRageCharge[boss]) >= 200 && RoundFloat(BossCharge[boss][0]) >= 200
			? -2 : 0;

		if(BossSkillDuration[boss][SkillName_Rage] > GetGameTime()
			|| BossSkillDuration[boss][SkillName_200Rage] > GetGameTime())
			return Plugin_Handled;

		kv.Rewind();
		if(kv.JumpToKey("abilities"))
		{
			abilityKv.Import(kv);

			char ability[10];
			abilityKv.GotoFirstSubKey();
			do
			{
				char pluginName[64];
				abilityKv.GetSectionName(pluginName, sizeof(pluginName));
				abilityKv.GotoFirstSubKey();
				do
				{
					char abilityName[64];
					abilityKv.GetSectionName(abilityName, sizeof(abilityName));
					if(abilityKv.GetNum("slot", 0) != slot) // Rage is slot 0 or -2
					{
						continue;
					}

					abilityKv.GetString("life", ability, sizeof(ability), "");
					if(!ability[0]) // Just a regular ability that doesn't care what life the boss is on
					{
						if(!UseAbility(boss, pluginName, abilityName, slot))
						{
							return Plugin_Continue;
						}
					}
					else // But these do
					{
						char temp[3];
						ArrayList livesArray=CreateArray(sizeof(temp));
						int count=ExplodeStringIntoArrayList(ability, " ", livesArray, sizeof(temp));
						for(int n; n<count; n++)
						{
							livesArray.GetString(n, temp, sizeof(temp));
							if(StringToInt(temp)==BossLives[boss])
							{
								if(!UseAbility(boss, pluginName, abilityName, slot))
								{
									return Plugin_Continue;
								}
								break;
							}
						}
						delete livesArray;
					}
				}
				while(abilityKv.GotoNextKey());
				abilityKv.GoBack();
			}
			while(abilityKv.GotoNextKey());
		}

		char sound[PLATFORM_MAX_PATH];
		if(FindSound("ability", sound, sizeof(sound), boss, true))
		{
			EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, sound, client);
			EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, sound, client);
		}
		emitRageSound[boss]=true;

		AddBossCharge(boss, 0, slot == 0 ? -100.0 : -200.0);

		int type = slot == 0 ? SkillName_Rage : SkillName_200Rage;
		float duration = GetBossSkillDuration(boss, type);
		BossSkillDuration[boss][type] = GetGameTime() + duration;

		delete abilityKv;
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action OnSuicide(int client, const char[] command, int args)
{
	bool canBossSuicide=cvarBossSuicide.BoolValue;
	if(Enabled && IsBoss(client) && (canBossSuicide ? CheckRoundState()!=FF2RoundState_Setup : true) && CheckRoundState()!=FF2RoundState_RoundEnd)
	{
		CPrintToChat(client, "{olive}[FF2]{default} %t", canBossSuicide ? "Boss Suicide Pre-round" : "Boss Suicide Denied");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action OnChangeClass(int client, const char[] command, int args)
{
	if(Enabled && IsBoss(client) && IsPlayerAlive(client))
	{
		//Don't allow the boss to switch classes but instead set their *desired* class (for the next round)
		char playerclass[16];
		GetCmdArg(1, playerclass, sizeof(playerclass));
		if(TF2_GetClass(playerclass)!=TFClass_Unknown)  //Ignore cases where the client chooses an invalid class through the console
		{
			SetEntProp(client, Prop_Send, "m_iDesiredPlayerClass", TF2_GetClass(playerclass));
		}
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action OnJoinTeam(int client, const char[] command, int args)
{
	// Only block the commands when FF2 is actively running
	if(!Enabled || RoundCount<arenaRounds || CheckRoundState()==FF2RoundState_Loading)
	{
		return Plugin_Continue;
	}

	// autoteam doesn't come with arguments
	if(StrEqual(command, "autoteam", false))
	{
		TFTeam team=TFTeam_Unassigned, oldTeam=TF2_GetClientTeam(client);
		if(IsBoss(client))
		{
			team=BossTeam;
		}
		else
		{
			team=OtherTeam;
		}

		if(team!=oldTeam)
		{
			TF2_ChangeClientTeam(client, team);
		}
		return Plugin_Handled;
	}

	if(!args)
	{
		return Plugin_Continue;
	}

	TFTeam team=TFTeam_Unassigned, oldTeam=TF2_GetClientTeam(client);
	char teamString[10];
	GetCmdArg(1, teamString, sizeof(teamString));

	if(StrEqual(teamString, "red", false))
	{
		team=TFTeam_Red;
	}
	else if(StrEqual(teamString, "blue", false))
	{
		team=TFTeam_Blue;
	}
	else if(StrEqual(teamString, "auto", false))
	{
		team=OtherTeam;
	}
	else if(StrEqual(teamString, "spectate", false) && !IsBoss(client) && FindConVar("mp_allowspectators").BoolValue)
	{
		team=TFTeam_Spectator;
	}

	if(team==BossTeam && !IsBoss(client))
	{
		team=OtherTeam;
	}
	else if(team==OtherTeam && IsBoss(client))
	{
		team=BossTeam;
	}

	if(team>TFTeam_Unassigned && team!=oldTeam)
	{
		TF2_ChangeClientTeam(client, team);
	}

	if(CheckRoundState()!=FF2RoundState_RoundRunning && !IsBoss(client) || !IsPlayerAlive(client))  //No point in showing the VGUI if they can't change teams
	{
		switch(team)
		{
			case TFTeam_Red:
			{
				ShowVGUIPanel(client, "class_red");
			}
			case TFTeam_Blue:
			{
				ShowVGUIPanel(client, "class_blue");
			}
		}
	}
	return Plugin_Handled;
}

public Action OnPlayerDeath(Event event, const char[] eventName, bool dontBroadcast)
{
	if(!Enabled || CheckRoundState()!=FF2RoundState_RoundRunning)
	{
		return Plugin_Continue;
	}

	int client=GetClientOfUserId(event.GetInt("userid")), attacker=GetClientOfUserId(event.GetInt("attacker"));
	char sound[PLATFORM_MAX_PATH];
	CreateTimer(0.1, CheckAlivePlayers, _, TIMER_FLAG_NO_MAPCHANGE);
	DoOverlay(client, "");
	if(!IsBoss(client))
	{
		if(!(event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER))
		{
			CreateTimer(1.0, Timer_Damage, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		}

		if(IsBoss(attacker))
		{
			int boss=GetBossIndex(attacker);
			if(firstBlood)  //TF_DEATHFLAG_FIRSTBLOOD is broken
			{
				if(FindSound("first blood", sound, sizeof(sound), boss))
				{
					EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, sound);
					EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, sound);
				}
				firstBlood=false;
			}

			if(RedAlivePlayers!=1)  //Don't conflict with end-of-round sounds
			{
				if(GetRandomInt(0, 1) && FindSound("kill", sound, sizeof(sound), boss))
				{
					EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, sound);
					EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, sound);
				}
				else if(!GetRandomInt(0, 2))  //1/3 chance for "sound_kill_<class>"
				{
					char classnames[][]={"", "scout", "sniper", "soldier", "demoman", "medic", "heavy", "pyro", "spy", "engineer"};
					char playerclass[32];
					Format(playerclass, sizeof(playerclass), "kill %s", classnames[TF2_GetPlayerClass(client)]);
					if(FindSound(playerclass, sound, sizeof(sound), boss))
					{
						EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, sound);
						EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, sound);
					}
				}
			}

			if(GetGameTime()<=KSpreeTimer[boss])
			{
				KSpreeCount[boss]++;
			}
			else
			{
				KSpreeCount[boss]=1;
			}

			if(KSpreeCount[boss]==3)
			{
				if(FindSound("kspree", sound, sizeof(sound), boss))
				{
					EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, sound);
					EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, sound);
				}
				KSpreeCount[boss]=0;
			}
			else
			{
				KSpreeTimer[boss]=GetGameTime()+5.0;
			}
		}
	}
	else
	{
		int boss=GetBossIndex(client);
		if(boss==-1 || (event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER))
		{
			return Plugin_Continue;
		}

		if(FindSound("lose", sound, sizeof(sound), boss))
		{
			EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, sound);
			EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, sound);
		}

		BossHealth[boss]=0;
		UpdateHealthBar();

		Stabbed[boss]=0.0;
		Marketed[boss]=0.0;
	}

	if(TF2_GetPlayerClass(client)==TFClass_Engineer && !(event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER))
	{
		char name[PLATFORM_MAX_PATH];
		FakeClientCommand(client, "destroy 2");
		for(int entity=MaxClients+1; entity<MAXENTITIES; entity++)
		{
			if(IsValidEntity(entity))
			{
				GetEntityClassname(entity, name, sizeof(name));
				if(!StrContains(name, "obj_sentrygun") && (GetEntPropEnt(entity, Prop_Send, "m_hBuilder")==client))
				{
					SetVariantInt(GetEntPropEnt(entity, Prop_Send, "m_iMaxHealth")+1);
					AcceptEntityInput(entity, "RemoveHealth");

					Event eventRemoveObject=CreateEvent("object_removed", true);
					eventRemoveObject.SetInt("userid", GetClientUserId(client));
					eventRemoveObject.SetInt("index", entity);
					eventRemoveObject.Fire();
					AcceptEntityInput(entity, "kill");
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action Timer_Damage(Handle timer, int userid)
{
	int client=GetClientOfUserId(userid);
	if(IsValidClient(client, false))
	{
		CPrintToChat(client, "{olive}[FF2] %t.{default}", "Total Damage Dealt", Damage[client]);
	}
	return Plugin_Continue;
}

public Action OnObjectDeflected(Event event, const char[] name, bool dontBroadcast)
{
	if(!Enabled || event.GetInt("weaponid"))  //0 means that the client was airblasted, which is what we want
	{
		return Plugin_Continue;
	}

	int boss=GetBossIndex(GetClientOfUserId(event.GetInt("ownerid")));
	if(boss != -1)
	{
		AddBossCharge(boss, 0, 7.0); //TODO: Allow this to be customizable

		if(executed)
			timeleft += 5.0;
	}
	return Plugin_Continue;
}

public Action OnJarate(UserMsg msg_id, Handle bf, const int[] players, int playersNum, bool reliable, bool init)
{
	int client=BfReadByte(bf);
	int victim=BfReadByte(bf);
	int boss=GetBossIndex(victim);
	if(boss!=-1)
	{
		int jarate=GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
		if(jarate!=-1)
		{
			int index=GetEntProp(jarate, Prop_Send, "m_iItemDefinitionIndex");
			if((index==58 || index==1083 || index==1105) && GetEntProp(jarate, Prop_Send, "m_iEntityLevel")!=-122)  //-122 is the Jar of Ants which isn't really Jarate
				AddBossCharge(boss, 0, -8.0); //TODO: Allow this to be customizable
		}
	}
	return Plugin_Continue;
}

public Action OnDeployBackup(Event event, const char[] name, bool dontBroadcast)
{
	if(Enabled && event.GetInt("buff_type")==2)
	{
		FF2Flags[GetClientOfUserId(event.GetInt("buff_owner"))]|=FF2FLAG_ISBUFFED;
	}
	return Plugin_Continue;
}

public Action OnPlayerHealed(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("patient"));
	int healer = GetClientOfUserId(event.GetInt("healer"));
	int healed = event.GetInt("amount");
	int boss = GetBossIndex(client);

	if(CheckRoundState() != FF2RoundState_RoundRunning)
		return Plugin_Continue;

	// TODO: 자가치유 가능 여부 설정
	if(TF2_GetClientTeam(client) != BossTeam && IsBoss(client))
	{
		BossHealth[boss] += RoundFloat(healed * 0.1);

		int maxHealth = BossHealthMax[boss] * BossLivesMax[boss];
		if(BossHealth[boss] > maxHealth)
		{
			BossHealth[boss] = maxHealth;
		}
		UpdateHealthBar();
	}
	else if(client != healer)
	{
		Assist[healer] += healed/2;
	}

	return Plugin_Continue;
}

public Action CheckAlivePlayers(Handle timer)
{
	if(CheckRoundState()==FF2RoundState_RoundEnd)
	{
		return Plugin_Continue;
	}

	static int lastAlive = 0;
	RedAlivePlayers=0;
	BlueAlivePlayers=0;
	for(int client=1; client<=MaxClients; client++)
	{
		if(IsClientInGame(client) && IsPlayerAlive(client))
		{
			if(TF2_GetClientTeam(client)==OtherTeam)
			{
				RedAlivePlayers++;
			}
			else if(TF2_GetClientTeam(client)==BossTeam)
			{
				BlueAlivePlayers++;
			}
		}
	}

	if(timer != INVALID_HANDLE)
	{
		Call_StartForward(OnAlivePlayersChanged);  //Let subplugins know that the number of alive players just changed
		Call_PushCell(RedAlivePlayers);
		Call_PushCell(BlueAlivePlayers);
		Call_Finish();

		if(!RedAlivePlayers)
		{
			ForceTeamWin(BossTeam);
		}
		else if((RedAlivePlayers==1 && lastAlive!=1) && BlueAlivePlayers && Boss[0])
		{
			char sound[PLATFORM_MAX_PATH];
			if(FindSound("lastman", sound, sizeof(sound)))
			{
				EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, sound);
				EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, sound);
			}
		}
	}

	if(!PointType && RedAlivePlayers<=AliveToEnable && !executed && timeleft <= 180.0)
	{
		PrintHintTextToAll("%t", "Point Unlocked", AliveToEnable);
		if(RedAlivePlayers==AliveToEnable)
		{
			char sound[64];
			if(GetRandomInt(0, 1))
			{
				Format(sound, sizeof(sound), "vo/announcer_am_capenabled0%i.mp3", GetRandomInt(1, 4));
			}
			else
			{
				Format(sound, sizeof(sound), "vo/announcer_am_capincite0%i.mp3", GetRandomInt(0, 1) ? 1 : 3);
			}
			EmitSoundToAll(sound);
		}
		SetControlPoint(true);
		// SetArenaCapTime(20);
		executed=true;
	}
	else if(executed && timeleft > 180.0)
	{
		SetControlPoint(false);
		executed=false;
	}

	lastAlive = RedAlivePlayers;
	return Plugin_Continue;
}

public Action Timer_DrawGame(Handle timer)
{
	if(CheckRoundState()!=FF2RoundState_RoundRunning || timeleft <= -1.0)
	{
		return Plugin_Stop;
	}

	FF2HudDisplay hudDisplay;

	CheckAlivePlayers(INVALID_HANDLE);
	timeleft-=0.1; // TODO: Forward

	char timeDisplay[6], waveDisplay[20];
	int min=RoundToFloor(timeleft / 60.0), sec=RoundToCeil(timeleft)-(min*60)-1;
	int timeInteger = RoundFloat(timeleft);
	float fraction = FloatFraction(timeleft);

	static int lastNotice = -1;

	if(timeType == FF2Timer_WaveTimer)
		Format(waveDisplay, sizeof(waveDisplay), "WAVE: %d / %d", currentWave, maxWave);

	if(timeleft<60.0)
	{
		Format(timeDisplay, sizeof(timeDisplay), "%.1f", timeleft);
	}
	else
	{
		if(min < 10)
			Format(timeDisplay, sizeof(timeDisplay), "0%i", min);
		else
			IntToString(min, timeDisplay, sizeof(timeDisplay));

		if(sec < 10)
			Format(timeDisplay, sizeof(timeDisplay), "%s:0%i", timeDisplay, sec);
		else
			Format(timeDisplay, sizeof(timeDisplay), "%s:%i", timeDisplay, sec);
	}

	SetHudTextParams(-1.0, 0.17, 0.11, 255, 255, 255, 255);
	for(int client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client) && !IsFakeClient(client))
		{
			PlayerHudQueue[client].SetName("Timer");
			SetGlobalTransTarget(client);

			if(timeType == FF2Timer_WaveTimer)
			{
				hudDisplay=FF2HudDisplay.CreateDisplay("Wave", waveDisplay);
				PlayerHudQueue[client].AddHud(hudDisplay, client);
			}

			hudDisplay=FF2HudDisplay.CreateDisplay("Game Timer", timeDisplay);
			PlayerHudQueue[client].AddHud(hudDisplay, client);

			PlayerHudQueue[client].ShowSyncHudQueueText(client, timeleftHUD);
			PlayerHudQueue[client].DeleteAllDisplay();
		}
	}

	if(lastNotice != timeInteger && fraction < 0.1)
	{
		lastNotice = timeInteger;

		switch(timeInteger)
		{
			case 300:
			{
				EmitSoundToAll("vo/announcer_ends_5min.mp3");
			}
			case 120:
			{
				EmitSoundToAll("vo/announcer_ends_2min.mp3");
			}
			case 60:
			{
				EmitSoundToAll("vo/announcer_ends_60sec.mp3");
			}
			case 30:
			{
				EmitSoundToAll("vo/announcer_ends_30sec.mp3");
			}
			case 10:
			{
				EmitSoundToAll("vo/announcer_ends_10sec.mp3");
			}
			case 1, 2, 3, 4, 5:
			{
				char sound[PLATFORM_MAX_PATH];
				Format(sound, sizeof(sound), "vo/announcer_ends_%isec.mp3", timeInteger);
				EmitSoundToAll(sound);
			}
			case 0:
			{
				if(timeType == FF2Timer_WaveTimer)
				{
					if(currentWave == maxWave)
					{
						ForceTeamWin(TFTeam_Unassigned);
						return Plugin_Stop;
					}

					currentWave++;
					timeleft=maxTime;

					Call_StartForward(OnWaveStarted);
					Call_PushCell(currentWave);
					Call_Finish();

					return Plugin_Continue;
				}
				else
					ForceTeamWin(TFTeam_Unassigned);

				return Plugin_Stop;
			}
		}
	}

	return Plugin_Continue;
}

public Action OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)  //TODO: Can this be removed?
{
	if(Enabled && CheckRoundState()==FF2RoundState_RoundRunning && event.GetBool("minicrit") && event.GetBool("allseecrit"))
	{
		Debug("allseecrit removed");
		event.SetBool("allseecrit", false);
	}
	return Plugin_Continue;
}

public Action OnTakeDamageAlive(int client, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(!Enabled || !IsValidEntity(attacker))
	{
		return Plugin_Continue;
	}

	bool bChanged=false;

	if(CheckRoundState()==FF2RoundState_Setup || (IsBoss(client)
	&& (TF2_IsPlayerInCondition(client, TFCond_Ubercharged) || TF2_IsPlayerInCondition(client, TFCond_UberchargedHidden))))
	{
		damage=0.0;
		return Plugin_Changed;
	}

	if(attacker<=0 || client==attacker)
	{
		if(IsBoss(client))
		{
			int boss = GetBossIndex(client);
			KeyValues bossKv = GetBossKV(boss);
			bossKv.Rewind();

			// Debug("%d, %d, %d, %.1f", client, attacker, inflictor, damage);
			if(bossKv.GetNum("enable selfdamage", 0) > 0 && attacker > 0)
			{
				// Debug("selfdamage");
				return Plugin_Continue;
			}

			damage=0.0;
			return Plugin_Changed;
		}
	}

	float position[3];
	GetEntPropVector(attacker, Prop_Send, "m_vecOrigin", position);
	if(IsBoss(attacker))
	{
		if(damagecustom == TF_CUSTOM_BACKSTAB && IsBoss(client))
		{
			int boss=GetBossIndex(client);

			// 보스가 메인 보스를 백스탭 할 경우, 약화된 데미지 공식 사용
			// TODO: 동등한 보스의 위치(메인, 인간팀)의 경우를 고려해야 함
			if(GetBossIndex(attacker) != 0)
				damage=(BossHealthMax[boss]*(LastBossIndex()+1)*BossLivesMax[boss]*(0.05-Stabbed[boss]/180));
			else
				damage=BossHealth[boss]*1.1; // 즉사 처리

			damagetype|=DMG_CRIT;
			damagecustom=0;

			if(SpecialAttackToBoss(attacker, boss, weapon, "boss_backstab", damage) == Plugin_Handled)
				return Plugin_Handled;

			bChanged=true;
		}
		if(IsValidClient(client) && !IsBoss(client) && !TF2_IsPlayerInCondition(client, TFCond_Bonked))
		{
			if(TF2_IsPlayerInCondition(client, TFCond_DefenseBuffed))
			{
				ScaleVector(damageForce, 9.0);
				damage*=0.3;
				return Plugin_Changed;
			}

			if(TF2_IsPlayerInCondition(client, TFCond_DefenseBuffMmmph))
			{
				damage*=9;
				TF2_AddCondition(client, TFCond_Bonked, 0.1);  //In other words, no damage is actually taken
				return Plugin_Changed;
			}

			if(TF2_IsPlayerInCondition(client, TFCond_CritMmmph))
			{
				damage*=0.25;
				return Plugin_Changed;
			}

			if(shield[client] && damage)
			{
				if(GetEntProp(shield[client], Prop_Send, "m_iItemDefinitionIndex")==57)
				{
					if(GetEntPropFloat(client, Prop_Send, "m_flItemChargeMeter", TFWeaponSlot_Secondary)>=100.0)
					{
						PlayShieldBreakSound(client, attacker, position);
						SetEntPropFloat(client, Prop_Send, "m_flItemChargeMeter", 0.0, TFWeaponSlot_Secondary);
						return Plugin_Handled;
					}
					return Plugin_Continue;
				}
				else
				{
					// RemoveShield(client, attacker, position);
					PlayShieldBreakSound(client, attacker, position);
					float charge = GetEntPropFloat(client, Prop_Send, "m_flChargeMeter") - damage;
					SetEntPropFloat(client, Prop_Send, "m_flChargeMeter",
						charge > 0.0 ? charge : 0.0);
					return Plugin_Continue;
				}
			}

			if(TF2_GetPlayerClass(client)==TFClass_Soldier)
			{
				bool valid = IsValidEntity((weapon=GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary)));

				if(valid && GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex")==226  //Battalion's Backup
				&& !(FF2Flags[client] & FF2FLAG_ISBUFFED))
					SetEntPropFloat(client, Prop_Send, "m_flRageMeter", 100.0);
			}
		}
	}
	else
	{
		int boss=GetBossIndex(client);
		float victimPosition[3];
		GetEntPropVector(attacker, Prop_Send, "m_vecOrigin", position);
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", victimPosition);
		if(boss!=-1)
		{
			if(attacker<=MaxClients)
			{
				int index;
				char classname[64];
				if(IsValidEntity(weapon) && weapon>MaxClients && attacker<=MaxClients)
				{
					GetEntityClassname(weapon, classname, sizeof(classname));
					if(!StrContains(classname, "eyeball_boss"))  //Dang spell Monoculuses
					{
						index=-1;
						Format(classname, sizeof(classname), "");
					}
					else
					{
						index=GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
					}
				}
				else
				{
					index=-1;
					Format(classname, sizeof(classname), "");
				}

				/*if(kvWeaponMods.JumpToKey("onhit"))
				{
					//TODO
				}

				if(kvWeaponMods.JumpToKey("ontakedamage"))
				{
					//TODO
				}*/

				//Sniper rifles aren't handled by the switch/case because of the amount of reskins there are
				if(StrContains(classname, "tf_weapon_sniperrifle")!=-1)
				{
					if(CheckRoundState()!=FF2RoundState_RoundEnd)
					{
						float charge=(IsValidEntity(weapon) && weapon>MaxClients ? GetEntPropFloat(weapon, Prop_Send, "m_flChargedDamage") : 0.0);
						if(index==752)  //Hitman's Heatmaker
						{
							float focus=10+(charge/10);
							if(TF2_IsPlayerInCondition(attacker, TFCond_FocusBuff))
							{
								focus/=3;
							}
							float rage=GetEntPropFloat(attacker, Prop_Send, "m_flRageMeter");
							SetEntPropFloat(attacker, Prop_Send, "m_flRageMeter", (rage+focus>100) ? 100.0 : rage+focus);
						}
						else if(index!=230 && index!=402 && index!=526 && index!=30665)  //Sydney Sleeper, Bazaar Bargain, Machina, Shooting Star
						{
							float time=(GlowTimer[boss]>10 ? 1.0 : 2.0);
							time+=(GlowTimer[boss]>10 ? (GlowTimer[boss]>20 ? 1.0 : 2.0) : 4.0)*(charge/100.0);
							SetClientGlow(Boss[boss], time);
							if(GlowTimer[boss]>30.0)
							{
								GlowTimer[boss]=30.0;
							}
						}

						if(!(damagetype & DMG_CRIT) && damagecustom != TF_CUSTOM_HEADSHOT
							|| TF2_IsPlayerInCondition(attacker, TFCond_Buffed))
						{
							float distance = GetVectorDistance(position, victimPosition);
							if(distance>1800.0)
								damagetype|=DMG_PREVENT_PHYSICS_FORCE;

							damage*=TF2_IsPlayerInCondition(attacker, TFCond_Buffed) ? 1.0 : 1.6;
						}


						return Plugin_Changed;
					}
				}

				if(TF2_GetPlayerClass(attacker) == TFClass_Heavy && StrContains(classname, "tf_weapon_shotgun")!=-1)
				{
					int maxHealth = GetEntProp(attacker, Prop_Data, "m_iMaxHealth");
					TF2Util_TakeHealth(attacker, 50.0, TAKEHEALTH_IGNORE_MAXHEALTH);

					int currentHealth = GetEntProp(attacker, Prop_Data, "m_iHealth");
					if(currentHealth > maxHealth * 2)
					{
						SetEntProp(attacker, Prop_Data, "m_iHealth", maxHealth * 2);
					}
				}

				if(damagecustom==TF_WEAPON_SENTRY_BULLET)
				{
/*
					int sentry=-1, targettingCount=0, closestSentry, currentWeapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
					float distance, closestdistanse=800.0, sentryPos[3];

					if(IsValidEntity(currentWeapon) && GetEntProp(currentWeapon, Prop_Send, "m_iItemDefinitionIndex") == 141)
						return Plugin_Continue;

					while((sentry = FindEntityByClassname2(sentry, "obj_sentrygun")) != -1)
					{
						if(GetEntPropEnt(sentry, Prop_Send, "m_hEnemy") == client) {
							targettingCount++;
							GetEntPropVector(sentry, Prop_Send, "m_vecOrigin", sentryPos);
							if((distance = GetVectorDistance(sentryPos, victimPosition)) < closestdistanse) {
								closestSentry = sentry;
								closestdistanse = distance;
							}
						}
					}

					if(targettingCount > 1 && closestSentry != inflictor)
						damagetype |= DMG_PREVENT_PHYSICS_FORCE;
*/
					damagetype |= DMG_PREVENT_PHYSICS_FORCE;
					return Plugin_Changed;
				}

				if(damagecustom==TF_CUSTOM_BURNING_ARROW)
				{
					bChanged = true;
					damage *= 2.0;
				}

				switch(index)
				{
					case 61, 1006:  //Ambassador, Festive Ambassador
					{
						if(damagecustom==TF_CUSTOM_HEADSHOT)
						{
							damage=255.0 > damage ? damage : 255.0;
							return Plugin_Changed;
						}
					}
					case 132, 266, 482, 1082:  //Eyelander, HHHH, Nessie's Nine Iron, Festive Eyelander, Vita-Saw(?)
					{
						IncrementHeadCount(attacker);
					}
					case 142:
					{
						if(damagecustom==TF_CUSTOM_COMBO_PUNCH)
						{
							damage*=5.0;
							ScaleVector(damageForce, 5.0);

							EmitSoundToAll("potry_v2/se/homerun_bat.wav", client);
							EmitSoundToAll("potry_v2/se/homerun_bat.wav", client);
							EmitSoundToAll("potry_v2/se/homerun_bat.wav", client);

							SpecialAttackToBoss(attacker, boss, weapon, "combo_punch", damage);

							return Plugin_Changed;
						}
					}
					case 214:  //Powerjack
					{
						int health=GetClientHealth(attacker);
						int newhealth=health+50;
						if(newhealth<=GetEntProp(attacker, Prop_Data, "m_iMaxHealth"))  //No overheal allowed
						{
							SetEntityHealth(attacker, newhealth);
						}

						if(TF2_IsPlayerInCondition(attacker, TFCond_OnFire))
						{
							TF2_RemoveCondition(attacker, TFCond_OnFire);
						}
					}
					case 310:  //Warrior's Spirit
					{
						int health=GetClientHealth(attacker);
						int newhealth=health+50;
						if(newhealth<=GetEntProp(attacker, Prop_Data, "m_iMaxHealth"))  //No overheal allowed
						{
							SetEntityHealth(attacker, newhealth);
						}

						if(TF2_IsPlayerInCondition(attacker, TFCond_OnFire))
						{
							TF2_RemoveCondition(attacker, TFCond_OnFire);
						}
					}
					case 317:  //Candycane
					{
						SpawnSmallHealthPackAt(client, TF2_GetClientTeam(attacker));
					}
					case 327:  //Claidheamh Mòr
					{
						int health=GetClientHealth(attacker);
						int newhealth=health+25;
						if(newhealth<=GetEntProp(attacker, Prop_Data, "m_iMaxHealth"))  //No overheal allowed
						{
							SetEntityHealth(attacker, newhealth);
						}

						if(TF2_IsPlayerInCondition(attacker, TFCond_OnFire))
						{
							TF2_RemoveCondition(attacker, TFCond_OnFire);
						}

						float charge=GetEntPropFloat(attacker, Prop_Send, "m_flChargeMeter");
						if(charge+25.0>=100.0)
						{
							SetEntPropFloat(attacker, Prop_Send, "m_flChargeMeter", 100.0);
						}
						else
						{
							SetEntPropFloat(attacker, Prop_Send, "m_flChargeMeter", charge+25.0);
						}
					}
					case 349:
					{
						if(TF2_IsPlayerInCondition(client, TFCond_OnFire))
						{
							damage*=2.0;
							return Plugin_Changed;
						}
						else
						{
							TF2_IgnitePlayer(client, attacker);
						}
					}

					case 355:  //Fan O' War
					{
						AddBossCharge(boss, 0, -5.0);
					}
					case 357:  //Half-Zatoichi
					{
						SetEntProp(weapon, Prop_Send, "m_bIsBloody", 1);
						if(GetEntProp(attacker, Prop_Send, "m_iKillCountSinceLastDeploy")<1)
						{
							SetEntProp(attacker, Prop_Send, "m_iKillCountSinceLastDeploy", 1);
						}

						int health=GetClientHealth(attacker);
						int max=GetEntProp(attacker, Prop_Data, "m_iMaxHealth");
						int newhealth=health+50;
						if(health<max+100)
						{
							if(newhealth>max+100)
							{
								newhealth=max+100;
							}
							SetEntityHealth(attacker, newhealth);
						}

						if(TF2_IsPlayerInCondition(attacker, TFCond_OnFire))
						{
							TF2_RemoveCondition(attacker, TFCond_OnFire);
						}
					}
					case 416:  //Market Gardener (courtesy of Chdata)
					{
						if(FF2Flags[attacker] & FF2FLAG_BLAST_JUMPING)
						{
							damage=(Pow(float(BossHealthMax[boss]), 0.34074)+512.0-(Marketed[client]/128.0*float(BossHealthMax[boss])));
							if(damage < 300.0)
								damage = 300.0; // x3

							damagetype|=DMG_CRIT;

							if(SpecialAttackToBoss(attacker, boss, weapon, "market_garden", damage) == Plugin_Handled)
								return Plugin_Handled;

							if(Marketed[client]<5)
							{
								Marketed[client]++;
							}

							PrintHintText(attacker, "%t", "Market Gardener");  //You just market-gardened the boss!
							PrintHintText(client, "%t", "Market Gardened");  //You just got market-gardened!

							EmitSoundToAll("potry_v2/se/homerun_bat.wav", client);
							EmitSoundToAll("potry_v2/se/homerun_bat.wav", client);
							EmitSoundToAll("potry_v2/se/homerun_bat.wav", client);
							// EmitSoundToClient(client, "player/doubledonk.wav", _, _, _, _, 0.6, _, _, position, _, false);
							return Plugin_Changed;
						}
					}
					case 525, 595:  //Diamondback, Manmelter
					{
						if(GetEntProp(attacker, Prop_Send, "m_iRevengeCrits"))  //If a revenge crit was used, give a damage bonus
						{
							damage=255.0;
							return Plugin_Changed;
						}
					}
					case 528:  //Short Circuit
					{
						if(circuitStun)
						{
							TF2_StunPlayer(client, circuitStun, 0.0, TF_STUNFLAGS_SMALLBONK|TF_STUNFLAG_NOSOUNDOREFFECT, attacker);
							EmitSoundToAll("weapons/barret_arm_zap.wav", client);
							EmitSoundToClient(client, "weapons/barret_arm_zap.wav");
						}
					}
					case 593:  //Third Degree
					{
						int healers[MAXPLAYERS];
						int healerCount;
						for(int healer; healer<=MaxClients; healer++)
						{
							if(IsValidClient(healer) && IsPlayerAlive(healer) && (GetHealingTarget(healer, true)==attacker))
							{
								healers[healerCount]=healer;
								healerCount++;
							}
						}

						for(int healer; healer<healerCount; healer++)
						{
							if(IsValidClient(healers[healer]) && IsPlayerAlive(healers[healer]))
							{
								int medigun=GetPlayerWeaponSlot(healers[healer], TFWeaponSlot_Secondary);
								if(IsValidEntity(medigun))
								{
									char medigunClassname[64];
									GetEntityClassname(medigun, medigunClassname, sizeof(medigunClassname));
									if(StrEqual(medigunClassname, "tf_weapon_medigun", false))
									{
										float uber=GetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel")+(0.1/healerCount);
										if(uber>1.0)
										{
											uber=1.0;
										}
										SetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel", uber);
									}
								}
							}
						}
					}
					case 594:  //Phlogistinator
					{
						if(!TF2_IsPlayerInCondition(attacker, TFCond_CritMmmph))
						{
							damage/=2.0;
							return Plugin_Changed;
						}
					}
/*
					case 1099:  //Tide Turner
					{
						SetEntPropFloat(attacker, Prop_Send, "m_flChargeMeter", 100.0);
					}
*/
					case 1104:
					{
						static float airStrikeDamage;
						airStrikeDamage+=damage;
						if(airStrikeDamage>=200.0)
						{
							SetEntProp(attacker, Prop_Send, "m_iDecapitations", GetEntProp(attacker, Prop_Send, "m_iDecapitations")+1);
							airStrikeDamage-=200.0;
						}
					}
				}

				if(damagecustom==TF_CUSTOM_BACKSTAB)
				{
					// damage=BossHealthMax[boss]*(LastBossIndex()+1)*BossLivesMax[boss]*(0.12-Stabbed[boss]/80);
					damage = BossHealth[boss] * 0.06;
					if(damage < 900.0)
						damage = 900.0; // x3
					damagetype|=DMG_CRIT;
					damagecustom=0;

					if(SpecialAttackToBoss(attacker, boss, weapon, "backstab", damage) == Plugin_Handled)
						return Plugin_Handled;

					EmitSoundToClient(client, "player/spy_shield_break.wav", _, _, _, _, 0.7, _, _, position, _, false);
					EmitSoundToClient(attacker, "player/spy_shield_break.wav", _, _, _, _, 0.7, _, _, position, _, false);
					EmitSoundToClient(client, "player/crit_received3.wav", _, _, _, _, 0.7, _, _, _, _, false);
					EmitSoundToClient(attacker, "player/crit_received3.wav", _, _, _, _, 0.7, _, _, _, _, false);
					EmitSoundToAll("potry_v2/se/homerun_bat.wav", client);
					EmitSoundToAll("potry_v2/se/homerun_bat.wav", client);
					EmitSoundToAll("potry_v2/se/homerun_bat.wav", client);
					SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime()+2.0);
					SetEntPropFloat(attacker, Prop_Send, "m_flNextAttack", GetGameTime()+2.0);
					SetEntPropFloat(attacker, Prop_Send, "m_flStealthNextChangeTime", GetGameTime()+2.0);

					int viewmodel=GetEntPropEnt(attacker, Prop_Send, "m_hViewModel");
					if(viewmodel>MaxClients && IsValidEntity(viewmodel) && TF2_GetPlayerClass(attacker)==TFClass_Spy)
					{
						int melee=GetIndexOfWeaponSlot(attacker, TFWeaponSlot_Melee);
						int animation=41;
						switch(melee)
						{
							case 225, 356, 423, 461, 574, 649, 1071:  //Your Eternal Reward, Conniver's Kunai, Saxxy, Wanga Prick, Big Earner, Spy-cicle, Golden Frying Pan
							{
								animation=15;
							}
							case 638:  //Sharp Dresser
							{
								animation=31;
							}
						}
						SetEntProp(viewmodel, Prop_Send, "m_nSequence", animation);
					}

					if(!(FF2Flags[attacker] & FF2FLAG_HUDDISABLED))
					{
						PrintHintText(attacker, "%t", "Backstab");
					}

					if(!(FF2Flags[client] & FF2FLAG_HUDDISABLED))
					{
						PrintHintText(client, "%t", "Backstabbed");
					}

					if(index==225 || index==574)  //Your Eternal Reward, Wanga Prick
					{
						CreateTimer(0.3, Timer_DisguiseBackstab, GetClientUserId(attacker), TIMER_FLAG_NO_MAPCHANGE);
					}
					else if(index==356)  //Conniver's Kunai
					{
						int health=GetClientHealth(attacker)+200;
						if(health>500)
						{
							health=500;
						}
						SetEntityHealth(attacker, health);
					}
					else if(index==461)  //Big Earner
					{
						SetEntPropFloat(attacker, Prop_Send, "m_flCloakMeter", 100.0);  //Full cloak
						TF2_AddCondition(attacker, TFCond_SpeedBuffAlly, 3.0);  //Speed boost
					}

					if(GetIndexOfWeaponSlot(attacker, TFWeaponSlot_Primary)==525)  //Diamondback
					{
						SetEntProp(attacker, Prop_Send, "m_iRevengeCrits", GetEntProp(attacker, Prop_Send, "m_iRevengeCrits")+2);
					}

					char sound[PLATFORM_MAX_PATH];
					if(FindSound("stabbed", sound, sizeof(sound), boss))
					{
						EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, sound);
						EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, sound);
					}

					if(Stabbed[boss]<3)
					{
						Stabbed[boss]++;
					}
					return Plugin_Changed;
				}
				else if(damagecustom==TF_CUSTOM_TELEFRAG)
				{
					damagecustom=0;
					if(!IsPlayerAlive(attacker))
					{
						damage=1.0;
						return Plugin_Changed;
					}
					damage=(BossHealth[boss]>9001 ? 9001.0 : float(GetEntProp(Boss[boss], Prop_Send, "m_iHealth"))+90.0);

					int teleowner=FindTeleOwner(attacker);
					if(IsValidClient(teleowner) && teleowner!=attacker)
					{
						Assist[teleowner]+=9001*3/5;
						if(!(FF2Flags[teleowner] & FF2FLAG_HUDDISABLED))
						{
							PrintHintText(teleowner, "TELEFRAG ASSIST!  Nice job setting it up!");
						}
					}

					if(!(FF2Flags[attacker] & FF2FLAG_HUDDISABLED))
					{
						PrintHintText(attacker, "TELEFRAG! You are a pro!");
					}

					if(!(FF2Flags[client] & FF2FLAG_HUDDISABLED))
					{
						PrintHintText(client, "TELEFRAG! Be careful around quantum tunneling devices!");
					}
					return Plugin_Changed;
				}
				else if(damagecustom==TF_CUSTOM_BOOTS_STOMP)
				{
					damage*=5;
					return Plugin_Changed;
				}
			}
			else
			{
				char classname[64];
				if(GetEntityClassname(attacker, classname, sizeof(classname)) && StrEqual(classname, "trigger_hurt", false))
				{
					Action action;
					Call_StartForward(OnTriggerHurt);
					Call_PushCell(boss);
					Call_PushCell(attacker);
					float damage2=damage;
					Call_PushFloatRef(damage2);
					Call_Finish(action);
					if(action!=Plugin_Stop && action!=Plugin_Handled)
					{
						if(action==Plugin_Changed)
						{
							damage=damage2;
						}

						if(damage>1500.0)
						{
							damage=1500.0;
						}

						BossHealth[boss]-=RoundFloat(damage);
						AddBossCharge(boss, 0, damage*100.0/BossRageDamage[boss]);

						if(BossHealth[boss]<=0)  //TODO: Wat
						{
							damage*=5;
						}
						return Plugin_Changed;
					}
					else
					{
						return action;
					}
				}
			}
		}
		else
		{
			int index=(IsValidEntity(weapon) && weapon>MaxClients && attacker<=MaxClients ? GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") : -1);
			if(index==307)  //Ullapool Caber
			{
				if(detonations[attacker]<allowedDetonations)
				{
					detonations[attacker]++;
					PrintHintText(attacker, "%t", "Detonations Left", allowedDetonations-detonations[attacker]);
					if(allowedDetonations-detonations[attacker])  //Don't reset their caber if they have 0 detonations left
					{
						SetEntProp(weapon, Prop_Send, "m_bBroken", 0);
						SetEntProp(weapon, Prop_Send, "m_iDetonated", 0);
					}
				}
			}
		}
	}
	return bChanged ? Plugin_Changed : Plugin_Continue;
}

public void OnTakeDamageAlivePost(int client, int attacker, int inflictor, float damageFloat, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	if(!Enabled) return;

	int damage=RoundFloat(damageFloat);

	if(IsBoss(client))
	{
		int boss=GetBossIndex(client);

		for(int lives=1; lives<BossLives[boss]; lives++)
		{
			if(BossHealth[boss]-damage<=BossHealthMax[boss]*lives)
			{
				SetEntityHealth(client, (BossHealth[boss]-damage)-BossHealthMax[boss]*(lives-1));  //Set the health early to avoid the boss dying from fire, etc.

				Action action;
				int bossLives=BossLives[boss];  //Used for the forward
				Call_StartForward(OnLoseLife);
				Call_PushCell(boss);
				Call_PushCellRef(bossLives);
				Call_PushCell(BossLivesMax[boss]);
				Call_Finish(action);
				if(action==Plugin_Stop || action==Plugin_Handled)  //Don't allow any damage to be taken and also don't let the life-loss go through
				{
					SetEntityHealth(client, BossHealth[boss]);
					return;
				}
				else if(action==Plugin_Changed)
				{
					if(bossLives>BossLivesMax[boss])  //If the new amount of lives is greater than the max, set the max to the new amount
					{
						BossLivesMax[boss]=bossLives;
					}
					BossLives[boss]=lives=bossLives;
				}

				char ability[PLATFORM_MAX_PATH];  //FIXME: Create a new variable for the translation string later on
				KeyValues kv = GetCharacterKV(character[boss]);
				kv.Rewind();
				if(kv.JumpToKey("abilities"))
				{
					kv.GotoFirstSubKey();
					do
					{
						char pluginName[64];
						kv.GetSectionName(pluginName, sizeof(pluginName));
						kv.GotoFirstSubKey();
						do
						{
							char abilityName[64];
							kv.GetSectionName(abilityName, sizeof(abilityName));
							if(kv.GetNum("slot")!=-1) // Only activate for life-loss abilities
							{
								continue;
							}

							kv.GetString("life", ability, 10, "");
							if(!ability[0]) // Just a regular ability that doesn't care what life the boss is on
							{
								UseAbility(boss, pluginName, abilityName, -1);
							}
							else // But these do
							{
								char temp[3];
								ArrayList livesArray=CreateArray(sizeof(temp));
								int count=ExplodeStringIntoArrayList(ability, " ", livesArray, sizeof(temp));
								for(int n; n<count; n++)
								{
									livesArray.GetString(n, temp, sizeof(temp));
									if(StringToInt(temp)==BossLives[boss])
									{
										UseAbility(boss, pluginName, abilityName, -1);
										break;
									}
								}
								delete livesArray;
							}
						}
						while(kv.GotoNextKey());
						kv.GoBack();
					}
					while(kv.GotoNextKey());
				}
				BossLives[boss]=lives;

				char bossName[64];
				strcopy(ability, sizeof(ability), BossLives[boss]==1 ? "Boss with 1 Life Left" : "Boss with Multiple Lives Left");

				for(int target=1; target<=MaxClients; target++)
				{
					if(IsValidClient(target) && !(FF2Flags[target] & FF2FLAG_HUDDISABLED))
					{
						GetBossName(boss, bossName, sizeof(bossName), target);
						PrintCenterText(target, "%t", ability, bossName, BossLives[boss]);
					}
				}

				if(BossLives[boss]==1 && FindSound("last life", ability, sizeof(ability), boss))
				{
					EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, ability);
					EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, ability);
				}
				else if(FindSound("next life", ability, sizeof(ability), boss))
				{
					EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, ability);
					EmitSoundToAllExcept(FF2SOUND_MUTEVOICE, ability);
				}

				float duration = GetBossSkillDuration(boss, SkillName_LostLife);
				BossSkillDuration[boss][SkillName_LostLife] = GetGameTime() + duration;

				break;
			}
		}

		BossHealth[boss]-=damage;

		if(IsValidClient(attacker) && attacker!=client)
		{
			Damage[attacker]+=damage;
			bool rage = true;

			if(IsValidEntity(weapon))
			{
				switch(GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"))
				{
					case 442, 588: // The Righteous Bison, The Pomson 6000
					{
						rage = false;
					}
				}
			}

			if(rage)
				AddBossCharge(boss, 0, damage*100.0/BossRageDamage[boss]);
		}

		int[] healers=new int[MaxClients+1];
		int healerCount;
		for(int target=1; target<=MaxClients; target++)
		{
			if(IsValidClient(target) && IsPlayerAlive(target) && (GetHealingTarget(target, true)==attacker))
			{
				healers[healerCount]=target;
				healerCount++;
			}
		}

		for(int target=1; target<healerCount; target++)
		{
			if(IsValidClient(healers[target]) && IsPlayerAlive(healers[target]))
			{
				if(damage<10 || uberTarget[healers[target]]==attacker)
				{
					Assist[healers[target]]+=damage;
				}
				else
				{
					Assist[healers[target]]+=damage/(healerCount+1);
				}
			}
		}

		UpdateHealthBar();
	}
	else if(TF2_GetClientTeam(client) == BossTeam && TF2_GetClientTeam(attacker) != BossTeam)
	{
		Assist[attacker]+=damage;
	}
}

public Action TF2_OnPlayerTeleport(int client, int teleporter, bool& result)
{
	if(Enabled && IsBoss(client))
	{
		switch(bossTeleportation)
		{
			case -1:  //No bosses are allowed to use teleporters
			{
				result=false;
			}
			case 1:  //All bosses are allowed to use teleporters
			{
				result=true;
			}
		}
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action OnGetMaxHealth(int client, int& maxHealth)
{
	if(Enabled && IsBoss(client))
	{
		int boss=GetBossIndex(client);
		SetEntityHealth(client, BossHealth[boss]-BossHealthMax[boss]*(BossLives[boss]-1));
		maxHealth=BossHealthMax[boss];
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action Timer_DisguiseBackstab(Handle timer, int userid)
{
	int client=GetClientOfUserId(userid);
	if(IsValidClient(client, false))
	{
		RandomlyDisguise(client);
	}
	return Plugin_Continue;
}

stock void AssignTeam(int client, TFTeam team)
{
	if(!GetEntProp(client, Prop_Send, "m_iDesiredPlayerClass"))  //Living spectator check: 0 means that no class is selected
	{
		Debug("%N does not have a desired class!", client);
		if(IsBoss(client))
		{
			SetEntProp(client, Prop_Send, "m_iDesiredPlayerClass", KvGetNum(GetCharacterKV(character[Boss[client]]), "class", 1));  //So we assign one to prevent living spectators
		}
		else
		{
			Debug("%N was not a boss and did not have a desired class!  Please report this to https://github.com/50DKP/FF2-Official");
		}
	}

	SetEntProp(client, Prop_Send, "m_lifeState", 2);
	TF2_ChangeClientTeam(client, team);
	TF2_RespawnPlayer(client);

	if(GetEntProp(client, Prop_Send, "m_iObserverMode") && IsPlayerAlive(client))  //Welp
	{
		Debug("%N is a living spectator!  Please report this to https://github.com/50DKP/FF2-Official", client);
		if(IsBoss(client))
		{
			TF2_SetPlayerClass(client, view_as<TFClassType>(KvGetNum(GetCharacterKV(character[Boss[client]]), "class", 1)));
		}
		else
		{
			Debug("Additional information: %N was not a boss");
			TF2_SetPlayerClass(client, TFClass_Scout);
		}
		TF2_RespawnPlayer(client);
	}
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool& result)
{
	if(Enabled && IsBoss(client) && CheckRoundState()==FF2RoundState_RoundRunning && !TF2_IsPlayerCritBuffed(client) && !BossCrits)
	{
		result=false;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

stock int GetClientWithMostQueuePoints(bool[] omit)
{
	int winner=0;
	for(int client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client) && GetClientQueuePoints(client)>=GetClientQueuePoints(winner) && !omit[client])
		{
			if(SpecForceBoss || TF2_GetClientTeam(client)>TFTeam_Spectator)
			{
				winner=client;
			}
		}
	}

	return winner;
}

stock int RandomlySelectClient(bool[] omit)
{
	int count;
	ArrayList array=new ArrayList();
	for(int client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client) && !omit[client])
		{
			if(SpecForceBoss || TF2_GetClientTeam(client)>TFTeam_Spectator)
			{
				array.Push(client);
				count++;
			}
		}
	}

	int winner=array.Get(GetRandomInt(0, count-1));
	delete array;
	return winner;
}

stock int LastBossIndex()
{
	for(int client=1; client<=MaxClients; client++)
	{
		if(!Boss[client])
		{
			return client-1;
		}
	}
	return 0;
}

stock void Operate(ArrayList sumArray, int& bracket, float value, ArrayList _operator)
{
	float sum=sumArray.Get(bracket);
	switch(_operator.Get(bracket))
	{
		case Operator_Add:
		{
			sumArray.Set(bracket, sum+value);
		}
		case Operator_Subtract:
		{
			sumArray.Set(bracket, sum-value);
		}
		case Operator_Multiply:
		{
			sumArray.Set(bracket, sum*value);
		}
		case Operator_Divide:
		{
			if(!value)
			{
				LogError("[FF2 Bosses] Detected a divide by 0!");
				bracket=0;
				return;
			}
			sumArray.Set(bracket, sum/value);
		}
		case Operator_Exponent:
		{
			sumArray.Set(bracket, Pow(sum, value));
		}
		default:
		{
			sumArray.Set(bracket, value);  //This means we're dealing with a constant
		}
	}
	_operator.Set(bracket, Operator_None);
}

stock void OperateString(ArrayList sumArray, int& bracket, char[] value, int size, ArrayList _operator)
{
	if(!StrEqual(value, ""))  //Make sure 'value' isn't blank
	{
		Operate(sumArray, bracket, StringToFloat(value), _operator);
		strcopy(value, size, "");
	}
}

/*
 * Parses a mathematical formula and returns the result,
 * or `defaultValue` if there is an error while parsing
 *
 * Variables may be present in the formula as long as they
 * are in the format `{variable}`.  Unknown variables will
 * be passed to the `OnParseUnknownVariable` forward
 *
 * Known variables include:
 * - players
 * - lives
 * - health
 * - speed
 *
 * @param boss          Boss index
 * @param key           The key to retrieve the formula from.  If the
 *                      key is nested, the nested sections must be
 *                      delimited by a `>` symbol like so:
 *                      "plugin name > ability name > distance"
 * @param defaultValue  The default value to return in case of error
 * @return The value of the formula, or `defaultValue` in case of error
 */
stock int ParseFormula(int boss, const char[] key, int defaultValue)
{
	char formula[1024], bossName[64];
	KeyValues kv = GetCharacterKV(character[boss]);
	kv.Rewind();
	kv.GetString("name", bossName, sizeof(bossName), "=Failed name=");

	char keyPortions[5][128];
	int portions=ExplodeString(key, ">", keyPortions, sizeof(keyPortions), 128);
	for(int i=1; i<portions; i++)
	{
		kv.JumpToKey(keyPortions[i]);
	}
	kv.GetString(keyPortions[portions-1], formula, sizeof(formula));

	if(!formula[0])
	{
		return defaultValue;
	}

	int size=1;
	int matchingBrackets;
	for(int i; i<=strlen(formula); i++)  //Resize the arrays once so we don't have to worry about it later on
	{
		if(formula[i]=='(')
		{
			if(!matchingBrackets)
			{
				size++;
			}
			else
			{
				matchingBrackets--;
			}
		}
		else if(formula[i]==')')
		{
			matchingBrackets++;
		}
	}

	ArrayList sumArray=CreateArray(_, size), _operator=CreateArray(_, size);
	int bracket;  //Each bracket denotes a separate sum (within parentheses).  At the end, they're all added together to achieve the actual sum
	bool escapeCharacter;
	sumArray.Set(0, 0.0);  //TODO:  See if these can be placed naturally in the loop
	_operator.Set(bracket, Operator_None);

	char currentCharacter[2], value[16], variable[16];  //We don't decl these because we directly append characters to them and there's no point in decl'ing currentCharacter
	for(int i; i<=strlen(formula); i++)
	{
		currentCharacter[0]=formula[i];  //Find out what the next char in the formula is
		switch(currentCharacter[0])
		{
			case ' ', '\t':  //Ignore whitespace
			{
				continue;
			}
			case '(':
			{
				bracket++;  //We've just entered a new parentheses so increment the bracket value
				sumArray.Set(bracket, 0.0);
				_operator.Set(bracket, Operator_None);
			}
			case ')':
			{
				OperateString(sumArray, bracket, value, sizeof(value), _operator);
				if(_operator.Get(bracket)!=Operator_None)  //Something like (5*)
				{
					LogError("[FF2 Bosses] %s's %s formula has an invalid operator at character %i", bossName, key, i+1);
					delete sumArray;
					delete _operator;
					return defaultValue;
				}

				if(--bracket<0)  //Something like (5))
				{
					LogError("[FF2 Bosses] %s's %s formula has an unbalanced parentheses at character %i", bossName, key, i+1);
					delete sumArray;
					delete _operator;
					return defaultValue;
				}

				Operate(sumArray, bracket, GetArrayCell(sumArray, bracket+1), _operator);
			}
			case '\0':  //End of formula
			{
				OperateString(sumArray, bracket, value, sizeof(value), _operator);
			}
			case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '.':
			{
				StrCat(value, sizeof(value), currentCharacter);  //Constant?  Just add it to the current value
			}
			/*case 'n', 'x':  //n and x denote player variables
			{
				Operate(sumArray, bracket, float(playing), _operator);
			}*/
			case '{':
			{
				escapeCharacter=true;
			}
			case '}':
			{
				if(!escapeCharacter)
				{
					LogError("[FF2 Bosses] %s's %s formula has an invalid escape character at character %i", bossName, key, i+1);
					delete sumArray;
					delete _operator;
					return defaultValue;
				}
				escapeCharacter=false;

				if(StrEqual(variable, "players", false))
				{
					Operate(sumArray, bracket, float(playing), _operator);
				}
				else if(StrEqual(variable, "health", false))
				{
					Operate(sumArray, bracket, float(BossHealth[boss]), _operator);
				}
				else if(StrEqual(variable, "lives", false))
				{
					Operate(sumArray, bracket, float(BossLives[boss]), _operator);
				}
				else if(StrEqual(variable, "speed", false))
				{
					Operate(sumArray, bracket, BossSpeed[boss], _operator);
				}
				else
				{
					Action action;
					float variableValue;
					Call_StartForward(OnParseUnknownVariable);
					Call_PushString(variable);
					Call_PushFloatRef(variableValue);
					Call_Finish();

					if(action==Plugin_Changed)
					{
						Operate(sumArray, bracket, variableValue, _operator);
					}
					else
					{
						LogError("[FF2 Bosses] %s's %s formula has an unknown variable '%s'", bossName, key, variable);
						delete sumArray;
						delete _operator;
						return defaultValue;
					}
				}
				Format(variable, sizeof(variable), ""); // Reset the variable holder
			}
			case '+', '-', '*', '/', '^':
			{
				OperateString(sumArray, bracket, value, sizeof(value), _operator);
				switch(currentCharacter[0])
				{
					case '+':
					{
						_operator.Set(bracket, Operator_Add);
					}
					case '-':
					{
						_operator.Set(bracket, Operator_Subtract);
					}
					case '*':
					{
						_operator.Set(bracket, Operator_Multiply);
					}
					case '/':
					{
						_operator.Set(bracket, Operator_Divide);
					}
					case '^':
					{
						_operator.Set(bracket, Operator_Exponent);
					}
				}
			}
			default:
			{
				if(escapeCharacter)  //Absorb all the characters into 'variable' if we hit an escape character
				{
					StrCat(variable, sizeof(variable), currentCharacter);
				}
				else
				{
					LogError("[FF2 Bosses] %s's %s formula has an invalid character at character %i", bossName, key, i+1);
					delete sumArray;
					delete _operator;
					return defaultValue;
				}
			}
		}
	}

	int result=RoundFloat(GetArrayCell(sumArray, 0));
	delete sumArray;
	delete _operator;
	if(result<=0)
	{
		LogError("[FF2 Bosses] %s has an invalid %s formula, using default!", bossName, key);
		return defaultValue;
	}

	if(bMedieval && StrEqual(key, "health"))
	{
		return RoundFloat(result/3.6);  //TODO: Make this configurable
	}
	return result;
}

stock int GetAbilityArgument(int boss, const char[] pluginName, const char[] abilityName, const char[] argument, int defaultValue = 0, int slot = -3)
{
	if(HasAbility(boss, pluginName, abilityName, slot))
	{
		KeyValues kv=GetCharacterKV(character[boss]);
		return kv.GetNum(argument, defaultValue);
	}
	return defaultValue;
}

stock float GetAbilityArgumentFloat(int boss, const char[] pluginName, const char[] abilityName, const char[] argument, float defaultValue=0.0, int slot = -3)
{
	if(HasAbility(boss, pluginName, abilityName, slot))
	{
		KeyValues kv=GetCharacterKV(character[boss]);
		return kv.GetFloat(argument, defaultValue);
	}
	return defaultValue;
}

stock void GetAbilityArgumentString(int boss, const char[] pluginName, const char[] abilityName, const char[] argument, char[] abilityString, int length, const char[] defaultValue="", int slot = -3)
{
	strcopy(abilityString, length, defaultValue);
	if(HasAbility(boss, pluginName, abilityName, slot))
	{
		KeyValues kv=GetCharacterKV(character[boss]);
		kv.GetString(argument, abilityString, length, defaultValue);
	}
}

stock bool FindSound(const char[] sound, char[] file, int length, int boss=0, bool ability=false, int slot=0)
{
	KeyValues kv=GetCharacterKV(character[boss]);
	if(boss<0 || character[boss]<0 || !kv)
	{
		return false;
	}

	kv.Rewind();
	if(!kv.JumpToKey("sounds"))
	{
		return false;  //Boss doesn't have any sounds
	}

	ArrayList soundsArray=CreateArray(PLATFORM_MAX_PATH);
	char match[PLATFORM_MAX_PATH];
	kv.GotoFirstSubKey();
	do  //Just keep looping until there's no keys left
	{
		if(kv.GetNum(sound))
		{
			if(!ability || kv.GetNum("slot")==slot)
			{
				kv.GetSectionName(match, sizeof(match));
				if(soundsArray.FindString(match)>=0)
				{
					char bossName[64];
					kv.Rewind();
					kv.GetString("name", bossName, sizeof(bossName));
					PrintToServer("[FF2 Bosses] Character %s has a duplicate sound '%s'!", bossName, match);
					continue; // We ignore all duplicates
				}
				soundsArray.PushString(match);
			}
		}
	}
	while(kv.GotoNextKey());

	if(!soundsArray.Length)
	{
		delete soundsArray;
		return false;  //No sounds matching what we want
	}

	soundsArray.GetString(GetRandomInt(0, GetArraySize(soundsArray)-1), file, length);
	delete soundsArray;
	return true;
}

public bool PickCharacter(int boss, int companion)
{
	if(boss==companion)
	{
		ArrayList chancesArray = CreateChancesArray(Boss[boss]);
		character[boss]=Incoming[boss];
		Incoming[boss]=-1;
		if(character[boss]!=-1)  //We've already picked a boss through Command_SetNextBoss
		{
			Action action;
			Call_StartForward(OnBossSelected);
			Call_PushCell(boss);
			int newCharacter=character[boss];
			Call_PushCellRef(newCharacter);
			char newName[64];
			KeyValues kv = GetCharacterKV(character[boss]);
			kv.Rewind();
			kv.GetString("name", newName, sizeof(newName));
			Call_PushStringEx(newName, sizeof(newName), SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
			Call_PushCell(true);  //Preset
			Call_Finish(action);
			if(action==Plugin_Changed)
			{
				if(newName[0])
				{
					char characterName[64];
					int foundExactMatch=-1, foundPartialMatch=-1;
					for(int characterIndex; characterIndex < bossesArray.Length && (kv = GetCharacterKV(characterIndex)); characterIndex++)
					{
						kv.Rewind();
						kv.GetString("name", characterName, sizeof(characterName));
						if(StrEqual(newName, characterName, false))
						{
							foundExactMatch=characterIndex;
							break;  //If we find an exact match there's no reason to keep looping
						}
						else if(StrContains(newName, characterName, false)!=-1)
						{
							foundPartialMatch=characterIndex;
						}

						//Do the same thing as above here, but look at the filename instead of the boss name
						KvGetString(kv, "filename", characterName, sizeof(characterName));
						if(StrEqual(newName, characterName, false))
						{
							foundExactMatch=characterIndex;
							break;  //If we find an exact match there's no reason to keep looping
						}
						else if(StrContains(newName, characterName, false)!=-1)
						{
							foundPartialMatch=characterIndex;
						}
					}

					if(foundExactMatch!=-1)
					{
						character[boss]=foundExactMatch;
					}
					else if(foundPartialMatch!=-1)
					{
						character[boss]=foundPartialMatch;
					}
					else
					{
						return false;
					}
					return true;
				}
				character[boss]=newCharacter;
				return true;
			}
			return true;
		}

		character[boss]=chancesArray.Get(GetRandomInt(0, chancesArray.Length-1));
/*
		for(int tries; tries<100; tries++)
		{
			character[boss]=GetRandomInt(0, GetArraySize(chancesArray)-1);

			// TODO: It would be awesome if we didn't have to check for this.
			// Then we wouldn't need to wrap all of this in a for loop.
			// FindCharacters() doesn't deal with the individual boss KVs though...
			// And supplying 0 as the boss's chance won't load the character.
			KvRewind(GetArrayCell(bossesArray, character[boss]));
			if(KvGetNum(GetArrayCell(bossesArray, character[boss]), "hidden"))
			{
				character[boss]=-1;
				continue;
			}
			break;
		}
*/

		delete chancesArray;
	}
	else
	{
		KeyValues kv = GetCharacterKV(character[boss]);
		char bossName[64], companionName[64];

		kv.Rewind();
		kv.GetString("companion", companionName, sizeof(companionName), "=Failed companion name=");

		int characterIndex;
		while(characterIndex < bossesArray.Length)  //Loop through all the bosses to find the companion we're looking for
		{
			kv = GetCharacterKV(characterIndex);
			kv.Rewind();
			kv.GetString("name", bossName, sizeof(bossName), "=Failed name=");
			if(StrEqual(bossName, companionName, false))
			{
				character[companion]=characterIndex;
				break;
			}

			kv.GetString("filename", bossName, sizeof(bossName), "=Failed name=");
			if(StrEqual(bossName, companionName, false))
			{
				character[companion]=characterIndex;
				break;
			}
			characterIndex++;
		}

		if(characterIndex == bossesArray.Length)  //Companion not found
		{
			return false;
		}
	}

	//All of the following uses `companion` because it will always be the boss index we want
	Action action;
	Call_StartForward(OnBossSelected);
	Call_PushCell(companion);
	int newCharacter=character[companion];
	KeyValues kv = GetCharacterKV(newCharacter);

	Call_PushCellRef(newCharacter);
	char newName[64];
	kv.Rewind();
	kv.GetString("name", newName, sizeof(newName));
	Call_PushStringEx(newName, sizeof(newName), SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(false);  //Not preset
	Call_Finish(action);
	if(action==Plugin_Changed)
	{
		if(newName[0])
		{
			char characterName[64];
			int foundExactMatch=-1, foundPartialMatch=-1;
			for(int characterIndex;
				characterIndex < bossesArray.Length && (kv = GetCharacterKV(characterIndex)); characterIndex++)
			{
				kv.Rewind();
				kv.GetString("name", characterName, sizeof(characterName));
				if(StrEqual(newName, characterName, false))
				{
					foundExactMatch=characterIndex;
					break;  //If we find an exact match there's no reason to keep looping
				}
				else if(StrContains(newName, characterName, false)!=-1)
				{
					foundPartialMatch=characterIndex;
				}

				//Do the same thing as above here, but look at the filename instead of the boss name
				kv.GetString("filename", characterName, sizeof(characterName));
				if(StrEqual(newName, characterName, false))
				{
					foundExactMatch=characterIndex;
					break;  //If we find an exact match there's no reason to keep looping
				}
				else if(StrContains(newName, characterName, false)!=-1)
				{
					foundPartialMatch=characterIndex;
				}
			}

			if(foundExactMatch!=-1)
			{
				character[companion]=foundExactMatch;
			}
			else if(foundPartialMatch!=-1)
			{
				character[companion]=foundPartialMatch;
			}
			else
			{
				return false;
			}
			return true;
		}
		character[companion]=newCharacter;
		return true;
	}
	return true;
}

void FindCompanion(int boss, int players, bool[] omit)
{
	static int playersNeeded=3;
	char companionName[64];
	KeyValues kv = GetCharacterKV(character[boss]);
	kv.Rewind();
	kv.GetString("companion", companionName, sizeof(companionName));
	if(playersNeeded<players && strlen(companionName))  //Only continue if we have enough players and if the boss has a companion
	{
		int companion=RandomlySelectClient(omit);

		Boss[companion]=companion;  //Woo boss indexes!
		omit[companion]=true;
		if(PickCharacter(boss, companion))  //TODO: This is a bit misleading
		{
			playersNeeded++;
			FindCompanion(companion, players, omit);  //Make sure this companion doesn't have a companion of their own
		}
		else  //Can't find the companion's character, so just play without the companion
		{
			LogError("[FF2 Bosses] Could not find boss %s!", companionName);
			Boss[companion]=0;
			omit[companion]=false;
		}
	}
	playersNeeded=3;  //Reset the amount of players needed back to 3 after we're done
}

// NOTE:
public Action FF2_OnCheckRules(int client, int characterIndex, int &chance, const char[] ruleName, const char[] value)
{
	int integerValue = StringToInt(value);
	char authId[32];
	GetClientAuthId(client, AuthId_SteamID64, authId, sizeof(authId));

	// CPrintToChatAll("%s: %s", ruleName, value);

	if(StrEqual(ruleName, "admin"))
	{
		AdminId adminId = GetUserAdmin(client);

		if(adminId != INVALID_ADMIN_ID)
		{
			if(!adminId.HasFlag(view_as<AdminFlag>(integerValue), Access_Real))
				return Plugin_Handled;
		}
		return Plugin_Handled;
	}
	if(StrEqual(ruleName, "blocked"))
	{
		return Plugin_Handled;
	}
	if(StrEqual(ruleName, "creator"))
	{
		int flags = GetBossCreatorFlags(authId, characterIndex, true);
		return flags > 0 ? Plugin_Continue : Plugin_Handled;
	}

	return Plugin_Continue;
}

public int HintPanelH(Menu menu, MenuAction action, int client, int selection)
{
	if(IsValidClient(client) && (action==MenuAction_Select || (action==MenuAction_Cancel && selection==MenuCancel_Exit)))
	{
		FF2Flags[client]|=FF2FLAG_CLASSHELPED;
	}
	return;
}

public int QueuePanelH(Menu menu, MenuAction action, int client, int selection)
{
	if(action==MenuAction_Select && selection==10)
	{
		TurnToZeroPanel(client, client);
	}
	return false;
}


public Action QueuePanelCmd(int client, int args)
{
	if(!Enabled2)
	{
		return Plugin_Continue;
	}

	char text[64];
	int items;
	bool[] added=new bool[MaxClients+1];

	Panel panel=new Panel();
	SetGlobalTransTarget(client);
	Format(text, sizeof(text), "%t", "Boss Queue");  //"Boss Queue"
	panel.SetTitle(text);
	for(int boss; boss<=MaxClients; boss++)  //Add the current bosses to the top of the list
	{
		if(IsBoss(boss))
		{
			added[boss]=true;  //Don't want the bosses to show up again in the actual queue list
			Format(text, sizeof(text), "%N-%i", boss, GetClientQueuePoints(boss));
			panel.DrawItem(text);
			items++;
		}
	}

	panel.DrawText("---");
	do
	{
		int target=GetClientWithMostQueuePoints(added);  //Get whoever has the highest queue points out of those who haven't been listed yet
		if(!IsValidClient(target))  //When there's no players left, fill up the rest of the list with blank lines
		{
			panel.DrawItem("");
			items++;
			continue;
		}

		Format(text, sizeof(text), "%N-%i", target, GetClientQueuePoints(target));
		if(client!=target)
		{
			panel.DrawItem(text);
			items++;
		}
		else
		{
			panel.DrawText(text);  //DrawPanelText() is white, which allows the client's points to stand out
		}
		added[target]=true;
	}
	while(items<9);

	Format(text, sizeof(text), "%t (%t)", "Your Queue Points", GetClientQueuePoints(client), "Reset Queue Points");  //"Your queue point(s) is {1} (set to 0)"
	panel.DrawItem(text);

	panel.Send(client, QueuePanelH, MENU_TIME_FOREVER);
	delete panel;
	return Plugin_Handled;
}

public Action ResetQueuePointsCmd(int client, int args)
{
	if(!Enabled2)
	{
		return Plugin_Continue;
	}

	if(client && !args)  //Normal players
	{
		TurnToZeroPanel(client, client);
		return Plugin_Handled;
	}

	if(!client)  //No confirmation for console
	{
		TurnToZeroPanelH(null, MenuAction_Select, client, 1);
		return Plugin_Handled;
	}

	AdminId admin=GetUserAdmin(client);	 //Normal players
	if((admin==INVALID_ADMIN_ID) || !GetAdminFlag(admin, Admin_Cheats))
	{
		TurnToZeroPanel(client, client);
		return Plugin_Handled;
	}

	if(args!=1)  //Admins
	{
		CReplyToCommand(client, "{olive}[FF2]{default} Usage: ff2_resetqueuepoints <target>");
		return Plugin_Handled;
	}

	char pattern[MAX_TARGET_LENGTH];
	GetCmdArg(1, pattern, sizeof(pattern));
	char targetName[MAX_TARGET_LENGTH];
	int targets[MAXPLAYERS], matches;
	bool targetNounIsMultiLanguage;

	if((matches=ProcessTargetString(pattern, client, targets, 1, 0, targetName, sizeof(targetName), targetNounIsMultiLanguage))<=0)
	{
		ReplyToTargetError(client, matches);
		return Plugin_Handled;
	}

	if(matches>1)
	{
		for(int target=1; target<matches; target++)
		{
			TurnToZeroPanel(client, targets[target]);  //FIXME:  This can only handle one client currently and doesn't iterate through all clients
		}
	}
	else
	{
		TurnToZeroPanel(client, targets[0]);
	}
	return Plugin_Handled;
}

public int TurnToZeroPanelH(Menu menu, MenuAction action, int client, int position)
{
	if(action==MenuAction_Select && position==1)
	{
		if(shortname[client]==client)
		{
			CPrintToChat(client,"{olive}[FF2]{default} %t", "Reset Queue Points Done");  //Your queue points have been reset to {olive}0{default}
		}
		else
		{
			CPrintToChat(client, "{olive}[FF2]{default} %t", "Reset Player's Points Done", shortname[client]);  //{olive}{1}{default}'s queue points have been reset to {olive}0{default}
			CPrintToChat(shortname[client], "{olive}[FF2]{default} %t", "Queue Points Reset by Admin", client);  //{olive}{1}{default} reset your queue points to {olive}0{default}
		}
		SetClientQueuePoints(shortname[client], 0);
	}
}

public Action TurnToZeroPanel(int client, int target)
{
	if(!Enabled2)
	{
		return Plugin_Continue;
	}

	Panel panel=CreatePanel();
	char text[128];
	SetGlobalTransTarget(client);
	if(client==target)
	{
		Format(text, 512, "%t", "Reset Queue Points Confirmation");  //Do you really want to set your queue points to 0?
	}
	else
	{
		Format(text, 512, "%t", "Reset Player's Queue Points", client);  //Do you really want to set {1}'s queue points to 0?
	}

	PrintToChat(client, text);
	panel.SetTitle(text);
	Format(text, sizeof(text), "%t", "Yes");
	panel.DrawItem(text);
	Format(text, sizeof(text), "%t", "No");
	panel.DrawItem(text);
	shortname[client]=target;
	panel.Send(client, TurnToZeroPanelH, MENU_TIME_FOREVER);
	delete panel;
	return Plugin_Handled;
}

int GetClientClassInfoCookie(int client)
{
	return GetSettingData(client, "class_info_view", KvData_Int);
}

int GetClientQueuePoints(int client)
{
	if(!IsValidClient(client))
	{
		return 0;
	}

	if(IsFakeClient(client))
	{
		return botqueuepoints;
	}

	return queuePoints[client];
}

void SetClientQueuePoints(int client, int points)
{
	if(IsValidClient(client) && !IsFakeClient(client))
	{
		char buffer[12];
		IntToString(points, buffer, sizeof(buffer));
		SetClientCookie(client, FF2Cookie_QueuePoints, buffer);
		queuePoints[client] = points;
	}
}

public Action FF2Panel(int client, int args)  //._.
{
	if(Enabled2 && IsValidClient(client, false))
	{
		Panel panel=CreatePanel();
		char text[512];
		SetGlobalTransTarget(client);
		Format(text, sizeof(text), "%t", "What's Up");
		panel.SetTitle(text);
		Format(text, sizeof(text), "%t", "Observe Health Value");
		panel.DrawItem(text);
		Format(text, sizeof(text), "%t", "Class Changes");
		panel.DrawItem(text);
		Format(text, sizeof(text), "%t", "What's New in FF2");
		panel.DrawItem(text);
		Format(text, sizeof(text), "%t", "View Queue Points");
		panel.DrawItem(text);
		Format(text, sizeof(text), "%t", "Toggle Music");
		panel.DrawItem(text);
		Format(text, sizeof(text), "%t", "Toggle Monologue");
		panel.DrawItem(text);
		Format(text, sizeof(text), "%t", "Toggle Class Changes");
		panel.DrawItem(text);
		Format(text, sizeof(text), "%t", "Advance Menu Title");
		panel.DrawItem(text);
		Format(text, sizeof(text), "%t", "Exit Menu");
		panel.DrawItem(text);
		panel.Send(client, Handler_FF2Panel, MENU_TIME_FOREVER);
		delete panel;
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public int Handler_FF2Panel(Menu menu, MenuAction action, int client, int selection)
{
	if(action==MenuAction_Select)
	{
		switch(selection)
		{
			case 1:
			{
				Command_GetHP(client);
			}
			case 2:
			{
				HelpPanelClass(client);
			}
			case 3:
			{
				ShowChangelog(client);
			}
			case 4:
			{
				QueuePanelCmd(client, 0);
			}
			case 5:
			{
				MusicTogglePanel(client);
			}
			case 6:
			{
				VoiceTogglePanel(client);
			}
			case 7:
			{
				HelpPanel3(client);
			}
			case 8:
			{
				AdvanceMenu(client, 0);
			}
			default:
			{
				return;
			}
		}
	}
}

public Action AdvanceMenu(int client, int args)
{
	if(Enabled2 && IsValidClient(client, false))
	{
		Panel panel=CreatePanel();
		char text[512];
		SetGlobalTransTarget(client);
		Format(text, sizeof(text), "%t", "Advance Menu Title");
		panel.SetTitle(text);
		Format(text, sizeof(text), "%t", "Boss Difficulty Setting");
		panel.DrawItem(text, ITEMDRAW_DISABLED); // TODO: For Now.
		Format(text, sizeof(text), "%t", "Hud Setting");
		panel.DrawItem(text);
		Format(text, sizeof(text), "%t", "Human Team Boss Setting Title");
		panel.DrawItem(text);
		Format(text, sizeof(text), "%t", "Exit Menu");
		panel.DrawItem(text);
		panel.Send(client, Handler_AdvanceMenuPanel, MENU_TIME_FOREVER);
		delete panel;
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public int Handler_AdvanceMenuPanel(Menu menu, MenuAction action, int client, int selection)
{
	if(action==MenuAction_Select)
	{
		switch(selection)
		{
			case 1:
			{
				BossDifficultyMenu(client, 0);
			}
			case 2:
			{
				HudMenu(client, 0);
			}
			case 3:
			{
				HumanTeamBossMenu(client, 0);
			}
			default:
			{
				return;
			}
		}
	}
}

public Action BossDifficultyMenu(int client, int args)
{

}

public Action HudMenu(int client, int args)
{
	if(Enabled2 && IsValidClient(client, false))
	{
		Menu menu=new Menu(HudMenu_Handler);
		char text[512];
		Format(text, sizeof(text), "%t", "Advance Menu Title");
		Format(text, sizeof(text), "%s > %t", text, "HudMenu Title");
		menu.SetTitle(text);
		Format(text, sizeof(text), "%t", "HudMenu Boss");
		menu.AddItem("Boss", text);
		Format(text, sizeof(text), "%t", "HudMenu Player");
		menu.AddItem("Player", text);
		Format(text, sizeof(text), "%t", "HudMenu Observer");
		menu.AddItem("Observer", text);
		Format(text, sizeof(text), "%t", "HudMenu Other");
		menu.AddItem("Other", text);

		menu.ExitButton=true;
		menu.Display(client, MENU_TIME_FOREVER);
	}
}

public int HudMenu_Handler(Menu menu, MenuAction action, int client, int selection)
{
	if(action==MenuAction_Select)
	{
		int drawStyle;
		char infoBuf[64];
		menu.GetItem(selection, infoBuf, sizeof(infoBuf), drawStyle);
		HudSettingMenu(client, infoBuf);
	}
}

public void HudSettingMenu(int client, const char[] name)
{
	SetGlobalTransTarget(client);

	int posId;
	kvHudConfigs.GetSectionSymbol(posId);
	kvHudConfigs.Rewind();

	char infoBuf[64], text[512], languageId[4], statusString[8];
	if(!kvHudConfigs.JumpToKey(name))
	{
		CPrintToChat(client, "{olive}[FF2]{default} %t", "Hud Setting Not Found!");
		return;
	}

	GetLanguageInfo(GetClientLanguage(client), languageId, sizeof(languageId));
	Menu afterMenu=new Menu(HudSetting_Handler);
	int value;
	bool changedLanguage=false;

	afterMenu.SetTitle(name);

	if(kvHudConfigs.GotoFirstSubKey(true))
	{
		do
		{
			kvHudConfigs.GetSectionName(infoBuf, sizeof(infoBuf));
			value=GetHudSetting(client, infoBuf);
			if(!StrEqual(languageId, "en"))
				changedLanguage=kvHudConfigs.JumpToKey(languageId);
			else
				changedLanguage=false;

			GetHudSettingString(value, statusString, 8);
			kvHudConfigs.GetString("title", text, sizeof(text));
			Format(text, sizeof(text), "%s: %s", text, statusString);
			afterMenu.AddItem(infoBuf, text);

			if(changedLanguage)
				kvHudConfigs.GoBack();
		}
		while(kvHudConfigs.GotoNextKey(true));
	}

	afterMenu.ExitButton=true;
	afterMenu.Display(client, MENU_TIME_FOREVER);
	kvHudConfigs.JumpToKeySymbol(posId);
}

public int HudSetting_Handler(Menu menu, MenuAction action, int client, int selection)
{
	if(action==MenuAction_Select)
	{
		int drawStyle;
		char infoBuf[64];
		menu.GetItem(selection, infoBuf, sizeof(infoBuf), drawStyle);

		HudDataMenu(client, infoBuf);
	}
}

void HudDataMenu(int client, char[] name)
{
	char text[256], tempText[80];

	int value=GetHudSetting(client, name);
	Menu menu=new Menu(HudData_Handler);
	GetHudSettingString(value, text, 8);

	menu.SetTitle("HUD SETTING > %s: %s", name, text);

	for(int loop=HudSetting_None; loop < HudSettingValue_Last; loop++)
	{
		GetHudSettingString(loop, text, 8);
		Format(tempText, sizeof(tempText), "Hud Setting %s", text);

		Format(text, sizeof(tempText), "%s: %t", text, tempText);
		menu.AddItem(name, text, (loop == HudSetting_None || loop == value) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}

	menu.ExitButton=true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int HudData_Handler(Menu menu, MenuAction action, int client, int selection)
{
	if(action==MenuAction_Select)
	{
		int drawStyle;
		char infoBuf[64], statusString[8];
		menu.GetItem(selection, infoBuf, sizeof(infoBuf), drawStyle);

		int value = selection-1;
		SetHudSetting(client, infoBuf, value);
		GetHudSettingString(value, statusString, 8);

		CPrintToChat(client, "{olive}[FF2]{default} %s: %s", infoBuf, statusString);
		HudMenu(client, 0);
	}
}

public Action HumanTeamBossMenu(int client, int args)
{
	if(Enabled2 && IsValidClient(client, false))
	{
		char text[512];
		Menu menu=new Menu(HumanTeamBossMenu_Handler);

		SetGlobalTransTarget(client);
		int currentSetting = GetSettingData(client, "human_team_boss_play", KvData_Int);

		Format(text, sizeof(text), "%t", "Advance Menu Title");
		Format(text, sizeof(text), "%s > %t\n", text, "Human Team Boss Setting Title");
		Format(text, sizeof(text), "%s\n", text, "Human Team Boss Setting Description");
		menu.SetTitle(text);

		Format(text, sizeof(text), "ON");
		if(currentSetting == 0)
			Format(text, sizeof(text), "%s%t", text, "Menu Already Choose");
		menu.AddItem("ON", text, currentSetting == 0 ? ITEMDRAW_DISABLED : 0);

		Format(text, sizeof(text), "OFF");
		if(currentSetting == 1)
			Format(text, sizeof(text), "%s%t", text, "Menu Already Choose");
		menu.AddItem("OFF", text, currentSetting == 1 ? ITEMDRAW_DISABLED : 0);

		menu.ExitButton=true;
		menu.Display(client, MENU_TIME_FOREVER);
	}
}

public int HumanTeamBossMenu_Handler(Menu menu, MenuAction action, int client, int selection)
{
	if(action==MenuAction_Select)
	{
		// 0: ON, 1: OFF
		SetSettingData(client, "human_team_boss_play", selection, KvData_Int);
		CPrintToChat(client, "{olive}[FF2]{default} %t: %s",
			"Human Team Boss Setting Title", selection > 0 ? "OFF" : "ON");
	}
}

public int Handler_ChangelogMenu(Menu menu, MenuAction action, int client, int selection)
{
	if(IsValidClient(client) && action==MenuAction_Select)
	{
		KeyValues kv=LoadChangelog();
		Menu logMenu=new Menu(Handler_Temp);
		int id;
		char infoBuf[8], text[256], temp[32];
		menu.GetItem(selection, infoBuf, 8, id, temp, sizeof(temp));

		id=StringToInt(infoBuf);
		kv.JumpToKeySymbol(id);
		kv.GetSectionName(text, sizeof(text));
		logMenu.SetTitle(text);
		logMenu.ExitButton=true;

		if(kv.GotoFirstSubKey(false))
		{
			do
			{
				kv.GetString(NULL_STRING, text, sizeof(text));
				logMenu.AddItem(temp, text, ITEMDRAW_DISABLED);
			}
			while(kv.GotoNextKey(false));
		}
		logMenu.Display(client, MENU_TIME_FOREVER);
	}
}

public int Handler_Temp(Menu menu, MenuAction action, int client, int selection)
{
	// Nop
}

public Action Command_ShowChangelog(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	ShowChangelog(client);
	return Plugin_Handled;
}

public Action ShowChangelog(int client)
{
	if(Enabled2)
	{
		DisplayMenu(changelogMenu, client, MENU_TIME_FOREVER);

		char timeStr[64];
		FormatTime(timeStr, sizeof(timeStr), "%Y-%m-%d %H:%M:%S");

		SetSettingStringData(client, "changelog_last_view_time", timeStr);
	}
	return Plugin_Continue;
}

public Action HelpPanel3Cmd(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	HelpPanel3(client);
	return Plugin_Handled;
}

public Action HelpPanel3(int client)
{
	if(!Enabled2)
	{
		return Plugin_Continue;
	}

	Panel panel=CreatePanel();
	panel.SetTitle("FF2 병과 정보를..");
	panel.DrawItem("ON");
	panel.DrawItem("OFF");
	panel.DrawItem("ON: 이번 라운드 보스 설명");
	panel.Send(client, ClassInfoTogglePanelH, MENU_TIME_FOREVER);
	delete panel;
	return Plugin_Handled;
}


public int ClassInfoTogglePanelH(Menu menu, MenuAction action, int client, int selection)
{
	if(IsValidClient(client))
	{
		if(action==MenuAction_Select)
		{
			// class_info_view: 0: VIEW, 1: OFF, 2, VIEW: Main boss's help panel
			SetSettingData(client, "class_info_view", selection - 1, KvData_Int);
			CPrintToChat(client, "{olive}[FF2]{default} %t", "FF2 Class Info", selection==2 ? "off" : "on");
		}
	}
}

public Action Command_HelpPanelClass(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	HelpPanelClass(client);
	return Plugin_Handled;
}

public Action HelpPanelClass(int client)
{
	if(!Enabled)
	{
		return Plugin_Continue;
	}

	int boss=GetBossIndex(client);
	if(boss!=-1)
	{
		HelpPanelBoss(client, boss);
		return Plugin_Continue;
	}

	char text[512];
	TFClassType playerclass=TF2_GetPlayerClass(client);
	SetGlobalTransTarget(client);
	switch(playerclass)
	{
		case TFClass_Scout:
		{
			Format(text, sizeof(text), "%t", "Scout Advice");
		}
		case TFClass_Soldier:
		{
			Format(text, sizeof(text), "%t", "Soldier Advice");
		}
		case TFClass_Pyro:
		{
			Format(text, sizeof(text), "%t", "Pyro Advice");
		}
		case TFClass_DemoMan:
		{
			Format(text, sizeof(text), "%t", "Demo Advice");
		}
		case TFClass_Heavy:
		{
			Format(text, sizeof(text), "%t", "Heavy Advice");
		}
		case TFClass_Engineer:
		{
			Format(text, sizeof(text), "%t", "Engineer Advice");
		}
		case TFClass_Medic:
		{
			Format(text, sizeof(text), "%t", "Medic Advice");
		}
		case TFClass_Sniper:
		{
			Format(text, sizeof(text), "%t", "Sniper Advice");
		}
		case TFClass_Spy:
		{
			Format(text, sizeof(text), "%t", "Spy Advice");
		}
		default:
		{
			Format(text, sizeof(text), "");
		}
	}

	if(playerclass!=TFClass_Sniper)
	{
		Format(text, sizeof(text), "%t\n%s", "Melee Advice", text);
	}

	int weapon;
	char weaponHintText[100];
	for(int loop = TFWeaponSlot_Primary; loop <= TFWeaponSlot_PDA; loop++)
	{
		weapon = GetPlayerWeaponSlot(client, loop);
		if(IsValidEntity(weapon) && GetWeaponHint(client, weapon, weaponHintText, sizeof(weaponHintText)))
			Format(text, sizeof(text), "%s\n%s", text, weaponHintText);
	}

	Panel panel=CreatePanel();
	panel.SetTitle(text);
	panel.DrawItem("Exit");
	panel.Send(client, HintPanelH, 20);
	delete panel;
	return Plugin_Continue;
}

void HelpPanelBoss(int client, int boss)
{
	if(!IsValidClient(Boss[boss]))
	{
		return;
	}

	KeyValues kv = GetCharacterKV(character[boss]);
	kv.Rewind();
	if(kv.JumpToKey("description"))
	{
		char text[512], language[8];
		GetLanguageInfo(GetClientLanguage(client), language, sizeof(language));
		//kv.SetEscapeSequences(true);  //Not working
		kv.GetString(language, text, sizeof(text));
		if(!text[0])
		{
			kv.GetString("en", text, sizeof(text));  //Default to English if their language isn't available
			if(!text[0])
			{
				return;
			}
		}
		ReplaceString(text, sizeof(text), "\\n", "\n");
		//kv.SetEscapeSequences(false);  //We don't want to interfere with the download paths

		Panel panel=CreatePanel();
		panel.SetTitle(text);
		panel.DrawItem("Exit");
		panel.Send(client, HintPanelH, 20);
		delete panel;
	}
}

public Action MusicTogglePanelCmd(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	MusicTogglePanel(client);
	return Plugin_Handled;
}

public Action MusicTogglePanel(int client)
{
	if(!Enabled || !IsValidClient(client))
	{
		return Plugin_Continue;
	}

	char text[128];
	Panel panel=CreatePanel();
	SetGlobalTransTarget(client);
	Format(text, sizeof(text), "%t", "Toggle Music Switch");

	panel.SetTitle(text);
	panel.DrawItem("ON");
	panel.DrawItem("OFF");
	Format(text, sizeof(text), "%T", "Music Track Select Title", client);
	panel.DrawItem(text);
	panel.Send(client, MusicTogglePanelH, MENU_TIME_FOREVER);
	delete panel;
	return Plugin_Continue;
}

public int MusicTogglePanelH(Menu menu, MenuAction action, int client, int selection)
{
	if(IsValidClient(client) && action==MenuAction_Select)
	{
		if(selection == 3)
		{
			MusicTrackMenu(client);
			return 0;
		}
		else if(selection==2)  //Off
		{
			SetSoundFlags(client, FF2SOUND_MUTEMUSIC);
			StopMusic(client, true);
		}
		else  //On
		{
			//If they already have music enabled don't do anything
			if(!CheckSoundFlags(client, FF2SOUND_MUTEMUSIC))
			{
				ClearSoundFlags(client, FF2SOUND_MUTEMUSIC);
				StartMusic(client);
			}
		}
		CPrintToChat(client, "{olive}[FF2]{default} %t", "FF2 Music", selection==2 ? "off" : "on");
	}
	return 0;
}

public void MusicTrackMenu(int client)
{
	if(!Enabled || !IsValidClient(client))
	{
		return;
	}

	SetGlobalTransTarget(client);

	char text[128], musicId[84], bossName[64], kvString[64];
	Menu menu = new Menu(MusicTrackMenu_Handler);

	Format(text, sizeof(text), "%T", "Music Track Select Title", client);
	menu.SetTitle(text);

	MD5_String(currentBGM[client], musicId, sizeof(musicId));
	Format(text, sizeof(text), "[%s] %T", GetMusicSetting(client, musicId) ? "ON" : "OFF",
		"Menu Music Track Current Music", client);
	menu.AddItem(musicId, text);

	KeyValues bossKv;
	bool hasMusic;
	// TODO: 외부 팩 지원
	char language[8];
	int lang = GetClientLanguage(client);

	GetLanguageInfo(lang, language, sizeof(language));
	for(int characterIndex = 0; characterIndex < bossesArray.Length && (bossKv = GetCharacterKV(characterIndex)); characterIndex++)
	{
		hasMusic = false;

		bossKv.Rewind();
		if(bossKv.JumpToKey("name_lang"))
			bossKv.GetString(language, bossName, sizeof(bossName));
		else
			bossKv.GetString("name", bossName, sizeof(bossName));

		bossKv.Rewind();
		if(!bossKv.JumpToKey("sounds")) 	continue;

		bossKv.GotoFirstSubKey();
		do
		{
			int time = RoundFloat(bossKv.GetFloat("time", 0.0));
			if(time > 0)
			{
				hasMusic = true;
				break;
			}
		}
		while(bossKv.GotoNextKey());

		if(!hasMusic)	continue;

		IntToString(view_as<int>(bossKv), kvString, sizeof(kvString));
		Format(text, sizeof(text), "%T", "Menu Music Track Boss Music", client, bossName);
		menu.AddItem(kvString, text);
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

enum
{
	MusicTrackMenu_SelectCurrentMusic = 0,

	MusicTrackMenu_Count
};

public int MusicTrackMenu_Handler(Menu menu, MenuAction action, int client, int selection)
{
	char packName[128];

	switch(action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Cancel:
		{
			if(selection == MenuCancel_ExitBack)
				MusicTogglePanel(client);
		}
		case MenuAction_Select:
		{
			GetMenuItem(menu, selection, packName, sizeof(packName));
			switch(selection)
			{
				case MusicTrackMenu_SelectCurrentMusic:
				{
					bool value = !GetMusicSetting(client, packName);
					SetMusicSetting(client, packName, value);

					CPrintToChat(client, "{olive}[FF2]{default} %T", "Menu Music Track Choose Music Setting",
						client, value ? "ON" : "OFF");
					MusicTrackMenu(client);

					StopMusic(client);
					StartMusic(client);
				}
				default:
				{
					MusicTrackDetailMenu(client, view_as<KeyValues>(StringToInt(packName)));
				}
			}
		}
	}
}

public void MusicTrackDetailMenu(int client, KeyValues kv)
{
	if(!Enabled || !IsValidClient(client) || kv == null)
	{
		return;
	}

	SetGlobalTransTarget(client);

	char text[128], musicId[84], path[PLATFORM_MAX_PATH], information[258], bossName[64], language[8];
	Menu menu = new Menu(MusicTrackDetailMenu_Handler);
	int lang = GetClientLanguage(client);

	GetLanguageInfo(lang, language, sizeof(language));
	kv.Rewind();

	if(kv.JumpToKey("name_lang"))
		kv.GetString(language, bossName, sizeof(bossName), "");
	else
		kv.GetString("name", bossName, sizeof(bossName), "");

	kv.Rewind();
	if(!kv.JumpToKey("sounds"))		return;

	Format(text, sizeof(text), "%T", "Music Track Detail Title", client, bossName);
	menu.SetTitle(text);

	IntToString(view_as<int>(kv), musicId, sizeof(musicId));
	menu.AddItem(musicId, musicId, ITEMDRAW_IGNORE);

	int index = 1;

	kv.GotoFirstSubKey();
	do
	{
		kv.GetSectionName(path, PLATFORM_MAX_PATH);
		MD5_String(path, musicId, sizeof(musicId));
		int time = RoundFloat(kv.GetFloat("time", 0.0));
		if(time > 0)
		{
			kv.GetString("information", information, sizeof(information), "");
			if(information[0] == '\0')
			{
				Format(information, sizeof(information), "%T", "Boss Music Info", client, bossName, index);
			}

			Format(text, sizeof(text), "[%s] %s", GetMusicSetting(client, musicId) ? "ON" : "OFF",
				information);
			menu.AddItem(path, text);

			index++;
		}
	}
	while(kv.GotoNextKey());

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MusicTrackDetailMenu_Handler(Menu menu, MenuAction action, int client, int selection)
{
	char kvString[84], musicId[84], currentMusicId[84], path[PLATFORM_MAX_PATH];

	switch(action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Cancel:
		{
			if(selection == MenuCancel_ExitBack)
				MusicTrackMenu(client);
		}
		case MenuAction_Select:
		{
			GetMenuItem(menu, 0, kvString, sizeof(kvString));
			GetMenuItem(menu, selection, path, sizeof(path));
			MD5_String(path, musicId, sizeof(musicId));
/*
//			TODO: THIS
			if(GetClientButtons(client) & IN_RELOAD)
			{

				strcopy(currentBGM[client], sizeof(currentBGM[]), path);

				StopMusic(client);
				StartMusic(client);
			}
*/
			bool value = !GetMusicSetting(client, musicId);
			SetMusicSetting(client, musicId, value);

			CPrintToChat(client, "{olive}[FF2]{default} %T", "Menu Music Track Choose Music Setting", client, value ? "ON" : "OFF");

			MD5_String(currentBGM[client], currentMusicId, sizeof(currentMusicId));
			if(StrEqual(currentMusicId, musicId))
			{
				StopMusic(client);
				StartMusic(client);
			}

			KeyValues kv = view_as<KeyValues>(StringToInt(kvString));
			MusicTrackDetailMenu(client, kv);
		}
	}
}

public Action VoiceTogglePanelCmd(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	VoiceTogglePanel(client);
	return Plugin_Handled;
}

public Action VoiceTogglePanel(int client)
{
	if(!Enabled || !IsValidClient(client))
	{
		return Plugin_Continue;
	}

	char text[128];
	Panel panel=CreatePanel();
	SetGlobalTransTarget(client);
	Format(text, sizeof(text), "%t", "Toggle Monologue Switch");

	panel.SetTitle(text);
	panel.DrawItem("ON");
	panel.DrawItem("OFF");
	panel.Send(client, VoiceTogglePanelH, MENU_TIME_FOREVER);
	delete panel;
	return Plugin_Continue;
}

public int VoiceTogglePanelH(Menu menu, MenuAction action, int client, int selection)
{
	if(IsValidClient(client))
	{
		if(action==MenuAction_Select)
		{
			if(selection==2)
			{
				SetSoundFlags(client, FF2SOUND_MUTEVOICE);
			}
			else
			{
				ClearSoundFlags(client, FF2SOUND_MUTEVOICE);
			}

			CPrintToChat(client, "{olive}[FF2]{default} %t", "FF2 Voice", selection==2 ? "off" : "on");
			if(selection==2)
			{
				CPrintToChat(client, "%t", "FF2 Voice 2");
			}
		}
	}
}

public Action HookSound(int clients[64], int& numClients, char sound[PLATFORM_MAX_PATH], int& client, int& channel, float& volume, int& level, int& pitch, int& flags, char soundEntry[PLATFORM_MAX_PATH], int& seed)
{
	if(!Enabled || !IsValidClient(client) || channel<1)
	{
		return Plugin_Continue;
	}

	int boss=GetBossIndex(client);
	if(boss==-1)
	{
		return Plugin_Continue;
	}

	if(channel==SNDCHAN_VOICE)
	{
		char newSound[PLATFORM_MAX_PATH];
		if(FindSound("catch phrase", newSound, sizeof(newSound), boss))
		{
			strcopy(sound, sizeof(sound), newSound);
			return Plugin_Changed;
		}

		bool isBlockVoice = false;
		KeyValues bossKv = GetCharacterKV(character[boss]);

		bossKv.Rewind();
		isBlockVoice=bossKv.GetNum("block voice", 0) > 0;

		if(isBlockVoice)
		{
			return Plugin_Stop;
		}
	}
	return Plugin_Continue;
}

stock int GetHealingTarget(int client, bool checkgun=false)
{
	int medigun=GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
	if(!checkgun)
	{
		if(GetEntProp(medigun, Prop_Send, "m_bHealing"))
		{
			return GetEntPropEnt(medigun, Prop_Send, "m_hHealingTarget");
		}
		return -1;
	}

	if(IsValidEntity(medigun))
	{
		char classname[64];
		GetEntityClassname(medigun, classname, sizeof(classname));
		if(StrEqual(classname, "tf_weapon_medigun", false))
		{
			if(GetEntProp(medigun, Prop_Send, "m_bHealing"))
			{
				return GetEntPropEnt(medigun, Prop_Send, "m_hHealingTarget");
			}
		}
	}
	return -1;
}

public void CvarChangeNextmap(ConVar convar, const char[] oldValue, const char[] newValue)
{
	CreateTimer(0.1, Timer_DisplayCharsetVote, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_DisplayCharsetVote(Handle timer)
{
	if(isCharSetSelected)
	{
		return Plugin_Continue;
	}

	if(IsVoteInProgress())
	{
		CreateTimer(5.0, Timer_DisplayCharsetVote, _, TIMER_FLAG_NO_MAPCHANGE);  //Try again in 5 seconds if there's a different vote going on
		return Plugin_Continue;
	}

	Menu menu=new Menu(Handler_VoteCharset, view_as<MenuAction>(MENU_ACTIONS_ALL));
	menu.SetTitle("%t", "Vote for Character Set");  //"Please vote for the character set for the next map."

	char config[PLATFORM_MAX_PATH], charset[64];
	BuildPath(Path_SM, config, sizeof(config), "%s/%s", FF2_SETTINGS, BOSS_CONFIG);

	KeyValues Kv=new KeyValues("");
	Kv.ImportFromFile(config);
	menu.AddItem("Random", "Random");
	int total, charsets;
	do
	{
		total++;
		if(Kv.GetNum("hidden", 0))  //Hidden charsets are hidden for a reason :P
		{
			continue;
		}
		charsets++;
		validCharsets[charsets]=total;

		Kv.GetSectionName(charset, sizeof(charset));
		menu.AddItem(charset, charset);
	}
	while(Kv.GotoNextKey());
	delete Kv;

	if(charsets>1)  //We have enough to call a vote
	{
		FF2CharSet=charsets;  //Temporary so that if the vote result is random we know how many valid charsets are in the validCharset array
		ConVar voteDuration=FindConVar("sm_mapvote_voteduration");
		VoteMenuToAll(menu, voteDuration ? voteDuration.IntValue : 20);
	}
	return Plugin_Continue;
}

public int Handler_VoteCharset(Menu menu, MenuAction action, int param1, int param2)
{
	if(action==MenuAction_VoteEnd)
	{
		FF2CharSet=param1 ? param1-1 : validCharsets[GetRandomInt(1, FF2CharSet)]-1;  //If param1 is 0 then we need to find a random charset

		char nextmap[42];
		cvarNextmap.GetString(nextmap, sizeof(nextmap));
		menu.GetItem(param1, FF2CharSetString, sizeof(FF2CharSetString));
		CPrintToChatAll("{olive}[FF2]{default} %t", "Character Set Next Map", nextmap, FF2CharSetString);  //"The character set for {1} will be {2}."
		isCharSetSelected=true;
	}
	else if(action==MenuAction_End)
	{
		delete menu;
	}
}

public Action Command_Nextmap(int client, int args)
{
	if(FF2CharSetString[0])
	{
		char nextmap[42];
		cvarNextmap.GetString(nextmap, sizeof(nextmap));
		CPrintToChat(client, "{olive}[FF2]{default} %t", "Character Set Next Map", nextmap, FF2CharSetString);
	}
	return Plugin_Handled;
}

public Action Command_Say(int client, int args)
{
	char chat[128];
	if(GetCmdArgString(chat, sizeof(chat))<1 || !client)
	{
		return Plugin_Continue;
	}

	if(StrEqual(chat, "\"nextmap\"") && FF2CharSetString[0])
	{
		Command_Nextmap(client, 0);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

stock void RemoveShield(int client, int attacker, float position[3])
{
	TF2_RemoveWearable(client, shield[client]);
	PlayShieldBreakSound(client, attacker, position);
	TF2_AddCondition(client, TFCond_Bonked, 0.1); // Shows "MISS!" upon breaking shield
	shield[client]=0;
}

//Natives aren't inlined because of https://github.com/50DKP/FF2-Official/issues/263

public bool IsFF2Enabled()
{
	return Enabled;
}

public int Native_IsFF2Enabled(Handle plugin, int numParams)
{
	return IsFF2Enabled();
}

public void RegisterSubplugin(char[] pluginName)
{
	PushArrayString(subpluginArray, pluginName);
}

public int Native_RegisterSubplugin(Handle plugin, int numParams)
{
	char pluginName[64];
	GetNativeString(1, pluginName, sizeof(pluginName));
	RegisterSubplugin(pluginName);
}

public void UnregisterSubplugin(char[] pluginName)
{
	int index=FindStringInArray(subpluginArray, pluginName);
	if(index>=0)
	{
		RemoveFromArray(subpluginArray, index);
	}
}

public int Native_UnregisterSubplugin(Handle plugin, int numParams)
{
	char pluginName[64];
	GetNativeString(1, pluginName, sizeof(pluginName));
	UnregisterSubplugin(pluginName);
}

public bool GetFF2Version()
{
	int version[3];  //Blame the compiler for this mess -.-
	version[0]=StringToInt(MAJOR_REVISION);
	version[1]=StringToInt(MINOR_REVISION);
	version[2]=StringToInt(STABLE_REVISION);
	SetNativeArray(1, version, sizeof(version));
	#if !defined DEV_REVISION
		return false;
	#else
		return true;
	#endif
}

public int Native_GetFF2Version(Handle plugin, int numParams)
{
	return GetFF2Version();
}

public int Native_GetRoundState(Handle plugin, int numParams)
{
	return view_as<int>(CheckRoundState());
}

public int GetBossUserId(int boss)
{
	if(boss>=0 && boss<=MaxClients && IsValidClient(Boss[boss]))
	{
		return GetClientUserId(Boss[boss]);
	}
	return -1;
}

public int Native_GetBossUserId(Handle plugin, int numParams)
{
	return GetBossUserId(GetNativeCell(1));
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

public int Native_GetBossIndex(Handle plugin, int numParams)
{
	return GetBossIndex(GetNativeCell(1));
}

public TFTeam GetBossTeam()
{
	return BossTeam;
}

public int Native_GetBossTeam(Handle plugin, int numParams)
{
	return view_as<int>(GetBossTeam());
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

public int Native_GetBossName(Handle plugin, int numParams)
{
	int length=GetNativeCell(3);
	char[] bossName=new char[length];
	bool bossExists=GetBossName(GetNativeCell(1), bossName, length, GetNativeCell(4));
	SetNativeString(2, bossName, length);
	return bossExists;
}

static const char g_strCreatorType[][] = {
    "other",
    "model",
    "plugin",
    "sound"
};

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

public int Native_GetBossCreatorFlags(Handle plugin, int numParams)
{
	char steamId[32];
	GetNativeString(1, steamId, sizeof(steamId));
	return view_as<int>(GetBossCreatorFlags(steamId, GetNativeCell(2), GetNativeCell(3)));
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

public int Native_GetBossCreators(Handle plugin, int numParams)
{
	return view_as<int>(GetBossCreators(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3)));
}

public KeyValues GetBossKV(int boss)
{
	if(boss >= 0 && boss <= MaxClients && character[boss] >= 0 && character[boss] < bossesArray.Length)
	{
		return view_as<KeyValues>(GetCharacterKV(character[boss]));
	}
	return null;
}

public int Native_GetBossKV(Handle plugin, int numParams)
{
	return view_as<int>(GetBossKV(GetNativeCell(1)));
}

public KeyValues GetCharacterKV(int characterIndex)
{
	if(characterIndex >= 0 && characterIndex < bossesArray.Length)
	{
		return view_as<KeyValues>(bossesArray.Get(characterIndex));
	}
	return null;
}

public int Native_GetCharacterKV(Handle plugin, int numParams)
{
	return view_as<int>(GetCharacterKV(GetNativeCell(1)));
}

public int GetBossHealth(int boss)
{
	return BossHealth[boss];
}

public int Native_GetBossHealth(Handle plugin, int numParams)
{
	return GetBossHealth(GetNativeCell(1));
}

public int SetBossHealth(int boss, int health)
{
	BossHealth[boss]=health;
}

public int Native_SetBossHealth(Handle plugin, int numParams)
{
	SetBossHealth(GetNativeCell(1), GetNativeCell(2));
	UpdateHealthBar();
}

public int GetBossMaxHealth(int boss)
{
	return BossHealthMax[boss];
}

public int Native_GetBossMaxHealth(Handle plugin, int numParams)
{
	return GetBossMaxHealth(GetNativeCell(1));
}

public int SetBossMaxHealth(int boss, int health)
{
	BossHealthMax[boss]=health;
}

public int Native_SetBossMaxHealth(Handle plugin, int numParams)
{
	SetBossMaxHealth(GetNativeCell(1), GetNativeCell(2));
}

public int GetBossLives(int boss)
{
	return BossLives[boss];
}

public int Native_GetBossLives(Handle plugin, int numParams)
{
	return GetBossLives(GetNativeCell(1));
}

public int SetBossLives(int boss, int lives)
{
	BossLives[boss]=lives;
}

public int Native_SetBossLives(Handle plugin, int numParams)
{
	SetBossLives(GetNativeCell(1), GetNativeCell(2));
}

public int GetBossMaxLives(int boss)
{
	return BossLivesMax[boss];
}

public int Native_GetBossMaxLives(Handle plugin, int numParams)
{
	return GetBossMaxLives(GetNativeCell(1));
}

public int SetBossMaxLives(int boss, int lives)
{
	BossLivesMax[boss]=lives;
}

public int Native_SetBossMaxLives(Handle plugin, int numParams)
{
	SetBossMaxLives(GetNativeCell(1), GetNativeCell(2));
}

public float GetBossCharge(int boss, int slot)
{
	return BossCharge[boss][slot];
}

public int Native_GetBossCharge(Handle plugin, int numParams)
{
	return view_as<int>(GetBossCharge(GetNativeCell(1), GetNativeCell(2)));
}

public int SetBossCharge(int boss, int slot, float charge)
{
	BossCharge[boss][slot]=charge;
}

public int Native_SetBossCharge(Handle plugin, int numParams)
{
	SetBossCharge(GetNativeCell(1), GetNativeCell(2), view_as<float>(GetNativeCell(3)));
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

public int Native_AddBossCharge(Handle plugin, int numParams)
{
	AddBossCharge(GetNativeCell(1), GetNativeCell(2), view_as<float>(GetNativeCell(3)));
}

public int GetBossRageDamage(int boss)
{
	return BossRageDamage[boss];
}

public int Native_GetBossRageDamage(Handle plugin, int numParams)
{
	return GetBossRageDamage(GetNativeCell(1));
}

public int SetBossRageDamage(int boss, int damage)
{
	BossRageDamage[boss]=damage;
}

public int Native_SetBossRageDamage(Handle plugin, int numParams)
{
	SetBossRageDamage(GetNativeCell(1), GetNativeCell(2));
}

int GetBossRageDistance(int boss, const char[] pluginName, const char[] abilityName, int slot = -3)
{
	KeyValues kv = GetCharacterKV(character[boss]);
	if(!kv)  //Invalid boss
	{
		return 0;
	}

	kv.Rewind();
	if(!abilityName[0])  //Return the global rage distance if there's no ability specified
	{
		return ParseFormula(boss, "rage distance", 400);
	}

	if(HasAbility(boss, pluginName, abilityName, slot))
	{
		// char key[128];
		// Format(key, sizeof(key), "distance");

		int distance;
		if((distance = RoundFloat(kv.GetFloat("distance", -1.0))) < 0/*ParseFormula(boss, key, -1))<0*/)  //Distance doesn't exist, return the global rage distance instead
		{
			kv.Rewind();
			distance=ParseFormula(boss, "rage distance", 400);
		}
		return distance;
	}
	return 0;
}

public int Native_GetBossRageDistance(Handle plugin, int numParams)
{
	char pluginName[64], abilityName[64];
	GetNativeString(2, pluginName, sizeof(pluginName));
	GetNativeString(3, abilityName, sizeof(abilityName));
	return GetBossRageDistance(GetNativeCell(1), pluginName, abilityName, GetNativeCell(4));
}

public int GetClientDamage(int client)
{
	return Damage[client];
}

public int Native_GetClientDamage(Handle plugin, int numParams)
{
	return GetClientDamage(GetNativeCell(1));
}

public int SetClientDamage(int client, int damage)
{
	Damage[client]=damage;
}

public int Native_SetClientDamage(Handle plugin, int numParams)
{
	SetClientDamage(GetNativeCell(1), GetNativeCell(2));
}

public int GetRoundTime()
{
	return view_as<int>(timeleft);
}

public int Native_GetRoundTime(Handle plugin, int numParams)
{
	return GetRoundTime();
}

public void SetRoundTime(float time)
{
	timeleft = time;
}

public int Native_SetRoundTime(Handle plugin, int numParams)
{
	SetRoundTime(GetNativeCell(1));
}

public int GetClientAssist(int client)
{
	return Assist[client];
}

public int Native_GetClientAssist(Handle plugin, int numParams)
{
	return GetClientAssist(GetNativeCell(1));
}

public void SetClientAssist(int client, int assist)
{
	Assist[client]=assist;
}

public int Native_SetClientAssist(Handle plugin, int numParams)
{
	SetClientAssist(GetNativeCell(1), GetNativeCell(2));
}

public int Native_EquipBoss(Handle plugin, int numParams)
{
	EquipBoss(GetNativeCell(1));
}

public Action SpecialAttackToBoss(int attacker, int victimBoss, int weapon, char[] name, float &damage)
{
	return Forward_OnSpecialAttack(attacker, victimBoss, weapon, name, damage);
}

public int Native_SpecialAttackToBoss(Handle plugin, int numParams)
{
	char name[80];
	GetNativeString(4, name, sizeof(name));
	float damage = GetNativeCell(5);
	SpecialAttackToBoss(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3), name, damage);
}

public Action Forward_OnSpecialAttack(int attacker, int victimBoss, int weapon, const char[] name, float &damage)
{
	float tempDamage = damage;
	Action action;
	Call_StartForward(OnSpecialAttack);
	Call_PushCell(attacker);
	Call_PushCell(victimBoss);
	Call_PushCell(weapon);
	Call_PushString(name);
	Call_PushFloatRef(tempDamage);
	Call_Finish(action);

	if(action == Plugin_Stop || action == Plugin_Handled)
	{
		return Plugin_Handled;
	}
	else if(action == Plugin_Changed)
	{
		damage = tempDamage;
	}

	Forward_OnSpecialAttack_Post(attacker, victimBoss, name, damage);
	return Plugin_Continue;
}

public void Forward_OnSpecialAttack_Post(int attacker, int victimBoss, const char[] name, float damage)
{
	Call_StartForward(OnSpecialAttack_Post);
	Call_PushCell(attacker);
	Call_PushCell(victimBoss);
	Call_PushString(name);
	Call_PushFloat(damage);
	Call_Finish();
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

public int Native_HasAbility(Handle plugin, int numParams)
{
	char pluginName[64], abilityName[64];
	GetNativeString(2, pluginName, sizeof(pluginName));
	GetNativeString(3, abilityName, sizeof(abilityName));
	return HasAbility(GetNativeCell(1), pluginName, abilityName, GetNativeCell(4));
}

public int GetAbilityArgumentWrapper(int boss, const char[] pluginName, const char[] abilityName, const char[] argument, int defaultValue, int slot)
{
	return GetAbilityArgument(boss, pluginName, abilityName, argument, defaultValue, slot);
}

public int Native_GetAbilityArgument(Handle plugin, int numParams)
{
	char pluginName[64], abilityName[64], argument[64];
	GetNativeString(2, pluginName, sizeof(pluginName));
	GetNativeString(3, abilityName, sizeof(abilityName));
	GetNativeString(4, argument, sizeof(argument));
	return GetAbilityArgumentWrapper(GetNativeCell(1), pluginName, abilityName, argument, GetNativeCell(5), GetNativeCell(6));
}

public float GetAbilityArgumentFloatWrapper(int boss, const char[] pluginName, const char[] abilityName, const char[] argument, float defaultValue, int slot)
{
	return GetAbilityArgumentFloat(boss, pluginName, abilityName, argument, defaultValue, slot);
}

public int Native_GetAbilityArgumentFloat(Handle plugin, int numParams)
{
	char pluginName[64], abilityName[64], argument[64];
	GetNativeString(2, pluginName, sizeof(pluginName));
	GetNativeString(3, abilityName, sizeof(abilityName));
	GetNativeString(4, argument, sizeof(argument));
	return view_as<int>(GetAbilityArgumentFloatWrapper(GetNativeCell(1), pluginName, abilityName, argument, view_as<float>(GetNativeCell(5)), GetNativeCell(6)));
}

public int GetAbilityArgumentStringWrapper(int boss, const char[] pluginName, const char[] abilityName, const char[] argument, char[] abilityString, int length, const char[] defaultValue, int slot)
{
	GetAbilityArgumentString(boss, pluginName, abilityName, argument, abilityString, length, defaultValue, slot);
}

public int Native_GetAbilityArgumentString(Handle plugin, int numParams)
{
	char pluginName[64], abilityName[64], defaultValue[64], argument[64];
	GetNativeString(2, pluginName, sizeof(pluginName));
	GetNativeString(3, abilityName, sizeof(abilityName));
	GetNativeString(4, argument, sizeof(argument));
	GetNativeString(7, defaultValue, sizeof(defaultValue));
	int length=GetNativeCell(6);
	char[] abilityString=new char[length];
	GetAbilityArgumentStringWrapper(GetNativeCell(1), pluginName, abilityName, argument, abilityString, length, defaultValue, GetNativeCell(8));
	SetNativeString(5, abilityString, length);
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
				float charge=100.0*0.05/GetAbilityArgumentFloat(boss, pluginName, abilityName, "charge", 1.0);
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
				BossCharge[boss][slot]+=0.12;
			}
		}
		else if(BossCharge[boss][slot]>0.3)
		{
			Call_PushCell(3);  //In use
			float cooldown=GetAbilityArgumentFloat(boss, pluginName, abilityName, "cooldown", 0.0);

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
			BossCharge[boss][slot]+=0.12;
		}
		else
		{
			Call_PushCell(0);  //Not in use
			Call_Finish();
		}
	}
	return true;
}

public int Native_UseAbility(Handle plugin, int numParams)
{
	char pluginName[64], abilityName[64];
	GetNativeString(2, pluginName, sizeof(pluginName));
	GetNativeString(3, abilityName, sizeof(abilityName));
	UseAbility(GetNativeCell(1), pluginName, abilityName, GetNativeCell(4), GetNativeCell(5));
}

public int GetFF2Flags(int client)
{
	return FF2Flags[client];
}

public int Native_GetFF2Flags(Handle plugin, int numParams)
{
	return GetFF2Flags(GetNativeCell(1));
}

public int SetFF2Flags(int client, int flags)
{
	FF2Flags[client]=flags;
}

public int Native_SetFF2Flags(Handle plugin, int numParams)
{
	SetFF2Flags(GetNativeCell(1), GetNativeCell(2));
}

public int Native_GetQueuePoints(Handle plugin, int numParams)
{
	return GetClientQueuePoints(GetNativeCell(1));
}

public int Native_SetQueuePoints(Handle plugin, int numParams)
{
	SetClientQueuePoints(GetNativeCell(1), GetNativeCell(2));
}

public float GetClientGlow(int client)
{
	return GlowTimer[client];
}

public int Native_GetClientGlow(Handle plugin, int numParams)
{
	return view_as<int>(GetClientGlow(GetNativeCell(1)));
}

// FIXME: 구조가 명확하지 않음
void SetClientGlow(int client, float time1, float time2=-1.0)
{
	if(IsValidClient(client))
	{
		GlowTimer[client]+=time1;
		if(time2>=0)
		{
			GlowTimer[client]=time2;
		}

		if(GlowTimer[client]<=0.0)
		{
			GlowTimer[client]=0.0;
			SetEntProp(client, Prop_Send, "m_bGlowEnabled", 0);
		}
		else
		{
			SetEntProp(client, Prop_Send, "m_bGlowEnabled", 1);
		}
	}
}

public int Native_SetClientGlow(Handle plugin, int numParams)
{
	SetClientGlow(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3));
}

public int Native_Debug(Handle plugin, int numParams)
{
	return cvarDebug.BoolValue;
}

public int Native_GetTimerType(Handle plugin, int numParams)
{
	return timeType;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(cvarHealthBar.BoolValue)
	{
		/*
		if(StrEqual(classname, HEALTHBAR_CLASS))
		{
			healthBar=entity;
		}
		*/
		if(!IsValidEntity(g_Monoculus) && StrEqual(classname, MONOCULUS))
		{
			g_Monoculus=entity;
		}
	}

	if(StrContains(classname, "item_healthkit")!=-1 || StrContains(classname, "item_ammopack")!=-1 || StrEqual(classname, "tf_ammo_pack"))
	{
		SDKHook(entity, SDKHook_Spawn, OnItemSpawned);
	}

	if(StrEqual(classname, "tf_logic_koth"))
	{
		SDKHook(entity, SDKHook_Spawn, Spawn_Koth);
	}
}

public void OnEntityDestroyed(int entity)
{
	if(entity==g_Monoculus)
	{
		g_Monoculus=FindEntityByClassname(-1, MONOCULUS);
		if(g_Monoculus==entity)
		{
			g_Monoculus=FindEntityByClassname(entity, MONOCULUS);
		}
	}
}

public Action Spawn_Koth(int entity)
{
	DispatchSpawn(CreateEntityByName("tf_logic_arena"));
	return Plugin_Stop;  //Stop koth logic from being created
}

public void OnItemSpawned(int entity)
{
	SDKHook(entity, SDKHook_StartTouch, OnPickup);
	SDKHook(entity, SDKHook_Touch, OnPickup);
}

public Action OnPickup(int entity, int client)  //Thanks friagram!
{
	if(IsBoss(client))
	{
		char classname[32];
		GetEntityClassname(entity, classname, sizeof(classname));
		if(!StrContains(classname, "item_healthkit") && !(FF2Flags[client] & FF2FLAG_ALLOW_HEALTH_PICKUPS))
		{
			return Plugin_Handled;
		}
		else if((!StrContains(classname, "item_ammopack") || StrEqual(classname, "tf_ammo_pack")) && !(FF2Flags[client] & FF2FLAG_ALLOW_AMMO_PICKUPS))
		{
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public FF2RoundState CheckRoundState()
{
	switch(GameRules_GetRoundState())
	{
		case RoundState_Init, RoundState_Pregame:
		{
			return FF2RoundState_Loading;
		}
		case RoundState_StartGame, RoundState_Preround:
		{
			return FF2RoundState_Setup;
		}
		case RoundState_RoundRunning, RoundState_Stalemate:  //Oh Valve.
		{
			return FF2RoundState_RoundRunning;
		}
		default:
		{
			return FF2RoundState_RoundEnd;
		}
	}
}

void FindHealthBar()
{
	healthBar=TFMonsterResource.GetEntity(true);
}

public void HealthbarEnableChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(Enabled && cvarHealthBar.BoolValue && IsValidEntity(healthBar.Index))
	{
		UpdateHealthBar();
	}
	else if(!IsValidEntity(g_Monoculus) && IsValidEntity(healthBar.Index))
	{
		healthBar.BossHealthPercentageByte=0;
	}
}

void UpdateHealthBar(bool noHealState = false)
{
	if(!Enabled || !cvarHealthBar.BoolValue || IsValidEntity(g_Monoculus) || !IsValidEntity(healthBar.Index) || CheckRoundState()==FF2RoundState_Loading)
	{
		return;
	}

	int healthAmount, maxHealthAmount, bosses, healthPercent;
	static int recently;
	for(int boss; boss<=MaxClients; boss++)
	{
		if(IsValidClient(Boss[boss]) && IsPlayerAlive(Boss[boss]) && TF2_GetClientTeam(Boss[boss]) == BossTeam)
		{
			bosses++;
			healthAmount+=BossHealth[boss]-BossHealthMax[boss]*(BossLives[boss]-1);
			maxHealthAmount+=BossHealthMax[boss];
		}
	}

	if(bosses)
	{
		healthPercent=RoundToCeil(float(healthAmount)/float(maxHealthAmount)*float(HEALTHBAR_MAX));
		healthBar.BossHealthState=(!noHealState && recently < healthAmount) ? HealthState_Healing : HealthState_Default;

		if(healthPercent>HEALTHBAR_MAX)
		{
			healthPercent=HEALTHBAR_MAX;
		}
		else if(healthPercent<=0)
		{
			healthPercent=1;
		}
	}

	healthBar.BossHealthPercentageByte=healthPercent;
	recently=healthAmount;
}
