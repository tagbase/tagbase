#' Prepare SST data from mixed sources for eTUFF standardization
#'
#' Prepare SST data from mixed sources for eTUFF standardization. This is nearly always useful for dealing with Wildlife Computers tag datasets when SSTs can be derived from multiple "sources".
#'
#' @param sst is data frame of data from Wildlife Computers -SST.csv
#' @param obsTypes is data frame of observation types read from Github
#' @return a "master" sst dataset compiled across potential sources
#' @export

parse_sst <- function(sst, obsTypes){

  ## for WC mP's: if SST source = MixLayer then the value is an SST summary (mean?) integrated over the summary period
  ##              if SST source = TimeSeries then its discrete SST measurement with timestamp however depth may not be full resolution depending on how it was encoded in the source
  ##              if SST source = LightLoc then discrete SST measurements and depth at full resolution
  ##              if SST source = Status then it used a discrete status message temperature. But the timestamp in the SST file will be rounded to the nearest summary period.

  ### --- Tim's edits: DepthSensor filtering causing problems --- ###
  ncheck <- grepl("DepthSensor", paste(names(sst),collapse=" "), fixed=T)
  if (ncheck) sst <- subset(sst, select=-c(DepthSensor))
 ### --- End of Tim's edits --- ###
 
  # organize sst for flatfile format
  # sst <- subset(sst, select=-c(DepthSensor))
  ml <- sst[which(sst$Source == 'MixLayer'),]
  tseries <- sst[which(sst$Source == 'TimeSeries'),]
  ll <- sst[which(sst$Source == 'LightLoc'),]
  st <- sst[which(sst$Source == 'Status'),]

  if (nrow(ll) > 0){
    nms <- names(ll)
    nms[grep('Temperature', nms)] <- 'sst'
    nms[grep('Depth', nms)] <- 'sstDepth'
    names(ll) <- nms

    # summarize with melt
    ll <- reshape2::melt(ll, id.vars=c('dt'), measure.vars = c('sst','sstDepth'))
    ll$VariableName <- ll$variable

    # merge with obs types and do some formatting
    ll <- merge(x = ll, y = obsTypes[ , c("VariableID","VariableName", 'VariableUnits')], by = "VariableName", all.x=TRUE)
    ll <- ll[,c('dt','VariableID','value','VariableName','VariableUnits')]
    names(ll) <- c('DateTime','VariableID','VariableValue','VariableName','VariableUnits')

    if (exists('all.sst')){
      all.sst <- rbind(all.sst, ll)
    } else{
      all.sst <- ll
    }
  }

  if (nrow(ml) > 0){

    ml$summaryPeriod <- Mode(difftime(ml$dt[2:nrow(ml)], ml$dt[1:(nrow(ml) - 1)], units='hours'))
    nms <- names(ml)
    #nms[grep('summ', nms)] <- 'summaryPeriod'
    nms[grep('Temperature', nms)] <- 'sstMean'
    names(ml) <- nms

    # summarize with melt
    ml <- reshape2::melt(ml, id.vars=c('dt'), measure.vars = c('sstMean','summaryPeriod'))
    ml$VariableName <- ml$variable

    # merge with obs types and do some formatting
    ml <- merge(x = ml, y = obsTypes[ , c("VariableID","VariableName", 'VariableUnits')], by = "VariableName", aml.x=TRUE)
    ml <- ml[,c('dt','VariableID','value','VariableName','VariableUnits')]
    names(ml) <- c('DateTime','VariableID','VariableValue','VariableName','VariableUnits')

    if (exists('all.sst')){
      all.sst <- rbind(all.sst, ml)
    } else{
      all.sst <- ml
    }
  }

  if (nrow(tseries) > 0){
    nms <- names(tseries)
    nms[grep('Temperature', nms)] <- 'sst'
    nms[grep('Depth', nms)] <- 'sstDepth'
    names(tseries) <- nms

    # summarize with melt
    tseries <- reshape2::melt(tseries, id.vars=c('dt'), measure.vars = c('sst','sstDepth'))
    tseries$VariableName <- tseries$variable

    # merge with obs types and do some formatting
    tseries <- merge(x = tseries, y = obsTypes[ , c("VariableID","VariableName", 'VariableUnits')], by = "VariableName", atseries.x=TRUE)
    tseries <- tseries[,c('dt','VariableID','value','VariableName','VariableUnits')]
    names(tseries) <- c('DateTime','VariableID','VariableValue','VariableName','VariableUnits')

    if (exists('all.sst')){
      all.sst <- rbind(all.sst, tseries)
    } else{
      all.sst <- tseries
    }

  }

  if (nrow(st) > 0){
    # we have to throw out status sst due to discrete measurement and a summarized (rounded) timestamp
    warning('SST values sourced from Status data are being discarded due to a discrete measurement with a summarized timestamp.')
  }

  all.sst <- all.sst[order(all.sst$DateTime, all.sst$VariableID),]
  all.sst$DateTime <- as.POSIXct(all.sst$DateTime, tz='UTC')
  all.sst$DateTime <- format(all.sst$DateTime, '%Y-%m-%d %H:%M:%S') # yyyy-mm-dd hh:mm:ss

  all.sst

}
