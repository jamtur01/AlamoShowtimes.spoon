local obj = {}
obj.__index = obj

-- Metadata
obj.name = "AlamoShowtimes"
obj.version = "1.0"
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
    local iconPath = hs.spoons.resourcePath("alamo-logo-black.png")
    local iconImage = hs.image.imageFromPath(iconPath)

    if iconImage then
        obj.menubar:setIcon(iconImage)
    else
        -- Fallback to text if the image is not found
        obj.menubar:setTitle("A")
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
    local month = tonumber(date_str:sub(1, 2))
    local day = tonumber(date_str:sub(4, 5))
    local year = tonumber("20" .. date_str:sub(7, 8))  -- Convert the two-digit year to four digits

    -- Validate that all components exist and are valid
    if year and month and day and year > 1900 and year < 3000 and month >= 1 and month <= 12 and day >= 1 and day <= 31 then
        local time_obj = os.time({ year = year, month = month, day = day })
        if time_obj then
            return time_obj
        end
    end

    -- Log the invalid date for debugging purposes
    print("Invalid date encountered: ", date_str)

    -- Return `nil` if the conversion fails
    return nil
end

-- Function to align columns for showtimes and add URLs for clicking
function obj:formatShowtimesTable(showtimes_by_day)
    local menu_items = {}

    -- Calculate the maximum title length for consistent alignment
    local max_title_length = 0
    for _, shows in pairs(showtimes_by_day) do
        for show_title in pairs(shows) do
            if #show_title > max_title_length then
                max_title_length = #show_title
            end
        end
    end

    -- Add some padding to the maximum title length for spacing
    local padding = 5
    max_title_length = max_title_length + padding

    for date, shows in pairs(showtimes_by_day) do
        -- Add the date as a header
        table.insert(menu_items, { title = date, disabled = true })

        -- Add the shows under that date
        for show_title, show_data in pairs(shows) do
            local times = show_data.times
            local url = show_data.url

            -- Align the title and times with a fixed width for the title
            local formatted_title = show_title .. string.rep(" ", max_title_length - #show_title)  -- Left-align titles to max length
            local time_string = table.concat(times, " - ")

            -- Add the formatted title and times to the menu with a click handler to open the URL
            table.insert(menu_items, {
                title = string.format("%-" .. max_title_length .. "s %s", show_title, time_string),
                fn = function() hs.urlevent.openURL(url) end  -- Open the URL when clicked
            })
        end

        -- Add a separator between days
        table.insert(menu_items, { title = "-" })
    end

    return menu_items
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

-- Process showtimes and populate the menu by day and location with aligned columns and correct date order
function obj:processShowtimes(data)
    local market_name = data["data"]["market"][1]["name"]
    local presentations = data["data"]["presentations"]
    local showtimes_by_day = {}

    -- Get the cinemaId for the selected location
    local selected_cinema_id = self.cinema_ids[self.location:gsub(" ", "")]

    -- Today's date and limit to next 5 days
    local today = os.time()
    local five_days_from_now = os.time() + (5 * 24 * 60 * 60)

    -- Organize showtimes by day and filter by location (cinemaId)
    for _, session in ipairs(data["data"]["sessions"]) do
        if session["cinemaId"] == selected_cinema_id then
            local show_time_clt = session["showTimeClt"]
            local show_time_unix = os.time({
                year = tonumber(show_time_clt:sub(1, 4)),
                month = tonumber(show_time_clt:sub(6, 7)),
                day = tonumber(show_time_clt:sub(9, 10)),
                hour = tonumber(show_time_clt:sub(12, 13)),
                min = tonumber(show_time_clt:sub(15, 16)),
            })

            if show_time_unix >= today and show_time_unix <= five_days_from_now then
                local presentation_slug = session["presentationSlug"]
                local business_date = os.date("%x", show_time_unix)
                local formatted_time = self:formatTime(show_time_clt)

                -- Find the matching presentation for the session
                for _, presentation in ipairs(presentations) do
                    if presentation["slug"] == presentation_slug then
                        local show_title = presentation["show"]["title"]
                        local movie_url = "https://drafthouse.com/" .. self.market .. "/show/" .. presentation_slug

                        -- Group by the business date
                        if not showtimes_by_day[business_date] then
                            showtimes_by_day[business_date] = {}
                        end

                        -- Add the show details with the URL
                        if not showtimes_by_day[business_date][show_title] then
                            showtimes_by_day[business_date][show_title] = { times = {}, url = movie_url }
                        end
                        table.insert(showtimes_by_day[business_date][show_title].times, formatted_time)
                    end
                end
            end
        end
    end

    -- Sort the days based on today's date, followed by tomorrow, etc.
    local sorted_dates = {}
    for date in pairs(showtimes_by_day) do
        local time_obj = self:safeTime(date)
        if time_obj then
            table.insert(sorted_dates, { date = date, time_obj = time_obj })
        end
    end

    -- Safely sort the dates
    table.sort(sorted_dates, function(a, b) return a.time_obj < b.time_obj end)

    -- Generate the menu items in the correct order with aligned columns and clickable URLs
    local menu_items = {}
    table.insert(menu_items, { title = "Alamo Drafthouse | " .. market_name .. " (" .. self.location .. ")", disabled = true })

    for _, day_data in ipairs(sorted_dates) do
        local date = day_data.date
        -- Add the formatted showtimes for each date
        for _, item in ipairs(self:formatShowtimesTable({ [date] = showtimes_by_day[date] })) do
            table.insert(menu_items, item)
        end
    end

    -- Cache the showtimes data (without functions)
    self:cacheShowtimesData(showtimes_by_day)

    -- Add showtimes to the menu bar
    self.menubar:setMenu(menu_items)
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
    if self.cached_showtimes and #self.cached_showtimes > 0 then
        -- Add a title
        table.insert(menu_items, { title = "Cached Showtimes", disabled = true })

        -- Add cached showtimes to the menu
        for _, item in ipairs(self.cached_showtimes) do
            table.insert(menu_items, { title = item.title })
        end

        -- Update the menu bar with cached showtimes
        self.menubar:setMenu(menu_items)
    else
        table.insert(menu_items, { title = "No cached showtimes available", disabled = true })
        self.menubar:setMenu(menu_items)
    end
end

obj:init()

return obj

