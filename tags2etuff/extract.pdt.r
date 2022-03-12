#' Extract PDT from Wildlife Computers tag data
#' 
#' \code{extract.pdt} is a simple formatting function that parses PDT data and
#' makes it usable to subsequent functions
#' 
#' @param pdt data frame read from -PDTs.csv output of Wildlife Computers DAP 
#'   processor or Tag Portal.
#'   
#' @return data frame formatted for pdt data
#'   

extract.pdt <- function(pdt){
  # eliminate any oxygen data
  if(any(grep('X.Ox', colnames(pdt)))){
    dropidx <- c(grep('Ox', names(pdt)), grep('Disc', names(pdt)))
    pdt <- pdt[,-dropidx]
  }
  
  if(any(pdt[,2] != pdt[1,2])){
    stop('Formatting error in input data. Open csv file elsewhere and try adding header names after the "Discont15" column name. There is likely more data stored here that was not assigned a column header.')
  }
  
  # convert to long format
  vars = names(pdt[,c(which(names(pdt) == 'Depth1'):length(names(pdt)))])
  pdt <- stats::reshape(pdt, ids = pdt$Date, direction = 'long',
                 varying = vars, times = vars, sep='', timevar = 'BinNum')
  keepNames = c('Ptt', 'Date', 'NumBins', 'BinNum', 'Depth', 'MinTemp', 'MaxTemp')
  pdt <- pdt[,c(keepNames)]
  row.names(pdt) <- NULL
  # date conversion then sort
  pdt$Date <- as.POSIXct(pdt$Date, format = findDateFormat(pdt$Date))
  pdt <- pdt[order(pdt$Date, pdt$Depth),]               
  #pdt <- pdt[which(!is.na(pdt$Depth)),]
  pdt <- pdt[!is.na(pdt$Depth),]
  udates <- unique(format(pdt$Date, '%Y-%m-%d'))
  dates.tr <- format(pdt$Date, '%Y-%m-%d')
  dateidx <- match(dates.tr, udates)
  for(i in 1:max(dateidx)){
    pdt.i <- pdt[which(dateidx == i),]
    pdt.i$Depth[which(pdt.i$Depth < 0)] <- 0
    pdt.i <- pdt.i[which(!duplicated(pdt.i$Depth)),]
    if(length(unique(pdt.i[,5])) <= 2){ 
    
      pdt.t <- pdt.i
      pdt.t[,2] <- paste(format(pdt.t$Date, '%Y-%m-%d'),' 00:00:00', sep = '')
      
      } else{
        if(length(which(pdt.i$BinNum == 1)) > 1){
          pdt.i <- pdt.i[order(pdt.i$Depth),]
          pdt.i$Depth[which(pdt.i$Depth < 0)] <- 0
          z <- unique(pdt.i$Depth)#; z <- sort(z)
          pdt.t <- pdt.i[1:length(z),]
          
          for(ii in 1:length(z)){
            
            minT <- min(pdt.i[which(pdt.i$Depth == z[ii]),6])
            maxT <- max(pdt.i[which(pdt.i$Depth == z[ii]),7])
            pdt.t[ii,c(5:7)] <- c(z[ii],minT,maxT)
            
          }
          
          pdt.t[,4] <- seq(1, length(z), by = 1)
          pdt.t[,3] <- length(z)
          pdt.t[,2] <- paste(format(pdt.t$Date, '%Y-%m-%d'),' 00:00:00', sep = '')
          
        } else{
          pdt.t <- pdt.i
          pdt.t[,2] <- paste(format(pdt.t$Date, '%Y-%m-%d'),' 00:00:00', sep = '')
          
        }
      
      }
    
    if(i == 1){
      pdtNew <- pdt.t
    } else{
      pdtNew <- rbind(pdtNew, pdt.t)
    }
    
  }
  # write out / return
  return(pdtNew)
}
