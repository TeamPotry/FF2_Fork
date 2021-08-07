#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <morecolors>
#include <freak_fortress_2>
#include <ff2_potry>
#include <stocksoup/tf/annotations>

#define PLUGIN_VERSION "1.0.0"

public Plugin:myinfo=
{
	name="Freak Fortress 2: skeleton king",
	author="DaNetNavern0",
	description="FF2: Skeleton King",
	version=PLUGIN_VERSION
};

#define THIS_PLUGIN_NAME        	"skeleton_king"
/*
#define CHARGE_PROTECTILE			"charge_protectile"
#define RAGE_WRAITHFIRE_ERUPTION	"rage_wraithfire_eruption"
#define CRITICAL_HITS 				"critical_hits"
#define RAGE_REINCARNATION			"rage_reincarnation"
*/
new Handle:chargeHUD;
new Handle:cooldownHUD;
new BossTeam=_:TFTeam_Blue;
new bool:isDead[MAXPLAYERS+1];
new bool:bRaged[MAXPLAYERS+1];
new bool:canNotReincarnate[MAXPLAYERS+1];
new Handle:Timer_toReincarnate[MAXPLAYERS+1];
new timeleft_stacks[MAXPLAYERS+1];
new timeleft[MAXPLAYERS+1];

public OnPluginStart()
{
	HookEvent("teamplay_round_start", event_round_start);
	LoadTranslations("ff2_skeleton_king.phrases");
	HookEvent("player_hurt", event_hurt, EventHookMode_Pre);

	FF2_RegisterSubplugin(THIS_PLUGIN_NAME);

	for (new client = 1; client <= MaxClients; client++)
		if (IsValidEdict(client))
			OnClientPutInServer(client);
}

public OnMapStart()
{
	chargeHUD = CreateHudSynchronizer();
	cooldownHUD = CreateHudSynchronizer();
}


public Action:event_round_start(Handle:event, const String:name[], bool:dontBroadcast)
{
	CreateTimer(0.3, Timer_GetBossTeam);
	for(new i=0;i<MAXPLAYERS+1;i++)
	{
		isDead[i]=false;
		/*if(Timer_toReincarnate[i]!=INVALID_HANDLE)
		{
			KillTimer(Timer_toReincarnate[i]);
			Timer_toReincarnate[i]=INVALID_HANDLE;
		}*/
		timeleft_stacks[i]=0;
		canNotReincarnate[i]=false;
		bRaged[i]=false;
	}
	return Plugin_Continue;
}
public Action:Timer_GetBossTeam(Handle:hTimer)
{
	BossTeam=view_as<int>(FF2_GetBossTeam());
	return Plugin_Continue;
}

