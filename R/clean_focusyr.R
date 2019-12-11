# Data munging script - cleaning detections for focus year only
# 2019-08-26 M. Johnston
#--------------------------------------------#
# This script is Step 2 after the database has been appended and analysis is to begin.  It assumes you have parameterized TelemetrySummary.Rmd, and then it takes the raw detections and tags from the database for a given year and tidies them up for analysis, including:

#-------------------------------------------------------#
# PART 1 - check for dups in raw dets
#--------------------------------------------#

d = detmeta # creates a copy of the filtered detections
i = duplicated(d[, c("TagID", "Receiver", "DateTimePST")])
unique(d[d$Receiver %in% d$Receiver[i], ]$Receiver) 
d2 = d[!i,]
stopifnot(nrow(d) - nrow(d2) == sum(i)) # check that it removed the correct # of rows

#-------------------------------------------------------#
# PART 2 - Joining detections with their appropriate deployment (Station) data
#-------------------------------------------------------#

# Find receivers with multiple deployment locations:
(duprecs <- get_dup_deps(dep_df = as.data.frame(deps)))
# as of July 2019, there are only two receivers that have been used and then re-deployed in another place: Above Ag4/Belwo Wallace Weir, and Above Wallace Weir/Below Los Rios Check Dam.

# Because there will be more as deployments go on, it's important to appropriately join receiver data so that: 

# 1) the appropriate station is associated with receiver detections of a certain date range.
# 2) we can double check that each detection is associated with a valid receiver deployment, i.e. that there are no "orphan" detections.

# The get_stations() function does this in one step.  If you have NAs in your results (basically, detections that don't fall within any particular deployment window), the function will not fail but it will trip a warning.

d2 = get_stations(d2, deps)
colSums(is.na(d2)) # all the NAs should be in the StationAbbOld column.
stopifnot(nrow(d) - nrow(d2) == sum(i) )# should equal d without the dups

#--------------------------------------------#
# PART 3 - Adding a "grouped stations" column for gated receivers
#-------------------------------------------------------#
stnix = d2 %>% 
  filter(!duplicated(StationAbbOld)) %>% 
  select(StationAbbOld, Station) %>% 
  arrange(StationAbbOld)

d2 %>% 
  mutate(GroupedStn = case_when(
    StationAbbOld == "BCE" ~ "BCN",
    StationAbbOld == "BCW" ~ "BCN",
    StationAbbOld == "BCE2" ~ "BCS",
    StationAbbOld == "BCW2" ~ "BCS",
    StationAbbOld == "Abv_rstr" ~ "YBRSTR",
    TRUE ~ Station
  )) -> d2

d2 <- select(d2, TagID, CodeSpace, DateTimePST, Receiver, GroupedStn, Station, StationAbbOld)

#--------------------------------------------#
# PART 4 - Remove simultaneous detections at grouped stations
#--------------------------------------------#
# First, get rid of all the duplicate detections at grouped receivers: BCS, YBRSTR, BCN
simuls = d2 %>% 
  group_by(TagID, GroupedStn) %>% 
  filter(duplicated(DateTimePST)) %>% 
  ungroup() %>% 
  filter(GroupedStn %in% c("BCS", "BCN", "YBRSTR")) 

d3 = anti_join(d2, simuls) # filter out simultaneous detections within tags
stopifnot(nrow(d2) - nrow(d3) == nrow(simuls))

# find additional duplicates within TagIDs within other stations
dups = duplicated(d3[, c("TagID", "GroupedStn", "DateTimePST")])
dupsdf = d3[which(dups), ] # get duplicated dets
unique(dupsdf$Receiver)
range(dupsdf$DateTimePST)

d4 <- d3[!dups, ] # filter out duplicate Lisbon Weir detections

#--------------------------------------------#
# PART 5 - Check that no fish have detections before they were tagged
#--------------------------------------------#
d4 %>% 
  left_join(select(alltags, TagID, DateTagged)) %>% 
  group_by(TagID) %>% 
  filter(DateTimePST < as.POSIXct(DateTagged)) %>% 
  ungroup() -> falsedets
  
head(falsedets)
unique(falsedets$TagID)

falsedets %>% 
  group_by(TagID) %>% 
  summarise(DateTagged = unique(DateTagged),
            mindet = min(DateTimePST),
            maxdet = max(DateTimePST))

falsedets %>% 
  group_by(TagID) %>% 
  tally()

d5 <- anti_join(d4, falsedets)
stopifnot(nrow(d4) - nrow(d5) == nrow(falsedets))
#--------------------------------------------#
# Shed tags
#--------------------------------------------#
library(ggforce)
# end product: .csv with TagID, TruncatedLoc, TruncatedDateTimePST.
# to get there: series of functions

# first: fda results
fdas <- do.call(rbind, 
                lapply(list.files(path = fda_dir, 
                                  pattern = "FDA", 
                                  recursive = TRUE, 
                                  full.names = TRUE),
                       read.csv, stringsAsFactors = FALSE))
d <- fdas

