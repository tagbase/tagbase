read.wc <- function (filename, tag, pop, type = "sst", dateFormat = NULL, 
    verbose = FALSE) 
{
    if (type == "pdt") {
        data <- utils::read.table(filename, sep = ",", header = T, 
            blank.lines.skip = F, skip = 0)
        if (length(grep("Discont16", names(data))) == 0 & ncol(data) > 
            89) 
            names(data)[90:94] <- c("Depth16", "MinTemp16", "MaxTemp16", 
                "X.Ox16", "Discont16")
        if (verbose) 
            print(paste("If read.wc() fails for type=pdt, check the number of column headers in the PDTs.csv file."))
        data <- extract.pdt(data)
        if (is.null(dateFormat)) {
            dts <- as.POSIXct(data$Date, format = findDateFormat(data$Date))
        }
        else {
            dts <- as.POSIXct(data$Date, format = dateFormat)
        }
        data$Date <- dts
        d1 <- as.POSIXct("1900-01-02") - as.POSIXct("1900-01-01")
        didx <- dts >= (tag + d1) & dts <= (pop - d1)
        data <- data[didx, ]
        dts <- dts[didx]	
        data1 <- data
        data1$dts <- as.Date(dts)
        dt.cut <- data.frame(group_by(data1, dts) %>% summarise(n = n()))
        dt.cut <- dt.cut[which(dt.cut[, 2] < 3), 1]
        if (length(dt.cut) == 0) {
        }
        else {
            data <- data1[-which(data1$dts %in% dt.cut), ]
        }
        udates <- unique(as.Date(data$Date))
        gaps <- diff(c(as.Date(tag), udates, as.Date(pop)), units = "days")
        if (verbose) {
            print(utils::head(data))
            print(paste(length(which(as.Date(seq(tag, pop, "day")) %in% 
                udates)), " of ", length(seq(tag, pop, "day")), 
                " deployment days have PDT data...", sep = ""))
            print(paste("Data gaps are ", paste(gaps[gaps > 1], 
                collapse = ", "), " days in PDT..."))
        }
    }
    else if (type == "sst") {
        data <- utils::read.table(filename, sep = ",", header = T, 
            blank.lines.skip = F)
        if (is.null(dateFormat)) {
            dts <- as.POSIXct(data$Date, format = findDateFormat(data$Date))
        }
        else {
            dts <- as.POSIXct(data$Date, format = dateFormat)
        }
        data$Date <- dts
        d1 <- as.POSIXct("1900-01-02") - as.POSIXct("1900-01-01")
        didx <- dts >= (tag + d1) & dts <= (pop - d1)
        data <- data[didx, ]
        if (length(data[, 1]) < 1) {
            stop("Something wrong with reading and formatting of tags SST data. Check date format.")
        }
        dts <- as.POSIXct(data$Date, format = findDateFormat(data$Date))
        udates <- unique(as.Date(dts))
        data <- data[, c("Date", "Depth", "Temperature")]
        gaps <- diff(c(as.Date(tag), udates, as.Date(pop)), units = "days")
        if (verbose) {
            print(utils::head(data))
            print(paste(length(which(as.Date(seq(tag, pop, "day")) %in% 
                udates)), " of ", length(seq(tag, pop, "day")), 
                " deployment days have SST data...", sep = ""))
            print(paste("Data gaps are ", paste(gaps[gaps > 1], 
                collapse = ", "), " days..."))
        }
    }
    else if (type == "light") {
        data <- try(utils::read.table(filename, sep = ",", header = T, 
            blank.lines.skip = F, skip = 2), TRUE)
        if (class(data) == "try-error") {
            data <- try(utils::read.table(filename, sep = ",", 
                header = T, blank.lines.skip = F, skip = 0), 
                TRUE)
            if (class(data) == "try-error") 
                stop("Tried reading light data with skip=2 (old WC format) and skip=0 (new WC format) but both failed. Check source light data file and try again.")
        }
        if (!any(grep("depth", names(data), ignore.case = T))) 
            data <- utils::read.table(filename, sep = ",", header = T, 
                blank.lines.skip = F, skip = 1)
        if (!any(grep("depth", names(data), ignore.case = T))) 
            data <- utils::read.table(filename, sep = ",", header = T, 
                blank.lines.skip = F, skip = 0)
        data <- data[which(!is.na(data[, 1])), ]
        dts <- lubridate::parse_date_time(data$Day, orders = c("dby", 
            "dbY"), tz = "UTC")
        if (as.Date(dts[1]) > as.Date(Sys.Date()) | as.Date(dts[1]) < 
            "1990-01-01") {
            stop("Error: dates are in the future or before 1990 and thus likely did not parse correctly.")
        }
        d1 <- as.POSIXct("1900-01-02") - as.POSIXct("1900-01-01")
        didx <- (dts > (tag + d1)) & (dts < (pop - d1))
        data <- data[didx, ]
        data$dts <- as.Date(dts[didx])
        udates <- unique(as.Date(dts))
        gaps <- diff(c(as.Date(tag), udates, as.Date(pop)), units = "days")
        if (verbose) {
            print(utils::head(data))
            print(paste(length(which(as.Date(seq(tag, pop, "day")) %in% 
                udates)), " of ", length(seq(tag, pop, "day")), 
                " deployment days have light data...", sep = ""))
            print(paste("Data gaps are ", paste(gaps[gaps > 1], 
                collapse = ", "), " days..."))
        }
    }
    return(data)
}
