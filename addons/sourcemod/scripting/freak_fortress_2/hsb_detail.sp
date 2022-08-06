#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <ff2_modules/general>

public Plugin myinfo=
{
	name="Freak Fortress 2: HSB Detail",
	author="Nopied",
	description="",
	version="20220724",
};

#define HSB_EXPLODE "mvm/sentrybuster/mvm_sentrybuster_explode.wav"

#define THIS_PLUGIN_NAME "hsb_detail"

#define EXPLODE_ABILITY "explode"

float g_flPriviousRage[MAXPLAYERS+1];

public void OnPluginStart()
{
    FF2_RegisterSubplugin(THIS_PLUGIN_NAME);
}

public void OnMapStart()
{
	PrecacheSound(HSB_EXPLODE, true);
}

public void FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status)
{
	if(!StrEqual(pluginName, THIS_PLUGIN_NAME, false))
	{
		return;
	}

	if(!strcmp(EXPLODE_ABILITY, abilityName))
	{
		PrepareExplode(boss);	
	}
}

// Copied from shadow's plugin
// Only for RAGE.
void PrepareExplode(int boss)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));
	g_flPriviousRage[client] = FF2_GetBossCharge(boss, 0);

	CreateTimer(0.1, SentryBustPrepare, boss, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(2.1, SentryBusting, boss, TIMER_FLAG_NO_MAPCHANGE);
}

public Action SentryBustPrepare(Handle timer, any boss)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));

	if(!TF2_IsPlayerInCondition(client, TFCond_Taunting))
		FakeClientCommand(client, "taunt");
	SetEntityMoveType(client, MOVETYPE_NONE);

	TF2_AddCondition(client, TFCond_Ubercharged, 2.0);
	SetEntProp(client, Prop_Data, "m_takedamage", 0);
}

public Action SentryBusting(Handle timer, any boss)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));

	if(!IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Continue;

	float clientPos[3];
	GetClientAbsOrigin(client, clientPos);

	float range = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, EXPLODE_ABILITY, "explosion range", 700.0),
			power = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, EXPLODE_ABILITY, "explosion power", 600.0),
			multiplier = g_flPriviousRage[client] / 100.0;

	range *= multiplier;
	power *= multiplier;

	int explosion = CreateEntityByName("env_explosion");
	if (explosion)
	{
		DispatchKeyValueFloat(explosion, "DamageForce", power * multiplier);

		// PrintToChatAll("rage: %.1f,multiplier: %.1f, m_iMagnitude: %i, m_iRadiusOverride: %i", 
		// 	FF2_GetBossCharge(boss, 0), multiplier, RoundFloat(power * 0.4), RoundFloat(power));

		SetEntProp(explosion, Prop_Data, "m_iMagnitude", RoundFloat(power * 0.4), 4);
		SetEntProp(explosion, Prop_Data, "m_iRadiusOverride", RoundFloat(power), 4);
		SetEntPropEnt(explosion, Prop_Data, "m_hOwnerEntity", client);

		DispatchSpawn(explosion);
		TeleportEntity(explosion, clientPos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(explosion, "Explode", -1, -1, 0);
		AcceptEntityInput(explosion, "kill");
	}

	SetEntProp(client, Prop_Data, "m_takedamage", 2);
	EmitSoundToAll(HSB_EXPLODE, client);

	// AttachParticle(client, "fluidSmokeExpl_ring_mvm");
	AttachParticle(client, "cinefx_goldrush");

	if(TF2_IsPlayerInCondition(client, TFCond_Taunting))
		TF2_RemoveCondition(client,TFCond_Taunting);
	SetEntityMoveType(client, MOVETYPE_WALK);

	return Plugin_Continue;
}

stock bool AttachParticle(int Ent, char[] particleType, bool cache=false) // from L4D Achievement Trophy
{
	int particle = CreateEntityByName("info_particle_system");
	if (!IsValidEdict(particle)) return false;
	char tName[128];
	float f_pos[3];
	if (cache) f_pos[2] -= 3000;
	else
	{
		GetEntPropVector(Ent, Prop_Send, "m_vecOrigin", f_pos);
		f_pos[2] += 60;
	}
	TeleportEntity(particle, f_pos, NULL_VECTOR, NULL_VECTOR);
	Format(tName, sizeof(tName), "target%i", Ent);
	DispatchKeyValue(Ent, "targetname", tName);
	DispatchKeyValue(particle, "effect_name", particleType);
	DispatchSpawn(particle);
	SetVariantString(tName);
	AcceptEntityInput(particle, "SetParent", particle, particle, 0);
	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");

	char temp[64];
	Format(temp, sizeof(temp), "OnUser1 !self:kill::10:1");
	SetVariantString(temp);

	AcceptEntityInput(particle, "AddOutput");
	AcceptEntityInput(particle, "FireUser1");

	return true;
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool& result)
{
    int boss = FF2_GetBossIndex(client);
    if(boss != -1 && FF2_HasAbility(boss, THIS_PLUGIN_NAME, "infinite detonations"))
    {
        if(GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 307)
        {
			char classname[32];
			GetEntityClassname(weapon, classname, 32);
			if(StrEqual(classname, "tf_weapon_stickbomb"))
			{
				SetEntProp(weapon, Prop_Send, "m_bBroken", 0);
				SetEntProp(weapon, Prop_Send, "m_iDetonated", 0);
			}
        }
    }

    return Plugin_Continue;
}
