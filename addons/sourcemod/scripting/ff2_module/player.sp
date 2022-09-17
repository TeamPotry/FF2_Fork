Handle FF2Cookie_QueuePoints;

int botqueuepoints;

// TODO: 클라이언트에 한해서는 인덱스를 통한 직접 접근 허용
// 기타 엔티티의 경우는 리스트화 하여 접근할 수 있도록 할 것

enum
{
    FF2BE_Ref = 0,
    FF2BE_Index,

    FF2BE_Damage,
    FF2BE_LastNoticedDamage,
    FF2BE_Assist,
    
    FF2BE_Flags,

    // TODO: Add FF2SpecialInfo
    
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