# AlamoShowtimes Spoon

`AlamoShowtimes` is a Hammerspoon Spoon that displays movie showtimes for Alamo Drafthouse cinemas in your macOS menu bar. You can view upcoming movies and their showtimes directly from the menu. Clicking on a movie will open its details page on the Alamo Drafthouse website.

## Features

- **Displays Movie Showtimes**: View movie showtimes for today and the next five days for a selected Alamo Drafthouse cinema location.
- **Clickable Movie Titles**: Click on a movie title to open its details page on the Alamo Drafthouse website.
- **Customizable Locations**: Select from multiple Alamo Drafthouse locations (Brooklyn, Manhattan, Staten Island, Chicago, Los Angeles, San Francisco).
- **Cache Showtimes**: Showtimes are cached for offline viewing.

## Installation

1. **Download the Spoon**: Download or clone the `AlamoShowtimes.spoon` repository into your Hammerspoon `Spoons` directory.

   ```sh
   git clone https://github.com/jamtur01/AlamoShowtimes.spoon.git ~/.hammerspoon/Spoons/AlamoShowtimes.spoon
   ```

2. **Load the Spoon in Hammerspoon**: Open your `~/.hammerspoon/init.lua` file and add the following lines to load and configure the Spoon.

   ```lua
   hs.loadSpoon("AlamoShowtimes")

   spoon.AlamoShowtimes.market = "nyc"  -- Default market
   spoon.AlamoShowtimes.location = "Brooklyn"  -- Default location within the market

   spoon.AlamoShowtimes:init()  -- Initialize the Spoon
   ```

3. **Reload Hammerspoon**: Save the file and reload Hammerspoon using the menu bar icon or the console with `hs.reload()`.

## Usage

Once installed and configured, the Spoon will display the movie showtimes for the selected location in your macOS menu bar.

### Interacting with the Menu

You can select different markets (e.g., NYC, Chicago, Los Angeles) and locations (e.g., Brooklyn, Manhattan, Staten Island) in your configuration. The menu will show the movie titles along with their respective showtimes for the next five days. Clicking on a movie title will open the corresponding movie page on the Alamo Drafthouse website in your default web browser.

### Example Configuration in `init.lua`

```lua
hs.loadSpoon("AlamoShowtimes")

-- Set default market and location
spoon.AlamoShowtimes.market = "nyc"
spoon.AlamoShowtimes.location = "Brooklyn"

-- Initialize the spoon
spoon.AlamoShowtimes:init()
```

## Customization

You can customize the Spoon's behavior by modifying the following properties:

- **Market**: Set the `market` variable to your preferred Alamo Drafthouse market. Available options are:

  - `nyc`
  - `chicago`
  - `los-angeles`
  - `sf` (San Francisco)

- **Location**: Set the `location` variable to the desired cinema within your selected market. For NYC, the available options are:
  - `Brooklyn`
  - `Manhattan`
  - `Staten Island`

Example:

```lua
spoon.AlamoShowtimes.market = "nyc"
spoon.AlamoShowtimes.location = "Manhattan"
```

## Cache

The Spoon caches showtimes data for offline use. The cache is saved in a JSON file located in the Hammerspoon configuration directory (`~/.hammerspoon`). The cache is automatically updated when new showtimes are fetched.

To clear the cache, simply delete the cache file manually.

## Known Issues

- **Showtimes Discrepancies**: In some cases, the fetched showtimes may not match the current schedule if the Alamo Drafthouse website has been updated after the last cache refresh. You can manually reload Hammerspoon to fetch the latest data.

## Acknowledgements

- [Hammerspoon](https://www.hammerspoon.org/): Staggeringly powerful macOS desktop automation with Lua.
- [Alamo Drafthouse](https://drafthouse.com/): My local cinema.
- [Josh's Drafthouse scraper](https://github.com/josh/alamo-drafthouse-feeds): A Python script to scrape Alamo Drafthouse showtimes.

## Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/yourusername/AlamoShowtimes.spoon/issues) to see if there are any open issues or create a new one.

1. Fork the repository
2. Create your feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
