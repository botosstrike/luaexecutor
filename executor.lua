#include <windows.h>
#include <iostream>
#include <functional>
 
#include "MinHook.h"
 
const uintptr_t g_scriptingBase = (uintptr_t)GetModuleHandleA("citizen-scripting-lua.dll");
 
typedef struct lua_State lua_State;
typedef intptr_t lua_KContext;
typedef int (*lua_KFunction)(lua_State* L, int status, lua_KContext ctx);
 
typedef int(__fastcall* luaL_loadbufferxProto)(lua_State* L, const char* buff, size_t sz, const char* name, const char* mode);
typedef lua_State*(__fastcall* lua_newthreadProto)(lua_State *L);
typedef int(__fastcall* lua_pcallkProto)(lua_State *L, int nargs, int nresults, int errfunc, lua_KContext ctx, lua_KFunction k);
typedef void(__fastcall* lua_settopProto)(lua_State *L, int idx);
typedef const char*(__fastcall* lua_tolstringProto)(lua_State *L, int idx, size_t *len);
//
typedef int(__fastcall* LuaScriptRuntime__RunFileInternalProto)(uint64_t _this, const char* scriptName, std::function<int(const char*)> loadFunction);
 
const auto lua_settop =			(lua_settopProto)		(g_scriptingBase + 0x21DE0);
const auto lua_pcallk =			(lua_pcallkProto)		(g_scriptingBase + 0x211E0);
const auto lua_newthread =		(lua_newthreadProto)	(g_scriptingBase + 0x20020);
const auto luaL_loadbufferx =	(luaL_loadbufferxProto)	(g_scriptingBase + 0x22F50);
const auto lua_tolstring =		(lua_tolstringProto)	(g_scriptingBase + 0x220D0);
//
const auto LuaScriptRuntime__RunFileInternal = (LuaScriptRuntime__RunFileInternalProto)(g_scriptingBase + 0x107A0);
 
#define lua_pcall(L,n,r,f) lua_pcallk(L, (n), (r), (f), 0, NULL)
#define luaL_loadbuffer(L,s,sz,n) luaL_loadbufferx(L,s,sz,n,NULL)
#define lua_pop(L,n) lua_settop(L, -(n)-1)
#define LUA_MULTRET	(-1)
 
LuaScriptRuntime__RunFileInternalProto LuaScriptRuntime__RunFileInternalPtr = nullptr;
luaL_loadbufferxProto luaL_loadbufferxPtr = nullptr;
 
lua_State* g_state = nullptr;
 
int LuaScriptRuntime__RunFileInternalDetour(uintptr_t _this, const char* scriptName, std::function<int(const char*)> loadFunction) {
	g_state = *(lua_State**)(_this + 0x30);
	return LuaScriptRuntime__RunFileInternalPtr(_this, scriptName, loadFunction);
}
 
void createConsole(const char* title) {
	AllocConsole();
	SetConsoleTitleA(title);
 
	freopen_s((FILE**)stdin, "conin$", "r", stdin);
	freopen_s((FILE**)stdout, "conout$", "w", stdout);
}
 
DWORD WINAPI tmain(LPVOID lpParam) {
	createConsole("FiveM Script Executor - Created by Desudo @ unknowncheats.me");
 
	MH_Initialize();
 
	MH_CreateHook(LuaScriptRuntime__RunFileInternal, &LuaScriptRuntime__RunFileInternalDetour, (LPVOID*)&LuaScriptRuntime__RunFileInternalPtr);
	MH_EnableHook(LuaScriptRuntime__RunFileInternal);
 
	char buffer[4096];
	DWORD dwRead;
	HANDLE pipe = CreateNamedPipeA("\\\\.\\pipe\\FivePipe",
		PIPE_ACCESS_DUPLEX,
		PIPE_TYPE_MESSAGE | PIPE_READMODE_MESSAGE | PIPE_WAIT,
		1,
		sizeof(buffer) * 16,
		sizeof(buffer) * 16,
		NMPWAIT_USE_DEFAULT_WAIT,
		NULL);
	while (pipe != INVALID_HANDLE_VALUE) {
		if (ConnectNamedPipe(pipe, nullptr)) {
			while (ReadFile(pipe, buffer, sizeof(buffer) - 1, &dwRead, nullptr)) {
				if (g_state) {
					buffer[dwRead] = '\0';
 
					lua_State* L = lua_newthread(g_state);
 
					std::string script = "Citizen.CreateThread(function() ";
					script += buffer;
					script += " end)";
 
					if (luaL_loadbuffer(L, script.c_str(), script.length(), "t") || lua_pcall(L, 0, LUA_MULTRET, 0)) {
						// Todo: Error output?
					}
				} else {
					MessageBoxA(NULL, "g_state was invalid, are you in a game?", NULL, MB_OK);
				}
			}
		}
 
		DisconnectNamedPipe(pipe);
	}
 
	return 0;
}
 
BOOL APIENTRY DllMain(HMODULE hModule, DWORD dwReason, LPVOID lpReserved) {
	switch (dwReason) {
	case DLL_PROCESS_ATTACH:
		DisableThreadLibraryCalls(hModule);
		CreateThread(NULL, 0, tmain, NULL, 0, NULL);
		break;
 
	case DLL_PROCESS_DETACH:
		break;
 
	default:
		break;
	}
 
	return TRUE;
}
