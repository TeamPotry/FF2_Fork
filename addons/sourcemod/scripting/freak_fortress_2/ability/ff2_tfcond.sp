#include <sourcemod>
#include <tf2_stocks>
#include <sdkhooks>
#include <sdktools>
#include <sdktools_functions>
#include <freak_fortress_2>
#include <ff2_modules/general>

#define MAJOR_REVISION "1"
#define MINOR_REVISION "1"
#define PATCH_REVISION "1 (FORK)"

#define THIS_PLUGIN_NAME	"tfcond"

#if !defined PATCH_REVISION
	#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION
#else
	#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION..."."...PATCH_REVISION
#endif

bool bEnableSuperDuperJump[MAXPLAYERS+1];
bool HasTFCondTweak[MAXPLAYERS+1];
bool TFCond_TriggerAMS[MAXPLAYERS+1];
char TFCondTweakConditions[MAXPLAYERS+1][768];
char SpecialTFCondTweakConditions[MAXPLAYERS+1][768];
// Handle chargeHUD;

int buttonmode[MAXPLAYERS+1];
float dotCost[MAXPLAYERS+1], minCost[MAXPLAYERS+1], curRage[MAXPLAYERS+1];

public Plugin myinfo = {
    name = "Freak Fortress 2: TFConditions",
    author = "SHADoW NiNE TR3S",
    version = PLUGIN_VERSION,
};

public void OnPluginStart()
{
	HookEvent("arena_round_start", Event_ArenaRoundStart);
	HookEvent("arena_win_panel", Event_ArenaWinPanel);
	// chargeHUD=CreateHudSynchronizer();

	FF2_RegisterSubplugin(THIS_PLUGIN_NAME);
}

public void FF2_OnAbility(int boss, const char[] pluginName, const char[] abilityName, int slot, int status)
{
	int client=GetClientOfUserId(FF2_GetBossUserId(boss));
	if(!strcmp(abilityName, "rage_tfcondition"))
	{
		TFC_Invoke(client, slot);
	}
	if(!strcmp(abilityName, "charge_tfcondition"))
	{
		Charge_TFCondition(abilityName, boss, slot, status, client);
	}
}

public Action Event_ArenaRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return Plugin_Continue;

	PrepareAbilities();
	return Plugin_Continue;
}

public void PrepareAbilities()
{
	for(int client=1;client<=MaxClients;client++)
	{
		if(!IsValidClient(client))
			continue;
		TFCond_TriggerAMS[client]=false;
		HasTFCondTweak[client]=false;
		bEnableSuperDuperJump[client]=false;
	}

	int bossClient;
	for(int bossIdx=0;(bossClient=GetClientOfUserId(FF2_GetBossUserId(bossIdx)))>0;bossIdx++)
	{
		if(!IsValidClient(bossClient))
			continue;

		// AMS-exclusive version
		// char condName[96], condShort[96];
		/*
		for(int abilityNum=0; abilityNum<=9;abilityNum++)
		{
			Format(condName, sizeof(condName), "ams_tfcond_%i", abilityNum);
			if(FF2_HasAbility(bossIdx, THIS_PLUGIN_NAME, condName))
			{
				Format(condShort, sizeof(condShort), "TC%i", abilityNum);
				AMS_InitSubability(bossIdx, bossClient, THIS_PLUGIN_NAME, condName, condShort);
			}
		}

		// Legacy
		if(FF2_HasAbility(bossIdx, THIS_PLUGIN_NAME, "rage_tfcondition"))
		{
			if(AMS_IsSubabilityReady(bossIdx, THIS_PLUGIN_NAME, "rage_tfcondition"))
			{
				TFCond_TriggerAMS[bossClient] = true;
				AMS_InitSubability(bossIdx, bossClient, THIS_PLUGIN_NAME, "rage_tfcondition", "TFC");
			}
		}
		*/

		if(FF2_HasAbility(bossIdx, THIS_PLUGIN_NAME, "tfconditions"))
		{
			HasTFCondTweak[bossClient]=true;
			FF2_GetAbilityArgumentString(bossIdx, THIS_PLUGIN_NAME, "tfconditions", "round_start_boss_cond", TFCondTweakConditions[bossClient], sizeof(TFCondTweakConditions[])); // boss TFConds
			if(TFCondTweakConditions[bossClient][0]!='\0')
			{
				SetCondition(bossClient, TFCondTweakConditions[bossClient]);
			}
			for(int targetIdx;targetIdx<=MaxClients;targetIdx++)
			{
				if(!IsValidClient(targetIdx))
					continue;
				FF2_GetAbilityArgumentString(bossIdx, THIS_PLUGIN_NAME, "tfconditions", "round_start_player_cond", TFCondTweakConditions[targetIdx], sizeof(TFCondTweakConditions[])); // client TFConds
				if(TFCondTweakConditions[targetIdx][0]!='\0')
				{
					HasTFCondTweak[targetIdx]=true;
					SetCondition(targetIdx, TFCondTweakConditions[targetIdx]);
				}

			}
		}
		if(FF2_HasAbility(bossIdx, THIS_PLUGIN_NAME, "special_tfcondition"))
		{
			FF2_GetAbilityArgumentString(bossIdx, THIS_PLUGIN_NAME, "special_tfcondition", "cond", SpecialTFCondTweakConditions[bossClient], sizeof(SpecialTFCondTweakConditions[])); // boss TFConds
			minCost[bossClient]=FF2_GetAbilityArgumentFloat(bossIdx, THIS_PLUGIN_NAME, "special_tfcondition", "min_cost");
			dotCost[bossClient]=FF2_GetAbilityArgumentFloat(bossIdx, THIS_PLUGIN_NAME, "special_tfcondition", "rage_drain_rage");
			buttonmode[bossClient]=FF2_GetAbilityArgument(bossIdx, THIS_PLUGIN_NAME, "special_tfcondition", "buttonmode_tfcondition");
			SDKHook(bossClient, SDKHook_PreThink, PersistentTFCondition_PreThink);
		}
	}
}

