#define MAJOR_REVISION "2"
#define MINOR_REVISION "1"
#define STABLE_REVISION "8"
#define DEV_REVISION "alpha"
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

FF2DBSettingData ff2Database;
KeyValues kvWeaponMods;
KeyValues kvHudConfigs;

int ChangeLogLastTime;

int Boss[MAXPLAYERS+1];

methodmap FF2PlayerData < KeyValues {
	public FF2PlayerData(int client) {
		char authId[25], queryStr[256], dataFile[PLATFORM_MAX_PATH];
		GetClientAuthId(client, AuthId_SteamID64, authId, 25);
		FF2PlayerData playerData = view_as<FF2PlayerData>(new KeyValues("player_data", "authid", authId));

		if(ff2Database != null)	{
			Format(queryStr, sizeof(queryStr), "SELECT * FROM `ff2_player` WHERE `steam_id` = '%s'", authId);
			ff2Database.Query(ReadDataResult, queryStr, client);
		}
		else {
			BuildPath(Path_SM, dataFile, sizeof(dataFile), "data/ff2_player_data/%s.txt", authId);
			playerData.ImportFromFile(dataFile);
		}

		return playerData;
	}

	// SQL 서버나 데이터 파일에 모든 데이터를 저장
	public native void Update();
}

methodmap FF2HudData < KeyValues {
	public FF2HudData(int client) {
		char authId[25], queryStr[256], dataFile[PLATFORM_MAX_PATH];
		GetClientAuthId(client, AuthId_SteamID64, authId, 25);
		BuildPath(Path_SM, dataFile, sizeof(dataFile), "data/ff2_hud_data/%s.txt", authId);
		FF2HudData playerData = view_as<FF2HudData>(new KeyValues("player_data", "authid", authId));

		if(ff2Database == null)
			if(FileExists(dataFile))
				playerData.ImportFromFile(dataFile);

		if(ff2Database != null)	{
			Format(queryStr, sizeof(queryStr), "SELECT * FROM `ff2_player_hud_setting` WHERE `steam_id` = '%s'", authId);
			ff2Database.Query(ReadHudDataResult, queryStr, client);
		}

		return playerData;
	}

	// NOTE: 값을 수정하려면 update로 true로 바꿔야 해당 키에 'need_update' 서브 키가 생김.
	public native void GoToHudData(const char[] hudId, bool update = false);

	// SQL 서버나 데이터 파일에 모든 데이터를 저장
	public native void Update();
}

FF2PlayerData LoadedPlayerData[MAXPLAYERS+1];
FF2HudData LoadedHudData[MAXPLAYERS+1];

enum
{
	Data_SteamId = 0,
	Data_ChangelogLastViewTime,
	Data_SoundMuteFlags,
	Data_ClassInfoView,
	Data_LastSavedTime,

    DataCount_Max
};

enum
{
	HudData_SteamId = 0,
	HudData_HudId,
	HudData_Value,
	HudData_LastSavedTime,

    HudDataCount_Max
};

static const char g_QueryColumn[][] = {
	"steam_id",
	"changelog_last_view_time",
	"sound_mute_flag",
	"class_info_view",
	"last_saved_time"
};

static const char g_HudQueryColumn[][] = {
	"steam_id",
	"hud_id",
	"setting_value",
	"last_saved_time"
};

void Data_Native_Init()
{
	CreateNative("FF2PlayerData.Update", Native_FF2PlayerData_Update);

	CreateNative("FF2HudData.GoToHudData", Native_FF2HudData_GoToHudData);
	CreateNative("FF2HudData.Update", Native_FF2HudData_Update);
}

public void ReadDataResult(Database db, DBResultSet results, const char[] error, int client)
{
	char temp[120];

	for(int loop = 0; loop < results.RowCount; loop++)
	{
		if(!results.FetchRow()) {
			if(results.MoreRows) {
				loop--;
				continue;
			}
			break;
		}

		LoadedPlayerData[client].Rewind();

		// Initializing PlayerData
		results.FetchString(Data_ChangelogLastViewTime, temp, 120);
		LoadedPlayerData[client].SetString("changelog_last_view_time", temp);

		FormatTime(temp, sizeof(temp), "%Y-%m-%d %H:%M:%S");
		LoadedPlayerData[client].SetString("last_saved_time", temp);
		LoadedPlayerData[client].SetNum("sound_mute_flag", results.FetchInt(Data_SoundMuteFlags));
		LoadedPlayerData[client].SetNum("class_info_view", results.FetchInt(Data_ClassInfoView));
	}
}

