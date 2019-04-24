#define FF2DATABASE_CONFIG_NAME "ff2"

methodmap FF2DBSettingData < Database {
    public FF2DBSettingData()
    {
        Database database;
        DBDriver driver;
        char driverString[10];
        char errorMessage[64];

        database = SQL_Connect(FF2DATABASE_CONFIG_NAME, true, errorMessage, sizeof(errorMessage));
        if(database == null)
        {
            SetFailState("Can't connect to DB! Error: %s", errorMessage);
        }

        driver = database.Driver;
        driver.GetIdentifier(driverString, sizeof(driverString));

        if(!StrEqual("mysql", driverString))
        {
            SetFailState("This plugin is only allowed to use mysql!");
        }

        database.SetCharset("utf8");

        return view_as<FF2DBSettingData>(database);
    }

    public native void InitializePlayerData(const char[] authid);

    public native int GetValue(const char[] authid, const char[] settingid, char[] value = "", int buffer = 0);
    public native void SetValue(const char[] authid, const char[] settingid, const char[] value);

    // public native HudSettingValue GetHudSeting(const char[] authid, const char[] settingid);
    // public native void SetHudSeting(const char[] authid, const char[] hudId, HudSettingValue value);

    public native int GetSavedTime(const char[] authid);
}

public void QueryErrorCheck(Database db, DBResultSet results, const char[] error, any data)
{
    if(results == null || error[0] != '\0')
    {
        LogError("Ahh.. Something is wrong in QueryErrorCheck. check your DB. ERROR: %s", error);
    }
}

void DB_Native_Init()
{
    CreateNative("FF2DBSettingData.InitializePlayerData", Native_FF2DBSettingData_InitializePlayerData);

    CreateNative("FF2DBSettingData.GetValue", Native_FF2DBSettingData_GetValue);
    CreateNative("FF2DBSettingData.SetValue", Native_FF2DBSettingData_SetValue);
    CreateNative("FF2DBSettingData.GetSavedTime", Native_FF2DBSettingData_GetSavedTime);

    // CreateNative("FF2DBSettingData.GetHudSeting", Native_FF2DBSettingData_GetHudSeting);
    // CreateNative("FF2DBSettingData.SetHudSeting", Native_FF2DBSettingData_SetHudSeting);
}

public int Native_FF2DBSettingData_InitializePlayerData(Handle plugin, int numParams)
{
    FF2DBSettingData thisDB = GetNativeCell(1);
    char authId[24], queryStr[256];
    GetNativeString(2, authId, 24);

    if(thisDB.GetValue(authId, "steam_id", queryStr, 25) > 0)
        return;

    Format(queryStr, sizeof(queryStr), "INSERT INTO `ff2_player`(`steam_id`) VALUES('%s')", authId);
    thisDB.Query(QueryErrorCheck, queryStr);
}

public int Native_FF2DBSettingData_GetValue(Handle plugin, int numParams)
{
    FF2DBSettingData thisDB = GetNativeCell(1);

    char authId[24], settingId[256], queryStr[256], resultStr[64];
    int buffer = GetNativeCell(5);
    GetNativeString(2, authId, 24);
    GetNativeString(3, settingId, 128);
    thisDB.Escape(settingId, settingId, 256);

    Format(queryStr, sizeof(queryStr), "SELECT `%s` FROM `ff2_player` WHERE `steam_id` = '%s'", settingId, authId);

    DBResultSet query = SQL_Query(thisDB, queryStr);
    if(query == null) return -1;
    if(!query.HasResults || !query.FetchRow())
    {
        delete query;
        return -1;
    }

    int result;
    if(buffer > 0)
    {
        query.FetchString(0, resultStr, buffer),
        SetNativeString(4, resultStr, buffer);

        result = 1;
    }
    else
    {
        result = query.FetchInt(0);
    }

    delete query;
    return result;
}

public int Native_FF2DBSettingData_SetValue(Handle plugin, int numParams)
{
    FF2DBSettingData thisDB = GetNativeCell(1);

    char authId[24], settingId[256], queryStr[256], timeStr[64], valueString[64];
    GetNativeString(2, authId, 24);
    GetNativeString(3, settingId, 128);
    GetNativeString(4, valueString, 64);

    thisDB.Escape(settingId, settingId, 256);
    FormatTime(timeStr, sizeof(timeStr), "%Y-%m-%d %H:%M:%S");

    Format(queryStr, sizeof(queryStr), "UPDATE `ff2_player` SET `%s` = '%s', `last_saved_time` = '%s' WHERE `steam_id` = '%s'", settingId, valueString, timeStr, authId);
    thisDB.Query(QueryErrorCheck, queryStr);
}

public int Native_FF2DBSettingData_GetSavedTime(Handle plugin, int numParams)
{
    FF2DBSettingData thisDB = GetNativeCell(1);

    char authId[24], queryStr[256];
    GetNativeString(2, authId, 24);

    Format(queryStr, sizeof(queryStr), "SELECT UNIX_TIMESTAMP(`changelog_last_view_time`) FROM `ff2_player` WHERE `steam_id` = '%s'", authId);

    DBResultSet query = SQL_Query(thisDB, queryStr);
    if(query == null) return -1;
    if(!query.HasResults || !query.FetchRow())
    {
        delete query;
        return -1;
    }

    int result = query.FetchInt(0);

    delete query;
    return result;
}
/*
public int Native_FF2DBSettingData_GetHudSeting(Handle plugin, int numParams)
{
    FF2DBSettingData thisDB = GetNativeCell(1);

    char authId[24], hudId[256], queryStr[256];
    GetNativeString(2, authId, 24);
    GetNativeString(3, hudId, 128);
    thisDB.Escape(hudId, hudId, 256);

    Format(queryStr, sizeof(queryStr), "SELECT `setting_value` FROM `ff2_player_hud_setting` WHERE `steam_id` = '%s' AND `hud_id` = '%s'", authId, hudId);

    DBResultSet query = SQL_Query(thisDB, queryStr);
    if(query == null) return -1;
    else if(!query.HasResults || !query.FetchRow())
    {
        delete query;
        return -1;
    }

    int result = query.FetchInt(0);

    delete query;
    return result;
}

public int Native_FF2DBSettingData_SetHudSeting(Handle plugin, int numParams)
{
    FF2DBSettingData thisDB = GetNativeCell(1);

    char authId[24], hudId[256], queryStr[512], valueString[4], timeStr[64];
    int value = GetNativeCell(4);
    GetNativeString(2, authId, 24);
    GetNativeString(3, hudId, 128);
    IntToString(value, valueString, sizeof(valueString));

    thisDB.Escape(hudId, hudId, 256);
    FormatTime(timeStr, sizeof(timeStr), "%Y-%m-%d %H:%M:%S");
    Format(queryStr, sizeof(queryStr),
    "INSERT INTO `ff2_player_hud_setting` (`steam_id`, `hud_id`, `setting_value`) VALUES ('%s', '%s', '%s') ON DUPLICATE KEY UPDATE `steam_id` = '%s',  `hud_id` = '%s', `setting_value` = '%s', `last_saved_time` = '%s'",
    authId, hudId, valueString, authId, hudId, valueString, timeStr);

    SQL_FastQuery(thisDB, queryStr, strlen(queryStr)+1);
}
*/
