#--------------------------------------------#
# Yolo Bypass Telemetry Project Setup Script
# 2019-08-22 M. Johnston
#--------------------------------------------#
# This script is Step 1 of the analysis workflow, after the database workflow is complete.  It loads necessary libraries, pulls data from the Yolo Bypass telemetry SQLite database and creates variables in the global environment which Step 2 (R/clean.R) and the reproducible reports require.
#-------------------------------------------------------#
# 
# library(RCurl)
# library(RJSONIO)


# Global Variables
#--------------------------------------------#
# base dropbox filepath:
base_fp = "~/NonDropboxRepos/2020-YBT-FinalReport2019/data_clean/"

#base_fp = "C:/Users/Annie Brodsky/Dropbox (Cramer Fish Sciences)/NewPROJECTS/AECCA-2018-YoloTelemetry/DELIVERABLES/Database/"

# database connection: requires >= RSQLite 2.1.1
db_fp = paste0(base_fp, "ybt_database.sqlite") # filepath to the database
#con = RSQLite::dbConnect(RSQLite::SQLite(), db_fp)

# late-fall TagIDs to be excluded:
latefalls <- c(31570, 13720, 13723)

# Create copies of database tables for the global environment:
#--------------------------------------------#

# Chinook tagging metadata (includes RAMP data)
load(paste0(base_fp, "setup_cleaned_chn.rda"))

# All tagging metadata (including both wst and chinook)
load(paste0(base_fp, "setup_cleaned_tags.rda"))

# All cleaned detections
load(paste0(base_fp, "clean_dets_2019_report.rda"))

#--------------------------------------------#
#RSQLite::dbDisconnect(db) # disconnect from database
