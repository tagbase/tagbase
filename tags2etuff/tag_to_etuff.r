### --- Begin Tim's edit history  --- ###
### 2022-06-29
### a) Need to manually handle date format that is not guess-able by findDateFormat with the function "format.datetime"
### b) PDT has some NA in BinNum, need to be filtered out
### c) Add preview of read in data after each "Getting..."
### 2022-03-10
### a) remove the need to trim to be within start & end dates 
### b) update the function call to building an etuff header using local metadata listing
### c) slightly modify verbose messages
### d) add time elapsed
### --- End of Tim's edit history --- ###

format.datetime <- function(dframe, orders = "%m/%d/%Y %H:%M:%S"){
  ### Default format is for "08/08/2011 18:00:00"
  dframe <- lubridate::parse_date_time2(dframe, orders = orders, tz = "UTC")
  return(dframe)
}

tag_to_etuff <- function (dir, meta_row, fName = NULL, tatBins = NULL, tadBins = NULL, 
    obsTypes = NULL, check_meta = TRUE, metaTypes = NULL, returndata = FALSE , gpe.scaling=1, ...) 
{
	defaultW <- getOption("warn") 
    options(warn = -1) 
	print("------------------------------------------------")
	stopwatch = Sys.time()
    print("Processing...")
	print(dir)
	print("------------------------------------------------")
    args <- list(...)
    if ("fName" %in% names(args)) 
        fName <- args$fName
    if ("customCols" %in% names(args)) 
        customCols <- args$customCols
    if ("write_direct" %in% names(args)) 
        write_direct <- args$write_direct
    if ("etuff_file" %in% names(args)) 
        etuff_file <- args$etuff_file
    if ("manufacturer" %in% names(args)) {
        manufacturer <- args$manufacturer
    }
    else {
        manufacturer <- meta_row$manufacturer
    }
    if ("tagtype" %in% names(args)) {
        tagtype <- args$tagtype
    }
    else {
        tagtype <- meta_row$model
    }
    if ("dates" %in% names(args)) {
        dates <- args$dates
    }
    else {
        if (!lubridate::is.POSIXct(meta_row$time_coverage_start) | 
            !lubridate::is.POSIXct(meta_row$time_coverage_end)) 
            stop("Start and end times specified by meta_row must be of class POSIXct.")
        dates <- c(meta_row$time_coverage_start, meta_row$time_coverage_end)
    }
	### --- Tim's edits 2022-03-10: remove the need to trim to be within start & end dates --- ###
	dates <- c(as.POSIXct("1970-01-01", format = "%Y-%m-%d", tz="GMT"), 
	           as.POSIXct("2970-01-01", format = "%Y-%m-%d", tz="GMT"))
	### --- End of Tim's edits --- ###	
    if ("gpe3" %in% names(args)) {
        gpe3 <- args$gpe3
    }
    else if (!is.na(meta_row$waypoints_method)) {
        if (meta_row$waypoints_method == "GPE3") 
            gpe3 <- TRUE
    }
    else {
        gpe3 <- FALSE
    }
    if (is.null(obsTypes)) {
        print("Getting obsTypes...")
        url <- "https://raw.githubusercontent.com/camrinbraun/tagbase/master/eTUFF-ObservationTypes.csv"
        obsTypes <- try(read.csv(text = RCurl::getURL(url)), 
            TRUE)
        if (class(obsTypes) == "try-error") 
            stop(paste("obsTypes not specified in function call and unable to automatically download it from github at", 
                url, sep = " "))
    }
    if (names(obsTypes)[1] != "VariableID") 
        names(obsTypes)[1] <- "VariableID"
    if (manufacturer == "unknown") {
        if (!exists("customCols")) 
            stop("if manufacturer is unknown, customCols must be specified.")
    }
    else if (!(manufacturer %in% c("Microwave", "Wildlife", "Wildlife Computers", 
        "Lotek"))) {
        stop("the specified manufacturer is not supported.")
    }
    if (tagtype %in% c("spot", "SPOT", "SPOT-F", "mrPATspot", 
        "spot380", "spot258", "towed SPOT")) {
        tagtype <- "satellite"
    }
    else if (tagtype %in% c("miniPAT", "PAT", "MK10", "MK10AF", 
        "psat", "Xtag")) {
        tagtype <- "popup"
    }
    else if (tagtype %in% c("LAT-2810", "LTD2310", "Mk9", "LAT231")) {
        tagtype <- "archival"
    }
    else if (!(tagtype %in% c("satellite", "popup", "archival"))) {
        tagtype <- meta_row$instrument_type
        if (!(tagtype %in% c("satellite", "popup", "archival"))) {
            stop("specified model needs to match an accepted tag model or instrument_type needs to be satellite, popup or archival.")
        }
    }
    if (class(dates)[1] != "POSIXct") 
        stop("input to dates must be of class POSIXct")
    if (exists("customCols")) {
        print("Using the custom columns specified in customCols argument. This is an experimental feature and is not well tested.")
        warning("Defining column names using customCols as specified. These MUST exactly match observation types from the obsTypes set!")
        dat <- customCols
        dt.idx <- which(dat$DateTime < dates[1] | dat$DateTime > 
            dates[2])
        if (length(dt.idx) > 0) {
            warning("data in input dataset that is outside the bounds of specified start/end dates.")
            dat <- dat[-dt.idx, ]
        }
        dat <- reshape2::melt(dat, id.vars = c("DateTime"), measure.vars = names(dat)[-grep("DateTime", 
            names(dat))])
        dat$VariableName <- dat$variable
        dat <- merge(x = dat, y = obsTypes[, c("VariableID", 
            "VariableName", "VariableUnits")], by = "VariableName", 
            all.x = TRUE)
        dat <- dat[, c("DateTime", "VariableID", "value", "VariableName", 
            "VariableUnits")]
        names(dat) <- c("DateTime", "VariableID", "VariableValue", 
            "VariableName", "VariableUnits")
        dat <- dat[order(dat$DateTime, dat$VariableID), ]
        dat$DateTime <- as.POSIXct(dat$DateTime, tz = "UTC")
        dat$DateTime <- format(dat$DateTime, "%Y-%m-%d %H:%M:%S")
        dat <- dat[which(!is.na(dat$VariableValue)), ]
        dat <- dat[which(dat$VariableValue != " "), ]
        if (exists("returnData")) {
            returnData <- rbind(returnData, dat)
        }
        else {
            returnData <- dat
        }
    }
    if (tagtype == "satellite" & manufacturer == "Wildlife") {
        fList <- list.files(dir, full.names = T)
        fidx <- grep("-Locations.csv", fList)
        if (length(fidx) == 0) {
            print(paste("No Wildlife SPOT data to gather.", sep = ""))
            fe <- FALSE
        }
        else if (length(fidx) > 1) {
            stop(paste(length(fidx), "files match -Locations.csv in the current directory. Ensure there are no duplicated extensions and try again."))
        }
        else if (length(fidx) == 1) {
            fe <- TRUE
        }
        if (fe) {
            argos <- utils::read.table(fList[fidx], sep = ",", 
                header = T, blank.lines.skip = F)
            argos.new <- argos[which(argos$Type != "User"), ]
            nms <- tolower(names(argos.new))
            nms[grep("error.semi.major.axis", nms)] <- "argosErrMaj"
            nms[grep("error.semi.minor.axis", nms)] <- "argosErrMin"
            nms[grep("error.ellipse.orientation", nms)] <- "argosErrOrient"
            nms[grep("quality", nms)] <- "argosLC"
            names(argos.new) <- nms
            argos.new <- argos.new[which(argos.new$date != ""), 
                ]
            argos.new$date <- testDates(argos.new$date)
            argos.new <- argos.new[which(argos.new$date > dates[1] & 
                argos.new$date < dates[2]), ]
            argos.new <- argos.new[which(argos.new$argosLC != 
                "Z"), ]
            argos.new <- reshape2::melt(argos.new, id.vars = c("date"), 
                measure.vars = c("argosLC", "argosErrMaj", "argosErrMin", 
                  "argosErrOrient", "latitude", "longitude"))
            argos.new$VariableName <- argos.new$variable
            argos.new <- merge(x = argos.new, y = obsTypes[, 
                c("VariableID", "VariableName", "VariableUnits")], 
                by = "VariableName", all.x = TRUE)
            argos.new <- argos.new[, c("date", "VariableID", 
                "value", "VariableName", "VariableUnits")]
            names(argos.new) <- c("DateTime", "VariableID", "VariableValue", 
                "VariableName", "VariableUnits")
            argos.new <- argos.new[order(argos.new$DateTime, 
                argos.new$VariableID), ]
            argos.new$DateTime <- as.POSIXct(argos.new$DateTime, 
                tz = "UTC")
            argos.new$DateTime <- format(argos.new$DateTime, 
                "%Y-%m-%d %H:%M:%S")
            argos.new <- argos.new[which(!is.na(argos.new$VariableValue)), 
                ]
            argos.new <- argos.new[which(argos.new$VariableValue != 
                " "), ]
            if (exists("returnData")) {
                returnData <- rbind(returnData, argos.new)
            }
            else {
                returnData <- argos.new
            }
        }
        if (exists("fe")) 
            rm(fe)
    }
    if (tagtype == "popup" & manufacturer == "Microwave") {
        print("Reading Microwave PSAT for vertical data...")
        if (is.null(fName)) 
            stop("fName of target XLS file must be specified if manufacturer is Microwave.")
        fList <- list.files(dir, full.names = T)
        fidx <- grep(fName, fList)
        if (length(fidx) == 0) {
            print(paste("No Microwave data to gather using", 
                fName, ".", sep = ""))
            fe <- FALSE
        }
        else if (length(fidx) > 1) {
            stop(paste(length(fidx), "files match", fName, "in the current directory. Ensure there are no duplicated extensions and try again."))
        }
        else if (length(fidx) == 1) {
            fe <- TRUE
        }
        if (fe) {
            print(paste("Reading time series data from", fName, 
                "..."))
            xl_type <- readxl::excel_format(fList[fidx])
            if (xl_type == "xls") {
                depth <- gdata::read.xls(fList[fidx], sheet = "Press Data", 
                  skip = 1, header = T)[, 1:5]
                temp <- gdata::read.xls(fList[fidx], sheet = "Temp Data", 
                  skip = 1, header = T)[, 1:5]
                names(depth) <- c("Date.Time", "Press.val.", 
                  "Gain", "Depth.m.", "Delta.val.")
                names(temp) <- c("Date.Time", "Temp.val.", "Temp.C.", 
                  "Delta.val.", "DeltaLim.Temp")
                depth$Date <- as.POSIXct(depth$Date.Time, format = "%m/%d/%y %H:%M", 
                  tz = "UTC")
                depth$Depth <- depth$Depth.m. * -1
                temp$Date <- as.POSIXct(temp$Date.Time, format = "%m/%d/%y %H:%M", 
                  tz = "UTC")
            }
            else if (xl_type == "xlsx") {
                depth <- openxlsx::read.xlsx(fList[fidx], sheet = "Press Data", 
                  startRow = 2)[, 1:5]
                temp <- openxlsx::read.xlsx(fList[fidx], sheet = "Temp Data", 
                  startRow = 2)[, 1:5]
                names(depth) <- c("Date.Time", "Press.val.", 
                  "Gain", "Depth.m.", "Delta.val.")
                names(temp) <- c("Date.Time", "Temp.val.", "Temp.C.", 
                  "Delta.val.", "DeltaLim.Temp")
                depth$Date <- as.POSIXct(as.numeric(depth$Date.Time) * 
                  3600 * 24, origin = "1899-12-30", tz = "UTC")
                depth$Depth <- depth$Depth.m. * -1
                temp$Date <- as.POSIXct(as.numeric(temp$Date.Time) * 
                  3600 * 24, origin = "1899-12-30", tz = "UTC")
            }
            else {
                stop("Error: something bad happened when trying to parse the MT file as xls or xlsx. Are you sure you're providing one of these file types?")
            }
            mti <- merge(depth, temp, by = "Date", all = TRUE)
            mti <- mti[which(mti$Date >= dates[1] & mti$Date <= 
                dates[2]), ]
            names(mti)[1] <- "DateTime"
            names(mti)[grep("Press.val", names(mti))] <- "pressure"
            names(mti)[grep("Depth.m", names(mti))] <- "depth"
            names(mti)[grep("Temp.C", names(mti))] <- "temperature"
            mti.new <- reshape2::melt(mti, id.vars = c("DateTime"), 
                measure.vars = c("temperature", "depth", "pressure"))
            mti.new$VariableName <- mti.new$variable
            mti.new <- merge(x = mti.new, y = obsTypes[, c("VariableID", 
                "VariableName", "VariableUnits")], by = "VariableName", 
                all.x = TRUE)
            mti.new <- mti.new[, c("DateTime", "VariableID", 
                "value", "VariableName", "VariableUnits")]
            names(mti.new) <- c("DateTime", "VariableID", "VariableValue", 
                "VariableName", "VariableUnits")
            mti.new <- mti.new[order(mti.new$DateTime, mti.new$VariableID), 
                ]
            mti.new$DateTime <- as.POSIXct(mti.new$DateTime, 
                tz = "UTC")
            mti.new$DateTime <- format(mti.new$DateTime, "%Y-%m-%d %H:%M:%S")
            mti.new$VariableValue[which(mti.new$VariableName == 
                "depth")] <- abs(mti.new$VariableValue[which(mti.new$VariableName == 
                "depth")])
            mti.new <- mti.new %>% filter(!is.na(VariableValue))
            if (exists("returnData")) {
                returnData <- rbind(returnData, mti.new)
            }
            else {
                returnData <- mti.new
            }
        }
    }
    if (exists("fe")) 
        rm(fe)
    if (tagtype == "popup" & manufacturer == "Microwave") {
        if (is.null(fName)) 
            stop("fName of target XLS file must be specified if manufacturer is Microwave.")
        fList <- list.files(dir, full.names = T)
        fidx <- grep(fName, fList)
        if (length(fidx) == 0) {
            print(paste("No Microwave data to gather using", 
                fName, ".", sep = ""))
            fe <- FALSE
        }
        else if (length(fidx) > 1) {
            stop(paste(length(fidx), "files match", fName, "in the current directory. Ensure there are no duplicated extensions and try again."))
        }
        else if (length(fidx) == 1) {
            fe <- TRUE
        }
        if (fe) {
            print(paste("Reading light data from", fName, "..."))
            xl_type <- readxl::excel_format(fList[fidx])
            if (xl_type == "xls") {
                light <- gdata::read.xls(fList[fidx], sheet = "Sunrise and Sunset Times", 
                  skip = 1, header = T)[, 1:5]
                names(light) <- c("Date", "Sunrise.Time", "depthSunrise", 
                  "Sunset.Time", "depthSunset")
                light$Date <- as.Date(light$Date, format = "%b %d, %Y", 
                  tz = "UTC")
                sr <- reshape2::melt(light, id.vars = c("Date", 
                  "Sunrise.Time"), measure.vars = c("depthSunrise"))
                sr$DateTime <- as.POSIXct(paste(sr$Date, sr$Sunrise.Time), 
                  format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
                ss <- reshape2::melt(light, id.vars = c("Date", 
                  "Sunset.Time"), measure.vars = c("depthSunset"))
                ss$DateTime <- as.POSIXct(paste(ss$Date, ss$Sunset.Time), 
                  format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
            }
            else if (xl_type == "xlsx") {
                light <- openxlsx::read.xlsx(fList[fidx], sheet = "Sunrise and Sunset Times", 
                  startRow = 2)[, 1:5]
                names(light) <- c("Date", "Sunrise.Time", "depthSunrise", 
                  "Sunset.Time", "depthSunset")
                light$Sunrise.Time <- light$Date + light$Sunrise.Time
                light$Sunset.Time <- light$Date + light$Sunset.Time
                light$Date <- as.Date(as.POSIXct(as.numeric(light$Date) * 
                  3600 * 24, origin = "1899-12-30", tz = "UTC"))
                sr <- reshape2::melt(light, id.vars = c("Date", 
                  "Sunrise.Time"), measure.vars = c("depthSunrise"))
                sr$DateTime <- as.POSIXct(sr$Sunrise.Time * 3600 * 
                  24, origin = "1899-12-30", tz = "UTC")
                ss <- reshape2::melt(light, id.vars = c("Date", 
                  "Sunset.Time"), measure.vars = c("depthSunset"))
                ss$DateTime <- as.POSIXct(ss$Sunset.Time * 3600 * 
                  24, origin = "1899-12-30", tz = "UTC")
            }
            else {
                stop("Error: something bad happened when trying to parse the MT file as xls or xlsx. Are you sure you're providing one of these file types?")
            }
            light <- rbind(sr[, c("DateTime", "variable", "value")], 
                ss[, c("DateTime", "variable", "value")])
            light$VariableName <- light$variable
            mti.new <- merge(x = light, y = obsTypes[, c("VariableID", 
                "VariableName", "VariableUnits")], by = "VariableName", 
                all.x = TRUE)
            mti.new <- mti.new[, c("DateTime", "VariableID", 
                "value", "VariableName", "VariableUnits")]
            names(mti.new) <- c("DateTime", "VariableID", "VariableValue", 
                "VariableName", "VariableUnits")
            mti.new <- mti.new[order(mti.new$DateTime, mti.new$VariableID), 
                ]
            mti.new$DateTime <- as.POSIXct(mti.new$DateTime, 
                tz = "UTC")
            mti.new$DateTime <- format(mti.new$DateTime, "%Y-%m-%d %H:%M:%S")
            mti.new$VariableValue <- abs(mti.new$VariableValue)
            mti.new <- mti.new %>% filter(!is.na(VariableValue))
            if (exists("returnData")) {
                returnData <- rbind(returnData, mti.new)
            }
            else {
                returnData <- mti.new
            }
        }
    }
    if (exists("fe")) 
        rm(fe)
    if (tagtype == "popup" & manufacturer == "Microwave") {
        if (is.null(fName)) 
            stop("fName of target XLS file must be specified if manufacturer is Microwave.")
        fList <- list.files(dir, full.names = T)
        fidx <- grep(fName, fList)
        if (length(fidx) == 0) {
            print(paste("No Microwave data to gather using", 
                fName, ".", sep = ""))
            fe <- FALSE
        }
        else if (length(fidx) > 1) {
            stop(paste(length(fidx), "files match", fName, "in the current directory. Ensure there are no duplicated extensions and try again."))
        }
        else if (length(fidx) == 1) {
            fe <- TRUE
        }
        if (fe) {
            print(paste("Reading location data from", fName, 
                "..."))
            xl_type <- readxl::excel_format(fList[fidx])
            if (xl_type == "xls") {
                locs <- gdata::read.xls(fList[fidx], sheet = "Lat&Long", 
                  skip = 1, header = T, stringsAsFactors = F)
                day0 = as.POSIXct(locs[3, 8], format = "%b %d, %Y", 
                  tz = "UTC")
                x0 = as.numeric(locs[5, 8:9])
                x0[2] <- x0[2] * -1
                dayT = as.POSIXct(locs[9, 8], format = "%b %d, %Y", 
                  tz = "UTC")
                xT = as.numeric(locs[11, 8:9])
                xT[2] <- xT[2] * -1
                if (any(!is.na(stringr::str_locate(names(locs)[3], 
                  "W")))) 
                  is_west <- TRUE
                locs <- locs[, 1:3]
                locs$Date <- as.POSIXct(locs$Date, format = "%b %d, %Y", 
                  tz = "UTC")
            }
            else if (xl_type == "xlsx") {
                locs <- openxlsx::read.xlsx(fList[fidx], sheet = "Lat&Long", 
                  startRow = 2)
                day0 = as.POSIXct(as.numeric(locs[3, 6]) * 3600 * 
                  24, origin = "1899-12-30", tz = "UTC")
                x0 = as.numeric(locs[5, 6:7])
                x0[2] <- x0[2] * -1
                dayT = as.POSIXct(as.numeric(locs[9, 6]) * 3600 * 
                  24, origin = "1899-12-30", tz = "UTC")
                xT = as.numeric(locs[11, 6:7])
                xT[2] <- xT[2] * -1
                if (any(!is.na(stringr::str_locate(names(locs)[3], 
                  "W")))) 
                  is_west <- TRUE
                locs <- locs[, 1:3]
                locs$Date <- as.POSIXct(as.numeric(locs$Date) * 
                  3600 * 24, origin = "1899-12-30", tz = "UTC")
            }
            else {
                stop("Error: something bad happened when trying to parse the MT file as xls or xlsx. Are you sure you're providing one of these file types?")
            }
            names(locs)[1:3] <- c("DateTime", "latitude", "longitude")
            if (is_west) 
                locs$longitude <- locs$longitude * -1
            mti.new <- reshape2::melt(locs, id.vars = c("DateTime"), 
                measure.vars = c("latitude", "longitude"))
            mti.new$VariableName <- mti.new$variable
            mti.new <- merge(x = mti.new, y = obsTypes[, c("VariableID", 
                "VariableName", "VariableUnits")], by = "VariableName", 
                all.x = TRUE)
            mti.new <- mti.new[, c("DateTime", "VariableID", 
                "value", "VariableName", "VariableUnits")]
            names(mti.new) <- c("DateTime", "VariableID", "VariableValue", 
                "VariableName", "VariableUnits")
            mti.new <- mti.new[order(mti.new$DateTime, mti.new$VariableID), 
                ]
            mti.new$DateTime <- as.POSIXct(mti.new$DateTime, 
                tz = "UTC")
            mti.new$DateTime <- format(mti.new$DateTime, "%Y-%m-%d %H:%M:%S")
            mti.new <- mti.new %>% filter(!is.na(VariableValue))
            if (exists("returnData")) {
                returnData <- rbind(returnData, mti.new)
            }
            else {
                returnData <- mti.new
            }
        }
    }
    if (exists("fe")) 
        rm(fe)
    if (tagtype == "popup" & manufacturer == "Microwave") {
        if (is.null(fName)) 
            stop("fName of target XLS file must be specified if manufacturer is Microwave.")
        fList <- list.files(dir, full.names = T)
        fidx <- grep(fName, fList)
        if (length(fidx) == 0) {
            print(paste("No Microwave data to gather using", 
                fName, ".", sep = ""))
            fe <- FALSE
        }
        else if (length(fidx) > 1) {
            stop(paste(length(fidx), "files match", fName, "in the current directory. Ensure there are no duplicated extensions or filenames and try again."))
        }
        else if (length(fidx) == 1) {
            fe <- TRUE
        }
        if (fe) {
            print(paste("Reading min max statistics from", fName, 
                "..."))
            xl_type <- readxl::excel_format(fList[fidx])
            if (xl_type == "xls") {
                depth_mm <- try(gdata::read.xls(fList[fidx], 
                  sheet = "Press Data (MinMax)", skip = 1, header = T), 
                  TRUE)
            }
            else if (xl_type == "xlsx") {
                depth_mm <- try(openxlsx::read.xlsx(fList[fidx], 
                  sheet = "Press Data (MinMax)", startRow = 2), 
                  TRUE)
            }
            else {
                stop("Error: something bad happened when trying to parse the MT file as xls or xlsx. Are you sure you're providing one of these file types?")
            }
            if (class(depth_mm) == "try-error") {
                print("Unable to read data for min max statistics. Likely there is no sheet named Press Data (MinMax).")
            }
            else {
                depth_mm <- depth_mm[, 1:5]
                names(depth_mm)[1] <- "Date.Time"
                xl_type <- readxl::excel_format(fList[fidx])
                if (xl_type == "xls") {
                  temp_mm <- gdata::read.xls(fList[fidx], sheet = "Temp Data (MinMax)", 
                    skip = 1, header = T)[, 1:5]
                  light_mm <- gdata::read.xls(fList[fidx], sheet = "Light Data (MinMax)", 
                    skip = 1, header = T)[, 1:5]
                  depth_mm$Date <- as.POSIXct(depth_mm$Date.Time, 
                    format = "%m/%d/%y", tz = "UTC")
                  temp_mm$Date <- as.POSIXct(temp_mm$Date.Time, 
                    format = "%m/%d/%y", tz = "UTC")
                  light_mm$Date <- as.POSIXct(light_mm$Date.Time, 
                    format = "%m/%d/%y", tz = "UTC")
                }
                else if (xl_type == "xlsx") {
                  temp_mm <- openxlsx::read.xlsx(fList[fidx], 
                    sheet = "Temp Data (MinMax)", startRow = 2)[, 
                    1:5]
                  names(temp_mm)[1] <- "Date.Time"
                  light_mm <- openxlsx::read.xlsx(fList[fidx], 
                    sheet = "Light Data (MinMax)", startRow = 2)[, 
                    1:5]
                  names(light_mm)[1] <- "Date.Time"
                  depth_mm$Date <- as.POSIXct(as.numeric(depth_mm$Date.Time) * 
                    3600 * 24, origin = "1899-12-30", tz = "UTC")
                  temp_mm$Date <- as.POSIXct(as.numeric(temp_mm$Date.Time) * 
                    3600 * 24, origin = "1899-12-30", tz = "UTC")
                  light_mm$Date <- as.POSIXct(as.numeric(light_mm$Date.Time) * 
                    3600 * 24, origin = "1899-12-30", tz = "UTC")
                }
                mti <- merge(depth_mm, temp_mm, by = "Date")
                mti <- merge(mti, light_mm, by = "Date")
                mti <- mti[which(mti$Date >= dates[1] & mti$Date <= 
                  dates[2]), ]
                names(mti)[1] <- "DateTime"
                names(mti)[5] <- "depthMin"
                names(mti)[6] <- "depthMax"
                names(mti)[10] <- "tempMin"
                names(mti)[11] <- "tempMax"
                names(mti)[13] <- "lightMin"
                names(mti)[14] <- "lightMax"
                mti$depthMin <- abs(mti$depthMin)
                mti$depthMax <- abs(mti$depthMax)
                mti.new <- reshape2::melt(mti, id.vars = c("DateTime"), 
                  measure.vars = c("depthMin", "depthMax", "tempMin", 
                    "tempMax", "lightMin", "lightMax"))
                mti.new$VariableName <- mti.new$variable
                mti.new <- merge(x = mti.new, y = obsTypes[, 
                  c("VariableID", "VariableName", "VariableUnits")], 
                  by = "VariableName", all.x = TRUE)
                mti.new <- mti.new[, c("DateTime", "VariableID", 
                  "value", "VariableName", "VariableUnits")]
                names(mti.new) <- c("DateTime", "VariableID", 
                  "VariableValue", "VariableName", "VariableUnits")
                mti.new <- mti.new[order(mti.new$DateTime, mti.new$VariableID), 
                  ]
                mti.new$DateTime <- as.POSIXct(mti.new$DateTime, 
                  tz = "UTC")
                mti.new$DateTime <- format(mti.new$DateTime, 
                  "%Y-%m-%d %H:%M:%S")
                mti.new <- mti.new %>% filter(!is.na(VariableValue))
                if (exists("returnData")) {
                  returnData <- rbind(returnData, mti.new)
                }
                else {
                  returnData <- mti.new
                }
            }
        }
    }
    if (exists("fe")) 
        rm(fe)
    if ((tagtype == "popup" | tagtype == "archival") & (manufacturer == 
        "Wildlife" | manufacturer == "Wildlife Computers")) {
        print("Reading Wildlife Computers popup or archival tag")
        fList <- list.files(dir, full.names = T)
        fidx <- grep("-PDTs.csv", fList)
        if (length(fidx) == 0) {
            print("No PDT data to gather.")
            fe <- FALSE
        }
        else if (length(fidx) > 1) {
            stop(paste(length(fidx), "files match -PDTs.csv in the current directory. Ensure there are no duplicated extensions and try again."))
        }
        else if (length(fidx) == 1) {
            fe <- TRUE
        }
        if (fe) {
            print("Getting PDT data...")
            pdt <- read.wc(filename = fList[fidx], type = "pdt", 
                tag = dates[1], pop = dates[2])
            pdt.new <- pdt
            dtime <- difftime(pdt$Date[2:nrow(pdt)], pdt$Date[1:(nrow(pdt) - 
                1)], units = "hours")
            pdt.new$summaryPeriod <- Mode(dtime[dtime != 0])
            nms <- names(pdt.new)
            nms[grep("MinTemp", nms)] <- "TempMin"
            nms[grep("MaxTemp", nms)] <- "TempMax"
            names(pdt.new) <- nms
            pdt.new <- reshape2::melt(pdt.new, id.vars = c("Date", 
                "BinNum"), measure.vars = c("Depth", "TempMin", 
                "TempMax", "summaryPeriod"))
			### Tim's edits - 2022-06-29 some NAs in BinNum 
            pdt.new <- na.omit(pdt.new)
            ### --- End of Tim's edits --- ###			
            binchar <- pdt.new$BinNum
            for (i in 1:length(binchar)) if (nchar(binchar[i]) < 
                2) 
                binchar[i] <- paste("0", binchar[i], sep = "")
            pdt.new$VariableName <- paste("Pdt", pdt.new$variable, 
                binchar, sep = "")
            pdt.new <- pdt.new[-grep("Pdtsumm", pdt.new$VariableName), 
                ]
            pdt.new <- merge(x = pdt.new, y = obsTypes[, c("VariableID", 
                "VariableName", "VariableUnits")], by = "VariableName", 
                all.x = TRUE)
            pdt.new <- pdt.new[, c("Date", "VariableID", "value", 
                "VariableName", "VariableUnits")]
            names(pdt.new) <- c("DateTime", "VariableID", "VariableValue", 
                "VariableName", "VariableUnits")
            pdt.new <- pdt.new[order(pdt.new$DateTime, pdt.new$VariableID), 
                ]
            pdt.new$DateTime <- as.POSIXct(pdt.new$DateTime, 
                tz = "UTC")
            pdt.new$DateTime <- format(pdt.new$DateTime, "%Y-%m-%d %H:%M:%S")
            pdt.new <- pdt.new[which(!is.na(pdt.new$VariableID)), ]
			### Tim's edits
			print(head(pdt.new))
			print(paste("--- Missing variable values found: ", sum(is.na(pdt.new$VariableValue)), "---"))
            if (exists("returnData")) {
                returnData <- rbind(returnData, pdt.new)
            }
            else {
                returnData <- pdt.new
            }
        }
        if (exists("fe")) 
            rm(fe)
        fList <- list.files(dir, full.names = T)
        fidx <- grep("-GPE2.csv", fList)
        if (length(fidx) == 0) {
            print("No GPE2 data to gather.")
            fe <- FALSE
        }
        else if (length(fidx) > 1) {
            stop(paste(length(fidx), "files match -GPE2.csv in the current directory. Ensure there are no duplicated extensions and try again."))
        }
        else if (length(fidx) == 1) {
            fe <- TRUE
        }
        if (fe) {
            print("Getting GPE2 data...")
            locs <- read.table(fList[fidx], sep = ",", header = T)
            nms <- names(locs)
            nms[grep("Longitude", nms)] <- "longitude"
            nms[grep("Latitude", nms)] <- "latitude"
            nms[grep("Error.Semi.major.axis", nms)] <- "latitudeError"
            nms[grep("Error.Semi.minor.axis", nms)] <- "longitudeError"
            names(locs) <- nms
            locs$latitudeError <- locs$latitudeError/1000/110
            locs$longitudeError <- locs$longitudeError/1000/110
            locs.new <- reshape2::melt(locs, id.vars = c("Date"), 
                measure.vars = c("longitude", "latitude", "longitudeError", 
                  "latitudeError"))
            names(locs.new)[2] <- "VariableName"
            locs.new <- merge(x = locs.new, y = obsTypes[, c("VariableID", 
                "VariableName", "VariableUnits")], by = "VariableName", 
                all.x = TRUE)
            locs.new <- locs.new[, c("Date", "VariableID", "value", 
                "VariableName", "VariableUnits")]
            names(locs.new) <- c("DateTime", "VariableID", "VariableValue", 
                "VariableName", "VariableUnits")
            locs.new$DateTime <- testDates(locs.new$DateTime)
            locs.new$DateTime <- format(locs.new$DateTime, "%Y-%m-%d %H:%M:%S")
            locs.new <- locs.new[which(!is.na(locs.new$VariableID)), ]
			### Tim's edits
			print(head(locs.new))
			print(paste("--- Missing variable values found: ", sum(is.na(locs.new$VariableValue)), "---"))
            if (exists("returnData")) {
                returnData <- rbind(returnData, locs.new)
            }
            else {
                returnData <- locs.new
            }
        }
        if (exists("fe")) 
            rm(fe)
        fList <- list.files(dir, full.names = T)
        fidx <- grep("-Archive.csv", fList)
        if (length(fidx) == 0) {
            print("No Archive data to read.")
            fe <- FALSE
        }
        else if (length(fidx) > 1) {
            stop(paste(length(fidx), "files match -Archive.csv in the current directory. Ensure there are no duplicated extensions and try again."))
        }
        else if (length(fidx) == 1) {
            fe <- TRUE
        }
        if (fe) {
            print("Getting Archival data...")
            arch <- data.frame(data.table::fread(fList[fidx], 
                sep = ",", header = T, stringsAsFactors = F, 
                fill = TRUE))
            nms <- names(arch)
            temp_col <- grep("^Temperature$", nms)
            if (length(temp_col) != 1) {
                temp_col <- grep("^External.Temperature$", nms)
                if (length(temp_col) != 1) {
                  temp_col <- grep("^Stalk.Temp$", nms)
                }
            }
            intemp_col <- grep("^Internal.Temperature$", nms)
            if (length(intemp_col) != 1) {
                intemp_col <- grep("^Recorder.Temp$", nms)
            }
            depth_col <- grep("^Depth$", nms)
            light_col <- grep("^Light.Level$", nms)
            time_col <- grep("^Time$", nms)
            if (length(intemp_col) > 0) {
                arch <- arch[, c(time_col, depth_col, temp_col, 
                  intemp_col, light_col)]
                names(arch) <- c("DateTime", "depth", "temperature", 
                  "internalTemperature", "light")
                meas.vars <- c("depth", "temperature", "internalTemperature", 
                  "light")
            }
            else {
                arch <- arch[, c(time_col, depth_col, temp_col, 
                  light_col)]
                names(arch) <- c("DateTime", "depth", "temperature", 
                  "light")
                meas.vars <- c("depth", "temperature", "light")
            }
            x <- findDateFormat(arch$DateTime[1:10])
            arch$DateTime <- lubridate::parse_date_time(arch$DateTime, 
                orders = x, tz = "UTC")
            arch.new <- arch[which(arch$DateTime >= dates[1] & arch$DateTime <= dates[2]), ]
            arch.new <- reshape2::melt(arch.new, id.vars = c("DateTime"), 
                measure.vars = meas.vars)
            arch.new$VariableName <- arch.new$variable
            arch.new <- dplyr::left_join(x = arch.new, y = obsTypes[, 
                c("VariableID", "VariableName", "VariableUnits")], 
                by = "VariableName")
            arch.new <- arch.new[, c("DateTime", "VariableID", 
                "value", "VariableName", "VariableUnits")]
            names(arch.new) <- c("DateTime", "VariableID", "VariableValue", 
                "VariableName", "VariableUnits")
            arch.new <- arch.new[order(arch.new$DateTime, arch.new$VariableID), 
                ]
            arch.new <- arch.new[which(!is.na(arch.new$VariableValue)), 
                ]
            if (class(arch.new$DateTime[1])[1] != "POSIXct") {
                x <- findDateFormat(arch.new$DateTime[1:10])
                arch.new$DateTime <- lubridate::parse_date_time(arch.new$DateTime, 
                  orders = x, tz = "UTC")
            }
            arch.new$DateTime <- format(arch.new$DateTime, "%Y-%m-%d %H:%M:%S")
			### Tim's edits
			print(head(arch.new))
			print(paste("--- Missing variable values found: ", sum(is.na(arch.new$VariableValue)), "---"))
            if (exists("returnData")) {
                returnData <- rbind(returnData, arch.new)
            }
            else {
                returnData <- arch.new
            }
            rm(arch)
            gc()
        }
        if (exists("fe")) 
            rm(fe)
        fList <- list.files(dir, full.names = T)
        fidx <- grep("-Series.csv", fList)
        if (length(fidx) == 0) {
            print(paste("No Wildlife Series data to gather.", 
                sep = ""))
            fe <- FALSE
        }
        else if (length(fidx) > 1) {
            stop(paste(length(fidx), "files match -Series.csv in the current directory. Ensure there are no duplicated extensions and try again."))
        }
        else if (length(fidx) == 1) {
            fe <- TRUE
        }
        if (fe & !exists("arch.new")) {
            print("Getting Series data...")
			### --- Tim's edits: modify WC csv spreadsheet header --- ###
			filename = fList[fidx]
			fsuffix = "Series"
			if (check.line1(filename)) filename <- modify.wchead(filename,fsuffix)
			series <- utils::read.table(filename, sep = ",", header = T, blank.lines.skip = F)
            ncheck <- grepl("DepthSensor", paste(names(series),collapse=" "), fixed=T)
            #series <- utils::read.table(fList[fidx], sep = ",", header = T, blank.lines.skip = F)
			series$dt <- lubridate::parse_date_time(paste(series$Day, series$Time), orders = "dby HMS", tz = "UTC") 	
            series <- series[which(series$dt >= dates[1] & series$dt <= dates[2]), ]
			# Don't quite know why we have to subset but anyways...
            if (ncheck) {
			  series.new <- subset(series, select = -c(DepthSensor))
			} else {
			  series.new = series
			}
			### --- End of Tim's edits --- ###
            nms <- names(series.new)
            nms[grep("Depth", nms)] <- "depth"
            nms[grep("DRange", nms)] <- "depthDelta"
            nms[grep("Temperature", nms)] <- "temperature"
            nms[grep("TRange", nms)] <- "tempDelta"
            names(series.new) <- nms
            series.new <- reshape2::melt(series.new, id.vars = c("dt"), 
                measure.vars = c("depth", "depthDelta", "temperature", 
                  "tempDelta"))
            series.new$VariableName <- series.new$variable
            series.new <- merge(x = series.new, y = obsTypes[, 
                c("VariableID", "VariableName", "VariableUnits")], 
                by = "VariableName", all.x = TRUE)
            series.new <- series.new[, c("dt", "VariableID", 
                "value", "VariableName", "VariableUnits")]
            names(series.new) <- c("DateTime", "VariableID", 
                "VariableValue", "VariableName", "VariableUnits")
            series.new <- series.new[order(series.new$DateTime, 
                series.new$VariableID), ]
            series.new <- series.new[which(!is.na(series.new$VariableValue)), 
                ]
            series.new$DateTime <- as.POSIXct(series.new$DateTime, 
                tz = "UTC")
            series.new$DateTime <- format(series.new$DateTime, 
                "%Y-%m-%d %H:%M:%S")
			### Tim's edits
			print(head(series.new))	
			print(paste("--- Missing variable values found: ", sum(is.na(series.new$VariableValue)), "---"))
            if (exists("returnData")) {
                returnData <- rbind(returnData, series.new)
            }
            else {
                returnData <- series.new
            }
        }
        if (exists("fe")) 
            rm(fe)
        fList <- list.files(dir, full.names = T)
        fidx <- grep("-LightLoc.csv", fList)
        if (length(fidx) == 0) {
            print(paste("No Wildlife light data to gather.", 
                sep = ""))
            fe <- FALSE
        }
        else if (length(fidx) > 1) {
            stop(paste(length(fidx), "files match -light.csv in the current directory. Ensure there are no duplicated extensions and try again."))
        }
        else if (length(fidx) == 1) {
            fe <- TRUE
        }
        if (fe & !exists("arch.new")) {
            print("Getting light data...")
            light <- try(utils::read.table(fList[fidx], sep = ",", 
                header = T, blank.lines.skip = F, skip = 2), 
                silent = TRUE)
            if (class(light) == "try-error") {
                light <- try(utils::read.table(fList[fidx], sep = ",", 
                  header = T, blank.lines.skip = F, skip = 0), 
                  silent = TRUE)
                if (class(light) == "try-error") {
                  stop("Cant read light data.")
                }
                else {
                  light <- utils::read.table(fList[fidx], sep = ",", 
                    header = T, blank.lines.skip = F, skip = 0)
                }
            }
            else {
                light <- utils::read.table(fList[fidx], sep = ",", 
                  header = T, blank.lines.skip = F, skip = 2)
            }
            light.new <- extract.light(light) 
            light.new <- light.new[which(light.new$Date >= dates[1] & light.new$Date <= dates[2]), ]	
            nms <- names(light.new)
            nms[grep("MinDepth", nms)] <- "depthMin"
            nms[grep("MaxDepth", nms)] <- "depthMax"
            nms[grep("Depth", nms, ignore.case = FALSE)] <- "depth"
            nms[grep("LL", nms)] <- "light"
            names(light.new) <- nms
            light.new <- reshape2::melt(light.new, id.vars = c("Date"), 
                measure.vars = c("depth", "depthMin", "depthMax", 
                  "light"))
            light.new$VariableName <- light.new$variable
            light.new <- merge(x = light.new, y = obsTypes[, 
                c("VariableID", "VariableName", "VariableUnits")], 
                by = "VariableName", all.x = TRUE)
            light.new <- light.new[, c("Date", "VariableID", 
                "value", "VariableName", "VariableUnits")]
            names(light.new) <- c("DateTime", "VariableID", "VariableValue", 
                "VariableName", "VariableUnits")
            light.new <- light.new[order(light.new$DateTime, 
                light.new$VariableID), ]
            light.new <- light.new[which(!is.na(light.new$VariableValue)), 
                ]
            light.new$DateTime <- as.POSIXct(light.new$DateTime, 
                tz = "UTC")
            light.new$DateTime <- format(light.new$DateTime, 
                "%Y-%m-%d %H:%M:%S")
            light.new <- light.new %>% distinct(DateTime, VariableID, 
                .keep_all = TRUE)
			### Tim's edits
			print(head(light.new))
			print(paste("--- Missing variable values found: ", sum(is.na(light.new$VariableValue)), "---"))			
            if (exists("returnData")) {
                returnData <- rbind(returnData, light.new)
            }
            else {
                returnData <- light.new
            }
        }
        if (exists("fe")) 
            rm(fe)
        fList <- list.files(dir, full.names = T)
        fidx <- grep("-MinMaxDepth.csv", fList)
        if (length(fidx) == 0) {
            print(paste("No Wildlife MinMaxDepth data to gather.", sep = ""))
            fe <- FALSE
        }
        else if (length(fidx) > 1) {
            stop(paste(length(fidx), "files match -MinMaxDepth.csv in the current directory. Ensure there are no duplicated extensions and try again."))
        }
        else if (length(fidx) == 1) {
            fe <- TRUE
        }
        if (fe) {
            print("Getting min/max depth data...")
			### --- Tim's edits: modify WC csv spreadsheet header --- ###
			filename = fList[fidx]
			fsuffix = "MinMaxDepth"
			if (check.line1(filename)) filename <- modify.wchead(filename,fsuffix)
			mmd <- utils::read.table(filename, sep = ",", header = T, blank.lines.skip = F)	
			#mmd <- utils::read.table(fList[fidx], sep = ",", header = T, blank.lines.skip = F)
            mmd$dt <- lubridate::parse_date_time(mmd$Date, orders = findDateFormat(mmd$Date), tz = "UTC")
			if (sum(is.na(mmd$dt))>0) mmd$dt <- format.datetime(mmd$Date)
            ### --- End of Tim's edits --- ###			
            mmd <- mmd[which(mmd$dt >= dates[1] & mmd$dt <= dates[2]), ]
            mmd.new <- mmd
            nms <- names(mmd.new)
            nms[grep("MinDepth", nms)] <- "depthMin"
            nms[grep("MaxDepth", nms)] <- "depthMax"
            names(mmd.new) <- nms
            mmd.new <- reshape2::melt(mmd.new, id.vars = c("dt"), 
                measure.vars = c("depthMin", "depthMax"))
            mmd.new$VariableName <- mmd.new$variable
            mmd.new <- merge(x = mmd.new, y = obsTypes[, c("VariableID", 
                "VariableName", "VariableUnits")], by = "VariableName", 
                all.x = TRUE)
            mmd.new <- mmd.new[, c("dt", "VariableID", "value", 
                "VariableName", "VariableUnits")]
            names(mmd.new) <- c("DateTime", "VariableID", "VariableValue", 
                "VariableName", "VariableUnits")
            mmd.new <- mmd.new[order(mmd.new$DateTime, mmd.new$VariableID), 
                ]
            mmd.new$DateTime <- as.POSIXct(mmd.new$DateTime, 
                tz = "UTC")
            mmd.new$DateTime <- format(mmd.new$DateTime, "%Y-%m-%d %H:%M:%S")
			### Tim's edits
			print(head(mmd.new))
			print(paste("--- Missing variable values found: ", sum(is.na(mmd.new$VariableValue)), "---"))
            if (exists("returnData")) {
                returnData <- rbind(returnData, mmd.new)
            }
            else {
                returnData <- mmd.new
            }
        }
        if (exists("fe")) 
            rm(fe)
        fList <- list.files(dir, full.names = T)
        fidx <- grep("-SST.csv", fList)
        if (length(fidx) == 0) {
            print(paste("No Wildlife SST data to gather.", sep = ""))
            fe <- FALSE
        }
        else if (length(fidx) > 1) {
            stop(paste(length(fidx), "files match -SST.csv in the current directory. Ensure there are no duplicated extensions and try again."))
        }
        else if (length(fidx) == 1) {
            fe <- TRUE
        }
        if (fe) {
            print("Getting SST data...")
		    ### --- Tim's edits: modify WC csv spreadsheet header --- ###
			filename = fList[fidx]
			fsuffix = "SST"
			if (check.line1(filename)) filename <- modify.wchead(filename,fsuffix)
			sst <- utils::read.table(filename, sep = ",", header = T, blank.lines.skip = F)
			#sst <- utils::read.table(fList[fidx], sep = ",", header = T, blank.lines.skip = F)
            sst$dt <- lubridate::parse_date_time(sst$Date, orders = findDateFormat(sst$Date), tz = "UTC")
			if (sum(is.na(sst$dt))>0) sst$dt <- format.datetime(sst$Date)		
			### --- Tim's edits 2022-03-10: remove the need to trim to be within start & end dates --- ###			
            #sst <- sst[which(sst$dt >= dates[1] & sst$dt <= dates[2]), ]
			### --- End of Tim's edits --- ###	
            sst.new <- parse_sst(sst, obsTypes)
			### Tim's edits
			print(head(sst.new))
			print(paste("--- Missing variable values found: ", sum(is.na(sst.new$VariableValue)), "---"))
            if (exists("returnData")) {
                returnData <- rbind(returnData, sst.new)
            }
            else {
                returnData <- sst.new
            }
        }
        if (exists("fe")) 
            rm(fe)
        fList <- list.files(dir, full.names = T)
        fidx <- grep("-MixLayer.csv", fList)
        if (length(fidx) == 0) {
            print(paste("No Wildlife MixedLayer data to gather.", 
                sep = ""))
            fe <- FALSE
        }
        else if (length(fidx) > 1) {
            stop(paste(length(fidx), "files match -MixedLayer.csv in the current directory. Ensure there are no duplicated extensions and try again."))
        }
        else if (length(fidx) == 1) {
            fe <- TRUE
        }
        if (fe) {
            print("Getting MixedLayer data...")
			### --- Tim's edits: modify WC csv spreadsheet header --- ###
			filename = fList[fidx]
			fsuffix = "MixedLayer"
			if (check.line1(filename)) filename <- modify.wchead(filename,fsuffix)
			ml <- utils::read.table(filename, sep = ",", header = T, blank.lines.skip = F)
			ml$dt <- lubridate::parse_date_time(ml$Date, orders = findDateFormat(ml$Date), tz = "UTC")
			if (sum(is.na(ml$dt))>0) {
			   ml$Date <- format.datetime(ml$Date)
			} else {
			   ml$Date <- ml$dt
			}
			#ml <- utils::read.table(fList[fidx], sep = ",", header = T, blank.lines.skip = F)
            #ml$Date <- lubridate::parse_date_time(ml$Date, orders = findDateFormat(ml$Date), tz = "UTC")
			### --- End of Tim's edits --- ###
            ml <- ml[which(ml$Date >= dates[1] & ml$Date <= dates[2]), ]
            ml.new <- ml
            nms <- names(ml.new)
            nms[grep("SSTAve", nms)] <- "sstMean"
            nms[grep("SSTmin", nms)] <- "sstMin"
            nms[grep("SSTmax", nms)] <- "sstMax"
            nms[grep("TempMin", nms)] <- "tempMin"
            nms[grep("DepthMin", nms)] <- "depthMin"
            nms[grep("DepthMax", nms)] <- "depthMax"
            nms[grep("Hours", nms)] <- "summaryPeriod"
            names(ml.new) <- nms
            ml.new <- reshape2::melt(ml.new, id.vars = c("Date"), 
                measure.vars = c("depthMin", "depthMax", "sstMean", 
                  "sstMin", "sstMax", "tempMin"))
            ml.new$VariableName <- ml.new$variable
            ml.new <- merge(x = ml.new, y = obsTypes[, c("VariableID", 
                "VariableName", "VariableUnits")], by = "VariableName", 
                all.x = TRUE)
            ml.new <- ml.new[, c("Date", "VariableID", "value", 
                "VariableName", "VariableUnits")]
            names(ml.new) <- c("DateTime", "VariableID", "VariableValue", 
                "VariableName", "VariableUnits")
            ml.new <- ml.new[order(ml.new$DateTime, ml.new$VariableID), 
                ]
            ml.new <- ml.new[which(!is.na(ml.new$VariableValue)), 
                ]
            ml.new$DateTime <- as.POSIXct(ml.new$DateTime, tz = "UTC")
            ml.new$DateTime <- format(ml.new$DateTime, "%Y-%m-%d %H:%M:%S")
			### Tim's edits
			print(head(ml.new))
			print(paste("--- Missing variable values found: ", sum(is.na(ml.new$VariableValue)), "---"))
            if (exists("returnData")) {
                returnData <- rbind(returnData, ml.new)
            }
            else {
                returnData <- ml.new
            }
        }
        if (exists("fe")) 
            rm(fe)
        fList <- list.files(dir, full.names = T)
        fidx <- grep("-Histos.csv", fList)
        if (length(fidx) == 0) {
            print(paste("No Wildlife Histos data to gather.", 
                sep = ""))
            fe <- FALSE
        }
        else if (length(fidx) > 1) {
            stop(paste(length(fidx), "files match -Histos.csv in the current directory. Ensure there are no duplicated extensions and try again."))
        }
        else if (length(fidx) == 1) {
            fe <- TRUE
        }
        if (fe) {
            print("Getting Histos data...")
			### --- Tim's edits: modify WC csv spreadsheet header --- ###
			filename = fList[fidx]
			fsuffix = "Histos"
			if (check.line1(filename)) filename <- modify.wchead(filename,fsuffix)
			histo <- utils::read.table(filename, sep = ",", header = T, blank.lines.skip = F)			
            #histo <- utils::read.table(fList[fidx], sep = ",", header = T, blank.lines.skip = F)
			### --- End of Tim's edits --- ###
            tat.lim <- histo[which(histo$HistType == "TATLIMITS"), 
                grep("Bin", names(histo))]
            tat.lim <- Filter(function(x) !all(is.na(x)), tat.lim)
            tad.lim <- histo[which(histo$HistType == "TADLIMITS"), 
                grep("Bin", names(histo))]
            tad.lim <- c(Filter(function(x) !all(is.na(x)), tad.lim))
            if (all(is.na(tat.lim)) & !is.null(tatBins)) {
                tat.lim <- tatBins
            }
            else if (all(is.na(tat.lim)) & is.null(tatBins)) {
                stop("TAT bins could not be read from file and were not specified in function call. Please specify them and try again.")
            }
            if (all(is.na(tad.lim)) & !is.null(tadBins)) {
                tad.lim <- tadBins
            }
            else if (all(is.na(tad.lim)) & is.null(tadBins)) {
                stop("TAD bins could not be read from file and were not specified in function call. Please specify them and try again.")
            }
            histo <- histo[which(!is.na(histo$Sum)), ]
            histo$dt <- lubridate::parse_date_time(histo$Date, orders = findDateFormat(histo$Date), tz = "UTC")
			### --- Tim's edits 2022-06-29: need to specify date format for desktop DAP generated files, at least for ICCAT's Stasa examples --- ###	
			if (sum(is.na(histo$dt))>0) histo$dt <- format.datetime(histo$Date)
			### --- End of Tim's edits --- ###	
            histo <- histo[which(histo$dt >= dates[1] & histo$dt <=  dates[2]), ]
            histo <- subset(histo, select = -c(NumBins))
            tat <- histo[which(histo$HistType == "TAT"), ]
            tat$summaryPeriod <- Mode(difftime(tat$dt[2:nrow(tat)], 
                tat$dt[1:(nrow(tat) - 1)], units = "hours"))
            nms <- names(tat)
            nms[grep("Bin1$", nms)] <- "TimeAtTempBin01"
            nms[grep("Bin2$", nms)] <- "TimeAtTempBin02"
            nms[grep("Bin3$", nms)] <- "TimeAtTempBin03"
            nms[grep("Bin4$", nms)] <- "TimeAtTempBin04"
            nms[grep("Bin5$", nms)] <- "TimeAtTempBin05"
            nms[grep("Bin6$", nms)] <- "TimeAtTempBin06"
            nms[grep("Bin7$", nms)] <- "TimeAtTempBin07"
            nms[grep("Bin8$", nms)] <- "TimeAtTempBin08"
            nms[grep("Bin9$", nms)] <- "TimeAtTempBin09"
            nms[grep("Bin10$", nms)] <- "TimeAtTempBin10"
            nms[grep("Bin11$", nms)] <- "TimeAtTempBin11"
            nms[grep("Bin12$", nms)] <- "TimeAtTempBin12"
            nms[grep("Bin13$", nms)] <- "TimeAtTempBin13"
            nms[grep("Bin14$", nms)] <- "TimeAtTempBin14"
            nms[grep("Bin15$", nms)] <- "TimeAtTempBin15"
            nms[grep("Bin16$", nms)] <- "TimeAtTempBin16"
            names(tat) <- nms
            tat <- Filter(function(x) !all(is.na(x)), tat)
            tat.new <- reshape2::melt(tat, id.vars = c("dt"), 
                measure.vars = c(grep("Bin", names(tat)), grep("summaryPeriod", 
                  names(tat))))
            tad <- histo[which(histo$HistType == "TAD"), ]
            tad$summaryPeriod <- Mode(difftime(tad$dt[2:nrow(tad)], 
                tad$dt[1:(nrow(tad) - 1)], units = "hours"))
            nms <- names(tad)
            nms[grep("Bin1$", nms)] <- "TimeAtDepthBin01"
            nms[grep("Bin2$", nms)] <- "TimeAtDepthBin02"
            nms[grep("Bin3$", nms)] <- "TimeAtDepthBin03"
            nms[grep("Bin4$", nms)] <- "TimeAtDepthBin04"
            nms[grep("Bin5$", nms)] <- "TimeAtDepthBin05"
            nms[grep("Bin6$", nms)] <- "TimeAtDepthBin06"
            nms[grep("Bin7$", nms)] <- "TimeAtDepthBin07"
            nms[grep("Bin8$", nms)] <- "TimeAtDepthBin08"
            nms[grep("Bin9$", nms)] <- "TimeAtDepthBin09"
            nms[grep("Bin10$", nms)] <- "TimeAtDepthBin10"
            nms[grep("Bin11$", nms)] <- "TimeAtDepthBin11"
            nms[grep("Bin12$", nms)] <- "TimeAtDepthBin12"
            nms[grep("Bin13$", nms)] <- "TimeAtDepthBin13"
            nms[grep("Bin14$", nms)] <- "TimeAtDepthBin14"
            nms[grep("Bin15$", nms)] <- "TimeAtDepthBin15"
            nms[grep("Bin16$", nms)] <- "TimeAtDepthBin16"
            names(tad) <- nms
            tad <- Filter(function(x) !all(is.na(x)), tad)
            tad.new <- reshape2::melt(tad, id.vars = c("dt"), 
                measure.vars = c(grep("Bin", names(tad)), grep("summaryPeriod", 
                  names(tad))))
            histo.new <- rbind(tat.new, tad.new)
            histo.new$VariableName <- histo.new$variable
            histo.new <- merge(x = histo.new, y = obsTypes[, 
                c("VariableID", "VariableName", "VariableUnits")], 
                by = "VariableName", all.x = TRUE)
            histo.new <- histo.new[, c("dt", "VariableID", "value", 
                "VariableName", "VariableUnits")]
            names(histo.new) <- c("DateTime", "VariableID", "VariableValue", 
                "VariableName", "VariableUnits")
            hdb <- obsTypes[grep("HistDepthBin", obsTypes$VariableName), 
                c("VariableID", "VariableName")]
            hdb$Value <- NA
            hdb$Value[1] <- 0
            idx <- grep("Max", hdb$VariableName)[1:length(tad.lim)]
            for (zz in idx) {
                hdb$Value[zz] <- unlist(tad.lim[which(idx == 
                  zz)])
                if (which(idx == zz) != 1 & !is.na(unlist(tad.lim[which(idx == 
                  zz)]))) 
                  hdb$Value[zz - 1] <- unlist(tad.lim[which(idx == 
                    zz) - 1]) + 0.1
            }
            hdb <- hdb[which(!is.na(hdb$Value)), ]
            if (hdb$Value[1] > hdb$Value[2]) 
                hdb$Value[1] <- -10
            htb <- obsTypes[grep("HistTempBin", obsTypes$VariableName), 
                c("VariableID", "VariableName")]
            htb$Value <- NA
            htb$Value[1] <- 0
            idx <- grep("Max", htb$VariableName)[1:length(tat.lim)]
            for (zz in idx) {
                htb$Value[zz] <- unlist(tat.lim[which(idx == 
                  zz)])
                if (which(idx == zz) != 1 & !is.na(unlist(tat.lim[which(idx == 
                  zz)]))) 
                  htb$Value[zz - 1] <- unlist(tat.lim[which(idx == 
                    zz) - 1]) + 0.1
            }
            htb <- htb[which(!is.na(htb$Value)), ]
            if (htb$Value[1] > htb$Value[2]) 
                htb$Value[1] <- -10
            histo.new <- rbind(histo.new, data.frame(DateTime = NA, 
                VariableID = htb$VariableID, VariableValue = htb$Value, 
                VariableName = htb$VariableName, VariableUnits = "Celsius"))
            histo.new <- rbind(histo.new, data.frame(DateTime = NA, 
                VariableID = hdb$VariableID, VariableValue = hdb$Value, 
                VariableName = hdb$VariableName, VariableUnits = "meter"))
            histo.new <- histo.new[order(histo.new$DateTime, 
                histo.new$VariableID), ]
            histo.new <- histo.new[which(!is.na(histo.new$VariableValue)), 
                ]
            histo.new$DateTime <- as.POSIXct(histo.new$DateTime, 
                tz = "UTC")
            histo.new$DateTime <- format(histo.new$DateTime, 
                "%Y-%m-%d %H:%M:%S")
			### Tim's edits
			print(head(histo.new))	
			print(paste("--- Missing variable values found: ", sum(is.na(histo.new$VariableValue)), "---"))
            if (exists("returnData")) {
                returnData <- rbind(returnData, histo.new)
            }
            else {
                returnData <- histo.new
            }
        }
        if (exists("fe")) 
            rm(fe)
        fList <- list.files(dir, full.names = T)
        fidx <- grep("-GPE3.csv", fList)
        if (length(fidx) == 0 | gpe3 == FALSE) {
            print(paste("No Wildlife GPE3 data to gather.", sep = ""))
            fe <- FALSE
        }
        else if (length(fidx) > 1) {
            stop(paste(length(fidx), "files match -GPE3.csv in the current directory. Ensure there are no duplicated extensions and try again."))
        }
        else if (length(fidx) == 1) {
            fe <- TRUE
        }
        if (fe) {
            print("Getting GPE3 data...")
            ncFile <- list.files(dir, full.names = T)[grep("GPE3.nc", 
                list.files(dir, full.names = T))]
            csvFile <- list.files(dir, full.names = T)[grep("GPE3.csv", 
                list.files(dir, full.names = T))]
            if (length(ncFile) > 1 | length(csvFile) > 1) 
                stop("Multiple matches to .nc or GPE3.csv in the specified directory.")
            out <- getCtr_gpe3(ncFile, csvFile, threshold = 5, makePlot = F, scaling=gpe.scaling)
            df <- lapply(out, FUN = function(x) cbind(x$loc, x$xDist, x$yDist))
            df <- rlist::list.rbind(df)
            names(df) <- c("ptt", "date", "lat", "lon", "xDist", 
                "yDist")
            gpe <- df
            nms <- names(gpe)
            nms[grep("lon", nms)] <- "longitude"
            nms[grep("lat", nms)] <- "latitude"
            nms[grep("xDist", nms)] <- "longitudeError"
            nms[grep("yDist", nms)] <- "latitudeError"
            names(gpe) <- nms
            gpe <- reshape2::melt(gpe, id.vars = c("date"), measure.vars = c("longitude", 
                "latitude", "longitudeError", "latitudeError"))
            gpe$VariableName <- gpe$variable
            gpe <- merge(x = gpe, y = obsTypes[, c("VariableID", 
                "VariableName", "VariableUnits")], by = "VariableName", 
                all.x = TRUE)
            gpe <- gpe[, c("date", "VariableID", "value", "VariableName", 
                "VariableUnits")]
            names(gpe) <- c("DateTime", "VariableID", "VariableValue", 
                "VariableName", "VariableUnits")
            gpe <- gpe[order(gpe$DateTime, gpe$VariableID), ]
            gpe <- gpe[which(!is.na(gpe$VariableValue)), ]
            gpe$DateTime <- as.POSIXct(gpe$DateTime, tz = "UTC")
            gpe$DateTime <- format(gpe$DateTime, "%Y-%m-%d %H:%M:%S")
			### Tim's edits
			print(head(gpe))
			print(paste("--- Missing variable values found: ", sum(is.na(gpe$VariableValue)), "---"))
            if (exists("returnData")) {
                returnData <- rbind(returnData, gpe)
            }
            else {
                returnData <- gpe
            }
        }
        if (exists("fe")) 
            rm(fe)
    }
    if ((tagtype == "archival" | tagtype == "popup") & manufacturer == 
        "Lotek") {
        print("Reading Lotek archival or pop up archival tag...")
        lotek <- read_lotek(dir)
        dl <- lotek_format_dl(lotek$daylog, dates, obsTypes, 
            meta_row)
        ts <- lotek_format_ts(lotek$timeseries, dates, obsTypes, 
            meta_row)
        if (exists("returnData")) {
            returnData <- rbind(returnData, ts, dl)
        }
        else {
            returnData <- rbind(ts, dl)
        }
    }
    returnData <- distinct(returnData, DateTime, VariableName, 
        .keep_all = TRUE)
    returnData <- returnData[order(returnData$DateTime, returnData$VariableID), 
        ]
    returnData$DateTime <- as.character(returnData$DateTime)
    returnData$DateTime[which(is.na(returnData$DateTime))] <- ""
    if (exists("write_direct")) {
        if (write_direct == TRUE & exists("etuff_file")) {
		    ### --- Tim's edits 2022-03-10 ###
            # build_meta_head(meta_row = meta_row, filename = etuff_file, write_hdr = T)
			build_meta_head(meta_row = meta_row, metaTypes = metaTypes, filename=etuff_file, write_hdr = TRUE)
			### --- Tim's edits end ###
            print(utils::head(returnData))
            data.table::fwrite(returnData, file = etuff_file, 
                sep = ",", col.names = F, row.names = F, quote = F, 
                append = T)
            print(paste("Data added to eTUFF file ", etuff_file, 
                ".", sep = ""))
        }
        else {
            stop("Must specify etuff_file if write_direct = TRUE.")
        }
    }
    #print("Generating output object...")
    df <- returnData %>% dplyr::select(-c(VariableID, VariableUnits)) %>% 
        tidyfast::dt_pivot_wider(names_from = VariableName, values_from = VariableValue) %>% 
        as.data.frame()
    names(df)[1] <- "DateTime"
    print("Appending bins...")
    if (any(df$DateTime == "")) {
        bins <- df[which(df$DateTime == ""), ]
        drop_idx <- which(apply(bins, 2, FUN = function(x) all(is.na(x) | 
            x == "")))
        bins <- bins[, -drop_idx]
        df <- df[which(df$DateTime != ""), ]
    }
    if (!exists("bins")) 
        bins <- NULL
    df$DateTime <- fasttime::fastPOSIXct(df$DateTime, tz = "UTC")
    df$id <- meta_row$instrument_name
    print("------------------------------------------------")
    print("eTUFF generation completed! Time elapsed:")
	print(Sys.time() - stopwatch)
	print("------------------------------------------------")
    options(warn = defaultW)
	if (returndata){
      etuff <- list(etuff = df, meta = meta_row, bins = bins)
      class(etuff) <- "etuff"
      return(etuff)
	}
}
