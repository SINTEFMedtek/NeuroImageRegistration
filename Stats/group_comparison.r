library(jsonlite)
library(oro.nifti)
library(fslr)
library(foreach)
library(doParallel)
library(logging)

source('utils.r')

# File and folder names
results_folder_name <- format(Sys.time(),format='RES_survival_stats_%Y%m%d_%H%M')
results_file_name <- 'p_values_corrected'
log_file_name <- 'group_comparison.log'
dir.create(results_folder_name)

# Setting up logging
logReset()
basicConfig(level='DEBUG')
addHandler(writeToFile, file=paste(results_folder_name, log_file_name, sep='/'), level='INFO')
removeHandler('writeToConsol')

# Host-specific parameters
host <- Sys.info()["nodename"]
if (host == 'SINTEF-0ZQHTDG'){
    n_cores <- 4
} else if (host == 'medtech-beast') {
    n_cores <- 30
} else {
    logwarn
    logwarn('The computer named %s is not known. Number of cores is set to 1.', host)
    n_cores <- 1
}
registerDoParallel(cores=n_cores)

loginfo('Reading data')
#pids_per_voxel <- fromJSON('pids_per_voxel.json')
load('test_data.RData')
survival_group_per_patient <- unlist( fromJSON('survival_group_per_patient.json'), use.names=FALSE)

template_img_file <- 'total_tumor.nii.gz'
template_img <- readNIfTI(template_img_file)
img_dim <- template_img@dim_[2:4]

n_total <- count_patients_per_group(survival_group_per_patient)

n_permutations <- 50
min_marginal <- 10

loginfo('Creating permutations')
set.seed(7)
permuted_indices <- rperm( length(survival_group_per_patient), n_permutations )

loginfo('Performing permutation tests')
batch_size <- ((length(pids_per_voxel)/(2*n_cores))%/%1000+1)*1000 # Two batches per processor, rounded up to nearest 1000
batch_lims <- seq(0,length(pids_per_voxel)-1, by=batch_size)
t1 <- system.time({
    p_values_array <- 
        foreach( lim = batch_lims, .combine = '+') %dopar% {
            lim1 <- lim+1
            lim2 <- min( lim+batch_size, length(pids_per_voxel) )
            batch <- c(lim1:lim2)
            t2 <- system.time({
                temp_array <- array(0, dim=img_dim)
                for (i in batch) {
                    pids <- pids_per_voxel[[i]]+1 # Add 1 to convert from pythonic, zero-based indexing
                    if (length(pids)>=min_marginal) {
                        p_value_original <- stat_test(survival_group_per_patient[pids], n_total)
                        p_values <- rep(0, n_permutations)
                        for (j in 1:n_permutations) {
                            survival_groups_permuted <- survival_group_per_patient[permuted_indices[j,]]
                            #groups <- survival_groups_permuted[pids] #evt. unlist(pid,use.names=FALSE)?
                            p_values[j] <- stat_test(survival_groups_permuted[pids], n_total)
                        }
                        p_value_corrected <- sum(p_values>p_value_original)/n_permutations # ER DETTE RIKTIG??

                        index_str <- names(pids_per_voxel[i])
                        index_str_list <- strsplit(index_str,'_')
                        index <- strtoi(unlist(index_str_list))+1 # Add 1 to convert from pythonic, zero-based indexing
                        temp_array[img_dim[1]+1-index[1], index[2], index[3]] <- p_value_corrected #p_values_corrected[[index_str]]
                    }                
                }
            })
            #cat(paste('Finished processing voxels', lim1, 'to', lim2, ' out of ', length(pids_per_voxel), ' in ', round(t2[3]), ' seconds.\n'), file='log.txt', append=TRUE)
            loginfo('Finished processing voxels %i to %i out of %i in %i seconds', lim1, lim2, length(pids_per_voxel), round(t2[3]))
            temp_array
        } 
})
loginfo('Total processing time: %i seconds.', round(t1[3]))

loginfo('Writing results to file')
p_values_img <- niftiarr(template_img, p_values_array)
writeNIfTI(p_values_img, filename=paste(results_folder_name, results_file_name, sep='/'))
loginfo('Finished.')




