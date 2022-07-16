#if defined _ff2_db_included
 #endinput
#endif
#define _ff2_db_included

#undef REQUIRE_PLUGIN
#include <db_simple>
#define REQUIRE_PLUGIN

/**
 * Get/Set Player's setting data.
 *
 * @param client            client's index
 * @param settingId         setting ID
 * @param value             Get/Set data
 * @param type              KvData_Int, KvData_Float is supported, otherwise error occured
 *
 */
native any FF2_GetSettingData(int client, const char[] settingId, DBSDataTypes type);
native void FF2_GetSettingStringData(int client, const char[] settingId, char[] value, DBSDataTypes buffer);

native void FF2_SetSettingData(int client, const char[] settingId, any value, DBSDataTypes type);
native void FF2_SetSettingStringData(int client, const char[] settingId, char[] value);

public SharedPlugin __pl_ff2_db=
{
	name="ff2_db",
	file="freak_fortress_2.smx",
	#if defined REQUIRE_PLUGIN
		required=1,
	#else
		required=0,
	#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_ff2_db_SetNTVOptional()
{
    MarkNativeAsOptional("FF2_GetSettingData");
    MarkNativeAsOptional("FF2_GetSettingStringData");
    MarkNativeAsOptional("FF2_SetSettingData");
    MarkNativeAsOptional("FF2_SetSettingStringData");
}
#endif