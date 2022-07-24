public int Native_GetBossUserId(Handle plugin, int numParams)
{
	return GetBossUserId(GetNativeCell(1));
}

public int Native_GetBossIndex(Handle plugin, int numParams)
{
	return GetBossIndex(GetNativeCell(1));
}

public int Native_GetBossHealth(Handle plugin, int numParams)
{
	return GetBossHealth(GetNativeCell(1));
}
public int Native_SetBossHealth(Handle plugin, int numParams)
{
	SetBossHealth(GetNativeCell(1), GetNativeCell(2));
	UpdateHealthBar(false);
}

public int Native_GetBossMaxHealth(Handle plugin, int numParams)
{
	return GetBossMaxHealth(GetNativeCell(1));
}
public int Native_SetBossMaxHealth(Handle plugin, int numParams)
{
	SetBossMaxHealth(GetNativeCell(1), GetNativeCell(2));
}

public int Native_GetBossLives(Handle plugin, int numParams)
{
	return GetBossLives(GetNativeCell(1));
}
public int Native_SetBossLives(Handle plugin, int numParams)
{
	SetBossLives(GetNativeCell(1), GetNativeCell(2));
}

public int Native_GetBossMaxLives(Handle plugin, int numParams)
{
	return GetBossMaxLives(GetNativeCell(1));
}
public int Native_SetBossMaxLives(Handle plugin, int numParams)
{
	SetBossMaxLives(GetNativeCell(1), GetNativeCell(2));
}

public int Native_GetBossCharge(Handle plugin, int numParams)
{
	return view_as<int>(GetBossCharge(GetNativeCell(1), GetNativeCell(2)));
}
public int Native_SetBossCharge(Handle plugin, int numParams)
{
	SetBossCharge(GetNativeCell(1), GetNativeCell(2), view_as<float>(GetNativeCell(3)));
}
public int Native_AddBossCharge(Handle plugin, int numParams)
{
	AddBossCharge(GetNativeCell(1), GetNativeCell(2), view_as<float>(GetNativeCell(3)));
}

public int Native_GetBossMaxCharge(Handle plugin, int numParams)
{
	return view_as<int>(GetBossMaxCharge(GetNativeCell(1)));
}
public int Native_SetBossMaxCharge(Handle plugin, int numParams)
{
	SetBossMaxCharge(GetNativeCell(1), view_as<float>(GetNativeCell(2)));
}

public int Native_GetBossRageDamage(Handle plugin, int numParams)
{
	return GetBossRageDamage(GetNativeCell(1));
}
public int Native_SetBossRageDamage(Handle plugin, int numParams)
{
	SetBossRageDamage(GetNativeCell(1), GetNativeCell(2));
}

public int Native_GetBossTeam(Handle plugin, int numParams)
{
	return view_as<int>(GetBossTeam());
}

public int Native_GetBossName(Handle plugin, int numParams)
{
	int length=GetNativeCell(3);
	char[] bossName=new char[length];
	bool bossExists=GetBossName(GetNativeCell(1), bossName, length, GetNativeCell(4));
	SetNativeString(2, bossName, length);
	return bossExists;
}

public int Native_GetBossCreatorFlags(Handle plugin, int numParams)
{
	char steamId[32];
	GetNativeString(1, steamId, sizeof(steamId));
	return view_as<int>(GetBossCreatorFlags(steamId, GetNativeCell(2), GetNativeCell(3)));
}

public int Native_GetBossCreators(Handle plugin, int numParams)
{
	return view_as<int>(GetBossCreators(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3)));
}

public int Native_GetBossKV(Handle plugin, int numParams)
{
	return view_as<int>(GetBossKV(GetNativeCell(1)));
}

public int Native_HasAbility(Handle plugin, int numParams)
{
	char pluginName[64], abilityName[64];
	GetNativeString(2, pluginName, sizeof(pluginName));
	GetNativeString(3, abilityName, sizeof(abilityName));
	return HasAbility(GetNativeCell(1), pluginName, abilityName, GetNativeCell(4));
}

public int Native_GetAbilityArgument(Handle plugin, int numParams)
{
	char pluginName[64], abilityName[64], argument[64];
	GetNativeString(2, pluginName, sizeof(pluginName));
	GetNativeString(3, abilityName, sizeof(abilityName));
	GetNativeString(4, argument, sizeof(argument));
	return GetAbilityArgumentWrapper(GetNativeCell(1), pluginName, abilityName, argument, GetNativeCell(5), GetNativeCell(6));
}

public int Native_GetAbilityArgumentFloat(Handle plugin, int numParams)
{
	char pluginName[64], abilityName[64], argument[64];
	GetNativeString(2, pluginName, sizeof(pluginName));
	GetNativeString(3, abilityName, sizeof(abilityName));
	GetNativeString(4, argument, sizeof(argument));
	return view_as<int>(GetAbilityArgumentFloatWrapper(GetNativeCell(1), pluginName, abilityName, argument, view_as<float>(GetNativeCell(5)), GetNativeCell(6)));
}

public int Native_GetAbilityArgumentString(Handle plugin, int numParams)
{
	char pluginName[64], abilityName[64], defaultValue[64], argument[64];
	GetNativeString(2, pluginName, sizeof(pluginName));
	GetNativeString(3, abilityName, sizeof(abilityName));
	GetNativeString(4, argument, sizeof(argument));
	GetNativeString(7, defaultValue, sizeof(defaultValue));
	int length=GetNativeCell(6);
	char[] abilityString=new char[length];
	GetAbilityArgumentStringWrapper(GetNativeCell(1), pluginName, abilityName, argument, abilityString, length, defaultValue, GetNativeCell(8));
	SetNativeString(5, abilityString, length);
}


public int Native_UseAbility(Handle plugin, int numParams)
{
	char pluginName[64], abilityName[64];
	GetNativeString(2, pluginName, sizeof(pluginName));
	GetNativeString(3, abilityName, sizeof(abilityName));
	UseAbility(GetNativeCell(1), pluginName, abilityName, GetNativeCell(4), GetNativeCell(5));
}
