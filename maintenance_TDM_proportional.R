# in silico infliximab maintenance adaptive dosing project
# Script for simulating concentrations for the maintenance phase
# Subsequent doses are dependent on measured trough concentrations
# If trough target = 3 mg/L, and measured trough is 1.5 mg/L, then next dose will be doubled
# Assuming linear kinetics - double the dose, double the trough concentration
# ------------------------------------------------------------------------------
# Set up a loop that will sample the individual's concentration optimise their dose and administer until time = 602 days
	proportional.function <- function(induction.data) {
	# Make all predicted concentrations (IPRE) and PK parameter values after day 98 == NA
		conc.data <- induction.data
		conc.data$IPRE[conc.data$time > max(sample.times)] <- NA
		prev.int <- 56
		interval.increment <- 0

	# If the last predicted concentration in the data frame (i.e., when time = 602) is NA, then continue with the loop
		repeat {
		# Time of most recent sample
			last.sample <- max(sample.times)
		# Previous DV
			prev.DV <- conc.data$DV[conc.data$time == last.sample]
			prev.DV[prev.DV < 0] <- .Machine$double.eps
		# Previous covariate values
			prev.WT <- conc.data$WTCOV[conc.data$time == last.sample]
			prev.ADA <- conc.data$ADA[conc.data$time == last.sample]
			prev.ALB <- conc.data$ALBCOV[conc.data$time == last.sample]
		# Previous dose
			prev.dose.time <- head(tail(sample.times,2),1)
			prev.dose <- conc.data$amt[conc.data$time == prev.dose.time]
		# Calculate the new dose for the next interval based on "sample" and "dose"
			if (prev.DV < trough.target | prev.DV >= trough.upper) {
				new.dose <- trough.target/prev.DV*prev.dose	# Adjust the dose if out of range
			} else {
				new.dose <- prev.dose	# Continue with previous dose if within range
			}
		# Cap "new.dose" to 10 mg/kg
			if (new.dose > amt.max*prev.WT) {
				new.dose <- amt.max*prev.WT
				new.int <- prev.int-7	# Reduce interval by 7 days
				if (new.int < 7) new.int <- 7	# Minimum interval is 7 days
				prev.int <- new.int
			}
			if (new.dose < amt.min*prev.WT) {
				new.dose <- amt.min*prev.WT	# Minimum dose is still 3 mg/kg
				new.int <- prev.int+7	# Increase interval by 7 days
				if (new.int > 56) new.int <- 56	# Maximum interval is 56 days
				prev.int <- new.int
			}

		# Create input data frame for simulation
			input.sim.data <- conc.data
			input.sim.data$amt[input.sim.data$time == last.sample] <- new.dose	# Add new dose to data frame at time of last sample
			input.sim.data$TIME_WT <- prev.WT
			input.sim.data$TIME_ADA <- prev.ADA
			input.sim.data$TIME_ALB <- prev.ALB
			# Re-add evid and rate columns
				input.sim.data$cmt <- 1	# Signifies which compartment the dose goes into
				input.sim.data$evid <- 1	# Signifies dosing event
				input.sim.data$evid[input.sim.data$amt == 0] <- 0
				input.sim.data$rate <- -2	# Signifies that infusion duration is specified in model file
				input.sim.data$rate[input.sim.data$amt == 0] <- 0
			# Flag that this is simulation and want covariates to change depending on concentrations
				input.sim.data$FLAG <- time.dep
		# Simulate
			conc.data <- mod %>% mrgsim(data = input.sim.data,carry.out = c("amt","ERRPRO")) %>% as.tbl
		# Add the "next.sample" time to the list of sample.times
			next.sample <- last.sample+prev.int
			sample.times <- sort(c(unique(c(sample.times,next.sample))))
		# Make all predicted concentrations (IPRE) and PK parameter values after sample.time1 == NA
			conc.data$IPRE[conc.data$time > max(sample.times)] <- NA
		# If the last predicted concentration in the data frame (i.e., when time = 546) is NA, then continue with the loop
			if (is.na(conc.data$IPRE[conc.data$time == last.time]) == FALSE) break
		}	# Brackets closing "repeat"
		conc.data
	}	# Brackets closing "proportional.function"

	proportional.data <- ddply(induction.data, .(SIM,ID), proportional.function)

# ------------------------------------------------------------------------------
# Write proportional.data to a .csv file
	proportional.filename <- paste0("time_dep_",time.dep,"_proportional.csv")
	write.csv(proportional.data,file = proportional.filename,na = ".",quote = F,row.names = F)
