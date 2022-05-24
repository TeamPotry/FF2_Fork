public int Native_GetCharacterIndex(Handle plugin, int numParams)
{
	return GetCharacterIndex(GetNativeCell(1));
}

public int Native_GetCharacterKV(Handle plugin, int numParams)
{
	return view_as<int>(GetCharacterKV(GetNativeCell(1)));
}
