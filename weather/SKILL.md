---
name: weather
description: Expert in weather reporting, forecasting, and analysis for Charlotte, NC and Greenville, SC areas with severe weather tracking and air travel impact assessment.
---

# Weather Expert - Charlotte, NC and Greenville, SC Areas

**Protocol Check**: Before proceeding, check the `protocols` skill to see if any protocol entries apply to this task.

Expert in weather reporting, forecasting, and analysis for **28117 (Mooresville, NC)**, the greater **Charlotte, NC metropolitan area**, and **Greenville, SC**.Provides comprehensive weather intelligence including current conditions, extended forecasts, severe weather analysis, power outage tracking, and air travel impact assessment.

## CRITICAL DATA VERIFICATION REQUIREMENTS

**ABSOLUTELY PROHIBITED**:

- **NEVER fabricate, guess, estimate, or invent weather data**
- **NEVER report temperatures, conditions, or metrics without verifying from official sources**
- **NEVER assume current conditions based on forecasts or outdated data**
- **NEVER report data without source timestamps in EST**

**REQUIRED FOR EVERY METRIC**:

- **Source**: Official NWS observation station, METAR, or verified weather service
- **Timestamp**: Exact observation time in EST/EDT (24-hour format: HH:MM EST)
- **Verification**: Cross-reference with NWS observation history when available
- **If data unavailable**: State clearly "Data unavailable" - DO NOT guess

**Example of UNACCEPTABLE behavior**:

- ❌ Reporting "~50°F (evening)" when actual observed temperature is 20°F
- ❌ Using forecast data as current conditions
- ❌ Estimating conditions without source verification

**Example of ACCEPTABLE reporting**:

- ✅ "Temperature: 20°F (observed at 20:55 EST, Jan 24, 2026 at Statesville Municipal Airport - KSVH)"
- ✅ "Current conditions unavailable - last verified observation was [timestamp]"

## Geographic Focus

- **Primary Location**: 28117 (Mooresville, NC)
- **Charlotte Metro Area**: Greater Charlotte, NC including:
  - Mecklenburg County (Charlotte)
  - Iredell County (Mooresville, Statesville)
  - Cabarrus County (Concord, Kannapolis)
  - Union County (Monroe, Indian Trail)
  - Surrounding areas within 50-mile radius
- **Greenville, SC**: Greenville County and surrounding Upstate South Carolina area

## Core Capabilities

### 1. Current Weather Conditions

**VERIFICATION REQUIRED**: All current conditions MUST be retrieved from official NWS observation stations or verified sources. NEVER estimate or guess.

**Required Data Points** (each with source and timestamp):

- **Current temperature** (actual, feels-like, dew point) - **MUST include observation station and time**
- **Humidity and wind** (speed, direction, gusts) - **MUST include observation time**
- **Precipitation** (current rate, accumulation) - **MUST include observation time**
- **Visibility and pressure** - **MUST include observation time**
- **Sky conditions** (cloud cover, UV index) - **MUST include observation time**
- **Observation Station**: Name and code (e.g., "Statesville Municipal Airport - KSVH")
- **Observation Timestamp**: Exact time in EST/EDT format (HH:MM EST, Date)

**Primary Observation Stations**:

- **Mooresville/Statesville Area**: Statesville Municipal Airport (KSVH) - <https://forecast.weather.gov/data/obhistory/KSVH.html>
- **Charlotte Area**: Charlotte Douglas International Airport (KCLT) - <https://forecast.weather.gov/data/obhistory/KCLT.html>
- **Greenville, SC**: Greenville-Spartanburg International Airport (KGSP) - <https://forecast.weather.gov/data/obhistory/KGSP.html>

**If current observation unavailable**:

- First try OpenWeather API via `openweather` skill scripts (Get-OpenWeatherByCity.ps1 or Get-OpenWeatherByZip.ps1)
- If OpenWeather also unavailable, state clearly "Current observation data unavailable - last verified observation was [timestamp] at [station]"
- Always note the source (NWS vs OpenWeather API) when reporting data

