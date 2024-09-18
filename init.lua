local obj = {}
obj.__index = obj

obj.name = "AlamoShowtimes"
obj.version = "1.5"
obj.author = "James Turnbull"
obj.homepage = "https://github.com/jamtur01/AlamoShowtimes.spoon"
obj.license = "MIT"

obj.market = "nyc"
obj.location = "Brooklyn"
obj.cinema_ids = { Brooklyn = "2101", Manhattan = "2103", StatenIsland = "2102" }

obj.cache_path = hs.fs.pathToAbsolute(hs.configdir) .. "/drafthouse_cache.json"

obj.menubar = hs.menubar.new()

function obj:setMenubarIcon()
    local iconPath = hs.spoons.resourcePath("film-logo.png")
    local iconImage = hs.image.imageFromPath(iconPath)

    if iconImage then
        obj.menubar:setIcon(iconImage)
    else
        obj.menubar:setTitle("🎬")
    end
    self.menubar:setTooltip("Alamo Drafthouse Showtimes")
end

function obj:init()
    self:loadCache()
    self:setMenubarIcon()
    self:updateMenu()

    self.refresh_timer = hs.timer.doEvery(3600, function()
        self:updateMenu()
    end)
end

function obj:formatTime(date_str)
    local time_table = {
        year = tonumber(date_str:sub(1, 4)),
        month = tonumber(date_str:sub(6, 7)),
        day = tonumber(date_str:sub(9, 10)),
        hour = tonumber(date_str:sub(12, 13)),
        min = tonumber(date_str:sub(15, 16))
    }
    
    local formatted_time = os.date("%I:%M %p", os.time(time_table))
    return formatted_time:gsub("^0", "")
end

function obj:timeToMinutes(timeStr)
    if not timeStr then return nil end
    local hour, min, period = timeStr:match("(%d+):(%d+)%s*(%a+)")
    if not (hour and min and period) then
        print("Invalid time format: " .. tostring(timeStr))
        return nil
    end
    hour, min = tonumber(hour), tonumber(min)
    if period == "PM" and hour ~= 12 then
        hour = hour + 12
    elseif period == "AM" and hour == 12 then
        hour = 0
    end
    return hour * 60 + min
end

function obj:safeTime(date_str)
    local month, day, year = date_str:match("(%d+)/(%d+)/(%d+)")
    
    if month and day and year then
        month, day, year = tonumber(month), tonumber(day), tonumber("20" .. year)
        if year and month and day and year > 1900 and year < 3000 and month >= 1 and month <= 12 and day >= 1 and day <= 31 then
            return os.time({ year = year, month = month, day = day })
        end
    end

    print("Invalid date encountered: ", date_str)
    return nil
end

function obj:removeDiacritics(str)
    local diacritics = {
        ['á'] = 'a', ['à'] = 'a', ['ã'] = 'a', ['â'] = 'a', ['ä'] = 'a',
        ['é'] = 'e', ['è'] = 'e', ['ê'] = 'e', ['ë'] = 'e',
        ['í'] = 'i', ['ì'] = 'i', ['î'] = 'i', ['ï'] = 'i',
        ['ó'] = 'o', ['ò'] = 'o', ['õ'] = 'o', ['ô'] = 'o', ['ö'] = 'o',
        ['ú'] = 'u', ['ù'] = 'u', ['û'] = 'u', ['ü'] = 'u',
        ['ñ'] = 'n',
        ['ç'] = 'c'
    }
    return str:gsub('[%z\1-\127\194-\244][\128-\191]*', diacritics)
end

function obj:visualLength(str)
    local len = 0
    for _ in str:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        len = len + 1
    end
    return len
end

function obj:cacheShowtimesData(showtimes_by_day)
    local cacheable_data = {
        showtimes = showtimes_by_day,
        timestamp = os.time() -- Store the current time as the cache timestamp
    }

    local file = io.open(self.cache_path, "w")
    if file then
        local contents = hs.json.encode(cacheable_data)
        file:write(contents)
        file:close()
    end
end

function obj:processShowtimes(data)
    local showtimes_by_day = {}
    local selected_cinema_id = self.cinema_ids[self.location:gsub(" ", "")]
    local now = os.time()
    local presentation_lookup = {}
    for _, presentation in ipairs(data.data.presentations) do
        presentation_lookup[presentation.slug] = presentation
    end

    for _, session in ipairs(data.data.sessions) do
        if session.cinemaId == selected_cinema_id then
            local show_time_clt = session.showTimeClt
            local show_time_unix = os.time({
                year = tonumber(show_time_clt:sub(1, 4)),
                month = tonumber(show_time_clt:sub(6, 7)),
                day = tonumber(show_time_clt:sub(9, 10)),
                hour = tonumber(show_time_clt:sub(12, 13)),
                min = tonumber(show_time_clt:sub(15, 16)),
            })

            if show_time_unix >= now then
                local presentation = presentation_lookup[session.presentationSlug]
                if presentation then
                    local business_date = os.date("%Y-%m-%d", show_time_unix)
                    local formatted_time = self:formatTime(show_time_clt)
                    local show_title = presentation.show.title
                    local movie_url = "https://drafthouse.com/" .. self.market .. "/show/" .. session.presentationSlug

                    if not showtimes_by_day[business_date] then
                        showtimes_by_day[business_date] = {
                            date = business_date,
                            formatted_date = os.date("%A, %B %d", show_time_unix),
                            shows = {}
                        }
                    end

                    if not showtimes_by_day[business_date].shows[show_title] then
                        showtimes_by_day[business_date].shows[show_title] = { times = {}, url = movie_url }
                    end

                    table.insert(showtimes_by_day[business_date].shows[show_title].times, formatted_time)
                end
            end
        end
    end

    for _, day_data in pairs(showtimes_by_day) do
        for _, show_data in pairs(day_data.shows) do
            table.sort(show_data.times, function(a, b)
                local a_min = self:timeToMinutes(a)
                local b_min = self:timeToMinutes(b)
                if a_min and b_min then
                    return a_min < b_min
                elseif a_min then
                    return true
                elseif b_min then
                    return false
                else
                    return tostring(a) < tostring(b)
                end
            end)
        end
    end

    return showtimes_by_day
