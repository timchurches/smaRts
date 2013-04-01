# mc-eigen.R
# Tim Churches, March 2013

library(parallel)

bigEigen <- function(id,dmn) {
  mdnAbsEigVals <- NA 
  A <- matrix(runif(dmn^2),dmn,dmn)
  eigValues <- eigen(A)$values 
  mdnAbsEigVals <- median(abs(eigValues))
  return(data.frame(id=id,dmn=dmn,mdnAbsEigVals=mdnAbsEigVals))
}

# Wrapper function which takes a dataframe of named function arguments and a
# function to be evaluated for each row of the dataframe arguments, and returns
# a dataframe of results. multi=F causes sequential processing, multi=T dispatches
# forked processes to run in parallel

in.parallel <- function(df, FUN, multi=T, cl=NULL) {
  # Because lapply() and mclapply() want to pass arguments as a list, we need to 
  # provide a wrapper to call our target function via do.call()
  DC.FUN <- function (argslist) { do.call(FUN, argslist) }
  
  if (multi == T) {
    if ("cluster" %in% class(cl)) {
      return.list <- parLapply(cl, split(df, rownames(df)), DC.FUN)
    } else {
      return.list <- mclapply(split(df, rownames(df)), DC.FUN, mc.cores=detectCores())
    }
  } else {
    return.list <- lapply(split(df, rownames(df)), DC.FUN)
  }
  
  # bind each dataframe in the returned list into one big dataframe
  return.df <- do.call("rbind", return.list)
  # sort the dataframe, assuming the sort column (id) is the first column
  return.df <- return.df[ do.call(order,return.df),]
  
  return(return.df)
}

# Create a dataframe of arguments
my.args <- data.frame(dmn=1000,id=1:8)

# Evaluate sequentially, only one process and one CPU core used
system.time(    sequential <- in.parallel(my.args, bigEigen, multi=F)    )
# Examine results
sequential

# Evaluate in parallel, one forked process per CPU core available
system.time(    parall <- in.parallel(my.args, bigEigen, multi=T)    )
# Examine results
parall

# Now, let's start up our cluster of R processes on our computer - as many R processes as there are CPU cores
cl <- makeCluster(detectCores() )

# Distribute our function to each cluster process
clusterExport(cl,"bigEigen")

# Now let's run it using the cluster of R processes we started up:
system.time(    parall <- in.parallel(my.args, bigEigen, multi=T, cl=cl)    )
parall

# Shut down the cluster processes
stopCluster(cl)