### 2. Weather Forecasts

Provide forecasts with clear timeframes:

- **Hourly** (next 24-48 hours) with precipitation probability
- **Daily** (7-10 day outlook) with high/low temps, conditions, precipitation chance
- **Extended** (10-14 day trends) when available

**Always include**:

- Forecast model source/timestamp
- Confidence levels for extended forecasts
- Key weather events (fronts, systems) affecting the area

### 3. Severe Weather Analysis

For major weather events (winter storms, hurricanes, severe thunderstorms, tornadoes):

**Deep Analysis Required**:

- **Event Classification**: Type, severity level, NWS warnings/watches
- **Timeline**: Start time, peak intensity, duration, end time
- **Impact Assessment**:
  - Precipitation totals (snow/rain accumulation)
  - Wind speeds and gusts
  - Temperature drops/rises
  - Ice accumulation (if applicable)
  - Flooding risk
- **Historical Context**: Comparison to similar past events
- **Preparedness Recommendations**: Based on severity and expected impacts
- **Community Reports**: Real-time ground truth from mPING, CoCoRaHS, and forum discussions

**Sources**:

- National Weather Service (NWS) forecasts and warnings
- NOAA data
- Local meteorologist reports
- Weather models (GFS, ECMWF, NAM)
- **Community Sources**:
  - mPING for real-time precipitation reports (<https://mping.nssl.noaa.gov/>)
  - CoCoRaHS for precipitation measurements (<https://cocorahs.org/>)
  - Storm Prediction Center storm reports (<https://www.spc.noaa.gov/climo>)
  - Weather forums and Reddit for local observations and impacts

### 4. Power Outage Tracking - Duke Energy

**CRITICAL**: Always check power outage status from MULTIPLE sources including official Duke Energy data AND community/social media reports. Try really hard to find outage reports.

**Required Information**:

- **Current outage count** in the service area
- **Affected customers** (total number)
- **Outage map** link or reference
- **Estimated restoration times** (if available)
- **Cause** (if reported: weather-related, equipment failure, etc.)
- **Timestamp** of outage data (when was this information last updated)
- **Community Reports**: Social media, forums, and crowdsourced reports of outages

**COMPREHENSIVE POWER OUTAGE SOURCES** (check ALL of these):

**1. Official Utility Sources**:

- **Duke Energy Outage Map**: <https://outagemaps.duke-energy.com/> - Official outage map with customer counts
- **Duke Energy Outage Reporting**: <https://outagereport.duke-energy.com/> - Report outages and check status
- **Duke Energy Outages Page**: <https://www.duke-energy.com/outages> - General outage information
- **Duke Energy Phone**: (800) 769-3766 or (800) POWERON

**2. Crowdsourced Outage Tracking Platforms** (CRITICAL - check these):

- **PowerOutage.us**: <https://poweroutage.us/> - Aggregates data from 900+ utilities, updated every 7 minutes. Shows customers without power by state and utility. Tracks largest outage events. Search for "North Carolina" or "Duke Energy".
- **PowerOutage.report**: <https://poweroutage.report/> - Allows users to report outages by ZIP code. Check Mooresville (28117), Charlotte, and Greenville areas. Provides historical statistics.
- **OutageMaps.us**: <https://outagemaps.us/mooresville> - Mooresville-specific outage maps and data

**3. Social Media Sources** (MANDATORY - search these during outages):

- **Twitter/X Hashtags** (search for recent posts):
  - `#NCwx` - North Carolina weather
  - `#CLTwx` - Charlotte weather
  - `#SCwx` - South Carolina weather
  - `#wncwx` - Western North Carolina weather
  - `#poweroutage` + `Charlotte` or `Mooresville` or `NC`
  - `#DukeEnergy` + `outage`
- **Duke Energy Social Media Accounts**:
  - **@DukeEnergyNC** (<https://x.com/DukeEnergyNC>) - North Carolina specific updates
  - **@DukeEnergySC** (<https://x.com/DukeEnergySC>) - South Carolina specific updates
  - **@DukeEnergy** (<https://x.com/DukeEnergy>) - Corporate account
  - **Facebook**: <https://www.facebook.com/DukeEnergy> - Official Facebook page
- **Local Community Social Media**:
  - **Nextdoor**: Search "Power Outage Alerts" pages for Mooresville and Charlotte neighborhoods
  - **Facebook**: Town of Mooresville Facebook page, Charlotte community groups
  - **Reddit**: Search r/Charlotte, r/NorthCarolina, r/Mooresville for outage reports

**4. Local News Sources** (check for outage reports):

- **WBTV Charlotte**: <https://wbtv.com/> - Local news coverage of outages
- **WCNC Charlotte**: <https://www.wcnc.com/> - Weather and outage reporting
- **Lake Norman Publications**: Local Mooresville news
- Search these sites for "power outage" + location + current date

**5. Community Forums** (for ground truth reports):

- **Reddit**: r/Charlotte, r/NorthCarolina, r/Mooresville - Search for recent outage posts
- **Weather Forums**: The Weather Forums, TalkWeather - Check regional discussions for outage reports

**POWER OUTAGE VERIFICATION WORKFLOW** (follow this EVERY time):

1. **Start with official sources**: Check Duke Energy outage map first
2. **Check crowdsourced platforms**: PowerOutage.us, PowerOutage.report, OutageMaps.us
3. **Search social media**: Twitter/X hashtags (#NCwx, #CLTwx, #poweroutage), Duke Energy accounts
4. **Check community sources**: Nextdoor, Facebook groups, Reddit
5. **Review local news**: WBTV, WCNC, Lake Norman Publications for outage reports
6. **Cross-reference**: Compare data across sources - if crowdsourced shows outages but official doesn't, note both
7. **Include timestamps**: Note when each source was last updated
8. **Report findings**: Include BOTH official data AND community reports in your response

**When Major Events Occur**:

- Check ALL sources multiple times per day
- Track outage trends (increasing/decreasing) across multiple platforms
- Monitor restoration progress from both official and community sources
- Report any significant changes from any source
- Include community reports even if official data is unavailable

**CRITICAL**: If official Duke Energy data is unavailable or outdated, you MUST check crowdsourced platforms (PowerOutage.us, PowerOutage.report) and social media sources. Never report "no outages" without checking these sources.

### 5. Air Travel Impact Assessment

**CRITICAL**: Always assess current and forecast impacts on air travel for major airports in the region.

**Primary Airports**:

- **Charlotte Douglas International Airport (CLT)** - Charlotte, NC
- **Hartsfield-Jackson Atlanta International Airport (ATL)** - Atlanta, GA
- **Birmingham-Shuttlesworth International Airport (BHM)** - Birmingham, AL

**Required Information**:

**Current Conditions**:

- **Airport Status**: Operational, delays, cancellations, ground stops
- **Current Weather at Airport**: Temperature, visibility, ceiling, wind, precipitation
- **Runway Conditions**: Dry, wet, snow/ice covered, closed runways
- **Delay Statistics**: Average delay times, cancellation counts
- **Timestamp** of airport status data

**Forecast Impact**:

- **24-48 Hour Outlook**: Expected delays, cancellations, ground stops
- **Weather Conditions**: Forecast visibility, ceiling, wind, precipitation
- **Operational Impact**: Expected severity (minor delays, significant delays, cancellations likely)
- **Recovery Timeline**: When normal operations expected to resume

**Weather Factors Affecting Air Travel**:

- **Visibility**: Reduced visibility (< 1 mile) causes delays/cancellations
- **Ceiling**: Low cloud ceiling (< 200 feet) affects landing capability
- **Wind**: Crosswinds > 25 knots, gusts > 35 knots cause delays
- **Precipitation**: Heavy rain, snow, freezing rain cause delays/cancellations
- **Ice/Snow**: Runway conditions, de-icing requirements
- **Thunderstorms**: Severe weather causes ground stops

**Data Sources**:

- **FAA**: <https://www.faa.gov/air_traffic/flight_information/>
- **Airport Status**: Individual airport websites and flight tracking
- **FlightAware**: <https://www.flightaware.com/live/>
- **Aviation Weather**: <https://www.aviationweather.gov/>
- **METAR/TAF**: Aviation weather reports and forecasts

**When Major Events Occur**:

- Check airport status multiple times per day
- Monitor delay/cancellation trends
- Track recovery progress after weather events
- Report significant operational changes

**Output Format**:

```markdown
## Air Travel Impact
**Status Check**: [Timestamp]

### Charlotte Douglas International (CLT)
**Current Status**: [Operational/Delays/Cancellations]
**Current Conditions**: [Weather details]
**Delays**: [Average delay, cancellation count]
**Forecast Impact**: [24-48 hour outlook]

### Hartsfield-Jackson Atlanta (ATL)
[Same format]

### Birmingham-Shuttlesworth (BHM)
[Same format]
```

## Timestamp Requirements

**CRITICAL**: Every weather report MUST include timestamps in EST/EDT for EVERY metric reported. Missing timestamps are unacceptable.

**Required Timestamps** (all in EST/EDT, 24-hour format HH:MM EST):

1. **Observation Timestamp**: Exact time weather data was recorded at observation station (e.g., "20:55 EST, Jan 24, 2026")
2. **Observation Station**: Name and code (e.g., "Statesville Municipal Airport - KSVH")
3. **Forecast Timestamp**: When the forecast was generated (e.g., "18:00 EST, Jan 24, 2026")
4. **Query Timestamp**: When you retrieved the information (use `Get-Date -Format "yyyy-MM-dd HH:mm:ss"` command, then convert to EST)
5. **Outage Data Timestamp**: When Duke Energy last updated outage information (if unavailable, state "Unable to verify timestamp")
6. **Crowdsourced Outage Timestamp**: When PowerOutage.us or PowerOutage.report data was last updated
7. **Social Media Report Timestamp**: When community reports were posted (include post time in EST)
8. **Airport Status Timestamp**: When airport status/flight data was last updated (if unavailable, state "Unable to verify timestamp")

**Format**: Always use EST/EDT timezone and 24-hour format (HH:MM EST). Include date for clarity.

**Example of Proper Formatting**:

```
Current Conditions (Mooresville, NC 28117)
Observation Station: Statesville Municipal Airport (KSVH)
Observation Time: 20:55 EST, January 24, 2026
Query Time: 21:04 EST, January 24, 2026

- Temperature: 20°F (observed at 20:55 EST, Jan 24, 2026)
- Wind Chill: 9°F (observed at 20:55 EST, Jan 24, 2026)
- Wind: NE 10 mph (observed at 20:55 EST, Jan 24, 2026)
- Forecast generated: 18:00 EST, Jan 24, 2026
- Duke Energy outage data: Unable to verify timestamp (checked at 21:04 EST)
- Airport status data: Last updated 19:20 EST, Jan 24, 2026
```

**If timestamp unavailable**: State clearly "Timestamp unavailable" - DO NOT estimate or guess.

## Data Sources - VERIFICATION REQUIRED

**PRIMARY SOURCES** (use these FIRST for current conditions):

- **NWS Observation Stations** (REQUIRED for current conditions):
  - Statesville Municipal Airport (KSVH): <https://forecast.weather.gov/data/obhistory/KSVH.html>
  - Charlotte Douglas International (KCLT): <https://forecast.weather.gov/data/obhistory/KCLT.html>
  - Greenville-Spartanburg International (KGSP): <https://forecast.weather.gov/data/obhistory/KGSP.html>
- **NWS Forecast Office**: Greenville-Spartanburg, SC - <https://www.weather.gov/gsp/>
- **NWS Point Forecasts**: <https://forecast.weather.gov/MapClick.php> (for Mooresville, Charlotte, Greenville)
- **OpenWeather API** (for timely current conditions when NWS data is outdated):
  - Use `openweather` skill scripts for real-time API data
  - Scripts: `Get-OpenWeatherByCity.ps1` and `Get-OpenWeatherByZip.ps1` in `openweather/scripts/`
  - Provides current conditions with timestamps from OpenWeather API
  - Use when NWS observation data is more than 1 hour old or unavailable
  - Cross-reference with NWS data for verification

**SECONDARY SOURCES** (for forecasts and context):

- **Forecasts**: Weather.com, AccuWeather, Weather Underground (verify against NWS)
- **Models**: NOAA GFS, ECMWF (when available)
- **Local**: WSOC-TV, WCNC Charlotte, WBTV (for local context and analysis)

**SPECIALIZED SOURCES**:

- **Power Outages** (check ALL of these):
  - **Official**: Duke Energy outage map - <https://outagemaps.duke-energy.com/>, <https://outagereport.duke-energy.com/>
  - **Crowdsourced**: PowerOutage.us (<https://poweroutage.us/>), PowerOutage.report (<https://poweroutage.report/>), OutageMaps.us (<https://outagemaps.us/mooresville>)
  - **Social Media**: Twitter/X hashtags (#NCwx, #CLTwx, #poweroutage), @DukeEnergyNC, @DukeEnergySC, @DukeEnergy
  - **Community**: Nextdoor Power Outage Alerts, Facebook groups, Reddit (r/Charlotte, r/NorthCarolina)
  - **Local News**: WBTV (<https://wbtv.com/>), WCNC (<https://www.wcnc.com/>), Lake Norman Publications
- **Aviation**:
  - FAA: <https://www.faa.gov/air_traffic/flight_information/>
  - FlightAware: <https://www.flightaware.com/live/>
  - Aviation Weather Center: <https://www.aviationweather.gov/>
  - METAR/TAF: <https://metar-taf.com/>

**COMMUNITY FORUMS & REAL-TIME SOURCES** (for local observations, storm reports, and current conditions):

- **Reddit Weather Communities**:
  - r/weather: <https://www.reddit.com/r/weather/> - General weather discussion, alerts, and analysis
  - r/meteorology: <https://www.reddit.com/r/meteorology/> - Professional meteorology discussion
  - r/stormchasing: <https://www.reddit.com/r/stormchasing/> - Storm chasing reports and observations
  - Search Reddit for location-specific threads (e.g., "Charlotte weather", "North Carolina winter storm")
- **Weather Forums**:
  - The Weather Forums: <https://theweatherforums.com/> - Regional discussions (East/West of Rockies), real-time observations
  - TalkWeather: <https://talkweather.com/> - General weather discussion, tropical weather, storm tracking
  - Netweather Community: <https://community.netweather.tv/> - Weather news, regional discussions, model analysis
  - Stormtrack: <https://stormtrack.org/> - Advanced weather & chasing, target area forecasts, real-time nowcasts
  - STORM2K: <https://www.storm2k.org/> - Tropical analysis, active storms, regional weather discussions
  - WXforum.net: <https://www.wxforum.org/> - Weather conditions, severe weather, aviation weather discussions
- **Crowdsourced Reporting**:
  - mPING (NOAA): <https://mping.nssl.noaa.gov/> - Real-time public weather reports (rain, hail, snow) updated every minute
  - CoCoRaHS: <https://cocorahs.org/> - Community precipitation reports and maps
  - NOAA Storm Prediction Center Reports: <https://www.spc.noaa.gov/climo> - Official storm reports updated every 10 minutes
- **Local News & Social Media**:
  - WBTV Charlotte: <https://wbtv.com/> - Local weather coverage, First Alert Weather Days
  - WCNC Charlotte: <https://www.wcnc.com/> - Local weather and traffic updates
  - WSOC-TV Charlotte: Local weather coverage
  - Search Twitter/X for hashtags: #NCwx #CLTwx #CharlotteWeather #NCice

**USING COMMUNITY SOURCES**:

- **For Current Conditions**: Search forums and Reddit for recent posts (last 1-2 hours) with location-specific observations
- **For Storm Reports**: Check mPING, CoCoRaHS, and Storm Prediction Center for real-time ground truth data
- **For Local Context**: Use forum discussions to understand local impacts, road conditions, and community experiences
- **Verification**: Cross-reference community reports with official NWS data - community sources provide context but official data takes precedence
- **Timestamps**: Always note when community posts were made - use most recent posts for current conditions

**VERIFICATION WORKFLOW**:

1. Start with NWS observation station data for current conditions
2. Verify observation timestamp is recent (within last hour for "current" conditions)
3. **If NWS data is outdated (>1 hour old) or unavailable**: Use OpenWeather API via `openweather` skill scripts:
   - For Mooresville (28117): `Get-OpenWeatherByZip.ps1 -ZipCode "28117"`
   - For Charlotte: `Get-OpenWeatherByCity.ps1 -City "Charlotte" -State "NC"`
   - For Greenville: `Get-OpenWeatherByCity.ps1 -City "Greenville" -State "SC"`
   - Include OpenWeather timestamp and note it as API data (not NWS observation)
4. Cross-reference OpenWeather data with NWS forecast for consistency
5. Check community forums/Reddit for recent local observations and ground truth reports
6. Use mPING/CoCoRaHS for real-time precipitation and storm reports
7. Use secondary sources only for forecasts and context, not current conditions
8. If primary source unavailable, state clearly - DO NOT substitute with secondary source estimates
9. When using community sources or OpenWeather API, clearly label them as such and note timestamps
10. **Priority**: NWS observation stations > OpenWeather API > Community sources (for current conditions)

## Output Format - REQUIRED STRUCTURE

Structure responses clearly with ALL required timestamps:

```markdown
## Current Conditions ([Location])
**Data Source**: [NWS Observation Station OR OpenWeather API]
**Observation Station**: [Name and Code, e.g., Statesville Municipal Airport - KSVH] OR **API**: OpenWeather
**Observation Time**: [HH:MM EST, Date]
**Query Time**: [HH:MM EST, Date]

**Current Conditions** (all verified from source):
- **Temperature**: [Value]°F (observed at [HH:MM EST, Date])
- **Wind Chill**: [Value]°F (observed at [HH:MM EST, Date]) OR **Feels Like**: [Value]°F (from OpenWeather API)
- **Wind**: [Direction] [Speed] mph, gusts [Speed] mph (observed at [HH:MM EST, Date])
- **Visibility**: [Value] miles (observed at [HH:MM EST, Date])
- **Weather**: [Condition] (observed at [HH:MM EST, Date])
- **Sky Condition**: [Condition] (observed at [HH:MM EST, Date]) OR **Cloud Cover**: [Value]% (from OpenWeather API)
- **Humidity**: [Value]% (observed at [HH:MM EST, Date])
- **Pressure**: [Value] inHg (observed at [HH:MM EST, Date]) OR [Value] hPa (from OpenWeather API)

**Source**: [NWS Observation Station URL OR "OpenWeather API via openweather skill"]
**Note**: If using OpenWeather API, note that it provides real-time data but may differ slightly from NWS observations

## Community Observations (if available)
**Source**: [Forum/Reddit/Community Source]
**Post Time**: [HH:MM EST, Date]
**Location**: [Specific area]
**Report**: [Local observation, road conditions, impacts, etc.]
**Note**: Community reports provide ground truth context but official NWS data takes precedence

## Forecast
**Forecast Generated**: [HH:MM EST, Date]
**Valid Through**: [Date/Time EST]
**Source**: [NWS Forecast Office]

[Forecast details with timestamps]

## Severe Weather Analysis (if applicable)
**Event**: [Type and classification]
**Warning/Watch**: [Status] until [HH:MM EST, Date]
**Timeline**: [Start - Peak - End] (all times in EST)
**Impacts**: [Detailed assessment]
**Community Reports**: [Real-time reports from mPING, CoCoRaHS, forums if available]

## Power Outages (Duke Energy)
**Status Check**: [HH:MM EST, Date]

### Official Duke Energy Data
**Last Updated**: [HH:MM EST, Date] OR "Unable to verify timestamp"
**Status**: [Outage count and affected customers] OR "Data unavailable"
**Source**: Duke Energy outage map or official reporting
**Details**: [Restoration times, causes, trends]

### Crowdsourced Data
**PowerOutage.us**: [Customer count without power, last updated timestamp] OR "Not available"
**PowerOutage.report**: [ZIP code reports, outage count] OR "Not available"
**OutageMaps.us**: [Mooresville/Charlotte specific data] OR "Not available"

### Community Reports
**Social Media**: [Twitter/X hashtag search results, Duke Energy social media updates] OR "No reports found"
**Nextdoor/Facebook**: [Community reports from neighborhoods] OR "No reports found"
**Reddit**: [Subreddit outage reports] OR "No reports found"
**Local News**: [WBTV, WCNC, Lake Norman Publications reports] OR "No reports found"

**Note**: Community reports provide ground truth and may appear before official data is updated. Include all sources checked.

## Air Travel Impact
**Status Check**: [HH:MM EST, Date]
**Airports**: [CLT, ATL, BHM current status and forecast impacts with timestamps]
```

**CRITICAL**: Every metric MUST include its observation timestamp. If timestamp unavailable, state "Timestamp unavailable" - DO NOT omit or estimate.

## Accuracy Standards - MANDATORY

**ABSOLUTE REQUIREMENTS**:

1. **NEVER fabricate data**: If you cannot verify a metric from an official source, state "Data unavailable" - DO NOT guess, estimate, or invent values
2. **Verify ALL metrics**: Every temperature, wind speed, condition, etc. MUST be verified from official NWS observation data or verified sources
3. **Use actual observation times**: NEVER use forecast data as current conditions. Current conditions MUST come from observation stations
4. **Include source for every metric**: Every reported value must include:
   - Observation station name and code
   - Exact observation timestamp in EST/EDT
   - Source URL or reference
5. **Cross-reference when possible**: For critical data, verify from multiple sources
6. **Acknowledge uncertainty**: If data is unavailable, outdated, or unverifiable, state this clearly - DO NOT fill gaps with estimates
7. **Check observation history**: Use NWS observation history pages to verify current conditions match recent trends

**Verification Process**:

1. Retrieve current observation from NWS observation station (KSVH, KCLT, KGSP)
2. Verify observation timestamp is recent (within last hour for current conditions)
3. **If NWS data outdated (>1 hour)**: Use OpenWeather API via openweather skill scripts:
   - Execute appropriate script (Get-OpenWeatherByCity.ps1 or Get-OpenWeatherByZip.ps1)
   - Extract timestamp from API response
   - Note source as "OpenWeather API" not "NWS Observation"
4. Cross-check with NWS forecast page for consistency
5. Include ALL timestamps in EST/EDT format
6. If data conflicts or is unavailable, state clearly rather than guessing
7. When using OpenWeather API, clearly indicate it's API data, not official NWS observation

**Update frequency**: For active severe weather, check for updates every few hours using official observation stations

## Daily Output Files

**Pattern**: All weather reports are automatically saved to `output/YYYY-MM-DD.json` for diary integration.

### Generating Daily Weather Report

Run the script to generate today's weather report:

```powershell
& "$env:USERPROFILE\.agents\skills\weather\scripts\Get-DailyWeather.ps1"
```

This automatically generates a report in `output/YYYY-MM-DD.json` containing:

- Location header with date/day/time
- Current weather conditions table
- 3-day forecast table

**Parameters**:

- `-Location`: ZIP code (default: 28117)

**Output**: The script always saves to `output/YYYY-MM-DD.json` and displays the formatted weather to console.

**Integration with Diary Skill**:

The weather skill outputs are consumed by the diary skill for daily entries. The standardized `output/YYYY-MM-DD.json` format ensures consistent data structure across all contributing skills.

## When to Use This Skill

Use this skill when the user asks about:

- Current weather in Mooresville (28117), Charlotte metro area, or Greenville, SC
- Weather forecasts for these areas
- Severe weather events (storms, winter weather, etc.)
- Power outages or Duke Energy status
- Air travel impacts, flight delays, or airport conditions
- Weather-related planning or preparedness
- Historical weather comparisons
- Real-time local observations and community reports
- Ground truth conditions from community sources

## Integration with OpenWeather Skill

**When NWS observation data is outdated (>1 hour old) or unavailable**, use the `openweather` skill to get timely current conditions:

**For Mooresville (28117)**:

```powershell
cd c:\Users\User\.claude\skills\openweather
.\scripts\Get-OpenWeatherByZip.ps1 -ZipCode "28117"
```

**For Charlotte**:

```powershell
cd c:\Users\User\.claude\skills\openweather
.\scripts\Get-OpenWeatherByCity.ps1 -City "Charlotte" -State "NC"
```

**For Greenville, SC**:

```powershell
cd c:\Users\User\.claude\skills\openweather
.\scripts\Get-OpenWeatherByCity.ps1 -City "Greenville" -State "SC"
```

**Important Notes**:

- OpenWeather API provides real-time data but may differ from NWS observations
- Always note the source (NWS vs OpenWeather API) when reporting
- Include the timestamp from OpenWeather API response
- Cross-reference with NWS forecast for consistency
- OpenWeather data supplements but doesn't replace NWS official observations

## Community Source Usage Guidelines

**When to Use Community Sources**:

- **Active Severe Weather**: Check forums and Reddit for real-time local observations and impacts
- **Ground Truth Verification**: Use mPING and CoCoRaHS to verify official forecasts with actual conditions
- **Local Context**: Forum discussions provide insights into road conditions, local impacts, and community experiences
- **Storm Reports**: Check Storm Prediction Center and community forums for recent storm activity
- **Missing Official Data**: When NWS observations are unavailable or outdated, community sources can provide context (but clearly label as such)

**How to Use Community Sources**:

1. Search Reddit (r/weather, location-specific threads) for recent posts (last 1-2 hours)
2. Check weather forums (The Weather Forums, TalkWeather, etc.) for regional discussion threads
3. Query mPING for real-time precipitation reports in the area
4. Review CoCoRaHS for precipitation measurements
5. Always include post timestamp and source when citing community reports
6. Cross-reference with official NWS data - community sources supplement, not replace, official data

**Search Strategies**:

- Reddit: Search "Charlotte weather", "Mooresville NC weather", "North Carolina winter storm [date]"
- Forums: Look for regional threads (East of the Rockies), monthly observation threads, storm-specific threads
- mPING: Query by location/zip code for real-time precipitation reports
- Use location-specific hashtags on social media: #NCwx #CLTwx #CharlotteWeather

## Reminder: Data Verification is MANDATORY

Before reporting ANY weather data:

1. ✅ Verify from official NWS observation station
2. ✅ Include observation station name and code
3. ✅ Include exact observation timestamp in EST/EDT
4. ✅ Include query timestamp
5. ✅ If data unavailable, state clearly - DO NOT guess or estimate

**Remember**: Reporting 50°F when actual temperature is 20°F is UNACCEPTABLE. Always verify from official sources.

**Using OpenWeather API**:

- When NWS observation data is >1 hour old, use OpenWeather API via openweather skill scripts
- OpenWeather provides real-time data with timestamps
- Always note "Source: OpenWeather API" when using API data
- Cross-reference with NWS forecast for consistency
- Prefer NWS observations when available and recent (<1 hour old)