public void ReadHudDataResult(Database db, DBResultSet results, const char[] error, int client)
{
	char temp[120];

	for(int loop = 0; loop < results.RowCount; loop++)
	{
		if(!results.FetchRow()) {
			if(results.MoreRows) {
				loop--;
				continue;
			}
			break;
		}

		LoadedHudData[client].Rewind();
		kvHudConfigs.Rewind();
		results.FetchString(HudData_HudId, temp, 120);

		LoadedHudData[client].JumpToKey(temp, true);

		// Initializing PlayerData
		FormatTime(temp, sizeof(temp), "%Y-%m-%d %H:%M:%S");
		LoadedHudData[client].SetString("last_saved_time", temp);
		LoadedHudData[client].SetNum("setting_value", results.FetchInt(HudData_Value));
	}
}

public int Native_FF2PlayerData_Update(Handle plugin, int numParams)
{
	FF2PlayerData playerData = GetNativeCell(1);
	char queryStr[512], authId[25], temp[120], dataFile[PLATFORM_MAX_PATH];

	playerData.Rewind();
	playerData.GetString("authid", authId, sizeof(authId));

	if(ff2Database != null)
	{
		Transaction transaction = new Transaction();
		for(int loop = Data_ChangelogLastViewTime; loop < DataCount_Max; loop++)
		{
			playerData.GetString(g_QueryColumn[loop], temp, sizeof(temp), "");

			if(temp[0] == '\0') continue;

			Format(queryStr, sizeof(queryStr),
			"INSERT INTO `ff2_player` (`steam_id`, `%s`) VALUES ('%s', '%s') ON DUPLICATE KEY UPDATE `steam_id` = '%s', `%s` = '%s'",
			g_QueryColumn[loop], authId, temp,
			authId, g_QueryColumn[loop], temp);

			transaction.AddQuery(queryStr);
		}
		ff2Database.Execute(transaction, _, OnTransactionError);
	}
	else
	{
		BuildPath(Path_SM, dataFile, sizeof(dataFile), "data/ff2_player_data/%s.txt", authId);
		playerData.ExportToFile(dataFile);
	}
}

public int Native_FF2HudData_GoToHudData(Handle plugin, int numParams)
{
	FF2HudData playerData = GetNativeCell(1);

	char hudId[80], timeStr[64];
	bool needUpdate = GetNativeCell(3);

	playerData.Rewind();
	GetNativeString(2, hudId, sizeof(hudId));

	if(playerData.JumpToKey(hudId, needUpdate) && needUpdate)
	{
		FormatTime(timeStr, sizeof(timeStr), "%Y-%m-%d %H:%M:%S");
		playerData.SetString("last_saved_time", timeStr);

		playerData.SetNum("need_update", 1);
	}
	return;
}

public int Native_FF2HudData_Update(Handle plugin, int numParams)
{
	FF2HudData playerData = GetNativeCell(1);
	char hudId[80], queryStr[512], authId[25], temp[120], dataFile[PLATFORM_MAX_PATH];
	playerData.Rewind();
	playerData.GetString("authid", authId, sizeof(authId));

	if(ff2Database == null)
	{
		BuildPath(Path_SM, dataFile, sizeof(dataFile), "data/ff2_hud_data/%s.txt", authId);
		playerData.ExportToFile(dataFile);
		return;
	}

	Transaction transaction = new Transaction();
	if(playerData.GotoFirstSubKey())
	{
		do
		{
			playerData.GetSectionName(hudId, sizeof(hudId));

			if(playerData.GetNum("need_update", 0) > 0)
			{
				for(int loop = HudData_Value; loop < HudDataCount_Max; loop++)
				{
					playerData.GetString(g_HudQueryColumn[loop], temp, sizeof(temp), "");

					if(temp[0] == '\0') continue;

					Format(queryStr, sizeof(queryStr),
					"INSERT INTO `ff2_player_hud_setting` (`steam_id`, `hud_id`, `%s`) VALUES ('%s', '%s', '%s') ON DUPLICATE KEY UPDATE `steam_id` = '%s', `hud_id` = '%s', `%s` = '%s'",
					g_HudQueryColumn[loop], authId, hudId, temp,
					authId, hudId, g_HudQueryColumn[loop], temp);

					transaction.AddQuery(queryStr);
				}
				playerData.DeleteKey("need_update");
			}
		}
		while(playerData.GotoNextKey());
	}

	ff2Database.Execute(transaction, _, OnTransactionError);
}

public void OnTransactionError(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError("Something is Error while saving data. \n%s", error);
}
