library("tabulizer")
library("dplyr")
library("lubridate")
f <- "Pune_Karve_Road.pdf"

# prepare table
data_pdf <- tbl_df(data.frame(date = NA,
                          station = NA,
                          city = NA,
                          state = NA,
                          pollutant = NA,
                          conc = NA,
                          aqi = NA,
                          info = NA))

# not very elegant loop
# the fact is that I don't know how to get the number of pages in the pdf
# and I don't want to input it by hand
errored <- FALSE
page <- 1
while(errored == FALSE){
  print(page)
  # catch error
  out1 <- tryCatch(
    extract_tables(f, page = page),
    error = function(e)
    {
      return(TRUE)
    }
  )
  if(class(out1) == "list"){
    # get the table
    table_aqi <- tbl_df(as.data.frame(out1[[1]]))
    # rare occurence is having two tables per page and thus a shorter table on a page
    if(nrow(table_aqi) > 22){
      # info that is easy to get
      date <- dmy(table_aqi[3,]$V1)
      station <- as.character(table_aqi[2,]$V3)
      city <- as.character(table_aqi[3,]$V3)
      state <- as.character(table_aqi[4,]$V3)
      # loop over pollutants
      table_aqi <- table_aqi[3:17,]
      for(pollutant in c("PM10", "PM2.5", "SO2",
                         "NOx", "CO", "O3",
                         "NH3")){
        pollutant_table <- filter(table_aqi,
                                  grepl(pollutant, V1))
        info <- as.character(pollutant_table$V2)
        values <- as.character(pollutant_table$V3)
        values <- sub(" AQI.*", "", values)
        values <- strsplit(values, " ")[[1]]
        # use the "check" info
        if(values[length(values)] == 0){
          conc <- NA
          aqi <- NA
        }else{
          conc <- as.numeric(values[1])
          aqi <- as.numeric(values[2])
        }

        data_pdf <- bind_rows(data_pdf,
                          data.frame(date = date,
                                     station = station,
                                     city = city,
                                     state = state,
                                     pollutant = pollutant,
                                     conc = conc,
                                     aqi = aqi,
                                     info = info))

      }
    }

    page <- page + 1
  }
  else{
    errored <- TRUE
  }


}

save(data_pdf, file = "data_pdf.RData")
load("data_pdf.RData")

# clean data
data_pdf <- data_pdf[2: nrow(data_pdf),]
data_pdf <- data_pdf %>% mutate(pollutant = factor(pollutant))

# make a plot
library("ggplot2")
data_pdf %>% filter(pollutant != "NH3") %>%
ggplot() +
  geom_point(aes(x = date,  y = conc)) +
  facet_grid(pollutant ~ ., scales = "free_y") +
  ggtitle("AQI pollutants in Pune")
ggsave(file = "aqi.PNG")

