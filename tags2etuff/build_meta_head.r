#' Build eTUFF metadata header
#'
#' Takes typical row of metadata spreadsheet and creates standardized eTUFF
#' header for use in Tagbase.
#'
#' @param meta_row is a row of meta spreadsheet for the deployment of interest
#' @param filename is output filename for this eTUFF file. Needs to be .txt.
#' @param write_hdr is logical indicating whether or not to actually write the
#'   header to the file specified by filename. If FALSE, the constructed header
#'   is returned.
#' @param global_attributes is character vector of additional global attributes
#'   to be associated with this eTUFF file. See the example for required
#'   formatting of vector elements.
#' @param metaTypes is csv sourced from github containing the latest metaTypes
#'   recognized by the NASA OIIP project. Usually this is left NULL and the file
#'   is auto-magically downloaded for you. The only reason you may want to
#'   specify this would be in order to work offline.
#'
#' @return nothing to console. header is written to disk.
#' @export
#' @examples
#' \dontrun{
#' # build_meta_head uses input tag metadata to build a header similar to:
#' cat("header1\nheader2\n", file="filename.csv")
#' cat("header3\n", file="filename.csv", append=TRUE)
#' DF <- data.frame(a=1:2, b=c("a","B"))
#' write.table(DF, file="filename.csv", append=TRUE)
#' > header1
#' header2
#' header3
#' "a" "b"
#' "1" 1 "a"
#' "2" 2 "B"
#'
#' g_atts <- c('institution = "WHOI"', 'references = "doi: xxxx"')
#' build_meta_head(meta_row = meta[1,], filename = 'eTUFF_example.txt', global_attributes = g_atts)
#' }
#' @importFrom utils read.csv
#' @importFrom utils write.table

### --- Begin Tim's edit history  --- ###
### 2023-09-22
### Include new categories
### --- End of Tim's edit history --- ###


