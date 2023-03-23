#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <clientprefs>

Menu g_mShortcutsMenu;

ConVar g_cConfigPath;

float g_bQuickMenuPressLength[MAXPLAYERS+1] = {0.1, ...};
bool g_bQuickMenuOpened[MAXPLAYERS+1], g_bQuickMenuStatus[MAXPLAYERS+1];
Handle g_cQuickMenu_Cookie = INVALID_HANDLE, g_cQuickMenu_PressLength = INVALID_HANDLE;

public Plugin myinfo = {
	name = "GCG Shortcuts Menu",
	author = "Lerrdy",
	description = "Adds a Shortcuts menu on shift press with client customizability",
	version = "0.1",
	url = "https://ghostcap.com"
};

public void OnPluginStart() {
	g_cConfigPath = CreateConVar("sm_quickmenu_config_path", "addons/sourcemod/configs/shortcuts_menu.cfg", "The path to the config file. (Root in csgo/)");

	g_cQuickMenu_Cookie = RegClientCookie("gcg_quickmenu_status", "Status of QuickMenu", CookieAccess_Protected);
	g_cQuickMenu_PressLength = RegClientCookie("gcg_quickmenu_press_length", "Length of the Shift Press required to open the QuickMenu", CookieAccess_Protected);

	SetCookieMenuItem(PrefMenu, 0, "Quickmenu Settings");
	
	RegConsoleCmd("sm_shiftmenu", MenuQuickSettings, "Opens Quickmenu settings.");
	RegConsoleCmd("sm_quickmenu", MenuQuickSettings, "Opens Quickmenu settings.");
	
	for (int i = 1; i <= MaxClients; i++) {
		if (AreClientCookiesCached(i))
			OnClientCookiesCached(i);
	}
	
	AutoExecConfig();
}

public void OnClientConnected(int client) {
	g_bQuickMenuOpened[client] = false;
}

public void OnClientCookiesCached(int client) {
	char sValue[8];
	
	GetClientCookie(client, g_cQuickMenu_Cookie, sValue, sizeof(sValue));
	if (sValue[0] == '\0') {
		SetClientCookie(client, g_cQuickMenu_Cookie, "1");
		strcopy(sValue, sizeof(sValue), "1");
	}
	g_bQuickMenuStatus[client] = view_as<bool>(StringToInt(sValue));
	
	GetClientCookie(client, g_cQuickMenu_PressLength, sValue, sizeof(sValue));
	if (sValue[0] == '\0') {
		SetClientCookie(client, g_cQuickMenu_PressLength, "5");
		strcopy(sValue, sizeof(sValue), "5");
	}
	g_bQuickMenuPressLength[client] = view_as<float>(StringToFloat(sValue));
}

public void OnMapStart() {
	delete g_mShortcutsMenu;
	
	// Find the Config
	char sConfigPath[PLATFORM_MAX_PATH];
	g_cConfigPath.GetString(sConfigPath, sizeof(sConfigPath));
	
	if (!FileExists(sConfigPath))
		SetFailState("The quickmenu configuration file is not present.");
		
	KeyValues kv = CreateKeyValues("Shortcuts");
	
	if (!kv.ImportFromFile(sConfigPath) || !kv.GotoFirstSubKey(false))
		SetFailState("The quickmenu configuration file is improperly formatted.");

	g_mShortcutsMenu = new Menu(ShortcutsMenu_Handler, MenuAction_Select);
	g_mShortcutsMenu.SetTitle("Quickmenu\n ");
	
	char sDisplay[64], sCommand[64];
	do {
		kv.GetSectionName(sDisplay, sizeof(sDisplay));

		kv.GetString(NULL_STRING, sCommand, sizeof(sCommand));
		
		g_mShortcutsMenu.AddItem(sCommand, sDisplay);
	} while (kv.GotoNextKey(false));
	
	delete kv;
}

