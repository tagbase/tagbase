### Easier listing for loading modified scripts
modscript <- function(txt=""){
  ### Must have	
  mss = c('url_tagbase.r', 'tag_to_etuff.r', 'build_meta_head.r')
  ### Wildlife Computers
  if (txt == "wc"){
  	mss <- c(mss, c('getCtr_gpe3.r','findDateFormat.r','readwc.r', 'extract.pdt.r', 'extract.light.r'))
  }
  ### Lotek Wireless
  if (txt == "lotek"){
  	mss <- c(mss, c('read_lotek.r','testDates.r', 'lotek_format_dl.r', 'lotek_format_ts.r'))
  }  
  ### Microwave Telemetry
  if (txt == "mt"){
  	# Nothing special required
  	mss <- c(mss, c())
  }    
  return(mss)
}