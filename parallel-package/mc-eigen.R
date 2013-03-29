# Write your function to expect arguments as a named list so it can be called
# via lapply which passes a list to each call of the function (is there a better way to do this?)

bigEigen <- function(args) {
  dmn <- args$dmn
  id <- args$id
  mdnAbsEigVals <- NA 
  A <- matrix(runif(dmn^2),dmn,dmn)
  eigValues <- eigen(A)$values 
  mdnAbsEigVals <- median(abs(eigValues))
  return(data.frame(id=id,mdnAbsEigVals=mdnAbsEigVals))
}

# Wrapper function which takes a dataframe of named function arguments and a
# function to be evaluated for each row of the dataframe arguments, and returns
# a dataframe of results. multi=F causes sequential processing, multi=T dispatches
# forked processes to run in parallel
oh.fork.it <- function(df, FUN, multi=T) {
  require(parallel)
  if (multi == T) {
    return.df <- as.data.frame(do.call("rbind", mclapply(split(df, rownames(df)), FUN)))
  } else {
    return.df <- as.data.frame(do.call("rbind", lapply(split(df, rownames(df)), FUN)))
  }
  return.df <- return.df[ do.call(order,return.df),]
  return(return.df)
}

# Create a dataframe of arguments
my.args <- data.frame(dmn=1000,id=1:10,other.random.stuff=rnorm(10))

# Evaluate sequentially, only one process and one CPU core used
system.time(sequential <- oh.fork.it(my.args,bigEigen,multi=F))
# Examine results
sequential

# Evaluate in parallel, one forked process per CPU core available
system.time(parall <- oh.fork.it(my.args,bigEigen,multi=T))
# Examine results
parall