int ShortcutsMenu_Handler(Menu menu, MenuAction action, int param1, int param2) {
	switch(action) {
		case MenuAction_Cancel: g_bQuickMenuOpened[param1] = false;
		case MenuAction_Select: {
			char sCommand[64];
			
			menu.GetItem(param2, sCommand, sizeof(sCommand));
			
			FakeClientCommand(param1, sCommand);
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]) {
	if (g_bQuickMenuStatus[client]) {
		static bool bHoldingWalk[MAXPLAYERS + 1];
		static float fTimePressed[MAXPLAYERS + 1];
		if(buttons & IN_SPEED) {
			if (!bHoldingWalk[client]) {
				bHoldingWalk[client] = true;
				fTimePressed[client] = GetEngineTime();
			}
		} else if (bHoldingWalk[client]) {
			bHoldingWalk[client] = false;
			if (fTimePressed[client] + (g_bQuickMenuPressLength[client] / 10) > GetEngineTime()) {
				if (!g_bQuickMenuOpened[client]) {
					g_mShortcutsMenu.Display(client, MENU_TIME_FOREVER);
					g_bQuickMenuOpened[client] = true;
				} else {
					InternalShowMenu(client, "\10", 1);
					CancelClientMenu(client, true, null);
					g_bQuickMenuOpened[client] = false;
				}
			}
		}
	}
}

public void PrefMenu(int client, CookieMenuAction actions, any info, char[] buffer, int maxlen) {
	if (actions == CookieMenuAction_SelectOption) {
		MenuQuickSettings(client, 0);
	}
}

public Action MenuQuickSettings(int client, int args) {
	Menu menu = new Menu(MenuQuickSettingsHandler);
	char sTranslate[128];
	Format(sTranslate, sizeof(sTranslate), " ุ  ุ  ุ Quickmenu Settings\n ");
	menu.SetTitle(sTranslate);
	
	Format(sTranslate, sizeof(sTranslate), "Quickmenu is currently:\n %s\n ", g_bQuickMenuStatus[client] ? "Enabled" : "Disabled", client);
	menu.AddItem("disable", sTranslate);
	
	if (g_bQuickMenuStatus[client]) {
		if (g_bQuickMenuPressLength[client] == 10)
			Format(sTranslate, sizeof(sTranslate), "Shift press length:\n 1.0s");
		else
			Format(sTranslate, sizeof(sTranslate), "Shift press length:\n 0.%.0fs", g_bQuickMenuPressLength[client]);
			
		switch (g_bQuickMenuPressLength[client] / 10.0) {
			case 0.1: menu.AddItem("len_2", sTranslate);
			case 0.2: menu.AddItem("len_3", sTranslate);
			case 0.3: menu.AddItem("len_4", sTranslate);
			case 0.4: menu.AddItem("len_5", sTranslate);
			case 0.5: menu.AddItem("len_6", sTranslate);
			case 0.6: menu.AddItem("len_7", sTranslate);
			case 0.7: menu.AddItem("len_8", sTranslate);
			case 0.8: menu.AddItem("len_9", sTranslate);
			case 0.9: menu.AddItem("len_10", sTranslate);
			case 1.0: menu.AddItem("len_1", sTranslate);
			default: menu.AddItem("len_1", sTranslate);
		}
	}
	
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, 20);
}

public int MenuQuickSettingsHandler(Menu hMenu, MenuAction hAction, int iClient, int iParam2) {
	switch(hAction) {
		case MenuAction_End: delete hMenu;
		case MenuAction_Cancel: if(iParam2 == MenuCancel_ExitBack) ShowCookieMenu(iClient);
		case MenuAction_Select: {
			char sOption[8];
			hMenu.GetItem(iParam2, sOption, sizeof(sOption));
			if(StrContains(sOption, "len") >= 0) {
				g_bQuickMenuPressLength[iClient] = StringToFloat(sOption[4]);
				SetClientCookie(iClient, g_cQuickMenu_PressLength, sOption[4]);
				if (g_bQuickMenuPressLength[iClient] == 10)
					PrintToChat(iClient, "Quickmenu is now Enabled! Shift press length is 1.0s");
				else
					PrintToChat(iClient, "Quickmenu is now Enabled! Shift press length is 0.%.0fs", g_bQuickMenuPressLength[iClient]);
				MenuQuickSettings(iClient, 0);
			} else if (StrEqual(sOption, "disable")) {
				ToggleQuickMenu(iClient, 0);
				MenuQuickSettings(iClient, 0);
			}
		}
	}
}

public Action ToggleQuickMenu(int client, int args) {
	char sValue[8];
	g_bQuickMenuStatus[client] = !g_bQuickMenuStatus[client];
	
	PrintToChat(client, "Quickmenu is now %s!", g_bQuickMenuStatus[client] ? "Enabled" : "Disabled");
	
	Format(sValue, sizeof(sValue), "%i", g_bQuickMenuStatus[client]);
	SetClientCookie(client, g_cQuickMenu_Cookie, sValue);
	
	return Plugin_Handled;
}
