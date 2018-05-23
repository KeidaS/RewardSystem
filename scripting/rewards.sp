#pragma semicolon 1

#include <sourcemod>
#include <sdktools>


public Plugin myinfo = 
{
	name = "Time rewards",
	author = "KeidaS",
	description = "Rewards users with cosmetics elements",
	version = "1.0",
	url = "www.hermandadfenix.es"
};

Handle Tmenu = INVALID_HANDLE;
Handle CTmenu = INVALID_HANDLE;

Handle db = INVALID_HANDLE;



String:TerroristSkin[128][64];
String:TerroristArms[128][64];
String:CounterTerroristSkin[128][64];
String:CounterTerroristArms[128][64];

int hoursT[128];
int hoursCT[128];
int TSkinsCount;
int CTSkinsCount;

bool selected[MAXPLAYERS + 1];

int selectedSkin[MAXPLAYERS + 1];

int timePlayed[MAXPLAYERS + 1];

public void OnPluginStart() {
	RegConsoleCmd("rewards", Rewards);
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Post);
	ConnectDB();
}

public void ConnectDB() {
	char error[255];
	db = SQL_Connect("rankme", true, error, sizeof(error));
	
	if (db == INVALID_HANDLE) {
		LogError("ERROR CONNECTING TO THE DB"); 
	}
}

public void OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsFakeClient(client)) {
		if (IsClientInGame(client) && selected[client]) {
			CreateTimer(1.6, Timer_ChangeSkin, client);
		}
	}
}

public Action Timer_ChangeSkin(Handle time, any client) {
	int team = GetClientTeam(client);
	if (team == 2) { //T
		SetEntityModel(client, TerroristSkin[selectedSkin[client]]);
		SetEntPropString(client, Prop_Send, "m_szArmsModel", TerroristArms[selectedSkin[client]]);
	} else if (team == 3) { //CT
		SetEntityModel(client, CounterTerroristSkin[selectedSkin[client]]);
		SetEntPropString(client, Prop_Send, "m_szArmsModel", CounterTerroristArms[selectedSkin[client]]);
	}
}
public void OnClientPostAdminCheck(int client) {
	char query[254];
	char steamID[32];
	if (!IsFakeClient(client)) {
		GetClientAuthId(client, AuthId_Steam2, steamID, sizeof(steamID));
		Format(query, sizeof(query), "SELECT timeTotal FROM timerank WHERE steamid = '%s'", steamID);
		SQL_TQuery(db, OnClientPostAdminCheckCallback, query, GetClientUserId(client));
	}
}

public void OnClientPostAdminCheckCallback(Handle owner, Handle hndl, char[] error, any data) {
	int client = GetClientOfUserId(data);
	if (hndl == INVALID_HANDLE) {
		LogError("ERROR GETING THE TIME");
		LogError("%i", error);
	} else {
		SQL_FetchRow(hndl);
		timePlayed[client] = SQL_FetchInt(hndl, 0);
	}
}

public void OnMapStart() {
	decl String:file[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, file, sizeof(file), "configs/rewards/rewards.cfg");
	if (!FileExists(file)) {
		SetFailState("Error: Couldn't open configuration file rewards.cfg on /configs/rewards");
	}
	TSkinsCount = 0;
	CTSkinsCount = 0;
	PrepareMenu();
	Configure(file);
}

public Action Rewards (client, args) {
	if (!IsFakeClient(client)) {
		OnClientPostAdminCheck(client);
		if (IsClientInGame(client)) {
			int team = GetClientTeam(client);
			if (team == 2) { //T
				DisplayMenu(Tmenu, client, 20);
			} else if (team == 3) { //CT
				DisplayMenu(CTmenu, client, 20);
			}
		}
	}
}

public void PrepareMenu() {
	if (Tmenu != INVALID_HANDLE) {
		CloseHandle(Tmenu);
		Tmenu = INVALID_HANDLE;
	}
	if (CTmenu != INVALID_HANDLE) {
		CloseHandle(CTmenu);
		CTmenu = INVALID_HANDLE;
	}
	Tmenu = CreateMenu(MenuHandler_Skin, MenuAction_Select | MenuAction_Cancel | MenuAction_End);
	CTmenu = CreateMenu(MenuHandler_Skin, MenuAction_Select | MenuAction_Cancel | MenuAction_End);
	
	SetMenuTitle(Tmenu, "Reward Skins");
	SetMenuTitle(CTmenu, "Reward Skins");
}

