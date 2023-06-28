### --- Begin Tim's edit history  --- ###
### 2023-06-15
### a) Extend limited support for LAT Viewer Studio day log output with Template Fit manufacturer geolocation
### --- End of Tim's edit history --- ###

#' Format Lotek daily log
#'
#' Format Lotek daily log data from archival tag
#'
#' @param dl is data frame of Lotek's daily log file output from \code{read_lotek}
#' @param dates is POSIXct vector (length 2) of release and recovery dates
#' @param obsTypes is csv sourced from github containing the latest obsTypes
#'   recognized by the NASA OIIP project. Usually this is left NULL and the file
#'   is automatically downloaded for you. The only reason you may want to
#'   specify this would be in order to work offline.
#' @param meta_row is data frame with nrow == 1 containing metadata
#' @param hemisphere is character indicating whether you expect your animals movements to be in the northern (N) or southern (S) hemisphere. Choices are "N" or "S".
#' @export

lotek_format_dl <- function(dl, dates, obsTypes, meta_row, hemisphere='N'){

### --- Begin Tim's edit 2023-06-15 --- ###
### Try take out TF1_ suffix from header
 hh <- unlist(strsplit(names(dl), "_"))
 jj <- grep("TF",hh)
 ignore.sun = !identical(jj, integer(0))
 if (ignore.sun) names(dl) <- hh[-grep("TF",hh)]
 dl[,1] <- format(as.POSIXct(dl[,1], format = "%d/%m/%y", tz="GMT"),"%Y-%m-%d")
 names(dl)[1] <- 'DateTime'
 # Add one more condition for ignore.sun 
 jj <- grep("depthSunrise",names(dl))
 if (identical(jj, integer(0))) ignore.sun = TRUE
 # Show a preview
 print(head(dl))
### --- End of Tim's edit --- ###

  if (!(hemisphere %in% c('N','S'))) stop('hemisphere must be either N or S')

  measure.vars <- c()

  ## rename to standard names
  sst_idx <- which(names(dl) %in% c('SSTMin'))
  names(dl)[sst_idx] <- 'sstMin'; rm(sst_idx)
  if (any(names(dl) %in% 'sstMin')){
    measure.vars[length(measure.vars) + 1] <- 'sstMin'
  }

  sst_idx <- which(names(dl) %in% c('SSTMedian'))
  names(dl)[sst_idx] <- 'sstMedian'; rm(sst_idx)
  if (any(names(dl) %in% 'sstMedian')){
    measure.vars[length(measure.vars) + 1] <- 'sstMedian'
  }

  sst_idx <- which(names(dl) %in% c('SSTMax'))
  names(dl)[sst_idx] <- 'sstMax'; rm(sst_idx)
  if (any(names(dl) %in% 'sstMax')){
    measure.vars[length(measure.vars) + 1] <- 'sstMax'
  }

### --- Begin Tim's edit 2023-06-15 --- ###  
### To allow reading files from LATVS daylog
### a) Add SST2, MinExtTemp, MaxExtTemp, SST2Depth, LatN, LatS, LonN, LonS, LatErrN, LatErrS, LonErrN, LonErrS, MaxPress to the mix
### b) Bypass Sunrise and Sunset with a flag, ignore.sun = TRUE
  
  sst_idx <- which(names(dl) %in% c('SST1[C]','SST1.C.','SST_Aquatic_[C]','SST_Aquatic_.C.','SST2'))
  names(dl)[sst_idx] <- 'sst'
  if (any(names(dl) %in% 'sst')){
    measure.vars[length(measure.vars) + 1] <- 'sst'
  }

  temp_idx <- which(names(dl) %in% c('MinExtTemp_[C]','MinExtTemp_.C.','MinExtTemp'))
  names(dl)[temp_idx] <- 'tempMin'
  if (any(names(dl) %in% 'tempMin')){
    measure.vars[length(measure.vars) + 1] <- 'tempMin'
  }

  temp_idx <- which(names(dl) %in% c('MaxExtTemp_[C]','MaxTemp','MaxExtTemp_.C.','MaxExtTemp'))
  names(dl)[temp_idx] <- 'tempMax'
  if (any(names(dl) %in% 'tempMax')){
    measure.vars[length(measure.vars) + 1] <- 'tempMax'
  }

  dep_idx <- which(names(dl) %in% c('SST1Depth[dBars]',	'SST1Depth.dBars.', 'DepthForSST','SST_Aquatic_Pressure_[dBar]','SST_Aquatic_Pressure_.dBar.','SST2Depth'))
  names(dl)[dep_idx] <- 'sstDepth'; rm(dep_idx)
  if (any(names(dl) %in% 'sstDepth')){
    dl$sstDepth <- oce::swDepth(dl$sstDepth, as.numeric(meta_row$geospatial_lat_start))
    measure.vars[length(measure.vars) + 1] <- 'sstDepth'
  }

  lat_idx <- which(names(dl) %in% c("LatN_.deg.", "LatS_.deg.",'LatN', 'LatS'))
  if (length(lat_idx) >= 1){
    if (hemisphere == 'N'){
      lat_idx <- which(names(dl) %in% c("LatN_.deg.",'LatN'))
      names(dl)[lat_idx] <- 'latitude'
      print('Lotek Template-Fit latitude: using movement data from the northern hemisphere. If that is incorrect, see the hemisphere input argument.')

      lat_err_idx <- which(names(dl) %in% c("LatErrN_.deg.",'LatErrN'))
      names(dl)[lat_err_idx] <- 'latitudeError'
      if (any(names(dl) %in% 'latitudeError')){
        measure.vars[length(measure.vars) + 1] <- 'latitudeError'
      }

    } else if (hemisphere == 'S'){
      lat_idx <- which(names(dl) %in% c("LatS_.deg.",'LatS'))
      names(dl)[lat_idx] <- 'latitude'
      print('Lotek Template-Fit latitude: using movement data from the southern hemisphere. If that is incorrect, see the hemisphere input argument.')

      lat_err_idx <- which(names(dl) %in% c("LatErrS_.deg.",'LatErrS'))
      names(dl)[lat_err_idx] <- 'latitudeError'
      if (any(names(dl) %in% 'latitudeError')){
        measure.vars[length(measure.vars) + 1] <- 'latitudeError'
      }
    }
    measure.vars[length(measure.vars) + 1] <- 'latitude'
  } else{
    lat_idx <- which(names(dl) %in% c('Latitude[degs]',	'Latitude.degs.', 'Latitude(-3.44elevation)', 'Latitude..3.44elevation.'))
    names(dl)[lat_idx] <- 'latitude'
    if (any(names(dl) %in% 'latitude')){
      measure.vars[length(measure.vars) + 1] <- 'latitude'
    }
  }

  lon_idx <- which(names(dl) %in% c("LonN_.deg.", "LonS_.deg.",'LonN','LonS'))
  if (length(lon_idx) >= 1){
    if (hemisphere == 'N'){
      lon_idx <- which(names(dl) %in% c("LonN_.deg.",'LonN'))
      names(dl)[lon_idx] <- 'longitude'
      print('Lotek Template-Fit longitude: using movement data from the northern hemisphere. If that is incorrect, see the hemisphere input argument.')

      lon_err_idx <- which(names(dl) %in% c("LonErrN_.deg.",'LonErrN'))
      names(dl)[lon_err_idx] <- 'longitudeError'
      if (any(names(dl) %in% 'longitudeError')){
        measure.vars[length(measure.vars) + 1] <- 'longitudeError'
      }

    } else if (hemisphere == 'S'){
      lon_idx <- which(names(dl) %in% c("LonS_.deg.",'LonS'))
      names(dl)[lon_idx] <- 'longitude'
      print('Lotek Template-Fit longitude: using movement data from the southern hemisphere. If that is incorrect, see the hemisphere input argument.')

      lon_err_idx <- which(names(dl) %in% c("LonErrS_.deg.",'LonErrS'))
      names(dl)[lon_err_idx] <- 'longitudeError'
      if (any(names(dl) %in% 'longitudeError')){
        measure.vars[length(measure.vars) + 1] <- 'longitudeError'
      }
    }
    measure.vars[length(measure.vars) + 1] <- 'longitude'

  } else{
    lon_idx <- which(names(dl) %in% c('Longitude[degs]', 'Longitude.degs.', 'Longitude'))
    names(dl)[lon_idx] <- 'longitude'
    if (any(names(dl) %in% 'longitude')){
      measure.vars[length(measure.vars) + 1] <- 'longitude'
    }
  }
  
  if (length(grep('West', dl$longitude)) > 0 | length(grep('East', dl$longitude)) > 0){
    for (ii in 1:nrow(dl)){
      if (dl$longitude[ii] == ''){
        dl$longitude[ii] <- NA
      } else if (length(grep('West', dl$longitude)) > 0){
        dl$longitude[ii] <- as.numeric(substr(dl$longitude[ii], 1,
                                              stringr::str_locate_all(dl$longitude[ii], ' ')[[1]][1,1] - 1)) * -1
      } else if(length(grep('East', dl$longitude)) > 0){
        dl$longitude[ii] <- as.numeric(substr(dl$longitude[ii], 1,
                                              stringr::str_locate_all(dl$longitude[ii], ' ')[[1]][1,1] - 1))
      }
    }
    dl$longitude <- as.numeric(dl$longitude)
  }

  if (length(grep('North', dl$latitude)) > 0 | length(grep('South', dl$latitude)) > 0){
    for (ii in 1:nrow(dl)){
      if (dl$latitude[ii] == ''){
        dl$latitude[ii] <- NA
      } else{
        dl$latitude[ii] <- as.numeric(substr(dl$latitude[ii], 1,
                                              stringr::str_locate_all(dl$latitude[ii], ' ')[[1]][1,1] - 1))
      }
    }
    dl$latitude <- as.numeric(dl$latitude)
  }

  dep_idx <- which(names(dl) %in% c('MinPress[dBars]', 'MinPress.dBars.', 'MinDepth'))
  names(dl)[dep_idx] <- 'depthMin'; rm(dep_idx)
  if (any(names(dl) %in% 'depthMin')){
    dl$depthMin <- oce::swDepth(dl$depthMin, as.numeric(meta_row$geospatial_lat_start))
    measure.vars[length(measure.vars) + 1] <- 'depthMin'
  }

  dep_idx <- which(names(dl) %in% c('MaxPress[dBars]', 'MaxPress.dBars.', 'MaxDepth','MaxPressure_[dBar]','MaxPressure_.dBar.','MaxPress'))
  names(dl)[dep_idx] <- 'depthMax'
  if (any(names(dl) %in% 'depthMax')){
    dl$depthMax <- oce::swDepth(dl$depthMax, as.numeric(meta_row$geospatial_lat_start))
    measure.vars[length(measure.vars) + 1] <- 'depthMax'
  }

  if (any(names(dl) %in% 'sst')){
    dl$sst[which(dl$sst < -2 | dl$sst > 36)] <- NA
  }
  if (any(names(dl) %in% 'sstDepth')){
    dl$sstDepth[which(dl$sstDepth > 100)] <- NA
  }
  if (any(names(dl) %in% 'depthMax')){
    dl$depthMax[which(dl$depthMax > 3000)] <- NA
  }

  ## sunrise
  if (any(names(dl) %in% c('Sunrise', 'SunriseUTC')) & !ignore.sun){
    
    sr_idx <- which(names(dl) %in% c('Sunrise', 'SunriseUTC'))
    day_idx <- which(names(dl) %in% c('Date', 'MissionDate'))
    sr <- dl[,c(day_idx, sr_idx)]
    sr <- sr[which(sr[,1] != ''),]
    warning('depthSunrise being fixed at 0.')
    sr$depthSunrise <- 0

    if (any(names(sr) %in% c('Sunrise'))){
      if (is.numeric(sr$Sunrise)){ 

      	## convert numeric to time
        sr$DateTime <- testDates(sr[,1]) + as.numeric(sr$Sunrise * 60, units='secs')
      }
    } else{

      sr$DateTime <- testDates(paste(sr[,1], sr[,2]))
    }
    sr <- sr[,c('DateTime','depthSunrise')]
    sr <- sr[which(sr$DateTime >= dates[1] & sr$DateTime <= dates[2]),]

    ## reshape sr
    sr <- reshape2::melt(sr, id.vars=c('DateTime'), measure.vars = c('depthSunrise'))
    sr$VariableName <- sr$variable

    ## merge with observation types
    sr <- merge(x = sr, y = obsTypes[ , c("VariableID","VariableName", 'VariableUnits')], by = "VariableName", all.x=TRUE)
    sr <- sr[,c('DateTime','VariableID','value','VariableName','VariableUnits')]

    ## finish formatting/filtering after standardization
    names(sr) <- c('DateTime','VariableID','VariableValue','VariableName','VariableUnits')

  }

  ## sunset
  if (any(names(dl) %in% c('Sunset', 'SunsetUTC')) & !ignore.sun){

    ss_idx <- which(names(dl) %in% c('Sunset', 'SunsetUTC'))
    day_idx <- which(names(dl) %in% c('Date', 'MissionDate'))
    ss <- dl[,c(day_idx, ss_idx)]
    ss <- ss[which(ss[,1] != ''),]
    warning('depthSunset being fixed at 0.')
    ss$depthSunset <- 0

    if (any(names(ss) %in% c('Sunset'))){
      if (is.numeric(ss$Sunset)){ ## convert numeric to time
        ss$DateTime <- testDates(ss[,1]) + as.numeric(ss$Sunset * 60, units='secs')
      }
    } else{
      ss$DateTime <- testDates(paste(ss[,1], ss[,2]))
    }
    ss <- ss[,c('DateTime','depthSunset')]
    ss <- ss[which(ss$DateTime >= dates[1] & ss$DateTime <= dates[2]),]

    ## reshape ss
    ss <- reshape2::melt(ss, id.vars=c('DateTime'), measure.vars = c('depthSunset'))
    ss$VariableName <- ss$variable

    ## merge with observation types
    ss <- merge(x = ss, y = obsTypes[ , c("VariableID","VariableName", 'VariableUnits')], by = "VariableName", all.x=TRUE)
    ss <- ss[,c('DateTime','VariableID','value','VariableName','VariableUnits')]

    ## finish formatting/filtering after standardization
    names(ss) <- c('DateTime','VariableID','VariableValue','VariableName','VariableUnits')

  }
### --- End of Tim's edits --- ###

  dt_idx <- which(names(dl) %in% c('DateTime', 'Date/Time','Date.Time'))
  names(dl)[dt_idx] <- 'DateTime'
  if (length(dt_idx) == 1){ ## use combined datetime
    dl <- dl[which(dl$DateTime != '' & !is.na(dl$DateTime)),]
    dl$DateTime <- testDates(dl$DateTime)
  
  } else{ ## deal with separate date and time
    day_idx <- which(names(dl) %in% c('Date', 'MissionDate'))
    names(dl)[day_idx] <- 'Date'
    if (any(names(dl) %in% 'Date')){
      ## deal with dates
      dl <- dl[which(dl$Date != '' & !is.na(dl$Date)),]
    }

    time_idx <- which(names(dl) %in% c('Time'))
    names(dl)[time_idx] <- 'Time'
    if (any(names(dl) %in% 'Time')){
      dl$DateTime <- testDates(paste(dl$Date, dl$Time))
    } else{
      dl$DateTime <- testDates(paste(dl$Date, '00:00:00'))
    }
  }

  if (all(dl$DateTime < dates[1]) | all(dl$DateTime > dates[2])){
    stop('Error parsing time series dates.')
  }

  nms <- names(dl)
  warning('The following variables are NOT being included in the resulting eTUFF file:')
  warning(nms[which(!(nms %in% measure.vars))])

  ## filter (dates, bad data, etc)
  dl.new <- dl[which(dl$DateTime >= dates[1] & dl$DateTime <= dates[2]),]
  #dl.new <- dl.new %>% filter()

  ## reshape
  dl.new <- reshape2::melt(dl.new, id.vars=c('DateTime'), measure.vars = measure.vars)
  dl.new$VariableName <- dl.new$variable

  ## merge with observation types
  dl.new <- merge(x = dl.new, y = obsTypes[ , c("VariableID","VariableName", 'VariableUnits')], by = "VariableName", all.x=TRUE)
  dl.new <- dl.new[,c('DateTime','VariableID','value','VariableName','VariableUnits')]

  ## finish formatting/filtering after standardization
  names(dl.new) <- c('DateTime','VariableID','VariableValue','VariableName','VariableUnits')

  ## rbind
  if (exists('ss')) dl.new <- rbind(dl.new, ss)
  if (exists('sr')) dl.new <- rbind(dl.new, sr)

  dl.new <- dl.new[order(dl.new$DateTime, dl.new$VariableID),]
  dl.new$DateTime <- as.POSIXct(dl.new$DateTime, tz='UTC')
  dl.new$DateTime <- format(dl.new$DateTime, '%Y-%m-%d %H:%M:%S') # yyyy-mm-dd hh:mm:ss
  dl.new <- dl.new[which(!is.na(dl.new$VariableValue)),]
  dl.new <- dl.new[which(dl.new$VariableValue != ' '),]
  dl.new <- dl.new %>% distinct(DateTime, VariableID, VariableValue, VariableName, VariableUnits) %>% as.data.frame()

  return(dl.new)
}

