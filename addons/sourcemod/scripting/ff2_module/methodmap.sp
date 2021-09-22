// ff2_module/music.sp
int muteSound[MAXPLAYERS+1];
bool playBGM[MAXPLAYERS+1]=true;
char currentBGM[MAXPLAYERS+1][PLATFORM_MAX_PATH];
char currentMusicPhase[MAXPLAYERS+1][64];
Handle MusicTimer[MAXPLAYERS+1];
