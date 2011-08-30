# Title: Tagbase analysis library
# Author: Tim Sippel
# Date started: 12 August 2011
# Purpose: Connected to tagbase through R terminal

##################### start dbCon #################################
# Connect R to tagbase
# db.dir is character string pointing to directory holding the database (ie. "/.../tagbase")
# db.filename is character string of database filename with .mdb extension (ie. "tagbase.mdb")
dbCon<-function(db.dir, db.filename){
library(RODBC)
db<-odbcConnectAccess2007(access.file=paste(db.dir, db.filename, sep=""))
}
###################### end dbCon ##################################