public Action Event_ArenaWinPanel(Handle event, const char[] name, bool dontBroadcast)
{
	for(int client=1;client<=MaxClients;client++)
	{
		if(IsValidClient(client))
		{
			TFCond_TriggerAMS[client]=false;
			bEnableSuperDuperJump[client]=false;
			if(IsPlayerAlive(client) && HasTFCondTweak[client])
			{
				HasTFCondTweak[client]=false;
				if(TFCondTweakConditions[client][0]!='\0')
				{
					RemoveCondition(client, TFCondTweakConditions[client]);
				}
			}
		}
	}
	return Plugin_Continue;
}

public void PersistentTFCondition_PreThink(int client)
{
	if(FF2_GetRoundState()!=1 || !IsPlayerAlive(client) || !IsValidClient(client, false)) // Round ended or boss was defeated?
	{
		SDKUnhook(client, SDKHook_PreThink, PersistentTFCondition_PreThink);
		return;
	}

	int bossIdx=FF2_GetBossIndex(client);
	if(FF2_HasAbility(bossIdx, THIS_PLUGIN_NAME, "special_tfcondition"))
	{
		curRage[client]=FF2_GetBossCharge(bossIdx, 0);
		if(!buttonmode[client] && (GetClientButtons(client) & IN_ATTACK2) || buttonmode[client]==1 && (GetClientButtons(client) & IN_RELOAD) || buttonmode[client]==2 && (GetClientButtons(client) & IN_ATTACK3))
		{
			if(curRage[client]<=minCost[client]-1.0 && !IsPlayerInSpecificConditions(client, SpecialTFCondTweakConditions[client]) || curRage[client]<=0.44)
			{
				SetHudTextParams(-1.0, 0.5, 3.0, 255, 0, 0, 255);
				ShowHudText(client, -1, "Insufficient RAGE! You need a minimum of %i percent RAGE to use!", RoundFloat(minCost[client]));
				return;
			}

			FF2_SetBossCharge(bossIdx, 0, curRage[client]-dotCost[client]);
			SetPersistentCondition(client, SpecialTFCondTweakConditions[client]);
		}
	}
}


