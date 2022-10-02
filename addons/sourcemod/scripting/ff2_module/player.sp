Handle FF2Cookie_QueuePoints;

int botqueuepoints;

enum
{
    FF2BE_Ref = 0,
    FF2BE_Index,

    FF2BE_Damage,
    FF2BE_LastNoticedDamage,
    FF2BE_Assist,
    
    FF2BE_Flags,

    // TODO: Add FF2SpecialInfo
    FF2BE_SpecialInfo,
    
    FF2BE_MAX_COUNT
};

/*
 * Not only player, include other entities
 * 
 * General Info about entities for FF2
 */
methodmap FF2BaseEntity < ArrayList
{
    public FF2BaseEntity(int entRef)
    {
        ArrayList newArray = new ArrayList(PLATFORM_MAX_PATH);

        newArray.Push(entRef);
        
        newArray.Push(0);
        newArray.Push(0);
        newArray.Push(0);

        newArray.Push(0);

        return view_as<FF2BaseEntity>(newArray);
    }

    property int Ref {
        public get() {
            return this.Get(FF2BE_Ref);
        }
        public set(int ref) {
            this.Set(FF2BE_Ref, ref);
        }
    } 

    property int Index {
        public get() {
            return EntRefToEntIndex(this.Get(FF2BE_Ref));
        }
    } 

    property int Damage {
        public get() {
            return this.Get(FF2BE_Damage);
        }
        public set(int damage) {
            this.Set(FF2BE_Damage, damage);
        }
    }
    property int LastNoticedDamage {
        public get() {
            return this.Get(FF2BE_LastNoticedDamage);
        }
        public set(int damage) {
            this.Set(FF2BE_LastNoticedDamage, damage);
        }
    }
    property int Assist {
        public get() {
            return this.Get(FF2BE_Assist);
        }
        public set(int assist) {
            this.Set(FF2BE_Assist, assist);
        }
    }

    property int Flags {
        public get() {
            return this.Get(FF2BE_Flags);
        }
        public set(int flags) {
            this.Set(FF2BE_Flags, flags);
        }
    }
}

methodmap FF2BaseEntity_List < ArrayList
{
    public FF2BaseEntity_List()
    {
        return view_as<FF2BaseEntity_List>(new ArrayList());
    }

    public int AddEntity(FF2BaseEntity baseEnt)
    {
        int ref = baseEnt.Ref,
            len = this.Length;

        if(len < 1)
        {
            this.Push(baseEnt);
            return 0;
        }

        int absRef = ref & 0x7FFFFFFF;
        if(absRef < view_as<FF2BaseEntity>(this.Get(0)).Ref & 0x7FFFFFFF)
        {
            this.ShiftUp(0);
            this.Set(0, baseEnt);
            return 0;
        }
        else if(view_as<FF2BaseEntity>(this.Get(len - 1)).Ref & 0x7FFFFFFF < absRef)
        {
            this.Push(baseEnt);
            return len;
        }

        for(int loop = 0; loop < len; loop++)
        {
            if(view_as<FF2BaseEntity>(this.Get(loop)).Ref & 0x7FFFFFFF > absRef)
            {
                this.ShiftUp(loop);
                this.Set(loop, baseEnt);

                return loop;
            }
        }

        // Should not be.
        return -1;
    }
/*
    // NOTE: Not working 
    public int AddEntity(FF2BaseEntity baseEnt)
    {
        int ref = baseEnt.Ref,
            len = this.Length;

        if(len < 1)
        {
            this.Push(baseEnt);
            return 0;
        }
        // 초기값 검증 (왼쪽, 오른쪽 끝 값과 비교)
        int absRef = ref & 0x7FFFFFFF;
        if(absRef < view_as<FF2BaseEntity>(this.Get(0)).Ref & 0x7FFFFFFF)
        {
            // this.Resize(len + 1);
            this.ShiftUp(0);
            this.Set(0, baseEnt);
            return 0;
        }
        else if(view_as<FF2BaseEntity>(this.Get(len - 1)).Ref & 0x7FFFFFFF < absRef)
        {
            this.Push(baseEnt);
            return len;
        }

        int left = 0, right = len, mid;
        do
        {
            mid = ((left + (right - 1)) / 2) + 1;
            if(left == mid || right == mid || mid >= len)     break;

            int midRef = view_as<FF2BaseEntity>(this.Get(mid)).Ref;

            if(absRef > midRef)
            {
                left = mid;
            }
            // Can't be same.
            else
            {
                right = mid;
            }
        }
        while(left < right);

        // is (left + 1) best position?
        int bestPos = left + 1;
        if(left == mid)
            LogError("left is mid! (%d ==  %d)", left, mid);
        if(right == mid)
        {
            if(right == len)
            {
                bestPos = right - 1;
                this.Push(baseEnt);
            }
               
            else
                bestPos = right - 2;

            LogError("right is mid! (%d == %d -> %d)", right, mid, bestPos);
        }
            
        // this.Resize(len + 1);
        this.ShiftUp(bestPos);
        this.Set(bestPos, baseEnt);

        return bestPos;
    }
*/

    public int SearchEntityByRef(int entRef) 
    {
        int len = this.Length; 

        if(len == 0)        return -1;
        else if(len == 1)   return 0;

        if(entRef == view_as<FF2BaseEntity>(this.Get(0)).Ref)
            return 0;
        else if(view_as<FF2BaseEntity>(this.Get(len - 1)).Ref == entRef)
            return len - 1;

        int absRef = entRef & 0x7FFFFFFF,
            left = 0, right = len, mid;
        do
        {
            mid = ((left + (right - 1)) / 2) + 1;
            if(left == mid || right == mid || mid >= len)     break;
            
            int midRef = view_as<FF2BaseEntity>(this.Get(mid)).Ref & 0x7FFFFFFF;

            if(absRef > midRef)
            {
                left = mid;
            }
            else if(absRef == midRef)
            {
                return mid;
            }
            else
            {
                right = mid;
            }
        }
        while(left < right);

        // final check
        if(right == mid
            && view_as<FF2BaseEntity>(this.Get(right - 1)).Ref == entRef)
            return right - 1;
        else if(left == mid
            && view_as<FF2BaseEntity>(this.Get(left + 1)).Ref == entRef)
            return left + 1;

        return -1;
    }

    public void EraseEntity(int entRef)
    {
        int index = this.SearchEntityByRef(entRef);

        if(index >= 0)
        {
            this.Erase(index);
        }
    }

    public void PrintMe()
    {
        int len = this.Length;
        for(int loop = 0; loop < len; loop++)
        {
            LogError("%d: %X", loop, view_as<FF2BaseEntity>(this.Get(loop)).Ref);
        }
    }
}

