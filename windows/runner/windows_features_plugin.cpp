#define FLUTTER_PLUGIN_IMPL
#include "windows_features_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <windows.h>
#include <shlobj.h>
#include <shlwapi.h>
#include <winreg.h>
#include <wtsapi32.h>
#include <taskschd.h>
#include <comdef.h>
#include <comutil.h>
#include <winspool.h>
#include <psapi.h>
#include <memory>
#include <sstream>
#include <string>
#include <vector>

#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "wtsapi32.lib")
#pragma comment(lib, "advapi32.lib")
#pragma comment(lib, "winspool.lib")
#pragma comment(lib, "psapi.lib")

namespace {

// Windows Features Plugin implementation
class WindowsFeaturesPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  WindowsFeaturesPlugin();

  virtual ~WindowsFeaturesPlugin();

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Toast notification methods
  void ShowToastNotification(
      const flutter::EncodableMap& args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Registry methods
  void ReadRegistryValue(
      const flutter::EncodableMap& args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  
  void WriteRegistryValue(
      const flutter::EncodableMap& args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Event logging methods
  void WriteEventLog(
      const flutter::EncodableMap& args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Task scheduler methods
  void CreateScheduledTask(
      const flutter::EncodableMap& args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // File association methods
  void RegisterFileAssociation(
      const flutter::EncodableMap& args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Jump list methods
  void UpdateJumpList(
      const flutter::EncodableMap& args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Print queue methods
  void GetPrintQueue(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Security methods
  void RequestUACElevation(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Performance methods
  void GetPerformanceCounters(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

// static
void WindowsFeaturesPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "windows_features",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<WindowsFeaturesPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

WindowsFeaturesPlugin::WindowsFeaturesPlugin() {}

WindowsFeaturesPlugin::~WindowsFeaturesPlugin() {}

void WindowsFeaturesPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto& method = method_call.method_name();
  const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());

  if (method == "showToastNotification") {
    if (args) {
      ShowToastNotification(*args, std::move(result));
    } else {
      result->Error("INVALID_ARGS", "Arguments required");
    }
  } else if (method == "readRegistryValue") {
    if (args) {
      ReadRegistryValue(*args, std::move(result));
    } else {
      result->Error("INVALID_ARGS", "Arguments required");
    }
  } else if (method == "writeRegistryValue") {
    if (args) {
      WriteRegistryValue(*args, std::move(result));
    } else {
      result->Error("INVALID_ARGS", "Arguments required");
    }
  } else if (method == "writeEventLog") {
    if (args) {
      WriteEventLog(*args, std::move(result));
    } else {
      result->Error("INVALID_ARGS", "Arguments required");
    }
  } else if (method == "createScheduledTask") {
    if (args) {
      CreateScheduledTask(*args, std::move(result));
    } else {
      result->Error("INVALID_ARGS", "Arguments required");
    }
  } else if (method == "registerFileAssociation") {
    if (args) {
      RegisterFileAssociation(*args, std::move(result));
    } else {
      result->Error("INVALID_ARGS", "Arguments required");
    }
  } else if (method == "updateJumpList") {
    if (args) {
      UpdateJumpList(*args, std::move(result));
    } else {
      result->Error("INVALID_ARGS", "Arguments required");
    }
  } else if (method == "getPrintQueue") {
    GetPrintQueue(std::move(result));
  } else if (method == "requestUACElevation") {
    RequestUACElevation(std::move(result));
  } else if (method == "getPerformanceCounters") {
    GetPerformanceCounters(std::move(result));
  } else {
    result->NotImplemented();
  }
}

void WindowsFeaturesPlugin::ShowToastNotification(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  try {
    auto title_it = args.find(flutter::EncodableValue("title"));
    auto message_it = args.find(flutter::EncodableValue("message"));
    
    if (title_it == args.end() || message_it == args.end()) {
      result->Error("INVALID_ARGS", "Title and message required");
      return;
    }

    std::string title = std::get<std::string>(title_it->second);
    std::string message = std::get<std::string>(message_it->second);

    // Convert to wide strings
    int title_len = MultiByteToWideChar(CP_UTF8, 0, title.c_str(), -1, nullptr, 0);
    std::wstring wtitle(title_len, 0);
    MultiByteToWideChar(CP_UTF8, 0, title.c_str(), -1, &wtitle[0], title_len);

    int msg_len = MultiByteToWideChar(CP_UTF8, 0, message.c_str(), -1, nullptr, 0);
    std::wstring wmessage(msg_len, 0);
    MultiByteToWideChar(CP_UTF8, 0, message.c_str(), -1, &wmessage[0], msg_len);

    // Use MessageBox for now (can be upgraded to toast notifications later)
    MessageBox(nullptr, wmessage.c_str(), wtitle.c_str(), MB_OK | MB_ICONINFORMATION);
    
    result->Success(flutter::EncodableValue(true));
  } catch (...) {
    result->Error("TOAST_ERROR", "Failed to show notification");
  }
}

void WindowsFeaturesPlugin::ReadRegistryValue(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  try {
    auto key_it = args.find(flutter::EncodableValue("key"));
    auto value_it = args.find(flutter::EncodableValue("value"));
    auto hive_it = args.find(flutter::EncodableValue("hive"));

    if (key_it == args.end() || value_it == args.end()) {
      result->Error("INVALID_ARGS", "Key and value required");
      return;
    }

    std::string key = std::get<std::string>(key_it->second);
    std::string value = std::get<std::string>(value_it->second);
    std::string hive_str = "HKEY_CURRENT_USER";
    if (hive_it != args.end()) {
      hive_str = std::get<std::string>(hive_it->second);
    }

    HKEY hkey = HKEY_CURRENT_USER;
    if (hive_str == "HKEY_LOCAL_MACHINE") {
      hkey = HKEY_LOCAL_MACHINE;
    }

    // Convert key to wide string
    int key_len = MultiByteToWideChar(CP_UTF8, 0, key.c_str(), -1, nullptr, 0);
    std::wstring wkey(key_len, 0);
    MultiByteToWideChar(CP_UTF8, 0, key.c_str(), -1, &wkey[0], key_len);

    int val_len = MultiByteToWideChar(CP_UTF8, 0, value.c_str(), -1, nullptr, 0);
    std::wstring wvalue(val_len, 0);
    MultiByteToWideChar(CP_UTF8, 0, value.c_str(), -1, &wvalue[0], val_len);

    HKEY reg_key;
    LONG ret = RegOpenKeyEx(hkey, wkey.c_str(), 0, KEY_READ, &reg_key);
    if (ret != ERROR_SUCCESS) {
      result->Success(flutter::EncodableValue());
      return;
    }

    DWORD data_type;
    DWORD data_size = 0;
    ret = RegQueryValueEx(reg_key, wvalue.c_str(), nullptr, &data_type, nullptr, &data_size);
    
    if (ret == ERROR_SUCCESS && data_size > 0) {
      std::vector<BYTE> buffer(data_size);
      ret = RegQueryValueEx(reg_key, wvalue.c_str(), nullptr, &data_type, buffer.data(), &data_size);
      
      if (ret == ERROR_SUCCESS) {
        if (data_type == REG_SZ || data_type == REG_EXPAND_SZ) {
          std::wstring wstr(reinterpret_cast<wchar_t*>(buffer.data()));
          int utf8_len = WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), -1, nullptr, 0, nullptr, nullptr);
          std::string utf8_str(utf8_len, 0);
          WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), -1, &utf8_str[0], utf8_len, nullptr, nullptr);
          result->Success(flutter::EncodableValue(utf8_str));
        } else if (data_type == REG_DWORD) {
          DWORD dw_value = *reinterpret_cast<DWORD*>(buffer.data());
          result->Success(flutter::EncodableValue(static_cast<int32_t>(dw_value)));
        } else {
          result->Success(flutter::EncodableValue());
        }
      } else {
        result->Success(flutter::EncodableValue());
      }
    } else {
      result->Success(flutter::EncodableValue());
    }

    RegCloseKey(reg_key);
  } catch (...) {
    result->Error("REGISTRY_ERROR", "Failed to read registry value");
  }
}

void WindowsFeaturesPlugin::WriteRegistryValue(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  try {
    auto key_it = args.find(flutter::EncodableValue("key"));
    auto value_it = args.find(flutter::EncodableValue("value"));
    auto data_it = args.find(flutter::EncodableValue("data"));
    auto hive_it = args.find(flutter::EncodableValue("hive"));

    if (key_it == args.end() || value_it == args.end() || data_it == args.end()) {
      result->Error("INVALID_ARGS", "Key, value, and data required");
      return;
    }

    std::string key = std::get<std::string>(key_it->second);
    std::string value = std::get<std::string>(value_it->second);
    std::string hive_str = "HKEY_CURRENT_USER";
    if (hive_it != args.end()) {
      hive_str = std::get<std::string>(hive_it->second);
    }

    HKEY hkey = HKEY_CURRENT_USER;
    if (hive_str == "HKEY_LOCAL_MACHINE") {
      hkey = HKEY_LOCAL_MACHINE;
    }

    // Convert to wide strings
    int key_len = MultiByteToWideChar(CP_UTF8, 0, key.c_str(), -1, nullptr, 0);
    std::wstring wkey(key_len, 0);
    MultiByteToWideChar(CP_UTF8, 0, key.c_str(), -1, &wkey[0], key_len);

    int val_len = MultiByteToWideChar(CP_UTF8, 0, value.c_str(), -1, nullptr, 0);
    std::wstring wvalue(val_len, 0);
    MultiByteToWideChar(CP_UTF8, 0, value.c_str(), -1, &wvalue[0], val_len);

    HKEY reg_key;
    LONG ret = RegCreateKeyEx(hkey, wkey.c_str(), 0, nullptr, REG_OPTION_NON_VOLATILE,
                              KEY_WRITE, nullptr, &reg_key, nullptr);
    if (ret != ERROR_SUCCESS) {
      result->Error("REGISTRY_ERROR", "Failed to create/open registry key");
      return;
    }

    const auto& data = data_it->second;
    if (std::holds_alternative<std::string>(data)) {
      std::string str_data = std::get<std::string>(data);
      int data_len = MultiByteToWideChar(CP_UTF8, 0, str_data.c_str(), -1, nullptr, 0);
      std::wstring wdata(data_len, 0);
      MultiByteToWideChar(CP_UTF8, 0, str_data.c_str(), -1, &wdata[0], data_len);
      ret = RegSetValueEx(reg_key, wvalue.c_str(), 0, REG_SZ,
                          reinterpret_cast<const BYTE*>(wdata.c_str()),
                          static_cast<DWORD>((wdata.length() + 1) * sizeof(wchar_t)));
    } else if (std::holds_alternative<int32_t>(data)) {
      DWORD dw_value = static_cast<DWORD>(std::get<int32_t>(data));
      ret = RegSetValueEx(reg_key, wvalue.c_str(), 0, REG_DWORD,
                          reinterpret_cast<const BYTE*>(&dw_value), sizeof(DWORD));
    } else {
      RegCloseKey(reg_key);
      result->Error("INVALID_ARGS", "Unsupported data type");
      return;
    }

    RegCloseKey(reg_key);
    result->Success(flutter::EncodableValue(ret == ERROR_SUCCESS));
  } catch (...) {
    result->Error("REGISTRY_ERROR", "Failed to write registry value");
  }
}

void WindowsFeaturesPlugin::WriteEventLog(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  try {
    auto message_it = args.find(flutter::EncodableValue("message"));
    auto level_it = args.find(flutter::EncodableValue("level"));

    if (message_it == args.end()) {
      result->Error("INVALID_ARGS", "Message required");
      return;
    }

    std::string message = std::get<std::string>(message_it->second);
    std::string level = "INFO";
    if (level_it != args.end()) {
      level = std::get<std::string>(level_it->second);
    }

    WORD event_type = EVENTLOG_INFORMATION_TYPE;
    if (level == "ERROR") {
      event_type = EVENTLOG_ERROR_TYPE;
    } else if (level == "WARNING") {
      event_type = EVENTLOG_WARNING_TYPE;
    }

    HANDLE h_event_log = RegisterEventSource(nullptr, L"offline_pos_system");
    if (h_event_log) {
      int msg_len = MultiByteToWideChar(CP_UTF8, 0, message.c_str(), -1, nullptr, 0);
      std::wstring wmessage(msg_len, 0);
      MultiByteToWideChar(CP_UTF8, 0, message.c_str(), -1, &wmessage[0], msg_len);

      LPCWSTR strings[] = { wmessage.c_str() };
      ReportEvent(h_event_log, event_type, 0, 0, nullptr, 1, 0, strings, nullptr);
      DeregisterEventSource(h_event_log);
      result->Success(flutter::EncodableValue(true));
    } else {
      result->Error("EVENT_LOG_ERROR", "Failed to register event source");
    }
  } catch (...) {
    result->Error("EVENT_LOG_ERROR", "Failed to write event log");
  }
}

void WindowsFeaturesPlugin::CreateScheduledTask(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // Task scheduler implementation would go here
  // This is complex and requires COM initialization
  result->Error("NOT_IMPLEMENTED", "Task scheduler not yet implemented");
}

void WindowsFeaturesPlugin::RegisterFileAssociation(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  try {
    auto ext_it = args.find(flutter::EncodableValue("extension"));
    auto prog_it = args.find(flutter::EncodableValue("progId"));

    if (ext_it == args.end() || prog_it == args.end()) {
      result->Error("INVALID_ARGS", "Extension and progId required");
      return;
    }

    std::string ext = std::get<std::string>(ext_it->second);
    std::string prog_id = std::get<std::string>(prog_it->second);

    // Convert to wide strings
    int ext_len = MultiByteToWideChar(CP_UTF8, 0, ext.c_str(), -1, nullptr, 0);
    std::wstring wext(ext_len, 0);
    MultiByteToWideChar(CP_UTF8, 0, ext.c_str(), -1, &wext[0], ext_len);

    int prog_len = MultiByteToWideChar(CP_UTF8, 0, prog_id.c_str(), -1, nullptr, 0);
    std::wstring wprog_id(prog_len, 0);
    MultiByteToWideChar(CP_UTF8, 0, prog_id.c_str(), -1, &wprog_id[0], prog_len);

    // Get executable path
    wchar_t exe_path[MAX_PATH];
    GetModuleFileName(nullptr, exe_path, MAX_PATH);

    std::wstring ext_key = L"Software\\Classes\\." + wext;
    std::wstring prog_key = L"Software\\Classes\\" + wprog_id;
    std::wstring shell_key = prog_key + L"\\shell\\open\\command";

    HKEY hkey;
    LONG ret;

    // Register extension
    ret = RegCreateKeyEx(HKEY_CURRENT_USER, ext_key.c_str(), 0, nullptr,
                         REG_OPTION_NON_VOLATILE, KEY_WRITE, nullptr, &hkey, nullptr);
    if (ret == ERROR_SUCCESS) {
      RegSetValue(hkey, nullptr, REG_SZ, wprog_id.c_str(), 0);
      RegCloseKey(hkey);
    }

    // Register program ID
    ret = RegCreateKeyEx(HKEY_CURRENT_USER, prog_key.c_str(), 0, nullptr,
                         REG_OPTION_NON_VOLATILE, KEY_WRITE, nullptr, &hkey, nullptr);
    if (ret == ERROR_SUCCESS) {
      RegSetValue(hkey, nullptr, REG_SZ, L"POS System File", 0);
      RegCloseKey(hkey);
    }

    // Register shell command
    ret = RegCreateKeyEx(HKEY_CURRENT_USER, shell_key.c_str(), 0, nullptr,
                         REG_OPTION_NON_VOLATILE, KEY_WRITE, nullptr, &hkey, nullptr);
    if (ret == ERROR_SUCCESS) {
      std::wstring command = std::wstring(L"\"") + exe_path + L"\" \"%1\"";
      RegSetValue(hkey, nullptr, REG_SZ, command.c_str(), 0);
      RegCloseKey(hkey);
      result->Success(flutter::EncodableValue(true));
    } else {
      result->Error("FILE_ASSOC_ERROR", "Failed to register file association");
    }
  } catch (...) {
    result->Error("FILE_ASSOC_ERROR", "Failed to register file association");
  }
}

void WindowsFeaturesPlugin::UpdateJumpList(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // Jump list implementation would go here
  // This requires COM and Windows 7+ APIs
  result->Error("NOT_IMPLEMENTED", "Jump list not yet implemented");
}

void WindowsFeaturesPlugin::GetPrintQueue(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  try {
    flutter::EncodableList printers;
    
    DWORD needed, returned;
    EnumPrinters(PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS, nullptr, 2, nullptr, 0, &needed, &returned);
    
    if (needed > 0) {
      std::vector<BYTE> buffer(needed);
      if (EnumPrinters(PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS, nullptr, 2,
                       buffer.data(), needed, &needed, &returned)) {
        PRINTER_INFO_2* printer_info = reinterpret_cast<PRINTER_INFO_2*>(buffer.data());
        
        for (DWORD i = 0; i < returned; i++) {
          flutter::EncodableMap printer;
          
          // Convert printer name
          int name_len = WideCharToMultiByte(CP_UTF8, 0, printer_info[i].pPrinterName, -1, nullptr, 0, nullptr, nullptr);
          std::string name(name_len, 0);
          WideCharToMultiByte(CP_UTF8, 0, printer_info[i].pPrinterName, -1, &name[0], name_len, nullptr, nullptr);
          
          printer[flutter::EncodableValue("name")] = flutter::EncodableValue(name);
          printer[flutter::EncodableValue("status")] = flutter::EncodableValue(static_cast<int32_t>(printer_info[i].Status));
          printer[flutter::EncodableValue("jobs")] = flutter::EncodableValue(static_cast<int32_t>(printer_info[i].cJobs));
          
          if (printer_info[i].pPortName) {
            int port_len = WideCharToMultiByte(CP_UTF8, 0, printer_info[i].pPortName, -1, nullptr, 0, nullptr, nullptr);
            std::string port(port_len, 0);
            WideCharToMultiByte(CP_UTF8, 0, printer_info[i].pPortName, -1, &port[0], port_len, nullptr, nullptr);
            printer[flutter::EncodableValue("port")] = flutter::EncodableValue(port);
          }
          
          printers.push_back(flutter::EncodableValue(printer));
        }
      }
    }
    
    result->Success(flutter::EncodableValue(printers));
  } catch (...) {
    result->Error("PRINT_QUEUE_ERROR", "Failed to get print queue");
  }
}

void WindowsFeaturesPlugin::RequestUACElevation(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // UAC elevation requires manifest changes
  result->Error("NOT_IMPLEMENTED", "UAC elevation requires manifest configuration");
}

void WindowsFeaturesPlugin::GetPerformanceCounters(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  try {
    flutter::EncodableMap counters;
    
    // Get memory info
    MEMORYSTATUSEX mem_info;
    mem_info.dwLength = sizeof(MEMORYSTATUSEX);
    if (GlobalMemoryStatusEx(&mem_info)) {
      counters[flutter::EncodableValue("memoryTotal")] = flutter::EncodableValue(static_cast<int64_t>(mem_info.ullTotalPhys));
      counters[flutter::EncodableValue("memoryAvailable")] = flutter::EncodableValue(static_cast<int64_t>(mem_info.ullAvailPhys));
      counters[flutter::EncodableValue("memoryUsed")] = flutter::EncodableValue(static_cast<int64_t>(mem_info.ullTotalPhys - mem_info.ullAvailPhys));
      counters[flutter::EncodableValue("memoryPercent")] = flutter::EncodableValue(static_cast<int32_t>(mem_info.dwMemoryLoad));
    }
    
    // Get disk space info
    ULARGE_INTEGER free_bytes, total_bytes;
    if (GetDiskFreeSpaceEx(L"C:\\", &free_bytes, &total_bytes, nullptr)) {
      counters[flutter::EncodableValue("diskTotal")] = flutter::EncodableValue(static_cast<int64_t>(total_bytes.QuadPart));
      counters[flutter::EncodableValue("diskFree")] = flutter::EncodableValue(static_cast<int64_t>(free_bytes.QuadPart));
      counters[flutter::EncodableValue("diskUsed")] = flutter::EncodableValue(static_cast<int64_t>(total_bytes.QuadPart - free_bytes.QuadPart));
    }
    
    // Get process memory info
    PROCESS_MEMORY_COUNTERS_EX pmc;
    if (GetProcessMemoryInfo(GetCurrentProcess(), reinterpret_cast<PROCESS_MEMORY_COUNTERS*>(&pmc), sizeof(pmc))) {
      counters[flutter::EncodableValue("processMemory")] = flutter::EncodableValue(static_cast<int64_t>(pmc.WorkingSetSize));
    }
    
    result->Success(flutter::EncodableValue(counters));
  } catch (...) {
    result->Error("PERFORMANCE_ERROR", "Failed to get performance counters");
  }
}

}  // namespace

void WindowsFeaturesPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  WindowsFeaturesPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}