public Action:FF2_OnLoseLife(index)
{
	new userid = FF2_GetBossUserId(index);
	new client=GetClientOfUserId(userid);
	if(index==-1 || !IsValidEdict(client) || !FF2_HasAbility(index, THIS_PLUGIN_NAME, "rage_reincarnation"))
		return Plugin_Continue;

	if (canNotReincarnate[index])
	{
		//ForcePlayerSuicide(client);
	}
	else
	{
		isDead[index] = true;
		canNotReincarnate[index] = true;
		timeleft[index]=FF2_GetAbilityArgument(index, THIS_PLUGIN_NAME, "rage_reincarnation", "first cooldown", 60)+timeleft_stacks[index];
		timeleft_stacks[index]+=FF2_GetAbilityArgument(index, THIS_PLUGIN_NAME, "rage_reincarnation", "cooldown increaser", 60);
		if (Timer_toReincarnate[index]!=INVALID_HANDLE)
			KillTimer(Timer_toReincarnate[index]);
		Timer_toReincarnate[index]=CreateTimer(1.0, Timer_nowUcanReincarnate, index, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		FF2_SetBossLives(index,2);
		FF2_SetBossHealth(index,FF2_GetBossMaxHealth(index)*10);
		decl String:model[PLATFORM_MAX_PATH];
		FF2_GetAbilityArgumentString(index, THIS_PLUGIN_NAME, "rage_reincarnation", "gravestone model", model, PLATFORM_MAX_PATH);
		SetVariantString(model);
		AcceptEntityInput(client, "SetCustomModel");
		SetEntityMoveType(client, MOVETYPE_NONE);
		new Handle:data;
		SDKHook(client, SDKHook_OnTakeDamage, StopTakeDamage);
		SetEntityFlags(client, GetEntityFlags(client) | FL_FROZEN);
		new Float:delay = FF2_GetAbilityArgumentFloat(index, THIS_PLUGIN_NAME, "rage_reincarnation", "delay", 3.0)+2;
		TF2_AddCondition(client,TFCond_UberchargedHidden,delay);
		CreateDataTimer(2.0, Timer_ReincarnateI, data);
		SetVariantInt(1);
		AcceptEntityInput(client, "SetForcedTauntCam");
		WritePackCell(data, userid);
		WritePackCell(data, index);
		ResetPack(data);

		float pos[3];
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);

		FF2_GetAbilityArgumentString(index, THIS_PLUGIN_NAME, "rage_reincarnation", "dead skeleton model", model, PLATFORM_MAX_PATH);
		if (strlen(model)>5)
		{
			decl Float:rot[3];

			GetEntPropVector(client, Prop_Data, "m_angRotation", rot);
			new deadbody = CreateEntityByName("prop_dynamic");
			TeleportEntity(deadbody, pos, rot, NULL_VECTOR);
			SetEntityModel(deadbody, model);
			DispatchSpawn(deadbody);
			new String:anim[32];
			if (GetEntityFlags(client) & FL_ONGROUND)
				FF2_GetAbilityArgumentString(index, THIS_PLUGIN_NAME, "rage_reincarnation", "in ground anim name", anim, 32);
			else
				FF2_GetAbilityArgumentString(index, THIS_PLUGIN_NAME, "rage_reincarnation", "in air anim name", anim, 32);
			SetVariantString(anim);
			AcceptEntityInput(deadbody, "SetAnimation");
			CreateTimer(delay,RemoveEntity_Delay,EntIndexToEntRef(deadbody));
		}

		SetHudTextParams(-1.0, 0.35, 10.0, 255, 255, 255, 255);

		for(new player=1; player<=MaxClients; player++)
		{
			if(IsValidClient(player) && GetClientTeam(player)!=GetClientTeam(client))
			{
				SetGlobalTransTarget(player);
				char charnaem[64], text[256];
				FF2_GetBossSpecial(index,charnaem,64,GetClientLanguage(player));
				Format(text,256,"%t","reincarnation_info",timeleft[index],charnaem);

				TF2_ShowPositionalAnnotationToClient(player, pos, text, _, _, 10.0);
				// ShowSyncHudText(player, cooldownHUD, text);
			}

		}

	}
	return Plugin_Continue;
}

public void FF2_GetBossSpecial(int boss, char[] name, int buffer, int lang)
{
	char langCode[8];
	GetLanguageInfo(lang, langCode, 8);
	KeyValues bossKV = FF2_GetBossKV(boss);

	bossKV.Rewind();
	if(StrEqual(langCode, "en"))
		bossKV.GetString("name", name, buffer, "ERROR NAME");
	else if(!bossKV.JumpToKey("name_lang"))
		return;

	bossKV.GetString(langCode, name, buffer);
}