public void Configure(const String:file[]) {
	new Handle:kv = CreateKeyValues("Skins");
	FileToKeyValues(kv, file);
	if (KvJumpToKey(kv, "Terrorists")) {
		decl String:section[128], String:skin[128], String:arms[128], String:skinId[3];
		KvGotoFirstSubKey(kv);
		do {
			KvGetSectionName(kv, section, sizeof(section));
			if (KvGetString(kv, "skin", skin, sizeof(skin)) && KvGetString(kv, "arms", arms, sizeof(arms)) && KvGetNum(kv, "hours")) {
				strcopy(TerroristSkin[TSkinsCount], sizeof(TerroristSkin[]), skin);
				strcopy(TerroristArms[TSkinsCount], sizeof(TerroristArms[]), arms);
				hoursT[TSkinsCount] = KvGetNum(kv, "hours");
				Format(skinId, sizeof(skinId), "%d", TSkinsCount);
				char item[128];
				Format(item, sizeof(item), "%s -> Requires %i hours played", section, hoursT[TSkinsCount]);
				TSkinsCount++;
				AddMenuItem(Tmenu, skinId, item);
				PrecacheModel(skin, true);
				PrecacheModel(arms, true);
			}
		}
		while (KvGotoNextKey(kv));
	}
	KvRewind(kv);
	if (KvJumpToKey(kv, "Counter-Terrorists")) {
		decl String:section[128], String:skin[128], String:arms[128], String:skinId[3];
		KvGotoFirstSubKey(kv);
		do {
			KvGetSectionName(kv, section, sizeof(section));
			if (KvGetString(kv, "skin", skin, sizeof(skin)) && KvGetString(kv, "arms", arms, sizeof(arms)) && KvGetNum(kv, "hours")) {
				strcopy(CounterTerroristSkin[CTSkinsCount], sizeof(CounterTerroristSkin[]), skin);
				strcopy(CounterTerroristArms[CTSkinsCount], sizeof(CounterTerroristArms[]), arms);
				hoursCT[CTSkinsCount] = KvGetNum(kv, "hours");
				Format(skinId, sizeof(skinId), "%d", CTSkinsCount);
				char item[128];
				Format(item, sizeof(item), "%s -> Requires %i hours played", section, hoursCT[CTSkinsCount]);
				CTSkinsCount++;
				AddMenuItem(CTmenu, skinId, item);
				PrecacheModel(skin, true);
				PrecacheModel(arms, true);
			}
		}
		while (KvGotoNextKey(kv));
	}
	KvRewind(kv);
	CloseHandle(kv);
}

public int MenuHandler_Skin(Menu menu, MenuAction action, int param1, int param2) {
	if (action == MenuAction_Select) {
		char skinId[10];
		GetMenuItem(menu, param2, skinId, sizeof(skinId));
		int skin = StringToInt(skinId);
		selectedSkin[param1] = skin;
		int team = GetClientTeam(param1);
		if (team == 2) { //T
			if (timePlayed[param1] >= hoursT[skin] * 3600) {
				SetEntityModel(param1, TerroristSkin[skin]);
				SetEntPropString(param1, Prop_Send, "m_szArmsModel", TerroristArms[skin]);
				selected[param1] = true;
			} else {
				PrintToChat(param1, "You have to play at least %i hours to use that skin. You have %i hours played. Check !rank for more info.", hoursT[skin], timePlayed[param1] / 3600);
			}
		} else if (team == 3) { //CT
			if (timePlayed[param1] >= hoursCT[skin] * 3600) {
				SetEntityModel(param1, CounterTerroristSkin[skin]);
				SetEntPropString(param1, Prop_Send, "m_szArmsModel", CounterTerroristArms[skin]);
				selected[param1] = true;
			} else {
				PrintToChat(param1, "You have to play at least %i hours to use that skin. You have %i hours played. Check !rank for more info.", hoursCT[skin], timePlayed[param1] / 3600);
			}
		}
	}
}

public void OnMapEnd() {
	for (int i = 1; i < MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i)) {
			timePlayed[i] = 0;
			selected[i] = false;
		}
	}
}

public void OnClientDisconnect(int client) {
	timePlayed[client] = 0;
	selected[client] = false;
}