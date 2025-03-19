meta.prep <- function(meta){
	## Camrin needs a uid_no (unique no.) field
    meta$uid_no <- meta$instrument_name
    ### Extra spaces tend to appear in random places, like manufacturer
    j = ncol(meta)
    for (i in 1:j){
    	meta[,i] <- trimws(meta[,i])
    }
    ## Change to appropriate datetime format
    meta$time_coverage_start <- as.POSIXct(meta$time_coverage_start, format = "%Y-%m-%d %H:%M:%S", tz="GMT")
    meta$time_coverage_end <- as.POSIXct(meta$time_coverage_end, format = "%Y-%m-%d %H:%M:%S", tz="GMT")
    ### All done
    return(meta)
}

check.meta <- function(mydat){
	tcover = mydat$time_coverage_start 
	## Catch if datetime is missing due to incorrect format
    if (is.na(tcover)){
    	cat("--------------------------------------------------------\n\n")
    	cat("Here are the metadata you have provided...\n\n")
    	cat("--------------------------------------------------------\n")
    	print(mydat)
    	stop("WRONG input detected!!! Please make sure 'time_coverage_start' date format is in YYYY-mm-dd HH:mm:ss in the source metadata file")}
    ## Do it once more
    tcover = mydat$time_coverage_end
    if (is.na(tcover)){
    cat("--------------------------------------------------------\n\n")
    cat("Here are the metadata you have provided...\n\n")
    cat("--------------------------------------------------------\n")
    print(mydat)
    stop("WRONG input detected!!! Please make sure 'time_coverage_end' date format is in YYYY-mm-dd HH:mm:ss in the source metadata file")}
	cat("--------------------------------------------------------\n")
    cat("Metadata for this tag, please check carefully...\n")
    cat("--------------------------------------------------------\n")
	txt <- build_meta_head(meta_row = mydat, metaTypes = mtypes)
	i = length(txt)
	txt = txt[1:(i-2)]
	print(txt)
}
