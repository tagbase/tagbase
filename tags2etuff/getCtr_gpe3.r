getCtr_gpe3 <- function(ncFile, csvFile, threshold = 50, makePlot=T, scaling = 1)
{
  ### --- Begin Tim's edit history  --- ###
  ### 2022-03-10
  ### a) add "scaling" to scale the resolution of Raster.big 
  ### b) handle empty lat/lon in csvFile
  ### --- End of Tim's edit history --- ###
  nc <- RNetCDF::open.nc(ncFile)
  mtime <- as.POSIXct(RNetCDF::var.get.nc(nc, 'twelve_hour_timestamps'), origin='1970-01-01', tz='UTC')
  s <- raster::stack(ncFile, varname="twelve_hour_likelihoods")

  #To interpolate a surface (resample it at a higher resolution):
  Raster.big <- raster::raster(ncol=400*scaling, nrow=300*scaling, ext=raster::extent(s)) #creates the higher resolution grid

  Raster.HR <- raster::resample(x=s, y=Raster.big, method="bilinear")
  #will resample the data object onto the higher resolution grid

  Raster.HR <- Raster.HR / raster::cellStats(Raster.HR, stat='sum', na.rm=T)
  #normalize the grid values so they sum to 1

  #ex <- raster::extent(Raster.HR)
  #lon <- seq(ex@xmin, ex@xmax, length.out=dim(Raster.HR)[2])
  #lat <- seq(ex@ymin, ex@ymax, length.out=dim(Raster.HR)[1])

  tr.zz <- read.table(csvFile, sep=',', skip=4, header=T)
  tr.zz$Date <- as.POSIXct(tr.zz$Date, format='%d-%b-%Y %H:%M:%S', tz='UTC')
  names(tr.zz) <- tolower(names(tr.zz))
  if (length(grep('ptt', names(tr.zz), ignore.case = T)) == 0) tr.zz$ptt <- as.integer(substr(ncFile, 1, regexpr('-', ncFile)[1]-1))
  if (!any(!is.na(tr.zz$ptt))) tr.zz$ptt <- as.integer(substr(ncFile, 1, regexpr('-', ncFile)[1]-1))

  for (tt in c('ptt','date','lat','lon')){
    if (tt == 'ptt'){
      idx <- grep(tt, names(tr.zz), ignore.case=T)
    } else {
      idx <- c(idx, grep(tt, names(tr.zz), ignore.case=T))
    }
  }

  usr <-  tr.zz[which(tr.zz$observation.type == 'User'), idx]
  tr <- tr.zz[which(tr.zz$date %in% mtime), idx]

  #tr <- tr.zz[,idx]
  names(tr) <- c('ptt','date','lat','lon')
  names(usr) <- c('ptt','date','lat','lon')

  threshold <- threshold / 100

  out <- list()

  for (i in 1:dim(s)[3]){
    #To create probability surfaces (95%, 75%, 50%):
    RasterVals <- sort(raster::getValues(Raster.HR[[i]])) #sort the probability values

    #sets breaks at the cumulative probabilities (95%, 75%, 50%) with a cap at 1 (higher than necessary, but no value can ever exceed 1)
    Raster.breaks <- c(RasterVals[max(which(cumsum(RasterVals) <= threshold))])

    #print(i)
	#print(Raster.breaks)
    ctr <- raster::rasterToContour(Raster.HR[[i]], levels=Raster.breaks)
    #ctr <- contourLines(lon, lat, s[[i]])
    #idx <- which.min(lapply(ctr, FUN=function(x) which(round(x$level,1) == round(threshold, 1))) == 1)
    #ctr.i <- as.data.frame(ctr)
    #sp::coordinates(ctr.i) <- ~x+y
    #l1 <- sp::SpatialLines(list(sp::Lines(sp::Line(sp::coordinates(ctr.i)), "L1")))
    l1 <- sp::as.SpatialLines.SLDF(ctr)
    
	### --- Tim's edits 2022-03-10: tr$lon or tr$lat somehow is NA in WC's output nc file --- ###
	inY = NULL
	inX = NULL
	if (!is.na(tr$lon[i]) | !is.na(tr$lat[i])){
	### --- End of Tim's edits --- ###	
      hl <- data.frame(matrix(c(tr$lon[i] - 10, tr$lon[i], tr$lon[i] + 10, rep(tr$lat[i], 3)), ncol=2))
      names(hl) <- c('x','y')
      sp::coordinates(hl) <- ~x+y
      hl <- sp::SpatialLines(list(sp::Lines(sp::Line(sp::coordinates(hl)), 'hl')))

      vl <- data.frame(matrix(c(rep(tr$lon[i], 3), tr$lat[i] - 10, tr$lat[i], tr$lat[i] + 10), ncol=2))
      names(vl) <- c('x','y')
      sp::coordinates(vl) <- ~x+y
      vl <- sp::SpatialLines(list(sp::Lines(sp::Line(sp::coordinates(vl)), 'vl')))

      inY <- rgeos::gIntersection(l1, vl)
      inX <- rgeos::gIntersection(l1, hl)
	}
	
    if (is.null(inX) | is.null(inY)){
      out[[i]] <- list(ctr=l1, yDist=NA, xDist=NA, loc=tr[i,], inY=NA, inX=NA)

    } else{
      if(makePlot){
        xl <- c(ctr@bbox[1,1]-1, ctr@bbox[1,2]+1)
        yl <- c(ctr@bbox[2,1]-1, ctr@bbox[2,2]+1)

        #fields::image.plot(lon, lat, Raster.HR[[i]])#, xlim=xl, ylim=yl)
        image(Raster.HR[[i]], xlim=xl, ylim=yl)
        lines(l1)
        lines(hl)
        lines(vl)
        points(tr$lon[i], tr$lat[i])
        points(inY)
        points(inX)

        # get user input to proceed
        invisible(readline(prompt="Press [enter] to perform the next iteration and plot"))
      }

      if(dim(inY@coords)[1] == 1){
        tr.i <- data.frame(matrix(c(tr$lon[i], tr$lat[i]),ncol=2))
        names(tr.i) <- c('x','y')
        sp::coordinates(tr.i) <- ~x+y
        yDist <- sp::spDists(tr.i, inY)
      } else{
        yDist <- sp::spDists(inY)[1,2] / 2 # Euclidean, in degrees
      }

      if(dim(inX@coords)[1] == 1){
        tr.i <- data.frame(matrix(c(tr$lon[i], tr$lat[i]),ncol=2))
        names(tr.i) <- c('x','y')
        sp::coordinates(tr.i) <- ~x+y
        xDist <- sp::spDists(tr.i, inX)
      } else{
        xDist <- sp::spDists(inX)[1,2] / 2 # Euclidean, in degrees
      }

      out[[i+1]] <- list(ctr=l1, yDist=yDist, xDist=xDist, loc=tr[i,], inY=inY, inX=inX)

    }

  }

  out[[1]] <- list(ctr = NA, yDist = 0, xDist = 0, loc = usr[1,], inY = NA, inX = NA)
  out[[length(out) + 1]] <- list(ctr = NA, yDist = 0, xDist = 0, loc = usr[2,], inY = NA, inX = NA)

  return(out)

}



