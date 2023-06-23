### --- Begin Tim's edit history  --- ###
### 2023-06-15
### a) Added variations of datetime formats used by Lotek after consulting with technical support on TagTalk (locale datetime) and LAT Viewer Studio (fixed format for TimeS)
### --- End of Tim's edit history --- ###

#' Try to figure out the date format
#'
#' Try to figure out the date format and coerce to something useful
#'
#' @param x is input character vector of dates
#' @return a POSIXct vector of dates

testDates <- function(x){
  # first try lubridate
  dt <- suppressWarnings(try(lubridate::as_datetime(x, tz='UTC'), TRUE))

  if(any(class(dt) == 'try-error') | any(is.na(dt))){
    # then try flipTime
    dt <- suppressWarnings(try(flipTime::AsDateTime(x, time.zone = 'UTC'), TRUE))

    if(any(class(dt) == 'try-error') | any(is.na(dt))){
      # attempt to switch date time to time date
      dt <- suppressWarnings(try(lubridate::parse_date_time(x, orders='HMS ymd', tz='UTC'), TRUE))

      if(any(class(dt) == 'try-error') | any(is.na(dt))){
        # attempt to switch date time to time date
        dt <- suppressWarnings(try(lubridate::parse_date_time(x, orders='HMS dbY', tz='UTC'), TRUE))

        if(any(class(dt) == 'try-error') | any(is.na(dt))){
          # attempt to switch date time to time date
          dt <- suppressWarnings(try(lubridate::parse_date_time(x, orders='mdY HMS', tz='UTC'), TRUE))

### Tim's edits 2023-06-15: added other date formats
###-------------------------------------------------
        if(any(class(dt) == 'try-error') | any(is.na(dt))){
          # attempt to switch date time to time date
          dt <- suppressWarnings(try(lubridate::parse_date_time(x, orders='dmY HMS', tz='UTC'), TRUE))

### Tim's addition, for LAT Viewer Studio TimeS column
        if(any(class(dt) == 'try-error') | any(is.na(dt))){
          # attempt to switch date time to time date
          dt <- suppressWarnings(try(lubridate::parse_date_time(x, orders='HMS dmy', tz='UTC'), TRUE))
        if(any(class(dt) == 'try-error') | any(is.na(dt))){
          # attempt to switch date time to time date
          dt <- suppressWarnings(try(lubridate::parse_date_time(x, orders='HMS dmY', tz='UTC'), TRUE))
### --- End of Tim's edits --- ###

          if(any(class(dt) == 'try-error') | any(is.na(dt))){
            # attempt to switch date time to time date
            dt <- suppressWarnings(try(lubridate::parse_date_time(x, orders='mdY HM', tz='UTC'), TRUE))

            if(any(class(dt) == 'try-error') | any(is.na(dt))){
              stop('Tried lubridate, flipTime and HMS ymd orders but unable to figure out datetime format.')
                }
               }             
              }
            }
          }
        }
      }
    }
  }
  return(dt)
}
