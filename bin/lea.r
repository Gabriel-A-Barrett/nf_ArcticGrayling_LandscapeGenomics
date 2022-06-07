#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly=TRUE)

if (length(args) < 3) {
    stop("Usage: lea.r <env value> <vcf file> <env file>")
}

env <- args[1]
vcf <- args[2]
env_file <- args[3]

if(!(file.exists(vcf) && (!file.info(vcf)$isdir))) stop("Second argument '<vcf file>' file does not exist")
if(!(file.exists(env_file) && (!file.info(env_file)$isdir))) stop("Third argument '<env file>' file does not exist")

message("Input meta (Arg 1:) ", env)
message("Input meta (Arg 2:) ", vcf)
message("Input meta (Arg 3:) ", env_file)

library(dplyr)
library(LEA)

if (env != "max_dist" | env != "min_dist"){
        latentFactors = 5
    } else {
        latentFactors = 3
    }

env <- toString(env) %>% gsub("[[:space:]]","",.)

# ~~~~~~~~~~~~~
# Population Genetic Differientation
# ~~~~~~~~~~~~~

geno <- ped2geno(vcf, output.file=paste0(env,".geno"), force=TRUE)

proj.snmf <- snmf(geno,K=latentFactors,entropy=T,ploidy=2,project="new",alpha=10,tolerance=0.0001,repetitions=2,iterations=100,CPU=25,percentage=.75)
# fst values
best <- which.min(cross.entropy(proj.snmf, K = latentFactors))

# fst function
fst = function(project,run = 1, K, ploidy = 2){
l = dim(G(project, K = K, run = run))[1]
q = apply(Q(project, K = K, run = run), MARGIN = 2, mean)
if (ploidy == 2) {
G1.t = G(project, K = K, run = run)[seq(2,l,by = 3),]
G2.t = G(project, K = K, run = run)[seq(3,l,by = 3),]
freq = G1.t/2 + G2.t}
else {
freq = G(project, K = K, run = run)[seq(2,l,by = 2),]}
H.s = apply(freq*(1-freq), MARGIN = 1, FUN = function(x) sum(q*x))
P.t = apply(freq, MARGIN = 1, FUN = function(x) sum(q*x))
H.t = P.t*(1-P.t)
return(1-H.s/H.t)
}

fst.values <- fst(proj.snmf, K = latentFactors, run = best)
# z-scores
n <- dim(Q(proj.snmf, K = latentFactors, run = best))[1]
fst.values[fst.values<0] <- 0.000001
GD_z_scores <- sqrt(fst.values*(n - latentFactors)/(1 - fst.values))
GD_z_scores <- as.data.frame(GD_z_scores)
colnames(GD_z_scores) <- paste0(env,"_GD_zscores")

# ~~~~~~~~~~~~~~
# Latent Factor Mixed Model
# ~~~~~~~~~~~~~~

lfmm <- ped2lfmm(vcf, output.file=paste0(env,".lfmm"), force=TRUE)

proj.lfmm <- lfmm(lfmm, env_file, K = latentFactors, repetitions = 2, project = "new", iterations = 100, burnin = 50, CPU = 25, missing.data = TRUE, random.init = TRUE)
# z-scores from all repititions
zv <- data.frame(z.scores(proj.lfmm, K = latentFactors))
zv %>% rowwise() %>% mutate(paste0(env,"_EA_zscores") := median(c_across(everything()))) %>% select(paste0(env,"_EA_zscores")) %>% 
cbind(.,GD_z_scores) %>% 
write.table(x=., file = paste0(env,"_zscores.txt"),quote=F,row.names=F,col.names=T,sep="\t")



