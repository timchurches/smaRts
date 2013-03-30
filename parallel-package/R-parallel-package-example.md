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
This short investigation of the _parallel_ package for R, was motvated by a demonstration of parallel processing with R given by Dr Jan Luts of the School of Mathematical Sciences at the University of Technology Sydney (UTS). The example function shown below is a slightly modified version of a function used by Jan in his demonstration (thanks to Jan for making a copy of his code available).

A much better resource for the _parallel_ pakage than this document is the [fairly extensive vignette](http://stat.ethz.ch/R-manual/R-devel/library/parallel/doc/parallel.pdf) for it!

### Threading and processes
Each instance of R running on a computer is typically just a single process, which itself is essentially single-threaded (although that is slowly changing with each new version of R). What that means is that an R process will use the resources of only one CPU core. If your computer has one CPU chip with two cores (as do most recent laptops and desktop computers), then a single R session (running in a single process) will  use only half the available CPU power of that computer. Higher-end laptop and desktop computers (eg recent Macbook Pro laptops) typically have quad-core CPUs, and servers typically have two or four CPU chips each with between 4 and 12 cores - thus up to 48 cores in total. Some shared memory (NUMA) high-performance computing (HPC) machines make thousands of CPU cores available to the operating system. Running a single R process on such machines clearly under-utilises their capabilities. 

One solution is to make each R process multi-threaded, so that work is divided internally within R and assigned to run on more than one CPU core at once. There is a lot of work underway to introduce such multi-threading into R: for statisticians, the work being done at Imperial College London on the use of high-performance linear algebra code in R in order to make better use of both multi-core CPUs and the massively-parallel computational units inside GPU (graphics processing unit) cards and chips looks particularly exciting - see the [HiPLAR](http://www.hiplar.org) web site for details.

Another solution is to break the computational task into parts and execute each part as a separate process, often on a _cluster_ of networked computers. There are several R packages that facilitate such use of a clustered HPC compute facility - see the R [task view for parallel and high-performance computing](http://cran.r-project.org/web/views/HighPerformanceComputing.html) for more details.

However, all these methods currently require the installation of special software libraries and/or the compilation of special patched versions of R (as in the case of _HiPLARb_), or access to a HPC cluster. By contrast, the technique demonstrated by Jan Luts, and the package discussed here, will work on any computer with more than one CPU core running Linux or Mac OS X without any additional work. Later on, techniques that will work on MS-Windows computers will be demonstrated.

The parallel package
--------------------
This package has been a standard core inclusion in R since version 2.14 - hence it is probably already installed in your version of R. If not, its predecessor, the _multicore_ package, can be installed (in the usual way) in earlier versions of R and it should work in an identical fashion. The _parallel_ package has also subsumed the _snow_ package, which provides support for parallel computatin in R on computer clusters.

### Forking
We will be using the  _parallel_ package to  _fork_ the operating system process in which R is running. On modern POSIX operating systems (which include Mac OS X and linux), this means that the process is effectively cloned, and the forked child process has access to the same memory regions as the parent process and can thus reference, say, R objects created in the parent process, without having to pass a copy of these objects to it. However, the memory sharing is done on a _copy-on-write_ basis, such that as soon as any of the child processes which share the parent process's memory write to a region of that memory (as they do when, say, updating values in an R object such as a vector), then the write is made to a copy of that memory region. In this way, each forked child process has access to its own version of its memory space, while still sharing the parts of that memory space which are in-common with the parent process. This can dramatically reduce memory consumption when launching multiple R processes on one computer, particularly when large R data objects need to be read (but not modified) by each of the forked child processes - only one copy of the large read-only R object (say, a large matrix) need be in memory at once. The lexical scoping rules in R make such object sharing even easier. Forking also avoids the start-up time overhead of launching separate, new R processes. Unfortunately, MS-Windows doesn't support forking of processes, and thus other methods must be employed (see below).

First, let's load the package:

```r
library(parallel)
```

Next, let's define a test function: this one is based on Jan Luts' example function which computes the eigenvalues of a matrix of random numbers. The only difference from Jan's version is that here the function returns a dataframe.


```r
bigEigen <- function(id, dmn) {
    mdnAbsEigVals <- NA
    A <- matrix(runif(dmn^2), dmn, dmn)
    eigValues <- eigen(A)$values
    mdnAbsEigVals <- median(abs(eigValues))
    return(data.frame(id = id, dmn = dmn, mdnAbsEigVals = mdnAbsEigVals))
}
```


Now let's define a wrapper function which takes a dataframe of named function arguments and a function to be evaluated for each row of the dataframe arguments, and returns a dataframe of results. The argument multi=F causes it to use the usual sequential processing on a single CPU core, whereas multi=T dispatches forked processes to run in parallel. The _parallel_ package looks after all the housekeeping details, including working out how many CPU cores are available and therefore how many sub-processes to optimally fork.


```r
in.parallel <- function(df, FUN, multi = T) {
    # Because lapply() and mclapply() want to pass arguments as a list, we
    # need to provide a wrapper to call our target function via do.call()
    DC.FUN <- function(argslist) {
        do.call(FUN, argslist)
    }
    
    if (multi == T) {
        return.list <- mclapply(split(df, rownames(df)), DC.FUN, mc.cores = detectCores())
    } else {
        return.list <- lapply(split(df, rownames(df)), DC.FUN)
    }
    
    # bind each dataframe in the returned list into one big dataframe
    return.df <- as.data.frame(do.call("rbind", return.list))
    # sort the dataframe, assuming the sort column (id) is the first column
    return.df <- return.df[do.call(order, return.df), ]
    
    return(return.df)
}
```

OK, so let's create a dataframe of arguments - say, 8 replicates of a 1000 by 1000 matrix.

```r
my.args <- data.frame(dmn = 1000, id = 1:8)
```


Now let's run this on just one CPU core to see how long it takes, and examine the results:

```r
seq.time <- system.time(sequential <- in.parallel(my.args, bigEigen, multi = F))
```

That took 119.451 seconds to run all replicates. Better check the results:

```r
sequential
```

```
##   id  dmn mdnAbsEigVals
## 1  1 1000         6.503
## 2  2 1000         6.487
## 3  3 1000         6.446
## 4  4 1000         6.561
## 5  5 1000         6.511
## 6  6 1000         6.459
## 7  7 1000         6.443
## 8  8 1000         6.530
```

Now let's run it using all the available CPU cores (the computer on which this document/code was run has 2 cores):

```r
par.time <- system.time(parall <- in.parallel(my.args, bigEigen, multi = T))
```

OK, that took 73.709 seconds, which is **1.6 times as fast**, using **2 times as many CPU cores**. Not too shabby! Check the results:

```r
parall
```

```
##   id  dmn mdnAbsEigVals
## 1  1 1000         6.423
## 2  2 1000         6.440
## 3  3 1000         6.453
## 4  4 1000         6.476
## 5  5 1000         6.488
## 6  6 1000         6.449
## 7  7 1000         6.431
## 8  8 1000         6.456
```

Yup, they look the same (remembering that each replicate creates its own matrix of random numbers).

Using a cluster
---------------
Forking of processes only works on POSIX computers, and it only works within a single instance of the operating system (i.e on a single physical computer or a single virtual machine). The alternative is to use a _cluster_, which involves the creation of multiple R processes which are independent of each other, either on the same computer, or distributed over many networked computers, with each process communicating with others via a network socket, or by more specialised protocols such as MPI or PVM. Network sockets are supported on all operating systems by default, and require no additional software or hardware to work. They can be used for communication between processes on a single computer and thus, cluster computing via sockets will work on standard MS-Windows computers.

First, let's modify our wrapper function so that it can use a cluster of independent processes, not just forked child processes. We'll add an argument called cl which takes an object of class cluster. If cl is set, socket communications to a cluster of processes is used. If cl is not set (it defaults to NA), then the function will use forking as previously: 


```r
in.parallel <- function(df, FUN, multi = T, cl = NULL) {
    # Because lapply() and mclapply() want to pass arguments as a list, we
    # need to provide a wrapper to call our target function via do.call()
    DC.FUN <- function(argslist) {
        do.call(FUN, argslist)
    }
    
    if (multi == T) {
        if ("cluster" %in% class(cl)) {
            return.list <- parLapply(cl, split(df, rownames(df)), DC.FUN)
        } else {
            return.list <- mclapply(split(df, rownames(df)), DC.FUN, mc.cores = detectCores())
        }
    } else {
        return.list <- lapply(split(df, rownames(df)), DC.FUN)
    }
    
    # bind each dataframe in the returned list into one big dataframe
    return.df <- as.data.frame(do.call("rbind", return.list))
    # sort the dataframe, assuming the sort column (id) is the first column
    return.df <- return.df[do.call(order, return.df), ]
    
    return(return.df)
}
```


Now, let's start up our cluster of R processes on our computer - as many R processes as there are CPU cores:

```r
cl <- makeCluster(detectCores())
```


Now let's run this on just one CPU core to see how long it takes, and examine the results:

```r
seq.time <- system.time(sequential <- in.parallel(my.args, bigEigen, multi = F))
```

That took 116.857 seconds to run all replicates. Better check the results:

```r
sequential
```

```
##   id  dmn mdnAbsEigVals
## 1  1 1000         6.417
## 2  2 1000         6.436
## 3  3 1000         6.483
## 4  4 1000         6.467
## 5  5 1000         6.506
## 6  6 1000         6.420
## 7  7 1000         6.462
## 8  8 1000         6.495
```

Now let's run it using the cluster of R processes we started up:

```r
par.time <- system.time(parall <- in.parallel(my.args, bigEigen, multi = T, 
    cl = cl))
```

```
## Error: 2 nodes produced errors; first error: object 'bigEigen' not found
```

```
## Timing stopped at: 0.004 0 0.007
```


Hmmm, that threw an error. Why? Because in a cluster, each compute node is completely separate, and thus they don't know about the biEigen() function which we created in the parent R process. Handily, there is a function provided in _parallel_ to distribute objects (such as user-defined functions) to each node in a cluster:

```r
clusterExport(cl, "bigEigen")
```

Now let's try it again:

```r
par.time <- system.time(parall <- in.parallel(my.args, bigEigen, multi = T, 
    cl = cl))
```

OK, that took 71.979 seconds, which is **1.6 times as fast**, using **2 times as many CPU cores**. Also not too bad! Best check the results:

```r
parall
```

```
##   id  dmn mdnAbsEigVals
## 1  1 1000         6.482
## 2  2 1000         6.469
## 3  3 1000         6.466
## 4  4 1000         6.430
## 5  5 1000         6.480
## 6  6 1000         6.518
## 7  7 1000         6.461
## 8  8 1000         6.450
```


Yup, looks OK. Finally, remember to stop the cluster! Alternatively, creation and shut-down of the cluster could be put inside our _in.parallel()_ function, but that would mean that there was the overhead of starting up several R processes, and then shutting them down, each time we called the function.

```r
stopCluster(cl)
```


Other functions in _parallel_
-----------------------------
The _parallel_ package also provides equivalent functions to automatically parallelise functions acting on vectors, as well as support for parallel processing on HPC clusters which use the more efficient MPI or PVM mechanisms, as opposed to sockets, for communication between each computer in the cluster.

Other resources
---------------
 * Matt Moores and Cathy Hargrave from QUT on [parallel Bayesian computation in R](http://www.slideshare.net/azeari/parallel-r) 
 * The [vignette for the _foreach_ package](The [fairly extensive vignette](http://stat.ethz.ch/R-manual/R-devel/library/parallel/doc/parallel.pdf) for the _parallel_ package), which can execute iterations of a for loop in parallel (is a parallel iteration an oxymoron?).
 * As mentioned, the [fairly extensive vignette](http://stat.ethz.ch/R-manual/R-devel/library/parallel/doc/parallel.pdf) for the _parallel_ package
 * the _boot_ package for bootstrap operations supports parallel computation via the _parallel_ package.

*******