void Charge_TFCondition(const char[] ability_name, int boss, int slot, int action, int bClient)
{
	char VictimCond[768], BossCond[768];
	float charge = FF2_GetBossCharge(boss,slot), bCharge = FF2_GetBossCharge(boss,0);
	float rCost = FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, ability_name, "cost", 0.0, slot);
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));
	// int override=FF2_GetAbilityArgument(boss, THIS_PLUGIN_NAME, ability_name, 11);

	if(rCost && !bEnableSuperDuperJump[boss])
	{
		if(bCharge<rCost)
		{
			return;
		}
	}
	switch (action)
	{
		case 3:
		{
			if (bEnableSuperDuperJump[boss] && slot == 1)
			{
				float vel[3], rot[3];
				GetEntPropVector(bClient, Prop_Data, "m_vecVelocity", vel);
				GetClientEyeAngles(bClient, rot);
				vel[2]=750.0+500.0*charge/70+2000;
				vel[0]+=Cosine(DegToRad(rot[0]))*Cosine(DegToRad(rot[1]))*500;
				vel[1]+=Cosine(DegToRad(rot[0]))*Sine(DegToRad(rot[1]))*500;
				bEnableSuperDuperJump[boss] = false;
				TeleportEntity(bClient, NULL_VECTOR, NULL_VECTOR, vel);
			}
			else
			{
				if(charge<100)
				{
					ResetBossCharge(boss, slot);
					return;
				}
				if(rCost)
				{
					FF2_SetBossCharge(boss,0,bCharge-rCost);
				}

				// Conditions
				FF2_GetAbilityArgumentString(boss, THIS_PLUGIN_NAME, ability_name, "boss_conditions", BossCond, sizeof(BossCond), "", slot); // client TFConds
				FF2_GetAbilityArgumentString(boss, THIS_PLUGIN_NAME, ability_name, "player_conditions", VictimCond, sizeof(VictimCond), "", slot); // victim TFConds

				if(BossCond[0]!='\0')
				{
					SetCondition(bClient, BossCond);
				}

				if(VictimCond[0]!='\0')
				{
					float pos[3], pos2[3], dist;
					float dist2=FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, ability_name, "distance", 600.0, slot);
					GetEntPropVector(bClient, Prop_Send, "m_vecOrigin", pos);

					for(int target=1; target<=MaxClients; target++)
					{
						if(IsValidClient(target) && IsPlayerAlive(target) && TF2_GetClientTeam(target)!= TF2_GetClientTeam(client))
						{
							GetEntPropVector(target, Prop_Send, "m_vecOrigin", pos2);
							dist=GetVectorDistance(pos,pos2);
							if (dist<dist2 && TF2_GetClientTeam(target)!=TF2_GetClientTeam(client))
							{
								SetCondition(target, VictimCond);
							}
						}
					}
				}


				float position[3];
				char sound[PLATFORM_MAX_PATH];
				if(FF2_FindSound("tfcond", sound, PLATFORM_MAX_PATH, boss, true, slot))
				{
					EmitSoundToAll(sound, bClient, _, _, _, _, _, boss, position);
					EmitSoundToAll(sound, bClient, _, _, _, _, _, boss, position);

					for(int target=1; target<=MaxClients; target++)
					{
						if(IsClientInGame(target) && target!=boss)
						{
							EmitSoundToClient(target, sound, bClient, _, _, _, _, _, boss, position);
							EmitSoundToClient(target, sound, bClient, _, _, _, _, _, boss, position);
						}
					}
				}
			}
		}
	}
}

public Action FF2_OnTriggerHurt(int boss, int triggerhurt, float &damage)
{
	if(!bEnableSuperDuperJump[boss])
	{
		bEnableSuperDuperJump[boss]=true;
		if (FF2_GetBossCharge(boss,1)<0)
			FF2_SetBossCharge(boss,1,0.0);
	}
	return Plugin_Continue;
}

stock bool IsBoss(int client)
{
	return FF2_GetBossIndex(client)!=-1;
}

stock bool IsValidClient(int client, bool isPlayerAlive=false)
{
	if (client <= 0 || client > MaxClients) return false;
	if(isPlayerAlive) return IsClientInGame(client) && IsPlayerAlive(client);
	return IsClientInGame(client);
}

stock void SetCondition(int client, char[] cond)
{
	char conds[32][32];
	int count = ExplodeString(cond, " ; ", conds, sizeof(conds), sizeof(conds));
	if (count > 0)
	{
		for (new i = 0; i < count; i+=2)
		{
			if(!TF2_IsPlayerInCondition(client, TFCond:StringToInt(conds[i])))
			{
				TF2_AddCondition(client, TFCond:StringToInt(conds[i]), StringToFloat(conds[i+1]));
			}
		}
	}
}

stock void SetPersistentCondition(int client, char[] cond)
{
	char conds[32][32];
	int count = ExplodeString(cond, " ; ", conds, sizeof(conds), sizeof(conds));
	if (count > 0)
	{
		for (int i = 0; i < count; i++)
		{
			if(view_as<TFCond>(StringToInt(conds[i]))==TFCond_Charging)
			{
				SetEntPropFloat(client, Prop_Send, "m_flChargeMeter", 100.0);
			}
			TF2_AddCondition(client, view_as<TFCond>(StringToInt(conds[i])), 0.2);
		}
	}
}

stock bool IsPlayerInSpecificConditions(int client, char[] cond)
{
	char conds[32][32];
	int count = ExplodeString(cond, " ; ", conds, sizeof(conds), sizeof(conds));
	if (count > 0)
	{
		for (int i = 0; i < count; i++)
		{
			return TF2_IsPlayerInCondition(client, view_as<TFCond>(StringToInt(conds[i])));
		}
	}
	return false;
}

