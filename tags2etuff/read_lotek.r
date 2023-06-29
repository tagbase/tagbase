### --- Begin Tim's edit history  --- ###
### 2023-06-15
### a) Return nothing when only customCols is used to provide a track
### b) Improve search for log files based on keywords "dive" and "day"
### --- End of Tim's edit history --- ###

#' Read Lotek archival tag data
#'
#' Smart way to read lotek archival tag data.
#'
#' @param dir is directory the target files are stored in
#' @export

read_lotek <- function(dir){

  ## list files in directory
  fList <- list.files(dir, full.names = TRUE, recursive = TRUE)

  check_switch <- FALSE

 ##=======================
 ### Read time series, ts
 ##=======================
 print('Reading time series...')
 print('Lotek time series files need _00.csv, Basic Log.csv or Dive Log.csv in the filename.')
 ### --- Tim's edits 2023-06-15: new search conditions
 fs1 = grep('_00.csv', fList)
 fs2 = grep('Basic', fList, ignore.case = T)
 fs3 = grep('Dive', fList, ignore.case = T)
 ### If any of the above returns more than 1 result
 fs0 = length(fs1) + length(fs2) + length(fs3)
 if (fs0 > 1) {
 	stop('More than 1 file was found in the input directory that matched Lotek time series .csv file. Only one log file matching that extension is allowed.')
 }
 ### Find out the filename used
 findfile = c(length(fs1) == 1, length(fs2) == 1, length(fs3) == 1)
 findfile = which(findfile == TRUE)            
 if (identical(findfile, integer(0))) findfile = 0
 
 ### Use findfile value to get through the ingestion
 if (findfile > 0){
 ### Read in the file
   if(findfile == 1) series_file <- fList[fs1]
   if(findfile == 2) series_file <- fList[fs2]
   if(findfile == 3) series_file <- fList[fs3]
   ts <- data.table::fread(series_file, sep = ',', header = T) 
   print(head(ts)); print(tail(ts))
   
   ### For Dive Log only
   if(findfile ==3){
      ## read header separate in case there are non-UTF chars
      x <- scan(series_file, what = character(), sep=',', nmax = 100)
      Encoding(x) <- "UTF-8"
      x <- iconv(x, "UTF-8", "UTF-8",sub='')
      hdr <- x[1:4]
      if (length(hdr) != ncol(ts)) hdr <- c(hdr, 'unknown')
      hdr <- gsub(" ", "", hdr, fixed = TRUE)
      names(ts) <- hdr
   } 
    ## check for ts and dl logs being backwards from expected
    check_switch <- TRUE
    
   } else if (length(grep('timeseries', fList, ignore.case = T)) == 1){
    series_file <- fList[grep('timeseries', fList, ignore.case = T)]
    ts <- data.table::fread(series_file, sep = ',', header = T)

   } else if (length(grep('timeseries', fList, ignore.case = T)) > 1){
    stop('More than 1 file was found in the input directory that matched "timeseries". Only one log filename matching that text string is allowed.')
 } else {
	### --- Tim's edits 2023-06-15: Return nothing when only customCols is used to provide a track
 	ts = NULL
 	print('No time series file was found.')
	### --- End of Tim's edit history --- ###    
 }

  #=======================
  ## Read daily log, dl 
  #=======================
  print('Reading daily log...')
  print('Lotek daily files need _01.csv or Day Log.csv in the filename.')

 ### --- Tim's edits 2023-06-15: new search conditions
 fs1 = grep('_01.csv', fList)
 fs2 = grep('Day', fList, ignore.case = T)
 ### If any of the above returns more than 1 result
 fs0 = length(fs1) + length(fs2)
 if (fs0 > 1) {
 	stop('More than 1 file was found in the input directory that matched Lotek day log .csv file. Only one log file matching that extension is allowed.')
 }
 ### Find out the filename used
 findfile = c(length(fs1) == 1, length(fs2) == 1)
 findfile = which(findfile == TRUE)            
 if (identical(findfile, integer(0))) findfile = 0
 
 ### Use findfile value to get through the ingestion
 if (findfile > 0){
 ### Read in the file
   if(findfile == 1) daylog_file <- fList[fs1]
   if(findfile == 2) daylog_file <- fList[fs2]
   dl <- data.table::fread(daylog_file, sep = ',', skip = 1)#, header = F, nrows = 10, blank.lines.skip = F, stringsAsFactors = F)

    ## read header separate in case there are non-UTF chars
    x <- scan(daylog_file, what = character(), sep=',', nmax = 100)
    Encoding(x) <- "UTF-8"
    x <- iconv(x, "UTF-8", "UTF-8",sub='')

    ## get start char
    if (length(grep('Rec #', x, ignore.case = T)) != 0){
      start <- grep('Rec #', x, ignore.case = T)
    } else if (length(grep('Mission Date', x, ignore.case = T)) != 0){
      start <- grep('Mission Date', x, ignore.case = T)
    } else{
      start <- 1
    }

    ## get end char
    if (length(grep('C_TooDimFlag', x, ignore.case = T)) > 0){
      end <- grep('C_TooDimFlag', x, ignore.case = T)
    } else if (length(grep('T S Pointer', x, ignore.case = T)) > 0){
      end <- grep('T S Pointer', x, ignore.case = T)
    } else if (length(grep('Valid Flag', x, ignore.case = T)) > 0){
      end <- grep('Valid Flag', x, ignore.case = T)
    } else {
      end <- ncol(dl) + start - 1
    }

    hdr <- x[start:end]
    if (length(hdr) != ncol(dl)) hdr <- c(hdr, 'unknown')
    hdr <- gsub(" ", "", hdr, fixed = TRUE)

    names(dl) <- hdr

    ### check for ts and dl logs being backwards from expected
    check_switch <- TRUE

  } else if (length(grep('daylog', fList, ignore.case = T)) == 1){
    daylog_file <- fList[grep('daylog', fList, ignore.case = T)]

    ## read without header then add it
    dl <- data.table::fread(daylog_file, sep = ',')#, header = F, nrows = 10, blank.lines.skip = F, stringsAsFactors = F)

    ## read header separate in case there are non-UTF chars
    x <- scan(daylog_file, what = character(), sep=',', nmax = 100)
    Encoding(x) <- "UTF-8"
    x <- iconv(x, "UTF-8", "UTF-8",sub='')

    ## get start char
    if (length(grep('Rec #', x, ignore.case = T)) != 0){
      start <- grep('Rec #', x, ignore.case = T)
    } else if (length(grep('Mission Date', x, ignore.case = T)) != 0){
      start <- grep('Mission Date', x, ignore.case = T)
    }

    ## get end char
    if (length(grep('C_TooDimFlag', x, ignore.case = T)) > 0){
      end <- grep('C_TooDimFlag', x, ignore.case = T)
    } else if (length(grep('T S Pointer', x, ignore.case = T)) > 0){
      end <- grep('T S Pointer', x, ignore.case = T)
    } else {
      end <- ncol(dl) + start - 1
    }

    hdr <- x[start:end]
    if (length(hdr) != ncol(dl)) hdr <- c(hdr, 'unknown')
    hdr <- gsub(" ", "", hdr, fixed = TRUE)

    names(dl) <- hdr

  } else if (length(grep('daylog', fList, ignore.case = T)) > 1){
    stop('More than 1 file was found in the input directory that matched "daylog". Only one log filename matching that text string is allowed.')
  } else{
 	dl = NULL
 	print('No daylog file was found.')
  }	

	### --- Tim's edits 2023-06-15: commented out file checking
   check_switch = FALSE
	### --- End of Tim's edit history --- ###
  
  ## are the 00 and 01 logs opposite from what we expect?
  if (check_switch &
      any(c('Longitude [degs]', 'Longitude[degs]') %in% names(ts)) &
      any(c('ExtTemp [C]', 'ExtTemp[C]', 'Ext temp deg C', 'ExttempdegC') %in% names(dl))){ ## then ts and dl are likely backwards

    warning('Time series and daily log appear to be specified opposite of what we expect. Switching the input files to (hopefully) appropriately specify these file types.')
    dl_old <- dl
    dl <- ts
    ts <- dl_old
  }

  ### --- Tim's edits 2023-06-15: allow the return of NULL objects
  ## remove all the weird spacing from col names
  if (!is.null(ts)) names(ts) <- gsub(" ", "", names(ts), fixed = TRUE)
  if (!is.null(dl)) names(dl) <- gsub(" ", "", names(dl), fixed = TRUE)

  ## are there more than logs 00 and 01?
  if (length(grep('_02.csv', fList)) > 0) warning('More than logs _00.csv and _01.csv were detected. More than 2 logs is not currently supported, thus additional logs are ignored.')

  out <- list(daylog = NULL, timeseries = NULL)
  if (!is.null(ts)) out$timeseries = data.frame(ts)
  if (!is.null(dl)) out$daylog = data.frame(dl)
  ### --- End of Tim's edit history --- ###  
  return(out)
  
}
