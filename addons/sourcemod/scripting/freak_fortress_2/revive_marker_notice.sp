#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <ff2_modules/general>

#define PLUGIN_VERSION "20191128"

public Plugin myinfo=
{
	name="Freak Fortress 2: Revive Marker Notice",
	author="Nopied",
	description="FF2: Notice message for healing revive marker.",
	version=PLUGIN_VERSION,
};

public void OnPluginStart()
{
    LoadTranslations("ff2_revive_marker_notice");
}

public void FF2_OnCalledQueue(FF2HudQueue hudQueue, int client)
{
	char text[256];
	FF2HudDisplay hudDisplay = null;

	SetGlobalTransTarget(client);
	hudQueue.GetName(text, sizeof(text));

	if(StrEqual(text, "Observer"))
	{
		int temp = -1, healed, observer = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
		if(IsValidClient(observer)) // 소생마커 인덱스 = 클라이언트 인덱스?
        {
            healed = GetHealingTarget(observer, true);
            if(IsValidEntity(healed))
            {
                while((temp = FindEntityByClassname(temp, "entity_revive_marker")) != -1)
                    if(temp == healed)
                    {
                        Format(text, sizeof(text), "%T", "Revive Marker Healing", client, GetEntProp(healed, Prop_Send, "m_iMaxHealth") - GetEntProp(healed, Prop_Send, "m_iHealth"));
                        hudDisplay = FF2HudDisplay.CreateDisplay("Dev Mode", text);
                        hudQueue.AddHud(hudDisplay, client);
                    }
            }
        }
	}

	return;
}

stock int GetHealingTarget(int client, bool checkgun=false)
{
	int medigun=GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
	if(!checkgun)
	{
		if(GetEntProp(medigun, Prop_Send, "m_bHealing"))
		{
			return GetEntPropEnt(medigun, Prop_Send, "m_hHealingTarget");
		}
		return -1;
	}

	if(IsValidEntity(medigun))
	{
		char classname[64];
		GetEntityClassname(medigun, classname, sizeof(classname));
		if(StrEqual(classname, "tf_weapon_medigun", false))
		{
			if(GetEntProp(medigun, Prop_Send, "m_bHealing"))
			{
				return GetEntPropEnt(medigun, Prop_Send, "m_hHealingTarget");
			}
		}
	}
	return -1;
}

stock bool IsValidClient(int client)
{
    return (0 < client && client <= MaxClients && IsClientInGame(client));
}

stock bool IsBoss(int client)
{
	return FF2_GetBossIndex(client) != -1;
}
