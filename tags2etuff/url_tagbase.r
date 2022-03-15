### --- Tim's edits: function to construct Github repo urls --- ###
tagbase.url <- function(filenum=1){
  # filenum = file number to access
  gurl = 'https://raw.githubusercontent.com/tagbase/tagbase/master'
  gdir1 = '/tags2etuff/'
  gdir2 = '/etuff/'
  ### Metadata types
  gfile = switch(filenum,'eTagMetadataInventory.csv',
						 'eTUFF-ObservationTypes.csv',
						 'FileHeadersWC.csv')
  ### Return file
  filename <- paste0(gurl,gdir2,gfile)
  return(filename)
}
### --- End of Tim's edits --- ###