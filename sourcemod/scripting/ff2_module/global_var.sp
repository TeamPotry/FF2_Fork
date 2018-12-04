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

int ChangeLogLastTime;

int Boss[MAXPLAYERS+1];

enum DateTimeCheck
{
    Check_None = -1,
	Check_Year,
	Check_Month,
	Check_Day,
	Check_Hour,
	Check_Minute,
	Check_Second,

	Check_MaxCount
};

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
FF2PlayerData LoadedPlayerData[MAXPLAYERS+1];

enum
{
	Data_SteamId = 0,
	Data_ChangelogLastViewTime,
	Data_SoundMuteFlags,
	Data_ClassInfoView,
	Data_LastSavedTime,

    DataCount_Max
};

static const char g_QueryColumn[][] = {
	"steam_id",
	"changelog_last_view_time",
	"sound_mute_flag",
	"class_info_view",
	"last_saved_time"
};

void Data_Native_Init()
{
	CreateNative("FF2PlayerData.Update", Native_FF2PlayerData_Update);
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

public void OnTransactionError(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError("Something is Error while saving data. \n%s", error);
}
