int Incoming[MAXPLAYERS+1];

// int Damage[MAXPLAYERS+1];
// int LastNoticedDamage[MAXPLAYERS+1];
//int Assist[MAXPLAYERS+1];
int uberTarget[MAXPLAYERS+1];
int shield[MAXPLAYERS+1];
int detonations[MAXPLAYERS+1];
// int queuePoints[MAXPLAYERS+1];

int FF2Flags[MAXPLAYERS+1];

int BossHealthMax[MAXPLAYERS+1];
int BossHealth[MAXPLAYERS+1];
int BossHealthLast[MAXPLAYERS+1];
int BossLives[MAXPLAYERS+1];
int BossLivesMax[MAXPLAYERS+1];
int BossRageDamage[MAXPLAYERS+1];
float BossSpeed[MAXPLAYERS+1];
float BossCharge[MAXPLAYERS+1][8];
float BossMaxRageCharge[MAXPLAYERS+1];
float BossSkillDuration[MAXPLAYERS+1][3];

// ff2_module/music.sp
int muteSound[MAXPLAYERS+1];
bool playBGM[MAXPLAYERS+1] = {true, ...};
char currentBGM[MAXPLAYERS+1][PLATFORM_MAX_PATH];
char currentMusicPhase[MAXPLAYERS+1][64];
Handle MusicTimer[MAXPLAYERS+1];
