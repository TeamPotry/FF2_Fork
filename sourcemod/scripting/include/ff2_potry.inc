#if defined _FF2_POTRY_included
 #endinput
#endif
#define _FF2_POTRY_included



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

}
#endif