colnames(d)[1:2] <- c("TagID", "Monitor")
head(d)
d <- parse_receiver_col(d, "Monitor")
d <- parse_tagid_col(d, "TagID")
head(d)
d$DateTimePST <- ymd_hms(d$First.Detected) # Convert to POSIXct
d$Last.Detected <- ymd_hms(d$Last.Detected)
d$Receiver <- as.numeric(d$Receiver) # Convert Receiver S/Ns to numeric
d$TagID <- as.numeric(d$TagID) # Convert tagIDs to numeric
d$CodeSpace <- as.numeric(d$CodeSpace)
# check for NAs
stopifnot(sum(colSums(is.na(d))) == 0)
d <- select(d, TagID, CodeSpace, Receiver, DateTimePST, Last.Detected, Detections, Minimum.Interval, Short.Intervals, Long.Intervals, Acceptance)

# convert UTC time to PST time and save as a new column
d <- d  %>% 
  mutate(DateTimePST = with_tz(DateTimePST, tzone ="Pacific/Pitcairn"),
         Last.Detected = with_tz(Last.Detected, tzone ="Pacific/Pitcairn")) %>% 
  filter(TagID %in% alltags$TagID) %>% 
  filter(Acceptance == "Questionable")

fda_dets = d

head(arrange(d, desc(Detections)))

# see if there are "questionable" detections within the cleaned dets 
mm <- merge(d5, d[,c("TagID","Receiver","DateTimePST")], all.x = FALSE, all.y = FALSE)

#--------------------------------------------#
stns %>% 
  select(GroupedStn, rkms) %>% 
  filter(!is.na(GroupedStn)) %>% 
  filter(!duplicated(GroupedStn)) -> stns

d7 <- left_join(d5, stns) # keep all detection rows, discard non-matching grouped stations

d7 %>% 
  filter(TagID %in% mm$TagID) %>% 
  mutate(fd = ifelse(DateTimePST %in% mm$DateTimePST, "questn", "real")) %>% 
  ggplot() +
  geom_jitter(aes(x = DateTimePST, y = reorder(GroupedStn, rkms),
                  color = fd), width = 0.05) +
  facet_wrap_paginate(~TagID, scales = "free", ncol = 2, nrow = 3, page = 1)

# ~10 / 54 fish flagged by fda may actually be false dets... but the sturgeon are a funny thing, need to run the tag life numbers to see how much of those detections should be counted in the first place.
dis <- c(13728, 13722, 23053, 46644, 56473, 56483, 56492, 56494, 37835, 31563)

fd_discard <- filter(mm, TagID %in% dis)
str(fd_discard)
str(d7)
d8 <- anti_join(d7, mm[,c("TagID","Receiver","DateTimePST")])
str(d8)
#-------------------------------------------------------#
# Shed tags
#--------------------------------------------#
# end product: df with TagID, TruncatedLoc, TruncatedDateTimePST.
# Note: for shed tags, truncated DateTimePST = 24 hours after arrival at final station, where shed record begins.

orgdets <- d5 # to compare with
dets = d8 # after "false dets removed"
dets[dets$DateTimePST == max(dets$DateTimePST), ]

ct1 <- dets %>% filter(TagID == 9982, DateTimePST > force_tz(ymd_hms("2018-11-15 03:10:35"), "Pacific/Pitcairn"))

ct2 <- dets %>% filter(TagID == 13729, DateTimePST > with_tz(ymd_hms("2014-12-04 15:23:06"), tzone = "Pacific/Pitcairn")) # died/shed at Cache Creek

ct3 <- dets %>% filter(TagID == 20168, DateTimePST > with_tz(ymd_hms("2014-11-17 05:26:10"), "Pacific/Pitcairn")) # died/shed abv_lisbon

ct4 <- dets %>% filter(TagID == 20164, DateTimePST > with_tz(ymd_hms("2014-12-23 12:04:55"), "Pacific/Pitcairn")) # died/shed wallace weir

ct5 <- dets %>% filter(TagID == 37835, DateTimePST >= ymd_hms("2016-01-07 08:51:42")) # this one is odd... no way to tell how/whedetsit got above swanston, but have truncated it to last detection below swanston for now
ct6 <- dets %>% filter(TagID == 2600, DateTimePST >= ymd_hms("2017-10-16 20:51:12")) # ended at rstr

ct7 <- dets %>% filter(TagID == 2625, DateTimePST >   with_tz(ymd_hms("2017-12-27 21:06:10"), "Pacific/Pitcairn"))

ct8 <- dets %>% filter(TagID == 9973, DateTimePST > force_tz(ymd_hms("2018-12-02 10:30:08"), "Pacific/Pitcairn"))

ct9 <- dets %>% filter(TagID == 9986, DateTimePST > force_tz(ymd_hms("2018-12-03 06:37:13"),"Pacific/Pitcairn"))

ct10 <- dets %>% filter(TagID == 2619, DateTimePST >  force_tz(ymd_hms("2017-11-20 15:42:04"), "Pacific/Pitcairn"))

ct11 <- dets %>% filter(TagID == 31555, DateTimePST > force_tz(ymd_hms("2013-10-20 07:34:45"), "Pacific/Pitcairn"))


chn_truncate <- rbind(ct1, ct2, ct3, ct4, ct5, ct6, ct7, ct8, ct9, ct10, ct11 )

cleandets <- anti_join(dets, chn_truncate)

stopifnot(nrow(dets) - nrow(cleandets) == nrow(chn_truncate)) # should equal the nrows of chn_truncate
rm(dets)
