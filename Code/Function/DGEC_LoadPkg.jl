#==================================================#
# load required packages
#==================================================#

using Pkg

using LinearAlgebra,
    # Package for data manipulation
    JLD2, # save data using julia native format
    StatFiles, # read and write Stata files
    XLSX, # read and write Excel files
    ExcelReaders, # read and write old Excel files
    CSV, # read and write csv files
    Tables,
    DataFrames, # same as .dta in Stata

    # Other packages
    FixedEffectModels, # Fixed effect models
    QuantEcon,
    AppleAccelerate, # Apple's BLAS !!!Warning: only for MacOS!!!
    BenchmarkTools, # test the speed of the code
    PyCall, # call Python functions
    ClipData, # copy data

    # Plots
    Plots, 
    StatsPlots