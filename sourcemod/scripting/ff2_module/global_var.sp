#define MAJOR_REVISION "2"
#define MINOR_REVISION "3"
#define STABLE_REVISION "0"
#define DEV_REVISION "Write In Process"
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

FF2HudQueue PlayerHudQueue[MAXPLAYERS+1] = null;

static const char g_QueryColumn[][] = {
	"steam_id",
	"changelog_last_view_time",
	"sound_mute_flag",
	"class_info_view",
	"last_saved_time"
};

static const KvDataTypes g_iQueryColumnDataType[] = {
	KvData_String,
	KvData_String,
	KvData_Int,
	KvData_Int,
	KvData_String
};

static const char g_HudQueryColumn[][] = {
	"steam_id",
	"hud_id",
	"setting_value",
	"last_saved_time"
};

static const KvDataTypes g_iHudQueryColumnDataType[] = {
	KvData_String,
	KvData_String,
	KvData_Int,
	KvData_String
};

public void DBS_OnLoadData(DBSData data)
{
	KeyValues tabledata = DBSData.CreateTableData(FF2_DB_PLAYERDATA_TABLENAME, true);
	for(int loop = 0; loop < sizeof(g_QueryColumn); loop++)
	{
		DBSData.PushTableData(tabledata, g_QueryColumn[loop], g_iQueryColumnDataType[loop]);
	}
	data.Add(FF2DATABASE_CONFIG_NAME, tabledata);
	delete tabledata;

	tabledata = DBSData.CreateTableData(FF2_DB_PLAYER_HUDDATA_TABLENAME);
	for(int loop = 0; loop < sizeof(g_HudQueryColumn); loop++)
	{
		DBSData.PushTableData(tabledata, g_HudQueryColumn[loop], g_iHudQueryColumnDataType[loop]);
	}
	data.Add(FF2DATABASE_CONFIG_NAME, tabledata);
	delete tabledata;
}
