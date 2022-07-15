include {compositeStats; combineEnv} from '../modules/composite_stats'

workflow postGWAS {
    
    take:
    gwas
    
    main:
    compositeStats (gwas, params.ann_vcf, params.fullentap, params.headers_key)
    combineEnv (compositeStats.out.candidates.collect())

}




/*

upgrade to collect all baypass and lea files gwas.collect(it[1], it[2])

ruins staching in environmental directories within results, solves caching issues by reducing to 1 process

*/