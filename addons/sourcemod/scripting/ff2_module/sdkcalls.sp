Handle g_SDKCallGetMaxAmmo;

void GameData_Init(GameData gamedata)
{
    if (gamedata == null)
    {
        SetFailState("Could not find potry gamedata");
        return;
    }

    g_SDKCallGetMaxAmmo = PrepSDKCall_GetMaxAmmo(gamedata);
}

Handle PrepSDKCall_GetMaxAmmo(GameData gamedata)
{
    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFPlayer::GetMaxAmmo");
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);

    Handle call = EndPrepSDKCall();
    if (!call)
    	LogMessage("Failed to create SDK call: CTFPlayer::GiveAmmo");

    return call;
}

int SDKCall_GetMaxAmmo(int player, int iAmmoIndex, int iClassIndex = -1)
{
    if (g_SDKCallGetMaxAmmo)
        return SDKCall(g_SDKCallGetMaxAmmo, player, iAmmoIndex, iClassIndex);

    return 0;
}
