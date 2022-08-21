#define MAJOR_REVISION "2022"
#define MINOR_REVISION "4"
#define STABLE_REVISION "2"
// #define DEV_REVISION ""
#if !defined DEV_REVISION
	#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION  //2.0.0
#else
	#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION..."-"...DEV_REVISION  //semver.org
#endif

#define UPDATE_URL ""

#define MAXENTITIES 2048

#define HEALTHBAR_CLASS "monster_resource"
#define HEALTHBAR_PROPERTY "m_iBossHealthPercentageByte"
#define HEALTHBAR_MAX 255
#define MONOCULUS "eyeball_boss"

#define FF2_CONFIGS "configs/freak_fortress_2"
#define FF2_SETTINGS "data/freak_fortress_2"
#define BOSS_CONFIG "characters.cfg"
#define DOORS_CONFIG "doors.cfg"
#define WEAPONS_CONFIG "weapons.cfg"
#define MAPS_CONFIG	"maps.cfg"
#define HUDS_CONFIG "hud_setting.cfg"
#define CHANGELOG "changelog.txt"

#define KILLSTREAK_DAMAGE_INTERVAL 500

bool Enabled=true;
bool Enabled2=true;

TFTeam OtherTeam=TFTeam_Red;
TFTeam BossTeam=TFTeam_Blue;
int playing;
int healthcheckused;
int RedAlivePlayers;
int BlueAlivePlayers;
int StartingPlayers;
int RoundCount;
int character[MAXPLAYERS+1];

ArrayList bossesArray;
ArrayList bossesArrayOriginal; // FIXME: ULTRA HACKY HACK
ArrayList subpluginArray;

int FF2CharSet;
int validCharsets[64];
char FF2CharSetString[42];
bool isCharSetSelected;

KeyValues kvCharacterConfig;

Handle OnCheckRules;

KeyValues kvWeaponMods;
KeyValues kvHudConfigs;

int ChangeLogLastTime;

int Boss[MAXPLAYERS+1];

FF2HudQueue PlayerHudQueue[MAXPLAYERS+1] = {null, ...};

// TODO: REMOVE THIS
int shortname[MAXPLAYERS+1];

enum FF2RoundState
{
	FF2RoundState_Loading=-1,
	FF2RoundState_Setup,
	FF2RoundState_RoundRunning,
	FF2RoundState_RoundEnd,
}

enum FF2WeaponSpecials
{
	FF2WeaponSpecial_PreventDamage,
	FF2WeaponSpecial_RemoveOnDamage,
	FF2WeaponSpecial_JarateOnChargedHit,
}

enum FF2WeaponModType
{
	FF2WeaponMod_AddAttrib,
	FF2WeaponMod_RemoveAttrib,
	FF2WeaponMod_Replace,
	FF2WeaponMod_OnHit,
	FF2WeaponMod_OnTakeDamage,
}

/*char WeaponSpecials[][]=
{
	"drop health pack on kill",
	"glow on scoped hit",
	"prevent damage",
	"remove on damage",
	"drain boost when full"
};*/

enum Operators
{
	Operator_None=0,
	Operator_Add,
	Operator_Subtract,
	Operator_Multiply,
	Operator_Divide,
	Operator_Exponent,
};

enum
{
	SkillName_Rage = 0,
	SkillName_200Rage,
	SkillName_LostLife,

	SkillName_MaxCounts
};


Handle PreAbility;
Handle OnAbility;
Handle OnTriggerHurt;
Handle OnBossSelected;
Handle OnAddQueuePoints;
Handle OnLoadCharacterSet;
Handle OnLoseLife;
Handle OnAlivePlayersChanged;
Handle OnParseUnknownVariable;

// ff2_modules/general.inc
Handle OnWaveStarted;
Handle OnPlayBoss;
Handle OnSpecialAttack;
Handle OnSpecialAttack_Post;
