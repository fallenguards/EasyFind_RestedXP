-- Runs every tests/test_*.lua; each returns its tests by name.
-- From the addon's folder: lua tests/Run.lua
local source = debug.getinfo(1, "S").source:sub(2)
local DIR = source:gsub("[/\\]?Run%.lua$", "")
if DIR == "" then DIR = "." end
package.path = DIR .. "/?.lua;" .. package.path

local files = {}
local handle = io.popen(string.format([[ls "%s"/test_*.lua 2>/dev/null]], DIR:gsub("\\", "/")))
if handle then
    for line in handle:lines() do files[#files + 1] = line end
    handle:close()
end
table.sort(files)
if #files == 0 then
    print("no test files in " .. DIR)
    os.exit(1)
end

local pass, fail = 0, 0
for _, file in ipairs(files) do
    local chunk, err = loadfile(file)
    local tests = chunk and chunk()
    if type(tests) ~= "table" then
        print("LOAD ERROR " .. file .. ": " .. tostring(err))
        fail = fail + 1
    else
        local names = {}
        for name in pairs(tests) do names[#names + 1] = name end
        table.sort(names)
        for _, name in ipairs(names) do
            local ok, e = xpcall(tests[name], debug.traceback)
            if ok then
                pass = pass + 1
            else
                fail = fail + 1
                print("FAIL " .. name .. "\n  " .. tostring(e))
            end
        end
    end
end
print(string.format("%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
