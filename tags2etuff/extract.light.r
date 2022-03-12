#' Extract lgiht from Wildlife Computers tag data
#'
#' \code{extract.light} is a simple formatting function that parses LL data and
#' makes it usable to subsequent functions
#'
#' @param lightloc data frame read from -LightLoc.csv output of Wildlife Computers DAP
#'   processor or Tag Portal.
#'
#' @return data frame formatted for LL data
#'

extract.light <- function(light){

  # convert to long format
  vars = names(light[,c(which(names(light) == 'LL0'):length(names(light)))])
  light <- light[which(light$Type %in% c('Dawn','Dusk')),]
  light <- light[which(light$Day != ''),]
  #light <- which(duplicated(paste(light$Day, light$Time)))
  light <- stats::reshape(light, ids = paste(light$Day, light$Time), direction = 'long',
                 varying = vars, times = vars, sep='', timevar = 'BinNum')
  keepNames = c('Ptt', 'id', 'BinNum', 'LL', 'Depth', 'Delta', 'MinDepth','MaxDepth')
  light <- light[,c(keepNames)]
  row.names(light) <- NULL

  # date conversion then sort
  light$Date <- as.POSIXct(light$id, format = findDateFormat(light$id), tz='UTC')
  light <- light[order(light$Date, light$Depth),]
  #light <- light[which(!is.na(light$Depth)),]
  light <- light[!is.na(light$LL),]
  #light <- light[-which(light$Type %in% c('Begin','End')),]
  light <- subset(light, select=-c(id))

  # adds incremental secs to timestamp to reflect the duration during which LL's were taken (see WC lightloc "Delta" column)
  light.df <- light %>% group_by(Date) %>% dplyr::summarise(delta_df = unique(Delta))
  for (i in 1:nrow(light.df)){
    idx <- which(light$Date %in% light.df$Date[i])
    for (bb in 1:length(idx)){
      light$Date[idx[bb]] <- light$Date[idx[bb]] + light.df$delta_df[i] / (length(idx) - 1) * (bb - 1)
    }
  }

  # write out / return
  light
}
