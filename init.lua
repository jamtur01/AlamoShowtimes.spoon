local obj = {}
obj.__index = obj

-- Metadata
obj.name = "AlamoShowtimes"
obj.version = "1.2"
obj.author = "James Turnbull"
obj.homepage = "https://github.com/jamtur01/AlamoShowtimes.spoon"
obj.license = "MIT"

-- Default market and location
obj.market = "nyc"
obj.location = "Brooklyn"  -- Default location within NYC
obj.cinema_ids = { Brooklyn = "2101", Manhattan = "2103", StatenIsland = "2102" }

-- Cache file location
obj.cache_path = hs.fs.pathToAbsolute(hs.configdir) .. "/drafthouse_cache.json"

-- Menu bar icon
obj.menubar = hs.menubar.new()

-- Set Menubar Icon
function obj:setMenubarIcon()
    local iconPath = hs.spoons.resourcePath("film-logo.png")
    local iconImage = hs.image.imageFromPath(iconPath)

    if iconImage then
        obj.menubar:setIcon(iconImage)
    else
        -- Fallback to text if the image is not found
        obj.menubar:setTitle("🎬")
    end
end

-- Initialization
function obj:init()
    -- Load cache if available
    self:loadCache()

    -- Set the menubar icon
    self:setMenubarIcon()

    -- Set up menu
    self:updateMenu()
end

-- Helper function to format times
function obj:formatTime(date_str)
    local time_table = {
        year = tonumber(date_str:sub(1, 4)),
        month = tonumber(date_str:sub(6, 7)),
        day = tonumber(date_str:sub(9, 10)),
        hour = tonumber(date_str:sub(12, 13)),
        min = tonumber(date_str:sub(15, 16))
    }
    
    -- Format the time as 12-hour format (e.g., 12:45 PM)
    local formatted_time = os.date("%I:%M %p", os.time(time_table))
    
    -- Remove leading zero from the hour (e.g., 01:00 PM -> 1:00 PM)
    return formatted_time:gsub("^0", "")
end

-- Update menu
function obj:updateMenu()
    local menu_items = {}

    -- Fetch and display movie times in the menu bar
    hs.http.asyncGet("https://drafthouse.com/s/mother/v2/schedule/market/" .. self.market, nil, function(status, body, headers)
        if status == 200 then
            local result = hs.json.decode(body)
            self:processShowtimes(result)
        else
            print("Failed to fetch movie times")
            self:displayCachedShowtimes(menu_items)
        end
    end)
end

-- Safely convert a date string into a time object and handle errors
function obj:safeTime(date_str)
    -- Expected date format is MM/DD/YY (e.g., 08/22/24)
    local month, day, year = date_str:match("(%d+)/(%d+)/(%d+)")
    
    -- Validate that all components exist and are valid
    if month and day and year then
        month, day, year = tonumber(month), tonumber(day), tonumber("20" .. year)
        if year and month and day and year > 1900 and year < 3000 and month >= 1 and month <= 12 and day >= 1 and day <= 31 then
            return os.time({ year = year, month = month, day = day })
        end
    end

    -- Log the invalid date for debugging purposes
    print("Invalid date encountered: ", date_str)

    -- Return `nil` if the conversion fails
    return nil
end

-- Helper function to remove diacritics from a string
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

-- Helper function to get the visual length of a string (considering UTF-8 characters)
function obj:visualLength(str)
    local len = 0
    for _ in str:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        len = len + 1
    end
    return len
end

-- Calculate max title length across all days
function obj:calculateMaxTitleLength(showtimes_by_day)
    local max_length = 0
    for _, shows in pairs(showtimes_by_day) do
        for show_title, _ in pairs(shows) do
            local title_without_diacritics = self:removeDiacritics(show_title)
            max_length = math.max(max_length, self:visualLength(title_without_diacritics))
        end
    end
    return max_length + 3  -- Add 3 spaces for padding
end

function obj:formatShowtimesTable(showtimes_by_day)
    local menu_items = {}
    local max_title_length = self:calculateMaxTitleLength(showtimes_by_day)

    -- Define the monospaced font style
    local font_style = { font = { name = "Menlo", size = 14 }, paragraphStyle = { alignment = "left" } }

    -- Format and add menu items
    for date, shows in pairs(showtimes_by_day) do
        local formatted_date = os.date("%A, %B %d", self:safeTime(date))
        table.insert(menu_items, { title = "───── " .. formatted_date .. " ─────", disabled = true })

        for show_title, show_data in pairs(shows) do
            local times = show_data.times
            local url = show_data.url

            -- Remove diacritics for length calculation
            local title_without_diacritics = self:removeDiacritics(show_title)

            -- Calculate padding
            local padding = max_title_length - self:visualLength(title_without_diacritics)
            local formatted_title = show_title .. string.rep(" ", padding)

            local time_string = table.concat(times, " • ")

            -- Combine title and times and apply monospaced font
            local combined_entry = hs.styledtext.new(formatted_title .. "│ " .. time_string, font_style)

            table.insert(menu_items, {
                title = combined_entry,
                fn = function() hs.urlevent.openURL(url) end
            })
        end
    end

    return menu_items