public Action:FF2_OnTriggerHurt(index, triggerhurt, &Float:damage)
{
	if (damage<=450 || !isDead[index])
		return Plugin_Continue;
	new tries;
	new bool:otherTeamIsAlive=false;
	new boss=GetClientOfUserId(FF2_GetBossUserId(index));
	for(new target=1; target<=MaxClients; target++)
	{
		if(IsValidEdict(target) && IsClientInGame(target) && IsPlayerAlive(target) && GetClientTeam(target)!=BossTeam)
		{
			otherTeamIsAlive=true;
			break;
		}
	}
	if (otherTeamIsAlive)
	{
		new target;
		do
		{
			tries++;
			target=GetRandomInt(1, MaxClients);
			if(tries==100)
			{
				return Plugin_Continue;
			}
		}
		while((!IsValidEdict(target) || target==boss || !IsPlayerAlive(target)));

		decl Float:position[3];
		if(IsValidEdict(target))
		{
			GetEntPropVector(target, Prop_Send, "m_vecOrigin", position);
			if(GetEntProp(target, Prop_Send, "m_bDucked"))
			{
				new Float:vectorsMax[3]={24.0, 24.0, 62.0};
				SetEntPropVector(boss, Prop_Send, "m_vecMaxs", vectorsMax);
				SetEntProp(boss, Prop_Send, "m_bDucked", 1);
				SetEntityFlags(boss, GetEntityFlags(boss)|FL_DUCKING);
			}
			TeleportEntity(boss, position, NULL_VECTOR, NULL_VECTOR);
		}
	}
	return Plugin_Stop;
}

public Action:StopTakeDamage(client, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	new String:charnaem[64];
	new index = FF2_GetBossIndex(client);
	if (index==-1)
	{
		LogError("LolWAT?");
		LogMessage("LolWAT?");
		return Plugin_Continue;
	}
	// FF2_GetBossSpecial(index,charnaem,64,GetClientLanguage(attacker));
	// SetHudTextParams(-1.0, 0.45, 4.0, 255, 255, 255, 255);
	// ShowSyncHudText(attacker, cooldownHUD, "%t","reincarnation_invulnerable",charnaem);
	return Plugin_Stop;
}

public Action:event_hurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client=GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker=GetClientOfUserId(GetEventInt(event, "attacker"));
	new index = FF2_GetBossIndex(client);
	if(index!=-1)
	{
		if (isDead[index])
		{
			if (attacker>0 && attacker!=client)
			{
				/*
				new String:charnaem[64];
				FF2_GetBossSpecial(index,charnaem,64,GetClientLanguage(attacker));
				SetHudTextParams(-1.0, 0.45, 4.0, 255, 255, 255, 255);
				ShowSyncHudText(attacker, cooldownHUD, "%t","reincarnation_invulnerable",charnaem);
				*/
			}
			return Plugin_Stop;
		}
	}
	else if (GetConVarInt(FindConVar("ff2_crits"))==0)
	{
		index = FF2_GetBossIndex(attacker);
		if (index!=-1 && FF2_HasAbility(index, THIS_PLUGIN_NAME, "critical_hits"))
		{
			new Float:chance = FF2_GetAbilityArgumentFloat(index, THIS_PLUGIN_NAME, "critical_hits", "chance", 0.2);
			if (GetRandomFloat(0.0, 1.0)<=chance)
			{
				SetEventInt(event, "damageamount", GetEventInt(event, "damageamount")*2);
				new slot=FF2_GetAbilityArgument(index, THIS_PLUGIN_NAME, "critical_hits", "slot");
				decl String:s[PLATFORM_MAX_PATH];
				if(FF2_FindSound("ability",s,PLATFORM_MAX_PATH,index,true,slot))
				{
					decl Float:position[3];
					GetEntPropVector(attacker, Prop_Send, "m_vecOrigin", position);
					EmitSoundToAll(s, attacker, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, attacker, position, NULL_VECTOR, true, 0.0);
					EmitSoundToAll(s, attacker, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, attacker, position, NULL_VECTOR, true, 0.0);

					for(new i=1; i<=MaxClients; i++)
						if(IsClientInGame(i) && i!=attacker)
						{
							EmitSoundToClient(i,s, attacker, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, attacker, position, NULL_VECTOR, true, 0.0);
							EmitSoundToClient(i,s, attacker, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, attacker, position, NULL_VECTOR, true, 0.0);
						}
				}
				return Plugin_Changed;
			}
		}
	}
	return Plugin_Continue;
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action:OnTakeDamage(client, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if (attacker<1 || attacker>MaxClients || !IsValidClient(attacker))
		return Plugin_Continue;
	new index = FF2_GetBossIndex(attacker);
	if (index!=-1 && client!=attacker && FF2_HasAbility(index, THIS_PLUGIN_NAME, "charge_protectile"))
	{
		if (inflictor>MaxClients)
		{
			new Float:duration=FF2_GetAbilityArgumentFloat(index,THIS_PLUGIN_NAME,"charge_protectile","stun duration",3.0);
			if (duration>0.25)
				TF2_StunPlayer(client, duration, 0.0, TF_STUNFLAGS_NORMALBONK, attacker);
		}
	}
	return Plugin_Continue;
}


