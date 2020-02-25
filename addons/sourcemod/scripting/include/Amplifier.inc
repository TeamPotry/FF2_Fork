/**
 * vim: set ai et ts=4 sw=4 syntax=sourcepawn :
 * File: Amplifier.inc
 * Description: Native Interface to Amplifier
 * Author(s): -=|JFH|=-Naris (Murray Wilson)
 */

#if defined _Amplifier_included
 #endinput
#endif
#define _Amplifier_included

/**
 * Assume control of the Amplifier plugin
 *
 * @param plugin_only 	Set to 1 to assume complete control of Amplifier.
 * @return		    	none
 */
native ControlAmplifier(bool:plugin_only=true);

/**
 * Set the sate of the Amplifier flag
 *
 * @param index 	Client index
 * @param enable    Set true so player builds an Amplifier instead of a dispenser
 * @param distance  Range of the amplifier (-1.0=use convar)
 * @param condition Condition to set players within range of the amplifier (-1=use convar)
 * @param percent   Percent (0-100) chance of applying the condition (-1=use convar)
 * @return		    none
 */
native SetAmplifier(client, bool:enable=true, Float:distance=-1.0, TFCond:condition=TFCond:-1, percent=-1);

/**
 * Count how many Amplifiers the client has constructed.
 *
 * @param index 	Client index
 * @return			The number of Amplifiers the client has constructed.
 */
native HasAmplifier(client);

/**
 * Converts a dispenser into an Amplifier
 *
 * @param entity    Dispenser Entity to convert.
 * @param client 	Client index of the owner.
 * @param distance  Range of the amplifier (-1.0=use convar)
 * @param condition Condition to set players within range of the amplifier (-1=use convar)
 * @param percent   Percent (0-100) chance of applying the condition (-1=use convar)
 * @return			none
 */
native ConvertToAmplifier(entity, client, Float:distance=-1.0, TFCond:condition=TFCond:-1, percent=-1);

/**
 * Gets called when the amplifier applys a condition to someone
 *
 * @param builder:  The index of the client that built the amplifier.
 * @param client:   The index of the player that is being afected.
 * @param condition The condition beign applied to the client.
 * @return		    Plugin_Stop will prevent the client from being affected.
 */
forward Action:OnAmplify(builder,client,TFCond:condition);

/* DO NOT EDIT BELOW THIS LINE */

public SharedPlugin:__pl_Amplifier = 
{
	name = "Amplifier",
	file = "Amplifier.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_Amplifier_SetNTVOptional()
{
	MarkNativeAsOptional("ControlAmplifier");
	MarkNativeAsOptional("SetAmplifier");
	MarkNativeAsOptional("HasAmplifier");
	MarkNativeAsOptional("ConvertToAmplifier");
}
#endif

