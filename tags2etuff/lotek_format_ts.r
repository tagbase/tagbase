#' Format Lotek time series
#'
#' Format Lotek time series data from archival tag
#'
#' @param ts is data frame of Lotek's time series file output from \code{read_lotek}
#' @param dates is POSIXct vector (length 2) of release and recovery dates
#' @param obsTypes is csv sourced from github containing the latest obsTypes
#'   recognized by the NASA OIIP project. Usually this is left NULL and the file
#'   is automatically downloaded for you. The only reason you may want to
#'   specify this would be in order to work offline.
#' @param meta_row is data frame with nrow == 1 containing metadata
#' @export

lotek_format_ts <- function(ts, dates, obsTypes, meta_row){

  measure.vars <- c()

  ## rename to standard names
  ext_idx <- which(names(ts) %in% c('ExtTemp[C]', 'ExtTempdegC', 'ExtTemp.C.','External_Temp_.C.'))
  names(ts)[ext_idx] <- 'temperature'
  if (any(names(ts) %in% 'temperature')){
    measure.vars[length(measure.vars) + 1] <- 'temperature'
  }

  int_idx <- which(names(ts) %in% c('IntTemp[C]', 'IntTempdegC', 'IntTemp.C.'))
  names(ts)[int_idx] <- 'internalTemperature'
  if (any(names(ts) %in% 'internalTemperature')){
    measure.vars[length(measure.vars) + 1] <- 'internalTemperature'
  }

  dep_idx <- which(names(ts) %in% c('Depth-dBar', 'Depth.dBar', 'Pressure[dBars]', 'Pressure.dBars.','Pressure_.dBar.'))
  names(ts)[dep_idx] <- 'depth'
  if (any(names(ts) %in% 'depth')){
    ts$depth <- oce::swDepth(ts$depth, as.numeric(meta_row$geospatial_lat_start))
    measure.vars[length(measure.vars) + 1] <- 'depth'
  }

  light_idx <- which(names(ts) %in% c('LightatDepth', 'LightIntensity'))
  names(ts)[light_idx] <- 'light'
  if (any(names(ts) %in% 'light')){
    measure.vars[length(measure.vars) + 1] <- 'light'
  }

  ## deal with dates
  dt_idx <- which(names(ts) %in% c('Date/Time', 'Timestamp','Date.Time'))
  if ('Date' %in% names(ts) & 'Time' %in% names(ts)){
    ts <- ts[which(ts$Date != '' & !is.na(ts$Date)),]
    ts$DateTime <- testDates(paste(ts$Date, ts$Time))
  } else if ('Time(UTC)' %in% names(ts) | 'Time.UTC.' %in% names(ts)){
    time_idx <- which('Time(UTC)' %in% names(ts) | 'Time.UTC.' %in% names(ts))
    ts <- ts[which(ts[,time_idx] != '' & !is.na(ts[,time_idx])),]
    ts$DateTime <- testDates(ts[,time_idx])
  } else if (length(dt_idx) == 1){
    names(ts)[dt_idx] <- 'DateTime'
    ts <- ts[which(ts$DateTime != '' & !is.na(ts$DateTime)),]
    ts$DateTime <- testDates(ts$DateTime)
  }

  if (all(ts$DateTime < dates[1]) | all(ts$DateTime > dates[2])){
    stop('Error parsing time series dates.')
  }

  ## filter (dates, bad data, etc)
  ts.new <- ts[which(ts$DateTime >= dates[1] & ts$DateTime <= dates[2]),]

  ## reshape
  ts.new <- reshape2::melt(ts.new, id.vars=c('DateTime'), measure.vars = measure.vars)
  ts.new$VariableName <- ts.new$variable

  ## merge with observation types
  ts.new <- merge(x = ts.new, y = obsTypes[ , c("VariableID","VariableName", 'VariableUnits')], by = "VariableName", all.x=TRUE)
  ts.new <- ts.new[,c('DateTime','VariableID','value','VariableName','VariableUnits')]

  ## finish formatting/filtering after standardization
  names(ts.new) <- c('DateTime','VariableID','VariableValue','VariableName','VariableUnits')
  ts.new <- ts.new[order(ts.new$DateTime, ts.new$VariableID),]
  ts.new$DateTime <- as.POSIXct(ts.new$DateTime, tz='UTC')
  ts.new$DateTime <- format(ts.new$DateTime, '%Y-%m-%d %H:%M:%S') # yyyy-mm-dd hh:mm:ss
  ts.new <- ts.new[which(!is.na(ts.new$VariableValue)),]
  ts.new <- ts.new[which(ts.new$VariableValue != ' '),]
  ts.new <- ts.new %>% distinct(DateTime, VariableID, VariableValue, VariableName,VariableUnits) %>% as.data.frame()

  return(ts.new)
}
