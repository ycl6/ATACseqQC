#' read in bam files
#'
#' wraper for readGAlignments/readGAlignmentsList to read in bam files.
#'
#' @param bamFile character(1). Bam file name.
#' @param which A \link[GenomicRanges:GRanges-class]{GRanges}, \link[IRanges:IntegerRangesList-class]{IntegerRangesList}, 
#' or any object that can be coerced to a RangesList, or missing object, 
#' from which a IRangesList instance will be constructed. 
#' See \link[Rsamtools:ScanBamParam-class]{ScanBamParam}.
#' @param tag A vector of characters indicates the tag names to be read.
#' See \link[Rsamtools:ScanBamParam-class]{ScanBamParam}.
#' @param what A character vector naming the fields to return. 
#' Fields are described on the \link{Rsamtools}[scanBam] help page.
#' @param flag An integer(2) vector used to filter reads based on their 
#' 'flag' entry. 
#' @param bigFile If the file take too much memory, set it to true to avoid read the reads into memory.
#' \link[Rsamtools:ScanBamParam-class]{scanBamFlag} helper function.
#' @param asMates logical(1). Paired ends or not
#' @param ... parameters used by \link[GenomicAlignments:readGAlignments]{readGAlignmentsList} 
#' or \link[GenomicAlignments]{readGAlignments}
#' @import GenomeInfoDb
#' @import S4Vectors
#' @importFrom GenomicAlignments readGAlignmentsList readGAlignments GAlignmentsList GAlignments
#' @importFrom Rsamtools scanBamFlag ScanBamParam scanBamHeader
#' @export
#' @return A GAlignmentsList object when asMates=TRUE,
#' otherwise A GAlignments object.
#' If bigFile is set to TRUE, no reads will be read into memory at this step and 
#' empty GAlignments/GAlignmentsList will be returned.
#' @author Jianhong Ou
#' @examples 
#' library(BSgenome.Hsapiens.UCSC.hg19)
#' which <- as(seqinfo(Hsapiens)["chr1"], "GRanges")
#' bamfile <- system.file("extdata", "GL1.bam", 
#'                        package="ATACseqQC", mustWork=TRUE)
#' readBamFile(bamfile, which=which, asMates=TRUE)
readBamFile <- function(bamFile, which, tag=character(0),
                        what=c("qname", "flag", "mapq", "isize", 
                               "seq", "qual", "mrnm"),
                        flag=scanBamFlag(isSecondaryAlignment = FALSE,
                                         isUnmappedQuery=FALSE,
                                         isNotPassingQualityControls = FALSE,
                                         isSupplementaryAlignment = FALSE),
                        asMates=FALSE, bigFile=FALSE,
                        ...) {
  stopifnot(length(bamFile)==1)
  if(file.size(bamFile)>1e8 && !bigFile && interactive()){
    bigFile <- readline("This is a big BAM file. Do you want to set bigFile=TRUE to save memory? (Y/n)? ")
    bigFile <- bigFile=="" || bigFile=="Y" || bigFile=="y"
  }
  if(!bigFile){
    if(!missing(which)){
      which <- keepSeqlevels(which, as.character(unique(seqnames(which))))
      param <-
        ScanBamParam(what=what,
                     tag=tag,
                     which=which,
                     flag=flag)
    }else{
      param <-
        ScanBamParam(what=what,
                     tag=tag,
                     flag=flag)
    }
    if(asMates) {
      readGAlignmentsList(bamFile, ..., param=param)
    }else{
      readGAlignments(bamFile, ..., param=param)
    }
  }else{
    if(!missing(which)){
      which <- keepSeqlevels(which, as.character(unique(seqnames(which))))
    }else{
      which <- scanBamHeader(bamFile, what=c("targets"))
      which <- which[[1]]$targets
      which <- GRanges(seqnames = names(which), IRanges(1, which))
    }
    param <-
      ScanBamParam(what=what,
                   tag=tag,
                   which=which,
                   flag=flag)
    if(asMates){
      gal <- GAlignmentsList()
    }else{
      gal <- GAlignments()
    }
    metadata(gal) <- list(file=bamFile, param=param, asMates=asMates, which=which, ...)
    gal
  }
}

loadBamFile <- function(gal, which=NULL, minimal=FALSE){
  meta <- metadata(gal)
  if(!all(c("file", "param") %in% names(meta))){
    stop("length of gal could not be 0.")
  }
  asMates <- meta$asMates
  if(length(asMates)==0) asMates <- FALSE
  meta$asMates <- NULL
  meta$which <- which
  if(minimal){
    meta$param <- ScanBamParam(flag=meta$param@flag, what=("qname"))
  }
  if(asMates){
    meta$mpos <- NULL
    do.call(readGAlignmentsList, meta)
  }else{
    if(length(meta$mpos)>0){
      mpos <- meta$mpos
      meta$mpos <- NULL
      gal1 <- do.call(readGAlignments, meta)
      mcols(gal1)$MD <- NULL
      names(gal1) <- mcols(gal1)$qname
      gal1 <- gal1[order(names(gal1))]
      mcols(gal1)$mpos <- mpos[paste(mcols(gal1)$qname, start(gal1))]
      gal1
    }else{
      do.call(readGAlignments, meta)
    }
  }
}