end

function obj:formatShowtimesTable(showtimes_by_day)
    local menu_items = {}
    local max_title_length = self:calculateMaxTitleLength(showtimes_by_day)
    local sorted_days = {}
    for day in pairs(showtimes_by_day) do
        table.insert(sorted_days, day)
    end
    table.sort(sorted_days)

    local font_style = { font = { name = "Menlo", size = 14 }, paragraphStyle = { alignment = "left" } }

    local function wrapTimes(times, maxWidth)
        local lines = {}
        local currentLine = {}
        local currentWidth = 0
        for _, time in ipairs(times) do
            if currentWidth + #time + 3 > maxWidth and #currentLine > 0 then
                table.insert(lines, table.concat(currentLine, " • "))
                currentLine = {}
                currentWidth = 0
            end
            table.insert(currentLine, time)
            currentWidth = currentWidth + #time + 3
        end
        if #currentLine > 0 then
            table.insert(lines, table.concat(currentLine, " • "))
        end
        return lines
    end

    for _, date in ipairs(sorted_days) do
        local day_data = showtimes_by_day[date]
        table.insert(menu_items, { title = "───── " .. day_data.formatted_date .. " ─────", disabled = true })

        for show_title, show_data in pairs(day_data.shows) do
            local times = show_data.times
            local url = show_data.url
            local title_without_diacritics = self:removeDiacritics(show_title)
            local padding = max_title_length - self:visualLength(title_without_diacritics)
            local formatted_title = show_title .. string.rep(" ", padding)

            local wrapped_times = wrapTimes(times, 50)
            for i, time_line in ipairs(wrapped_times) do
                local line_title = i == 1 and formatted_title or string.rep(" ", self:visualLength(formatted_title))
                local combined_entry = hs.styledtext.new(line_title .. "│ " .. time_line, font_style)
                table.insert(menu_items, {
                    title = combined_entry,
                    fn = function() hs.urlevent.openURL(url) end
                })
            end
        end
    end

    return menu_items
end

function obj:calculateMaxTitleLength(showtimes_by_day)
    local max_length = 0
    for _, day_data in pairs(showtimes_by_day) do
        for show_title, _ in pairs(day_data.shows) do
            local title_without_diacritics = self:removeDiacritics(show_title)
            max_length = math.max(max_length, self:visualLength(title_without_diacritics))
        end
    end
    return max_length + 3
end

function obj:updateMenu()
    hs.http.asyncGet("https://drafthouse.com/s/mother/v2/schedule/market/" .. self.market, nil, function(status, body, headers)
        if status == 200 then
            local result = hs.json.decode(body)
            local showtimes_by_day = self:processShowtimes(result)
            local menu_items = self:formatShowtimesTable(showtimes_by_day)
            self.menubar:setMenu(menu_items)
        else
            self:displayCachedShowtimes()
        end
    end)
end

function obj:setMarket(market, location)
    self.market = market
    self.location = location or self.location
    self:updateMenu()
end

function obj:loadCache()
    if hs.fs.attributes(self.cache_path) then
        local file = io.open(self.cache_path, "r")
        if file then
            local contents = file:read("*a")
            local cached_data = hs.json.decode(contents)
            file:close()

            if cached_data and cached_data.timestamp then
                local expiration_time = 24 * 60 * 60
                local cache_age = os.time() - cached_data.timestamp

                if cache_age < expiration_time then
                    self.cached_showtimes = cached_data.showtimes
                else
                    self.cached_showtimes = {}
                end
            else
                self.cached_showtimes = {}
            end
        end
    else
        self.cached_showtimes = {}
    end
end

function obj:displayCachedShowtimes(menu_items)
    if self.cached_showtimes and next(self.cached_showtimes) then
        table.insert(menu_items, { title = "🕰 Cached Showtimes", disabled = true })
        table.insert(menu_items, { title = "─────────────────────────────────", disabled = true })

        for date, shows in pairs(self.cached_showtimes) do
            local formatted_date = os.date("%A, %B %d", self:safeTime(date))
            table.insert(menu_items, { title = "───── " .. formatted_date .. " ─────", disabled = true })
            for show_title, show_data in pairs(shows) do
                local times_string = table.concat(show_data.times, " • ")
                table.insert(menu_items, { 
                    title = string.format("%-30s│ %s", show_title, times_string),
                    fn = function() hs.urlevent.openURL(show_data.url) end
                })
            end
            table.insert(menu_items, { title = "─────────────────────────────────", disabled = true })
        end
    else
        table.insert(menu_items, { title = "No cached showtimes available", disabled = true })
    end
    self.menubar:setMenu(menu_items)
end

obj:init()

return obj