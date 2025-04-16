--[[ 
  Script: export_namespace_elements
  Author: luftruepel
  Date: 9.4.2025

  Purpose:
    This script iterates over all global tables (namespaces) in the Lua environment (_G)
    and writes all their members (functions, constants, etc.) to a file.

    For each global table found in _G (e.g., system, lcd, model, etc.), 
    the script lists each key within that table along with its type (function, number, string, table, etc.).
    The output is saved as a simple CSV-style text file.

  Output format:
    namespace.keyName, valueType

  Example output:
    system.getVersion, function
    lcd.drawText, function
    _G.KEY_EXIT_FIRST, number

  Output File:
    ./namespace_elements.txt (created in the same directory as the script)

  Usage:
    This script is executed immediately when ETHOS loads it.
    It is meant for development, diagnostics, or reverse-engineering purposes 
    and should not be used as a persistent or runtime script on the transmitter.

  Important:
    - There is no init(), run(), or registration function.
    - This script is intentionally self-contained and executes once at load time.
    - It should be removed from the transmitter after use to avoid unnecessary file writes 
      or confusion.

  Note:
    This script resides in a folder named 'export_namespace_elements' and is executed via its main.lua entry point.
    ETHOS recognizes the app by its folder name.
]]

local file = io.open("./namespace_elements.txt", "w")

for ns_name, ns_value in pairs(_G) do
    if type(ns_value) == "table" then
        for key, val in pairs(ns_value) do
            local val_type = type(val)
            local line
            if val_type == "number" then
                line = string.format("%s.%s, %s, %s\n", ns_name, tostring(key), val_type, tostring(val))
            else
                line = string.format("%s.%s, %s\n", ns_name, tostring(key), val_type)
            end
            file:write(line)
        end
    end
end

file:close()
