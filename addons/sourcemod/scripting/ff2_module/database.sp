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

#define FF2DATA_STEAMID_NAME		"private_steamid"

enum
{
	PlayerData_SteamID = 0,
	PlayerData_SettingID,
	PlayerData_Value,
	PlayerData_LastSavedTime
};

enum
{
	PlayerDataType_Setting = 0,
	PlayerDataType_HUD,
	PlayerDataType_Music
};

static const char g_strIDName[][] = {
	"setting_id",
	"hud_id",
	"music_id"
};

static const char g_strTableName[][] = {
	FF2_DB_PLAYERDATA_TABLENAME,
	FF2_DB_PLAYER_HUDDATA_TABLENAME,
	FF2_DB_PLAYER_MUSICDATA_TABLENAME
};

methodmap FF2PlayerData < StringMap {	
	// constructor: LoadPlayerData(int client)
	public void UpdateData() {
		
	}
}

FF2PlayerData LoadPlayerData(int client, int type = 0)
{
	FF2PlayerData data = view_as<FF2PlayerData>(new StringMap());

	char authId[32];
	GetClientAuthId(client, AuthId_SteamID64, authId, sizeof(authId));
	data.SetString(FF2DATA_STEAMID_NAME, authId, true);

	return data;
}

Database g_hFF2DB;
FF2PlayerData g_hPlayerSettingData[MAXPLAYERS+1];
FF2PlayerData g_hPlayerHUDData[MAXPLAYERS+1];
FF2PlayerData g_hPlayerMusicData[MAXPLAYERS+1];

void DB_Init()
{
	if(g_hFF2DB != null)
		delete g_hFF2DB;
/*
	for(int client = 1; client <= MaxClients; client++)
	{
		PlayerData_Kill(client);
	}
*/
	Database.Connect(DB_Connected, FF2DATABASE_CONFIG_NAME);
}

public void DB_Connected(Database db, const char[] error, any data)
{
	if(db == null)
	{
		SetFailState("[FF2] DB Connection failed! error: %s", error);
		return;
	}
	
	g_hFF2DB = db;
}

void DB_LoadAuthId(char[] authId)
{
	
}

void PlayerData_Init(int client)
{
	g_hPlayerSettingData[client] = LoadPlayerData(client, PlayerDataType_Setting);
	g_hPlayerHUDData[client] = LoadPlayerData(client, PlayerDataType_HUD);
	g_hPlayerMusicData[client] = LoadPlayerData(client, PlayerDataType_Music);
	
}

void PlayerData_Kill(int client)
{
	if(g_hPlayerSettingData[client] != null)
	{
		delete g_hPlayerSettingData[client];
		g_hPlayerSettingData[client] = null;
	}

	if(g_hPlayerHUDData[client] != null)
	{
		delete g_hPlayerHUDData[client];
		g_hPlayerHUDData[client] = null;
	}

	if(g_hPlayerMusicData[client] != null)
	{
		delete g_hPlayerMusicData[client];
		g_hPlayerMusicData[client] = null;
	}
}
