#' Determine date format of vector
#' 
#' \code{findDateFormat} determines the date format of a given vector of dates
#' 
#' @param dateVec a character vector representing dates
#' @return dateformat is character string used as input to strptime(format = dateformat)
#' @export
#' 
#' @examples
#' dte <- '2015-01-01 05:30:17'
#' findDateFormat(dte)
#' dte.POSIX <- as.POSIXct(dte, format = findDateFormat(dte))
#' dte.POSIX
#'

findDateFormat <- function(dateVec){

  dateformat = '%Y-%m-%d %H:%M:%S'
  ddates = as.POSIXct(strptime(as.character(dateVec), format = dateformat)) #reads dates as dates

  if (is.na(ddates[1])){
    dateformat = '%H:%M:%S %d-%b-%Y'
    ddates = as.POSIXct(strptime(as.character(dateVec), format = dateformat)) #reads dates as dates
  
    if (is.na(ddates[1])){
      dateformat = '%m-%d-%y %H:%M'
      ddates = as.POSIXct(strptime(as.character(dateVec), format = dateformat)) #reads dates as dates
      
	  if (is.na(ddates[1])){
		  dateformat = '%m/%d/%Y %I:%M:%S' ### Tim's edits: format for "08/08/2011 00:00:00"
		  ddates = as.POSIXct(strptime(as.character(dateVec), format = dateformat)) #reads dates as dates  
	  
       if (is.na(ddates[1])){
        dateformat = '%m/%d/%y %H:%M'
        ddates = as.POSIXct(strptime(as.character(dateVec), format = dateformat)) #reads dates as dates        
		
        if (is.na(ddates[1])){
          dateformat = '%m/%d/%Y'
          ddates = as.POSIXct(strptime(as.character(dateVec), format = dateformat)) #reads dates as dates
          
          if (is.na(ddates[1])){
            dateformat = '%H:%M:%S %d-%b-%Y'
            ddates = as.POSIXct(strptime(as.character(dateVec), format = dateformat)) #reads dates as dates
            
            if (is.na(ddates[1])){
              dateformat = '%H:%M:%OS %d-%b-%Y'
              ddates = as.POSIXct(strptime(as.character(dateVec), format = dateformat)) #reads dates as dates
              
              if (is.na(ddates[1])){
                dateformat = '%d-%b-%Y %H:%M:%S'
                ddates = as.POSIXct(strptime(as.character(dateVec), format = dateformat)) #reads dates as dates
                
                if (is.na(ddates[1])){
                  dateformat = '%d-%b-%Y'
                  ddates = as.POSIXct(strptime(as.character(dateVec), format = dateformat)) #reads dates as dates
                  
                  if (is.na(ddates[1])){
                    dateformat = '%d-%b-%y'
                    ddates = as.POSIXct(strptime(as.character(dateVec), format = dateformat)) #reads dates as dates					
						
						  if (is.na(ddates[1])){
							dateformat = '%H:%M %d-%b-%Y' ### Tim's edits: format for "10:00 29-May-2011"
							ddates = as.POSIXct(strptime(as.character(dateVec), format = dateformat)) #reads dates as dates			
							
              if(is.na(ddates[1])){
                stop('No correct date format was found.')
              }
							} else {}   			  
						} else {}                    
                    } else {}
                  } else {}
                } else {}
              } else {}
            } else {}
          } else {}       
      } else {}
    } else {}
  } else {}
  
  dateformat #return dateformat variable

}
