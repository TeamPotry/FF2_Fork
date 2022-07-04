#define FF2DATABASE_CONFIG_NAME     "ff2"

#define FF2_DB_PLAYERDATA_TABLENAME "ff2_player_setting"
#define FF2_DB_PLAYER_HUDDATA_TABLENAME "ff2_player_hud_setting"
#define FF2_DB_PLAYER_MUSICDATA_TABLENAME "ff2_player_music_setting"

static const char g_QueryColumn[][] = {
	"steam_id",
	"setting_id",
	"value",
	"last_saved_time"
};

static const DBSDataTypes g_iQueryColumnDataType[] = {
	DBSData_String,
	DBSData_String,
	DBSData_String,
	DBSData_String
};

static const char g_HudQueryColumn[][] = {
	"steam_id",
	"hud_id",
	"setting_value",
	"last_saved_time"
};

static const DBSDataTypes g_iHudQueryColumnDataType[] = {
	DBSData_String,
	DBSData_String,
	DBSData_Int,
	DBSData_String
};

static const char g_MusicQueryColumn[][] = {
	"steam_id",
	"music_id",
	"setting_value",
	"last_saved_time"
};

static const DBSDataTypes g_iMusicQueryColumnDataType[] = {
	DBSData_String,
	DBSData_String,
	DBSData_Int,
	DBSData_String
};

public void DBS_OnLoadData(DBSData data)
{
	KeyValues tabledata = DBSData.CreateTableData(FF2_DB_PLAYERDATA_TABLENAME);
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

	tabledata = DBSData.CreateTableData(FF2_DB_PLAYER_MUSICDATA_TABLENAME);
	for(int loop = 0; loop < sizeof(g_MusicQueryColumn); loop++)
	{
		DBSData.PushTableData(tabledata, g_MusicQueryColumn[loop], g_iMusicQueryColumnDataType[loop]);
	}
	data.Add(FF2DATABASE_CONFIG_NAME, tabledata);
	delete tabledata;
}
