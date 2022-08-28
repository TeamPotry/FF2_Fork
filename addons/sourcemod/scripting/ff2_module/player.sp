// TODO: 클라이언트에 한해서는 인덱스를 통한 직접 접근 허용
// 기타 엔티티의 경우는 리스트화 하여 접근할 수 있도록 할 것

enum
{
    FF2BE_Ref = 0,

    FF2BE_Damage,
    FF2BE_LastNoticedDamage,
    FF2BE_Assist,
    
    FF2BE_Flags,

    // TODO: Add FF2SpecialInfo
    
    FF2BE_MAX_COUNT
};

/*
 * TODO: Not only player, include other entities
 * 
 * General Info about entities for FF2
 */
methodmap FF2BaseEntity < ArrayList
{
    public FF2BaseEntity(int entRef)
    {
        ArrayList newArray = new ArrayList();

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

// TODO: Replace this to Tree.
FF2BaseEntity g_hBaseEntity[MAXPLAYERS+1];

/*
 * Currently, only client index is supported.
 * TODO: add case of other entities.
 */
FF2BaseEntity GetBaseByEntIndex(int ent)
{
    if(ent <= MaxClients)
        return g_hBaseEntity[ent];

    return null;
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