@echo on
copy /y C:\Users\Administrator\Documents\GitHub\FF2_Fork\addons\sourcemod\scripting C:\Users\Administrator\Desktop\Portal\sourcemod_lib
copy /y C:\Users\Administrator\Documents\GitHub\FF2_Fork\addons\sourcemod\scripting\ff2_module C:\Users\Administrator\Desktop\Portal\sourcemod_lib\ff2_module
copy /y C:\Users\Administrator\Documents\GitHub\FF2_Fork\addons\sourcemod\scripting\include C:\Users\Administrator\Desktop\Portal\sourcemod_lib\include

cd C:\Users\Administrator\Desktop\Portal\sourcemod_lib
spcomp ./freak_fortress_2.sp -o compiled/freak_fortress_2.smx
