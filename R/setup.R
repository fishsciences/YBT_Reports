#--------------------------------------------#
# Yolo Bypass Telemetry Project Setup Script
# 2019-08-22 M. Johnston
#--------------------------------------------#
# This script is Step 1 of the analysis workflow, after the database workflow is complete.  It loads necessary libraries, pulls data from the Yolo Bypass telemetry SQLite database and creates variables in the global environment which Step 2 (R/clean.R) and the reproducible reports require.
#-------------------------------------------------------#
library(dplyr)
library(RCurl)
library(RJSONIO)
library(ybt)
library(fishpals)

# Global Variables
#--------------------------------------------#
# Browser handles for BARD query:
curl = getCurlHandle(useragent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/75.0.3770.100 Safari/537.36", followlocation = TRUE)

# database connection: requires >= RSQLite 2.1.1
db = RSQLite::dbConnect(RSQLite::SQLite(), "~/Dropbox (Cramer Fish Sciences)/NewPROJECTS/AECCA-2018-YoloTelemetry/WORKING/GoogleDriveBackup20190723/yb_database.sqlite")

# late-fall TagIDs to be excluded:
latefalls <- c(31570, 13720, 13723)

# Create copies of database tables for the global environment:
#--------------------------------------------#

# Chinook tagging metadata (includes RAMP data)
chn = tbl(db, "chn") %>% collect() %>% 
  mutate(DateTagged = ymd(DateTagged))


# All tagging metadata (including both wst and chinook)
alltags = tbl(db, "tags") %>% collect() %>% 
  mutate(DateTagged = as.Date(DateTagged))

# Receiver deployments table
deps = tbl(db, "deployments") %>% 
  collect() %>% 
  select(StationAbbOld, Station, Receiver, Start = DeploymentStart, End = DeploymentEnd) %>% 
  mutate(Start = force_tz(ymd_hms(Start), "Pacific/Pitcairn"),
         End = force_tz(ymd_hms(End), "Pacific/Pitcairn"))

deps = deps[!is.na(deps$End), ] # filter out the ragged last cell


# All detections
dets <- tbl(db, "detections") %>% 
  collect() %>% # this pulls entire table - may take awhile
  filter(TagID %in% alltags$TagID) %>% # filter down to just our fish
  mutate(DateTimePST = ymd_hms(DateTimePST)) %>% 
  arrange(DateTimePST)

dets$DateTimePST <- force_tz(dets$DateTimePST, "Pacific/Pitcairn")

#--------------------------------------------#
RSQLite::dbDisconnect(db) # disconnect from database
