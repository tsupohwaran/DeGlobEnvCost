#==================================================#
# Install required Julia packages for the project
#==================================================#

using Pkg
cd("/Users/pohwaran/Doctorate/Paper/DeGlobEnvCost")
Pkg.activate("/Users/pohwaran/Doctorate/Paper/DeGlobEnvCost")
Pkg.instantiate()

ENV["PYTHON"]="/Users/pohwaran/anaconda3/bin/python"
Pkg.build("PyCall")