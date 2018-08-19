#if defined _FF2_POTRY_included
 #endinput
#endif
#define _FF2_POTRY_included

/**
 * Gets assist by this client
 *
 * @param client    Client's index
 * @return          Damage dealt
 */
native int FF2_GetClientAssist(int client);

/**
 * Sets assist by this client
 *
 * @param client 	Client's index
 * @param damage	New damage dealt
 * @noreturn
 */
native void FF2_SetClientAssist(int client, int assist);

/**
 * Gets a Character's KV handle
 *
 * @param characterIndex    character's index (config)
 * @return                  Character's KV handle or null if character index is invalid
 */
native KeyValues FF2_GetCharacterKV(int characterIndex);

public SharedPlugin __pl_FF2_POTRY=
{
	name="ff2_potry",
	file="freak_fortress_2.smx",
	#if defined REQUIRE_PLUGIN
		required=1,
	#else
		required=0,
	#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_FF2_POTRY_SetNTVOptional()
{
    MarkNativeAsOptional("FF2_GetClientAssist");
    MarkNativeAsOptional("FF2_SetClientAssist");
    MarkNativeAsOptional("FF2_GetCharacterKV");
}
#endif
