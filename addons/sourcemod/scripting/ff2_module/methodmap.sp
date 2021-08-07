// ff2_module/music.sp
int muteSound[MAXPLAYERS+1];
bool playBGM[MAXPLAYERS+1]=true;
char currentBGM[MAXPLAYERS+1][PLATFORM_MAX_PATH];
Handle MusicTimer[MAXPLAYERS+1];