public Action:Timer_nowUcanReincarnate(Handle:hTimer,any:index)
{
	timeleft[index]--;
	new boss=GetClientOfUserId(FF2_GetBossUserId(index));
	if (FF2_GetRoundState()!=1)
	{
		KillTimer(Timer_toReincarnate[index]);
		Timer_toReincarnate[index]=INVALID_HANDLE;
	}
	else if (timeleft[index]<=0)
	{
		// SetHudTextParams(-1.0, 0.42, 4.0, 255, 255, 255, 255);
		// ShowSyncHudText(boss, cooldownHUD, "%t","reincarnation_ready");
		FF2_SetBossLives(index,2);
		FF2_SetBossHealth(index,FF2_GetBossHealth(index)+FF2_GetBossMaxHealth(index));
		canNotReincarnate[index] = false;
		KillTimer(Timer_toReincarnate[index]);
		Timer_toReincarnate[index]=INVALID_HANDLE;
	}
	else
	{
		// SetHudTextParams(-1.0, 0.42, 1.0, 255, 255, 255, 255);
		// ShowSyncHudText(boss, cooldownHUD, "%t","reincarnation_cooldown",timeleft[index]);
	}
}

public void FF2_OnCalledQueue(FF2HudQueue hudQueue, int client)
{
	int boss = FF2_GetBossIndex(client);
	if(boss != -1 && (Timer_toReincarnate[boss] == INVALID_HANDLE || timeleft[boss] <= 0))
		return;

	char text[256];
	bool changed = false;
	FF2HudDisplay hudDisplay = null;

	SetGlobalTransTarget(client);
	hudQueue.GetName(text, sizeof(text));

	if(StrEqual(text, "Boss"))
	{
		Format(text, sizeof(text), "%t", "reincarnation_cooldown", timeleft[boss]);

		hudDisplay = FF2HudDisplay.CreateDisplay("reincarnation_cooldown", text);
		hudQueue.AddHud(hudDisplay, client);
	}
}