end

-- Update menu
function obj:updateMenu()
    local menu_items = {}

    -- Fetch and display movie times in the menu bar
    hs.http.asyncGet("https://drafthouse.com/s/mother/v2/schedule/market/" .. self.market, nil, function(status, body, headers)
        if status == 200 then
            local result = hs.json.decode(body)
            local showtimes_by_day = self:processShowtimes(result)
            menu_items = self:formatShowtimesTable(showtimes_by_day)
            self.menubar:setMenu(menu_items)
        else
            print("Failed to fetch movie times")
            self:displayCachedShowtimes(menu_items)
        end
    end)
end

-- Cache only the data that can be serialized (no functions)
function obj:cacheShowtimesData(showtimes_by_day)
    local cacheable_data = {}

    for date, shows in pairs(showtimes_by_day) do
        cacheable_data[date] = {}
        for show_title, show_data in pairs(shows) do
            cacheable_data[date][show_title] = {
                times = show_data.times,
                url = show_data.url
            }
        end
    end

    local file = io.open(self.cache_path, "w")
    if file then
        local contents = hs.json.encode(cacheable_data)
        file:write(contents)
        file:close()
    end
end

-- Process showtimes and return a table organized by day
function obj:processShowtimes(data)
    local market_name = data.data.market[1].name
    local presentations = data.data.presentations
    local showtimes_by_day = {}

    -- Get the cinemaId for the selected location
    local selected_cinema_id = self.cinema_ids[self.location:gsub(" ", "")]

    -- Today's date and limit to the next 5 days
    local now = os.time()
    local five_days_from_now = now + (5 * 24 * 60 * 60)

    -- Create a lookup table for presentations
    local presentation_lookup = {}
    for _, presentation in ipairs(presentations) do
        presentation_lookup[presentation.slug] = presentation
    end

    -- Organize showtimes by day and filter by location (cinemaId)
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

            -- Filter out past showtimes
            if show_time_unix >= now and show_time_unix <= five_days_from_now then
                local presentation = presentation_lookup[session.presentationSlug]
                if presentation then
                    local business_date = os.date("%x", show_time_unix)
                    local formatted_time = self:formatTime(show_time_clt)
                    local show_title = presentation.show.title
                    local movie_url = "https://drafthouse.com/" .. self.market .. "/show/" .. session.presentationSlug

                    showtimes_by_day[business_date] = showtimes_by_day[business_date] or {}
                    showtimes_by_day[business_date][show_title] = showtimes_by_day[business_date][show_title] or { times = {}, url = movie_url }
                    table.insert(showtimes_by_day[business_date][show_title].times, formatted_time)
                end
            end
        end
    end

    -- Sort the times for each movie
    for _, day_shows in pairs(showtimes_by_day) do
        for _, show_data in pairs(day_shows) do
            table.sort(show_data.times)
        end
    end

    return showtimes_by_day
end

-- Helper function to format times (should be defined elsewhere in your code)
function obj:formatTime(date_str)
    local time_table = {
        year = tonumber(date_str:sub(1, 4)),
        month = tonumber(date_str:sub(6, 7)),
        day = tonumber(date_str:sub(9, 10)),
        hour = tonumber(date_str:sub(12, 13)),
        min = tonumber(date_str:sub(15, 16))
    }

    -- Format the time as 12-hour format (e.g., 12:45 PM)
    local formatted_time = os.date("%I:%M %p", os.time(time_table))

    -- Remove leading zero from the hour (e.g., 01:00 PM -> 1:00 PM)
    return formatted_time:gsub("^0", "")
end

-- Set the market and location, then update the menu
function obj:setMarket(market, location)
    self.market = market
    self.location = location or self.location
    self:updateMenu()
end

-- Load cached showtimes
function obj:loadCache()
    if hs.fs.attributes(self.cache_path) then
        local file = io.open(self.cache_path, "r")
        if file then
            local contents = file:read("*a")
            self.cached_showtimes = hs.json.decode(contents) or {}
            file:close()
        end
    else
        self.cached_showtimes = {}
    end
end

-- Display cached showtimes if available
function obj:displayCachedShowtimes(menu_items)
    if self.cached_showtimes and next(self.cached_showtimes) then
        -- Add a title
        table.insert(menu_items, { title = "🕰 Cached Showtimes", disabled = true })
        table.insert(menu_items, { title = "─────────────────────────────────", disabled = true })

        -- Add cached showtimes to the menu
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
