# some numberr checking

## first lets get the actual number of hospitals listed as entities in 2025

## Then lets get those that are active... e.g. do they have data if not we drop them
rm(list=ls())
library(tidyverse)
Registry<-read.csv("E:/HospitalIntelligenceR/dev/registry_flat.csv") %>%
# we have 146 hospitals in the registry
  # 3 of them have been retired 
  # 653 Englehart, 696 Kirkland and 813 Stratford
  # 7 ARE BLOCKED BY ROBOTXT
  # THIS DATA SET HAS ALREADY SCREEND OUT THE OTHER/PRIVATE
  group_by(robots_allowed) %>%
  mutate(robotStatus=n()) %>%
  ungroup() %>%
  filter(robots_allowed=="TRUE") %>%
  filter(retired=="FALSE")
RoboTxtBlocked<-read.csv("E:/HospitalIntelligenceR/dev/registry_flat.csv") %>%
  filter(robots_allowed=="FALSE")

# 7 of them are robotxtxt blocked.
HIT<-read.csv("E:/HospitalIntelligenceR/roles/hit/source_data/MOH_FACILITIES_MAY1_2026.csv") %>%
 filter(!is.na(Facility.ID))%>%
  rename(fac=Facility.ID) %>%
  rename(Hospital=Facility)%>%
  rename(Type=Facility.Type) %>%
  select(fac,Hospital,Type) %>%
  group_by(Type)%>%
  mutate(ntype=n())
## so 146 hosptials. three of these are "other" which are essentially privately run
#Toronto don Mills Surgical fac=680
#Thronhill Shouldice 855
#Toronto Bellwood health services 908

## Then lets match with the strategy.master.csv
StratHosp<-read.csv("E:/HospitalIntelligenceR/analysis/data/strategy_master_analytical.csv") %>%
  group_by(direction_type)%>%
  mutate(DiretionNumbers=n()) %>%
 ## 55 enablers and 519 directions totoaling 574 overall  
  ungroup()%>%
 select(fac,hospital_name,hospital_type,hospital_type_group) %>%
  unique()
# so 125 hosptials
#There are 125 hospitals in our Srategy_master_analytical.csv
146-125
# so 21 missing from the strategic planning data. 
missing<-anti_join(HIT,StratHosp,by="fac") %>%
  select(fac)
anti_join(StratHosp,Registry)


# LETS ENSURE THAT THE BLOCKED ARE MISSING 


left_join(RoboTxtBlocked,StratHosp) %>%
  select(fac,name,strat_phase2_n_dirs)