public Action:Timer_ReincarnateI(Handle:hTimer,Handle:data)
{
	new userid = ReadPackCell(data);
	new client=GetClientOfUserId(userid);
	new index = EntRefToEntIndex(ReadPackCell(data));
	decl String:particle[128];
	decl Float:position[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", position);
	FF2_GetAbilityArgumentString(index, THIS_PLUGIN_NAME, "rage_reincarnation", "reincarnation particle", particle, 128);
	new Float:delay = FF2_GetAbilityArgumentFloat(index, THIS_PLUGIN_NAME, "rage_reincarnation", "delay", 3.0);
	if(strlen(particle)>2)
	{
		new Float:asd[3] = {0.0,0.0,-30.0};
		CreateTimer(delay, RemoveEntity_Delay, EntIndexToEntRef(AttachParticle(client, particle, asd, false)));
	}
	new Handle:data2;
	CreateDataTimer(delay, Timer_ReincarnateII, data2);
	WritePackCell(data2, userid);
	WritePackCell(data2, index);
	ResetPack(data2);
}

public Action:Timer_ReincarnateII(Handle:hTimer,Handle:data)
{
	new client=GetClientOfUserId(ReadPackCell(data));
	new index = EntRefToEntIndex(ReadPackCell(data));
	if (client>0)
	{
		decl String:model[PLATFORM_MAX_PATH];
		new Handle:see = FF2_GetBossKV(index);
		KvRewind(see);
		KvGetString(see, "model", model, PLATFORM_MAX_PATH);
		SetVariantString(model);
		AcceptEntityInput(client, "SetCustomModel");
		SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
		CloseHandle(see);
		SetEntityFlags(client, GetEntityFlags(client) & ~FL_FROZEN);
		SDKUnhook(client, SDKHook_OnTakeDamage, StopTakeDamage);
		FF2_SetBossHealth(index,FF2_GetBossMaxHealth(index));
		isDead[false] = false;
		SetVariantInt(0);
		AcceptEntityInput(client, "SetForcedTauntCam");
		SetEntityMoveType(client, MOVETYPE_WALK);
	}
	return Plugin_Continue;
}

public void FF2_OnAbility(int index, const char[] pluginName, const char[] abilityName, int slot, int status)
{
	if(!strcmp(abilityName, "charge_protectile"))
	{
		Charge_RocketSpawn(abilityName, index, slot, status);
	}
	else if(!strcmp(abilityName, "rage_wraithfire_eruption"))
	{
		Rage_Eruption(abilityName, index, slot);
	}
}

Charge_RocketSpawn(const String:ability_name[],index,slot,action)
{
	/*
	new Float:zero_charge = FF2_GetBossCharge(index,0);
	if(zero_charge<10)
		return;
	*/
	new boss=GetClientOfUserId(FF2_GetBossUserId(index));
	new Float:see=FF2_GetAbilityArgumentFloat(index,THIS_PLUGIN_NAME,ability_name,"charge duration",5.0);
	new Float:charge=FF2_GetBossCharge(index,slot);
	switch(action)
	{
		case 1:
		{
			SetHudTextParams(-1.0, 0.73, 0.08, 255, 255, 255, 255);
			ShowSyncHudText(boss, chargeHUD, "%t","charge_cooldown",-RoundFloat(charge));
		}
		case 2:
		{
			SetHudTextParams(-1.0, 0.73, 0.08, 255, 255, 255, 255);
			if(charge+1<see)
				FF2_SetBossCharge(index,slot,charge+1);
			else
				charge=see;
			ShowSyncHudText(boss, chargeHUD, "%t","charge_status",RoundFloat(charge*100/see));
		}
		default:
		{
			if (charge<=0.2)
			{
				SetHudTextParams(-1.0, 0.73, 0.08, 255, 255, 255, 255);
				ShowSyncHudText(boss, chargeHUD, "%t","charge_ready");
			}
			else if (charge>=see)
			{
				// FF2_SetBossCharge(index,0,zero_charge-10);
				decl Float:position[3];
				decl Float:rot[3];
				decl Float:velocity[3];
				GetEntPropVector(boss, Prop_Send, "m_vecOrigin", position);
				GetClientEyeAngles(boss,rot);
				position[2]+=63;

				new proj=CreateEntityByName("tf_projectile_rocket");
				SetVariantInt(BossTeam);
				AcceptEntityInput(proj, "TeamNum", -1, -1, 0);
				SetVariantInt(BossTeam);
				AcceptEntityInput(proj, "SetTeam", -1, -1, 0);
				SetEntPropEnt(proj, Prop_Send, "m_hOwnerEntity",boss);
				new Float:speed=FF2_GetAbilityArgumentFloat(index,THIS_PLUGIN_NAME,ability_name,"projectile speed",1000.0);
				velocity[0]=Cosine(DegToRad(rot[0]))*Cosine(DegToRad(rot[1]))*speed;
				velocity[1]=Cosine(DegToRad(rot[0]))*Sine(DegToRad(rot[1]))*speed;
				velocity[2]=Sine(DegToRad(rot[0]))*speed;
				velocity[2]*=-1;
				TeleportEntity(proj, position, rot,velocity);
				SetEntProp(proj, Prop_Send, "m_bCritical", 1);
				SetEntDataFloat(proj, FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4, FF2_GetAbilityArgumentFloat(index,THIS_PLUGIN_NAME,ability_name,"damage",40.0), true);
				DispatchSpawn(proj);
				new String:s[PLATFORM_MAX_PATH];
				FF2_GetAbilityArgumentString(index,THIS_PLUGIN_NAME,ability_name,"model path",s,PLATFORM_MAX_PATH);
				if(strlen(s)>5)
					SetEntityModel(proj,s);
				FF2_GetAbilityArgumentString(index,THIS_PLUGIN_NAME,ability_name,"projectile particle",s,PLATFORM_MAX_PATH);
				if(strlen(s)>2)
					CreateTimer(15.0, RemoveEntity_Delay, EntIndexToEntRef(AttachParticle(proj, s,_,true)));
				if(FF2_FindSound("ability",s,PLATFORM_MAX_PATH,index,true,slot))
				{
					EmitSoundToAll(s, boss, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, boss, position, NULL_VECTOR, true, 0.0);
					EmitSoundToAll(s, boss, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, boss, position, NULL_VECTOR, true, 0.0);

					for(new i=1; i<=MaxClients; i++)
						if(IsClientInGame(i) && i!=boss)
						{
							EmitSoundToClient(i,s, boss, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, boss, position, NULL_VECTOR, true, 0.0);
							EmitSoundToClient(i,s, boss, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, boss, position, NULL_VECTOR, true, 0.0);
						}
				}
			}
			else
			{
				ResetBossCharge(index, slot);
			}
		}
	}
}

Rage_Eruption(const String:ability_name[], index, slot)
{
	new client=GetClientOfUserId(FF2_GetBossUserId(index));
	/*
	if (!(GetEntityFlags(client) & FL_ONGROUND) && FF2_GetAbilityArgument(index, THIS_PLUGIN_NAME, ability_name, 9, 1))
	{
		PrintHintText(client,"%t","rage_available_in_ground");
		CreateTimer(0.3, Timer_RestoreCharge, index);
		return;
	}
	*/
	if (bRaged[index])
		return;
	bRaged[index]=true;
	SetEntityFlags(client, GetEntityFlags(client) | FL_FROZEN);
	SetEntityMoveType(client, MOVETYPE_NONE);
	SDKHook(client, SDKHook_OnTakeDamage, StopTakeDamage);

	decl Float:position[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", position);

	decl String:s[PLATFORM_MAX_PATH];
	new String:keys[][] = {"ability_effect","ability_voice"};
	for(new i=0;i<2;i++)
		if(FF2_FindSound(keys[i],s,PLATFORM_MAX_PATH,index))
			EmitSoundToAll(s, client, _, SNDLEVEL_RAIDSIREN, SND_NOFLAGS, SNDVOL_NORMAL, 100, client, position, NULL_VECTOR, true, 0.0);
	new Float:delay = FF2_GetAbilityArgumentFloat(index, THIS_PLUGIN_NAME, ability_name, "delay", 3.0);
	CreateTimer(delay, Timer_Eruption, index);
	if (FF2_GetAbilityArgument(index, THIS_PLUGIN_NAME, ability_name, "enable uber", 0))
		TF2_AddCondition(client, TFCond_Ubercharged, delay);
	if (FF2_GetAbilityArgument(index, THIS_PLUGIN_NAME, ability_name, "slow enemies in radius", 0))
		Rage_Slow(delay, FF2_GetAbilityArgumentFloat(index, THIS_PLUGIN_NAME, ability_name, "radius", 800.0), client);
	decl String:model[PLATFORM_MAX_PATH];
	FF2_GetAbilityArgumentString(index, THIS_PLUGIN_NAME, ability_name, "radius model", model, PLATFORM_MAX_PATH);
	if(strlen(model)>5)
	{
		new prop=CreateEntityByName("prop_dynamic_override");
		SetEntityModel(prop, model);
		SetEntityRenderMode(prop, RENDER_TRANSCOLOR);
		SetEntityRenderColor(prop, 255, 255, 255, 125);
		DispatchSpawn(prop);
		TeleportEntity(prop, position, NULL_VECTOR, NULL_VECTOR);
		SetEntityRenderMode(prop, RENDER_TRANSCOLOR);
		SetEntityRenderColor(prop, 255, 255, 255, 125);
		CreateTimer(delay/4, Timer_ChangeOpaque, EntIndexToEntRef(prop));
		CreateTimer(delay/2, Timer_ChangeOpaque, EntIndexToEntRef(prop));
		CreateTimer(delay, RemoveEntity_Delay, EntIndexToEntRef(prop));
	}
}

public Action:Timer_ChangeOpaque(Handle:hTimer,any:prop)
{
	new entity=EntRefToEntIndex(prop);
	SetEntityRenderColor(entity, 255, 255, 255, 175);
}

public Action:Timer_ChangeOpaqueII(Handle:hTimer,any:prop)
{
	new entity=EntRefToEntIndex(prop);
	SetEntityRenderColor(entity, 255, 255, 255, 255);
}


Rage_Slow(Float:duration, Float:distance, client)
{
	decl Float:bossPosition[3];
	decl Float:clientPosition[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", bossPosition);
	for(new target=1; target<=MaxClients; target++)
	{
		if(IsClientInGame(target) && IsPlayerAlive(target) && GetClientTeam(target)!=BossTeam)
		{
			GetEntPropVector(target, Prop_Send, "m_vecOrigin", clientPosition);
			if(!TF2_IsPlayerInCondition(target, TFCond_Ubercharged) && (GetVectorDistance(bossPosition, clientPosition)<=distance))
			{
				TF2_StunPlayer(target, duration, 0.0, TF_STUNFLAGS_GHOSTSCARE|TF_STUNFLAG_NOSOUNDOREFFECT, client);
				new Float:asd[3] = {0.0, 0.0, 75.0};
				CreateTimer(duration, RemoveEntity_Delay, EntIndexToEntRef(AttachParticle(target, "yikes_fx", asd, true)));
			}
		}
	}
}

public Action:Timer_RestoreCharge(Handle:hTimer,any:index)
{
	FF2_SetBossCharge(index,0,100.0);
}

public Action:Timer_Eruption(Handle:hTimer,any:index)
{
	bRaged[index]=false;
	new boss=GetClientOfUserId(FF2_GetBossUserId(index));

	if (FF2_GetRoundState() != 1)
	{
		return Plugin_Continue;
	}
	/*
	if (isDead[index])
	{
		// PrintHintText(boss,"%t","rage_available_in_ground");
		CreateTimer(0.3, Timer_RestoreCharge, index);
		return Plugin_Continue;
	}
	*/
	SetEntityFlags(boss, GetEntityFlags(boss) & ~FL_FROZEN);
	SetEntityMoveType(boss, MOVETYPE_WALK);
	SDKUnhook(boss, SDKHook_OnTakeDamage, StopTakeDamage);

	decl String:effect[128];
	FF2_GetAbilityArgumentString(index, THIS_PLUGIN_NAME, "rage_wraithfire_eruption", "explosion particle", effect, 128);
	new Float:distance=FF2_GetAbilityArgumentFloat(index, THIS_PLUGIN_NAME, "rage_wraithfire_eruption", "radius", 800.0);
	new Float:multiplier=FF2_GetAbilityArgumentFloat(index, THIS_PLUGIN_NAME, "rage_wraithfire_eruption", "damage multiplier", 2.5);
	decl Float:position2[3];
	decl Float:pos[3];
	GetEntPropVector(boss, Prop_Send, "m_vecOrigin", pos);
	new Float:z_radius = FF2_GetAbilityArgumentFloat(index, THIS_PLUGIN_NAME, "rage_wraithfire_eruption","z-axis radius", 0.0);
	if (z_radius<1.0)
		z_radius=distance;
	for(new i=0;i<20;i++)
	{
		position2[0]=GetRandomFloat(-distance/1.3,distance/1.3);
		position2[1]=GetRandomFloat(-distance/1.3,distance/1.2);
		position2[2]=GetRandomFloat(-z_radius/8,z_radius/1.2);
		CreateTimer(4.0, RemoveEntity_Delay, EntIndexToEntRef(AttachParticle(boss, effect, position2,false)));
	}
	for(new victim=1;victim<=MaxClients;victim++)
	{
		if (!IsValidClient(victim) || GetClientTeam(victim)==GetClientTeam(boss) || !IsPlayerAlive(victim))
			continue;

		GetEntPropVector(victim, Prop_Send, "m_vecOrigin", position2);
		new Float:adistance = GetVectorDistance(pos, position2);
		new Float:damage = (distance-adistance)*multiplier;

		if (adistance<distance)
		{
			SDKHooks_TakeDamage(victim,
                        boss,
                        boss,
                        damage);

			FF2_SetBossMaxHealth(FF2_GetBossIndex(boss), FF2_GetBossMaxHealth(FF2_GetBossIndex(boss)) + 200);
			FF2_SetBossHealth(FF2_GetBossIndex(boss), FF2_GetBossHealth(FF2_GetBossIndex(boss)) + 200);
		}
	}
	return Plugin_Continue;
}

stock AttachParticle(entity, String:particleType[], Float:offset[]={0.0,0.0,0.0}, bool:attach=true)
{
	new particle=CreateEntityByName("info_particle_system");

	decl String:targetName[128];
	decl Float:position[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
	position[0]+=offset[0];
	position[1]+=offset[1];
	position[2]+=offset[2];
	TeleportEntity(particle, position, NULL_VECTOR, NULL_VECTOR);

	Format(targetName, sizeof(targetName), "target%i", entity);
	DispatchKeyValue(entity, "targetname", targetName);

	DispatchKeyValue(particle, "targetname", "tf2particle");
	DispatchKeyValue(particle, "parentname", targetName);
	DispatchKeyValue(particle, "effect_name", particleType);
	DispatchSpawn(particle);
	SetVariantString(targetName);
	if(attach)
	{
		AcceptEntityInput(particle, "SetParent", particle, particle, 0);
		SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", entity);
	}
	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
	return particle;
}

public Action:RemoveEntity_Delay(Handle:timer, any:entid)
{
	new entity=EntRefToEntIndex(entid);
	if(IsValidEdict(entity) && entity>MaxClients)
	{
		/*
			if(TF2_IsWearable(entity))
			{
				for(new client=1; client<MaxClients; client++)
				{
					if(IsValidEdict(client) && IsClientInGame(client))
					{
						TF2_RemoveWearable(client, entity);
					}
				}
			}
			else
			{
				AcceptEntityInput(entity, "Kill");
			}
			*/
		AcceptEntityInput(entity, "Kill");
	}
}

stock IsValidClient(client, bool:replaycheck=true)
{
	if(client<=0 || client>MaxClients)
	{
		return false;
	}

	if(!IsClientInGame(client))
	{
		return false;
	}

	if(GetEntProp(client, Prop_Send, "m_bIsCoaching"))
	{
		return false;
	}

	if(replaycheck)
	{
		if(IsClientSourceTV(client) || IsClientReplay(client))
		{
			return false;
		}
	}
	return true;
}
