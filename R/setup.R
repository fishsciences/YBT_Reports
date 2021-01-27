#--------------------------------------------#
# Yolo Bypass Telemetry Project Setup Script
# 2020-01-26 M. Johnston
#--------------------------------------------#
# This script installs all the necessary packages for making the reproducible telemetry report

# CRAN packages
#-------------------------------------------------------#
CRAN.packages <- c("lubridate", 
                   "knitr", 
                   "ggplot2", 
                   "dplyr", 
                   "plyr", 
                   "ggridges", 
                   "devtools",
                   "padr", 
                   "tidyr",
                   "ggbeeswarm")


new.packages <- CRAN.packages[!(CRAN.packages %in% installed.packages()[,"Package"])]

if(length(new.packages)) install.packages(new.packages)


# Github packages
#-------------------------------------------------------#

github.packages <- c("fishpals", "tagtales", "ybt", "CDECRetrieve")

github.package_sites <- c("fishsciences/fishpals", "Myfanwy/tagtales", "Myfanwy/ybt", "flowwest/CDECRetrieve")

new.gh.pkgs <- github.packages[!(github.packages %in% installed.packages()[, "Package"])]

message("Note for DWR training sessions: if you see a list of packages to update, select 3: nothing")

if(length(new.gh.pkgs)) devtools::install_github(github.package_sites)
