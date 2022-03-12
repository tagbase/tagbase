# Title: tagbase_plotting.R
# Date started: 12 August 2011
# Purpose: plotting with tagbase data

library(RODBC)

##################### start plot.pdt #################################
# db.object is object created from call to dbCon to connect to tagbase
# PSAT.Ptt is the Argos PTT assigned to the tag
# x.int is the time interval plotted on the x.axis
# y.int is the depth interval plotted on the y.axis
# title is the title at the top of the plot
# save.name is the directory and filename where the plot should be saved in .pdf format. (ie. save.name="/.../Tagbase/Plots/pdt.pdf")
# smallplot are the plot coordinates where the temperature scale bar should be put
# interp is binary indicating if temperatures should be interpolated across depths
# add.cont is binary indicating if contours should be overlayed on interpolated points
# interp.obs is binary indicating if raw observations used for interpolations should also be overlayed
plot.pdt<-function(db.object, PSAT.Ptt, xlab='Date (GMT)', ylab='Depth (m)', x.int="5 days", y.int=25, title="", save.name, smallplot=c(0.90,0.92,0.25,0.75), interp=T, add.cont=T, interp.obs=T){
  library(fields)
  taginfo.table<-sqlFetch(channel=db.object, "TagInfo"); taginfo.table
  pdt.table<-sqlFetch(channel=db.object, "Proc_WC_PDT"); pdt.table
  id.info<-taginfo.table[taginfo.table$TagPTTID == PSAT.Ptt,]; id.info
  pdt.PSAT<-pdt.table[pdt.table$TagID == id.info$TagID,]; pdt.PSAT
  pdt.PSAT<-pdt.PSAT[order(pdt.PSAT$DateTime),]  
  pdt.PSAT$DateTime<-ISOdatetime(substr(pdt.PSAT$DateTime,1,4), substr(pdt.PSAT$DateTime,6,7), substr(pdt.PSAT$DateTime,9,10), 
    substr(pdt.PSAT$DateTime,12,13),substr(pdt.PSAT$DateTime,15,16),substr(pdt.PSAT$DateTime,18,19), 'GMT'); pdt.PSAT$DateTime
  date.plot<-seq(from = min(pdt.PSAT$DateTime), to = max(pdt.PSAT$DateTime) + difftime(max(pdt.PSAT$DateTime), min(pdt.PSAT$DateTime))*.03, by = x.int); date.plot
  xyz<-na.omit(as.data.frame(cbind(x=as.numeric(pdt.PSAT$DateTime)/10000, y=pdt.PSAT$Depth, z=pdt.PSAT$MaxTemperature)));xyz[1:10,]  
  int<- if(interp == TRUE){
    library(akima)
    int<-interp(x=xyz$x, y=-xyz$y, z=unlist(xyz$z), xo=seq(from=min(xyz$x), to=max(xyz$x), length=500),
      yo=seq(from=min(-xyz$y), to=max(-xyz$y), length=500), duplicate='strip', extrap=F)  
    par(font.lab=2)
    pdf(paste(save.name, '.pdf', sep=""))
    image.plot(int, las=2, cex.axis=0.8, font.axis=2, font.lab=2, xaxt='n', ylab="Depth (m)")
    image(int, axes=F, col=0, xlab="", add=T)
    axis.POSIXct(1, at=date.plot, format='%d-%b-%y')
    if (interp.obs == TRUE){ 
      points(xyz$x, -xyz$y, col='white', pch=16, cex=0.25)
      }
    if (add.cont == TRUE){ 
      contour(int, add=T, labcex=0.8, font=2, lty=2)
      }
    box()  
    dev.off()
    }
  if(interp == FALSE){
  pdf(paste(save.name, '.pdf', sep=""))
  par(font.lab=2, font.axis=2, plt=c(0.1171429, 0.9000000, 0.1457143, 0.8828571), mai=c(bottom=1.02, left=0.82, top=0.82, right=0.82))
  plot(x=pdt.PSAT$DateTime, y=-pdt.PSAT$Depth, col=color.scale(z=pdt.PSAT$MaxTemperature, col=tim.colors()), xaxt='n', 
    las=1, xlab="", ylab=ylab, xlim=range(date.plot, na.rm=T), ylim=c(min(-pdt.PSAT$Depth, na.rm=T), 0), pch=19, axes=T, main=title)
  image.plot(x=pdt.PSAT$DateTime, y=-pdt.PSAT$Depth, z=pdt.PSAT$MaxTemperature, add=T, legend.only=T, smallplot=smallplot)  
  axis.POSIXct(1, at=as.character(date.plot), format='%d-%b-%y', las=2, cex.axis=0.8, xlab, las=2, font=2)
  axis(2, at = rev(seq(from=min(-pdt.PSAT$Depth, na.rm=T), to=0, by=y.int)), labels=seq(from=0, to=max(pdt.PSAT$Depth, na.rm=T), by=y.int), tick=T, las=2, font=2)
  box()
  dev.off()
  }}
################################# end plot.pdt #################################################################################


##################### start plot.histo.ts #################################
# db.object is object created from call to dbCon to connect to tagbase
# PSAT.Ptt is the Argos PTT assigned to the tag
# smallplot are plot coordinates for where temperature scalebar will be placed. Default is horizontally along the top of the plot
# x.int is the time interval plotted on the x.axis
# y.int is the depth interval plotted on the y.axis
# title is the title at the top of the plot
# save.name is the directory and filename where the plot should be saved in .pdf format. (ie. save.name="/.../Tagbase/Plots/pdt.pdf")
# smallplot are the plot coordinates where the temperature scale bar should be put
# interp is binary indicating if temperatures should be interpolated across depths
# add.cont is binary indicating if contours should be overlayed on interpolated points
# interp.obs is binary indicating if raw observations used for interpolations should also be overlayed  