stock void RemoveCondition(int client, char[] cond)
{
	char conds[32][32];
	int count = ExplodeString(cond, " ; ", conds, sizeof(conds), sizeof(conds));
	if (count > 0)
	{
		for (int i = 0; i < count; i+=2)
		{
			if(TF2_IsPlayerInCondition(client, view_as<TFCond>(StringToInt(conds[i]))))
			{
				TF2_RemoveCondition(client, view_as<TFCond>(StringToInt(conds[i])));
			}
		}
	}
}

///////////////////////////////////////////
// Combo RAGE & AMS TFConditions Version //
///////////////////////////////////////////

public bool:TFC_CanInvoke(client)
{
	return true; // no special conditions will prevent this ability
}

public TFC_Invoke(client, slot)
{
	new boss=FF2_GetBossIndex(client);
	InvokeCondition(boss, client, -1, slot);
}

////////////////////////////////////////
// AMS-exclusive TFConditions Version //
////////////////////////////////////////

public bool:TC0_CanInvoke(client)
{
	return true; // no special conditions will prevent this ability
}

public TC0_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	InvokeCondition(boss, client, 0);
}

public bool:TC1_CanInvoke(client)
{
	return true; // no special conditions will prevent this ability
}

public TC1_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	InvokeCondition(boss, client, 1);
}

public bool:TC2_CanInvoke(client)
{
	return true; // no special conditions will prevent this ability
}

public TC2_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	InvokeCondition(boss, client, 2);
}

public bool:TC3_CanInvoke(client)
{
	return true; // no special conditions will prevent this ability
}

public TC3_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	InvokeCondition(boss, client, 3);
}

public bool:TC4_CanInvoke(client)
{
	return true; // no special conditions will prevent this ability
}

public TC4_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	InvokeCondition(boss, client, 4);
}

public bool:TC5_CanInvoke(client)
{
	return true; // no special conditions will prevent this ability
}

public TC5_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	InvokeCondition(boss, client, 5);
}

public bool:TC6_CanInvoke(client)
{
	return true; // no special conditions will prevent this ability
}

public TC6_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	InvokeCondition(boss, client, 6);
}

public bool:TC7_CanInvoke(client)
{
	return true; // no special conditions will prevent this ability
}

public TC7_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	InvokeCondition(boss, client, 7);
}

public bool:TC8_CanInvoke(client)
{
	return true; // no special conditions will prevent this ability
}

public TC8_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	InvokeCondition(boss, client, 8);
}

public bool:TC9_CanInvoke(client)
{
	return true; // no special conditions will prevent this ability
}

public TC9_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	InvokeCondition(boss, client, 9);
}

void InvokeCondition(int boss, int client, int tfcnum, int slot = -3)
{
	char amsCond[96];// , abilitySound[PLATFORM_MAX_PATH];

	if(tfcnum<0)
	{
		Format(amsCond, sizeof(amsCond), "rage_tfcondition");
		// Format(abilitySound,sizeof(abilitySound), "sound_tfcondition");
	}
	else
	{
		Format(amsCond, sizeof(amsCond), "ams_tfcond_%i", tfcnum);
		// Format(abilitySound,sizeof(abilitySound), "sound_tfcondition_%i", tfcnum);
	}

	char PlayerCond[768], BossCond[768], snd[PLATFORM_MAX_PATH];
	FF2_GetAbilityArgumentString(boss, THIS_PLUGIN_NAME, amsCond, "boss_conditions", BossCond, sizeof(BossCond), _, slot); // client TFConds
	FF2_GetAbilityArgumentString(boss, THIS_PLUGIN_NAME, amsCond, "player_conditions", PlayerCond, sizeof(PlayerCond), _, slot); // Player TFConds

	if(FF2_FindSound("tfcond", snd, sizeof(snd), boss, true, 0))
	{
		EmitSoundToAll(snd);
	}

	if(BossCond[0]!='\0')
	{
		SetCondition(client, BossCond);
	}
	if(PlayerCond[0]!='\0')
	{
		float pos[3], pos2[3], dist;
		float dist2=FF2_GetAbilityArgumentFloat(boss, THIS_PLUGIN_NAME, amsCond, "distance", view_as<float>(FF2_GetBossRageDistance(boss, THIS_PLUGIN_NAME, amsCond, slot)));
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);

		for(int target=1; target<=MaxClients; target++)
		{
			if(IsValidClient(target) && IsPlayerAlive(target) && TF2_GetClientTeam(target)!= TF2_GetClientTeam(client))
			{
				GetEntPropVector(target, Prop_Send, "m_vecOrigin", pos2);
				dist=GetVectorDistance(pos,pos2);
				if (dist<dist2 && TF2_GetClientTeam(target)!=TF2_GetClientTeam(client))
				{
					SetCondition(target, PlayerCond);
				}
			}
		}
	}
}