// LOL. There is no prototype definition in SourcePawn.
// This is the best spot for define this, I think..
FF2BaseEntity_List g_hBaseEntityList;
FF2BaseEntity g_hBasePlayer[MAXPLAYERS+1];

enum
{
    FF2P_QueuePoints = 0,
    FF2P_MusicTimer,
    FF2P_CurrentMusicPath,
    // FF2P_MusicPacks
    
    FF2P_MAX_COUNT
};

methodmap FF2BasePlayer < FF2BaseEntity
{
    public FF2BasePlayer(int playerIndex)
    {
        FF2BaseEntity newArray = new FF2BaseEntity(EntIndexToEntRef(playerIndex));

        newArray.Push(0);
        newArray.Push(0);
        newArray.PushString("");
        newArray.Push(0);   // 
        
        return view_as<FF2BasePlayer>(newArray); 
    }

    property int QueuePoints {
        public get() {
            if(!IsClientInGame(this.Index))
                return -1;

            if(IsFakeClient(this.Index))
                return botqueuepoints;

            return this.Get(FF2BE_MAX_COUNT + FF2P_QueuePoints);
        }
        public set(int queuepoints) {
            if(!IsClientInGame(this.Index))
                return;
                
            if(!IsFakeClient(this.Index))
            {
                char buffer[12];
                IntToString(queuepoints, buffer, sizeof(buffer));
                SetClientCookie(this.Index, FF2Cookie_QueuePoints, buffer);
                this.Set(FF2BE_MAX_COUNT + FF2P_QueuePoints, queuepoints);
            }
        }
    }

    property Handle MusicTimer {
        public get() {
            return this.Get(FF2BE_MAX_COUNT + FF2P_MusicTimer);
        }
        public set(Handle timer) {
            this.Set(FF2BE_MAX_COUNT + FF2P_MusicTimer, timer);
        }
    }    

    public bool LoadPlayerData()
    {
        if(!AreClientCookiesCached(this.Index))     return false;

        char buffer[4];
        GetClientCookie(this.Index, FF2Cookie_QueuePoints, buffer, sizeof(buffer));
        if(!buffer[0])
        {
            SetClientCookie(this.Index, FF2Cookie_QueuePoints, "0");
        }

        this.QueuePoints = StringToInt(buffer);

        return true;
    }
}

/*
 * Currently, only client index is supported.
 * TODO: add case of other entities.
 */
FF2BaseEntity GetBaseByEntIndex(int ent)
{
    if(0 < ent && ent <= MaxClients)
        return g_hBasePlayer[ent];

    // search in list array
    int index = g_hBaseEntityList.SearchEntityByRef(EntIndexToEntRef(ent));
    if(index != -1)
        return g_hBaseEntityList.Get(index);

    return null;
}

FF2BasePlayer GetBasePlayer(int ent)
{
    return view_as<FF2BasePlayer>(GetBaseByEntIndex(ent));
}

/*
methodmap Example < ArrayList {
    property int ex {
        public get()
        {
            return 2;
        }
    }
}

methodmap Example2 < Example {
    public static void printtest()
    {
        PrintToServer(this.ex);
    } 

}
*/

// FF2SpecialInfo: 병과별 특수 변수 저장 (서브플러그인 호환)
// ㄴ 방패 인덱스, 우버 타켓, 폭발물 등
// 이게 왜 필요한가? 서브플러그인 간의 상호 호환

// FF2AbilityInfo: 보스의 능력 정보 (보스가 아니여도 이 정보만 있으면 능력을 사용할 수 있도록 함)
// FF2CharacterInfo: 보스의 캐릭터 정보