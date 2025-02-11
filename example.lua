local colors     = require("config.colors")
local settings   = require("config.settings")
local app_icons  = settings.icons.apps
local cjson      = require "cjson"
local json       = cjson.new()

local aerospace  = sbar.aerospace
local spaces     = {}
local icon_cache = {}

local function getIconForApp(appName)
    if icon_cache[appName] then
        return icon_cache[appName]
    end
    local icon = app_icons[appName] or app_icons["default"] or "?"
    icon_cache[appName] = icon
    return icon
end

local function updateSpaceIcons(spaceId, workspaceName, isSelected)
    aerospace:list_windows(workspaceName, function(appsOutput)
        appsOutput = json.decode(appsOutput)
        local hasApps = appsOutput and next(appsOutput) ~= nil
        local icon_strip = ""
        if hasApps then
            for _, app in ipairs(appsOutput) do
                local appName = app["app-name"]
                if appName and appName ~= "" then
                    icon_strip = icon_strip .. " " .. getIconForApp(appName)
                end
            end
        end

        if spaces[spaceId] then
            local shouldDraw = hasApps or isSelected
            spaces[spaceId].item:set({
                drawing = shouldDraw,
                label = {
                    string = icon_strip == "" and "—" or icon_strip,
                    drawing = shouldDraw
                }
            })
            spaces[spaceId].bracket:set({
                drawing = shouldDraw
            })
        end
    end)
end

local function addOrUpdateWorkspaceItem(workspaceName, monitorId, isSelected)
    local spaceId = "workspace_" .. workspaceName .. "_" .. monitorId

    if not spaces[spaceId] then
        local space_item = sbar.add("item", spaceId, {
            icon = {
                font = {
                    family = settings.fonts.text,
                    style = settings.fonts.style_map["Bold"],
                    size = 15.0,
                },
                shadow = { color = 0xA000000, distance = 4 },
                string = workspaceName,
                padding_left = 12,
                padding_right = 12,
                highlight_color = 0xffffffff,
            },
            label = {
                padding_right = 12,
                padding_left = 0,
                highlight_color = 0xffffffff,
                color = colors.grey,
                font = "sketchybar-app-font:Regular:14.0",
                y_offset = -1,
                shadow = {
                    color = 0xA000000,
                    distance = 4,
                },
            },
            padding_left = 2,
            padding_right = 2,
            background = { height = 25 },
            click_script = "aerospace workspace " .. workspaceName,
            display = monitorId,
            drawing = false,
        })

        local space_bracket = sbar.add("bracket", { spaceId }, {
            background = {
                color = colors.transparent,
                height = 26,
            },
            drawing = false
        })

        spaces[spaceId] = {
            item = space_item,
            bracket = space_bracket
        }
        space_item:subscribe("aerospace_workspace_change", function(env)
            local is_focused = (env.FOCUSED_WORKSPACE == workspaceName)
            space_item:set({
                icon = { highlight = is_focused },
                label = { highlight = is_focused },
                background = { color = is_focused and colors.bg1 or colors.bg2 },
            })
        end)
    end

    spaces[spaceId].item:set({
        icon = { highlight = isSelected },
        label = { highlight = isSelected },
        background = { color = isSelected and colors.bg1 or colors.bg2 }
    })
end

local function removeWorkspaceItem(spaceId)
    if spaces[spaceId] then
        sbar.remove(spaces[spaceId].item)
        sbar.remove(spaces[spaceId].bracket)
        table.remove(spaces, spaceId)
    end
end

local function updateAllWorkspaces()
    aerospace:list_current(function(focusedWorkspaceOutput)
        local focusedWorkspace = focusedWorkspaceOutput:match("[^\r\n]+") or ""

        aerospace:query_workspaces(function(workspaces_and_monitors)
            local updatedSpaces = {}

            for _, entry in ipairs(workspaces_and_monitors) do
                local workspaceName = entry.workspace
                local monitorId = math.floor(entry["monitor-appkit-nsscreen-screens-id"])
                local spaceId = "workspace_" .. workspaceName .. "_" .. monitorId
                local isSelected = (workspaceName == focusedWorkspace)

                addOrUpdateWorkspaceItem(workspaceName, monitorId, isSelected)
                updatedSpaces[spaceId] = true
            end

            for spaceId in pairs(spaces) do
                if not updatedSpaces[spaceId] then
                    removeWorkspaceItem(spaceId)
                end
            end

            for spaceId in pairs(updatedSpaces) do
                local workspaceName, monitorId =
                    spaceId:match("^workspace_(.-)_(%d+)$")
                local isSelected = (workspaceName == focusedWorkspace)
                updateSpaceIcons(spaceId, workspaceName, isSelected)
            end
        end)
    end)
end

local space_window_observer = sbar.add("item", {
    drawing = false,
    updates = true,
})



updateAllWorkspaces()

space_window_observer:subscribe({ "front_app_switched" }, updateAllWorkspaces())
