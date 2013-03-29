Using all the CPU cores on your computer with the _parallel_ package for R
==========================================================================
**Tim Churches**  
Sydney, Australia  
tim∙churches@gmail∙com  
29 March 2013.

About this document
-------------------
This document is an example of [literate programming](http://en.wikipedia.org/wiki/Literate_programming), in which expository text is interleaved with computer program code and the output of that code. The document was created in markdown format using [RStudio](http://www.rstudio.com) and the [_knitr_](http://yihui.name/knitr/) package for the [R statistical environment](http://www.r-project.org).

Pre-amble
---------
This short investigation of the _parallel_ package for R, which was included in the set of core R packages starting with R 2.14.0, was motvated by a demonstration of parallel processing with R given by Dr Jan Luts of the School of Mathematical Sciences at the University of Technology Sydney (UTS). The example function shown below is a slightly modified version of a function used by Jan in his demonstration.

### Threading and processes
Each instance of R running on a computer is typically just a single process, which itself is essentially single-threaded (although that is slowly chnaging with each new version of R). What that means is that an R process will use the resources of only one CPU core. If your computer has one CPU chip with two cores (as do most recent laptops and desltop computers), then a single R session (running in a single process) will only use half the available CPU power of that computer. Higher-end laptop and desktop computers (eg recent Macbook Pro laptops) may have a quad-core CPU, and servers typically have two or four CPU chips each with between four and 12 cores. Some high-performance computing (HPC) machines have thousands of CPU cores available. Running a single R process on such machines clearly underutilises their capabilities. 

One solution is to make each R process multi-threaded, so that work is divided internally within R and assigned to run on more than one CPU core at once. There is a lot of work underway to introduce such multi-threading into R: for statisticians, the work being done at Imperial College London on the use of high-performance linear algebra code in R in order to make better use of both multi-core CPUs and the massively-parallel computational units inside GPU (graphics processing unit) cards and chips looks particularly exciting - see the [HiPLAR](http://www.hiplar.org) web site for details.

Another solution is to break the computational task into parts and execute each part as a separate process, often on a _cluster_ of networked computers. There are several R packages that facilitate such use of a clustered HPC compute facility - see the R [task view for parallel and high-performance computing](http://cran.r-project.org/web/views/HighPerformanceComputing.html) for more details.

However, all these methods currently require the nstallation of special software libraries and the building of patched versions of R (HiPLAR), or access to a HPC cluster. By contrast, the technique demonstrated by Jan Luts and the package discussed here will work on any computer with more than one CPU core running Linux or Mac OS X without an additional work. MS-Windows users will need to research alternative solutions.

The parallel package
--------------------
This package has been a standard core inclusion in R since version 2.14 - hence it is probably already installed in your version of R. If not, its predecessor, the _multicore_ package, can be installed (in the usual way) in earlier versions of R and it should work in an identical fashion.

### Forking
The _parallel_ package works by _forking_ the operation system process in which R is running. On modern unix (including Mac OS X) and linux systems, this means that the process is effectively cloned, and the forked process has access to the same memory regions as the parent process and can thus reference, say, R objects created in the parent process, without having to pass a copy of them. However, the memory sharing is done on a copy-on-write basis, so that as soon as any of the processes which share memory write to a region of that memory (as they do when, say, updating values in an R object such as a vector), then the write is made to a copy of that memory region. In this way, each forked process has access to its own version of its memory space, while still sharing the parts of that memory space which are in-common. This can dramatically reduce memory consumption, particularly when large R data objects need to be read (but not modified) by each of the forked sub-processes - only one copy of the large read-only R object (say, a large matrix) need be in memory at once. The lexical scoping rules in R make such object sharing even easier. Let's load the package:

```r
library(parallel)
```

Next, let's define a test function: this one is based on Jan Luts' simple example function which computes the eigenvalues of a matrix of random numbers. The only difference to Jan's version is that here the function expects its arguments to be passed as a list of named values. This was done because we will be using the _mclapply()_ function from the _parallel_ package, and like _lapply()_ it expects a list and returns a list.


```r
bigEigen <- function(args) {
    dmn <- args$dmn
    id <- args$id
    mdnAbsEigVals <- NA
    A <- matrix(runif(dmn^2), dmn, dmn)
    eigValues <- eigen(A)$values
    mdnAbsEigVals <- median(abs(eigValues))
    return(data.frame(id = id, mdnAbsEigVals = mdnAbsEigVals))
}
```


Now let's define a wrapper function which takes a dataframe of named function arguments and a function to be evaluated for each row of the dataframe arguments, and returns a dataframe of results. The argument multi=F causes it to use usual sequential processing on a single CPU core, whereas multi=T dispatches forked processes to run in parallel. The _parallel_ package looks after all the housekeeping details, including working out how many CPU cores are available and therefore how many sub-processes to fork.


```r
oh.fork.it <- function(df, FUN, multi = T) {
    if (multi == T) {
        return.df <- as.data.frame(do.call("rbind", mclapply(split(df, rownames(df)), 
            FUN)))
    } else {
        return.df <- as.data.frame(do.call("rbind", lapply(split(df, rownames(df)), 
            FUN)))
    }
    return.df <- return.df[do.call(order, return.df), ]
    return(return.df)
}
```

OK, so let's create a dataframe of arguments - say, 10 replications of a 1000 by 1000 matrix.

```r
my.args <- data.frame(dmn = 1000, id = 1:10)
```


Now let's run this on just one CPU core to see how long it takes, and examine the results:

```r
seq.time <- system.time(sequential <- oh.fork.it(my.args, bigEigen, multi = F))
```

That took 145.864 seconds to run all replicates. Better check the results:

```r
sequential
```

```
##    id mdnAbsEigVals
## 1   1         6.491
## 2   2         6.439
## 3   3         6.387
## 4   4         6.447
## 5   5         6.400
## 6   6         6.460
## 7   7         6.440
## 8   8         6.460
## 9   9         6.453
## 10 10         6.408
```

Now let's run it using all the available CPU cores (the computer on which this document/code was run has 2 cores):

```r
par.time <- system.time(parall <- oh.fork.it(my.args, bigEigen, multi = T))
```

OK, that took 88.06 seconds, which is **1.7 times as fast**. Nice! Check the results:

```r
parall
```

```
##    id mdnAbsEigVals
## 1   1         6.460
## 2   2         6.460
## 3   3         6.428
## 4   4         6.460
## 5   5         6.470
## 6   6         6.410
## 7   7         6.455
## 8   8         6.511
## 9   9         6.428
## 10 10         6.469
```

Yup, they look the same (remembering that each replicate creates its own matrix of random numbers).

Other functions in _parallel_
-----------------------------
The _parallel_ package provides equivalent functions to automatically parallelise map functions for vectors, as well as support for parallel processing on HPC clusters (including MPI and PVM clusters) via the _snow_ package.