build_meta_head <- function(meta_row, filename, write_hdr = FALSE, metaTypes = NULL, global_attributes = NULL){

  # if metatypes null, get it
  if (is.null(metaTypes)){
    metaTypes <- utils::read.csv(url("https://raw.githubusercontent.com/camrinbraun/tagbase/master/eTagMetadataInventory.csv"))
    metaTypes$Necessity[which(metaTypes$AttributeID %in% c(3,8,100,101,200,302,400:404))] <- 'recommended'
  }

  # melt cols to rows
  for (i in 1:ncol(meta_row)) meta_row[,i] <- as.character(meta_row[,i]) # need to be as.character to preserve dates
  meta.new <- reshape2::melt(meta_row, id.vars=c('uid_no'))

  # filter out NA and other missing values
  meta.new <- meta.new[which(!is.na(meta.new$value)),]
  meta.new <- meta.new[which(meta.new$value != ''),]

  # merge with possible meta types
  meta.new <- merge(x = meta.new, y = metaTypes[ , c("Category","AttributeID", 'AttributeName')],
                    by.x = 'variable', by.y = "AttributeName", all.x=TRUE)

  # are we missing any essential vars?
  if (any(!(metaTypes$AttributeID[which(metaTypes$Necessity == 'required')] %in% meta.new$AttributeID))){
    idx <- which(metaTypes$Necessity == 'required')
    idx <- idx[!(metaTypes$AttributeID[idx] %in% meta.new$AttributeID)]
    missingVars <- metaTypes[idx, c(1:3)]
    e <- simpleError('missing required metadata attributes. The missing attributes have been printed to the console. To store as variable you can run foo <- build_meta_head().')
    print(missingVars)
    stop(print(e))
    #tryCatch(stop(e), finally = return(missingVars))
  }

  meta.new <- meta.new[,c('Category','AttributeID','variable','value')]
  names(meta.new) <- c('Category','AttributeID','AttributeName','AttributeValue')
  meta.new <- meta.new[which(!is.na(meta.new$Category)),]

  # format to etuff header

  ## add global atts, if any
  hdr <- paste('// global attributes:',sep='')
  if(!is.null(global_attributes)){
    for (ii in 1:length(global_attributes)){
    hdr[(length(hdr)+1)] <- paste('  :', global_attributes[ii], sep='')
    }
  }

  idx <- which(meta.new$Category == 'instrument')
  if (length(idx) > 0){
    hdr[(length(hdr)+1)] <- paste('// etag device attributes:', sep='')
    for (ii in idx){
      hdr[(length(hdr)+1)] <- paste('  :', meta.new$AttributeName[ii], ' = ', '\"', meta.new$AttributeValue[ii], '\"', sep='')
    }
  }

  idx <- which(meta.new$Category == 'attachment')
  if (length(idx) > 0){
    hdr[(length(hdr)+1)] <- paste('// etag attachment attributes:', sep='')
    for (ii in idx){
      hdr[(length(hdr)+1)] <- paste('  :', meta.new$AttributeName[ii], ' = ', '\"', meta.new$AttributeValue[ii], '\"', sep='')
    }
  }

  idx <- which(meta.new$Category == 'deployment')
  if (length(idx) > 0){
    hdr[(length(hdr)+1)] <- paste('// etag deployment attributes:', sep='')
    for (ii in idx){
      hdr[(length(hdr)+1)] <- paste('  :', meta.new$AttributeName[ii], ' = ', '\"', meta.new$AttributeValue[ii], '\"', sep='')
    }
  }

  idx <- which(meta.new$Category == 'end_of_mission')
  if (length(idx) > 0){
    hdr[(length(hdr)+1)] <- paste('// etag end of mission attributes:', sep='')
    for (ii in idx){
      hdr[(length(hdr)+1)] <- paste('  :', meta.new$AttributeName[ii], ' = ', '\"', meta.new$AttributeValue[ii], '\"', sep='')
    }
  }

  idx <- which(meta.new$Category == 'animal')
  if (length(idx) > 0){
    hdr[(length(hdr)+1)] <- paste('// etag animal attributes:', sep='')
    for (ii in idx){
      hdr[(length(hdr)+1)] <- paste('  :', meta.new$AttributeName[ii], ' = ', '\"', meta.new$AttributeValue[ii], '\"', sep='')
    }
  }

  idx <- which(meta.new$Category == 'waypoints')
  if (length(idx) > 0){
    hdr[(length(hdr)+1)] <- paste('// etag waypoints attributes:', sep='')
    for (ii in idx){
      hdr[(length(hdr)+1)] <- paste('  :', meta.new$AttributeName[ii], ' = ', '\"', meta.new$AttributeValue[ii], '\"', sep='')
    }
  }

  idx <- which(meta.new$Category == 'quality')
  if (length(idx) > 0){
    hdr[(length(hdr)+1)] <- paste('// etag quality attributes:', sep='')
    for (ii in idx){
      hdr[(length(hdr)+1)] <- paste('  :', meta.new$AttributeName[ii], ' = ', '\"', meta.new$AttributeValue[ii], '\"', sep='')
    }
  }
  
  ### --- Tim's edits 2023-09-22: check for new categories --- ###
  fcat = unique(meta.new$Category)
  scat = c('instrument','attachment','deployment','end_of_mission',
           'animal','waypoints','quality')
  acat = setdiff(fcat,scat)
  if (length(acat) > 0){
  	for (aa in acat){
  		idx <- which(meta.new$Category == aa)
        if (length(idx) > 0){
          hdr[(length(hdr)+1)] <- paste('// etag ', aa,' attributes:', sep='')
          for (ii in idx){
            hdr[(length(hdr)+1)] <- paste('  :', meta.new$AttributeName[ii], ' = ', '\"', meta.new$AttributeValue[ii], '\"', sep='')
          }
        }
  	}
  }
  ### --- End of Tim's edit history --- ###

  ## skip file attributes?

  # add data header
  hdr[(length(hdr)+1)] <- paste('// data:', sep='')
  hdr[(length(hdr)+1)] <- paste('// DateTime,VariableID,VariableValue,VariableName,VariableUnits', sep='')

  if (write_hdr){
    # then append header info to existing file
    cat(hdr, file = filename, sep='\n')
    print(paste('Header written to ', filename, '.', sep=''))

  } else{
    # if not, return the hdr
    return(hdr)
  }


}
