# Connect to tagbase
source("C:/Tagbase/Code/R/function_library/connect2database.R")
db<-dbCon(db.dir="C:/Tagbase/", db.filename="TagBase4_3-BlueSharkData")

# Get meta-data of tags deployed
meta<-sqlFetch(channel=db, "TagInfo"); meta

# pdt
source("C:/Tagbase/Code/R/function_library/tagbase_plotting.r")
for (i in 1 : length(unique(meta$TagPTTID))){
PSAT.Ptt<-unique(meta$TagPTTID)[i]
plot.pdt(db.object=db, PSAT.Ptt=PSAT.Ptt, save.name=paste('C:/Tagbase/Figures/PDT/', PSAT.Ptt, "_interp.pdt", sep=""), interp=T, add.cont=TRUE, interp.obs=F)
}

# Load meta data table, select tag to geolocate
i<-1
PSAT.Ptt<-unique(meta$TagPTTID)[i]

 # change to desired PTT number
meta.PSAT<-meta[-grep(pattern="SPOT", x=meta$TagModel) & meta$TagPTTID == PSAT.Ptt,]; meta.PSAT # excludes SPOT data

# trackit
library(trackit)
source("C:/Tagbase/Code/R/function_library/geolocation.r")
track<-get.trackit.dat(db.object=db, TagID=meta.PSAT$TagID); track[c(1,nrow(track)),]
track<-two.layer.depth.corr(track) # depth corrected light levels based on http://www.lotek.com/irradiance.pdf (2002 paper by Phil Ekstrom)
prep<-prepit(track=track, scan=F,
  fix.first=c(ifelse(meta.PSAT$Lon_Deploy < 0, meta.PSAT$Lon_Deploy + 360, meta.PSAT$Lon_Deploy), meta.PSAT$Lat_Deploy,
  as.numeric(substr(meta.PSAT$DateTime_Deploy,1,4)), as.numeric(substr(meta.PSAT$DateTime_Deploy,6,7)), as.numeric(substr(meta.PSAT$DateTime_Deploy,9,10)), 0, 0 ,0),
  fix.last=c(ifelse(meta.PSAT$Lon_Popoff < 0, meta.PSAT$Lon_Popoff + 360, meta.PSAT$Lon_Popoff), meta.PSAT$Lat_Popoff,
  as.numeric(substr(meta.PSAT$DateTime_Popoff,1,4)), as.numeric(substr(meta.PSAT$DateTime_Popoff,6,7)), as.numeric(substr(meta.PSAT$DateTime_Popoff,9,10)), 0, 0 ,0))
t<-trackit(prep);t
fit2csv(t, "C:\\Tagbase\\Code\\R\\", 3184)